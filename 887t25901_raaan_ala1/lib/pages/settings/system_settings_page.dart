import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../models/dashboard_persistent_data.dart';
import '../../services/local_version_reader.dart';
import '../../services/wifi_manager.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/design_resolution_scaler.dart';
import '../../widgets/prototype_chrome.dart';
import '../../widgets/touch_password_keyboard.dart';
import '../engineering/engineering_mode_page.dart';

typedef SaveDashboardSettings = Future<bool> Function(DashboardData next);
typedef SavePersistentConfiguration = Future<bool> Function(
  DashboardPersistentData next,
);

/// Wi-Fi 详情页扫描节拍：进入时立即执行一次，之后每 10 秒尝试一次。
/// 连接、断开或上一次扫描未完成时会跳过本拍，不并发扫描。
const Duration kWifiScanInterval = Duration(seconds: 10);

/// 设置页：系统设置、设备维护和工程模式密码入口。
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({
    Key? key,
    required this.data,
    required this.engineeringPassword,
    required this.onEngineeringPasswordChanged,
    required this.persistentData,
    required this.onSavePersistentConfiguration,
    required this.onBack,
    this.wifiManager,
    required this.onSaveSettings,
    required this.onEngineeringModeChanged,
    this.onWifiConnectionLockChanged,
    required this.entryToken,
  }) : super(key: key);

  final DashboardData data;
  final String engineeringPassword;
  final ValueChanged<String> onEngineeringPasswordChanged;
  final DashboardPersistentData persistentData;
  final SavePersistentConfiguration onSavePersistentConfiguration;
  final VoidCallback onBack;
  final DashboardWifiManager? wifiManager;
  final SaveDashboardSettings onSaveSettings;
  final Future<void> Function(bool active) onEngineeringModeChanged;
  final ValueChanged<bool>? onWifiConnectionLockChanged;
  final int entryToken;

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  static const String _defaultDebugWifiPassword = '666666';
  static const Duration _debugWifiConnectionDelay =
      Duration(milliseconds: 3000);
  static const double _datePickerDesignScale = 2.0;

  int _sectionIndex = 0;
  bool _showNetworkDetail = false;
  bool _saving = false;
  String? _connectingWifiSsid;
  String? _wifiConnectionErrorSsid;
  bool _engineeringModeActive = false;
  bool _timeFormatMenuOpen = false;
  bool _clockMenuOpen = false;
  bool _languageMenuOpen = false;
  bool _brightnessMenuOpen = false;
  bool _priorityMetricMenuOpen = false;
  bool _indicatorLightBrightnessMenuOpen = false;
  bool _screenOffTimeMenuOpen = false;
  int _engineeringEntrySerial = 0;
  bool _inUpdateProgress = false;
  Timer? _wifiScanTimer;
  bool _wifiScanRequestInFlight = false;
  bool _wifiConnectionLockActive = false;
  int? _connectingWifiPasswordLength;
  String _localVersion = kAppDefaultVersion;

  // Figma 69:4201：三项分别对应系统设置、设备维护、工程模式。
  List<PrototypeMenuItem> _buildMenuItems(AppLocalizations l10n) {
    return <PrototypeMenuItem>[
      PrototypeMenuItem(
        l10n.menuSettings,
        PrototypeGlyph.system,
        activeIconAsset: 'assets/navigation/settings_system_active.png',
        inactiveIconAsset: 'assets/navigation/settings_system_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.menuMaintenance,
        PrototypeGlyph.maintenance,
        activeIconAsset: 'assets/navigation/settings_maintenance_active.png',
        inactiveIconAsset:
            'assets/navigation/settings_maintenance_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.menuEngineering,
        PrototypeGlyph.engineering,
        activeIconAsset: 'assets/navigation/settings_engineering_active.png',
        inactiveIconAsset:
            'assets/navigation/settings_engineering_inactive.png',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalVersion());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyWifiConnectionLock();
      }
    });
  }

  Future<void> _loadLocalVersion() async {
    final version = await readLocalVersion();
    if (!mounted || version == _localVersion) {
      return;
    }
    setState(() => _localVersion = version);
  }

  @override
  void didUpdateWidget(covariant SystemSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    String? passwordRetrySsid;
    final wifi = widget.data.effectiveWifiState;
    final operation = wifi.operation;
    if (widget.data.backendReachable && wifi.available) {
      if (operation == 'connecting') {
        // 只有用户点选产生的 pending 才锁住本次连接事务；模组或外部
        // 命令产生的连接过程只按运行快照展示。
        _connectingWifiSsid = widget.wifiManager?.manualPendingSsid;
        _wifiConnectionErrorSsid = null;
      } else if (operation == 'failed') {
        final manualSsid = _connectingWifiSsid;
        final failedSsid =
            wifi.operationSsid.isEmpty ? manualSsid : wifi.operationSsid;
        _wifiConnectionErrorSsid = failedSsid;
        if (manualSsid != null && failedSsid == manualSsid) {
          _connectingWifiSsid = null;
          _connectingWifiPasswordLength = null;
          if (_showNetworkDetail) {
            passwordRetrySsid = manualSsid;
          }
        } else {
          // 失败结果必须命中同一轮手动连接事务。旧的或外部连接的
          // 失败快照不能清掉当前手动 pending，也不能触发密码弹窗。
          _connectingWifiSsid = widget.wifiManager == null
              ? manualSsid
              : widget.wifiManager!.manualPendingSsid;
        }
      } else if (wifi.connected) {
        _connectingWifiSsid = null;
        _connectingWifiPasswordLength = null;
        _wifiConnectionErrorSsid = null;
      } else {
        // 外部连接状态不能把手动选网入口长期锁住；用户主动连接 pending
        // 仍保持事务内防重入。
        _connectingWifiSsid = widget.wifiManager?.manualPendingSsid;
      }
    }
    if (_showNetworkDetail) {
      final scanWasAvailable = _canScanWifi(oldWidget.data);
      final scanIsAvailable = _canScanWifi(widget.data);
      if (!scanIsAvailable) {
        _stopWifiScanLoop();
      } else if (!scanWasAvailable) {
        _startWifiScanLoop();
      }
    }
    if (widget.entryToken != oldWidget.entryToken) {
      _stopWifiScanLoop();
      _sectionIndex = 0;
      _showNetworkDetail = false;
      _saving = false;
      _inUpdateProgress = false;
      _connectingWifiSsid = null;
      _connectingWifiPasswordLength = null;
      _wifiConnectionErrorSsid = null;
      _closeInlineMenusInState();
      if (_engineeringModeActive) {
        _engineeringModeActive = false;
        unawaited(widget.onEngineeringModeChanged(false));
      }
    }
    if (passwordRetrySsid != null &&
        widget.entryToken == oldWidget.entryToken) {
      _scheduleWifiPasswordRetry(passwordRetrySsid);
    }
    _notifyWifiConnectionLock(defer: true);
    // 版本更新状态检测：下载失败时弹出失败弹窗。
    if (_inUpdateProgress &&
        widget.data.versionUpdateStatus == 'download_failed' &&
        oldWidget.data.versionUpdateStatus != 'download_failed') {
      _inUpdateProgress = false;
      // 关闭当前更新中弹窗。使用 rootNavigator: true 与 showDialog 的根导航器一致。
      Navigator.of(context, rootNavigator: true).pop();
      // 延迟到下一帧再弹失败弹窗，避免在 didUpdateWidget 重建期间
      // 同时 pop 和 push 路由导致 Navigator 状态冲突。
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_showUpdateFailedDialog());
          }
        });
      }
    }
  }

  void _scheduleWifiPasswordRetry(String ssid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_showNetworkDetail ||
          _connectingWifiSsid != null ||
          _wifiConnectionErrorSsid != ssid) {
        return;
      }
      unawaited(_selectWifi(ssid));
    });
  }

  @override
  void dispose() {
    _stopWifiScanLoop();
    if (_wifiConnectionLockActive) {
      widget.onWifiConnectionLockChanged?.call(false);
    }
    super.dispose();
  }

  void _notifyWifiConnectionLock({bool defer = false}) {
    final active = _isWifiConnectionInProgress;
    if (active == _wifiConnectionLockActive) {
      return;
    }
    _wifiConnectionLockActive = active;
    final callback = widget.onWifiConnectionLockChanged;
    if (callback == null) {
      return;
    }
    void notify() {
      if (mounted || !active) {
        callback(active);
      }
    }

    if (defer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      notify();
    }
  }

  bool get _isWifiConnectionInProgress {
    // 休眠锁只属于前端主动发起的连接事务。后端、模组或命令行的
    // connecting 快照仅作被动展示，不改变前端的休眠策略。
    return _connectingWifiSsid != null;
  }

  String? get _wifiConnectionDisplaySsid {
    final pending = _connectingWifiSsid;
    if (pending != null && pending.isNotEmpty) {
      return pending;
    }
    final wifi = widget.data.effectiveWifiState;
    if (widget.data.backendReachable &&
        wifi.operation == 'connecting' &&
        wifi.operationSsid.isNotEmpty) {
      return wifi.operationSsid;
    }
    return null;
  }

  Future<bool> _save(DashboardData next) async {
    if (!mounted || _saving) {
      return false;
    }
    // 写入期间只作为防重入锁，不触发整页重建。开关控件自己负责
    // 局部反馈；保存成功后由 settings 快照通知更新最终值。
    _saving = true;
    try {
      return await widget.onSaveSettings(next);
    } finally {
      _saving = false;
    }
  }

  void _handleBack() {
    if (_wifiConnectionLockActive) {
      return;
    }
    if (_hasOpenInlineMenu) {
      setState(() {
        _closeInlineMenusInState();
      });
      return;
    }
    if (_engineeringModeActive) {
      _exitEngineeringMode();
      return;
    }
    if (_sectionIndex == 0 && _showNetworkDetail) {
      _closeNetworkDetail();
      return;
    }
    widget.onBack();
  }

  Future<void> _selectSection(int index) async {
    if (_engineeringModeActive && index != 2) {
      await _exitEngineeringMode();
    }
    if (!mounted) {
      return;
    }
    _stopWifiScanLoop();
    setState(() {
      _sectionIndex = index;
      _showNetworkDetail = false;
      _closeInlineMenusInState();
      _wifiConnectionErrorSsid = null;
    });
  }

  Future<void> _enterEngineeringMode() async {
    setState(() {
      _engineeringEntrySerial++;
      _engineeringModeActive = true;
    });
    await widget.onEngineeringModeChanged(true);
  }

  Future<void> _exitEngineeringMode() async {
    await widget.onEngineeringModeChanged(false);
    if (!mounted) {
      return;
    }
    setState(() {
      _engineeringModeActive = false;
      _sectionIndex = 2;
    });
  }

  Future<bool> _resetMaintenanceConsumables() {
    // 剩余天数属于正常设备维护确认状态：写 settings，读取成功后
    // 由父级数据回传刷新界面；不进入 runtime 或长期工程配置。
    return _save(
      widget.data.copyWith(
        filter1RemainingDays: 400,
        filter2RemainingDays: 400,
        filter3RemainingDays: 400,
      ),
    );
  }

  Future<void> _showMaintenanceResetDialog() async {
    if (_saving) {
      return;
    }
    await _showSettingsDialog<void>(
      barrierDismissible: false,
      barrierColor: const Color(0xA6000000),
      builder: (context) => _MaintenanceResetDialog(
        onConfirm: _resetMaintenanceConsumables,
      ),
    );
  }

  void _openNetworkDetail() {
    setState(() {
      _showNetworkDetail = true;
      // 连接失败仅提示本次尝试；重新进入网络页时不保留旧提示。
      _wifiConnectionErrorSsid = null;
    });
    _startWifiScanLoop();
  }

  void _closeNetworkDetail() {
    _stopWifiScanLoop();
    setState(() {
      _showNetworkDetail = false;
      _wifiConnectionErrorSsid = null;
    });
  }

  void _toggleTimeFormatMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_timeFormatMenuOpen;
      _closeInlineMenusInState();
      _timeFormatMenuOpen = open;
    });
  }

  Future<void> _selectTimeFormat(String selected) async {
    setState(() {
      _timeFormatMenuOpen = false;
    });
    if (selected != widget.data.timeFormat) {
      await _save(widget.data.copyWith(timeFormat: selected));
    }
  }

  Future<void> _selectDate() async {
    if (_saving) {
      return;
    }
    if (_hasOpenInlineMenu) {
      setState(_closeInlineMenusInState);
    }
    var initialDate = DateTime(
      widget.data.dateYear,
      widget.data.dateMonth,
      widget.data.dateDay,
    );
    while (mounted) {
      final selected = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2099, 12, 31),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        initialDatePickerMode: DatePickerMode.day,
        builder: (context, child) => Localizations.override(
          context: context,
          locale: _datePickerLocale(widget.data.languageCode),
          delegates: const <LocalizationsDelegate<dynamic>>[
            _DatePickerMaterialLocalizationsDelegate(),
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: TooltipVisibility(
            visible: false,
            child: Transform.scale(
              key: const ValueKey<String>('settings-date-picker-scale'),
              scale: _datePickerScaleFor(context),
              child: Theme(
                data: _datePickerThemeData(),
                child: child!,
              ),
            ),
          ),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      final unchanged = selected.year == widget.data.dateYear &&
          selected.month == widget.data.dateMonth &&
          selected.day == widget.data.dateDay;
      if (unchanged) {
        return;
      }
      final saved = await _save(
        widget.data.copyWith(
          dateYear: selected.year,
          dateMonth: selected.month,
          dateDay: selected.day,
        ),
      );
      if (saved || !mounted) {
        return;
      }
      // 保存失败时保持用户刚选的草稿，再次打开日历供确认重试。
      initialDate = selected;
    }
  }

  double _datePickerScaleFor(BuildContext context) {
    final viewport = MediaQuery.of(context).size;
    final viewportScale = math.min(
      viewport.width / kDesignResolution.width,
      viewport.height / kDesignResolution.height,
    );
    return _datePickerDesignScale * viewportScale;
  }

  ThemeData _datePickerThemeData() {
    final baseTheme = ThemeData.light();
    final baseTextTheme = baseTheme.textTheme.apply(
      fontFamily: AppFonts.sourceHanSansSc,
    );
    TextStyle? medium(TextStyle? style) => style?.copyWith(
          fontWeight: FontWeight.w500,
          fontVariations: AppFonts.sourceHanSansScMediumWght500,
        );

    return baseTheme.copyWith(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF25AEF3),
        onPrimary: Colors.white,
        surface: Colors.white,
        // Flutter 3.3.7 会再为月份、星期和日期叠加 60%/87% 透明度；
        // 使用更深的基础色，保证 8 寸实体屏上的笔画清楚。
        onSurface: Color(0xFF111418),
      ),
      dialogBackgroundColor: Colors.white,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: MaterialStateProperty.all<Color>(
            Colors.transparent,
          ),
          minimumSize: MaterialStateProperty.all<Size>(
            const Size(74, 36),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headline4: medium(baseTextTheme.headline4),
        headline5: medium(baseTextTheme.headline5)?.copyWith(fontSize: 18),
        subtitle1: medium(baseTextTheme.subtitle1),
        subtitle2: medium(baseTextTheme.subtitle2),
        bodyText1: medium(baseTextTheme.bodyText1),
        bodyText2: medium(baseTextTheme.bodyText2),
        caption: medium(baseTextTheme.caption)?.copyWith(fontSize: 14),
        button: medium(baseTextTheme.button),
        overline: medium(baseTextTheme.overline)?.copyWith(fontSize: 13),
      ),
    );
  }

  void _toggleClockMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_clockMenuOpen;
      _closeInlineMenusInState();
      _clockMenuOpen = open;
    });
  }

  Future<bool> _confirmClock(_ClockSettingValue selected) async {
    final unchanged = selected.hour == widget.data.clockHour &&
        selected.minute == widget.data.clockMinute &&
        selected.second == widget.data.clockSecond;
    final saved = unchanged
        ? true
        : await _save(
            widget.data.copyWith(
              clockHour: selected.hour,
              clockMinute: selected.minute,
              clockSecond: selected.second,
            ),
          );
    if (saved && mounted) {
      setState(() {
        _clockMenuOpen = false;
      });
    }
    return saved;
  }

  void _toggleLanguageMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_languageMenuOpen;
      _closeInlineMenusInState();
      _languageMenuOpen = open;
    });
  }

  Future<void> _selectLanguage(String selected) async {
    setState(() {
      _languageMenuOpen = false;
    });
    if (selected != widget.data.languageCode) {
      await _save(widget.data.copyWith(languageCode: selected));
    }
  }

  void _toggleBrightnessMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_brightnessMenuOpen;
      _closeInlineMenusInState();
      _brightnessMenuOpen = open;
    });
  }

  Future<bool> _saveBrightness(int selected) {
    if (selected == widget.data.effectiveScreenBrightnessPercent) {
      return Future<bool>.value(true);
    }
    return _save(
      widget.data.copyWith(screenBrightnessPercent: selected),
    );
  }

  void _togglePriorityMetricMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_priorityMetricMenuOpen;
      _closeInlineMenusInState();
      _priorityMetricMenuOpen = open;
    });
  }

  Future<void> _selectPriorityMetric(String selected) async {
    setState(() {
      _priorityMetricMenuOpen = false;
    });
    if (selected != widget.data.priorityMetric) {
      await _save(widget.data.copyWith(priorityMetric: selected));
    }
  }

  Future<bool> _toggleAqiIndicator(bool enabled) {
    return _save(widget.data.copyWith(aqiIndicatorEnabled: enabled));
  }

  Future<bool> _togglePresenceRadar(bool enabled) {
    return _save(widget.data.copyWith(presenceRadarEnabled: enabled));
  }

  void _toggleIndicatorLightBrightnessMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_indicatorLightBrightnessMenuOpen;
      _closeInlineMenusInState();
      _indicatorLightBrightnessMenuOpen = open;
    });
  }

  Future<void> _selectIndicatorLightBrightness(String selected) async {
    setState(() {
      _indicatorLightBrightnessMenuOpen = false;
    });
    if (selected != widget.data.indicatorLightBrightness) {
      await _save(
        widget.data.copyWith(indicatorLightBrightness: selected),
      );
    }
  }

  void _toggleScreenOffTimeMenu() {
    if (_saving) {
      return;
    }
    setState(() {
      final open = !_screenOffTimeMenuOpen;
      _closeInlineMenusInState();
      _screenOffTimeMenuOpen = open;
    });
  }

  Future<void> _selectScreenOffTime(String selected) async {
    setState(() {
      _screenOffTimeMenuOpen = false;
    });
    final seconds = int.tryParse(selected);
    if (seconds != null && seconds != widget.data.screenOffSeconds) {
      await _save(widget.data.copyWith(screenOffSeconds: seconds));
    }
  }

  bool get _hasOpenInlineMenu =>
      _timeFormatMenuOpen ||
      _clockMenuOpen ||
      _languageMenuOpen ||
      _brightnessMenuOpen ||
      _priorityMetricMenuOpen ||
      _indicatorLightBrightnessMenuOpen ||
      _screenOffTimeMenuOpen;

  void _closeInlineMenusInState() {
    _timeFormatMenuOpen = false;
    _clockMenuOpen = false;
    _languageMenuOpen = false;
    _brightnessMenuOpen = false;
    _priorityMetricMenuOpen = false;
    _indicatorLightBrightnessMenuOpen = false;
    _screenOffTimeMenuOpen = false;
  }

  Future<bool> _toggleAirQualityAutoDetection(bool enabled) {
    return _save(
      widget.data.copyWith(airQualityAutoDetectionEnabled: enabled),
    );
  }

  Future<bool> _toggleWifi(bool enabled) async {
    final manager = widget.wifiManager;
    if (manager == null) {
      return _save(
        enabled
            ? widget.data.copyWith(wifiEnabled: true)
            : widget.data.copyWith(
                wifiEnabled: false,
                clearWifiSsid: true,
                wifiConnected: false,
                wifiIpAddress: '',
                clearWifiConnectedSsid: true,
              ),
      );
    }
    final action = await manager.setEnabled(widget.data, enabled);
    if (!action.accepted) {
      return false;
    }
    final proposed = action.proposedSettings;
    final saved = proposed == null ? true : await _save(proposed);
    if (saved && !enabled) {
      _stopWifiScanLoop();
    }
    return saved;
  }

  bool _canScanWifi(DashboardData data) {
    final wifi = data.effectiveWifiState;
    return widget.wifiManager != null &&
        data.backendReachable &&
        wifi.available &&
        wifi.enabled;
  }

  bool _canOpenWifiDetail(DashboardData data) {
    final wifi = data.effectiveWifiState;
    return wifi.available && wifi.enabled;
  }

  /// 是否暂缓下一次扫描。
  ///
  /// 扫描只更新候选网络列表；连接/断开仍由后端 Wi-Fi 工作线程串行
  /// 执行。扫描中的页面仍允许用户选网，连接命令由后端顺序接管。
  bool get _wifiScanBlocked {
    return _wifiScanRequestInFlight ||
        _connectingWifiSsid != null ||
        const <String>{
          'scanning',
          'connecting',
          'disconnecting',
        }.contains(widget.data.effectiveWifiState.operation);
  }

  void _startWifiScanLoop() {
    _wifiScanTimer?.cancel();
    _wifiScanTimer = null;
    if (!_showNetworkDetail || !_canScanWifi(widget.data)) {
      return;
    }
    unawaited(_scanWifi());
  }

  void _stopWifiScanLoop() {
    _wifiScanTimer?.cancel();
    _wifiScanTimer = null;
  }

  void _scheduleNextWifiScan() {
    _wifiScanTimer?.cancel();
    _wifiScanTimer = null;
    if (!mounted || !_showNetworkDetail || !_canScanWifi(widget.data)) {
      return;
    }
    _wifiScanTimer = Timer(kWifiScanInterval, () {
      _wifiScanTimer = null;
      unawaited(_scanWifi());
    });
  }

  Future<void> _scanWifi() async {
    final manager = widget.wifiManager;
    if (manager == null || !_showNetworkDetail || !_canScanWifi(widget.data)) {
      return;
    }
    if (_saving || _wifiScanBlocked) {
      _scheduleNextWifiScan();
      return;
    }
    _wifiScanRequestInFlight = true;
    try {
      await manager.scan(widget.data);
    } finally {
      _wifiScanRequestInFlight = false;
      _scheduleNextWifiScan();
    }
  }

  Future<void> _selectWifi(String ssid) async {
    if (_connectingWifiSsid != null) {
      return;
    }
    final backendOnline = widget.data.backendReachable;
    final secured = !backendOnline ||
        widget.data.effectiveWifiState.securedSsids.contains(ssid);
    var showError = _wifiConnectionErrorSsid == ssid;
    var password = showError ? null : widget.data.savedWifiPasswordFor(ssid);
    if (!secured) {
      password = '';
    }
    while (mounted) {
      if (secured) {
        password ??= await _showWifiPasswordDialog(ssid, showError: showError);
      }
      if (password == null || !mounted) {
        return;
      }
      final connected = await _attemptWifiConnection(ssid, password);
      if (connected || !mounted) {
        return;
      }
      password = null;
      showError = true;
    }
  }

  Future<void> _disconnectWifi() async {
    if (_connectingWifiSsid != null) {
      return;
    }
    final manager = widget.wifiManager;
    if (manager == null) {
      final saved = await _save(
        widget.data.copyWith(
          clearWifiSsid: true,
          wifiConnected: false,
          wifiIpAddress: '',
          clearWifiConnectedSsid: true,
        ),
      );
      if (saved && mounted) {
        setState(() => _wifiConnectionErrorSsid = null);
      }
      return;
    }
    final action = await manager.disconnect(widget.data);
    if (!action.accepted) {
      return;
    }
    final proposed = action.proposedSettings;
    final saved = proposed == null ? true : await _save(proposed);
    if (saved && mounted) {
      setState(() => _wifiConnectionErrorSsid = null);
    }
  }

  Future<String?> _showWifiPasswordDialog(
    String ssid, {
    required bool showError,
  }) {
    return _showSettingsDialog<String>(
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (context) => _WifiPasswordDialog(
        ssid: ssid,
        showError: showError,
      ),
    );
  }

  Future<bool> _attemptWifiConnection(String ssid, String password) async {
    final wifi = widget.data.effectiveWifiState;
    if (widget.data.backendReachable &&
        wifi.available &&
        wifi.connected &&
        wifi.ssid == ssid) {
      // 密码弹窗打开期间可能已由模组或命令行连上同一网络。此时只展示
      // 最新实际状态，不重复连接，也不保存无法确认来源的输入密码。
      setState(() {
        _connectingWifiSsid = null;
        _connectingWifiPasswordLength = null;
        _wifiConnectionErrorSsid = null;
      });
      _notifyWifiConnectionLock();
      return true;
    }

    setState(() {
      _connectingWifiSsid = ssid;
      _connectingWifiPasswordLength = password.runes.length;
      _wifiConnectionErrorSsid = null;
    });
    _notifyWifiConnectionLock();
    final manager = widget.wifiManager;
    if (manager != null) {
      final action = await manager.connect(widget.data, ssid, password);
      if (!mounted) {
        return action.accepted;
      }
      if (!action.accepted) {
        setState(() {
          _connectingWifiSsid = null;
          _connectingWifiPasswordLength = null;
          _wifiConnectionErrorSsid = ssid;
        });
        _notifyWifiConnectionLock();
        return false;
      }
      final proposed = action.proposedSettings;
      final saved = proposed == null ? true : await _save(proposed);
      if (!mounted) {
        return saved;
      }
      if (proposed != null) {
        setState(() {
          _connectingWifiSsid = null;
          _connectingWifiPasswordLength = null;
          _wifiConnectionErrorSsid = saved ? null : ssid;
        });
        _notifyWifiConnectionLock();
      } else if (!action.awaitingConfirmation) {
        setState(() {
          _connectingWifiSsid = null;
          _connectingWifiPasswordLength = null;
          _wifiConnectionErrorSsid = null;
        });
        _notifyWifiConnectionLock();
      }
      return saved;
    }

    await Future<void>.delayed(_debugWifiConnectionDelay);
    if (!mounted) {
      return false;
    }

    // UI 联调桩：只有用户实际输入的 666666 判为连接成功。
    // 不预填、不显示，也不把空输入替换为调试密码。
    final connectionSucceeded = password == _defaultDebugWifiPassword;
    if (!connectionSucceeded) {
      setState(() {
        _connectingWifiSsid = null;
        _connectingWifiPasswordLength = null;
        _wifiConnectionErrorSsid = ssid;
      });
      _notifyWifiConnectionLock();
      return false;
    }

    final saved = await _save(
      widget.data.copyWith(
        wifiSsid: ssid,
        wifiConnected: true,
        savedWifiNetworks: widget.data.rememberSuccessfulWifi(ssid, password),
      ),
    );
    if (!mounted) {
      return saved;
    }
    setState(() {
      _connectingWifiSsid = null;
      _connectingWifiPasswordLength = null;
      _wifiConnectionErrorSsid = saved ? null : ssid;
    });
    _notifyWifiConnectionLock();
    return saved;
  }

  Future<bool> _toggleTimer(bool enabled) {
    return _save(widget.data.copyWith(timerEnabled: enabled));
  }

  Future<void> _selectTimerRange() async {
    final selected = await _showSettingsDialog<_TimeRangeValue>(
      builder: (context) => _TimeRangeDialog(
        startMinutes: widget.data.timerStartMinutes,
        endMinutes: widget.data.timerEndMinutes,
      ),
    );
    if (selected != null) {
      await _save(
        widget.data.copyWith(
          timerStartMinutes: selected.startMinutes,
          timerEndMinutes: selected.endMinutes,
        ),
      );
    }
  }

  Future<void> _selectRepeatDays() async {
    final selected = await _showSettingsDialog<List<int>>(
      builder: (context) => _RepeatDaysDialog(
        initialDays: widget.data.timerRepeatDays,
      ),
    );
    if (selected != null) {
      await _save(widget.data.copyWith(timerRepeatDays: selected));
    }
  }

  Future<void> _showUpdateResult() async {
    final status = widget.data.versionUpdateStatus;
    if (status == 'available') {
      final confirmed = await _showUpdateConfirmDialog();
      if (confirmed && mounted) {
        // 保存为 updating 状态，显示更新中弹窗。
        await _save(
          widget.data.copyWith(versionUpdateStatus: 'updating'),
        );
        if (!mounted) {
          return;
        }
        await _showUpdateInProgressDialog();
      }
    } else if (status == 'download_failed') {
      await _showUpdateFailedDialog();
    } else {
      await _showSettingsDialog<void>(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return _MessageDialog(
            title: l10n.checkUpdate,
            message: l10n.noUpdateMessage,
          );
        },
      );
    }
  }

  /// 显示版本更新确认弹窗。返回 true 表示用户点击了「立即更新」。
  Future<bool> _showUpdateConfirmDialog() async {
    final result = await _showSettingsDialog<bool>(
      barrierDismissible: false,
      barrierColor: const Color(0xA6000000),
      builder: (context) => const _VersionUpdateConfirmDialog(),
    );
    return result ?? false;
  }

  /// 显示更新进行中弹窗（请勿断电 + 加载动画）。
  Future<void> _showUpdateInProgressDialog() async {
    _inUpdateProgress = true;
    await _showSettingsDialog<void>(
      barrierDismissible: false,
      barrierColor: const Color(0xA6000000),
      builder: (context) => const _VersionUpdateProgressDialog(),
    );
    if (mounted) {
      _inUpdateProgress = false;
    }
  }

  /// 显示版本下载失败弹窗。
  Future<void> _showUpdateFailedDialog() async {
    await _showSettingsDialog<void>(
      barrierDismissible: false,
      barrierColor: const Color(0xA6000000),
      builder: (context) => const _VersionUpdateFailedDialog(),
    );
  }

  /// 设置页统一弹窗入口。
  ///
  /// 弹窗插入根导航器的 overlay，其本地化由全局根 locale 提供，
  /// 与页面自动保持一致，无需在此重复包裹 locale。
  Future<T?> _showSettingsDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (dialogContext) => Builder(builder: builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_engineeringModeActive) {
      return EngineeringModePage(
        key: ValueKey<String>('engineering-mode-$_engineeringEntrySerial'),
        engineeringPassword: widget.engineeringPassword,
        onEngineeringPasswordChanged: widget.onEngineeringPasswordChanged,
        persistentData: widget.persistentData,
        onSavePersistentConfiguration: widget.onSavePersistentConfiguration,
        onExit: _exitEngineeringMode,
      );
    }
    // 设置页本地化直接跟随全局根 locale，无需页面级 override。
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return PrototypePageChrome(
              prompt: _sectionIndex == 0 ? l10n.settingsBackHint : '',
              onBack: _handleBack,
              // Figma 69:4201：设置页返回控件和底线均比其它内页宽。
              backIconAsset: 'assets/navigation/common_back.png',
              backDividerAsset: 'assets/navigation/settings_back_line.png',
              backLeft: 146,
              backDividerWidth: 232,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 440,
                    top: 212,
                    child: _buildContent(),
                  ),
                  PrototypeSideMenu(
                    items: _buildMenuItems(l10n),
                    selectedIndex: _sectionIndex,
                    onSelected: _selectSection,
                    top: 254,
                    itemGap: 176,
                    dividerWidth: 232,
                  ),
                ],
              ),
            );
          },
        ),
        if (_wifiConnectionLockActive)
          const Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(color: Colors.transparent),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_sectionIndex == 1) {
      return _MaintenancePanel(
        remainingDays: <int>[
          widget.data.filter1RemainingDays,
          widget.data.filter2RemainingDays,
          widget.data.filter3RemainingDays,
        ],
        onReset: _showMaintenanceResetDialog,
      );
    }
    if (_sectionIndex == 2) {
      return _EngineeringPasswordPanel(
        password: widget.engineeringPassword,
        onAccepted: _enterEngineeringMode,
      );
    }
    if (_showNetworkDetail) {
      final connectingSsid = _wifiConnectionDisplaySsid;
      if (connectingSsid != null) {
        return _WifiConnectingPanel(
          ssid: connectingSsid,
          passwordLength: _connectingWifiPasswordLength,
        );
      }
      return _NetworkDetailPanel(
        wifi: widget.data.effectiveWifiState,
        connectingSsid: _connectingWifiSsid,
        connectionErrorSsid: _wifiConnectionErrorSsid,
        onSelectWifi: _selectWifi,
        onDisconnect: _disconnectWifi,
      );
    }
    return _SystemSettingsPanel(
      data: widget.data,
      versionText: _localVersion,
      timeFormatMenuOpen: _timeFormatMenuOpen,
      clockMenuOpen: _clockMenuOpen,
      languageMenuOpen: _languageMenuOpen,
      brightnessMenuOpen: _brightnessMenuOpen,
      priorityMetricMenuOpen: _priorityMetricMenuOpen,
      indicatorLightBrightnessMenuOpen: _indicatorLightBrightnessMenuOpen,
      screenOffTimeMenuOpen: _screenOffTimeMenuOpen,
      onTimeFormat: _toggleTimeFormatMenu,
      onTimeFormatSelected: _selectTimeFormat,
      onDate: _selectDate,
      onClock: _toggleClockMenu,
      onClockConfirmed: _confirmClock,
      onLanguage: _toggleLanguageMenu,
      onLanguageSelected: _selectLanguage,
      onBrightness: _toggleBrightnessMenu,
      onBrightnessChanged: _saveBrightness,
      onPriorityMetric: _togglePriorityMetricMenu,
      onPriorityMetricSelected: _selectPriorityMetric,
      onAqiIndicatorToggle: _toggleAqiIndicator,
      onPresenceRadarToggle: _togglePresenceRadar,
      onIndicatorLightBrightness: _toggleIndicatorLightBrightnessMenu,
      onIndicatorLightBrightnessSelected: _selectIndicatorLightBrightness,
      onScreenOffTime: _toggleScreenOffTimeMenu,
      onScreenOffTimeSelected: _selectScreenOffTime,
      onAirQualityAutoDetectionToggle: _toggleAirQualityAutoDetection,
      onWifiToggle: _toggleWifi,
      onWifiDetail: _canOpenWifiDetail(widget.data) ? _openNetworkDetail : null,
      onTimerToggle: _toggleTimer,
      onTimerRange: _selectTimerRange,
      onRepeatDays: _selectRepeatDays,
      onCheckUpdate: _showUpdateResult,
      versionUpdateStatus: widget.data.versionUpdateStatus,
      latestVersion: widget.data.latestVersion,
    );
  }
}

class _SystemSettingsPanel extends StatelessWidget {
  const _SystemSettingsPanel({
    required this.data,
    required this.versionText,
    required this.timeFormatMenuOpen,
    required this.clockMenuOpen,
    required this.languageMenuOpen,
    required this.brightnessMenuOpen,
    required this.priorityMetricMenuOpen,
    required this.indicatorLightBrightnessMenuOpen,
    required this.screenOffTimeMenuOpen,
    required this.onTimeFormat,
    required this.onTimeFormatSelected,
    required this.onDate,
    required this.onClock,
    required this.onClockConfirmed,
    required this.onLanguage,
    required this.onLanguageSelected,
    required this.onBrightness,
    required this.onBrightnessChanged,
    required this.onPriorityMetric,
    required this.onPriorityMetricSelected,
    required this.onAqiIndicatorToggle,
    required this.onPresenceRadarToggle,
    required this.onIndicatorLightBrightness,
    required this.onIndicatorLightBrightnessSelected,
    required this.onScreenOffTime,
    required this.onScreenOffTimeSelected,
    required this.onAirQualityAutoDetectionToggle,
    required this.onWifiToggle,
    required this.onWifiDetail,
    required this.onTimerToggle,
    required this.onTimerRange,
    required this.onRepeatDays,
    required this.onCheckUpdate,
    this.versionUpdateStatus = 'idle',
    this.latestVersion = '',
  });

  final DashboardData data;
  final String versionText;
  final bool timeFormatMenuOpen;
  final bool clockMenuOpen;
  final bool languageMenuOpen;
  final bool brightnessMenuOpen;
  final bool priorityMetricMenuOpen;
  final bool indicatorLightBrightnessMenuOpen;
  final bool screenOffTimeMenuOpen;
  final VoidCallback onTimeFormat;
  final ValueChanged<String> onTimeFormatSelected;
  final VoidCallback onDate;
  final VoidCallback onClock;
  final Future<bool> Function(_ClockSettingValue value) onClockConfirmed;
  final VoidCallback onLanguage;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onBrightness;
  final Future<bool> Function(int value) onBrightnessChanged;
  final VoidCallback onPriorityMetric;
  final ValueChanged<String> onPriorityMetricSelected;
  final Future<bool> Function(bool enabled) onAqiIndicatorToggle;
  final Future<bool> Function(bool enabled) onPresenceRadarToggle;
  final VoidCallback onIndicatorLightBrightness;
  final ValueChanged<String> onIndicatorLightBrightnessSelected;
  final VoidCallback onScreenOffTime;
  final ValueChanged<String> onScreenOffTimeSelected;
  final Future<bool> Function(bool enabled) onAirQualityAutoDetectionToggle;
  final Future<bool> Function(bool enabled) onWifiToggle;
  final VoidCallback? onWifiDetail;
  final Future<bool> Function(bool enabled) onTimerToggle;
  final VoidCallback onTimerRange;
  final VoidCallback onRepeatDays;
  final VoidCallback onCheckUpdate;
  final String versionUpdateStatus;
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    final wifi = data.effectiveWifiState;
    final l10n = AppLocalizations.of(context);
    // Figma 69:4156：1430×924；扩展信息通过纵向滚动展示。
    return Container(
      key: const ValueKey<String>('settings-system-main'),
      width: 1430,
      height: 924,
      decoration: const BoxDecoration(
        color: prototypePanel,
        image: DecorationImage(
          image: AssetImage('assets/settings/frame-bg2.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          key: const ValueKey<String>('settings-scroll-view'),
          child: SizedBox(
            height: 1996,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 248,
                  top: 24,
                  width: 882,
                  height: 2116,
                  child: Stack(
                    children: <Widget>[
                      _sectionTitle(l10n.generalSettings, 0),
                      _row(
                        keyName: 'time-format',
                        top: 0,
                        label: l10n.timeFormat,
                        value: data.timeFormat == '24h'
                            ? l10n.timeFormat24h
                            : l10n.timeFormat12h,
                        onTap: onTimeFormat,
                      ),
                      Positioned(
                        left: 306,
                        top: 88,
                        width: 576,
                        height: 88,
                        child: _DateTimeSettingRow(
                          keyName: 'date',
                          label: l10n.dateSetting,
                          placeholder: _formatDateSetting(data),
                          icon: Icons.calendar_month_outlined,
                          onTap: onDate,
                        ),
                      ),
                      Positioned(
                        left: 306,
                        top: 176,
                        width: 576,
                        height: 88,
                        child: _DateTimeSettingRow(
                          keyName: 'clock',
                          label: l10n.clockSetting,
                          placeholder: _formatClockSetting(data, l10n),
                          icon: Icons.schedule,
                          onTap: onClock,
                        ),
                      ),
                      _row(
                        keyName: 'language',
                        top: 264,
                        label: l10n.languageSelection,
                        value: _languageName(data.languageCode),
                        onTap: onLanguage,
                        fontFamily: _languageFontFamily(data.languageCode),
                      ),
                      _row(
                        keyName: 'brightness',
                        top: 352,
                        label: l10n.screenBrightness,
                        value: l10n.brightnessPercent(
                          data.effectiveScreenBrightnessPercent,
                        ),
                        onTap: onBrightness,
                      ),
                      _row(
                        keyName: 'priority-metric',
                        top: 440,
                        label: l10n.priorityMetric,
                        value: _priorityMetricName(data.priorityMetric, l10n),
                        onTap: onPriorityMetric,
                      ),
                      _toggleRow(
                        keyName: 'aqi-indicator-toggle',
                        top: 528,
                        label: l10n.aqiIndicator,
                        value: data.effectiveAqiIndicatorEnabled,
                        onChanged: onAqiIndicatorToggle,
                      ),
                      _row(
                        keyName: 'indicator-light-brightness',
                        top: 616,
                        label: l10n.indicatorLightBrightness,
                        value: data.indicatorLightBrightness == 'bright'
                            ? l10n.indicatorLightBright
                            : l10n.indicatorLightDark,
                        onTap: onIndicatorLightBrightness,
                      ),
                      _toggleRow(
                        keyName: 'presence-radar-toggle',
                        top: 704,
                        label: l10n.presenceRadar,
                        value: data.presenceRadarEnabled,
                        onChanged: onPresenceRadarToggle,
                      ),
                      _row(
                        keyName: 'screen-off-time',
                        top: 792,
                        label: l10n.screenOffTime,
                        value:
                            l10n.screenOffSecondsValue(data.screenOffSeconds),
                        onTap: onScreenOffTime,
                      ),
                      _toggleRow(
                        keyName: 'air-quality-auto-detection-toggle',
                        top: 880,
                        label: l10n.airQualityAutoDetection,
                        value: data.airQualityAutoDetectionEnabled,
                        onChanged: onAirQualityAutoDetectionToggle,
                      ),
                      _sectionTitle(l10n.networkSettings, 1040),
                      _toggleRow(
                        keyName: 'wifi-toggle',
                        top: 1040,
                        label: l10n.network,
                        value: wifi.enabled,
                        onChanged: onWifiToggle,
                      ),
                      _row(
                        keyName: 'wifi-detail',
                        top: 1128,
                        label: l10n.myNetwork,
                        value: wifi.connected ? wifi.ssid : l10n.notConnected,
                        onTap: onWifiDetail,
                        muted: onWifiDetail == null,
                      ),
                      _row(
                        keyName: 'wifi-ip-address',
                        top: 1216,
                        label: l10n.ipAddress,
                        value: wifi.ipAddress,
                        muted: onWifiDetail == null,
                      ),
                      _sectionTitle(l10n.timerSettings, 1360),
                      _toggleRow(
                        keyName: 'timer-toggle',
                        top: 1360,
                        label: l10n.timer,
                        value: data.timerEnabled,
                        onChanged: onTimerToggle,
                      ),
                      _row(
                        keyName: 'timer-range',
                        top: 1448,
                        label: l10n.timeRangeSetting,
                        value: l10n.timerRangeValue(
                          _formatMinutes(data.timerStartMinutes),
                          _formatMinutes(data.timerEndMinutes),
                        ),
                        onTap: onTimerRange,
                      ),
                      _row(
                        keyName: 'timer-repeat',
                        top: 1536,
                        label: l10n.repeatCycle,
                        value: _formatRepeatDays(data.timerRepeatDays, l10n),
                        onTap: onRepeatDays,
                      ),
                      _sectionTitle(l10n.systemInfo, 1680),
                      const Positioned(
                        left: 306,
                        top: 1680,
                        width: 576,
                        height: 88,
                        child: _SystemUptimeRow(days: 200),
                      ),
                      _row(
                        keyName: 'version',
                        top: 1768,
                        label: l10n.version,
                        value: versionText,
                        overflow: TextOverflow.clip,
                      ),
                      Positioned(
                        left: 306,
                        top: 1856,
                        width: 576,
                        height: 84,
                        child: _UpdateRow(
                          onTap: onCheckUpdate,
                          versionUpdateStatus: versionUpdateStatus,
                          latestVersion: latestVersion,
                        ),
                      ),
                    ],
                  ),
                ),
                if (timeFormatMenuOpen)
                  Positioned(
                    left: 1135,
                    top: 50,
                    child: _TimeFormatMenu(
                      selectedValue: data.timeFormat,
                      onSelected: onTimeFormatSelected,
                    ),
                  ),
                if (clockMenuOpen)
                  Positioned(
                    key: const ValueKey<String>(
                      'settings-clock-menu-position',
                    ),
                    left: 743,
                    top: 221,
                    child: _ClockSettingMenu(
                      hour: data.clockHour,
                      minute: data.clockMinute,
                      second: data.clockSecond,
                      timeFormat: data.timeFormat,
                      onConfirm: onClockConfirmed,
                    ),
                  ),
                if (languageMenuOpen)
                  Positioned(
                    left: 1135,
                    top: 317,
                    child: _LanguageMenu(
                      selectedValue: data.languageCode,
                      onSelected: onLanguageSelected,
                    ),
                  ),
                if (brightnessMenuOpen)
                  Positioned(
                    key: const ValueKey<String>(
                      'settings-brightness-menu-position',
                    ),
                    left: 1135,
                    top: 405,
                    child: _BrightnessMenu(
                      value: data.effectiveScreenBrightnessPercent,
                      onChanged: onBrightnessChanged,
                    ),
                  ),
                if (priorityMetricMenuOpen)
                  Positioned(
                    left: 1135,
                    top: 491,
                    child: _SettingsInlineChoiceMenu(
                      keyName: 'priority-metric',
                      selectedValue: data.priorityMetric,
                      options: <_SettingsChoice>[
                        _SettingsChoice('temperature', l10n.metricTemperature),
                        _SettingsChoice('humidity', l10n.metricHumidity),
                        _SettingsChoice('pm25', l10n.metricPm25),
                        _SettingsChoice('co2', l10n.metricCo2),
                        _SettingsChoice(
                            'formaldehyde', l10n.metricFormaldehyde),
                      ],
                      onSelected: onPriorityMetricSelected,
                    ),
                  ),
                if (indicatorLightBrightnessMenuOpen)
                  Positioned(
                    left: 1135,
                    top: 659,
                    child: _SettingsInlineChoiceMenu(
                      keyName: 'indicator-light-brightness',
                      selectedValue: data.indicatorLightBrightness,
                      options: <_SettingsChoice>[
                        _SettingsChoice('bright', l10n.indicatorLightBright),
                        _SettingsChoice('dark', l10n.indicatorLightDark),
                      ],
                      onSelected: onIndicatorLightBrightnessSelected,
                    ),
                  ),
                if (screenOffTimeMenuOpen)
                  Positioned(
                    left: 1135,
                    top: 835,
                    child: _SettingsInlineChoiceMenu(
                      keyName: 'screen-off-time',
                      selectedValue: data.screenOffSeconds.toString(),
                      options: <_SettingsChoice>[
                        _SettingsChoice('15', l10n.screenOffSecondsValue(15)),
                        _SettingsChoice('30', l10n.screenOffSecondsValue(30)),
                        _SettingsChoice('45', l10n.screenOffSecondsValue(45)),
                        _SettingsChoice('60', l10n.screenOffSecondsValue(60)),
                      ],
                      onSelected: onScreenOffTimeSelected,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Positioned _sectionTitle(String text, double top) {
    return Positioned(
      left: 0,
      top: top,
      width: 180,
      height: 56,
      child: Text(text, style: _sectionStyle),
    );
  }

  Positioned _row({
    required String keyName,
    required double top,
    required String label,
    required String value,
    VoidCallback? onTap,
    String fontFamily = AppFonts.sourceHanSansSc,
    bool muted = false,
    bool showArrowWhenMuted = true,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Positioned(
      left: 306,
      top: top,
      width: 576,
      height: 88,
      child: _SettingsRow(
        keyName: keyName,
        label: label,
        value: value,
        onTap: onTap,
        fontFamily: fontFamily,
        muted: muted,
        showArrowWhenMuted: showArrowWhenMuted,
        overflow: overflow,
      ),
    );
  }

  Positioned _toggleRow({
    required String keyName,
    required double top,
    required String label,
    required bool value,
    required Future<bool> Function(bool enabled) onChanged,
  }) {
    return Positioned(
      left: 306,
      top: top,
      width: 576,
      height: 88,
      child: _SettingsToggleRow(
        keyName: keyName,
        label: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.keyName,
    required this.label,
    required this.value,
    this.onTap,
    this.fontFamily = AppFonts.sourceHanSansSc,
    this.muted = false,
    this.showArrowWhenMuted = true,
    this.overflow = TextOverflow.ellipsis,
  });

  final String keyName;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String fontFamily;
  final bool muted;
  final bool showArrowWhenMuted;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final showArrow = enabled || (muted && showArrowWhenMuted);
    return GestureDetector(
      key: ValueKey<String>('settings-row-$keyName'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned(
            key: ValueKey<String>('settings-row-$keyName-label-position'),
            left: 24,
            top: 18,
            child: Text(
              key: ValueKey<String>('settings-row-$keyName-label'),
              label,
              style: _rowLabelStyle.copyWith(
                fontFamily: fontFamily,
                color: muted
                    ? const Color(0x4DFFFFFF)
                    : enabled
                        ? const Color(0xB3FFFFFF)
                        : const Color(0x99FFFFFF),
              ),
            ),
          ),
          Positioned(
            key: ValueKey<String>('settings-row-$keyName-value-position'),
            right: showArrow ? 69 : 24,
            top: 18,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Text(
                key: ValueKey<String>('settings-row-$keyName-value'),
                value,
                maxLines: 1,
                overflow: overflow,
                textAlign: TextAlign.right,
                style: _rowValueStyle.copyWith(
                  fontFamily: fontFamily,
                  color: muted ? const Color(0x4DFFFFFF) : Colors.white,
                ),
              ),
            ),
          ),
          if (showArrow)
            Positioned(
              key: ValueKey<String>('settings-row-$keyName-arrow-position'),
              right: 24,
              top: 28,
              width: 13,
              height: 24,
              child: Opacity(
                key: ValueKey<String>('settings-row-$keyName-arrow'),
                opacity: muted ? 0.3 : 1,
                child: Image.asset('assets/settings/next.png'),
              ),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _DateTimeSettingRow extends StatelessWidget {
  const _DateTimeSettingRow({
    required this.keyName,
    required this.label,
    required this.placeholder,
    required this.icon,
    this.onTap,
  });

  final String keyName;
  final String label;
  final String placeholder;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('settings-row-$keyName'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 24,
            top: 15,
            child: Text(label, style: _rowLabelStyle),
          ),
          Positioned(
            right: 24,
            top: 18,
            width: 364,
            height: 48,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        placeholder,
                        style: _dateTimePlaceholderStyle,
                      ),
                    ),
                    Icon(icon, size: 25, color: const Color(0xFF9A9A9A)),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _SystemUptimeRow extends StatelessWidget {
  const _SystemUptimeRow({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      key: const ValueKey<String>('settings-row-system-uptime'),
      children: <Widget>[
        Positioned(
          right: 24,
          top: 15,
          child: Text.rich(
            TextSpan(
              style: _rowValueStyle,
              children: <InlineSpan>[
                TextSpan(text: l10n.systemUptimePrefix),
                TextSpan(
                  text: '$days',
                  style: const TextStyle(color: Color(0xFF48C900)),
                ),
                TextSpan(text: l10n.systemUptimeSuffix),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }
}

class _SettingsToggleRow extends StatefulWidget {
  const _SettingsToggleRow({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final bool value;
  final Future<bool> Function(bool enabled) onChanged;

  @override
  State<_SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<_SettingsToggleRow> {
  late bool _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SettingsToggleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  Future<void> _toggle() async {
    if (_saving) {
      return;
    }
    final next = !_value;
    setState(() {
      _value = next;
      _saving = true;
    });
    var saved = false;
    try {
      saved = await widget.onChanged(next);
    } on Object catch (_) {
      // The row owns the optimistic state. Any write exception is treated as
      // a failed toggle so the switch rolls back and is not left locked.
      saved = false;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (!saved) {
        _value = !next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('settings-row-${widget.keyName}'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 24,
            top: 15,
            child: Text(widget.label, style: _rowLabelStyle),
          ),
          Positioned(
            right: 24,
            top: 16,
            width: 96,
            height: 48,
            child: Image.asset(
              _value
                  ? 'assets/settings/toggle-button-on.png'
                  : 'assets/settings/toggle-button-off.png',
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.onTap,
    this.versionUpdateStatus = 'idle',
    this.latestVersion = '',
  });

  final VoidCallback onTap;
  final String versionUpdateStatus;
  final String latestVersion;

  bool get _isUpdateAvailable => versionUpdateStatus == 'available';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttonColor =
        _isUpdateAvailable ? const Color(0xFF42CEEA) : const Color(0xFFA5A5A5);
    return Stack(
      children: <Widget>[
        Positioned(
          left: 24,
          top: 15,
          child: Text(l10n.checkUpdate, style: _rowLabelStyle),
        ),
        Positioned(
          right: 24,
          top: 16,
          child: GestureDetector(
            key: const ValueKey<String>('settings-check-update'),
            onTap: onTap,
            child: Container(
              width: 96,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                l10n.update,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }
}

class _WifiConnectingPanel extends StatelessWidget {
  const _WifiConnectingPanel({
    required this.ssid,
    required this.passwordLength,
  });

  final String ssid;
  final int? passwordLength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mask = passwordLength == null || passwordLength! <= 0
        ? ''
        : List<String>.filled(passwordLength!, '*').join('  ');
    return Container(
      key: const ValueKey<String>('settings-wifi-connecting'),
      width: 1430,
      height: 924,
      decoration: const BoxDecoration(
        color: prototypePanel,
        image: DecorationImage(
          image: AssetImage('assets/settings/frame-bg2.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 330,
            top: 190,
            width: 850,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: l10n.wifiConnectingPrefix),
                  TextSpan(text: '“$ssid”'),
                  TextSpan(text: l10n.wifiConnectingSuffix),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _wifiConnectingTitleStyle,
            ),
          ),
          Positioned(
            left: 330,
            top: 320,
            width: 820,
            height: 74,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 8,
                  right: 90,
                  top: 8,
                  child: Text(
                    mask,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: _wifiConnectingPasswordStyle,
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 12,
                  child: Opacity(
                    opacity: 0.35,
                    child: SizedBox(
                      width: 40,
                      height: 30,
                      child: Image.asset(
                        'assets/settings/pw-hide.png',
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x66585B5E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkDetailPanel extends StatelessWidget {
  const _NetworkDetailPanel({
    required this.wifi,
    required this.connectingSsid,
    required this.connectionErrorSsid,
    required this.onSelectWifi,
    required this.onDisconnect,
  });

  final DashboardWifiState wifi;
  final String? connectingSsid;
  final String? connectionErrorSsid;
  final ValueChanged<String> onSelectWifi;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otherNetworks = wifi.availableSsids
        .where((ssid) => ssid != wifi.ssid)
        .toList(growable: false);
    return Container(
      key: const ValueKey<String>('settings-network-detail'),
      width: 1430,
      height: 924,
      decoration: const BoxDecoration(
        color: prototypePanel,
        image: DecorationImage(
          image: AssetImage('assets/settings/frame-bg2.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 248,
            top: 35,
            child: Text(l10n.currentNetwork, style: _sectionStyle),
          ),
          Positioned(
            left: 554,
            top: 28,
            width: 576,
            height: 88,
            child: _CurrentWifiRow(
              wifi: wifi,
              onDisconnect: onDisconnect,
            ),
          ),
          Positioned(
            left: 554,
            top: 116,
            width: 576,
            height: 88,
            child: _NetworkInfoRow(
              label: l10n.ipAddress,
              value: wifi.ipAddress,
            ),
          ),
          Positioned(
            left: 248,
            top: 235,
            child: Text(l10n.otherNetworks, style: _sectionStyle),
          ),
          Positioned(
            left: 554,
            top: 220,
            width: 576,
            height: 704,
            // 与系统设置长内容相同：标题和当前网络固定，只有可用网络列表上下滑动。
            child: Scrollbar(
              child: SingleChildScrollView(
                key: const ValueKey<String>('settings-wifi-scroll-view'),
                child: SizedBox(
                  height: otherNetworks.length * 88.0,
                  child: Stack(
                    children: <Widget>[
                      for (var index = 0; index < otherNetworks.length; index++)
                        Positioned(
                          top: index * 88,
                          width: 576,
                          height: 88,
                          child: _AvailableWifiRow(
                            ssid: otherNetworks[index],
                            statusText: connectingSsid == otherNetworks[index]
                                ? l10n.connecting
                                : connectionErrorSsid == otherNetworks[index]
                                    ? l10n.connectionFailed
                                    : null,
                            isConnecting:
                                connectingSsid == otherNetworks[index],
                            onTap: connectingSsid == null
                                ? () => onSelectWifi(otherNetworks[index])
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentWifiRow extends StatelessWidget {
  const _CurrentWifiRow({
    required this.wifi,
    required this.onDisconnect,
  });

  final DashboardWifiState wifi;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: <Widget>[
        Positioned(
          left: 14,
          top: 15,
          child: wifi.connected
              ? Row(
                  children: <Widget>[
                    const Image(
                      image: AssetImage('assets/settings/check.png'),
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      wifi.ssid,
                      style: _rowValueStyle.copyWith(color: prototypeCyan),
                    ),
                  ],
                )
              : Text(
                  l10n.notConnected,
                  style: _rowValueStyle.copyWith(
                    color: const Color(0xB3FFFFFF),
                  ),
                ),
        ),
        if (wifi.connected)
          Positioned(
            right: 24,
            top: 12,
            child: GestureDetector(
              key: const ValueKey<String>('settings-wifi-disconnect'),
              onTap: onDisconnect,
              child: Container(
                width: 96,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: prototypeCyan,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(l10n.disconnect, style: _smallButtonStyle),
              ),
            ),
          ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }
}

class _NetworkInfoRow extends StatelessWidget {
  const _NetworkInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
            left: 24, top: 15, child: Text(label, style: _rowLabelStyle)),
        Positioned(
          right: 24,
          top: 15,
          child: Text(value, style: _rowValueStyle),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }
}

class _AvailableWifiRow extends StatelessWidget {
  const _AvailableWifiRow({
    required this.ssid,
    required this.statusText,
    required this.isConnecting,
    required this.onTap,
  });

  final String ssid;
  final String? statusText;
  // 状态颜色不能依赖本地化文案，需由调用方显式传入连接中标记。
  final bool isConnecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('settings-wifi-$ssid'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned(
              left: 48, top: 15, child: Text(ssid, style: _rowValueStyle)),
          if (statusText == null)
            Positioned(
              right: 24,
              top: 28,
              width: 15,
              height: 26,
              child: Image.asset('assets/settings/next.png'),
            )
          else
            Positioned(
              right: 24,
              top: 15,
              child: Text(
                statusText!,
                key: ValueKey<String>('settings-wifi-status-$ssid'),
                style: _rowLabelStyle.copyWith(
                  color: isConnecting ? prototypeCyan : const Color(0xFFE06B6B),
                ),
              ),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _WifiPasswordDialog extends StatefulWidget {
  const _WifiPasswordDialog({
    required this.ssid,
    required this.showError,
  });

  final String ssid;
  final bool showError;

  @override
  State<_WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<_WifiPasswordDialog> {
  late String _password;
  bool _showPassword = true;

  @override
  void initState() {
    super.initState();
    // 每次进入都从空输入开始。调试密码仅在连接桩中判断，不能预填或隐式代入。
    _password = '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visiblePassword = _showPassword
        ? _password
        : List<String>.filled(_password.length, '*').join(' ');
    return Dialog(
      key: const ValueKey<String>('settings-wifi-password-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1240,
        height: 820,
        padding: const EdgeInsets.fromLTRB(78, 45, 77, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF18191B),
          border: Border.all(color: const Color(0xFF55585B)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.ssid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _dialogTitleStyle,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Text(
                      l10n.enterPassword,
                      style: _engineeringPasswordTitleStyle,
                    ),
                  ),
                  if (widget.showError)
                    Positioned(
                      left: 244,
                      top: 5,
                      child: Text(
                        l10n.passwordError,
                        style: _engineeringPasswordErrorStyle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 1085,
              height: 74,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 8,
                    right: 90,
                    top: 8,
                    child: Transform.translate(
                      key: const ValueKey<String>(
                        'settings-wifi-password-mask-position',
                      ),
                      // 圆点的字面框视觉重心偏上；仅密文模式下移，
                      // 明文基线、下划线与眼睛坐标保持设计稿原值。
                      offset: Offset(0, _showPassword ? 0 : 7),
                      child: Text(
                        visiblePassword,
                        key: const ValueKey<String>(
                            'settings-wifi-password-value'),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: _wifiPasswordValueStyle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 12,
                    child: GestureDetector(
                      key: const ValueKey<String>('settings-wifi-password-eye'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _showPassword = !_showPassword),
                      child: SizedBox(
                        width: 40,
                        height: 30,
                        child: Image.asset(
                          _showPassword
                              ? 'assets/settings/pw-show.png'
                              : 'assets/settings/pw-hide.png',
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFF8A8D90),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            TouchPasswordKeyboard(
              initialValue: _password,
              maxLength: 64,
              onChanged: (value) => setState(() => _password = value),
              onConfirm: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeGlyphPainter extends CustomPainter {
  const _EyeGlyphPainter({required this.open});

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 35,
      height: 21,
    );
    canvas.drawOval(rect, paint);
    canvas.drawCircle(rect.center, 5, paint);
    if (!open) {
      canvas.drawLine(
        Offset(rect.left - 2, rect.bottom + 2),
        Offset(rect.right + 2, rect.top - 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EyeGlyphPainter oldDelegate) =>
      oldDelegate.open != open;
}

class _SettingsChoice {
  const _SettingsChoice(this.value, this.label);

  final String value;
  final String label;
}

/// Figma 系统设置下拉卡片：235 宽、单项 56 高，选中项显示青色勾选。
class _SettingsInlineChoiceMenu extends StatelessWidget {
  const _SettingsInlineChoiceMenu({
    required this.keyName,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  final String keyName;
  final String selectedValue;
  final List<_SettingsChoice> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('settings-$keyName-menu'),
      width: 235,
      height: options.length * 56,
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < options.length; index++)
            _option(options[index], index * 56),
          for (var index = 1; index < options.length; index++)
            Positioned(
              left: 17,
              top: index * 56,
              width: 200,
              height: 0.5,
              child: const ColoredBox(color: Color(0x80FFFFFF)),
            ),
        ],
      ),
    );
  }

  Widget _option(_SettingsChoice option, double top) {
    final selected = option.value == selectedValue;
    return Positioned(
      top: top,
      width: 235,
      height: 56,
      child: GestureDetector(
        key: ValueKey<String>('settings-choice-${option.value}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(option.value),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? prototypeCyan : Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 32,
                  height: 1.448,
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 193,
                top: 20,
                width: 24,
                height: 18,
                child: Image(
                  image: AssetImage('assets/settings/check.png'),
                  fit: BoxFit.fill,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Figma `设置-系统设置（时间格式弹窗）`：页面内锚定的小型选择卡片。
///
/// 尺寸、文字与选中标记采用时间格式画板；半透明背景和叠层方式沿用
/// 历史趋势周期选择器，不进入通用居中 Dialog。
class _TimeFormatMenu extends StatelessWidget {
  const _TimeFormatMenu({
    required this.selectedValue,
    required this.onSelected,
  });

  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('settings-time-format-menu'),
      width: 235,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          _option(
            value: '12h',
            label: l10n.timeFormat12h,
            top: 0,
          ),
          _option(
            value: '24h',
            label: l10n.timeFormat24h,
            top: 56,
          ),
          const Positioned(
            left: 17,
            top: 56,
            width: 200,
            height: 0.5,
            child: ColoredBox(color: Color(0x80FFFFFF)),
          ),
        ],
      ),
    );
  }

  Widget _option({
    required String value,
    required String label,
    required double top,
  }) {
    final selected = value == selectedValue;
    return Positioned(
      top: top,
      width: 235,
      height: 56,
      child: GestureDetector(
        key: ValueKey<String>('settings-choice-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(value),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 67,
              top: 3,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? prototypeCyan : Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 32,
                  height: 1.448,
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 193,
                top: 20,
                width: 24,
                height: 18,
                child: Image(
                  image: AssetImage('assets/settings/check.png'),
                  fit: BoxFit.fill,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Figma `设置-系统设置（语言选择弹窗）`：语言名称使用各自语言显示。
class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.selectedValue,
    required this.onSelected,
  });

  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('settings-language-menu'),
      width: 235,
      height: 168,
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          _option(
            value: 'zh_CN',
            label: '简体中文',
            top: 0,
            fontFamily: AppFonts.sourceHanSansSc,
          ),
          _option(
            value: 'en_US',
            label: 'English',
            top: 56,
            fontFamily: AppFonts.sourceHanSansSc,
          ),
          _option(
            value: 'ja_JP',
            label: '日本語',
            top: 112,
            fontFamily: AppFonts.sourceHanSansSc,
          ),
          for (final top in <double>[56, 112])
            Positioned(
              left: 17,
              top: top,
              width: 200,
              height: 0.5,
              child: const ColoredBox(color: Color(0x80FFFFFF)),
            ),
        ],
      ),
    );
  }

  Widget _option({
    required String value,
    required String label,
    required double top,
    required String fontFamily,
  }) {
    final selected = value == selectedValue;
    return Positioned(
      top: top,
      width: 235,
      height: 56,
      child: GestureDetector(
        key: ValueKey<String>('settings-choice-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(value),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? prototypeCyan : Colors.white,
                  fontFamily: fontFamily,
                  fontVariations: fontFamily == AppFonts.harmonyRegular
                      ? null
                      : AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 32,
                  height: 1.448,
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 193,
                top: 20,
                width: 24,
                height: 18,
                child: Image(
                  image: AssetImage('assets/settings/check.png'),
                  fit: BoxFit.fill,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClockSettingValue {
  const _ClockSettingValue({
    required this.hour,
    required this.minute,
    required this.second,
    this.isAm = true,
  });

  final int hour;
  final int minute;
  final int second;
  final bool isAm;
}

class _ClockSettingMenu extends StatefulWidget {
  const _ClockSettingMenu({
    required this.hour,
    required this.minute,
    required this.second,
    required this.timeFormat,
    required this.onConfirm,
  });

  final int hour;
  final int minute;
  final int second;
  final String timeFormat;
  final Future<bool> Function(_ClockSettingValue value) onConfirm;

  @override
  State<_ClockSettingMenu> createState() => _ClockSettingMenuState();
}

class _ClockSettingMenuState extends State<_ClockSettingMenu> {
  late int _hour;
  late int _minute;
  late int _second;
  late bool _isAm;
  bool _saving = false;

  bool get _is12h => widget.timeFormat == '12h';

  @override
  void initState() {
    super.initState();
    _readWidgetValue();
  }

  @override
  void didUpdateWidget(covariant _ClockSettingMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving &&
        (widget.hour != oldWidget.hour ||
            widget.minute != oldWidget.minute ||
            widget.second != oldWidget.second)) {
      _readWidgetValue();
    }
  }

  void _readWidgetValue() {
    _hour = widget.hour;
    _minute = widget.minute;
    _second = widget.second;
    _isAm = widget.hour < 12;
  }

  int get _displayHour {
    if (!_is12h) return _hour;
    final h12 = _hour % 12;
    return h12 == 0 ? 12 : h12;
  }

  Future<void> _confirm() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final hour24 =
        _is12h ? (_isAm ? _displayHour % 12 : (_displayHour % 12) + 12) : _hour;
    final saved = await widget.onConfirm(
      _ClockSettingValue(
          hour: hour24, minute: _minute, second: _second, isAm: _isAm),
    );
    if (mounted && !saved) {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final is12h = _is12h;
    return Container(
      key: const ValueKey<String>('settings-clock-menu'),
      width: 363,
      height: 372,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          // Headers: only for hour/minute/second (no AM/PM header per Figma).
          if (!is12h) ...[
            Positioned(
              left: 46,
              top: 12,
              child: Text(l10n.clockHourHand, style: _clockHeaderStyle),
            ),
          ] else ...[
            Positioned(
              left: 112,
              top: 12,
              child: Text(l10n.clockHourHand, style: _clockHeaderStyle),
            ),
          ],
          Positioned(
            left: 157,
            top: 12,
            child: Text(l10n.clockMinuteHand, style: _clockHeaderStyle),
          ),
          Positioned(
            left: 269,
            top: 12,
            child: Text(l10n.clockSecondHand, style: _clockHeaderStyle),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 55,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE9EDF2),
            ),
          ),
          // Blue selection rectangles.
          if (is12h) ...[
            // 4 columns: AM/PM (31), Hour (110), Minute (190), Second (270)
            for (final left in <double>[31, 110, 190, 270])
              Positioned(
                left: left,
                top: 169,
                width: 49,
                height: 33,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF25AEF3),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
          ] else ...[
            for (final left in <double>[24, 135, 247])
              Positioned(
                left: left,
                top: 169,
                width: 93,
                height: 33,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF25AEF3),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
          ],
          // Wheels
          if (is12h) ...[
            // AM/PM wheel
            Positioned(
              left: 31,
              top: 76,
              width: 49,
              height: 219,
              child: _AmPmWheel(
                isAm: _isAm,
                interactionEnabled: !_saving,
                onChanged: (am) => setState(() => _isAm = am),
              ),
            ),
            // Hour wheel (1-12)
            Positioned(
              left: 110,
              top: 76,
              width: 49,
              height: 219,
              child: _ClockValueWheel(
                keyName: 'hour',
                value: _displayHour - 1,
                minimum: 0,
                itemCount: 12,
                interactionEnabled: !_saving,
                labelBuilder: (index) => '${index + 1}',
                onChanged: (value) => setState(() {
                  final displayH = value + 1;
                  _hour = _isAm ? displayH % 12 : (displayH % 12) + 12;
                }),
              ),
            ),
          ] else ...[
            // Hour wheel (0-23) — existing layout
            Positioned(
              left: 24,
              top: 76,
              width: 93,
              height: 219,
              child: _ClockValueWheel(
                keyName: 'hour',
                value: _hour,
                minimum: 0,
                itemCount: 24,
                interactionEnabled: !_saving,
                onChanged: (value) => setState(() => _hour = value),
              ),
            ),
          ],
          // Minute wheel
          Positioned(
            left: is12h ? 190 : 135,
            top: 76,
            width: is12h ? 49 : 93,
            height: 219,
            child: _ClockValueWheel(
              keyName: 'minute',
              value: _minute,
              minimum: 0,
              itemCount: 60,
              interactionEnabled: !_saving,
              onChanged: (value) => setState(() => _minute = value),
            ),
          ),
          // Second wheel
          Positioned(
            left: is12h ? 270 : 247,
            top: 76,
            width: is12h ? 49 : 93,
            height: 219,
            child: _ClockValueWheel(
              keyName: 'second',
              value: _second,
              minimum: 0,
              itemCount: 60,
              interactionEnabled: !_saving,
              onChanged: (value) => setState(() => _second = value),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 321,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE9EDF2),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 321,
            height: 51,
            child: GestureDetector(
              key: const ValueKey<String>('settings-clock-confirm'),
              behavior: HitTestBehavior.opaque,
              onTap: _saving ? null : () => unawaited(_confirm()),
              child: Center(
                child: Text(l10n.confirm, style: _clockConfirmStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockValueWheel extends StatefulWidget {
  const _ClockValueWheel({
    required this.keyName,
    required this.value,
    required this.minimum,
    required this.itemCount,
    required this.interactionEnabled,
    required this.onChanged,
    this.labelBuilder,
  });

  final String keyName;
  final int value;
  final int minimum;
  final int itemCount;
  final bool interactionEnabled;
  final ValueChanged<int> onChanged;
  final String Function(int index)? labelBuilder;

  @override
  State<_ClockValueWheel> createState() => _ClockValueWheelState();
}

class _ClockValueWheelState extends State<_ClockValueWheel> {
  static const double _itemExtent = 31;
  static const int _initialCycle = 100;
  late FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _controller = FixedExtentScrollController(
      initialItem: _indexForValue(_selected),
    );
  }

  @override
  void didUpdateWidget(covariant _ClockValueWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _selected) {
      _selected = widget.value;
      if (_controller.hasClients) {
        _controller.jumpToItem(_indexForValue(_selected));
      }
    }
  }

  int _indexForValue(int value) {
    return widget.itemCount * _initialCycle + value - widget.minimum;
  }

  int _valueForIndex(int index) {
    return widget.minimum + index % widget.itemCount;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      key: ValueKey<String>('settings-clock-${widget.keyName}-wheel'),
      controller: _controller,
      physics: widget.interactionEnabled
          ? const FixedExtentScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemExtent: _itemExtent,
      diameterRatio: 100,
      perspective: 0.0001,
      squeeze: 1,
      overAndUnderCenterOpacity: 1,
      onSelectedItemChanged: (index) {
        if (!widget.interactionEnabled) {
          return;
        }
        final value = _valueForIndex(index);
        if (value == _selected) {
          return;
        }
        setState(() {
          _selected = value;
        });
        widget.onChanged(value);
      },
      childDelegate: ListWheelChildLoopingListDelegate(
        children: List<Widget>.generate(widget.itemCount, (index) {
          final value = widget.minimum + index;
          final selected = value == _selected;
          final label = widget.labelBuilder != null
              ? widget.labelBuilder!(index)
              : value.toString().padLeft(2, '0');
          return Center(
            child: Text(
              label,
              style: selected ? _clockSelectedValueStyle : _clockValueStyle,
            ),
          );
        }),
      ),
    );
  }
}

/// AM/PM scroll wheel for the 12-hour clock setting.
class _AmPmWheel extends StatefulWidget {
  const _AmPmWheel({
    required this.isAm,
    required this.interactionEnabled,
    required this.onChanged,
  });

  final bool isAm;
  final bool interactionEnabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_AmPmWheel> createState() => _AmPmWheelState();
}

class _AmPmWheelState extends State<_AmPmWheel> {
  static const double _itemExtent = 31;
  late FixedExtentScrollController _controller;
  late bool _isAm;

  @override
  void initState() {
    super.initState();
    _isAm = widget.isAm;
    _controller = FixedExtentScrollController(
      initialItem: _isAm ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(covariant _AmPmWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAm != _isAm) {
      _isAm = widget.isAm;
      if (_controller.hasClients) {
        _controller.jumpToItem(_isAm ? 0 : 1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListWheelScrollView.useDelegate(
      key: const ValueKey<String>('settings-clock-ampm-wheel'),
      controller: _controller,
      physics: widget.interactionEnabled
          ? const FixedExtentScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemExtent: _itemExtent,
      diameterRatio: 100,
      perspective: 0.0001,
      squeeze: 1,
      overAndUnderCenterOpacity: 1,
      onSelectedItemChanged: (index) {
        if (!widget.interactionEnabled) {
          return;
        }
        final am = index == 0;
        if (am == _isAm) {
          return;
        }
        setState(() {
          _isAm = am;
        });
        widget.onChanged(am);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 2,
        builder: (context, index) {
          final selected = (index == 0) == _isAm;
          return Center(
            child: Text(
              index == 0 ? l10n.am : l10n.pm,
              style: selected ? _clockSelectedValueStyle : _clockValueStyle,
            ),
          );
        },
      ),
    );
  }
}

class _BrightnessMenu extends StatefulWidget {
  const _BrightnessMenu({required this.value, required this.onChanged});

  final int value;
  final Future<bool> Function(int value) onChanged;

  @override
  State<_BrightnessMenu> createState() => _BrightnessMenuState();
}

class _BrightnessMenuState extends State<_BrightnessMenu> {
  late int _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _BrightnessMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  void _update(double localX) {
    final next = ((localX / 250) * 100).round().clamp(0, 100).toInt();
    if (next != _value) {
      setState(() {
        _value = next;
      });
    }
  }

  Future<void> _commit() async {
    if (_saving) {
      return;
    }
    final committedValue = _value;
    setState(() {
      _saving = true;
    });
    final saved = await widget.onChanged(committedValue);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (!saved) {
        _value = widget.value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('settings-brightness-menu'),
      width: 282,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 15,
            top: 8,
            child: Text(
              AppLocalizations.of(context).brightness,
              style: _brightnessLabelStyle,
            ),
          ),
          Positioned(
            right: 19,
            top: 8,
            child: Text('$_value%', style: _brightnessValueStyle),
          ),
          Positioned(
            left: 15,
            top: 44,
            width: 250,
            height: 30,
            child: GestureDetector(
              key: const ValueKey<String>('settings-brightness-slider'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _update(details.localPosition.dx),
              onTapUp: (_) => unawaited(_commit()),
              onHorizontalDragStart: (details) =>
                  _update(details.localPosition.dx),
              onHorizontalDragUpdate: (details) =>
                  _update(details.localPosition.dx),
              onHorizontalDragEnd: (_) => unawaited(_commit()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFA8A8A8)),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 250 * _value / 100,
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeValue {
  const _TimeRangeValue(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;
}

class _TimeRangeDialog extends StatefulWidget {
  const _TimeRangeDialog({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  @override
  State<_TimeRangeDialog> createState() => _TimeRangeDialogState();
}

class _TimeRangeDialogState extends State<_TimeRangeDialog> {
  late int _startSlot;
  late int _endSlot;

  @override
  void initState() {
    super.initState();
    _startSlot = (widget.startMinutes / 30).round().clamp(0, 47).toInt();
    _endSlot = (widget.endMinutes / 30).round().clamp(0, 47).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DialogShell(
      keyName: 'settings-time-range-dialog',
      title: l10n.timeRangeSetting,
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TimeSlotRow(
              keyName: 'start',
              label: l10n.start,
              value: _startSlot,
              onChanged: (value) => setState(() => _startSlot = value),
            ),
            _TimeSlotRow(
              keyName: 'end',
              label: l10n.end,
              value: _endSlot,
              onChanged: (value) => setState(() => _endSlot = value),
            ),
            _DialogActions(
              onConfirm: () => Navigator.of(context).pop(
                _TimeRangeValue(_startSlot * 30, _endSlot * 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Row(
        children: <Widget>[
          Text(label, style: _dialogTouchOptionStyle),
          const Spacer(),
          SizedBox(
            width: 300,
            height: 96,
            child: Theme(
              // 触摸屏点击时间项只改变值，不显示跟随点击的焦点框、悬停块
              // 或按下底色；文字仍沿用当前对话框主题色。
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: DropdownButton<int>(
                key: ValueKey<String>('settings-time-slot-$keyName'),
                value: value,
                isExpanded: true,
                itemHeight: 96,
                dropdownColor: prototypePanel,
                focusColor: Colors.transparent,
                style: _dialogTouchOptionStyle,
                items: List<DropdownMenuItem<int>>.generate(
                  48,
                  (slot) => DropdownMenuItem<int>(
                    key: ValueKey<String>('settings-time-option-$slot'),
                    value: slot,
                    child: SizedBox(
                      height: 96,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_formatMinutes(slot * 30)),
                      ),
                    ),
                  ),
                ),
                onChanged: (next) {
                  if (next != null) {
                    onChanged(next);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepeatDaysDialog extends StatefulWidget {
  const _RepeatDaysDialog({required this.initialDays});

  final List<int> initialDays;

  @override
  State<_RepeatDaysDialog> createState() => _RepeatDaysDialogState();
}

class _RepeatDaysDialogState extends State<_RepeatDaysDialog> {
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <String>[
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];
    return _DialogShell(
      keyName: 'settings-repeat-dialog',
      title: l10n.repeatCycle,
      child: SizedBox(
        // 七个加大的星期按钮仍保持一行，避免“周日”换行。
        width: 960,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              spacing: 12,
              children: List<Widget>.generate(7, (index) {
                final day = index + 1;
                final selected = _days.contains(day);
                return SizedBox(
                  // 不使用会按内容收缩的 ChoiceChip：按钮本体和热区同尺寸。
                  // 1920×1200 设计坐标缩放到 800×500 时约为 50×40 实际像素。
                  width: 120,
                  height: 96,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: labels[index],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          selected ? _days.remove(day) : _days.add(day);
                        });
                      },
                      child: Container(
                        key: ValueKey<String>('settings-repeat-day-$day'),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? prototypeCyan
                              : const Color(0xFF4B4B4B),
                          border: Border.all(
                            color: selected
                                ? prototypeCyan
                                : const Color(0xFF707070),
                          ),
                          borderRadius: BorderRadius.circular(48),
                        ),
                        child: Text(
                          labels[index],
                          style: _dialogActionStyle.copyWith(
                            fontSize: 34,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFF2F2F2),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            _DialogActions(
              onConfirm: _days.isEmpty
                  ? null
                  : () {
                      final sorted = _days.toList()..sort();
                      Navigator.of(context).pop(sorted);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// 版本更新确认弹窗（Figma 1006-9282：确认对话框）。
/// 显示更新提示文本和「下次再说」/「立即更新」按钮。
class _VersionUpdateConfirmDialog extends StatelessWidget {
  const _VersionUpdateConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey<String>('settings-version-update-confirm-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1440,
        height: 524,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(
            color: const Color(0xB3FFFFFF),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 160,
              child: Text(
                l10n.updateAvailableMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 42,
                ),
              ),
            ),
            // 「下次再说」按钮（左）
            Positioned(
              left: 400,
              top: 336,
              child: GestureDetector(
                key: const ValueKey<String>(
                  'settings-version-update-cancel',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  width: 220,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x45FFFFFF),
                    border: Border.all(
                      color: const Color(0x4DFFFFFF),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.updateLater,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppFonts.sourceHanSansSc,
                      fontVariations: AppFonts.sourceHanSansScRegularWght400,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            ),
            // 「立即更新」按钮（右）
            Positioned(
              left: 820,
              top: 336,
              child: GestureDetector(
                key: const ValueKey<String>(
                  'settings-version-update-confirm',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  width: 220,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xB33B82F6),
                    border: Border.all(
                      color: const Color(0x4DFFFFFF),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.updateNow,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppFonts.sourceHanSansSc,
                      fontVariations: AppFonts.sourceHanSansScRegularWght400,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 版本更新进行中弹窗（Figma 1006-9610：更新过程中请勿断电）。
/// 显示加载动画，后端下载完成或失败后由父级关闭。
class _VersionUpdateProgressDialog extends StatelessWidget {
  const _VersionUpdateProgressDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey<String>('settings-version-update-progress-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1440,
        height: 524,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(
            color: const Color(0xB3FFFFFF),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 145,
              child: Text(
                l10n.updatingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 42,
                ),
              ),
            ),
            // 加载图标（Figma 1006-9934：nonicons:loading-16，66x66）
            const Positioned(
              left: 687,
              top: 279,
              width: 66,
              height: 66,
              child: _UpdateLoadingIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 版本下载失败弹窗（Figma 1006-9292：版本下载更新失败）。
/// 显示失败提示信息和「退出」按钮。
class _VersionUpdateFailedDialog extends StatelessWidget {
  const _VersionUpdateFailedDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey<String>('settings-version-update-failed-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1440,
        height: 524,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(
            color: const Color(0xB3FFFFFF),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 145,
              child: Text(
                l10n.updateFailedMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 42,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 330,
              child: Center(
                child: GestureDetector(
                  key: const ValueKey<String>(
                    'settings-version-update-failed-exit',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 220,
                    height: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x45FFFFFF),
                      border: Border.all(
                        color: const Color(0x4DFFFFFF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.exit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.sourceHanSansSc,
                        fontVariations: AppFonts.sourceHanSansScRegularWght400,
                        fontSize: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 更新中的加载动画指示器（Figma 1006-9934：nonicons:loading-16，66x66）。
class _UpdateLoadingIndicator extends StatefulWidget {
  const _UpdateLoadingIndicator();

  @override
  State<_UpdateLoadingIndicator> createState() =>
      _UpdateLoadingIndicatorState();
}

class _UpdateLoadingIndicatorState extends State<_UpdateLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: 66,
        height: 66,
        child: CustomPaint(
          painter: _DotsLoadingPainter(),
        ),
      ),
    );
  }
}

/// 三点旋转加载动画绘制器，匹配 Figma 中的 eos-icons:bubble-loading 风格。
class _DotsLoadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF42CEEA);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 12;
    final orbitRadius = size.width / 3.5;
    for (var i = 0; i < 3; i++) {
      final angle = i * 2 * math.pi / 3;
      final dotCenter = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle),
      );
      canvas.drawCircle(dotCenter, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      keyName: 'settings-message-dialog',
      title: title,
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, style: _dialogOptionStyle),
            _DialogActions(onConfirm: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.keyName,
    required this.title,
    required this.child,
  });

  final String keyName;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: ValueKey<String>(keyName),
      backgroundColor: prototypePanel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x66FFFFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(42, 34, 42, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: _dialogTitleStyle),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({this.onConfirm});

  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _DialogActionButton(
            key: const ValueKey<String>('settings-dialog-cancel'),
            label: l10n.cancel,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 28),
          _DialogActionButton(
            key: const ValueKey<String>('settings-dialog-confirm'),
            label: l10n.confirm,
            primary: true,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// 系统设置弹窗统一使用适合 8 寸触控屏的大尺寸按钮，避免 Material 默认小按钮。
class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.primary = false,
  }) : super(key: key);

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final backgroundColor = primary
        ? (enabled ? prototypeCyan : const Color(0xFF55595C))
        : const Color(0xFF24282B);
    final borderColor = primary
        ? (enabled ? prototypeCyan : const Color(0xFF666A6D))
        : const Color(0xCC42CEEA);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: ValueKey<String>(
            primary
                ? 'settings-dialog-confirm-surface'
                : 'settings-dialog-cancel-surface',
          ),
          width: 160,
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(35),
          ),
          child: Text(
            label,
            style: _dialogActionStyle.copyWith(
              color: enabled ? Colors.white : const Color(0x99FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceResetDialog extends StatefulWidget {
  const _MaintenanceResetDialog({required this.onConfirm});

  final Future<bool> Function() onConfirm;

  @override
  State<_MaintenanceResetDialog> createState() =>
      _MaintenanceResetDialogState();
}

class _MaintenanceResetDialogState extends State<_MaintenanceResetDialog> {
  bool _confirming = false;

  Future<void> _confirm() async {
    if (_confirming) {
      return;
    }
    setState(() => _confirming = true);
    final saved = await widget.onConfirm();
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    // 保存失败时保留弹窗，恢复按钮供用户再次确认。
    setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        key: const ValueKey<String>('settings-maintenance-reset-dialog'),
        insetPadding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          key: const ValueKey<String>(
            'settings-maintenance-reset-dialog-surface',
          ),
          width: 1440,
          height: 524,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            border: Border.all(
              color: const Color(0xB3FFFFFF),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 120,
                right: 120,
                top: 160,
                child: Text(
                  l10n.maintenanceResetMessage,
                  key: const ValueKey<String>(
                    'settings-maintenance-reset-message',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: AppFonts.sourceHanSansSc,
                    fontVariations: AppFonts.sourceHanSansScRegularWght400,
                    fontSize: 42,
                    height: 1.45,
                  ),
                ),
              ),
              Positioned(
                left: 390,
                top: 336,
                child: _MaintenanceDialogButton(
                  keyName: 'settings-maintenance-reset-cancel',
                  label: l10n.cancel,
                  enabled: !_confirming,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                right: 390,
                top: 336,
                child: _MaintenanceDialogButton(
                  keyName: 'settings-maintenance-reset-confirm',
                  label: l10n.ok,
                  primary: true,
                  enabled: !_confirming,
                  onTap: _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceDialogButton extends StatelessWidget {
  const _MaintenanceDialogButton({
    required this.keyName,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String keyName;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background =
        primary ? const Color(0xB33B82F6) : const Color(0x45FFFFFF);
    const border = Color(0x4DFFFFFF);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        key: ValueKey<String>(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : .62,
          child: Container(
            key: ValueKey<String>('$keyName-surface'),
            width: 220,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 36,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 设备维护页的滤网剩余天数写入 settings；服务入口仍为本地样板。
class _MaintenancePanel extends StatelessWidget {
  const _MaintenancePanel({
    required this.remainingDays,
    required this.onReset,
  });

  final List<int> remainingDays;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('settings-maintenance-main'),
      width: 1430,
      height: 924,
      decoration: const BoxDecoration(
        color: prototypePanel,
        image: DecorationImage(
          image: AssetImage('assets/settings/frame-bg2.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 248,
            top: 26,
            child: Text(l10n.consumableStatus, style: _maintenanceSectionStyle),
          ),
          Positioned(
            left: 570,
            top: 148,
            child: _ConsumableStatus(
              filterIndex: 1,
              name: l10n.filterName(1),
              days: remainingDays[0],
              totalDays: 300,
              onTap: onReset,
            ),
          ),
          Positioned(
            left: 768,
            top: 148,
            child: _ConsumableStatus(
              filterIndex: 2,
              name: l10n.filterName(2),
              days: remainingDays[1],
              totalDays: 90,
              onTap: onReset,
            ),
          ),
          Positioned(
            left: 966,
            top: 148,
            child: _ConsumableStatus(
              filterIndex: 3,
              name: l10n.filterName(3),
              days: remainingDays[2],
              totalDays: 365,
              useNeutralStyle: true,
              onTap: onReset,
            ),
          ),
          const Positioned(
            left: 554,
            top: 237,
            width: 576,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0x66FFFFFF),
            ),
          ),
          Positioned(
            left: 248,
            top: 314,
            child: Text(l10n.maintenance, style: _maintenanceSectionStyle),
          ),
          Positioned(
            left: 554,
            top: 294,
            width: 576,
            child: _MaintenanceInfoRow(
              label: l10n.service,
              value: l10n.callServiceProvider,
              isAction: true,
            ),
          ),
          Positioned(
            left: 554,
            top: 382,
            width: 576,
            child: _MaintenanceInfoRow(
              label: l10n.nextMaintenanceDate,
              value: '2026.08.28',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumableStatus extends StatelessWidget {
  const _ConsumableStatus({
    required this.filterIndex,
    required this.name,
    required this.days,
    required this.totalDays,
    this.useNeutralStyle = false,
    this.onTap,
  });

  final int filterIndex;
  final String name;
  final int days;
  final int totalDays;
  final bool useNeutralStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 生命周期日后由工程模式设定；当前仅以设计展示值计算剩余百分比。
    // 重置后的 400 天高于展示生命周期时按满格显示。
    final fraction = (days / totalDays).clamp(0.0, 1.0);
    // 当前切图以滤网类别区分颜色；重置为 400 天只恢复满格，不改变类别色。
    final displayColor = days <= 0
        ? const Color(0xFFE53935)
        : useNeutralStyle
            ? const Color(0xFF908D8D)
            : filterIndex == 2
                ? const Color(0xFFFF7815)
                : const Color(0xFF43D410);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 168,
        height: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _ConsumableFittedText(name, _consumableLabelStyle),
                  const Spacer(),
                  if (days <= 0)
                    _ConsumableFittedText(
                      l10n.dueForMaintenance,
                      _consumableDueStyle,
                    )
                  else ...<Widget>[
                    _ConsumableFittedText(
                      l10n.remainingPrefix,
                      _consumableLabelStyle,
                    ),
                    SizedBox(
                      width: 44,
                      height: 30,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$days',
                          key: ValueKey<String>(
                            'settings-maintenance-filter-$filterIndex-days',
                          ),
                          style: _consumableDaysStyle.copyWith(
                              color: displayColor),
                        ),
                      ),
                    ),
                    _ConsumableFittedText(l10n.dayUnit, _consumableLabelStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 168,
                height: 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xD9FFFFFF)),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth * fraction,
                        child: ColoredBox(color: displayColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumableFittedText extends StatelessWidget {
  const _ConsumableFittedText(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(text, style: style),
      ),
    );
  }
}

class _MaintenanceInfoRow extends StatelessWidget {
  const _MaintenanceInfoRow({
    required this.label,
    required this.value,
    this.isAction = false,
  });

  final String label;
  final String value;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        children: <Widget>[
          Positioned(
              left: 24, top: 15, child: Text(label, style: _rowLabelStyle)),
          if (isAction)
            Positioned(
              right: 24,
              top: 13,
              child: Container(
                width: 156,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFA5A5A5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(value, style: _smallButtonStyle),
              ),
            )
          else
            Positioned(
              right: 24,
              top: 15,
              child: Text(value, style: _rowValueStyle),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// Figma 69:4387、69:4419、69:4958：工程模式的六码密码入口。
///
/// 默认密码仅用于当前 UI 联调。运行期间可从工程模式内修改，但不落盘、
/// 不进入 JSON，也不复用 Wi-Fi 密码；App 重启后恢复默认值 666666。
class _EngineeringPasswordPanel extends StatefulWidget {
  const _EngineeringPasswordPanel({
    required this.password,
    required this.onAccepted,
  });

  final String password;
  final VoidCallback onAccepted;

  @override
  State<_EngineeringPasswordPanel> createState() =>
      _EngineeringPasswordPanelState();
}

class _EngineeringPasswordPanelState extends State<_EngineeringPasswordPanel> {
  static const int _passwordLength = 6;

  String _password = '';
  bool _keyboardVisible = false;
  bool _showPassword = false;
  bool _showError = false;
  bool _accepted = false;

  void _togglePasswordVisibility() {
    if (!mounted) {
      return;
    }
    final keyboardVisible = _keyboardVisible;
    setState(() {
      _showPassword = !_showPassword;
      // 眼睛只改变明文/密文；键盘保持点击前状态。
      _keyboardVisible = keyboardVisible;
    });
  }

  void _beginInput() {
    setState(() {
      // 再次点密码区域就是重新输入一次，不沿用已通过的临时内存值。
      if (_accepted) {
        _password = '';
        _accepted = false;
      }
      _showError = false;
      _keyboardVisible = true;
    });
  }

  void _changePassword(String value) {
    setState(() {
      _password = value;
      _accepted = false;
      _showError = false;
      _keyboardVisible = true;
    });
    if (value.length == _passwordLength) {
      _verifyPassword(value);
    }
  }

  void _confirmPassword(String value) {
    if (value.length == _passwordLength) {
      _verifyPassword(value);
    }
  }

  void _verifyPassword(String value) {
    final accepted = value == widget.password;
    if (!mounted) {
      return;
    }
    setState(() {
      _accepted = accepted;
      _showError = !accepted;
      // 成功后保持六码掩码作为已验证状态；后续参数页有设计后再接入。
      _keyboardVisible = !accepted;
    });
    if (accepted) {
      widget.onAccepted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 面板视觉高度保持 Figma 的 924；键盘从 y=487 延伸至 y=988。
    // 本组件位于整屏 y=212，因此 212 + 988 = 1200，正好抵达画布底边。
    // Stack 必须覆盖键盘的完整可见范围，否则 clipBehavior 虽允许绘制，
    // 父 RenderBox 边界外的底部 64px 仍无法参与命中测试。
    return SizedBox(
      key: const ValueKey<String>('settings-engineering-password-panel'),
      width: 1430,
      height: 988,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            width: 1430,
            height: 924,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: prototypePanel,
                borderRadius: BorderRadius.circular(2),
                image: const DecorationImage(
                  image: AssetImage('assets/settings/frame-bg2.png'),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          if (_keyboardVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _keyboardVisible = false;
                }),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            left: 330,
            top: 191,
            child: Text(
              l10n.enterPassword,
              style: _engineeringPasswordTitleStyle,
            ),
          ),
          if (_showError)
            Positioned(
              left: 574,
              top: 196,
              child: Text(
                l10n.passwordError,
                key: const ValueKey<String>(
                  'settings-engineering-password-error',
                ),
                style: _engineeringPasswordErrorStyle,
              ),
            ),
          Positioned(
            left: 330,
            top: 286,
            child: GestureDetector(
              key:
                  const ValueKey<String>('settings-engineering-password-input'),
              behavior: HitTestBehavior.opaque,
              onTap: _beginInput,
              child: SizedBox(
                width: 820,
                height: 150,
                child: Row(
                  children: List<Widget>.generate(_passwordLength, (index) {
                    final hasCharacter = index < _password.length;
                    final displayed = !hasCharacter
                        ? ''
                        : _showPassword
                            ? _password[index]
                            : '*';
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _passwordLength - 1 ? 0 : 20,
                      ),
                      child: Container(
                        key: ValueKey<String>(
                            'settings-engineering-password-cell-$index'),
                        width: 120,
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E7E7),
                          border: Border.all(
                            color: _keyboardVisible && index == _password.length
                                ? prototypeCyan
                                : const Color(0xFF868686),
                            width: _keyboardVisible && index == _password.length
                                ? 3
                                : 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Transform.translate(
                          key: ValueKey<String>(
                            'settings-engineering-password-cell-content-$index',
                          ),
                          // 方框与眼睛已经按几何中心对齐；星号字形本身
                          // 视觉重心偏上，只在密文状态做光学校正。
                          offset: Offset(
                            0,
                            hasCharacter && !_showPassword ? 17 : 0,
                          ),
                          child: Text(
                            displayed,
                            style: _engineeringPasswordCellStyle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Positioned(
            left: 1214,
            top: 339,
            child: GestureDetector(
              key: const ValueKey<String>('settings-engineering-password-eye'),
              behavior: HitTestBehavior.opaque,
              onTap: _togglePasswordVisibility,
              child: SizedBox(
                width: 48,
                height: 40,
                child: CustomPaint(
                  painter: _EyeGlyphPainter(open: _showPassword),
                ),
              ),
            ),
          ),
          if (_keyboardVisible) ...<Widget>[
            const Positioned(
              left: -440,
              top: 487,
              width: 1920,
              height: 501,
              child: ColoredBox(color: Color(0xE6000000)),
            ),
            Positioned(
              left: 173,
              top: 487,
              child: TouchPasswordKeyboard(
                initialValue: _password,
                maxLength: _passwordLength,
                onChanged: _changePassword,
                onConfirm: _confirmPassword,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _languageName(String code) {
  switch (code) {
    case 'ja_JP':
      return '日本語';
    case 'en_US':
      return 'English';
    default:
      return '简体中文';
  }
}

String _languageFontFamily(String code) {
  // 客户字体规范：中、日、英翻译文字统一使用 Source Han Sans SC。
  return AppFonts.sourceHanSansSc;
}

String _priorityMetricName(String metric, AppLocalizations l10n) {
  switch (metric) {
    case 'temperature':
      return l10n.metricTemperature;
    case 'humidity':
      return l10n.metricHumidity;
    case 'co2':
      return l10n.metricCo2;
    case 'formaldehyde':
      return l10n.metricFormaldehyde;
    default:
      return l10n.metricPm25;
  }
}

Locale _datePickerLocale(String code) {
  switch (code) {
    case 'ja_JP':
      return const Locale('ja', 'JP');
    case 'en_US':
      return const Locale('en', 'US');
    default:
      return const Locale('zh', 'CN');
  }
}

class _DatePickerMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _DatePickerMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const <String>{'zh', 'en', 'ja'}.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // 先复用 Flutter 原生代理完成离线日期符号初始化，再只替换标题格式。
    await GlobalMaterialLocalizations.delegate.load(locale);
    final canonicalLocale = intl.Intl.canonicalizedLocale(locale.toString());
    final dateLocale = intl.DateFormat.localeExists(canonicalLocale)
        ? canonicalLocale
        : locale.languageCode;
    final numberLocale = intl.NumberFormat.localeExists(canonicalLocale)
        ? canonicalLocale
        : locale.languageCode;
    return getMaterialTranslation(
      locale,
      intl.DateFormat.y(dateLocale),
      intl.DateFormat.yMd(dateLocale),
      intl.DateFormat.yMMMd(dateLocale),
      intl.DateFormat('yyyy-MM-dd\nEEEE', dateLocale),
      intl.DateFormat.yMMMMEEEEd(dateLocale),
      intl.DateFormat.yMMMM(dateLocale),
      intl.DateFormat.MMMd(dateLocale),
      intl.NumberFormat.decimalPattern(numberLocale),
      intl.NumberFormat('00', numberLocale),
    )!;
  }

  @override
  bool shouldReload(_DatePickerMaterialLocalizationsDelegate old) => false;
}

String _formatDateSetting(DashboardData data) {
  final year = data.dateYear.toString().padLeft(4, '0');
  final month = data.dateMonth.toString().padLeft(2, '0');
  final day = data.dateDay.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatClockSetting(DashboardData data, AppLocalizations l10n) {
  final minute = data.clockMinute.toString().padLeft(2, '0');
  final second = data.clockSecond.toString().padLeft(2, '0');
  if (data.timeFormat == '12h') {
    final h24 = data.clockHour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ampm = h24 < 12 ? l10n.am : l10n.pm;
    return '${h12.toString().padLeft(2, '0')}:$minute:$second $ampm';
  }
  final hour = data.clockHour.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatRepeatDays(List<int> days, AppLocalizations l10n) {
  final names = <String>[
    '',
    l10n.monday,
    l10n.tuesday,
    l10n.wednesday,
    l10n.thursday,
    l10n.friday,
    l10n.saturday,
    l10n.sunday,
  ];
  if (days.length == 7) {
    return l10n.everyDay;
  }
  var consecutive = true;
  for (var index = 1; index < days.length; index++) {
    if (days[index] != days[index - 1] + 1) {
      consecutive = false;
      break;
    }
  }
  if (consecutive && days.length > 1) {
    return '${names[days.first]}～${names[days.last]}';
  }
  return days.map((day) => names[day]).join('、');
}

const TextStyle _sectionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 36,
  height: 1.448,
);

const TextStyle _maintenanceSectionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 36,
  height: 1.448,
);

const TextStyle _consumableLabelStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 20,
  height: 1.0,
);

const TextStyle _consumableDaysStyle = TextStyle(
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 28,
  height: 1.0,
);

const TextStyle _consumableDueStyle = TextStyle(
  color: Color(0xFFE53935),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScMediumWght500,
  fontSize: 22,
  height: 1.0,
);

const TextStyle _rowLabelStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 28,
  height: 1.448,
);

const TextStyle _rowValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 28,
  height: 1.448,
);

const TextStyle _brightnessLabelStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 20,
  height: 1.448,
);

const TextStyle _brightnessValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 20,
  height: 1.448,
);

const TextStyle _dateTimePlaceholderStyle = TextStyle(
  color: Color(0xFF9A9A9A),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 21,
  height: 1.2,
);

const TextStyle _clockHeaderStyle = TextStyle(
  color: Color(0xFF626A73),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
  fontSize: 22,
  height: 1.448,
);

const TextStyle _clockValueStyle = TextStyle(
  color: Color(0xFF8A929B),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 20,
  height: 1.448,
);

const TextStyle _clockSelectedValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
  fontSize: 20,
  height: 1.448,
);

const TextStyle _clockConfirmStyle = TextStyle(
  color: Color(0xFF3C4148),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 22,
  height: 1.448,
);

const TextStyle _smallButtonStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 20,
);

const TextStyle _dialogTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScMediumWght500,
  fontSize: 34,
);

const TextStyle _dialogOptionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 28,
);

/// 仅用于触控选择项：字与热区一起放大，普通页面文字不受影响。
const TextStyle _dialogTouchOptionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 34,
);

const TextStyle _dialogActionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScMediumWght500,
  fontSize: 24,
  height: 1.2,
);

const TextStyle _wifiPasswordValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 32,
);

const TextStyle _wifiConnectingTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
  fontSize: 36,
  fontWeight: FontWeight.w700,
);

const TextStyle _wifiConnectingPasswordStyle = TextStyle(
  color: Color(0x66666666),
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 36,
);

const TextStyle _engineeringPasswordTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
  fontSize: 36,
  height: 1.448,
);

const TextStyle _engineeringPasswordErrorStyle = TextStyle(
  color: Color(0xFFE54A4A),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 30,
  height: 1.448,
);

const TextStyle _engineeringPasswordCellStyle = TextStyle(
  color: Colors.black,
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 72,
  height: 1.0,
);
