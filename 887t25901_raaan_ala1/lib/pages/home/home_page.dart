import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../models/dashboard_page_refresh_policy.dart';
import '../../models/dashboard_persistent_data.dart';
import '../../models/weather_presentation.dart';
import '../../services/app_logger.dart';
import '../../services/dashboard_storage.dart';
import '../../services/dashboard_runtime_sync_service.dart';
import '../../services/time_source.dart';
import '../../services/wifi_manager.dart';
import '../../theme/app_fonts.dart';
import '../../utils/locale_controller.dart';
import '../../widgets/left_navigation_bar.dart';
import '../../widgets/status_bar.dart';
import '../history/history_page.dart';
import '../idle/idle_page.dart';
import '../manual/manual_page.dart';
import '../smart/smart_page.dart';
import '../settings/system_settings_page.dart';

part 'home_page_data.dart';
part 'home_page_data_controls.dart';
part 'home_page_data_support.dart';
part 'home_page_navigation.dart';
part 'home_page_idle.dart';
part 'home_page_view.dart';
part 'home_page_alerts.dart';
part 'home_page_alert_rows.dart';
part 'home_page_dashboard.dart';
part 'home_page_dashboard_orb.dart';
part 'home_page_dashboard_weather.dart';
part 'home_page_dashboard_devices.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    Key? key,
    this.storage,
    this.runtimeSyncService,
    this.timeSource = const SystemTimeSource(),
    this.animateWeather = true,
    this.idleTimeout = const Duration(seconds: 30),
    this.showBackendStatusOverlay = true,
    required this.localeController,
  }) : super(key: key);

  final DashboardDataRepository? storage;
  final DashboardRuntimeSyncService? runtimeSyncService;
  final TimeSource timeSource;
  final bool animateWeather;
  final Duration idleTimeout;
  final bool showBackendStatusOverlay;
  final ValueNotifier<Locale> localeController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _defaultEngineeringPassword = '666666';
  // HTTP 已接受写入后，等待后端完成“写一拍 + 整组确认读一拍”，再补读一次快照。
  // 只改这里即可根据真实设备响应速度微调，不阻塞 UI 线程。
  static const Duration _writeReadbackRefreshDelay =
      Duration(milliseconds: 350);
  static const Duration _idleScreenSleepDelay = Duration(seconds: 30);

  late final DashboardDataRepository _storage;
  late final DashboardWifiManager _wifiManager;
  DashboardData? _data;
  DashboardPersistentData? _persistentData;
  bool _homeInitialSurfaceReady = false;
  int _pageIndex = 0;
  int _manualEntryDeviceIndex = 0;
  int _navigationRequestSerial = 0;
  int _idleTransitionSerial = 0;
  bool _pageTransitionLoading = false;
  int? _transitionTargetPageIndex;
  int _transitionTargetManualDeviceIndex = 0;
  final List<int> _pageEntryTokens = List<int>.filled(5, 0);
  final FocusNode _shortcutFocusNode = FocusNode();
  final Set<String> _pendingControls = <String>{};
  bool _settingsWriteInFlight = false;
  bool _persistentWriteInFlight = false;
  Timer? _runtimeRefreshTimer;
  Timer? _writeReadbackRefreshTimer;
  Timer? _idleTimer;
  Timer? _idleScreenSleepTimer;
  int _historyPulseCount = 0;
  late final PointerRoute _globalPointerRoute = _recordGlobalPointerActivity;
  bool _globalPointerRouteRegistered = false;
  bool _reloadInFlight = false;
  bool _writeReadbackRefreshPending = false;
  bool _idlePageVisible = false;
  bool _screenSleeping = false;
  bool _screenBlackOverlayVisible = false;
  bool _screenSleepCommandInFlight = false;
  int _screenSleepRequestSerial = 0;
  int? _screenWakePointer;
  bool _idleTransitionInFlight = false;
  bool _engineeringModeActive = false;
  bool _wifiConnectionLocked = false;
  bool _runtimeAlertDialogVisible = false;
  // dispose() 先撤销外部回调，再释放页面内部资源。这个标志覆盖
  // dispose() 与同一帧内已经排队的指针/定时器回调，避免回调重新创建资源。
  bool _lifecycleDisposing = false;
  String _engineeringPassword = _defaultEngineeringPassword;
  final ValueNotifier<DashboardData?> _homePageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _smartPageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _manualPageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _historyPageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _settingsPageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _idlePageData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _dialogData =
      ValueNotifier<DashboardData?>(null);
  final ValueNotifier<DashboardData?> _backendStatusOverlayData =
      ValueNotifier<DashboardData?>(null);

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ??
        DashboardStorage(runtimeSyncService: widget.runtimeSyncService);
    _wifiManager = DashboardWifiManager(_storage);
    _loadInitialData();
    _runtimeRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _onRuntimePulse(),
    );
    // Dialog 位于 Navigator Overlay，不能依赖主页 subtree 的 Listener。
    // 统一从全局指针路由记录活动，任何点击都能重新开始空闲计时。
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(
      _globalPointerRoute,
    );
    _globalPointerRouteRegistered = true;
    _restartIdleTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shortcutFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _lifecycleDisposing = true;
    _idleTransitionSerial++;
    _idleTransitionInFlight = false;
    // 让已经排队的异步导航在销毁后失效，即使它尚未走到 mounted 检查点。
    _navigationRequestSerial++;
    // pointerRouter 不属于 HomePage 的 subtree，必须在最前面解除注册；
    // 否则销毁过程中仍可能把事件转发到已经开始释放的 State。
    if (_globalPointerRouteRegistered) {
      WidgetsBinding.instance.pointerRouter.removeGlobalRoute(
        _globalPointerRoute,
      );
      _globalPointerRouteRegistered = false;
    }
    _runtimeRefreshTimer?.cancel();
    _runtimeRefreshTimer = null;
    _writeReadbackRefreshTimer?.cancel();
    _writeReadbackRefreshTimer = null;
    _writeReadbackRefreshPending = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    _idleScreenSleepTimer?.cancel();
    _idleScreenSleepTimer = null;
    _screenSleepRequestSerial++;
    _screenSleepCommandInFlight = false;
    _screenSleeping = false;
    _screenBlackOverlayVisible = false;
    _screenWakePointer = null;
    _idlePageVisible = false;
    _homePageData.dispose();
    _smartPageData.dispose();
    _manualPageData.dispose();
    _historyPageData.dispose();
    _settingsPageData.dispose();
    _idlePageData.dispose();
    _dialogData.dispose();
    _backendStatusOverlayData.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildHomePageRoot(context);

  void _onRuntimePulse() {
    if (_lifecycleDisposing || _engineeringModeActive) {
      return;
    }
    if (_historyPulseCount < 10) {
      _historyPulseCount++;
    }
    if (_historyPulseCount >= 10) {
      // 饱和计数：达到阈值后若本次已有请求进行中，保留阈值，
      // 下一个脉搏继续尝试，不因一次跳过而重新等待 10 次。
      if (_storage.requestHistoryRefresh()) {
        _historyPulseCount = 0;
      }
    }
    unawaited(_refreshRuntime());
  }
}
