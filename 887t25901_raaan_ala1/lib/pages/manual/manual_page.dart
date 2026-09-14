import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../services/app_logger.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/horizontal_stepper.dart';
import '../../widgets/prototype_chrome.dart';
import '../../widgets/semicircle_gauge_interaction.dart';
import '../../widgets/vertical_stepper.dart';

typedef CommitManualSettings = Future<bool> Function(
  String controlKey,
  DashboardData Function(DashboardData current) change,
);

typedef SetManualPurePower = Future<void> Function(bool enabled);
typedef SetManualModulePower = Future<void> Function(bool enabled);
typedef SetManualFreshAirMode = Future<void> Function(String mode);
typedef SetManualFreshAirFanLevel = Future<void> Function(String level);
typedef SetManualTargetHumidity = Future<void> Function(int percent);

/// 手动页下的五个独立设备页面；空调和地暖已接入 settings。
class ManualPage extends StatefulWidget {
  const ManualPage({
    Key? key,
    required this.data,
    required this.onBack,
    required this.onCommitSettingsChange,
    this.onSetFreshAirPower,
    this.onSetHumidifierPower,
    this.onSetFreshAirMode,
    this.onSetFreshAirFanLevel,
    this.onSetTargetHumidity,
    required this.onSetPurePower,
    required this.entryToken,
    this.initialDeviceIndex = 0,
  })  : assert(initialDeviceIndex >= 0 && initialDeviceIndex < 5),
        super(key: key);

  final DashboardData data;
  final VoidCallback onBack;
  final CommitManualSettings onCommitSettingsChange;
  final SetManualModulePower? onSetFreshAirPower;
  final SetManualModulePower? onSetHumidifierPower;
  final SetManualFreshAirMode? onSetFreshAirMode;
  final SetManualFreshAirFanLevel? onSetFreshAirFanLevel;
  final SetManualTargetHumidity? onSetTargetHumidity;
  final SetManualPurePower onSetPurePower;
  final int entryToken;
  final int initialDeviceIndex;

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  late int _deviceIndex;
  bool _deviceSwitchInFlight = false;

  /// 手动模式下右上角开关操作时弹出退出确认弹窗。
  ///
  /// [onConfirm] 在用户点击"确定"后执行；为 null 时执行返回上级页面。
  void _showExitDialog([VoidCallback? onConfirm]) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x4D000000),
      builder: (context) => const _ManualExitDialog(),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        (onConfirm ?? widget.onBack)();
      }
    });
  }

  static List<PrototypeMenuItem> _sideMenuItems(AppLocalizations l10n) {
    return <PrototypeMenuItem>[
      PrototypeMenuItem(
        l10n.deviceAirConditioner,
        PrototypeGlyph.airConditioner,
        activeIconAsset: 'assets/navigation/manual_air_conditioner_active.png',
        inactiveIconAsset:
            'assets/navigation/manual_air_conditioner_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.deviceFloorHeat,
        PrototypeGlyph.floorHeat,
        activeIconAsset: 'assets/navigation/manual_floor_heat_active.png',
        inactiveIconAsset: 'assets/navigation/manual_floor_heat_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.deviceFreshAir,
        PrototypeGlyph.freshAir,
        activeIconAsset: 'assets/navigation/manual_fresh_air_active.png',
        inactiveIconAsset: 'assets/navigation/manual_fresh_air_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.deviceHumidifier,
        PrototypeGlyph.humidity,
        activeIconAsset: 'assets/navigation/manual_humidity_active.png',
        inactiveIconAsset: 'assets/navigation/manual_humidity_inactive.png',
      ),
      PrototypeMenuItem(
        l10n.devicePure,
        PrototypeGlyph.clean,
        activeIconAsset: 'assets/navigation/manual_clean_active.png',
        inactiveIconAsset: 'assets/navigation/manual_clean_inactive.png',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _deviceIndex = widget.initialDeviceIndex;
  }

  @override
  void didUpdateWidget(covariant ManualPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entryToken != oldWidget.entryToken) {
      _deviceIndex = widget.initialDeviceIndex;
    }
  }

  Future<void> _selectDevice(int index) async {
    if (index == _deviceIndex || _deviceSwitchInFlight) {
      return;
    }
    setState(() => _deviceSwitchInFlight = true);

    // 设备子页切换也遵循“目标首屏先完成，再替换当前页”。相邻
    // PageView 页面由目标页首帧之后的资源窗口异步预热，不在这里抢先加载。
    final pageAssets = <String>{
      'assets/manual/frame-bg.png',
      'assets/manual/vertical_stepper_on.png',
      'assets/manual/vertical_stepper_off.png',
      'assets/manual/vertical_stepper_press_up.png',
      'assets/manual/vertical_stepper_press_down.png',
      'assets/settings/toggle-button-on.png',
      'assets/settings/toggle-button-off.png',
      'assets/navigation/manual_back.png',
      'assets/navigation/common_back_line.png',
      'assets/navigation/manual_air_conditioner_active.png',
      'assets/navigation/manual_air_conditioner_inactive.png',
      'assets/navigation/manual_floor_heat_active.png',
      'assets/navigation/manual_floor_heat_inactive.png',
      'assets/navigation/manual_fresh_air_active.png',
      'assets/navigation/manual_fresh_air_inactive.png',
      'assets/navigation/manual_humidity_active.png',
      'assets/navigation/manual_humidity_inactive.png',
      'assets/navigation/manual_clean_active.png',
      'assets/navigation/manual_clean_inactive.png',
    };
    if (index == 0) {
      pageAssets.addAll(<String>[
        'assets/manual/ac-cardbg.png',
        'assets/manual/ac-cardbg-off.png',
        'assets/manual/card-空调.png',
        'assets/manual/card-风量.png',
        'assets/manual/check-box-on.png',
        'assets/manual/check-box-off.png',
      ]);
    } else if (index == 1) {
      pageAssets.addAll(<String>[
        'assets/manual/fh-cardbg.png',
        'assets/manual/fh-cardbg-off.png',
        'assets/manual/card-空调.png',
        'assets/manual/card-风量.png',
        'assets/manual/check-box-on.png',
        'assets/manual/check-box-off.png',
      ]);
    }
    try {
      await Future.wait(
        pageAssets.map(
          (asset) => precacheImage(AssetImage(asset), context),
        ),
      ).timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      AppLogger.instance.w(
        '手动设备首屏资源预加载失败',
        tag: 'ManualPage',
        error: error,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceIndex = index;
      _deviceSwitchInFlight = false;
    });
  }

  String _pagePrompt(AppLocalizations l10n) {
    switch (_deviceIndex) {
      case 0:
        final settings = <String, ManualAirConditionerSetting>{
          for (final setting in widget.data.manualAirConditioners)
            setting.deviceId: setting,
        };
        final runningCount =
            widget.data.airConditionerZones.take(16).where((zone) {
          return zone.online && (settings[zone.deviceId]?.enabled ?? false);
        }).length;
        return l10n.runningDeviceCount(runningCount);
      case 1:
        if (widget.data.floorHeatControlMode == 'whole_home') {
          final wholeHomeEnabled = widget.data.manualFloorHeatSettings.any(
            (setting) =>
                setting.deviceId == DashboardData.wholeHomeFloorHeatDeviceId &&
                setting.enabled,
          );
          return wholeHomeEnabled ? '※ ${l10n.manualWholeHomeFloorHeat}' : '';
        }
        final settings = <String, ManualFloorHeatSetting>{
          for (final setting in widget.data.manualFloorHeatSettings)
            setting.deviceId: setting,
        };
        final runningCount = widget.data.floorHeatZones.take(16).where((zone) {
          return zone.online && (settings[zone.deviceId]?.enabled ?? false);
        }).length;
        return l10n.runningDeviceCount(runningCount);
      case 2:
        return widget.data.freshAirEnabled ? '※ ${l10n.manualWholeHomeFreshAir}' : '';
      case 3:
        return widget.data.humidifierEnabled ? '※ ${l10n.manualWholeHomeHumidity}' : '';
      case 4:
        return widget.data.pureEnabled ? '※ ${l10n.manualWholeHomePure}' : '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PrototypePageChrome(
      prompt: '',
      onBack: widget.onBack,
      backIconAsset: 'assets/navigation/manual_back.png',
      backDividerAsset: 'assets/navigation/common_back_line.png',
      child: Stack(
        children: <Widget>[
          PrototypeSideMenu(
            items: _sideMenuItems(l10n),
            selectedIndex: _deviceIndex,
            onSelected: _selectDevice,
            top: 254,
            itemGap: 176,
          ),
          // 手动页公共提示与导航同级；Figma 的 tips + 文本起点为 (460, 121)。
          Positioned(
            left: 460,
            top: 121,
            child: Text(
              _pagePrompt(l10n),
              key: const ValueKey<String>('manual-page-prompt'),
              style: _airPromptStyle,
            ),
          ),
          if (_deviceIndex == 0)
            Positioned.fill(
              child: KeyedSubtree(
                // 保留公共边界 key 供测试和诊断定位；真正承载 State 的
                // 子边界按设备区分，避免切换设备时短暂复用上一页 State。
                key: const ValueKey<String>('manual-main-content-boundary'),
                child: KeyedSubtree(
                  key: const ValueKey<String>(
                    'manual-air-conditioner-boundary',
                  ),
                  child: _ManualAirConditionerPanel(
                    data: widget.data,
                    onCommitSettingsChange: widget.onCommitSettingsChange,
                  ),
                ),
              ),
            ),
          if (_deviceIndex == 1)
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey<String>('manual-main-content-boundary'),
                child: KeyedSubtree(
                  key: const ValueKey<String>('manual-floor-heat-boundary'),
                  child: _ManualFloorHeatPanel(
                    data: widget.data,
                    // runtime 每次刷新后直接决定分区/全屋布局，不锁定进入时快照。
                    controlMode: widget.data.floorHeatControlMode,
                    onCommitSettingsChange: widget.onCommitSettingsChange,
                    onExitRequested: _showExitDialog,
                  ),
                ),
              ),
            ),
          if (_deviceIndex == 2)
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey<String>('manual-main-content-boundary'),
                child: KeyedSubtree(
                  key: const ValueKey<String>('manual-fresh-air-boundary'),
                  child: _ManualFreshAirPanel(
                    data: widget.data,
                    onCommitSettingsChange: widget.onCommitSettingsChange,
                    onSetPower: widget.onSetFreshAirPower,
                    onSetMode: widget.onSetFreshAirMode,
                    onSetFanLevel: widget.onSetFreshAirFanLevel,
                    onExitRequested: (onConfirm) => _showExitDialog(onConfirm),
                  ),
                ),
              ),
            ),
          if (_deviceIndex == 3)
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey<String>('manual-main-content-boundary'),
                child: KeyedSubtree(
                  key: const ValueKey<String>('manual-humidifier-boundary'),
                  child: _ManualHumidifierPanel(
                    data: widget.data,
                    onCommitSettingsChange: widget.onCommitSettingsChange,
                    onSetPower: widget.onSetHumidifierPower,
                    onSetTargetHumidity: widget.onSetTargetHumidity,
                    onExitRequested: (onConfirm) => _showExitDialog(onConfirm),
                  ),
                ),
              ),
            ),
          if (_deviceIndex == 4)
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey<String>('manual-main-content-boundary'),
                child: KeyedSubtree(
                  key: const ValueKey<String>('manual-pure-boundary'),
                  child: _ManualPurePanel(
                    data: widget.data,
                    onCommitSettingsChange: widget.onCommitSettingsChange,
                    onSetPurePower: widget.onSetPurePower,
                    onExitRequested: (onConfirm) => _showExitDialog(onConfirm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualFreshAirPanel extends StatefulWidget {
  const _ManualFreshAirPanel({
    required this.data,
    required this.onCommitSettingsChange,
    this.onSetPower,
    this.onSetMode,
    this.onSetFanLevel,
    this.onExitRequested,
  });

  final DashboardData data;
  final CommitManualSettings onCommitSettingsChange;
  final SetManualModulePower? onSetPower;
  final SetManualFreshAirMode? onSetMode;
  final SetManualFreshAirFanLevel? onSetFanLevel;
  final void Function(VoidCallback onConfirm)? onExitRequested;

  @override
  State<_ManualFreshAirPanel> createState() => _ManualFreshAirPanelState();
}

class _ManualFreshAirPanelState extends State<_ManualFreshAirPanel> {
  static const _saveDelay = Duration(milliseconds: 500);

  List<String> get _fanLevels {
    switch (_displayMode) {
      case 'full_heat_exchange':
        return ['L0', 'L1', 'L2', 'L3'];
      default:
        return ['L0', 'L1', 'L2', 'L3', 'L4', 'L5'];
    }
  }

  int get _fanLevelsMinIndex => 1; // L0 显示但不可选择
  int get _fanLevelsMaxIndex => _fanLevels.length - 1;

  Timer? _saveTimer;
  late int _draftFanIndex;
  bool _savePending = false;
  bool _saving = false;
  bool _modeMenuVisible = false;
  bool _timerVisible = false;
  late bool _timerEnabled;
  late int _timerStartMinutes;
  late int _timerEndMinutes;
  late String _timerRepeat;
  late String _timerMode;
  late String _timerFanLevel;

  @override
  void initState() {
    super.initState();
    _draftFanIndex = _fanLevels.indexOf(_displayFanLevel);
    if (_draftFanIndex < _fanLevelsMinIndex) _draftFanIndex = _fanLevelsMinIndex;
    _loadTimerDraft();
  }

  @override
  void didUpdateWidget(covariant _ManualFreshAirPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_savePending && !_saving) {
      final index = _fanLevels.indexOf(_displayFanLevel);
      _draftFanIndex = index < _fanLevelsMinIndex ? _fanLevelsMinIndex : index;
    }
  }

  String get _displayFanLevel => widget.onSetFanLevel == null ||
          widget.data.backendDataStatus == 'unreachable'
      ? widget.data.manualFreshAirFanLevel
      : widget.data.freshAirFanLevelActual;

  String get _displayMode => widget.onSetMode == null ||
          widget.data.backendDataStatus == 'unreachable'
      ? widget.data.manualFreshAirMode
      : widget.data.freshAirModeActual;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _loadTimerDraft() {
    _timerEnabled = widget.data.manualFreshAirTimerEnabled;
    _timerStartMinutes = widget.data.manualFreshAirTimerStartMinutes;
    _timerEndMinutes = widget.data.manualFreshAirTimerEndMinutes;
    _timerRepeat = widget.data.manualFreshAirTimerRepeat;
    _timerMode = widget.data.manualFreshAirMode;
    _timerFanLevel = widget.data.manualFreshAirFanLevel;
  }

  Future<bool> _commit(
    String key,
    DashboardData Function(DashboardData current) change,
  ) async {
    if (_saving) return false;
    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(key, change);
    if (mounted) setState(() => _saving = false);
    return saved;
  }

  void _previewFan(int index) {
    setState(() => _draftFanIndex = index.clamp(_fanLevelsMinIndex, _fanLevelsMaxIndex).toInt());
    _savePending = true;
    _saveTimer?.cancel();
  }

  void _queueFan(int delta) {
    final next = (_draftFanIndex + delta).clamp(_fanLevelsMinIndex, _fanLevelsMaxIndex).toInt();
    if (next == _draftFanIndex) return;
    setState(() => _draftFanIndex = next);
    _savePending = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flushFan);
  }

  Future<void> _flushFan() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_savePending || _saving) return;
    _savePending = false;
    final level = _fanLevels[_draftFanIndex];
    final submit = widget.onSetFanLevel;
    if (submit != null) {
      setState(() => _saving = true);
      await submit(level);
      if (mounted) setState(() => _saving = false);
    } else {
      await _commit(
        'manual-fresh-air-fan',
        (current) => current.copyWith(manualFreshAirFanLevel: level),
      );
    }
  }

  Future<void> _setMode(String value) async {
    if (_saving) return;
    setState(() {
      _modeMenuVisible = false;
      _saving = true;
    });
    final submit = widget.onSetMode;
    if (submit != null) {
      await submit(value);
    } else {
      await widget.onCommitSettingsChange(
        'manual-fresh-air-mode',
        (current) => current.copyWith(manualFreshAirMode: value),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  void _openTimer() {
    _loadTimerDraft();
    setState(() => _timerVisible = true);
  }

  Future<void> _saveTimerAndClose() async {
    final saved = await _commit(
      'manual-fresh-air-timer',
      (current) => current.copyWith(
        manualFreshAirTimerEnabled: _timerEnabled,
        manualFreshAirTimerStartMinutes: _timerStartMinutes,
        manualFreshAirTimerEndMinutes: _timerEndMinutes,
        manualFreshAirTimerRepeat: _timerRepeat,
        manualFreshAirMode: _timerMode,
        manualFreshAirFanLevel: _timerFanLevel,
      ),
    );
    if (mounted && saved) setState(() => _timerVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = widget.data.freshAirEnabled;
    if (_timerVisible) {
      return _ManualStandaloneDetail(
        detail: _WholeHomeTimerPage(
          title: l10n.freshAirTimerSetting,
          toggleKey: const ValueKey<String>('manual-fresh-air-timer-power'),
          timerEnabled: _timerEnabled,
          startMinutes: _timerStartMinutes,
          endMinutes: _timerEndMinutes,
          repeat: _timerRepeat,
          mode: _timerMode,
          fanLevel: _timerFanLevel,
          saving: _saving,
          timeFormat: widget.data.timeFormat,
          onBack: _saveTimerAndClose,
          onTimerEnabledChanged: (value) =>
              setState(() => _timerEnabled = value),
          onStartChanged: (value) => setState(() => _timerStartMinutes = value),
          onEndChanged: (value) => setState(() => _timerEndMinutes = value),
          onRepeatChanged: (value) => setState(() => _timerRepeat = value),
          onModeChanged: (value) => setState(() => _timerMode = value),
          onFanChanged: (value) => setState(() => _timerFanLevel = value),
        ),
      );
    }
    final panel = _WholeHomeControlSurface(
      keyPrefix: 'manual-fresh-air',
      title: l10n.manualFanSpeed,
      themeColor: const Color(0xFFA340FF),
      enabled: enabled,
      saving: _saving,
      valueIndex: _draftFanIndex,
      maxIndex: _fanLevelsMaxIndex,
      valueText: _displayMode == 'auto' ? 'AUTO' : _fanLevels[_draftFanIndex],
      // Figma 68:2295：风量值全局 y=561，仪表标题全局 y=314。
      valueTop: _displayMode == 'auto' ? 260 : 247,
      valueFontSize: _displayMode == 'auto' ? 125 : null,
      minLabel: 'L0',
      maxLabel: _fanLevels.last,
      timerSummary: enabled
          ? _wholeHomeTimerSummary(
              l10n,
              widget.data.manualFreshAirTimerEnabled,
              widget.data.manualFreshAirTimerStartMinutes,
              widget.data.manualFreshAirTimerEndMinutes,
              widget.data.manualFreshAirTimerRepeat,
            )
          : null,
      bottomLabel: l10n.manualMode,
      bottomValue: _freshAirModeText(_displayMode, l10n),
      bottomMenuVisible: _modeMenuVisible,
      bottomMenuValues: const <String>[
        'internal_circulation',
        'full_heat_exchange',
        'auto',
      ],
      bottomMenuDisplay: (value) => _freshAirModeText(value, l10n),
      onToggle: _saving
          ? null
          : (value) =>
              widget.onSetPower?.call(value) ??
              _commit(
                'manual-fresh-air-power',
                (current) => current.copyWith(freshAirEnabled: value),
              ),
      onTimer: enabled && !_saving ? _openTimer : null,
      onPreviewChanged: enabled && !_saving && _displayMode != 'auto' ? _previewFan : null,
      onChangeEnd: enabled && !_saving && _displayMode != 'auto' ? _flushFan : null,
      onMinus: enabled && !_saving && _displayMode != 'auto' ? () => _queueFan(-1) : null,
      onPlus: enabled && !_saving && _displayMode != 'auto' ? () => _queueFan(1) : null,
      onBottomTap: enabled && !_saving
          ? () => setState(() => _modeMenuVisible = !_modeMenuVisible)
          : null,
      onBottomMenuSelected: _setMode,
      onExitRequested: widget.onExitRequested,
    );
    return _WholeHomePanelFrame(panel: panel);
  }
}

class _ManualHumidifierPanel extends StatefulWidget {
  const _ManualHumidifierPanel({
    required this.data,
    required this.onCommitSettingsChange,
    this.onSetPower,
    this.onSetTargetHumidity,
    this.onExitRequested,
  });

  final DashboardData data;
  final CommitManualSettings onCommitSettingsChange;
  final SetManualModulePower? onSetPower;
  final SetManualTargetHumidity? onSetTargetHumidity;
  final void Function(VoidCallback onConfirm)? onExitRequested;

  @override
  State<_ManualHumidifierPanel> createState() => _ManualHumidifierPanelState();
}

class _ManualHumidifierPanelState extends State<_ManualHumidifierPanel> {
  static const _saveDelay = Duration(milliseconds: 500);
  Timer? _saveTimer;
  late int _draftHumidity;
  bool _savePending = false;
  bool _saving = false;
  bool _timerVisible = false;
  late bool _timerEnabled;
  late int _timerStartMinutes;
  late int _timerEndMinutes;
  late String _timerRepeat;
  late int _timerHumidity;

  @override
  void initState() {
    super.initState();
    _draftHumidity = _displayHumidity;
    _loadTimerDraft();
  }

  @override
  void didUpdateWidget(covariant _ManualHumidifierPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_savePending && !_saving) {
      _draftHumidity = _displayHumidity;
    }
  }

  int get _displayHumidity =>
      widget.onSetTargetHumidity == null ||
              widget.data.backendDataStatus == 'unreachable'
          ? widget.data.manualHumidifierSetpointPercent
          : widget.data.humidifierSetpointActualPercent;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _loadTimerDraft() {
    _timerEnabled = widget.data.manualHumidifierTimerEnabled;
    _timerStartMinutes = widget.data.manualHumidifierTimerStartMinutes;
    _timerEndMinutes = widget.data.manualHumidifierTimerEndMinutes;
    _timerRepeat = widget.data.manualHumidifierTimerRepeat;
    _timerHumidity = widget.data.manualHumidifierSetpointPercent;
  }

  Future<bool> _commit(
    String key,
    DashboardData Function(DashboardData current) change,
  ) async {
    if (_saving) return false;
    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(key, change);
    if (mounted) setState(() => _saving = false);
    return saved;
  }

  void _previewHumidity(int value) {
    setState(() => _draftHumidity = value.clamp(30, 70).toInt());
    _savePending = true;
    _saveTimer?.cancel();
  }

  void _queueHumidity(int delta) {
    final next = (_draftHumidity + delta).clamp(30, 70).toInt();
    if (next == _draftHumidity) return;
    setState(() => _draftHumidity = next);
    _savePending = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flushHumidity);
  }

  Future<void> _flushHumidity() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_savePending || _saving) return;
    _savePending = false;
    final value = _draftHumidity;
    final submit = widget.onSetTargetHumidity;
    if (submit != null) {
      setState(() => _saving = true);
      await submit(value);
      if (mounted) setState(() => _saving = false);
    } else {
      await _commit(
        'manual-humidifier-setpoint',
        (current) => current.copyWith(manualHumidifierSetpointPercent: value),
      );
    }
  }

  void _openTimer() {
    _loadTimerDraft();
    setState(() => _timerVisible = true);
  }

  Future<void> _saveTimerAndClose() async {
    final saved = await _commit(
      'manual-humidifier-timer',
      (current) => current.copyWith(
        manualHumidifierTimerEnabled: _timerEnabled,
        manualHumidifierTimerStartMinutes: _timerStartMinutes,
        manualHumidifierTimerEndMinutes: _timerEndMinutes,
        manualHumidifierTimerRepeat: _timerRepeat,
        manualHumidifierSetpointPercent: _timerHumidity,
      ),
    );
    if (mounted && saved) setState(() => _timerVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = widget.data.humidifierEnabled;
    if (_timerVisible) {
      return _ManualStandaloneDetail(
        detail: _WholeHomeTimerPage(
          title: l10n.humidifierTimerSetting,
          toggleKey: const ValueKey<String>('manual-humidifier-timer-power'),
          timerEnabled: _timerEnabled,
          startMinutes: _timerStartMinutes,
          endMinutes: _timerEndMinutes,
          repeat: _timerRepeat,
          humidity: _timerHumidity,
          saving: _saving,
          timeFormat: widget.data.timeFormat,
          onBack: _saveTimerAndClose,
          onTimerEnabledChanged: (value) =>
              setState(() => _timerEnabled = value),
          onStartChanged: (value) => setState(() => _timerStartMinutes = value),
          onEndChanged: (value) => setState(() => _timerEndMinutes = value),
          onRepeatChanged: (value) => setState(() => _timerRepeat = value),
          onHumidityChanged: (value) => setState(() => _timerHumidity = value),
        ),
      );
    }
    final panel = _WholeHomeControlSurface(
      keyPrefix: 'manual-humidifier',
      title: l10n.metricHumidity,
      themeColor: const Color(0xFF5BC132),
      enabled: enabled,
      saving: _saving,
      valueIndex: _draftHumidity - 30,
      maxIndex: 40,
      valueText: '$_draftHumidity',
      // Figma 68:3424/68:3514：湿度值全局 y=557.5。
      valueTop: 243.5,
      unit: '%',
      minLabel: '30',
      maxLabel: '70',
      timerSummary: enabled
          ? _wholeHomeTimerSummary(
              l10n,
              widget.data.manualHumidifierTimerEnabled,
              widget.data.manualHumidifierTimerStartMinutes,
              widget.data.manualHumidifierTimerEndMinutes,
              widget.data.manualHumidifierTimerRepeat,
            )
          : null,
      onToggle: _saving
          ? null
          : (value) =>
              widget.onSetPower?.call(value) ??
              _commit(
                'manual-humidifier-power',
                (current) => current.copyWith(humidifierEnabled: value),
              ),
      onTimer: enabled && !_saving ? _openTimer : null,
      onPreviewChanged:
          enabled && !_saving ? (index) => _previewHumidity(index + 30) : null,
      onChangeEnd: enabled && !_saving ? _flushHumidity : null,
      onMinus: enabled && !_saving ? () => _queueHumidity(-1) : null,
      onPlus: enabled && !_saving ? () => _queueHumidity(1) : null,
      onExitRequested: widget.onExitRequested,
    );
    return _WholeHomePanelFrame(panel: panel);
  }
}

class _ManualPurePanel extends StatefulWidget {
  const _ManualPurePanel({
    required this.data,
    required this.onCommitSettingsChange,
    required this.onSetPurePower,
    this.onExitRequested,
  });

  final DashboardData data;
  final CommitManualSettings onCommitSettingsChange;
  final SetManualPurePower onSetPurePower;
  final void Function(VoidCallback onConfirm)? onExitRequested;

  @override
  State<_ManualPurePanel> createState() => _ManualPurePanelState();
}

class _ManualPurePanelState extends State<_ManualPurePanel> {
  static const _durations = <String>['1h', '2h', '3h', 'hold'];
  static const _saveDelay = Duration(milliseconds: 500);
  Timer? _saveTimer;
  late int _draftIndex;
  bool _savePending = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draftIndex = _durations.indexOf(widget.data.manualPureDuration);
    if (_draftIndex < 0) _draftIndex = 0;
  }

  @override
  void didUpdateWidget(covariant _ManualPurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_savePending && !_saving) {
      final index = _durations.indexOf(widget.data.manualPureDuration);
      _draftIndex = index < 0 ? 0 : index;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<bool> _commit(
    String key,
    DashboardData Function(DashboardData current) change,
  ) async {
    if (_saving) return false;
    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(key, change);
    if (mounted) setState(() => _saving = false);
    return saved;
  }

  void _preview(int index) {
    setState(() => _draftIndex = index.clamp(0, 3).toInt());
    _savePending = true;
    _saveTimer?.cancel();
  }

  void _queue(int delta) {
    final next = (_draftIndex + delta).clamp(0, 3).toInt();
    if (next == _draftIndex) return;
    setState(() => _draftIndex = next);
    _savePending = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flush);
  }

  Future<void> _flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_savePending || _saving) return;
    _savePending = false;
    final value = _durations[_draftIndex];
    await _commit(
      'manual-pure-duration',
      (current) => current.copyWith(manualPureDuration: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = widget.data.pureEnabled;
    final value = _durations[_draftIndex];
    return _WholeHomePanelFrame(
      panel: _WholeHomeControlSurface(
        keyPrefix: 'manual-pure',
        title: l10n.manualDuration,
        themeColor: const Color(0xFF10BDCD),
        enabled: enabled,
        saving: _saving,
        valueIndex: _draftIndex,
        maxIndex: 3,
        valueText: value == 'hold' ? l10n.manualHold : value.substring(0, 1),
        // Figma 68:3469/68:3556：超净时长值全局 y=557.5。
        valueTop: 243.5,
        valueFontSize: value == 'hold' ? 112 : null,
        unit: value == 'hold' ? null : 'h',
        minLabel: '1h',
        maxLabel: l10n.manualHold,
        onToggle: _saving
            ? null
            : (next) async {
                if (_saving) return;
                setState(() => _saving = true);
                await widget.onSetPurePower(next);
                if (mounted) setState(() => _saving = false);
              },
        onPreviewChanged: enabled && !_saving ? _preview : null,
        onChangeEnd: enabled && !_saving ? _flush : null,
        onMinus: enabled && !_saving ? () => _queue(-1) : null,
        onPlus: enabled && !_saving ? () => _queue(1) : null,
        onExitRequested: widget.onExitRequested,
      ),
    );
  }
}

class _WholeHomePanelFrame extends StatelessWidget {
  const _WholeHomePanelFrame({required this.panel});

  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1920,
      height: 1200,
      child: Stack(
        children: <Widget>[
          Positioned(left: 400, top: 212, child: panel),
        ],
      ),
    );
  }
}

/// 手动模式详情页的独立挂载边界。
///
/// 定时/调节页进入后不再把主卡片树叠在下面；主卡片和它的图片、局部
/// 状态会从树中移除，只保留手动页的公共导航和当前详情页。返回时由
/// 对应面板重新创建主卡片。
class _ManualStandaloneDetail extends StatelessWidget {
  const _ManualStandaloneDetail({required this.detail});

  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1920,
      height: 1200,
      child: Stack(
        children: <Widget>[
          // 调节/定时详情页覆盖手动页时，底层左侧导航仍然存在于
          // Widget 树中。透明拦截区只覆盖底层导航和旧返回区，避免
          // 点击穿透切换设备；详情页自身从 x=160 开始，仍可正常操作。
          const Positioned(
            left: 0,
            top: 0,
            width: 400,
            height: 1200,
            child: AbsorbPointer(
              child: SizedBox.expand(),
            ),
          ),
          Positioned(left: 160, top: 100, child: detail),
        ],
      ),
    );
  }
}

class _WholeHomeControlSurface extends StatelessWidget {
  const _WholeHomeControlSurface({
    required this.keyPrefix,
    required this.title,
    required this.themeColor,
    required this.enabled,
    required this.saving,
    required this.valueIndex,
    required this.maxIndex,
    required this.valueText,
    required this.valueTop,
    required this.minLabel,
    required this.maxLabel,
    required this.onToggle,
    required this.onPreviewChanged,
    required this.onChangeEnd,
    required this.onMinus,
    required this.onPlus,
    this.unit,
    this.valueFontSize,
    this.timerSummary,
    this.onTimer,
    this.bottomLabel,
    this.bottomValue,
    this.bottomMenuVisible = false,
    this.bottomMenuValues = const <String>[],
    this.bottomMenuDisplay,
    this.onBottomTap,
    this.onBottomMenuSelected,
    this.onExitRequested,  // 右上角开关操作时触发的退出确认
  });

  final String keyPrefix;
  final String title;
  final Color themeColor;
  final bool enabled;
  final bool saving;
  final int valueIndex;
  final int maxIndex;
  final String valueText;
  final double valueTop;
  final String? unit;
  final double? valueFontSize;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<int>? onPreviewChanged;
  final VoidCallback? onChangeEnd;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? timerSummary;
  final VoidCallback? onTimer;
  final String? bottomLabel;
  final String? bottomValue;
  final bool bottomMenuVisible;
  final List<String> bottomMenuValues;
  final String Function(String value)? bottomMenuDisplay;
  final VoidCallback? onBottomTap;
  final ValueChanged<String>? onBottomMenuSelected;
  final void Function(VoidCallback onConfirm)? onExitRequested;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('$keyPrefix-whole-home'),
      width: 1470,
      height: 924,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ManualFrameBackground()),
          Positioned(
            right: 32,
            top: 32,
            child: _PrototypeToggleSwitch(
              toggleKey: ValueKey<String>('$keyPrefix-power'),
              value: enabled,
              onChanged: onExitRequested != null
                  ? (value) {
                      if (enabled) {
                        // 从开→关：显示退出确认弹窗，确认后执行关闭操作
                        onExitRequested!(onToggle != null ? () => onToggle!(false) : () {});
                      } else if (onToggle != null) {
                        // 从关→开：直接执行开关操作
                        onToggle!(value);
                      }
                    }
                  : onToggle,
            ),
          ),
          Positioned.fill(
            child: Opacity(
              key: ValueKey<String>('$keyPrefix-controls-opacity'),
              opacity: enabled ? 1 : .3,
              child: Stack(
                children: <Widget>[
                  if (timerSummary != null)
                    Positioned(
                      left: 52,
                      top: 36,
                      child: GestureDetector(
                        key: ValueKey<String>('$keyPrefix-timer'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onTimer,
                        child: SizedBox(
                          height: 42,
                          child: Row(
                            children: <Widget>[
                              const _AirTimerGlyph(),
                              const SizedBox(width: 12),
                              Text(timerSummary!, style: _airTimerStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 505 - semicircleGaugeHitPadding,
                    top: 102,
                    child: SemicircleGauge(
                      gaugeKey: ValueKey<String>('$keyPrefix-gauge'),
                      title: title,
                      titleStyle: _wholeHomeGaugeTitleStyle,
                      value: valueText,
                      valueKey: ValueKey<String>('$keyPrefix-value'),
                      valueStyle: _wholeHomeGaugeValueStyle.copyWith(
                        fontSize: valueFontSize ?? _wholeHomeGaugeValueFontSize,
                      ),
                      valueTop: valueTop +
                          (_wholeHomeGaugeValueFontSize -
                                  (valueFontSize ??
                                      _wholeHomeGaugeValueFontSize)) /
                              2,
                      unit: unit,
                      unitStyle: _wholeHomeGaugeUnitStyle,
                      currentValue: valueIndex,
                      minValue: 0,
                      maxValue: maxIndex,
                      minLabel: minLabel,
                      maxLabel: maxLabel,
                      endpointStyle:
                          _floorHeatEndpointStyle.copyWith(color: themeColor),
                      trackColor: themeColor.withOpacity(.30),
                      activeColor: themeColor.withOpacity(.72),
                      dotColor: themeColor,
                      interactionEnabled: enabled && !saving,
                      onPreviewChanged: onPreviewChanged,
                      onInteractionEnd: onChangeEnd,
                    ),
                  ),
                  if (onMinus != null || onPlus != null)
                    Positioned(
                      left: 604,
                      top: 596,
                      child: HorizontalStepper(
                        key: ValueKey<String>('$keyPrefix-stepper'),
                        keyPrefix: keyPrefix,
                        // 写 settings 时只锁操作，不切到设备关闭图，避免
                        // 500ms 防抖保存开始和结束各闪一次。
                        enabled: enabled,
                        interactionEnabled: enabled && !saving,
                        onMinus: onMinus ?? () {},
                        onPlus: onPlus ?? () {},
                      ),
                    ),
                  if (bottomLabel != null && bottomValue != null) ...<Widget>[
                    Positioned(
                      left: 604,
                      top: 787,
                      child: Text(
                        bottomLabel!,
                        style: _airColumnTitleStyle.copyWith(
                          fontSize: 32,
                          color: const Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 668,
                      top: 776,
                      width: 232,
                      height: 61,
                      child: GestureDetector(
                        key: ValueKey<String>('$keyPrefix-bottom-control'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onBottomTap,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  bottomValue!,
                                  key: ValueKey<String>(
                                    '$keyPrefix-bottom-value',
                                  ),
                                  // Figma 68:2304：底部当前值是 Regular 42，
                                  // 不是滚轮焦点使用的 Bold 50。
                                  style: _airSelectionStyle.copyWith(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w400,
                                    fontVariations:
                                        AppFonts.sourceHanSansScRegularWght400,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Text(
                                  bottomMenuVisible ? '‹' : '›',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: AppFonts.harmonyRegular,
                                    fontSize: 38,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (bottomMenuVisible)
                      Positioned(
                        left: 950,
                        top: 730,
                        child: Material(
                          color: const Color(0xFF050505),
                          child: Container(
                            width: 258,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0x99FFFFFF),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: bottomMenuValues
                                  .map(
                                    (value) => InkWell(
                                      onTap: () =>
                                          onBottomMenuSelected?.call(value),
                                      child: SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: Text(
                                            bottomMenuDisplay?.call(value) ??
                                                value,
                                            style: _airSelectionStyle.copyWith(
                                              fontSize: 32,
                                              color: (bottomMenuDisplay
                                                              ?.call(value) ??
                                                          value) ==
                                                      bottomValue
                                                  ? const Color(0xFF36C4E1)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WholeHomeTimerPage extends StatefulWidget {
  const _WholeHomeTimerPage({
    required this.title,
    required this.toggleKey,
    required this.timerEnabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.repeat,
    required this.saving,
    required this.onBack,
    required this.onTimerEnabledChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRepeatChanged,
    this.mode,
    this.fanLevel,
    this.humidity,
    this.onModeChanged,
    this.onFanChanged,
    this.onHumidityChanged,
    this.timeFormat = '24h',
  });

  final String title;
  final Key toggleKey;
  final bool timerEnabled;
  final int startMinutes;
  final int endMinutes;
  final String repeat;
  final String? mode;
  final String? fanLevel;
  final int? humidity;
  final bool saving;
  final VoidCallback onBack;
  final ValueChanged<bool> onTimerEnabledChanged;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final ValueChanged<String> onRepeatChanged;
  final ValueChanged<String>? onModeChanged;
  final ValueChanged<String>? onFanChanged;
  final ValueChanged<int>? onHumidityChanged;
  final String timeFormat;

  @override
  State<_WholeHomeTimerPage> createState() => _WholeHomeTimerPageState();
}

class _WholeHomeTimerPageState extends State<_WholeHomeTimerPage> {
  final ValueNotifier<bool> _editingStart = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _editingStart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final interactionEnabled = widget.timerEnabled && !widget.saving;
    return _AirDetailShell(
      title: widget.title,
      toggleKey: widget.toggleKey,
      toggleValue: widget.timerEnabled,
      onBack: widget.onBack,
      onPowerChanged: widget.saving ? null : widget.onTimerEnabledChanged,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _editingStart,
            builder: (context, editingStart, _) => Row(
              children: <Widget>[
                _TimeColumn(
                  keyPrefix: '${widget.title}-start',
                  title: l10n.manualTimerOn,
                  enabled: widget.timerEnabled,
                  interactionEnabled: interactionEnabled,
                  active: editingStart,
                  minutes: widget.startMinutes,
                  timeFormat: widget.timeFormat,
                  onTap: () => _editingStart.value = true,
                  onChanged: widget.onStartChanged,
                ),
                const SizedBox(width: 112),
                _TimeColumn(
                  keyPrefix: '${widget.title}-end',
                  title: l10n.manualTimerOff,
                  enabled: widget.timerEnabled,
                  interactionEnabled: interactionEnabled,
                  active: !editingStart,
                  minutes: widget.endMinutes,
                  timeFormat: widget.timeFormat,
                  onTap: () => _editingStart.value = false,
                  onChanged: widget.onEndChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 112),
          _FiniteWheelPicker<String>(
            pickerKey: ValueKey<String>('${widget.title}-repeat'),
            title: l10n.manualRepeat,
            values: const <String>['once', 'weekdays', 'daily', 'off'],
            selected: widget.repeat,
            display: (value) => _repeatText(value, l10n),
            enabled: widget.timerEnabled,
            interactionEnabled: interactionEnabled,
            onChanged: widget.onRepeatChanged,
          ),
          if (widget.mode != null) ...<Widget>[
            const SizedBox(width: 112),
            _FiniteWheelPicker<String>(
              pickerKey: ValueKey<String>('${widget.title}-mode'),
              title: l10n.manualMode,
              values: const <String>[
                'internal_circulation',
                'full_heat_exchange',
                'auto',
              ],
              selected: widget.mode!,
              display: (value) => _freshAirModeText(value, l10n),
              enabled: widget.timerEnabled,
              interactionEnabled: interactionEnabled,
              onChanged: widget.onModeChanged,
            ),
          ],
          if (widget.fanLevel != null) ...<Widget>[
            const SizedBox(width: 112),
            _FiniteWheelPicker<String>(
              pickerKey: ValueKey<String>('${widget.title}-fan'),
              title: l10n.manualFanSpeed,
              values: _timerFanLevels(widget.mode),
              selected: widget.fanLevel!,
              display: (value) => _fanText(value, l10n),
              enabled: widget.timerEnabled,
              interactionEnabled: interactionEnabled,
              onChanged: widget.onFanChanged,
            ),
          ],
          if (widget.humidity != null) ...<Widget>[
            const SizedBox(width: 112),
            _FiniteWheelPicker<int>(
              pickerKey: ValueKey<String>('${widget.title}-humidity'),
              title: l10n.metricHumidity,
              values: List<int>.generate(41, (index) => index + 30),
              selected: widget.humidity!,
              display: (value) => '$value',
              selectedSuffix: '%',
              enabled: widget.timerEnabled,
              interactionEnabled: interactionEnabled,
              onChanged: widget.onHumidityChanged,
            ),
          ],
        ],
      ),
    );
  }
}

enum _FloorHeatView { overview, timer }

class _ManualFloorHeatPanel extends StatefulWidget {
  const _ManualFloorHeatPanel({
    required this.data,
    required this.controlMode,
    required this.onCommitSettingsChange,
    this.onExitRequested,
  });

  final DashboardData data;
  final String controlMode;
  final CommitManualSettings onCommitSettingsChange;
  final VoidCallback? onExitRequested;

  @override
  State<_ManualFloorHeatPanel> createState() => _ManualFloorHeatPanelState();
}

class _ManualFloorHeatPanelState extends State<_ManualFloorHeatPanel> {
  _FloorHeatView _view = _FloorHeatView.overview;
  String? _activeDeviceId;
  String? _activeRoomName;
  ManualFloorHeatSetting? _draftSetting;
  bool _draftDirty = false;
  bool _saving = false;

  ManualFloorHeatSetting _settingFor(String deviceId) {
    for (final setting in widget.data.manualFloorHeatSettings) {
      if (setting.deviceId == deviceId) {
        return setting;
      }
    }
    return ManualFloorHeatSetting(
      deviceId: deviceId,
      enabled: false,
      targetTemperatureC: 26,
      timerEnabled: false,
      timerStartMinutes: 18 * 60,
      timerEndMinutes: 22 * 60,
      timerRepeat: 'once',
    );
  }

  Future<void> _updateSetting(
    String deviceId,
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    await widget.onCommitSettingsChange(
      'manual-floor-heat-$deviceId',
      (current) {
        var found = false;
        final settings = current.manualFloorHeatSettings.map((setting) {
          if (setting.deviceId != deviceId) {
            return setting;
          }
          found = true;
          return change(setting);
        }).toList(growable: true);
        if (!found) {
          settings.add(change(_settingFor(deviceId)));
        }
        return current.copyWith(manualFloorHeatSettings: settings);
      },
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  void _openTimer(FloorHeatZoneSnapshot zone) {
    setState(() {
      _activeDeviceId = zone.deviceId;
      _activeRoomName = zone.roomName;
      _draftSetting = _settingFor(zone.deviceId);
      _draftDirty = false;
      _view = _FloorHeatView.timer;
    });
  }

  void _updateDraft(
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) {
    if (_saving || _draftSetting == null) {
      return;
    }
    setState(() {
      _draftSetting = change(_draftSetting!);
      _draftDirty = true;
    });
  }

  Future<void> _saveDraftAndClose() async {
    if (_saving) {
      return;
    }
    final draft = _draftSetting;
    if (draft == null || !_draftDirty) {
      setState(() {
        _view = _FloorHeatView.overview;
        _activeDeviceId = null;
        _activeRoomName = null;
        _draftSetting = null;
      });
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(
      'manual-floor-heat-timer-${draft.deviceId}',
      (current) {
        var found = false;
        final settings = current.manualFloorHeatSettings.map((setting) {
          if (setting.deviceId != draft.deviceId) {
            return setting;
          }
          found = true;
          return draft;
        }).toList(growable: true);
        if (!found) {
          settings.add(draft);
        }
        return current.copyWith(manualFloorHeatSettings: settings);
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (saved) {
        _view = _FloorHeatView.overview;
        _activeDeviceId = null;
        _activeRoomName = null;
        _draftSetting = null;
        _draftDirty = false;
      }
    });
  }

  Widget _buildOverview() {
    if (widget.controlMode == 'whole_home') {
      final setting = _settingFor(DashboardData.wholeHomeFloorHeatDeviceId);
      return _WholeHomeFloorHeatPage(
        setting: setting,
        saving: _saving,
        onChanged: (change) => _updateSetting(setting.deviceId, change),
        onExitRequested: widget.onExitRequested,
      );
    }
    final visibleZones = widget.data.floorHeatZones.take(16).toList(
          growable: false,
        );
    return _ZonedFloorHeatPage(
      zones: visibleZones,
      settings: <String, ManualFloorHeatSetting>{
        for (final zone in visibleZones)
          zone.deviceId: _settingFor(zone.deviceId),
      },
      saving: _saving,
      onOpenTimer: _openTimer,
      onChanged: _updateSetting,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_view == _FloorHeatView.timer) {
      final timerDraft = _draftSetting;
      if (timerDraft != null && _activeDeviceId == timerDraft.deviceId) {
        return _ManualStandaloneDetail(
          detail: _FloorHeatTimerPage(
            roomName: _activeRoomName ?? l10n.manualRoom,
            setting: timerDraft,
            saving: _saving,
            timeFormat: widget.data.timeFormat,
            onBack: _saveDraftAndClose,
            onChanged: _updateDraft,
          ),
        );
      }
    }
    return SizedBox(
      width: 1920,
      height: 1200,
      child: Stack(
        children: <Widget>[
          Positioned(left: 400, top: 212, child: _buildOverview()),
        ],
      ),
    );
  }
}

class _ZonedFloorHeatPage extends StatefulWidget {
  const _ZonedFloorHeatPage({
    required this.zones,
    required this.settings,
    required this.saving,
    required this.onOpenTimer,
    required this.onChanged,
  });

  final List<FloorHeatZoneSnapshot> zones;
  final Map<String, ManualFloorHeatSetting> settings;
  final bool saving;
  final ValueChanged<FloorHeatZoneSnapshot> onOpenTimer;
  final Future<void> Function(
    String deviceId,
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) onChanged;

  @override
  State<_ZonedFloorHeatPage> createState() => _ZonedFloorHeatPageState();
}

class _ZonedFloorHeatPageState extends State<_ZonedFloorHeatPage> {
  late final PageController _pageController;
  int _pageIndex = 0;
  final Set<int> _resourceWindow = <int>{};
  final Map<String, int> _assetPageReferences = <String, int>{};
  int _resourceWindowRequestSerial = 0;
  bool _initialPagePreparing = false;
  bool _initialPageReady = false;

  static const List<String> _pageAssets = <String>[
    'assets/manual/fh-cardbg.png',
    'assets/manual/fh-cardbg-off.png',
    'assets/manual/vertical_stepper_on.png',
    'assets/manual/vertical_stepper_off.png',
    'assets/manual/vertical_stepper_press_up.png',
    'assets/manual/vertical_stepper_press_down.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_prepareInitialPage(context));
      }
    });
  }

  Future<void> _prepareInitialPage(BuildContext context) async {
    if (_initialPagePreparing || _initialPageReady) {
      return;
    }
    _initialPagePreparing = true;
    // 导航层已经完成了目标设备的首屏资源门槛；这里先只保留第 1 页。
    // 相邻页必须等旧子页被替换、当前首帧稳定后才进入窗口。
    _updatePageResourceWindow(context, 0, 1);
    if (!mounted) {
      return;
    }
    _initialPagePreparing = false;
    _initialPageReady = true;
    // 让第 1 页先完成一次布局/绘制，再决定是否存在并预热第 2 页。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _schedulePageResourceWindow(context, 0, _pageCount);
      }
    });
  }

  List<FloorHeatZoneSnapshot> get _visibleZones =>
      widget.zones.take(16).toList(growable: false);

  int get _pageCount => math.max(1, (_visibleZones.length / 4).ceil());

  bool _runtimeDevicesChanged(
    List<FloorHeatZoneSnapshot> previous,
    List<FloorHeatZoneSnapshot> next,
  ) {
    final oldVisible = previous.take(16).toList(growable: false);
    final newVisible = next.take(16).toList(growable: false);
    if (oldVisible.length != newVisible.length) {
      return true;
    }
    for (var index = 0; index < oldVisible.length; index++) {
      if (oldVisible[index].toJson().toString() !=
          newVisible[index].toJson().toString()) {
        return true;
      }
    }
    return false;
  }

  List<String> _assetsForPage(int page) => _pageAssets;

  void _updatePageResourceWindow(
    BuildContext context,
    int page,
    int pageCount,
  ) {
    // 资源窗口始终是“当前页 + 前后相邻页”。例如从第 2 页滑到第 3
    // 页时，窗口由 {1,2,3} 变为 {2,3,4}：先释放第 1 页，再预热第 4 页。
    final nextWindow = <int>{page - 1, page, page + 1}
      ..removeWhere((value) => value < 0 || value >= pageCount);
    final pagesToRelease = _resourceWindow.difference(nextWindow).toList();
    final pagesToPrepare = nextWindow.difference(_resourceWindow).toList();

    for (final oldPage in pagesToRelease) {
      _releasePageResources(oldPage);
    }
    for (final newPage in pagesToPrepare) {
      _retainPageResources(newPage);
    }
    _resourceWindow
      ..clear()
      ..addAll(nextWindow);

    final assetsToPrecache = <String>{};
    for (final newPage in pagesToPrepare) {
      for (final asset in _assetsForPage(newPage)) {
        if ((_assetPageReferences[asset] ?? 0) == 1) {
          assetsToPrecache.add(asset);
        }
      }
    }
    if (assetsToPrecache.isNotEmpty) {
      unawaited(Future.wait(
        assetsToPrecache.map(
          (asset) => precacheImage(AssetImage(asset), context),
        ),
      ).catchError((Object error) {
        AppLogger.instance.w(
          '地暖相邻页资源预加载失败',
          tag: 'ManualPage',
          error: error,
        );
      }));
    }
  }

  void _retainPageResources(int page) {
    for (final asset in _assetsForPage(page)) {
      _assetPageReferences[asset] = (_assetPageReferences[asset] ?? 0) + 1;
    }
  }

  void _releasePageResources(int page) {
    for (final asset in _assetsForPage(page)) {
      final references = (_assetPageReferences[asset] ?? 1) - 1;
      if (references <= 0) {
        _assetPageReferences.remove(asset);
        imageCache.evict(AssetImage(asset), includeLive: false);
      } else {
        _assetPageReferences[asset] = references;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ZonedFloorHeatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPageCount = _pageCount;
    final devicesChanged = _runtimeDevicesChanged(
      oldWidget.zones,
      widget.zones,
    );
    if (devicesChanged) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    } else if (_pageIndex >= nextPageCount) {
      _pageIndex = nextPageCount - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _initialPageReady) {
        _schedulePageResourceWindow(context, _pageIndex, nextPageCount);
      }
    });
  }

  void _schedulePageResourceWindow(
    BuildContext context,
    int page,
    int pageCount,
  ) {
    final requestSerial = ++_resourceWindowRequestSerial;
    // 分页状态改变不等于新页已经完成首帧。等这一帧提交后，才释放
    // 离开窗口的旧页，再异步预热相邻页；快速滑动时旧请求自动失效。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestSerial != _resourceWindowRequestSerial) {
        return;
      }
      _updatePageResourceWindow(context, page, pageCount);
    });
  }

  @override
  void dispose() {
    _resourceWindowRequestSerial++;
    for (final page in _resourceWindow.toList()) {
      _releasePageResources(page);
    }
    _resourceWindow.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return SizedBox(
      key: const ValueKey<String>('manual-floor-heat-zoned'),
      width: 1470,
      height: 924,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ManualFrameBackground()),
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey<String>('manual-floor-heat-pages'),
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (value) {
                setState(() => _pageIndex = value);
                if (_initialPageReady) {
                  _schedulePageResourceWindow(context, value, pageCount);
                }
              },
              itemBuilder: (context, page) {
                final start = page * 4;
                final end = math.min(start + 4, _visibleZones.length);
                final pageZones = _visibleZones.sublist(start, end);
                return Stack(
                  children: <Widget>[
                    for (var index = 0; index < pageZones.length; index++)
                      Positioned(
                        left: index.isEven ? 64 : 768,
                        top: index < 2 ? 34 : 482,
                        child: _FloorHeatZoneCard(
                          zone: pageZones[index],
                          setting: widget.settings[pageZones[index].deviceId]!,
                          disabled: widget.saving,
                          onOpenTimer: () =>
                              widget.onOpenTimer(pageZones[index]),
                          onChanged: (change) => widget.onChanged(
                            pageZones[index].deviceId,
                            change,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (pageCount > 1)
            Positioned(
              left: _pageDotsLeft(pageCount),
              bottom: 20,
              child: _PageDots(
                activeIndex: _pageIndex,
                count: pageCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _FloorHeatZoneCard extends StatefulWidget {
  const _FloorHeatZoneCard({
    required this.zone,
    required this.setting,
    required this.disabled,
    required this.onOpenTimer,
    required this.onChanged,
  });

  final FloorHeatZoneSnapshot zone;
  final ManualFloorHeatSetting setting;
  final bool disabled;
  final VoidCallback onOpenTimer;
  final Future<void> Function(
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) onChanged;

  @override
  State<_FloorHeatZoneCard> createState() => _FloorHeatZoneCardState();
}

class _FloorHeatZoneCardState extends State<_FloorHeatZoneCard> {
  static const Duration _stepSaveDelay = Duration(milliseconds: 500);

  late int _draftTemperatureC;
  Timer? _stepSaveTimer;
  bool _saveInFlight = false;
  bool _savePending = false;

  @override
  void initState() {
    super.initState();
    _draftTemperatureC = widget.setting.targetTemperatureC;
  }

  @override
  void didUpdateWidget(covariant _FloorHeatZoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_savePending &&
        !_saveInFlight &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      _draftTemperatureC = widget.setting.targetTemperatureC;
    }
  }

  @override
  void dispose() {
    _stepSaveTimer?.cancel();
    super.dispose();
  }

  void _queueTemperatureStep(int delta) {
    final next = (_draftTemperatureC + delta).clamp(16, 30).toInt();
    if (next == _draftTemperatureC) {
      return;
    }
    setState(() => _draftTemperatureC = next);
    _savePending = true;
    _stepSaveTimer?.cancel();
    _stepSaveTimer = Timer(_stepSaveDelay, _flushTemperatureSave);
  }

  Future<void> _flushTemperatureSave() async {
    _stepSaveTimer?.cancel();
    _stepSaveTimer = null;
    if (_saveInFlight || !_savePending) {
      return;
    }
    final value = _draftTemperatureC;
    _savePending = false;
    _saveInFlight = true;
    await widget.onChanged(
      (current) => current.copyWith(targetTemperatureC: value),
    );
    _saveInFlight = false;
    if (_savePending && mounted) {
      _stepSaveTimer = Timer(Duration.zero, _flushTemperatureSave);
    } else if (mounted &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      setState(
        () => _draftTemperatureC = widget.setting.targetTemperatureC,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final zone = widget.zone;
    final setting = widget.setting;
    final interactive = zone.online && !widget.disabled;
    final active = zone.online && setting.enabled;
    final stepperEnabled = zone.online && setting.enabled;
    return Opacity(
      // fh-cardbg-off.png 已经包含关闭态透明度；这里只处理设备离线。
      opacity: zone.online ? 1 : .28,
      child: Container(
        width: 639,
        height: 384,
        decoration: BoxDecoration(
          // 关闭态背景切图带透明度，Figma 按 #191919 底色合成。
          // 使用纯黑会让关闭态约 85% 的透明区域被再次压暗。
          color: const Color(0xFF191919),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  active
                      ? 'assets/manual/fh-cardbg.png'
                      : 'assets/manual/fh-cardbg-off.png',
                  key: ValueKey<String>(
                    'manual-floor-${zone.deviceId}-background',
                  ),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                // 关闭态素材只负责背景；文字、数值和操作控件沿用原来的
                // 关闭亮度，避免再次衰减背景导致暖色消失。
                opacity: active ? 1 : .34,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 46,
                      top: 30,
                      child: Text(zone.roomName, style: _airRoomStyle),
                    ),
                    if (!zone.online)
                      Positioned(
                        left: 48,
                        top: 94,
                        child: Text(l10n.offline, style: _airSmallStyle),
                      ),
                    Positioned(
                      left: _roomCardTemperatureLeft,
                      top: _roomCardTemperatureTop,
                      child: Text(
                        '$_draftTemperatureC',
                        key: ValueKey<String>(
                          'manual-floor-${zone.deviceId}-temperature-value',
                        ),
                        style: _airTemperatureStyle,
                      ),
                    ),
                    const Positioned(
                      left: _roomCardTemperatureUnitLeft,
                      top: _roomCardTemperatureUnitTop,
                      child: Text('℃', style: _airUnitStyle),
                    ),
                    Positioned(
                      right: 46,
                      top: 128,
                      width: 68,
                      height: 198,
                      child: VerticalStepper(
                        keyPrefix: 'manual-floor-${zone.deviceId}-temperature',
                        enabled: stepperEnabled,
                        // 同组保存时只锁输入，不能切换成禁用图造成闪烁。
                        interactionEnabled: !widget.disabled,
                        onPlus: () => _queueTemperatureStep(1),
                        onMinus: () => _queueTemperatureStep(-1),
                      ),
                    ),
                    Positioned(
                      left: _roomCardTimerLeft,
                      top: _roomCardTimerTop,
                      width: _roomCardTimerWidth,
                      height: _roomCardTimerHeight,
                      child: _AirTapArea(
                        keyName: 'manual-floor-${zone.deviceId}-timer',
                        onTap: interactive && active
                            ? () async {
                                await _flushTemperatureSave();
                                widget.onOpenTimer();
                              }
                            : null,
                        child: Row(
                          children: <Widget>[
                            const _AirTimerGlyph(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _floorTimerSummary(setting, l10n),
                                  style: _airTimerStyle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 32,
              top: 32,
              child: _PrototypeToggleSwitch(
                toggleKey:
                    ValueKey<String>('manual-floor-${zone.deviceId}-power'),
                value: setting.enabled,
                onChanged: interactive
                    ? (value) async {
                        await _flushTemperatureSave();
                        await widget.onChanged(
                          (current) => current.copyWith(enabled: value),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorHeatTimerPage extends StatefulWidget {
  const _FloorHeatTimerPage({
    required this.roomName,
    required this.setting,
    required this.saving,
    required this.onBack,
    required this.onChanged,
    this.timeFormat = '24h',
  });

  final String roomName;
  final ManualFloorHeatSetting setting;
  final bool saving;
  final VoidCallback onBack;
  final void Function(
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) onChanged;
  final String timeFormat;

  @override
  State<_FloorHeatTimerPage> createState() => _FloorHeatTimerPageState();
}

class _FloorHeatTimerPageState extends State<_FloorHeatTimerPage> {
  final ValueNotifier<bool> _editingStart = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _editingStart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = widget.setting;
    final enabled = setting.timerEnabled;
    final interactionEnabled = enabled && !widget.saving;
    return _AirDetailShell(
      title: l10n.floorHeatRoomTimerTitle(widget.roomName),
      toggleKey: const ValueKey<String>('manual-floor-timer-enabled'),
      toggleValue: enabled,
      onBack: widget.onBack,
      onPowerChanged: widget.saving
          ? null
          : (value) => widget.onChanged(
                (current) => current.copyWith(timerEnabled: value),
              ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _editingStart,
            builder: (context, editingStart, _) => Row(
              children: <Widget>[
                _TimeColumn(
                  keyPrefix: 'manual-floor-timer-start',
                  title: l10n.manualTimerOn,
                  enabled: enabled,
                  interactionEnabled: interactionEnabled,
                  active: editingStart,
                  minutes: setting.timerStartMinutes,
                  timeFormat: widget.timeFormat,
                  onTap: () => _editingStart.value = true,
                  onChanged: (value) => widget.onChanged(
                    (current) => current.copyWith(timerStartMinutes: value),
                  ),
                ),
                const SizedBox(width: 72),
                _TimeColumn(
                  keyPrefix: 'manual-floor-timer-end',
                  title: l10n.manualTimerOff,
                  enabled: enabled,
                  interactionEnabled: interactionEnabled,
                  active: !editingStart,
                  minutes: setting.timerEndMinutes,
                  timeFormat: widget.timeFormat,
                  onTap: () => _editingStart.value = false,
                  onChanged: (value) => widget.onChanged(
                    (current) => current.copyWith(timerEndMinutes: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 72),
          _FiniteWheelPicker<String>(
            pickerKey:
                const ValueKey<String>('manual-floor-timer-repeat-wheel'),
            title: l10n.manualRepeat,
            values: const <String>['once', 'weekdays', 'daily', 'off'],
            selected: setting.timerRepeat,
            display: (value) => _repeatText(value, l10n),
            enabled: enabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(timerRepeat: value),
            ),
          ),
          const SizedBox(width: 72),
          _FiniteWheelPicker<int>(
            pickerKey: const ValueKey<String>(
              'manual-floor-timer-temperature-wheel',
            ),
            title: l10n.metricTemperature,
            values: const <int>[
              16,
              17,
              18,
              19,
              20,
              21,
              22,
              23,
              24,
              25,
              26,
              27,
              28,
              29,
              30,
            ],
            selected: setting.targetTemperatureC,
            display: (value) => '$value',
            selectedSuffix: ' ℃',
            enabled: enabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(targetTemperatureC: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _WholeHomeFloorHeatPage extends StatefulWidget {
  const _WholeHomeFloorHeatPage({
    required this.setting,
    required this.saving,
    required this.onChanged,
    this.onExitRequested,
  });

  final ManualFloorHeatSetting setting;
  final bool saving;
  final Future<void> Function(
    ManualFloorHeatSetting Function(ManualFloorHeatSetting current) change,
  ) onChanged;
  final VoidCallback? onExitRequested;

  @override
  State<_WholeHomeFloorHeatPage> createState() =>
      _WholeHomeFloorHeatPageState();
}

class _WholeHomeFloorHeatPageState extends State<_WholeHomeFloorHeatPage> {
  static const Duration _stepSaveDelay = Duration(milliseconds: 500);

  bool _repeatMenuVisible = false;
  late int _draftTemperatureC;
  bool _temperatureDragging = false;
  Timer? _temperatureStepSaveTimer;
  bool _temperatureSaveInFlight = false;
  bool _temperatureSavePending = false;

  @override
  void initState() {
    super.initState();
    _draftTemperatureC = widget.setting.targetTemperatureC;
  }

  @override
  void didUpdateWidget(covariant _WholeHomeFloorHeatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_temperatureDragging &&
        !_temperatureSavePending &&
        !_temperatureSaveInFlight &&
        !widget.saving &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      _draftTemperatureC = widget.setting.targetTemperatureC;
    }
  }

  @override
  void dispose() {
    _temperatureStepSaveTimer?.cancel();
    super.dispose();
  }

  void _previewTemperature(int value) {
    setState(() {
      _temperatureDragging = true;
      _draftTemperatureC = value.clamp(16, 30).toInt();
    });
  }

  void _queueTemperatureStep(int delta) {
    final next = (_draftTemperatureC + delta).clamp(16, 30).toInt();
    if (next == _draftTemperatureC) {
      return;
    }
    setState(() => _draftTemperatureC = next);
    _temperatureSavePending = true;
    _temperatureStepSaveTimer?.cancel();
    _temperatureStepSaveTimer = Timer(
      _stepSaveDelay,
      _flushTemperatureSave,
    );
  }

  Future<void> _saveTemperatureImmediately(int value) async {
    final next = value.clamp(16, 30).toInt();
    setState(() => _draftTemperatureC = next);
    _temperatureSavePending = true;
    _temperatureStepSaveTimer?.cancel();
    await _flushTemperatureSave();
  }

  Future<void> _flushTemperatureSave() async {
    _temperatureStepSaveTimer?.cancel();
    _temperatureStepSaveTimer = null;
    if (_temperatureSaveInFlight || !_temperatureSavePending) {
      return;
    }
    final value = _draftTemperatureC;
    _temperatureSavePending = false;
    _temperatureSaveInFlight = true;
    await widget.onChanged(
      (current) => current.copyWith(targetTemperatureC: value),
    );
    _temperatureSaveInFlight = false;
    if (_temperatureSavePending && mounted) {
      _temperatureStepSaveTimer = Timer(
        Duration.zero,
        _flushTemperatureSave,
      );
    } else if (mounted &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      setState(
        () => _draftTemperatureC = widget.setting.targetTemperatureC,
      );
    }
  }

  Future<void> _finishTemperatureDrag() async {
    if (!_temperatureDragging) {
      return;
    }
    final value = _draftTemperatureC;
    _temperatureDragging = false;
    await _saveTemperatureImmediately(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = widget.setting;
    final enabled = setting.enabled;
    return SizedBox(
      key: const ValueKey<String>('manual-floor-heat-whole-home'),
      width: 1470,
      height: 924,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ManualFrameBackground()),
          Positioned(
            // Figma 68:2440: global (1742, 244), 96×48.
            right: 32,
            top: 32,
            child: _PrototypeToggleSwitch(
              toggleKey:
                  const ValueKey<String>('manual-floor-whole-home-power'),
              value: enabled,
              onChanged: widget.saving
                  ? null
                  : widget.onExitRequested != null
                      ? (_) => widget.onExitRequested!()
                      : (value) => widget.onChanged(
                            (current) => current.copyWith(enabled: value),
                          ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              key: const ValueKey<String>(
                'manual-floor-whole-controls-opacity',
              ),
              // 与智能模式禁用态一致：保留地暖橙色和文字的色相，
              // 只降低整个控制层亮度，不把弧线单独替换成中性灰。
              opacity: enabled ? 1 : .3,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    // Figma 68:2471/2473: label y=314, arc 462×231 at (905, 464).
                    left: 505 - semicircleGaugeHitPadding,
                    top: 102,
                    child: SemicircleGauge(
                      gaugeKey: const ValueKey<String>(
                        'manual-floor-whole-temperature-gauge',
                      ),
                      title: l10n.metricTemperature,
                      titleStyle: _wholeHomeGaugeTitleStyle,
                      value: '$_draftTemperatureC',
                      valueStyle: _wholeHomeGaugeValueStyle,
                      // Figma 68:2431/68:2478：全屋地暖数值全局 y=561，
                      // 当前仪表标题全局 y=314，因此局部偏移为 247。
                      valueTop: 243.5,
                      unit: '℃',
                      unitStyle: _wholeHomeGaugeUnitStyle,
                      currentValue: _draftTemperatureC,
                      minValue: 16,
                      maxValue: 30,
                      minLabel: '16',
                      maxLabel: '30',
                      endpointStyle: _floorHeatEndpointStyle,
                      trackColor: const Color(0x4DC97342),
                      activeColor: const Color(0xB3C97342),
                      dotColor: const Color(0xFFC35A2F),
                      interactionEnabled: enabled && !widget.saving,
                      onPreviewChanged: _previewTemperature,
                      onInteractionEnd: _finishTemperatureDrag,
                    ),
                  ),
                  Positioned(
                    // Figma 68:2472: global (1004, 808), 262×90.
                    left: 604,
                    top: 596,
                    child: HorizontalStepper(
                      key: const ValueKey<String>(
                        'manual-floor-whole-temperature-stepper',
                      ),
                      keyPrefix: 'manual-floor-whole-temperature',
                      enabled: enabled,
                      interactionEnabled: enabled &&
                          (!widget.saving || _temperatureSaveInFlight),
                      onPlus: () => _queueTemperatureStep(1),
                      onMinus: () => _queueTemperatureStep(-1),
                    ),
                  ),
                  Positioned(
                    // Figma 68:2475: global (1004, 999).
                    left: 604,
                    top: 787,
                    child: Text(
                      l10n.manualRepeat,
                      style: _airColumnTitleStyle.copyWith(
                        fontSize: 32,
                        color: const Color(0xB3FFFFFF),
                      ),
                    ),
                  ),
                  Positioned(
                    // Figma 68:2476/2477: value starts at global x=1100, y=988.
                    left: 700,
                    top: 776,
                    child: GestureDetector(
                      key: const ValueKey<String>(
                        'manual-floor-whole-repeat',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled && !widget.saving
                          ? () => setState(
                                () => _repeatMenuVisible = !_repeatMenuVisible,
                              )
                          : null,
                      child: SizedBox(
                        width: 168,
                        height: 61,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              _repeatText(setting.timerRepeat, l10n),
                              key: const ValueKey<String>(
                                'manual-floor-whole-repeat-value',
                              ),
                              // Figma 68:2476：全屋地暖循环当前值为
                              // Source Han Sans SC Regular 42。
                              style: _airSelectionStyle.copyWith(
                                fontSize: 42,
                                fontWeight: FontWeight.w400,
                                fontVariations:
                                    AppFonts.sourceHanSansScRegularWght400,
                              ),
                            ),
                            Text(
                              _repeatMenuVisible ? '‹' : '›',
                              key: const ValueKey<String>(
                                'manual-floor-whole-repeat-arrow',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: AppFonts.harmonyRegular,
                                fontSize: 38,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_repeatMenuVisible)
                    Positioned(
                      // Figma 68:2483: global (1307, 942), 258×168.
                      left: 907,
                      top: 730,
                      child: Material(
                        color: const Color(0xFF050505),
                        child: Container(
                          width: 258,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0x99FFFFFF),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <String>['once', 'weekdays', 'daily']
                                .map(
                                  (value) => InkWell(
                                    onTap: () {
                                      setState(
                                        () => _repeatMenuVisible = false,
                                      );
                                      widget.onChanged(
                                        (current) => current.copyWith(
                                          timerRepeat: value,
                                        ),
                                      );
                                    },
                                    child: SizedBox(
                                      height: 56,
                                      child: Center(
                                        child: Text(
                                          _repeatText(value, l10n),
                                          style: _airSelectionStyle.copyWith(
                                            fontSize: 32,
                                            color: value == setting.timerRepeat
                                                ? const Color(0xFF36C4E1)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _floorHeatEndpointStyle = TextStyle(
  color: Color(0xD9C97342),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 30,
);

enum _AirConditionerView { list, adjustment, timer }

class _ManualAirConditionerPanel extends StatefulWidget {
  const _ManualAirConditionerPanel({
    required this.data,
    required this.onCommitSettingsChange,
  });

  final DashboardData data;
  final CommitManualSettings onCommitSettingsChange;

  @override
  State<_ManualAirConditionerPanel> createState() =>
      _ManualAirConditionerPanelState();
}

class _ManualAirConditionerPanelState
    extends State<_ManualAirConditionerPanel> {
  _AirConditionerView _view = _AirConditionerView.list;
  String? _activeDeviceId;
  ManualAirConditionerSetting? _draftSetting;
  bool _draftDirty = false;
  bool _saving = false;

  List<AirConditionerZoneSnapshot> get _visibleRuntimeDevices =>
      widget.data.airConditionerZones.take(16).toList(growable: false);

  ManualAirConditionerSetting _settingFor(String deviceId) {
    for (final setting in widget.data.manualAirConditioners) {
      if (setting.deviceId == deviceId) {
        final zone = _visibleRuntimeDevices.firstWhere(
          (candidate) => candidate.deviceId == deviceId,
          orElse: () => AirConditionerZoneSnapshot(
            deviceId: deviceId,
            roomName: setting.roomName,
            online: true,
          ),
        );
        return setting.copyWith(roomName: zone.roomName);
      }
    }
    final zone = _visibleRuntimeDevices.firstWhere(
      (candidate) => candidate.deviceId == deviceId,
      orElse: () => AirConditionerZoneSnapshot(
        deviceId: deviceId,
        roomName: '房间',
        online: true,
      ),
    );
    return ManualAirConditionerSetting(
      deviceId: zone.deviceId,
      roomName: zone.roomName,
      enabled: false,
      targetTemperatureC: 24,
      mode: 'auto',
      fanLevel: 'auto',
      timerEnabled: false,
      timerStartMinutes: 18 * 60,
      timerEndMinutes: 22 * 60,
      timerRepeat: 'once',
    );
  }

  List<ManualAirConditionerSetting> get _visibleSettings =>
      _visibleRuntimeDevices
          .map((zone) => _settingFor(zone.deviceId))
          .toList(growable: false);

  List<ManualAirConditionerSetting> _replaceAirConditionerSetting(
    List<ManualAirConditionerSetting> current,
    ManualAirConditionerSetting replacement,
  ) {
    var found = false;
    final result = current.map((setting) {
      if (setting.deviceId != replacement.deviceId) {
        return setting;
      }
      found = true;
      return replacement;
    }).toList(growable: true);
    if (!found) {
      result.add(replacement);
    }
    return result;
  }

  ManualAirConditionerSetting? get _activeSetting {
    final draft = _draftSetting;
    if (draft != null && draft.deviceId == _activeDeviceId) {
      return draft;
    }
    final id = _activeDeviceId;
    if (id == null) {
      return null;
    }
    return _settingFor(id);
  }

  void _open(String deviceId, _AirConditionerView view) {
    final setting = _settingFor(deviceId);
    setState(() {
      _activeDeviceId = deviceId;
      _draftSetting = setting;
      _draftDirty = false;
      _view = view;
    });
  }

  void _updateDraft(
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) {
    if (_saving) {
      return;
    }
    final current = _draftSetting;
    if (current == null) {
      return;
    }
    setState(() {
      _draftSetting = change(current);
      _draftDirty = true;
    });
  }

  Future<void> _saveDraftAndClose() async {
    if (_saving) {
      return;
    }
    final draft = _draftSetting;
    if (draft == null || !_draftDirty) {
      setState(() {
        _view = _AirConditionerView.list;
        _activeDeviceId = null;
        _draftSetting = null;
        _draftDirty = false;
      });
      return;
    }

    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(
      'manual-air-conditioner-${draft.deviceId}',
      (current) => current.copyWith(
        manualAirConditioners: _replaceAirConditionerSetting(
          current.manualAirConditioners,
          draft,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (saved) {
        _view = _AirConditionerView.list;
        _activeDeviceId = null;
        _draftSetting = null;
        _draftDirty = false;
      }
    });
  }

  Future<void> _updateDevice(
    String deviceId,
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    await widget.onCommitSettingsChange(
      'manual-air-conditioner-$deviceId',
      (current) {
        ManualAirConditionerSetting? existing;
        for (final setting in current.manualAirConditioners) {
          if (setting.deviceId == deviceId) {
            existing = setting;
            break;
          }
        }
        return current.copyWith(
          manualAirConditioners: _replaceAirConditionerSetting(
            current.manualAirConditioners,
            change(existing ?? _settingFor(deviceId)),
          ),
        );
      },
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeSetting;
    Widget? detail;
    if (_view == _AirConditionerView.adjustment && active != null) {
      detail = _AirAdjustmentPage(
        setting: active,
        saving: _saving,
        onBack: () {
          _saveDraftAndClose();
        },
        onChanged: _updateDraft,
      );
    }
    if (_view == _AirConditionerView.timer && active != null) {
      detail = _AirTimerPage(
        setting: active,
        saving: _saving,
        timeFormat: widget.data.timeFormat,
        onBack: () {
          _saveDraftAndClose();
        },
        onChanged: _updateDraft,
      );
    }
    if (detail != null) {
      return _ManualStandaloneDetail(detail: detail);
    }
    return SizedBox(
      width: 1920,
      height: 1200,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 400,
            top: 212,
            child: _AirConditionerList(
              settings: _visibleSettings,
              runtimeDevices: _visibleRuntimeDevices,
              saving: _saving,
              timeFormat: widget.data.timeFormat,
              onOpenAdjustment: (deviceId) =>
                  _open(deviceId, _AirConditionerView.adjustment),
              onOpenTimer: (deviceId) =>
                  _open(deviceId, _AirConditionerView.timer),
              onChanged: _updateDevice,
            ),
          ),
        ],
      ),
    );
  }
}

class _AirConditionerList extends StatefulWidget {
  const _AirConditionerList({
    required this.settings,
    required this.runtimeDevices,
    required this.saving,
    required this.onOpenAdjustment,
    required this.onOpenTimer,
    required this.onChanged,
    this.timeFormat = '24h',
  });

  final List<ManualAirConditionerSetting> settings;
  final List<AirConditionerZoneSnapshot> runtimeDevices;
  final bool saving;
  final ValueChanged<String> onOpenAdjustment;
  final ValueChanged<String> onOpenTimer;
  final Future<void> Function(
    String deviceId,
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) onChanged;
  final String timeFormat;

  @override
  State<_AirConditionerList> createState() => _AirConditionerListState();
}

class _AirConditionerListState extends State<_AirConditionerList> {
  late final PageController _pageController;
  int _pageIndex = 0;
  final Set<int> _resourceWindow = <int>{};
  final Map<String, int> _assetPageReferences = <String, int>{};
  int _resourceWindowRequestSerial = 0;
  bool _initialPagePreparing = false;
  bool _initialPageReady = false;

  static const List<String> _pageAssets = <String>[
    'assets/manual/ac-cardbg.png',
    'assets/manual/ac-cardbg-off.png',
    'assets/manual/card-空调.png',
    'assets/manual/card-风量.png',
    'assets/manual/vertical_stepper_on.png',
    'assets/manual/vertical_stepper_off.png',
    'assets/manual/vertical_stepper_press_up.png',
    'assets/manual/vertical_stepper_press_down.png',
  ];

  int get _pageCount => math.max(1, (widget.settings.length / 4).ceil());

  bool _runtimeDevicesChanged(
    List<AirConditionerZoneSnapshot> previous,
    List<AirConditionerZoneSnapshot> next,
  ) {
    final oldVisible = previous.take(16).toList(growable: false);
    final newVisible = next.take(16).toList(growable: false);
    if (oldVisible.length != newVisible.length) {
      return true;
    }
    for (var index = 0; index < oldVisible.length; index++) {
      if (oldVisible[index].toJson().toString() !=
          newVisible[index].toJson().toString()) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_prepareInitialPage(context));
      }
    });
  }

  Future<void> _prepareInitialPage(BuildContext context) async {
    if (_initialPagePreparing || _initialPageReady) {
      return;
    }
    _initialPagePreparing = true;
    // 导航层已经完成了目标设备的首屏资源门槛；这里先只保留第 1 页。
    // 相邻页必须等旧子页被替换、当前首帧稳定后才进入窗口。
    _updatePageResourceWindow(context, 0, 1);
    if (!mounted) {
      return;
    }
    _initialPagePreparing = false;
    _initialPageReady = true;
    // 让第 1 页先完成一次布局/绘制，再决定是否存在并预热第 2 页。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _schedulePageResourceWindow(context, 0, _pageCount);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AirConditionerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPageCount = _pageCount;
    final devicesChanged = _runtimeDevicesChanged(
      oldWidget.runtimeDevices,
      widget.runtimeDevices,
    );
    if (devicesChanged) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    } else if (_pageIndex >= nextPageCount) {
      _pageIndex = nextPageCount - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _initialPageReady) {
        _schedulePageResourceWindow(context, _pageIndex, nextPageCount);
      }
    });
  }

  List<String> _assetsForPage(int page) => _pageAssets;

  void _updatePageResourceWindow(
    BuildContext context,
    int page,
    int pageCount,
  ) {
    // 资源窗口始终是“当前页 + 前后相邻页”。从第 2 页滑到第 3 页
    // 时，先释放第 1 页，再预热第 4 页（如果存在）。
    final nextWindow = <int>{page - 1, page, page + 1}
      ..removeWhere((value) => value < 0 || value >= pageCount);
    final pagesToRelease = _resourceWindow.difference(nextWindow).toList();
    final pagesToPrepare = nextWindow.difference(_resourceWindow).toList();

    for (final oldPage in pagesToRelease) {
      _releasePageResources(oldPage);
    }
    for (final newPage in pagesToPrepare) {
      _retainPageResources(newPage);
    }
    _resourceWindow
      ..clear()
      ..addAll(nextWindow);

    final assetsToPrecache = <String>{};
    for (final newPage in pagesToPrepare) {
      for (final asset in _assetsForPage(newPage)) {
        if ((_assetPageReferences[asset] ?? 0) == 1) {
          assetsToPrecache.add(asset);
        }
      }
    }
    if (assetsToPrecache.isNotEmpty) {
      unawaited(Future.wait(
        assetsToPrecache.map(
          (asset) => precacheImage(AssetImage(asset), context),
        ),
      ).catchError((Object error) {
        AppLogger.instance.w(
          '空调相邻页资源预加载失败',
          tag: 'ManualPage',
          error: error,
        );
      }));
    }
  }

  void _retainPageResources(int page) {
    for (final asset in _assetsForPage(page)) {
      _assetPageReferences[asset] = (_assetPageReferences[asset] ?? 0) + 1;
    }
  }

  void _releasePageResources(int page) {
    for (final asset in _assetsForPage(page)) {
      final references = (_assetPageReferences[asset] ?? 1) - 1;
      if (references <= 0) {
        _assetPageReferences.remove(asset);
        imageCache.evict(AssetImage(asset), includeLive: false);
      } else {
        _assetPageReferences[asset] = references;
      }
    }
  }

  void _schedulePageResourceWindow(
    BuildContext context,
    int page,
    int pageCount,
  ) {
    final requestSerial = ++_resourceWindowRequestSerial;
    // 分页状态改变不等于新页已经完成首帧。等这一帧提交后，才释放
    // 离开窗口的旧页，再异步预热相邻页；快速滑动时旧请求自动失效。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestSerial != _resourceWindowRequestSerial) {
        return;
      }
      _updatePageResourceWindow(context, page, pageCount);
    });
  }

  @override
  void dispose() {
    _resourceWindowRequestSerial++;
    for (final page in _resourceWindow.toList()) {
      _releasePageResources(page);
    }
    _resourceWindow.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return SizedBox(
      key: const ValueKey<String>('manual-air-conditioner-list'),
      width: 1470,
      height: 924,
      child: Stack(
        children: <Widget>[
          // Figma node 68:1988: each page contains up to four room cards.
          const Positioned.fill(child: _ManualFrameBackground()),
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey<String>('manual-air-conditioner-pages'),
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (value) {
                setState(() => _pageIndex = value);
                if (_initialPageReady) {
                  _schedulePageResourceWindow(context, value, pageCount);
                }
              },
              itemBuilder: (context, page) {
                final start = page * 4;
                final end = math.min(start + 4, widget.settings.length);
                final pageSettings = widget.settings.sublist(start, end);
                return Stack(
                  children: <Widget>[
                    for (var index = 0; index < pageSettings.length; index++)
                      Positioned(
                        left: index.isEven ? 64 : 768,
                        // Figma cards 68:1989/2005/2020/2034: 639×384,
                        // 34 px top inset.
                        top: index < 2 ? 34 : 482,
                        child: _AirConditionerCard(
                          setting: pageSettings[index],
                          disabled: widget.saving,
                          onOpenAdjustment: () => widget.onOpenAdjustment(
                            pageSettings[index].deviceId,
                          ),
                          onOpenTimer: () => widget.onOpenTimer(
                            pageSettings[index].deviceId,
                          ),
                          onChanged: (change) => widget.onChanged(
                            pageSettings[index].deviceId,
                            change,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (pageCount > 1)
            Positioned(
              left: _pageDotsLeft(pageCount),
              bottom: 20,
              child: _PageDots(
                activeIndex: _pageIndex,
                count: pageCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _AirConditionerCard extends StatefulWidget {
  const _AirConditionerCard({
    required this.setting,
    required this.disabled,
    required this.onOpenAdjustment,
    required this.onOpenTimer,
    required this.onChanged,
  });

  final ManualAirConditionerSetting setting;
  final bool disabled;
  final VoidCallback onOpenAdjustment;
  final VoidCallback onOpenTimer;
  final Future<void> Function(
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) onChanged;

  @override
  State<_AirConditionerCard> createState() => _AirConditionerCardState();
}

class _AirConditionerCardState extends State<_AirConditionerCard> {
  static const Duration _stepSaveDelay = Duration(milliseconds: 500);

  late int _draftTemperatureC;
  Timer? _stepSaveTimer;
  bool _saveInFlight = false;
  bool _savePending = false;

  @override
  void initState() {
    super.initState();
    _draftTemperatureC = widget.setting.targetTemperatureC;
  }

  @override
  void didUpdateWidget(covariant _AirConditionerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_savePending &&
        !_saveInFlight &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      _draftTemperatureC = widget.setting.targetTemperatureC;
    }
  }

  @override
  void dispose() {
    _stepSaveTimer?.cancel();
    super.dispose();
  }

  void _queueTemperatureStep(int delta) {
    final next = (_draftTemperatureC + delta).clamp(16, 30).toInt();
    if (next == _draftTemperatureC) {
      return;
    }
    setState(() => _draftTemperatureC = next);
    _savePending = true;
    _stepSaveTimer?.cancel();
    _stepSaveTimer = Timer(_stepSaveDelay, _flushTemperatureSave);
  }

  Future<void> _flushTemperatureSave() async {
    _stepSaveTimer?.cancel();
    _stepSaveTimer = null;
    if (_saveInFlight || !_savePending) {
      return;
    }
    final value = _draftTemperatureC;
    _savePending = false;
    _saveInFlight = true;
    await widget.onChanged(
      (current) => current.copyWith(targetTemperatureC: value),
    );
    _saveInFlight = false;
    if (_savePending && mounted) {
      _stepSaveTimer = Timer(Duration.zero, _flushTemperatureSave);
    } else if (mounted &&
        widget.setting.targetTemperatureC != _draftTemperatureC) {
      setState(
        () => _draftTemperatureC = widget.setting.targetTemperatureC,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = widget.setting;
    final active = setting.enabled;
    return Container(
      width: 639,
      height: 384,
      decoration: BoxDecoration(
        // ac-cardbg-off.png 与 Figma 一样叠在 #191919 上，不能垫纯黑。
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset(
                active
                    ? 'assets/manual/ac-cardbg.png'
                    : 'assets/manual/ac-cardbg-off.png',
                key: ValueKey<String>(
                  'manual-air-${setting.deviceId}-background',
                ),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              // 关闭态素材已经降低背景亮度；只衰减内容层，避免背景被
              // 二次变暗，同时让关闭开关保持客户切图的正常灰色。
              opacity: active ? 1 : .34,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 46,
                    top: 30,
                    child: Text(setting.roomName, style: _airRoomStyle),
                  ),
                  Positioned(
                    left: 37,
                    top: 119,
                    width: 160,
                    height: 48,
                    child: _AirTapArea(
                      keyName: 'manual-air-${setting.deviceId}-mode',
                      onTap: widget.disabled || !active
                          ? null
                          : () async {
                              await _flushTemperatureSave();
                              widget.onOpenAdjustment();
                            },
                      child: Row(
                        children: <Widget>[
                          const _AirConditionerGlyph(),
                          const SizedBox(width: 6),
                          Text(_modeText(setting.mode, l10n),
                              style: _airSmallStyle),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 37,
                    top: 168,
                    width: 160,
                    height: 48,
                    child: _AirTapArea(
                      keyName: 'manual-air-${setting.deviceId}-fan',
                      onTap: widget.disabled || !active
                          ? null
                          : () async {
                              await _flushTemperatureSave();
                              widget.onOpenAdjustment();
                            },
                      child: Row(
                        children: <Widget>[
                          const _AirFanGlyph(),
                          const SizedBox(width: 6),
                          Text(_fanText(setting.fanLevel, l10n),
                              style: _airSmallStyle),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: _roomCardTemperatureLeft,
                    top: _roomCardTemperatureTop,
                    child: Text(
                      '$_draftTemperatureC',
                      key: ValueKey<String>(
                        'manual-air-${setting.deviceId}-temperature-value',
                      ),
                      style: _airTemperatureStyle,
                    ),
                  ),
                  const Positioned(
                    left: _roomCardTemperatureUnitLeft,
                    top: _roomCardTemperatureUnitTop,
                    child: Text('℃', style: _airUnitStyle),
                  ),
                  Positioned(
                    // Figma node 68:2002: x=525, 68×198.
                    right: 46,
                    top: 128,
                    width: 68,
                    height: 198,
                    child: VerticalStepper(
                      keyPrefix: 'manual-air-${setting.deviceId}-temperature',
                      enabled: active,
                      // 保存锁与设备关闭态分离：锁操作，不改变正常切图。
                      interactionEnabled: !widget.disabled,
                      onPlus: () => _queueTemperatureStep(1),
                      onMinus: () => _queueTemperatureStep(-1),
                    ),
                  ),
                  Positioned(
                    // 空调与地暖使用同一套定时区域。旧实现额外加入 16px
                    // 左内边距且宽度更小，触发 FittedBox 二次缩放，导致
                    // 空调定时文字明显偏小。
                    left: _roomCardTimerLeft,
                    top: _roomCardTimerTop,
                    width: _roomCardTimerWidth,
                    height: _roomCardTimerHeight,
                    child: _AirTapArea(
                      keyName: 'manual-air-${setting.deviceId}-timer',
                      onTap: widget.disabled || !active
                          ? null
                          : () async {
                              await _flushTemperatureSave();
                              widget.onOpenTimer();
                            },
                      child: Row(
                        children: <Widget>[
                          const _AirTimerGlyph(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _timerSummary(setting, l10n),
                                style: _airTimerStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 32,
            top: 32,
            // Figma node 68:1992: supplied 96×48 toggle, not Material Switch.
            child: _PrototypeToggleSwitch(
              toggleKey: ValueKey<String>(
                'manual-air-${setting.deviceId}-power',
              ),
              value: active,
              onChanged: widget.disabled
                  ? null
                  : (value) async {
                      await _flushTemperatureSave();
                      await widget.onChanged(
                        (current) => current.copyWith(enabled: value),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _AirAdjustmentPage extends StatefulWidget {
  const _AirAdjustmentPage({
    required this.setting,
    required this.saving,
    required this.onBack,
    required this.onChanged,
  });

  final ManualAirConditionerSetting setting;
  final bool saving;
  final VoidCallback onBack;
  final void Function(
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) onChanged;

  @override
  State<_AirAdjustmentPage> createState() => _AirAdjustmentPageState();
}

class _AirAdjustmentPageState extends State<_AirAdjustmentPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = widget.setting;
    return _AirDetailShell(
      title: l10n.acAdjustTitle(setting.roomName),
      onBack: widget.onBack,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FiniteWheelPicker<String>(
            pickerKey: const ValueKey<String>('manual-air-adjust-mode-wheel'),
            title: l10n.manualMode,
            values: const <String>['auto', 'cooling', 'heating', 'ventilation'],
            selected: setting.mode,
            display: (value) => _modeText(value, l10n),
            enabled: true,
            interactionEnabled: !widget.saving,
            onChanged: (value) =>
                widget.onChanged((current) => current.copyWith(mode: value)),
          ),
          const SizedBox(width: 286),
          _FiniteWheelPicker<String>(
            pickerKey: const ValueKey<String>('manual-air-adjust-fan-wheel'),
            title: l10n.manualFanSpeed,
            values: const <String>['L1', 'L2', 'L3', 'auto'],
            selected: setting.fanLevel,
            display: (value) => _fanText(value, l10n),
            enabled: true,
            interactionEnabled: !widget.saving,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(fanLevel: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirTimerPage extends StatefulWidget {
  const _AirTimerPage({
    required this.setting,
    required this.saving,
    required this.onBack,
    required this.onChanged,
    this.timeFormat = '24h',
  });

  final ManualAirConditionerSetting setting;
  final bool saving;
  final VoidCallback onBack;
  final void Function(
    ManualAirConditionerSetting Function(ManualAirConditionerSetting current)
        change,
  ) onChanged;
  final String timeFormat;

  @override
  State<_AirTimerPage> createState() => _AirTimerPageState();
}

class _AirTimerPageState extends State<_AirTimerPage> {
  final ValueNotifier<bool> _editingStart = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _editingStart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = widget.setting;
    final timerEnabled = setting.timerEnabled;
    final interactionEnabled = timerEnabled && !widget.saving;
    return _AirDetailShell(
      title: l10n.acTimerSettingTitle(setting.roomName),
      toggleKey: const ValueKey<String>('manual-air-timer-enabled'),
      toggleValue: timerEnabled,
      onBack: widget.onBack,
      onPowerChanged: widget.saving
          ? null
          : (enabled) => widget.onChanged(
                (current) => current.copyWith(timerEnabled: enabled),
              ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: _editingStart,
              builder: (context, editingStart, _) => Row(
                children: <Widget>[
                  _TimeColumn(
                    keyPrefix: 'manual-air-timer-start',
                    title: l10n.manualTimerOn,
                    enabled: timerEnabled,
                    interactionEnabled: interactionEnabled,
                    active: editingStart,
                    minutes: setting.timerStartMinutes,
                    timeFormat: widget.timeFormat,
                    onTap: () => _editingStart.value = true,
                    onChanged: (minutes) => widget.onChanged(
                      (current) => current.copyWith(
                        timerStartMinutes: minutes,
                      ),
                    ),
                  ),
                  const SizedBox(width: 54),
                  _TimeColumn(
                    keyPrefix: 'manual-air-timer-end',
                    title: l10n.manualTimerOff,
                    enabled: timerEnabled,
                    interactionEnabled: interactionEnabled,
                    active: !editingStart,
                    minutes: setting.timerEndMinutes,
                    timeFormat: widget.timeFormat,
                    onTap: () => _editingStart.value = false,
                    onChanged: (minutes) => widget.onChanged(
                      (current) => current.copyWith(
                        timerEndMinutes: minutes,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 54),
          _FiniteWheelPicker<String>(
            pickerKey: const ValueKey<String>('manual-air-timer-repeat-wheel'),
            title: l10n.manualRepeat,
            values: const <String>['once', 'weekdays', 'daily', 'off'],
            selected: setting.timerRepeat,
            display: (value) => _repeatText(value, l10n),
            enabled: timerEnabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(timerRepeat: value),
            ),
          ),
          const SizedBox(width: 54),
          _FiniteWheelPicker<String>(
            pickerKey: const ValueKey<String>('manual-air-timer-mode-wheel'),
            title: l10n.manualMode,
            values: const <String>['auto', 'cooling', 'heating', 'ventilation'],
            selected: setting.mode,
            display: (value) => _modeText(value, l10n),
            enabled: timerEnabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) =>
                widget.onChanged((current) => current.copyWith(mode: value)),
          ),
          const SizedBox(width: 54),
          _FiniteWheelPicker<int>(
            pickerKey:
                const ValueKey<String>('manual-air-timer-temperature-wheel'),
            title: l10n.metricTemperature,
            values: const <int>[
              16,
              17,
              18,
              19,
              20,
              21,
              22,
              23,
              24,
              25,
              26,
              27,
              28,
              29,
              30
            ],
            selected: setting.targetTemperatureC,
            display: (value) => '$value',
            selectedSuffix: ' ℃',
            enabled: timerEnabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(targetTemperatureC: value),
            ),
          ),
          const SizedBox(width: 54),
          _FiniteWheelPicker<String>(
            pickerKey: const ValueKey<String>('manual-air-timer-fan-wheel'),
            title: l10n.manualFanSpeed,
            values: const <String>['L1', 'L2', 'L3', 'auto'],
            selected: setting.fanLevel,
            display: (value) => _fanText(value, l10n),
            enabled: timerEnabled,
            interactionEnabled: interactionEnabled,
            onChanged: (value) => widget.onChanged(
              (current) => current.copyWith(fanLevel: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirDetailShell extends StatelessWidget {
  const _AirDetailShell({
    required this.title,
    required this.onBack,
    required this.child,
    this.toggleKey,
    this.toggleValue,
    this.onPowerChanged,
  });

  final String title;
  final Key? toggleKey;
  final bool? toggleValue;
  final VoidCallback onBack;
  final ValueChanged<bool>? onPowerChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRect(
      key: ValueKey<String>('manual-air-detail-$title'),
      child: Container(
        width: 1600,
        height: 1000,
        decoration: BoxDecoration(
          color: const Color(0xCC141414),
          border: Border.all(color: const Color(0xB3FFFFFF)),
        ),
        child: Stack(
          children: <Widget>[
            // 返回文字保持原来的视觉坐标；外层透明热区扩大到 260×125，
            // 避免用户必须精准点中文字本身。IgnorePointer 让内层只负责绘制，
            // 所有点击统一由外层 GestureDetector 处理。
            Positioned(
              left: 12,
              top: 18,
              width: 260,
              height: 125,
              child: GestureDetector(
                // 兼容页面测试与诊断工具使用的公共返回键；热区本身仍是
                // 透明的大点击区域，视觉上的“返回”文字不承担命中逻辑。
                key: const ValueKey<String>('manual-air-detail-back'),
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 38,
                      top: 28,
                      width: 100,
                      height: 52,
                      child: IgnorePointer(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: onBack,
                          child: Text(l10n.back, style: _airBackStyle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (toggleKey != null && toggleValue != null)
              Positioned(
                right: 50,
                top: 48,
                // Figma node 68:2114: x=1614, y=149, 96×48.
                child: _PrototypeToggleSwitch(
                  toggleKey: toggleKey!,
                  value: toggleValue!,
                  onChanged: onPowerChanged,
                ),
              ),
            Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _airTitleStyle,
                ),
              ),
            ),
            Positioned(left: 0, right: 0, top: 237, child: child),
          ],
        ),
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.keyPrefix,
    required this.title,
    required this.enabled,
    required this.interactionEnabled,
    required this.active,
    required this.minutes,
    required this.onTap,
    required this.onChanged,
    this.timeFormat = '24h',
  });

  final String keyPrefix;
  final String title;
  final bool enabled;
  final bool interactionEnabled;
  final bool active;
  final int minutes;
  final VoidCallback? onTap;
  final ValueChanged<int>? onChanged;
  final String timeFormat;

  static int _to12Hour(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final hour12 = hour24 % 12;
    return hour12 == 0 ? 12 : hour12;
  }

  static bool _isAM(int minutes) => (minutes ~/ 60) % 24 < 12;

  static int _from12Hour(int hour12, int minute, bool isAM) {
    final hour24 = isAM
        ? hour12 % 12          // 12 AM → 0
        : (hour12 % 12) + 12;  // 12 PM → 12, 1-11 PM → 13-23
    return hour24 * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    final is12h = timeFormat == '12h';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = is12h ? _to12Hour(minutes) : hour;
    final displayHourCount = is12h ? 12 : 24;
    final isAM = _isAM(minutes);
    return SizedBox(
      // Figma nodes 68:2116 and 68:2134: 210×552, two linked wheels.
      width: 210,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 58,
            child: _TimerFocusButton(
              focusKey: ValueKey<String>('$keyPrefix-focus'),
              indicatorKey: ValueKey<String>('$keyPrefix-indicator'),
              title: title,
              enabled: enabled,
              interactionEnabled: interactionEnabled,
              active: enabled && active,
              onTap: onTap,
            ),
          ),
          // The Figma wheel starts at y=147 inside the 552 px column.
          if (is12h) ...[
            // Figma: AM/PM 选择行位于 title 与滚轮之间（y=76~132）。
            const SizedBox(height: 18),
            _AmPmSelector(
              keyPrefix: keyPrefix,
              isAM: isAM,
              enabled: enabled && active,
              interactionEnabled: interactionEnabled,
              onChanged: (am) => onChanged?.call(
                _from12Hour(displayHour, minute, am),
              ),
            ),
            const SizedBox(height: 15),
          ] else ...[
            const SizedBox(height: 89),
          ],
          SizedBox(
            height: 405,
            child: Row(
              children: <Widget>[
                _TimeWheel(
                  wheelKey: ValueKey<String>('$keyPrefix-hour-wheel'),
                  value: is12h ? displayHour - 1 : displayHour,
                  itemCount: displayHourCount,
                  active: enabled && active,
                  interactionEnabled: interactionEnabled,
                  labelBuilder: is12h
                      ? (index) => '${index + 1}'
                      : null,
                  onChanged: enabled && active
                      ? (value) => onChanged?.call(
                            is12h
                                ? _from12Hour(value + 1, minute, isAM)
                                : value * 60 + minute,
                          )
                      : null,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      ':',
                      textAlign: TextAlign.center,
                      style: _airSelectionStyle.copyWith(
                        fontSize: 56,
                        color: enabled && active
                            ? Colors.white
                            : const Color(0x4DFFFFFF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TimeWheel(
                  wheelKey: ValueKey<String>('$keyPrefix-minute-wheel'),
                  value: minute,
                  itemCount: 60,
                  active: enabled && active,
                  interactionEnabled: interactionEnabled,
                  onChanged: enabled && active
                      ? (value) => onChanged?.call(
                            is12h
                                ? _from12Hour(displayHour, value, isAM)
                                : hour * 60 + value,
                          )
                      : null,
                ),
                ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma 12h 格式的 AM/PM 选择器：圆形指示器 + 上午/下午文字。
class _AmPmSelector extends StatelessWidget {
  const _AmPmSelector({
    required this.keyPrefix,
    required this.isAM,
    required this.enabled,
    required this.interactionEnabled,
    required this.onChanged,
  });

  final String keyPrefix;
  final bool isAM;
  final bool enabled;
  final bool interactionEnabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = enabled && interactionEnabled;
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(width: 21),
          _AmPmOption(
            key: ValueKey<String>('$keyPrefix-ampm-am'),
            label: l10n.am,
            selected: isAM,
            active: active,
            onTap: active && onChanged != null
                ? () => onChanged!(true)
                : null,
          ),
          const SizedBox(width: 20),
          _AmPmOption(
            key: ValueKey<String>('$keyPrefix-ampm-pm'),
            label: l10n.pm,
            selected: !isAM,
            active: active,
            onTap: active && onChanged != null
                ? () => onChanged!(false)
                : null,
          ),
        ],
      ),
    );
  }
}

class _AmPmOption extends StatelessWidget {
  const _AmPmOption({
    Key? key,
    required this.label,
    required this.selected,
    required this.active,
    this.onTap,
  }) : super(key: key);

  final String label;
  final bool selected;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (selected ? Colors.white : const Color(0xB3FFFFFF))
        : const Color(0x4DFFFFFF);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: _airSelectionStyle.copyWith(
          color: color,
          fontSize: 42,
        ),
      ),
    );
  }
}

class _TimerFocusButton extends StatelessWidget {
  const _TimerFocusButton({
    required this.focusKey,
    required this.indicatorKey,
    required this.title,
    required this.enabled,
    required this.interactionEnabled,
    required this.active,
    required this.onTap,
  });

  final Key focusKey;
  final Key indicatorKey;
  final String title;
  final bool enabled;
  final bool interactionEnabled;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: active,
      enabled: enabled && interactionEnabled,
      child: GestureDetector(
        key: focusKey,
        behavior: HitTestBehavior.opaque,
        onTap: enabled && interactionEnabled ? onTap : null,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 21),
            Transform.translate(
              key: indicatorKey,
              offset: const Offset(0, 3),
              child: Image.asset(
                active
                    ? 'assets/manual/check-box-on.png'
                    : 'assets/manual/check-box-off.png',
                width: 36,
                height: 36,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: _airColumnTitleStyle.copyWith(
                color: !enabled
                    ? const Color(0x4DFFFFFF)
                    : active
                        ? Colors.white
                        : const Color(0xB3FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required this.wheelKey,
    required this.value,
    required this.itemCount,
    required this.active,
    required this.interactionEnabled,
    required this.onChanged,
    this.labelBuilder,
  });

  final Key wheelKey;
  final int value;
  final int itemCount;
  final bool active;
  final bool interactionEnabled;
  final ValueChanged<int>? onChanged;

  /// 自定义标签显示，默认使用两位数字（00, 01, …）。
  final String Function(int index)? labelBuilder;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  static const _itemExtent = 107.0;
  late FixedExtentScrollController _controller;
  late int _selected;

  bool get _acceptsInput =>
      widget.active && widget.interactionEnabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void didUpdateWidget(covariant _TimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _selected) {
      _selected = widget.value;
      if (_controller.hasClients) {
        _controller.jumpToItem(_selected);
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
    return SizedBox(
      key: widget.wheelKey,
      width: 89,
      height: 405,
      child: Stack(
        children: <Widget>[
          ListWheelScrollView.useDelegate(
            controller: _controller,
            physics: !_acceptsInput
                ? const NeverScrollableScrollPhysics()
                : const FixedExtentScrollPhysics(),
            itemExtent: _itemExtent,
            diameterRatio: 2.0,
            perspective: 0.003,
            squeeze: 1.0,
            // Figma 要求两级渐变：相邻项 70% 不透明度/42px，
            // 间隔 2 位项 30% 不透明度/36px。
            overAndUnderCenterOpacity: 1.0,
            onSelectedItemChanged: (value) {
              if (!_acceptsInput) {
                return;
              }
              setState(() => _selected = value);
              widget.onChanged!(value);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.itemCount,
              builder: (BuildContext context, int index) {
                final distance = (index - _selected).abs();
                final selected = distance == 0;
                final adjacent = distance == 1;
                // Figma: selected=50px Bold, adjacent=42px Regular,
                // further=36px Regular.
                final fontSize = selected ? 50.0 : (adjacent ? 42.0 : 36.0);
                // Figma: selected=100%, adjacent=70%, further=30%.
                final Color textColor;
                if (!widget.active) {
                  textColor = const Color(0x4DFFFFFF);
                } else if (selected) {
                  textColor = Colors.white;
                } else if (adjacent) {
                  textColor = const Color(0xB3FFFFFF);
                } else {
                  textColor = const Color(0x4DFFFFFF);
                }
                final label = widget.labelBuilder != null
                    ? widget.labelBuilder!(index)
                    : index.toString().padLeft(2, '0');
                return Center(
                  child: Text(
                    label,
                    style: AppFonts.sc(
                      selected ? AppFonts.w550 : AppFonts.w400,
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: SizedBox.expand(
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 149),
                  Divider(
                    height: 1,
                    color: widget.active
                        ? const Color(0xFFE4E7E7)
                        : const Color(0x4DFFFFFF),
                  ),
                  const SizedBox(height: 106),
                  Divider(
                    height: 1,
                    color: widget.active
                        ? const Color(0xFFE4E7E7)
                        : const Color(0x4DFFFFFF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma timer columns 68:2152/2161/2170/2180 are finite wheels: their first
/// and last values stop at the edge instead of wrapping around.
class _FiniteWheelPicker<T> extends StatefulWidget {
  const _FiniteWheelPicker({
    required this.pickerKey,
    required this.title,
    required this.values,
    required this.selected,
    required this.display,
    required this.enabled,
    required this.interactionEnabled,
    required this.onChanged,
    this.selectedSuffix,
  });

  final Key pickerKey;
  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) display;

  /// 决定滚轮的正常/关闭视觉，只反映对应功能是否开启。
  final bool enabled;

  /// 临时锁定滚动但保持当前视觉，例如详情页正在保存时。
  final bool interactionEnabled;
  final ValueChanged<T>? onChanged;
  final String? selectedSuffix;

  @override
  State<_FiniteWheelPicker<T>> createState() => _FiniteWheelPickerState<T>();
}

class _FiniteWheelPickerState<T> extends State<_FiniteWheelPicker<T>> {
  static const _itemExtent = 107.0;
  late FixedExtentScrollController _controller;
  late int _selectedIndex;

  bool get _acceptsInput =>
      widget.enabled && widget.interactionEnabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.values.indexOf(widget.selected);
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant _FiniteWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedIndex = widget.values.indexOf(widget.selected);
    if (updatedIndex != _selectedIndex) {
      _selectedIndex = updatedIndex;
      if (_controller.hasClients) {
        _controller.jumpToItem(_selectedIndex);
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
    final enabled = widget.enabled;
    return SizedBox(
      key: widget.pickerKey,
      width: 178,
      height: 552,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 58,
            child: Center(
              child: Text(
                widget.title,
                style: _airColumnTitleStyle.copyWith(
                  color: enabled
                      ? const Color(0xB3FFFFFF)
                      : const Color(0x4DFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 89),
          SizedBox(
            width: 178,
            height: 405,
            child: Stack(
              children: <Widget>[
                ListWheelScrollView.useDelegate(
                  controller: _controller,
                  physics: !_acceptsInput
                      ? const NeverScrollableScrollPhysics()
                      : const FixedExtentScrollPhysics(),
                  itemExtent: _itemExtent,
                  diameterRatio: 2.0,
                  perspective: 0.003,
                  squeeze: 1.0,
                  // Figma 要求两级渐变：相邻项 70% 不透明度/42px，
                  // 间隔 2 位项 30% 不透明度/36px。统一 opacity 无
                  // 法满足，故设为 1.0 后在 builder 中手动控制。
                  overAndUnderCenterOpacity: 1.0,
                  onSelectedItemChanged: (index) {
                    if (!_acceptsInput) {
                      return;
                    }
                    setState(() => _selectedIndex = index);
                    widget.onChanged!(widget.values[index]);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.values.length,
                    builder: (BuildContext context, int index) {
                      final distance = (index - _selectedIndex).abs();
                      final selected = distance == 0;
                      final adjacent = distance == 1;
                      // Figma: selected=50px Bold, adjacent=42px Regular,
                      // further=36px Regular.
                      final fontSize = selected ? 50.0 : (adjacent ? 42.0 : 36.0);
                      // Figma: selected=100%, adjacent=70%, further=30%.
                      final Color textColor;
                      if (!enabled) {
                        textColor = const Color(0x4DFFFFFF);
                      } else if (selected) {
                        textColor = Colors.white;
                      } else if (adjacent) {
                        textColor = const Color(0xB3FFFFFF);
                      } else {
                        textColor = const Color(0x4DFFFFFF);
                      }
                      final textStyle = AppFonts.sc(
                        selected ? AppFonts.w550 : AppFonts.w400,
                        fontSize: fontSize,
                        color: textColor,
                      );
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: selected && widget.selectedSuffix != null
                              ? Text.rich(
                                  TextSpan(
                                    text: widget.display(widget.values[index]),
                                    style: textStyle,
                                    children: <InlineSpan>[
                                      TextSpan(
                                        text: widget.selectedSuffix,
                                        style: _airSelectionStyle.copyWith(
                                          fontFamily: 'HarmonyOS Sans Bold',
                                          fontSize: 40,
                                          fontWeight: FontWeight.w700,
                                          color: enabled
                                              ? Colors.white
                                              : const Color(0x4DFFFFFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                )
                              : Text(
                                  widget.display(widget.values[index]),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: textStyle,
                                ),
                        ),
                      );
                    },
                  ),
                ),
                IgnorePointer(
                  child: SizedBox.expand(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 149),
                        Divider(
                          height: 1,
                          color: enabled
                              ? const Color(0xFFE4E7E7)
                              : const Color(0x4DFFFFFF),
                        ),
                        const SizedBox(height: 106),
                        Divider(
                          height: 1,
                          color: enabled
                              ? const Color(0xFFE4E7E7)
                              : const Color(0x4DFFFFFF),
                        ),
                      ],
                    ),
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

class _PrototypeToggleSwitch extends StatelessWidget {
  const _PrototypeToggleSwitch({
    required this.toggleKey,
    required this.value,
    required this.onChanged,
  });

  final Key toggleKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: value,
      enabled: onChanged != null,
      child: GestureDetector(
        key: toggleKey,
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Image.asset(
          value
              ? 'assets/settings/toggle-button-on.png'
              : 'assets/settings/toggle-button-off.png',
          width: 96,
          height: 48,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// 空调卡片直接使用设计稿提供的 40 px 状态图标。素材已经包含透明背景、
/// 抗锯齿透明度和 #42CEEA 原色，不再缩放主页母图或运行时染色。
class _AirConditionerGlyph extends StatelessWidget {
  const _AirConditionerGlyph();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/manual/card-空调.png',
      width: 40,
      height: 40,
      filterQuality: FilterQuality.high,
    );
  }
}

/// 风量同样使用设计稿 40 px 切图，并保留素材自带的 #9AD7FF 浅蓝色。
class _AirFanGlyph extends StatelessWidget {
  const _AirFanGlyph();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/manual/card-风量.png',
      width: 40,
      height: 40,
      filterQuality: FilterQuality.high,
    );
  }
}

class _AirTimerGlyph extends StatelessWidget {
  const _AirTimerGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _AirTimerGlyphPainter()),
    );
  }
}

class _AirTimerGlyphPainter extends CustomPainter {
  const _AirTimerGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD3D8D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const center = Offset(20, 20);
    canvas.drawCircle(center, 14, paint);
    canvas.drawLine(center, const Offset(20, 10), paint);
    canvas.drawLine(center, const Offset(28, 21), paint);
  }

  @override
  bool shouldRepaint(covariant _AirTimerGlyphPainter oldDelegate) => false;
}

class _ManualFrameBackground extends StatelessWidget {
  const _ManualFrameBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/manual/frame-bg.png',
      key: const ValueKey<String>('manual-frame-background'),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
  }
}

class _AirTapArea extends StatelessWidget {
  const _AirTapArea({
    required this.keyName,
    required this.onTap,
    required this.child,
  });

  final String keyName;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 卡片里的模式、风量和定时只负责打开对应调节界面；设计稿没有
    // InkWell 的按下/聚焦底色。使用 GestureDetector 保留点击热区，
    // 同时避免桌面和嵌入式平台绘制矩形高亮。
    return GestureDetector(
      key: ValueKey<String>(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({this.active = false});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFF6C7173),
          shape: BoxShape.circle,
        ),
      );
}

class _PageDots extends StatelessWidget {
  const _PageDots({this.count = 4, this.activeIndex = 0});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        count,
        (index) => _PageDot(active: index == activeIndex),
      ),
    );
  }
}

// 分页点只支持当前产品的 2/3/4 页稿，间距保持 _PageDot 原值不变；
// 三组固定左坐标让整组视觉中心保持一致，单页由调用方直接隐藏。
double _pageDotsLeft(int count) {
  switch (count) {
    case 2:
      return 707;
    case 3:
      return 691;
    case 4:
    default:
      return 675;
  }
}

String _modeText(String value, AppLocalizations l10n) {
  switch (value) {
    case 'auto':
      return l10n.modeAuto;
    case 'cooling':
      return l10n.stateCooling;
    case 'heating':
      return l10n.modeHeating;
    case 'ventilation':
      return l10n.modeFan;
  }
  return value;
}

String _fanText(String value, AppLocalizations l10n) =>
    value == 'auto' ? l10n.modeAuto : value;

List<String> _timerFanLevels(String? mode) {
  switch (mode) {
    case 'full_heat_exchange':
      return ['L0', 'L1', 'L2', 'L3'];
    default:
      return ['L0', 'L1', 'L2', 'L3', 'L4', 'L5'];
  }
}

String _freshAirModeText(String value, AppLocalizations l10n) {
  switch (value) {
    case 'internal_circulation':
      return l10n.freshAirModeInternalCirculation;
    case 'full_heat_exchange':
      return l10n.freshAirModeFullHeatExchange;
    case 'auto':
      return l10n.modeAuto;
  }
  return value;
}

String _repeatText(String value, AppLocalizations l10n) {
  switch (value) {
    case 'once':
      return l10n.repeatOnce;
    case 'weekdays':
      return l10n.repeatWeekdays;
    case 'daily':
      return l10n.everyDay;
    case 'off':
      return l10n.repeatOff;
  }
  return value;
}

String _timerSummary(ManualAirConditionerSetting setting, AppLocalizations l10n) {
  if (!setting.timerEnabled) {
    return l10n.timerNotSet;
  }
  return l10n.timerSummaryValue(
    _formatMinutes(setting.timerStartMinutes),
    _formatMinutes(setting.timerEndMinutes),
    _repeatText(setting.timerRepeat, l10n),
  );
}

String _floorTimerSummary(ManualFloorHeatSetting setting, AppLocalizations l10n) {
  if (!setting.timerEnabled) {
    return l10n.timerNotSet;
  }
  return l10n.timerSummaryValue(
    _formatMinutes(setting.timerStartMinutes),
    _formatMinutes(setting.timerEndMinutes),
    _repeatText(setting.timerRepeat, l10n),
  );
}

String _formatMinutes(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

String _wholeHomeTimerSummary(
  AppLocalizations l10n,
  bool enabled,
  int startMinutes,
  int endMinutes,
  String repeat,
) {
  if (!enabled) return l10n.timerNotSet;
  return l10n.timerSummaryValue(
    _formatMinutes(startMinutes),
    _formatMinutes(endMinutes),
    _repeatText(repeat, l10n),
  );
}

const TextStyle _wholeHomeGaugeTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 48,
);
const double _wholeHomeGaugeValueFontSize = 150;
const TextStyle _wholeHomeGaugeValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyLight,
  fontSize: _wholeHomeGaugeValueFontSize,
  height: 1,
);
const TextStyle _wholeHomeGaugeUnitStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 54,
);

const TextStyle _airPromptStyle = TextStyle(
  color: Color(0xFFD6DBDB),
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 31,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
const TextStyle _airRoomStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  // Figma node 68:2003: Source Han Sans SC Regular, 48 px.
  fontSize: 48,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
const TextStyle _airSmallStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 30,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
// Latest Figma cache: air-conditioner nodes 68:2000/2001 and floor-heat
// nodes 68:2320/2321 use the same value/unit anchors. Keep one shared set of
// Flutter positions so switching between the two manual pages cannot shift the
// temperature. The unit top includes the existing font-metric compensation.
const double _roomCardTemperatureLeft = 236;
const double _roomCardTemperatureTop = 135;
const double _roomCardTemperatureUnitLeft = 414;
const double _roomCardTemperatureUnitTop = 216;
// 空调和地暖卡片的定时摘要也必须共用一组布局参数。两者都可能显示
// 相同长度的时间与周期，不能让某一页因额外 padding 被单独缩小。
const double _roomCardTimerLeft = 205;
const double _roomCardTimerTop = 308;
const double _roomCardTimerWidth = 305;
const double _roomCardTimerHeight = 40;
const TextStyle _airTemperatureStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyLight,
  fontSize: 144,
);
const TextStyle _airUnitStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 45,
);
const TextStyle _airTimerStyle = TextStyle(
  color: Color(0xFFD5DBDB),
  // HarmonyOS Sans in this project contains digits but not Chinese glyphs.
  // The timer sentence mixes Chinese and digits, so keep it in Source Han
  // rather than relying on an embedded-platform fallback font.
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 30,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
const TextStyle _airBackStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 36,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
const TextStyle _airTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 54,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
);
const TextStyle _airColumnTitleStyle = TextStyle(
  color: Color(0xFFC6CBCC),
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 45,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
);
const TextStyle _airSelectionStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontSize: 46,
  fontWeight: FontWeight.w500,
);

/// 手动模式退出确认弹窗
class _ManualExitDialog extends StatelessWidget {
  const _ManualExitDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey<String>('manual-exit-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1440,
        height: 524,
        decoration: BoxDecoration(
          color: prototypePanel,
          border: Border.all(color: const Color(0xFF676767)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 321,
              top: 160,
              width: 798,
              child: Text(
                l10n.manualExitMessage,
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
              left: 400,
              top: 336,
              child: _DialogButton(
                keyName: 'manual-exit-cancel',
                label: l10n.cancel,
                color: const Color(0xFF555555),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            Positioned(
              left: 820,
              top: 336,
              child: _DialogButton(
                keyName: 'manual-exit-confirm',
                label: l10n.confirm,
                color: const Color(0xFF3478D4),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手动模式退出弹窗按钮（复用智能模式弹窗按钮样式）
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.keyName,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 220,
        height: 100,
        color: color,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.sourceHanSansSc,
            fontVariations: AppFonts.sourceHanSansScRegularWght400,
            fontSize: 36,
          ),
        ),
      ),
    );
  }
}
