/// 调试阶段保存的 Wi-Fi 成功连接记录。
///
/// 密码按当前联调要求明文落盘；正式设备接入时可以替换存储实现，
/// 但 UI 仍只应在连接成功后更新本记录。
class SavedWifiNetwork {
  const SavedWifiNetwork({required this.ssid, required this.password});

  final String ssid;
  final String password;

  factory SavedWifiNetwork.fromJson(Map<String, dynamic> json) {
    return SavedWifiNetwork(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ssid': ssid,
        'password': password,
      };
}

/// 手动模式中一台空调的已确认设置。
///
/// 用户可修改且重启后保留，因此属于 dashboard_settings.json；设备的
/// 实时反馈仍应单独留在 dashboard_runtime.json。
class ManualAirConditionerSetting {
  const ManualAirConditionerSetting({
    required this.deviceId,
    required this.roomName,
    required this.enabled,
    required this.targetTemperatureC,
    required this.mode,
    required this.fanLevel,
    required this.timerEnabled,
    required this.timerStartMinutes,
    required this.timerEndMinutes,
    required this.timerRepeat,
  });

  static const Set<String> supportedModes = <String>{
    'auto',
    'cooling',
    'heating',
    'ventilation',
  };
  static const Set<String> supportedFanLevels = <String>{
    'auto',
    'L1',
    'L2',
    'L3',
  };
  static const Set<String> supportedTimerRepeats = <String>{
    'once',
    'weekdays',
    'daily',
    'off',
  };

  final String deviceId;
  final String roomName;
  final bool enabled;
  final int targetTemperatureC;
  final String mode;
  final String fanLevel;
  final bool timerEnabled;
  final int timerStartMinutes;
  final int timerEndMinutes;
  final String timerRepeat;

  ManualAirConditionerSetting copyWith({
    String? roomName,
    bool? enabled,
    int? targetTemperatureC,
    String? mode,
    String? fanLevel,
    bool? timerEnabled,
    int? timerStartMinutes,
    int? timerEndMinutes,
    String? timerRepeat,
  }) {
    return ManualAirConditionerSetting(
      deviceId: deviceId,
      roomName: roomName ?? this.roomName,
      enabled: enabled ?? this.enabled,
      targetTemperatureC: targetTemperatureC ?? this.targetTemperatureC,
      mode: mode ?? this.mode,
      fanLevel: fanLevel ?? this.fanLevel,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerStartMinutes: timerStartMinutes ?? this.timerStartMinutes,
      timerEndMinutes: timerEndMinutes ?? this.timerEndMinutes,
      timerRepeat: timerRepeat ?? this.timerRepeat,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'roomName': roomName,
        'enabled': enabled,
        'targetTemperatureC': targetTemperatureC,
        'mode': mode,
        'fanLevel': fanLevel,
        'timerEnabled': timerEnabled,
        'timerStartMinutes': timerStartMinutes,
        'timerEndMinutes': timerEndMinutes,
        'timerRepeat': timerRepeat,
      };
}

/// 手动模式中一个地暖区域的已确认设置。
///
/// 房间名称和在线状态来自 runtime；这里仅保存用户可控制且需要重启保留的
/// 开关、设定温度和定时参数。
class ManualFloorHeatSetting {
  const ManualFloorHeatSetting({
    required this.deviceId,
    required this.enabled,
    required this.targetTemperatureC,
    required this.timerEnabled,
    required this.timerStartMinutes,
    required this.timerEndMinutes,
    required this.timerRepeat,
  });

  final String deviceId;
  final bool enabled;
  final int targetTemperatureC;
  final bool timerEnabled;
  final int timerStartMinutes;
  final int timerEndMinutes;
  final String timerRepeat;

  ManualFloorHeatSetting copyWith({
    bool? enabled,
    int? targetTemperatureC,
    bool? timerEnabled,
    int? timerStartMinutes,
    int? timerEndMinutes,
    String? timerRepeat,
  }) {
    return ManualFloorHeatSetting(
      deviceId: deviceId,
      enabled: enabled ?? this.enabled,
      targetTemperatureC: targetTemperatureC ?? this.targetTemperatureC,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerStartMinutes: timerStartMinutes ?? this.timerStartMinutes,
      timerEndMinutes: timerEndMinutes ?? this.timerEndMinutes,
      timerRepeat: timerRepeat ?? this.timerRepeat,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'enabled': enabled,
        'targetTemperatureC': targetTemperatureC,
        'timerEnabled': timerEnabled,
        'timerStartMinutes': timerStartMinutes,
        'timerEndMinutes': timerEndMinutes,
        'timerRepeat': timerRepeat,
      };
}

/// 设备侧提供的地暖区域快照；UI 只读，不把房间拓扑写回 settings。
class FloorHeatZoneSnapshot {
  const FloorHeatZoneSnapshot({
    required this.deviceId,
    required this.roomName,
    required this.online,
  });

  final String deviceId;
  final String roomName;
  final bool online;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'roomName': roomName,
        'online': online,
      };
}

/// 设备侧提供的一台空调运行快照；UI 只读，不把设备拓扑写回 settings。
///
/// 空调和地暖分别维护自己的 runtime 数组。数组的顺序就是手动页的
/// 展示顺序；数组可以为空，也可以很多，页面只取前 16 项。
class AirConditionerZoneSnapshot {
  const AirConditionerZoneSnapshot({
    required this.deviceId,
    required this.roomName,
    required this.online,
  });

  final String deviceId;
  final String roomName;
  final bool online;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'roomName': roomName,
        'online': online,
      };
}

/// 设备侧提供的一条通知或故障展示记录。
///
/// 两类记录共用同一组只读字段，但分别存放在 runtime 的
/// `notifications` 与 `faults` 数组中，避免两个弹窗互相耦合。
class DashboardAlertItem {
  const DashboardAlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
  });

  final String id;
  final String title;
  final String description;
  final String date;

  factory DashboardAlertItem.fromJson(Map<String, dynamic> json) {
    return DashboardAlertItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      date: json['date'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'date': date,
      };
}

/// 单个智能模式的独立确认状态。
///
/// 每个模式分别保存自己的开关和温湿度参数；运行状态遵守产品说明书的
/// 全局互斥规则，任意时刻最多一个模式开启，但各模式参数会独立保留。
class SmartModeSetting {
  const SmartModeSetting({
    required this.enabled,
    required this.temperatureSetpointC,
    required this.humiditySetpointPercent,
  });

  final bool enabled;
  final int temperatureSetpointC;
  final int humiditySetpointPercent;

  SmartModeSetting copyWith({
    bool? enabled,
    int? temperatureSetpointC,
    int? humiditySetpointPercent,
  }) {
    return SmartModeSetting(
      enabled: enabled ?? this.enabled,
      temperatureSetpointC: temperatureSetpointC ?? this.temperatureSetpointC,
      humiditySetpointPercent:
          humiditySetpointPercent ?? this.humiditySetpointPercent,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'temperatureSetpointC': temperatureSetpointC,
        'humiditySetpointPercent': humiditySetpointPercent,
      };
}

/// dashboard_runtime.json 中 Wi-Fi 事务快照的唯一字段表。
///
/// 后端 HTTP 使用语义更自然的 `available/enabled/...`；前端只在 HTTP
/// 适配边界转换一次，内部读取、校验和落盘统一使用本字段表。
class DashboardWifiRuntimeKeys {
  DashboardWifiRuntimeKeys._();

  static const String available = 'wifiAvailable';
  static const String enabled = 'wifiActualEnabled';
  static const String connected = 'wifiConnected';
  static const String connectedSsid = 'wifiConnectedSsid';
  static const String ipAddress = 'wifiIpAddress';
  static const String operation = 'wifiOperation';
  static const String operationSsid = 'wifiOperationSsid';
  static const String error = 'wifiError';
  static const String availableSsids = 'availableWifiSsids';
  static const String securedSsids = 'wifiSecuredSsids';

  static const Set<String> supportedOperations = <String>{
    'disabled',
    'idle',
    'scanning',
    'connecting',
    'connected',
    'disconnecting',
    'failed',
  };
}

/// Wi-Fi 运行态的不可拆快照。
///
/// JSON 仍保持现有扁平字段，避免破坏离线模板；业务层只读取本快照，
/// 不能把后端运行态、本地测试态和设置目标逐字段拼接。
class DashboardWifiState {
  DashboardWifiState._({
    required this.available,
    required this.enabled,
    required this.connected,
    required this.ssid,
    required this.ipAddress,
    required this.operation,
    required this.operationSsid,
    required this.error,
    required this.availableSsids,
    required this.securedSsids,
  });

  factory DashboardWifiState.normalized({
    required bool available,
    required bool enabled,
    required bool connected,
    required String ssid,
    required String ipAddress,
    required String operation,
    required String operationSsid,
    required String error,
    required List<String> availableSsids,
    required List<String> securedSsids,
  }) {
    if (!available) {
      return DashboardWifiState._(
        available: false,
        enabled: false,
        connected: false,
        ssid: '',
        ipAddress: '',
        operation: 'disabled',
        operationSsid: '',
        error: error,
        availableSsids: const <String>[],
        securedSsids: const <String>[],
      );
    }
    if (!enabled) {
      return DashboardWifiState._(
        available: true,
        enabled: false,
        connected: false,
        ssid: '',
        ipAddress: '',
        operation: 'disabled',
        operationSsid: '',
        error: error,
        availableSsids: const <String>[],
        securedSsids: const <String>[],
      );
    }

    final normalizedSsids = List<String>.unmodifiable(availableSsids);
    final normalizedSecuredSsids = List<String>.unmodifiable(
      securedSsids.where(normalizedSsids.contains),
    );
    final normalizedConnected = connected && ssid.isNotEmpty;
    return DashboardWifiState._(
      available: true,
      enabled: true,
      connected: normalizedConnected,
      ssid: normalizedConnected ? ssid : '',
      ipAddress: normalizedConnected ? ipAddress : '',
      operation: operation,
      operationSsid: operationSsid,
      error: error,
      availableSsids: normalizedSsids,
      securedSsids: normalizedSecuredSsids,
    );
  }

  final bool available;
  final bool enabled;
  final bool connected;
  final String ssid;
  final String ipAddress;
  final String operation;
  final String operationSsid;
  final String error;
  final List<String> availableSsids;
  final List<String> securedSsids;

  Map<String, dynamic> toRuntimePatch() => <String, dynamic>{
        DashboardWifiRuntimeKeys.available: available,
        DashboardWifiRuntimeKeys.enabled: enabled,
        DashboardWifiRuntimeKeys.connected: connected,
        DashboardWifiRuntimeKeys.connectedSsid: ssid,
        DashboardWifiRuntimeKeys.ipAddress: ipAddress,
        DashboardWifiRuntimeKeys.operation: operation,
        DashboardWifiRuntimeKeys.operationSsid: operationSsid,
        DashboardWifiRuntimeKeys.error: error,
        DashboardWifiRuntimeKeys.availableSsids: availableSsids,
        DashboardWifiRuntimeKeys.securedSsids: securedSsids,
      };

  List<Object?> get signature => <Object?>[
        available,
        enabled,
        connected,
        ssid,
        ipAddress,
        operation,
        operationSsid,
        error,
        availableSsids,
        securedSsids,
      ];
}

/// 主页展示和交互所需的数据。
///
/// 实时时间不写入 JSON，而是始终读取设备本地时间。
///
/// 刷新维护要求：给本类新增字段后，必须同步检查
/// `dashboard_page_refresh_policy.dart`，把字段登记到所有实际使用它的页面刷新签名，
/// 并补“相关页面刷新、无关页面不刷新”的测试。只改本类和 JSON 解析不算完成；
/// 漏登记会导致数据已经读入内存，但当前页面在两秒轮询后仍保持旧画面。
class DashboardData {
  const DashboardData({
    required this.areaName,
    required this.outdoorTemperatureC,
    required this.outdoorHumidityPercent,
    required this.outdoorPm25,
    required this.indoorPm25,
    required this.indoorTemperatureC,
    required this.indoorHumidityPercent,
    required this.indoorCo2Ppm,
    required this.indoorFormaldehydeMgM3,
    required this.dailyTemperatureIndoorC,
    required this.dailyTemperatureOutdoorC,
    required this.weeklyTemperatureIndoorC,
    required this.weeklyTemperatureOutdoorC,
    required this.monthlyTemperatureIndoorC,
    required this.monthlyTemperatureOutdoorC,
    required this.monthlyTrendYear,
    required this.monthlyTrendMonth,
    required this.dailyHumidityIndoorPercent,
    required this.dailyHumidityOutdoorPercent,
    required this.weeklyHumidityIndoorPercent,
    required this.weeklyHumidityOutdoorPercent,
    required this.monthlyHumidityIndoorPercent,
    required this.monthlyHumidityOutdoorPercent,
    required this.dailyPm25Indoor,
    required this.dailyPm25Outdoor,
    required this.weeklyPm25Indoor,
    required this.weeklyPm25Outdoor,
    required this.monthlyPm25Indoor,
    required this.monthlyPm25Outdoor,
    required this.dailyCo2Ppm,
    required this.weeklyCo2Ppm,
    required this.monthlyCo2Ppm,
    required this.runningDeviceCount,
    required this.totalDeviceCount,
    required this.availableDeviceTypes,
    required this.homeFloorLayeringEnabled,
    required this.allDevicesOn,
    this.leaveHomeModeEnabled = false,
    required this.homeFloorSelection,
    required this.timeFormat,
    required this.dateYear,
    required this.dateMonth,
    required this.dateDay,
    required this.clockHour,
    required this.clockMinute,
    required this.clockSecond,
    required this.languageCode,
    required this.screenBrightnessPercent,
    this.screenBrightnessAvailable = false,
    this.screenBrightnessActualPercent = 75,
    required this.priorityMetric,
    required this.aqiIndicatorEnabled,
    this.aqiIndicatorAvailable = false,
    this.aqiIndicatorActualEnabled = true,
    this.aqiIndicatorActualLevel = 1,
    required this.presenceRadarEnabled,
    required this.presenceRadarDistanceMeters,
    required this.buzzerFeedbackEnabled,
    required this.buzzerVolume,
    required this.indicatorLightBrightness,
    required this.screenOffSeconds,
    required this.airQualityAutoDetectionEnabled,
    required this.wifiEnabled,
    required this.wifiSsid,
    required this.savedWifiNetworks,
    required this.timerEnabled,
    required this.timerStartMinutes,
    required this.timerEndMinutes,
    required this.timerRepeatDays,
    required this.manualAirConditioners,
    required this.manualFloorHeatSettings,
    required this.manualFreshAirMode,
    required this.manualFreshAirFanLevel,
    required this.manualFreshAirTimerEnabled,
    required this.manualFreshAirTimerStartMinutes,
    required this.manualFreshAirTimerEndMinutes,
    required this.manualFreshAirTimerRepeat,
    required this.manualHumidifierSetpointPercent,
    required this.manualHumidifierTimerEnabled,
    required this.manualHumidifierTimerStartMinutes,
    required this.manualHumidifierTimerEndMinutes,
    required this.manualHumidifierTimerRepeat,
    required this.manualPureDuration,
    required this.smartModes,
    required this.filter1RemainingDays,
    required this.filter2RemainingDays,
    required this.filter3RemainingDays,
    this.airConditionerEnabled = false,
    this.floorHeatEnabled = false,
    this.freshAirEnabled = false,
    this.humidifierEnabled = false,
    this.pureEnabled = false,
    this.allDevicesRunning = false,
    this.freshAirRunning = false,
    this.humidifierRunning = false,
    this.pureRunning = false,
    this.freshAirModeActual = 'full_heat_exchange',
    this.freshAirFanLevelActual = 'L2',
    this.humidifierSetpointActualPercent = 30,
    required this.weatherCode,
    required this.weatherTemperatureRange,
    required this.wifiConnected,
    required this.wifiIpAddress,
    required this.availableWifiSsids,
    this.wifiAvailable = false,
    this.wifiActualEnabled = true,
    this.wifiConnectedSsid = '',
    this.wifiOperation = 'idle',
    this.wifiOperationSsid = '',
    this.wifiError = '',
    this.wifiSecuredSsids = const <String>[],
    required this.notificationBellVisible,
    required this.notifications,
    required this.faults,
    required this.faultServicePhone,
    required this.smartAirConditionerMode,
    required this.smartAirConditionerFanLevel,
    required this.smartFreshAirMode,
    required this.smartFreshAirFanLevel,
    required this.floorHeatControlMode,
    required this.airConditionerZones,
    required this.floorHeatZones,
    required this.backendDataStatus,
    required this.homeError,
    this.versionUpdateStatus = 'idle',
    this.latestVersion = 'V1.32.48 20260823-1355',
  });

  // 保留一键总开关与五个设备的独立开关两层语义。
  /// 主页设备卡固定顺序。runtime 只选择存在项，不能重排。
  static const List<String> availableDeviceTypeOrder = <String>[
    'air_conditioner',
    'floor_heat',
    'fresh_air',
    'humidifier',
    'pure',
  ];
  static const Set<String> supportedAvailableDeviceTypes = <String>{
    'air_conditioner',
    'floor_heat',
    'fresh_air',
    'humidifier',
    'pure',
  };
  static const Set<String> supportedBackendDataStatuses = <String>{
    'fresh',
    'stale',
    'unreachable',
  };
  static const List<String> homeFloorSelectionOrder = <String>[
    'all',
    'basement_1',
    'basement_2',
    'floor_1',
    'floor_2',
    'floor_3',
  ];
  static const Set<String> supportedHomeFloorSelections = <String>{
    'all',
    'basement_1',
    'basement_2',
    'floor_1',
    'floor_2',
    'floor_3',
  };

  static const Set<String> supportedTimeFormats = <String>{'24h', '12h'};
  static const Set<String> supportedLanguageCodes = <String>{
    'zh_CN',
    'ja_JP',
    'en_US',
  };
  static const Set<String> supportedPriorityMetrics = <String>{
    'temperature',
    'humidity',
    'co2',
    'formaldehyde',
    'pm25',
  };
  static const Set<String> supportedBuzzerVolumes = <String>{
    'low',
    'medium',
    'high',
  };
  static const Set<int> supportedPresenceRadarDistanceMeters = <int>{1, 2, 3};
  static const Set<int> supportedScreenOffSeconds = <int>{15, 30, 45, 60};
  static const Set<String> supportedSmartModes = <String>{
    'standard',
    'guest',
    'dry',
    'warm',
    'travel',
  };
  static const Set<String> supportedFloorHeatControlModes = <String>{
    'zoned',
    'whole_home',
  };
  static const Set<String> supportedManualFreshAirModes = <String>{
    'internal_circulation',
    'full_heat_exchange',
    'auto',
  };
  static const Set<String> supportedManualFreshAirFanLevels = <String>{
    'L1',
    'L2',
    'L3',
    'L4',
    'L5',
  };
  static const Set<String> supportedManualTimerRepeats = <String>{
    'once',
    'weekdays',
    'daily',
    'off',
  };
  static const Set<String> supportedManualPureDurations = <String>{
    '1h',
    '2h',
    '3h',
    'hold',
  };
  static const Set<String> supportedVersionUpdateStatuses = <String>{
    'idle',
    'available',
    'downloading',
    'download_failed',
    'updating',
  };
  static const String wholeHomeFloorHeatDeviceId = 'floor_heat_whole_home';

  final String areaName;
  final int outdoorTemperatureC;
  final int outdoorHumidityPercent;
  final int outdoorPm25;
  final int indoorPm25;
  final int indoorTemperatureC;
  final int indoorHumidityPercent;
  final int indoorCo2Ppm;
  final double indoorFormaldehydeMgM3;

  /// 按日温度趋势的 12 个时点（10:00 至次日 08:00），仅由 runtime 提供。
  final List<double> dailyTemperatureIndoorC;
  final List<double> dailyTemperatureOutdoorC;

  /// 按周温度趋势点由 runtime 提供；按月最多保留 31 项，界面按自然月天数读取。
  final List<double> weeklyTemperatureIndoorC;
  final List<double> weeklyTemperatureOutdoorC;
  final List<double> monthlyTemperatureIndoorC;
  final List<double> monthlyTemperatureOutdoorC;

  /// 月趋势采样所对应的自然月；用于确定当月实际 28、29、30 或 31 天。
  final int monthlyTrendYear;
  final int monthlyTrendMonth;

  /// 湿度与 PM2.5 的趋势采样规则与温度相同：按日 12 点、按周 7 点、按月 29/30/31 项。
  final List<double> dailyHumidityIndoorPercent;
  final List<double> dailyHumidityOutdoorPercent;
  final List<double> weeklyHumidityIndoorPercent;
  final List<double> weeklyHumidityOutdoorPercent;
  final List<double> monthlyHumidityIndoorPercent;
  final List<double> monthlyHumidityOutdoorPercent;
  final List<double> dailyPm25Indoor;
  final List<double> dailyPm25Outdoor;
  final List<double> weeklyPm25Indoor;
  final List<double> weeklyPm25Outdoor;
  final List<double> monthlyPm25Indoor;
  final List<double> monthlyPm25Outdoor;

  /// CO₂ 只有室内一组趋势数据：按日 12 点、按周 7 点、按月 29/30/31 点。
  final List<double> dailyCo2Ppm;
  final List<double> weeklyCo2Ppm;
  final List<double> monthlyCo2Ppm;
  final int runningDeviceCount;
  final int totalDeviceCount;
  final List<String> availableDeviceTypes;
  final bool homeFloorLayeringEnabled;
  final bool allDevicesOn;
  final bool leaveHomeModeEnabled;
  final String homeFloorSelection;
  final String timeFormat;
  final int dateYear;
  final int dateMonth;
  final int dateDay;
  final int clockHour;
  final int clockMinute;
  final int clockSecond;
  final String languageCode;

  /// 用户设置目标；后端不可达或尚无可靠读值时作为界面基准。
  final int screenBrightnessPercent;

  /// 后端是否已经取得本机数值调整器的可靠实际值。
  final bool screenBrightnessAvailable;

  /// 后端发布的本机实际值；只有 [screenBrightnessAvailable] 为真时有效。
  final int screenBrightnessActualPercent;

  int get effectiveScreenBrightnessPercent =>
      backendDataStatus == 'unreachable' || !screenBrightnessAvailable
          ? screenBrightnessPercent
          : screenBrightnessActualPercent;
  final String priorityMetric;
  final bool aqiIndicatorEnabled;
  final bool aqiIndicatorAvailable;
  final bool aqiIndicatorActualEnabled;
  final int aqiIndicatorActualLevel;

  bool get effectiveAqiIndicatorEnabled =>
      backendDataStatus == 'unreachable' || !aqiIndicatorAvailable
          ? aqiIndicatorEnabled
          : aqiIndicatorActualEnabled;
  final bool presenceRadarEnabled;
  final int presenceRadarDistanceMeters;
  final bool buzzerFeedbackEnabled;
  final String buzzerVolume;
  final String indicatorLightBrightness;
  final int screenOffSeconds;
  final bool airQualityAutoDetectionEnabled;
  final bool wifiEnabled;
  final String wifiSsid;
  final List<SavedWifiNetwork> savedWifiNetworks;
  final bool timerEnabled;
  final int timerStartMinutes;
  final int timerEndMinutes;
  final List<int> timerRepeatDays;
  final List<ManualAirConditionerSetting> manualAirConditioners;
  final List<ManualFloorHeatSetting> manualFloorHeatSettings;
  final String manualFreshAirMode;
  final String manualFreshAirFanLevel;
  final bool manualFreshAirTimerEnabled;
  final int manualFreshAirTimerStartMinutes;
  final int manualFreshAirTimerEndMinutes;
  final String manualFreshAirTimerRepeat;
  final int manualHumidifierSetpointPercent;
  final bool manualHumidifierTimerEnabled;
  final int manualHumidifierTimerStartMinutes;
  final int manualHumidifierTimerEndMinutes;
  final String manualHumidifierTimerRepeat;
  final String manualPureDuration;
  final Map<String, SmartModeSetting> smartModes;

  /// 三个滤网的确认剩余天数；由“设备维护-重置”写入 settings。
  final int filter1RemainingDays;
  final int filter2RemainingDays;
  final int filter3RemainingDays;
  final bool airConditionerEnabled;
  final bool floorHeatEnabled;
  final bool freshAirEnabled;
  final bool humidifierEnabled;
  final bool pureEnabled;

  /// 4CP 实际运行状态；只来自 runtime，设置目标不能覆盖这些字段。
  final bool allDevicesRunning;
  final bool freshAirRunning;
  final bool humidifierRunning;
  final bool pureRunning;
  final String freshAirModeActual;
  final String freshAirFanLevelActual;
  final int humidifierSetpointActualPercent;

  /// 天气 PNG/GIF 素材名（不含扩展名），全小写下划线命名，例如
  /// `01_clear_day`。
  final String weatherCode;
  final String weatherTemperatureRange;
  final bool wifiConnected;
  final String wifiIpAddress;
  final List<String> availableWifiSsids;
  final bool wifiAvailable;
  final bool wifiActualEnabled;
  final String wifiConnectedSsid;
  final String wifiOperation;
  final String wifiOperationSsid;
  final String wifiError;
  final List<String> wifiSecuredSsids;

  bool get backendReachable => backendDataStatus != 'unreachable';

  /// 当前唯一生效的 Wi-Fi 事务快照。
  ///
  /// 后端可达时整组使用运行快照；不可达时整组使用本地测试状态。
  /// 两条来源不会逐字段混合。
  DashboardWifiState get effectiveWifiState => backendReachable
      ? DashboardWifiState.normalized(
          available: wifiAvailable,
          enabled: wifiActualEnabled,
          connected: wifiConnected,
          ssid: wifiConnectedSsid,
          ipAddress: wifiIpAddress,
          operation: wifiOperation,
          operationSsid: wifiOperationSsid,
          error: wifiError,
          availableSsids: availableWifiSsids,
          securedSsids: wifiSecuredSsids,
        )
      : DashboardWifiState.normalized(
          available: true,
          enabled: wifiEnabled,
          connected: wifiConnected,
          ssid: wifiSsid,
          ipAddress: wifiIpAddress,
          operation: wifiEnabled ? 'idle' : 'disabled',
          operationSsid: '',
          error: '',
          availableSsids: availableWifiSsids,
          securedSsids: wifiSecuredSsids,
        );

  bool get effectiveWifiEnabled => effectiveWifiState.enabled;

  bool get effectiveWifiConnected => effectiveWifiState.connected;

  String get effectiveWifiSsid => effectiveWifiState.ssid;

  List<String> get effectiveAvailableWifiSsids =>
      effectiveWifiState.availableSsids;

  // ===== 环境数据展示辅助 getter =====
  // 直接返回原始值的字符串形式，不再做数据陈旧或范围检查。

  /// 室内环境数据
  String get displayIndoorPm25 => '$indoorPm25';
  String get displayIndoorTemperatureC => '$indoorTemperatureC';
  String get displayIndoorHumidityPercent => '$indoorHumidityPercent';
  String get displayIndoorCo2Ppm => '$indoorCo2Ppm';
  String get displayIndoorFormaldehydeMgM3 =>
      indoorFormaldehydeMgM3.toStringAsFixed(2);

  /// 室外环境数据
  String get displayOutdoorTemperatureC => '$outdoorTemperatureC';
  String get displayOutdoorHumidityPercent => '$outdoorHumidityPercent';
  String get displayOutdoorPm25 => '$outdoorPm25';

  /// 天气展示（weatherCode 用于加载图片素材，始终保留最后有效值）
  String get displayWeatherTemperatureRange => weatherTemperatureRange;

  /// 是否有任意智能模式正在运行
  bool get smartModeRunning =>
      smartModes.values.any((m) => m.enabled);

  /// 是否有任意手动模式正在运行（与智能模式互斥）
  bool get manualModeRunning =>
      backendReachable && allDevicesOn && !smartModeRunning;

  /// 一键离家模式是否激活：离家模式要求只有新风开启，其它设备关闭。
  bool get leaveHomeActive =>
      leaveHomeModeEnabled &&
      allDevicesOn &&
      freshAirEnabled &&
      !airConditionerEnabled &&
      !floorHeatEnabled &&
      !humidifierEnabled &&
      !pureEnabled;

  /// 设备实际模式/档位（始终按本地缓存展示）
  String get displayFreshAirModeActual => freshAirModeActual;
  String get displayFreshAirFanLevelActual => freshAirFanLevelActual;
  String get displayHumidifierSetpointActualPercent =>
      '$humidifierSetpointActualPercent';
  final bool notificationBellVisible;
  final List<DashboardAlertItem> notifications;
  final List<DashboardAlertItem> faults;
  final String faultServicePhone;

  /// 智能模式下的设备实际运行反馈；由 runtime 提供，界面只读展示。
  final String smartAirConditionerMode;
  final String smartAirConditionerFanLevel;
  final String smartFreshAirMode;
  final String smartFreshAirFanLevel;

  /// 地暖展示形态和区域清单均由 runtime 提供；页面进入后锁定本次形态，
  /// 避免两秒刷新把用户正在操作的页面切走。
  final String floorHeatControlMode;
  final List<AirConditionerZoneSnapshot> airConditionerZones;
  final List<FloorHeatZoneSnapshot> floorHeatZones;

  /// BeiAng8Panel 聚合快照状态：正常、设备数据陈旧或后端不可达。
  final String backendDataStatus;

  final String? homeError; // non-null → show error overlay (R43/R66)

  /// 版本更新状态：idle（无可用更新）、available（有可用更新）、
  /// downloading（下载中）、download_failed（下载失败）、updating（更新中）。
  final String versionUpdateStatus;

  /// 最新版本号，如 'V1.32.48 20260823-1355'。
  final String latestVersion;

  /// 自然月实际天数；闰年二月会正确返回 29 天。
  static int monthlyTrendDayCount(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// 将自然月中的某一天映射到固定 31 天横轴的 0～1 坐标。
  ///
  /// 第 1 天位于起点，第 31 天位于终点，因此 28、29、30、31 日的
  /// 终点比例依次是 27/30、28/30、29/30、30/30。
  static double monthlyTrendDayFraction(int day) {
    if (day < 1 || day > 31) {
      throw RangeError.range(day, 1, 31, 'day');
    }
    return (day - 1) / 30;
  }

  /// 按月趋势与平均值实际读取的数据量。
  ///
  /// 数组允许统一预留 31 项；界面只读取当前自然月所需的 28、29、30 或 31 项。
  /// 若底层暂时提供的数据更少，则只读取已有数据，不凭空补点。
  static int monthlyTrendVisibleCount(
    int year,
    int month,
    int storedCount,
  ) {
    final dayCount = monthlyTrendDayCount(year, month);
    return storedCount < dayCount ? storedCount : dayCount;
  }

  factory DashboardData.defaults() {
    return DashboardData(
      areaName: '上海市·徐汇区',
      outdoorTemperatureC: 26,
      outdoorHumidityPercent: 70,
      outdoorPm25: 128,
      indoorPm25: 28,
      indoorTemperatureC: 26,
      indoorHumidityPercent: 56,
      indoorCo2Ppm: 425,
      indoorFormaldehydeMgM3: 0.03,
      dailyTemperatureIndoorC: <double>[
        22.7,
        24.8,
        24.0,
        24.1,
        23.8,
        24.4,
        23.9,
        26.5,
        25.2,
        24.5,
        26.0,
        24.7,
      ],
      dailyTemperatureOutdoorC: <double>[
        23.5,
        28.0,
        27.7,
        29.2,
        30.8,
        30.5,
        31.0,
        34.2,
        38.4,
        35.1,
        32.2,
        31.8,
      ],
      weeklyTemperatureIndoorC: <double>[
        24.0,
        23.7,
        23.1,
        24.2,
        24.0,
        24.5,
        24.0
      ],
      weeklyTemperatureOutdoorC: <double>[
        31.0,
        31.5,
        32.0,
        31.2,
        31.8,
        29.8,
        31.5
      ],
      monthlyTemperatureIndoorC: _monthlySamples(<double>[
        22.0,
        23.3,
        23.0,
        24.5,
        22.3,
        24.4,
        24.5,
      ]),
      monthlyTemperatureOutdoorC: _monthlySamples(<double>[
        32.0,
        32.6,
        33.2,
        33.1,
        34.3,
        33.3,
        33.0,
      ]),
      monthlyTrendYear: 2026,
      monthlyTrendMonth: 10,
      dailyHumidityIndoorPercent: <double>[
        54,
        55,
        56,
        55,
        54,
        56,
        57,
        58,
        57,
        56,
        56,
        55
      ],
      dailyHumidityOutdoorPercent: <double>[
        72,
        74,
        76,
        75,
        73,
        71,
        70,
        68,
        67,
        69,
        71,
        73
      ],
      weeklyHumidityIndoorPercent: <double>[54, 55, 56, 55, 57, 56, 56],
      weeklyHumidityOutdoorPercent: <double>[72, 70, 69, 73, 75, 74, 71],
      monthlyHumidityIndoorPercent: _monthlySamples(<double>[
        53,
        55,
        54,
        56,
        57,
        55,
        56,
      ]),
      monthlyHumidityOutdoorPercent: _monthlySamples(<double>[
        70,
        72,
        74,
        73,
        71,
        69,
        72,
      ]),
      dailyPm25Indoor: <double>[24, 25, 27, 26, 28, 29, 31, 30, 28, 27, 29, 28],
      dailyPm25Outdoor: <double>[
        96,
        104,
        116,
        122,
        128,
        121,
        132,
        140,
        136,
        126,
        118,
        112
      ],
      weeklyPm25Indoor: <double>[24, 26, 28, 27, 30, 29, 28],
      weeklyPm25Outdoor: <double>[98, 112, 126, 119, 138, 128, 116],
      monthlyPm25Indoor: _monthlySamples(<double>[
        22,
        25,
        27,
        29,
        28,
        30,
        28,
      ]),
      monthlyPm25Outdoor: _monthlySamples(<double>[
        92,
        106,
        118,
        132,
        125,
        138,
        120,
      ]),
      dailyCo2Ppm: <double>[
        450,
        480,
        470,
        475,
        468,
        480,
        470,
        520,
        490,
        510,
        500,
        480,
      ],
      weeklyCo2Ppm: <double>[420, 455, 438, 470, 445, 485, 462],
      monthlyCo2Ppm: _monthlySamples(<double>[
        430,
        450,
        440,
        460,
        425,
        470,
        445,
      ]),
      runningDeviceCount: 0,
      totalDeviceCount: 20,
      availableDeviceTypes: availableDeviceTypeOrder,
      homeFloorLayeringEnabled: true,
      allDevicesOn: false,
      leaveHomeModeEnabled: false,
      homeFloorSelection: 'floor_1',
      timeFormat: '24h',
      dateYear: 2026,
      dateMonth: 8,
      dateDay: 15,
      clockHour: 0,
      clockMinute: 0,
      clockSecond: 0,
      languageCode: 'zh_CN',
      screenBrightnessPercent: 75,
      screenBrightnessAvailable: false,
      screenBrightnessActualPercent: 75,
      priorityMetric: 'pm25',
      aqiIndicatorEnabled: true,
      aqiIndicatorAvailable: false,
      aqiIndicatorActualEnabled: true,
      aqiIndicatorActualLevel: 1,
      presenceRadarEnabled: true,
      presenceRadarDistanceMeters: 1,
      buzzerFeedbackEnabled: false,
      buzzerVolume: 'medium',
      indicatorLightBrightness: 'bright',
      screenOffSeconds: 30,
      airQualityAutoDetectionEnabled: true,
      wifiEnabled: true,
      wifiSsid: 'CMCC-6U55-5G',
      savedWifiNetworks: const <SavedWifiNetwork>[
        SavedWifiNetwork(
          ssid: 'CMCC-6U55-5G',
          password: '666666',
        ),
      ],
      timerEnabled: false,
      timerStartMinutes: 18 * 60,
      timerEndMinutes: 22 * 60,
      timerRepeatDays: const <int>[1, 2, 3, 4, 5, 6],
      manualAirConditioners: const <ManualAirConditionerSetting>[
        ManualAirConditionerSetting(
          deviceId: 'air_conditioner_dining_room',
          roomName: '餐厅',
          enabled: true,
          targetTemperatureC: 24,
          mode: 'cooling',
          fanLevel: 'L2',
          timerEnabled: false,
          timerStartMinutes: 22 * 60,
          timerEndMinutes: 7 * 60,
          timerRepeat: 'daily',
        ),
        ManualAirConditionerSetting(
          deviceId: 'air_conditioner_master_bedroom',
          roomName: '卧室',
          enabled: true,
          targetTemperatureC: 26,
          mode: 'cooling',
          fanLevel: 'L3',
          timerEnabled: true,
          timerStartMinutes: 22 * 60,
          timerEndMinutes: 7 * 60,
          timerRepeat: 'daily',
        ),
        ManualAirConditionerSetting(
          deviceId: 'air_conditioner_children_room',
          roomName: '儿童房',
          enabled: true,
          targetTemperatureC: 27,
          mode: 'cooling',
          fanLevel: 'L1',
          timerEnabled: true,
          timerStartMinutes: 21 * 60,
          timerEndMinutes: 8 * 60,
          timerRepeat: 'weekdays',
        ),
        ManualAirConditionerSetting(
          deviceId: 'air_conditioner_guest_bedroom',
          roomName: '次卧',
          enabled: false,
          targetTemperatureC: 24,
          mode: 'cooling',
          fanLevel: 'L3',
          timerEnabled: true,
          timerStartMinutes: 22 * 60,
          timerEndMinutes: 7 * 60,
          timerRepeat: 'once',
        ),
      ],
      manualFloorHeatSettings: const <ManualFloorHeatSetting>[
        ManualFloorHeatSetting(
          deviceId: 'floor_heat_dining_room',
          enabled: true,
          targetTemperatureC: 26,
          timerEnabled: true,
          timerStartMinutes: 18 * 60,
          timerEndMinutes: 22 * 60,
          timerRepeat: 'once',
        ),
        ManualFloorHeatSetting(
          deviceId: 'floor_heat_bedroom',
          enabled: true,
          targetTemperatureC: 26,
          timerEnabled: true,
          timerStartMinutes: 22 * 60,
          timerEndMinutes: 7 * 60,
          timerRepeat: 'daily',
        ),
        ManualFloorHeatSetting(
          deviceId: 'floor_heat_children_room',
          enabled: true,
          targetTemperatureC: 26,
          timerEnabled: true,
          timerStartMinutes: 21 * 60,
          timerEndMinutes: 8 * 60,
          timerRepeat: 'weekdays',
        ),
        ManualFloorHeatSetting(
          deviceId: 'floor_heat_guest_bedroom',
          enabled: false,
          targetTemperatureC: 26,
          timerEnabled: true,
          timerStartMinutes: 22 * 60,
          timerEndMinutes: 7 * 60,
          timerRepeat: 'once',
        ),
        ManualFloorHeatSetting(
          deviceId: wholeHomeFloorHeatDeviceId,
          enabled: true,
          targetTemperatureC: 26,
          timerEnabled: true,
          timerStartMinutes: 18 * 60,
          timerEndMinutes: 22 * 60,
          timerRepeat: 'weekdays',
        ),
      ],
      manualFreshAirMode: 'full_heat_exchange',
      manualFreshAirFanLevel: 'L2',
      manualFreshAirTimerEnabled: true,
      manualFreshAirTimerStartMinutes: 21 * 60,
      manualFreshAirTimerEndMinutes: 8 * 60,
      manualFreshAirTimerRepeat: 'daily',
      manualHumidifierSetpointPercent: 30,
      manualHumidifierTimerEnabled: true,
      manualHumidifierTimerStartMinutes: 21 * 60,
      manualHumidifierTimerEndMinutes: 8 * 60,
      manualHumidifierTimerRepeat: 'daily',
      manualPureDuration: '2h',
      smartModes: const <String, SmartModeSetting>{
        'standard': SmartModeSetting(
          enabled: true,
          temperatureSetpointC: 25,
          humiditySetpointPercent: 60,
        ),
        'guest': SmartModeSetting(
          enabled: false,
          temperatureSetpointC: 24,
          humiditySetpointPercent: 55,
        ),
        'dry': SmartModeSetting(
          enabled: false,
          temperatureSetpointC: 24,
          humiditySetpointPercent: 40,
        ),
        'warm': SmartModeSetting(
          enabled: false,
          temperatureSetpointC: 26,
          humiditySetpointPercent: 55,
        ),
        'travel': SmartModeSetting(
          enabled: false,
          temperatureSetpointC: 25,
          humiditySetpointPercent: 55,
        ),
      },
      filter1RemainingDays: 90,
      filter2RemainingDays: 10,
      filter3RemainingDays: 300,
      airConditionerEnabled: false,
      floorHeatEnabled: false,
      freshAirEnabled: false,
      humidifierEnabled: false,
      pureEnabled: false,
      allDevicesRunning: false,
      freshAirRunning: false,
      humidifierRunning: false,
      pureRunning: false,
      freshAirModeActual: 'full_heat_exchange',
      freshAirFanLevelActual: 'L2',
      humidifierSetpointActualPercent: 30,
      weatherCode: '12_drizzle_to_middle_rain',
      weatherTemperatureRange: '28～38℃',
      wifiConnected: true,
      wifiIpAddress: '192.168.1.100',
      availableWifiSsids: const <String>[
        'beiang888',
        'AP-link-2.4G',
        'TPlink-2.4G',
        'TPlink-5G',
        'HomeLab-5G',
        'CMCC-Guest',
        'ChinaNet-5G',
        'ChinaNet-2.4G',
        'HUAWEI-5G-9A32',
        'HUAWEI-9A32',
        'MiWiFi_5G',
        'MiWiFi_2G',
        'Office-WiFi',
        'Office-Guest',
        'MeetingRoom',
        'R818-Debug',
        'EATON-Lab',
        'Beiang-Visitor',
        'Linksys-204',
        'NETGEAR-5G',
      ],
      wifiAvailable: false,
      wifiActualEnabled: true,
      wifiConnectedSsid: 'CMCC-6U55-5G',
      wifiOperation: 'idle',
      wifiOperationSsid: '',
      wifiError: '',
      wifiSecuredSsids: const <String>[],
      notificationBellVisible: true,
      notifications: const <DashboardAlertItem>[],
      faults: const <DashboardAlertItem>[],
      faultServicePhone: '400-888-6620',
      smartAirConditionerMode: '制冷',
      smartAirConditionerFanLevel: 'L1',
      smartFreshAirMode: '全热交换',
      smartFreshAirFanLevel: 'L1',
      floorHeatControlMode: 'zoned',
      airConditionerZones: const <AirConditionerZoneSnapshot>[
        AirConditionerZoneSnapshot(
          deviceId: 'air_conditioner_dining_room',
          roomName: '餐厅',
          online: true,
        ),
        AirConditionerZoneSnapshot(
          deviceId: 'air_conditioner_master_bedroom',
          roomName: '卧室',
          online: true,
        ),
        AirConditionerZoneSnapshot(
          deviceId: 'air_conditioner_children_room',
          roomName: '儿童房',
          online: true,
        ),
        AirConditionerZoneSnapshot(
          deviceId: 'air_conditioner_guest_bedroom',
          roomName: '次卧',
          online: true,
        ),
      ],
      floorHeatZones: const <FloorHeatZoneSnapshot>[
        FloorHeatZoneSnapshot(
          deviceId: 'floor_heat_dining_room',
          roomName: '餐厅',
          online: true,
        ),
        FloorHeatZoneSnapshot(
          deviceId: 'floor_heat_bedroom',
          roomName: '卧室',
          online: true,
        ),
        FloorHeatZoneSnapshot(
          deviceId: 'floor_heat_children_room',
          roomName: '儿童房',
          online: true,
        ),
        FloorHeatZoneSnapshot(
          deviceId: 'floor_heat_guest_bedroom',
          roomName: '次卧',
          online: true,
        ),
      ],
      backendDataStatus: 'fresh',
      homeError: null,
      versionUpdateStatus: 'idle',
      latestVersion: 'V1.32.48 20260823-1355',
    );
  }

  static List<double> _monthlySamples(List<double> seed) {
    return List<double>.generate(
      // 月数据统一预留 31 天；界面再按所选年月的实际天数读取。
      31,
      (index) => seed[index % seed.length],
    );
  }

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final defaults = DashboardData.defaults();
    final pureSettings = _readObject(json, 'pureSettings');
    return DashboardData(
      areaName: _readString(json, 'areaName', defaults.areaName),
      outdoorTemperatureC: _readInt(
        json,
        'outdoorTemperatureC',
        defaults.outdoorTemperatureC,
      ),
      outdoorHumidityPercent: _readInt(
        json,
        'outdoorHumidityPercent',
        defaults.outdoorHumidityPercent,
      ),
      outdoorPm25: _readInt(json, 'outdoorPm25', defaults.outdoorPm25),
      indoorPm25: _readInt(json, 'indoorPm25', defaults.indoorPm25),
      indoorTemperatureC: _readInt(
        json,
        'indoorTemperatureC',
        defaults.indoorTemperatureC,
      ),
      indoorHumidityPercent: _readInt(
        json,
        'indoorHumidityPercent',
        defaults.indoorHumidityPercent,
      ),
      indoorCo2Ppm: _readInt(json, 'indoorCo2Ppm', defaults.indoorCo2Ppm),
      indoorFormaldehydeMgM3: _readDouble(
        json,
        'indoorFormaldehydeMgM3',
        defaults.indoorFormaldehydeMgM3,
      ),
      dailyTemperatureIndoorC: _readDoubleList(
        json,
        'dailyTemperatureIndoorC',
        defaults.dailyTemperatureIndoorC,
      ),
      dailyTemperatureOutdoorC: _readDoubleList(
        json,
        'dailyTemperatureOutdoorC',
        defaults.dailyTemperatureOutdoorC,
      ),
      weeklyTemperatureIndoorC: _readDoubleList(
        json,
        'weeklyTemperatureIndoorC',
        defaults.weeklyTemperatureIndoorC,
      ),
      weeklyTemperatureOutdoorC: _readDoubleList(
        json,
        'weeklyTemperatureOutdoorC',
        defaults.weeklyTemperatureOutdoorC,
      ),
      monthlyTemperatureIndoorC: _readDoubleList(
        json,
        'monthlyTemperatureIndoorC',
        defaults.monthlyTemperatureIndoorC,
      ),
      monthlyTemperatureOutdoorC: _readDoubleList(
        json,
        'monthlyTemperatureOutdoorC',
        defaults.monthlyTemperatureOutdoorC,
      ),
      monthlyTrendYear: _readInt(
        json,
        'monthlyTrendYear',
        defaults.monthlyTrendYear,
      ),
      monthlyTrendMonth: _readInt(
        json,
        'monthlyTrendMonth',
        defaults.monthlyTrendMonth,
      ),
      dailyHumidityIndoorPercent: _readDoubleList(
        json,
        'dailyHumidityIndoorPercent',
        defaults.dailyHumidityIndoorPercent,
      ),
      dailyHumidityOutdoorPercent: _readDoubleList(
        json,
        'dailyHumidityOutdoorPercent',
        defaults.dailyHumidityOutdoorPercent,
      ),
      weeklyHumidityIndoorPercent: _readDoubleList(
        json,
        'weeklyHumidityIndoorPercent',
        defaults.weeklyHumidityIndoorPercent,
      ),
      weeklyHumidityOutdoorPercent: _readDoubleList(
        json,
        'weeklyHumidityOutdoorPercent',
        defaults.weeklyHumidityOutdoorPercent,
      ),
      monthlyHumidityIndoorPercent: _readDoubleList(
        json,
        'monthlyHumidityIndoorPercent',
        defaults.monthlyHumidityIndoorPercent,
      ),
      monthlyHumidityOutdoorPercent: _readDoubleList(
        json,
        'monthlyHumidityOutdoorPercent',
        defaults.monthlyHumidityOutdoorPercent,
      ),
      dailyPm25Indoor: _readDoubleList(
        json,
        'dailyPm25Indoor',
        defaults.dailyPm25Indoor,
      ),
      dailyPm25Outdoor: _readDoubleList(
        json,
        'dailyPm25Outdoor',
        defaults.dailyPm25Outdoor,
      ),
      weeklyPm25Indoor: _readDoubleList(
        json,
        'weeklyPm25Indoor',
        defaults.weeklyPm25Indoor,
      ),
      weeklyPm25Outdoor: _readDoubleList(
        json,
        'weeklyPm25Outdoor',
        defaults.weeklyPm25Outdoor,
      ),
      monthlyPm25Indoor: _readDoubleList(
        json,
        'monthlyPm25Indoor',
        defaults.monthlyPm25Indoor,
      ),
      monthlyPm25Outdoor: _readDoubleList(
        json,
        'monthlyPm25Outdoor',
        defaults.monthlyPm25Outdoor,
      ),
      dailyCo2Ppm: _readDoubleList(
        json,
        'dailyCo2Ppm',
        defaults.dailyCo2Ppm,
      ),
      weeklyCo2Ppm: _readDoubleList(
        json,
        'weeklyCo2Ppm',
        defaults.weeklyCo2Ppm,
      ),
      monthlyCo2Ppm: _readDoubleList(
        json,
        'monthlyCo2Ppm',
        defaults.monthlyCo2Ppm,
      ),
      runningDeviceCount: _readInt(
        json,
        'runningDeviceCount',
        defaults.runningDeviceCount,
      ),
      totalDeviceCount: _readInt(
        json,
        'totalDeviceCount',
        defaults.totalDeviceCount,
      ),
      availableDeviceTypes: _readStringList(
        json,
        'availableDeviceTypes',
        defaults.availableDeviceTypes,
      ),
      homeFloorLayeringEnabled: _readBool(
        json,
        'homeFloorLayeringEnabled',
        defaults.homeFloorLayeringEnabled,
      ),
      allDevicesOn: _readBool(
        json,
        'allDevicesOn',
        defaults.allDevicesOn,
      ),
      leaveHomeModeEnabled: _readBool(
        json,
        'leaveHomeModeEnabled',
        defaults.leaveHomeModeEnabled,
      ),
      homeFloorSelection: _readString(
        json,
        'homeFloorSelection',
        defaults.homeFloorSelection,
      ),
      timeFormat: _readString(json, 'timeFormat', defaults.timeFormat),
      dateYear: _readInt(json, 'dateYear', defaults.dateYear),
      dateMonth: _readInt(json, 'dateMonth', defaults.dateMonth),
      dateDay: _readInt(json, 'dateDay', defaults.dateDay),
      clockHour: _readInt(json, 'clockHour', defaults.clockHour),
      clockMinute: _readInt(json, 'clockMinute', defaults.clockMinute),
      clockSecond: _readInt(json, 'clockSecond', defaults.clockSecond),
      languageCode: _readString(json, 'languageCode', defaults.languageCode),
      screenBrightnessPercent: _readInt(
        json,
        'screenBrightnessPercent',
        defaults.screenBrightnessPercent,
      ),
      screenBrightnessAvailable: _readBool(
        json,
        'screenBrightnessAvailable',
        defaults.screenBrightnessAvailable,
      ),
      screenBrightnessActualPercent: _readInt(
        json,
        'screenBrightnessActualPercent',
        defaults.screenBrightnessActualPercent,
      ),
      priorityMetric: _readString(
        json,
        'priorityMetric',
        defaults.priorityMetric,
      ),
      aqiIndicatorEnabled: _readBool(
        json,
        'aqiIndicatorEnabled',
        defaults.aqiIndicatorEnabled,
      ),
      aqiIndicatorAvailable: _readBool(
        json,
        'aqiIndicatorAvailable',
        defaults.aqiIndicatorAvailable,
      ),
      aqiIndicatorActualEnabled: _readBool(
        json,
        'aqiIndicatorActualEnabled',
        defaults.aqiIndicatorActualEnabled,
      ),
      aqiIndicatorActualLevel: _readInt(
        json,
        'aqiIndicatorActualLevel',
        defaults.aqiIndicatorActualLevel,
      ),
      presenceRadarEnabled: _readBool(
        json,
        'presenceRadarEnabled',
        defaults.presenceRadarEnabled,
      ),
      presenceRadarDistanceMeters: _readInt(
        json,
        'presenceRadarDistanceMeters',
        defaults.presenceRadarDistanceMeters,
      ),
      buzzerFeedbackEnabled: _readBool(
        json,
        'buzzerFeedbackEnabled',
        defaults.buzzerFeedbackEnabled,
      ),
      buzzerVolume: _readString(
        json,
        'buzzerVolume',
        defaults.buzzerVolume,
      ),
      indicatorLightBrightness: _readString(
        json,
        'indicatorLightBrightness',
        defaults.indicatorLightBrightness,
      ),
      screenOffSeconds: _readInt(
        json,
        'screenOffSeconds',
        defaults.screenOffSeconds,
      ),
      airQualityAutoDetectionEnabled: _readBool(
        json,
        'airQualityAutoDetectionEnabled',
        defaults.airQualityAutoDetectionEnabled,
      ),
      wifiEnabled: _readBool(json, 'wifiEnabled', defaults.wifiEnabled),
      wifiSsid: _readStringAllowEmpty(json, 'wifiSsid', defaults.wifiSsid),
      savedWifiNetworks: _readSavedWifiNetworks(
        json,
        defaults.savedWifiNetworks,
      ),
      timerEnabled: _readBool(json, 'timerEnabled', defaults.timerEnabled),
      timerStartMinutes: _readInt(
        json,
        'timerStartMinutes',
        defaults.timerStartMinutes,
      ),
      timerEndMinutes: _readInt(
        json,
        'timerEndMinutes',
        defaults.timerEndMinutes,
      ),
      timerRepeatDays: _readIntList(
        json,
        'timerRepeatDays',
        defaults.timerRepeatDays,
      ),
      manualAirConditioners: _readManualAirConditioners(
        json,
        defaults.manualAirConditioners,
      ),
      manualFloorHeatSettings: _readManualFloorHeatSettings(
        json,
        defaults.manualFloorHeatSettings,
      ),
      manualFreshAirMode: _readString(
        json,
        'manualFreshAirMode',
        defaults.manualFreshAirMode,
      ),
      manualFreshAirFanLevel: _readString(
        json,
        'manualFreshAirFanLevel',
        defaults.manualFreshAirFanLevel,
      ),
      manualFreshAirTimerEnabled: _readBool(
        json,
        'manualFreshAirTimerEnabled',
        defaults.manualFreshAirTimerEnabled,
      ),
      manualFreshAirTimerStartMinutes: _readInt(
        json,
        'manualFreshAirTimerStartMinutes',
        defaults.manualFreshAirTimerStartMinutes,
      ),
      manualFreshAirTimerEndMinutes: _readInt(
        json,
        'manualFreshAirTimerEndMinutes',
        defaults.manualFreshAirTimerEndMinutes,
      ),
      manualFreshAirTimerRepeat: _readString(
        json,
        'manualFreshAirTimerRepeat',
        defaults.manualFreshAirTimerRepeat,
      ),
      manualHumidifierSetpointPercent: _readInt(
        json,
        'manualHumidifierSetpointPercent',
        defaults.manualHumidifierSetpointPercent,
      ),
      manualHumidifierTimerEnabled: _readBool(
        json,
        'manualHumidifierTimerEnabled',
        defaults.manualHumidifierTimerEnabled,
      ),
      manualHumidifierTimerStartMinutes: _readInt(
        json,
        'manualHumidifierTimerStartMinutes',
        defaults.manualHumidifierTimerStartMinutes,
      ),
      manualHumidifierTimerEndMinutes: _readInt(
        json,
        'manualHumidifierTimerEndMinutes',
        defaults.manualHumidifierTimerEndMinutes,
      ),
      manualHumidifierTimerRepeat: _readString(
        json,
        'manualHumidifierTimerRepeat',
        defaults.manualHumidifierTimerRepeat,
      ),
      manualPureDuration: pureSettings == null
          ? _readString(
              json,
              'manualPureDuration',
              defaults.manualPureDuration,
            )
          : _readString(
              pureSettings,
              'duration',
              defaults.manualPureDuration,
            ),
      smartModes: _readSmartModes(json, defaults.smartModes),
      filter1RemainingDays: _readInt(
        json,
        'filter1RemainingDays',
        defaults.filter1RemainingDays,
      ),
      filter2RemainingDays: _readInt(
        json,
        'filter2RemainingDays',
        defaults.filter2RemainingDays,
      ),
      filter3RemainingDays: _readInt(
        json,
        'filter3RemainingDays',
        defaults.filter3RemainingDays,
      ),
      airConditionerEnabled: _readBool(
        json,
        'airConditionerEnabled',
        defaults.airConditionerEnabled,
      ),
      floorHeatEnabled: _readBool(
        json,
        'floorHeatEnabled',
        defaults.floorHeatEnabled,
      ),
      freshAirEnabled: _readBool(
        json,
        'freshAirEnabled',
        defaults.freshAirEnabled,
      ),
      humidifierEnabled: _readBool(
        json,
        'humidifierEnabled',
        defaults.humidifierEnabled,
      ),
      pureEnabled: pureSettings == null
          ? _readBool(json, 'pureEnabled', defaults.pureEnabled)
          : _readBool(pureSettings, 'enabled', defaults.pureEnabled),
      allDevicesRunning: _readBool(
        json,
        'allDevicesRunning',
        defaults.allDevicesRunning,
      ),
      freshAirRunning: _readBool(
        json,
        'freshAirRunning',
        defaults.freshAirRunning,
      ),
      humidifierRunning: _readBool(
        json,
        'humidifierRunning',
        defaults.humidifierRunning,
      ),
      pureRunning: _readBool(
        json,
        'pureRunning',
        defaults.pureRunning,
      ),
      freshAirModeActual: _readString(
        json,
        'freshAirModeActual',
        defaults.freshAirModeActual,
      ),
      freshAirFanLevelActual: _readString(
        json,
        'freshAirFanLevelActual',
        defaults.freshAirFanLevelActual,
      ),
      humidifierSetpointActualPercent: _readInt(
        json,
        'humidifierSetpointActualPercent',
        defaults.humidifierSetpointActualPercent,
      ),
      weatherCode: _readString(json, 'weatherCode', defaults.weatherCode),
      weatherTemperatureRange: _readString(
        json,
        'weatherTemperatureRange',
        defaults.weatherTemperatureRange,
      ),
      wifiConnected: _readWifiConnected(json, defaults.wifiConnected),
      // IP 为空是合法状态：未连接，或已关联但 DHCP 尚未取得地址时，
      // 都由界面统一显示为“--”。
      wifiIpAddress: _readStringAllowEmpty(
        json,
        DashboardWifiRuntimeKeys.ipAddress,
        defaults.wifiIpAddress,
      ),
      availableWifiSsids: _readStringList(
        json,
        'availableWifiSsids',
        defaults.availableWifiSsids,
      ),
      wifiAvailable: _readBool(
        json,
        'wifiAvailable',
        defaults.wifiAvailable,
      ),
      wifiActualEnabled: _readBool(
        json,
        'wifiActualEnabled',
        defaults.wifiActualEnabled,
      ),
      wifiConnectedSsid: _readStringAllowEmpty(
        json,
        'wifiConnectedSsid',
        defaults.wifiConnectedSsid,
      ),
      wifiOperation: _readString(
        json,
        'wifiOperation',
        defaults.wifiOperation,
      ),
      wifiOperationSsid: _readStringAllowEmpty(
        json,
        'wifiOperationSsid',
        defaults.wifiOperationSsid,
      ),
      wifiError: _readStringAllowEmpty(
        json,
        'wifiError',
        defaults.wifiError,
      ),
      wifiSecuredSsids: _readStringList(
        json,
        'wifiSecuredSsids',
        defaults.wifiSecuredSsids,
      ),
      notificationBellVisible: _readBool(
        json,
        'notificationBellVisible',
        defaults.notificationBellVisible,
      ),
      notifications: _readAlertItems(
        json,
        'notifications',
        defaults.notifications,
      ),
      faults: _readAlertItems(
        json,
        'faults',
        defaults.faults,
      ),
      faultServicePhone: _readString(
        json,
        'faultServicePhone',
        defaults.faultServicePhone,
      ),
      smartAirConditionerMode: _readString(
        json,
        'smartAirConditionerMode',
        defaults.smartAirConditionerMode,
      ),
      smartAirConditionerFanLevel: _readString(
        json,
        'smartAirConditionerFanLevel',
        defaults.smartAirConditionerFanLevel,
      ),
      smartFreshAirMode: _readString(
        json,
        'smartFreshAirMode',
        defaults.smartFreshAirMode,
      ),
      smartFreshAirFanLevel: _readString(
        json,
        'smartFreshAirFanLevel',
        defaults.smartFreshAirFanLevel,
      ),
      floorHeatControlMode: _readString(
        json,
        'floorHeatControlMode',
        defaults.floorHeatControlMode,
      ),
      airConditionerZones: _readAirConditionerZones(
        json,
        defaults.airConditionerZones,
      ),
      floorHeatZones: _readFloorHeatZones(
        json,
        defaults.floorHeatZones,
      ),
      backendDataStatus: _readString(
        json,
        'backendDataStatus',
        defaults.backendDataStatus,
      ),
      homeError: _readNullableString(json, 'homeError'),
      versionUpdateStatus: _readString(
        json,
        'versionUpdateStatus',
        defaults.versionUpdateStatus,
      ),
      latestVersion: _readString(
        json,
        'latestVersion',
        defaults.latestVersion,
      ),
    );
  }

  /// 返回曾经成功连接过的密码；未记忆时返回 null。
  String? savedWifiPasswordFor(String ssid) {
    for (final network in savedWifiNetworks) {
      if (network.ssid == ssid) {
        return network.password;
      }
    }
    return null;
  }

  /// 连接成功后把网络移到最前面，只保留最近成功的 10 个记录。
  List<SavedWifiNetwork> rememberSuccessfulWifi(
    String ssid,
    String password,
  ) {
    final updated = <SavedWifiNetwork>[
      SavedWifiNetwork(ssid: ssid, password: password),
      ...savedWifiNetworks.where((network) => network.ssid != ssid),
    ];
    return List<SavedWifiNetwork>.unmodifiable(updated.take(10));
  }

  SmartModeSetting smartModeSetting(String mode) {
    final setting = smartModes[mode];
    if (setting == null) {
      throw ArgumentError.value(mode, 'mode', '不支持的智能模式');
    }
    return setting;
  }

  DashboardData copyWithSmartMode(
    String mode,
    SmartModeSetting setting,
  ) {
    if (!supportedSmartModes.contains(mode)) {
      throw ArgumentError.value(mode, 'mode', '不支持的智能模式');
    }
    return copyWith(
      smartModes: <String, SmartModeSetting>{
        for (final entry in smartModes.entries)
          entry.key: entry.key == mode
              ? setting
              : setting.enabled
                  ? entry.value.copyWith(enabled: false)
                  : entry.value,
      },
    );
  }

  DashboardData copyWith({
    bool? allDevicesOn,
    bool? leaveHomeModeEnabled,
    String? homeFloorSelection,
    bool? homeFloorLayeringEnabled,
    String? timeFormat,
    int? dateYear,
    int? dateMonth,
    int? dateDay,
    int? clockHour,
    int? clockMinute,
    int? clockSecond,
    String? languageCode,
    int? screenBrightnessPercent,
    bool? screenBrightnessAvailable,
    int? screenBrightnessActualPercent,
    String? priorityMetric,
    bool? aqiIndicatorEnabled,
    bool? aqiIndicatorAvailable,
    bool? aqiIndicatorActualEnabled,
    int? aqiIndicatorActualLevel,
    bool? presenceRadarEnabled,
    int? presenceRadarDistanceMeters,
    bool? buzzerFeedbackEnabled,
    String? buzzerVolume,
    String? indicatorLightBrightness,
    int? screenOffSeconds,
    bool? airQualityAutoDetectionEnabled,
    bool? wifiEnabled,
    String? wifiSsid,
    bool clearWifiSsid = false,
    List<SavedWifiNetwork>? savedWifiNetworks,
    bool? timerEnabled,
    int? timerStartMinutes,
    int? timerEndMinutes,
    List<int>? timerRepeatDays,
    List<ManualAirConditionerSetting>? manualAirConditioners,
    List<ManualFloorHeatSetting>? manualFloorHeatSettings,
    String? manualFreshAirMode,
    String? manualFreshAirFanLevel,
    bool? manualFreshAirTimerEnabled,
    int? manualFreshAirTimerStartMinutes,
    int? manualFreshAirTimerEndMinutes,
    String? manualFreshAirTimerRepeat,
    int? manualHumidifierSetpointPercent,
    bool? manualHumidifierTimerEnabled,
    int? manualHumidifierTimerStartMinutes,
    int? manualHumidifierTimerEndMinutes,
    String? manualHumidifierTimerRepeat,
    String? manualPureDuration,
    Map<String, SmartModeSetting>? smartModes,
    int? filter1RemainingDays,
    int? filter2RemainingDays,
    int? filter3RemainingDays,
    bool? airConditionerEnabled,
    bool? floorHeatEnabled,
    bool? freshAirEnabled,
    bool? humidifierEnabled,
    bool? pureEnabled,
    bool? allDevicesRunning,
    bool? freshAirRunning,
    bool? humidifierRunning,
    bool? pureRunning,
    String? freshAirModeActual,
    String? freshAirFanLevelActual,
    int? humidifierSetpointActualPercent,
    String? weatherCode,
    String? weatherTemperatureRange,
    bool? wifiConnected,
    String? wifiIpAddress,
    List<String>? availableWifiSsids,
    bool? wifiAvailable,
    bool? wifiActualEnabled,
    String? wifiConnectedSsid,
    bool clearWifiConnectedSsid = false,
    String? wifiOperation,
    String? wifiOperationSsid,
    bool clearWifiOperationSsid = false,
    String? wifiError,
    bool clearWifiError = false,
    List<String>? wifiSecuredSsids,
    List<String>? availableDeviceTypes,
    bool? notificationBellVisible,
    List<DashboardAlertItem>? notifications,
    List<DashboardAlertItem>? faults,
    String? faultServicePhone,
    String? smartAirConditionerMode,
    String? smartAirConditionerFanLevel,
    String? smartFreshAirMode,
    String? smartFreshAirFanLevel,
    String? floorHeatControlMode,
    List<AirConditionerZoneSnapshot>? airConditionerZones,
    List<FloorHeatZoneSnapshot>? floorHeatZones,
    String? backendDataStatus,
    List<double>? dailyTemperatureIndoorC,
    List<double>? dailyTemperatureOutdoorC,
    List<double>? weeklyTemperatureIndoorC,
    List<double>? weeklyTemperatureOutdoorC,
    List<double>? monthlyTemperatureIndoorC,
    List<double>? monthlyTemperatureOutdoorC,
    int? monthlyTrendYear,
    int? monthlyTrendMonth,
    List<double>? dailyHumidityIndoorPercent,
    List<double>? dailyHumidityOutdoorPercent,
    List<double>? weeklyHumidityIndoorPercent,
    List<double>? weeklyHumidityOutdoorPercent,
    List<double>? monthlyHumidityIndoorPercent,
    List<double>? monthlyHumidityOutdoorPercent,
    List<double>? dailyPm25Indoor,
    List<double>? dailyPm25Outdoor,
    List<double>? weeklyPm25Indoor,
    List<double>? weeklyPm25Outdoor,
    List<double>? monthlyPm25Indoor,
    List<double>? monthlyPm25Outdoor,
    List<double>? dailyCo2Ppm,
    List<double>? weeklyCo2Ppm,
    List<double>? monthlyCo2Ppm,
    String? homeError,
    bool clearHomeError = false,
    String? versionUpdateStatus,
    String? latestVersion,
  }) {
    return DashboardData(
      areaName: areaName,
      outdoorTemperatureC: outdoorTemperatureC,
      outdoorHumidityPercent: outdoorHumidityPercent,
      outdoorPm25: outdoorPm25,
      indoorPm25: indoorPm25,
      indoorTemperatureC: indoorTemperatureC,
      indoorHumidityPercent: indoorHumidityPercent,
      indoorCo2Ppm: indoorCo2Ppm,
      indoorFormaldehydeMgM3: indoorFormaldehydeMgM3,
      dailyTemperatureIndoorC:
          dailyTemperatureIndoorC ?? this.dailyTemperatureIndoorC,
      dailyTemperatureOutdoorC:
          dailyTemperatureOutdoorC ?? this.dailyTemperatureOutdoorC,
      weeklyTemperatureIndoorC:
          weeklyTemperatureIndoorC ?? this.weeklyTemperatureIndoorC,
      weeklyTemperatureOutdoorC:
          weeklyTemperatureOutdoorC ?? this.weeklyTemperatureOutdoorC,
      monthlyTemperatureIndoorC:
          monthlyTemperatureIndoorC ?? this.monthlyTemperatureIndoorC,
      monthlyTemperatureOutdoorC:
          monthlyTemperatureOutdoorC ?? this.monthlyTemperatureOutdoorC,
      monthlyTrendYear: monthlyTrendYear ?? this.monthlyTrendYear,
      monthlyTrendMonth: monthlyTrendMonth ?? this.monthlyTrendMonth,
      dailyHumidityIndoorPercent:
          dailyHumidityIndoorPercent ?? this.dailyHumidityIndoorPercent,
      dailyHumidityOutdoorPercent:
          dailyHumidityOutdoorPercent ?? this.dailyHumidityOutdoorPercent,
      weeklyHumidityIndoorPercent:
          weeklyHumidityIndoorPercent ?? this.weeklyHumidityIndoorPercent,
      weeklyHumidityOutdoorPercent:
          weeklyHumidityOutdoorPercent ?? this.weeklyHumidityOutdoorPercent,
      monthlyHumidityIndoorPercent:
          monthlyHumidityIndoorPercent ?? this.monthlyHumidityIndoorPercent,
      monthlyHumidityOutdoorPercent:
          monthlyHumidityOutdoorPercent ?? this.monthlyHumidityOutdoorPercent,
      dailyPm25Indoor: dailyPm25Indoor ?? this.dailyPm25Indoor,
      dailyPm25Outdoor: dailyPm25Outdoor ?? this.dailyPm25Outdoor,
      weeklyPm25Indoor: weeklyPm25Indoor ?? this.weeklyPm25Indoor,
      weeklyPm25Outdoor: weeklyPm25Outdoor ?? this.weeklyPm25Outdoor,
      monthlyPm25Indoor: monthlyPm25Indoor ?? this.monthlyPm25Indoor,
      monthlyPm25Outdoor: monthlyPm25Outdoor ?? this.monthlyPm25Outdoor,
      dailyCo2Ppm: dailyCo2Ppm ?? this.dailyCo2Ppm,
      weeklyCo2Ppm: weeklyCo2Ppm ?? this.weeklyCo2Ppm,
      monthlyCo2Ppm: monthlyCo2Ppm ?? this.monthlyCo2Ppm,
      runningDeviceCount: runningDeviceCount,
      totalDeviceCount: totalDeviceCount,
      availableDeviceTypes: availableDeviceTypes ?? this.availableDeviceTypes,
      homeFloorLayeringEnabled:
          homeFloorLayeringEnabled ?? this.homeFloorLayeringEnabled,
      allDevicesOn: allDevicesOn ?? this.allDevicesOn,
      leaveHomeModeEnabled:
          leaveHomeModeEnabled ?? this.leaveHomeModeEnabled,
      homeFloorSelection: homeFloorSelection ?? this.homeFloorSelection,
      timeFormat: timeFormat ?? this.timeFormat,
      dateYear: dateYear ?? this.dateYear,
      dateMonth: dateMonth ?? this.dateMonth,
      dateDay: dateDay ?? this.dateDay,
      clockHour: clockHour ?? this.clockHour,
      clockMinute: clockMinute ?? this.clockMinute,
      clockSecond: clockSecond ?? this.clockSecond,
      languageCode: languageCode ?? this.languageCode,
      screenBrightnessPercent:
          screenBrightnessPercent ?? this.screenBrightnessPercent,
      screenBrightnessAvailable:
          screenBrightnessAvailable ?? this.screenBrightnessAvailable,
      screenBrightnessActualPercent:
          screenBrightnessActualPercent ?? this.screenBrightnessActualPercent,
      priorityMetric: priorityMetric ?? this.priorityMetric,
      aqiIndicatorEnabled: aqiIndicatorEnabled ?? this.aqiIndicatorEnabled,
      aqiIndicatorAvailable:
          aqiIndicatorAvailable ?? this.aqiIndicatorAvailable,
      aqiIndicatorActualEnabled:
          aqiIndicatorActualEnabled ?? this.aqiIndicatorActualEnabled,
      aqiIndicatorActualLevel:
          aqiIndicatorActualLevel ?? this.aqiIndicatorActualLevel,
      presenceRadarEnabled: presenceRadarEnabled ?? this.presenceRadarEnabled,
      presenceRadarDistanceMeters:
          presenceRadarDistanceMeters ?? this.presenceRadarDistanceMeters,
      buzzerFeedbackEnabled:
          buzzerFeedbackEnabled ?? this.buzzerFeedbackEnabled,
      buzzerVolume: buzzerVolume ?? this.buzzerVolume,
      indicatorLightBrightness:
          indicatorLightBrightness ?? this.indicatorLightBrightness,
      screenOffSeconds: screenOffSeconds ?? this.screenOffSeconds,
      airQualityAutoDetectionEnabled:
          airQualityAutoDetectionEnabled ?? this.airQualityAutoDetectionEnabled,
      wifiEnabled: wifiEnabled ?? this.wifiEnabled,
      wifiSsid: clearWifiSsid ? '' : (wifiSsid ?? this.wifiSsid),
      savedWifiNetworks: savedWifiNetworks ?? this.savedWifiNetworks,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerStartMinutes: timerStartMinutes ?? this.timerStartMinutes,
      timerEndMinutes: timerEndMinutes ?? this.timerEndMinutes,
      timerRepeatDays: timerRepeatDays ?? this.timerRepeatDays,
      manualAirConditioners:
          manualAirConditioners ?? this.manualAirConditioners,
      manualFloorHeatSettings:
          manualFloorHeatSettings ?? this.manualFloorHeatSettings,
      manualFreshAirMode: manualFreshAirMode ?? this.manualFreshAirMode,
      manualFreshAirFanLevel:
          manualFreshAirFanLevel ?? this.manualFreshAirFanLevel,
      manualFreshAirTimerEnabled:
          manualFreshAirTimerEnabled ?? this.manualFreshAirTimerEnabled,
      manualFreshAirTimerStartMinutes: manualFreshAirTimerStartMinutes ??
          this.manualFreshAirTimerStartMinutes,
      manualFreshAirTimerEndMinutes:
          manualFreshAirTimerEndMinutes ?? this.manualFreshAirTimerEndMinutes,
      manualFreshAirTimerRepeat:
          manualFreshAirTimerRepeat ?? this.manualFreshAirTimerRepeat,
      manualHumidifierSetpointPercent: manualHumidifierSetpointPercent ??
          this.manualHumidifierSetpointPercent,
      manualHumidifierTimerEnabled:
          manualHumidifierTimerEnabled ?? this.manualHumidifierTimerEnabled,
      manualHumidifierTimerStartMinutes: manualHumidifierTimerStartMinutes ??
          this.manualHumidifierTimerStartMinutes,
      manualHumidifierTimerEndMinutes: manualHumidifierTimerEndMinutes ??
          this.manualHumidifierTimerEndMinutes,
      manualHumidifierTimerRepeat:
          manualHumidifierTimerRepeat ?? this.manualHumidifierTimerRepeat,
      manualPureDuration: manualPureDuration ?? this.manualPureDuration,
      smartModes: smartModes ?? this.smartModes,
      filter1RemainingDays: filter1RemainingDays ?? this.filter1RemainingDays,
      filter2RemainingDays: filter2RemainingDays ?? this.filter2RemainingDays,
      filter3RemainingDays: filter3RemainingDays ?? this.filter3RemainingDays,
      airConditionerEnabled:
          airConditionerEnabled ?? this.airConditionerEnabled,
      floorHeatEnabled: floorHeatEnabled ?? this.floorHeatEnabled,
      freshAirEnabled: freshAirEnabled ?? this.freshAirEnabled,
      humidifierEnabled: humidifierEnabled ?? this.humidifierEnabled,
      pureEnabled: pureEnabled ?? this.pureEnabled,
      allDevicesRunning: allDevicesRunning ?? this.allDevicesRunning,
      freshAirRunning: freshAirRunning ?? this.freshAirRunning,
      humidifierRunning: humidifierRunning ?? this.humidifierRunning,
      pureRunning: pureRunning ?? this.pureRunning,
      freshAirModeActual: freshAirModeActual ?? this.freshAirModeActual,
      freshAirFanLevelActual:
          freshAirFanLevelActual ?? this.freshAirFanLevelActual,
      humidifierSetpointActualPercent: humidifierSetpointActualPercent ??
          this.humidifierSetpointActualPercent,
      weatherCode: weatherCode ?? this.weatherCode,
      weatherTemperatureRange:
          weatherTemperatureRange ?? this.weatherTemperatureRange,
      wifiConnected: wifiConnected ?? this.wifiConnected,
      wifiIpAddress: wifiIpAddress ?? this.wifiIpAddress,
      availableWifiSsids: availableWifiSsids ?? this.availableWifiSsids,
      wifiAvailable: wifiAvailable ?? this.wifiAvailable,
      wifiActualEnabled: wifiActualEnabled ?? this.wifiActualEnabled,
      wifiConnectedSsid: clearWifiConnectedSsid
          ? ''
          : (wifiConnectedSsid ?? this.wifiConnectedSsid),
      wifiOperation: wifiOperation ?? this.wifiOperation,
      wifiOperationSsid: clearWifiOperationSsid
          ? ''
          : (wifiOperationSsid ?? this.wifiOperationSsid),
      wifiError: clearWifiError ? '' : (wifiError ?? this.wifiError),
      wifiSecuredSsids: wifiSecuredSsids ?? this.wifiSecuredSsids,
      notificationBellVisible:
          notificationBellVisible ?? this.notificationBellVisible,
      notifications: notifications ?? this.notifications,
      faults: faults ?? this.faults,
      faultServicePhone: faultServicePhone ?? this.faultServicePhone,
      smartAirConditionerMode:
          smartAirConditionerMode ?? this.smartAirConditionerMode,
      smartAirConditionerFanLevel:
          smartAirConditionerFanLevel ?? this.smartAirConditionerFanLevel,
      smartFreshAirMode: smartFreshAirMode ?? this.smartFreshAirMode,
      smartFreshAirFanLevel:
          smartFreshAirFanLevel ?? this.smartFreshAirFanLevel,
      floorHeatControlMode: floorHeatControlMode ?? this.floorHeatControlMode,
      airConditionerZones: airConditionerZones ?? this.airConditionerZones,
      floorHeatZones: floorHeatZones ?? this.floorHeatZones,
      backendDataStatus: backendDataStatus ?? this.backendDataStatus,
      homeError: clearHomeError ? null : (homeError ?? this.homeError),
      versionUpdateStatus: versionUpdateStatus ?? this.versionUpdateStatus,
      latestVersion: latestVersion ?? this.latestVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'areaName': areaName,
      'outdoorTemperatureC': outdoorTemperatureC,
      'outdoorHumidityPercent': outdoorHumidityPercent,
      'outdoorPm25': outdoorPm25,
      'indoorPm25': indoorPm25,
      'indoorTemperatureC': indoorTemperatureC,
      'indoorHumidityPercent': indoorHumidityPercent,
      'indoorCo2Ppm': indoorCo2Ppm,
      'indoorFormaldehydeMgM3': indoorFormaldehydeMgM3,
      'runningDeviceCount': runningDeviceCount,
      'totalDeviceCount': totalDeviceCount,
      'availableDeviceTypes': availableDeviceTypes,
      'homeFloorLayeringEnabled': homeFloorLayeringEnabled,
      'allDevicesOn': allDevicesOn,
      'leaveHomeModeEnabled': leaveHomeModeEnabled,
      'homeFloorSelection': homeFloorSelection,
      'timeFormat': timeFormat,
      'dateYear': dateYear,
      'dateMonth': dateMonth,
      'dateDay': dateDay,
      'clockHour': clockHour,
      'clockMinute': clockMinute,
      'clockSecond': clockSecond,
      'languageCode': languageCode,
      'screenBrightnessPercent': screenBrightnessPercent,
      'screenBrightnessAvailable': screenBrightnessAvailable,
      'screenBrightnessActualPercent': screenBrightnessActualPercent,
      'priorityMetric': priorityMetric,
      'aqiIndicatorEnabled': aqiIndicatorEnabled,
      'aqiIndicatorAvailable': aqiIndicatorAvailable,
      'aqiIndicatorActualEnabled': aqiIndicatorActualEnabled,
      'aqiIndicatorActualLevel': aqiIndicatorActualLevel,
      'presenceRadarEnabled': presenceRadarEnabled,
      'presenceRadarDistanceMeters': presenceRadarDistanceMeters,
      'buzzerFeedbackEnabled': buzzerFeedbackEnabled,
      'buzzerVolume': buzzerVolume,
      'indicatorLightBrightness': indicatorLightBrightness,
      'screenOffSeconds': screenOffSeconds,
      'airQualityAutoDetectionEnabled': airQualityAutoDetectionEnabled,
      'wifiEnabled': wifiEnabled,
      'wifiSsid': wifiSsid,
      'savedWifiNetworks': savedWifiNetworks
          .map((network) => network.toJson())
          .toList(growable: false),
      'timerEnabled': timerEnabled,
      'timerStartMinutes': timerStartMinutes,
      'timerEndMinutes': timerEndMinutes,
      'timerRepeatDays': timerRepeatDays,
      'manualAirConditioners': manualAirConditioners
          .map((setting) => setting.toJson())
          .toList(growable: false),
      'manualFloorHeatSettings': manualFloorHeatSettings
          .map((setting) => setting.toJson())
          .toList(growable: false),
      'manualFreshAirMode': manualFreshAirMode,
      'manualFreshAirFanLevel': manualFreshAirFanLevel,
      'manualFreshAirTimerEnabled': manualFreshAirTimerEnabled,
      'manualFreshAirTimerStartMinutes': manualFreshAirTimerStartMinutes,
      'manualFreshAirTimerEndMinutes': manualFreshAirTimerEndMinutes,
      'manualFreshAirTimerRepeat': manualFreshAirTimerRepeat,
      'manualHumidifierSetpointPercent': manualHumidifierSetpointPercent,
      'manualHumidifierTimerEnabled': manualHumidifierTimerEnabled,
      'manualHumidifierTimerStartMinutes': manualHumidifierTimerStartMinutes,
      'manualHumidifierTimerEndMinutes': manualHumidifierTimerEndMinutes,
      'manualHumidifierTimerRepeat': manualHumidifierTimerRepeat,
      'manualPureDuration': manualPureDuration,
      'smartModes': smartModes.map(
        (mode, setting) => MapEntry<String, dynamic>(mode, setting.toJson()),
      ),
      'filter1RemainingDays': filter1RemainingDays,
      'filter2RemainingDays': filter2RemainingDays,
      'filter3RemainingDays': filter3RemainingDays,
      'airConditionerEnabled': airConditionerEnabled,
      'floorHeatEnabled': floorHeatEnabled,
      'freshAirEnabled': freshAirEnabled,
      'humidifierEnabled': humidifierEnabled,
      'pureEnabled': pureEnabled,
      'allDevicesRunning': allDevicesRunning,
      'freshAirRunning': freshAirRunning,
      'humidifierRunning': humidifierRunning,
      'pureRunning': pureRunning,
      'freshAirModeActual': freshAirModeActual,
      'freshAirFanLevelActual': freshAirFanLevelActual,
      'humidifierSetpointActualPercent': humidifierSetpointActualPercent,
      'weatherCode': weatherCode,
      'weatherTemperatureRange': weatherTemperatureRange,
      'wifiConnected': wifiConnected,
      'wifiIpAddress': wifiIpAddress,
      'availableWifiSsids': availableWifiSsids,
      'wifiAvailable': wifiAvailable,
      'wifiActualEnabled': wifiActualEnabled,
      'wifiConnectedSsid': wifiConnectedSsid,
      'wifiOperation': wifiOperation,
      'wifiOperationSsid': wifiOperationSsid,
      'wifiError': wifiError,
      'wifiSecuredSsids': wifiSecuredSsids,
      'notificationBellVisible': notificationBellVisible,
      'notifications': notifications
          .map((notification) => notification.toJson())
          .toList(growable: false),
      'faults': faults.map((fault) => fault.toJson()).toList(growable: false),
      'faultServicePhone': faultServicePhone,
      'smartAirConditionerMode': smartAirConditionerMode,
      'smartAirConditionerFanLevel': smartAirConditionerFanLevel,
      'smartFreshAirMode': smartFreshAirMode,
      'smartFreshAirFanLevel': smartFreshAirFanLevel,
      'floorHeatControlMode': floorHeatControlMode,
      'airConditionerZones': airConditionerZones
          .map((zone) => zone.toJson())
          .toList(growable: false),
      'floorHeatZones':
          floorHeatZones.map((zone) => zone.toJson()).toList(growable: false),
      'backendDataStatus': backendDataStatus,
      if (homeError != null) 'homeError': homeError,
      'versionUpdateStatus': versionUpdateStatus,
      'latestVersion': latestVersion,
      'dailyTemperatureIndoorC': dailyTemperatureIndoorC,
      'dailyTemperatureOutdoorC': dailyTemperatureOutdoorC,
      'weeklyTemperatureIndoorC': weeklyTemperatureIndoorC,
      'weeklyTemperatureOutdoorC': weeklyTemperatureOutdoorC,
      'monthlyTemperatureIndoorC': monthlyTemperatureIndoorC,
      'monthlyTemperatureOutdoorC': monthlyTemperatureOutdoorC,
      'monthlyTrendYear': monthlyTrendYear,
      'monthlyTrendMonth': monthlyTrendMonth,
      'dailyHumidityIndoorPercent': dailyHumidityIndoorPercent,
      'dailyHumidityOutdoorPercent': dailyHumidityOutdoorPercent,
      'weeklyHumidityIndoorPercent': weeklyHumidityIndoorPercent,
      'weeklyHumidityOutdoorPercent': weeklyHumidityOutdoorPercent,
      'monthlyHumidityIndoorPercent': monthlyHumidityIndoorPercent,
      'monthlyHumidityOutdoorPercent': monthlyHumidityOutdoorPercent,
      'dailyPm25Indoor': dailyPm25Indoor,
      'dailyPm25Outdoor': dailyPm25Outdoor,
      'weeklyPm25Indoor': weeklyPm25Indoor,
      'weeklyPm25Outdoor': weeklyPm25Outdoor,
      'monthlyPm25Indoor': monthlyPm25Indoor,
      'monthlyPm25Outdoor': monthlyPm25Outdoor,
      'dailyCo2Ppm': dailyCo2Ppm,
      'weeklyCo2Ppm': weeklyCo2Ppm,
      'monthlyCo2Ppm': monthlyCo2Ppm,
    };
  }

  /// 应用拥有的设置目标。设备实际样式仍由 runtime 的 xxxRunning 驱动。
  Map<String, dynamic> toSettingsJson() {
    return <String, dynamic>{
      'allDevicesOn': allDevicesOn,
      'leaveHomeModeEnabled': leaveHomeModeEnabled,
      'homeFloorSelection': homeFloorSelection,
      'airConditionerEnabled': airConditionerEnabled,
      'floorHeatEnabled': floorHeatEnabled,
      'freshAirEnabled': freshAirEnabled,
      'humidifierEnabled': humidifierEnabled,
      'pureSettings': <String, dynamic>{
        'enabled': pureEnabled,
        'duration': manualPureDuration,
      },
      'timeFormat': timeFormat,
      'dateYear': dateYear,
      'dateMonth': dateMonth,
      'dateDay': dateDay,
      'clockHour': clockHour,
      'clockMinute': clockMinute,
      'clockSecond': clockSecond,
      'languageCode': languageCode,
      'screenBrightnessPercent': screenBrightnessPercent,
      'priorityMetric': priorityMetric,
      'aqiIndicatorEnabled': aqiIndicatorEnabled,
      'presenceRadarEnabled': presenceRadarEnabled,
      'presenceRadarDistanceMeters': presenceRadarDistanceMeters,
      'buzzerFeedbackEnabled': buzzerFeedbackEnabled,
      'buzzerVolume': buzzerVolume,
      'indicatorLightBrightness': indicatorLightBrightness,
      'screenOffSeconds': screenOffSeconds,
      'airQualityAutoDetectionEnabled': airQualityAutoDetectionEnabled,
      'wifiEnabled': wifiEnabled,
      'wifiSsid': wifiSsid,
      'savedWifiNetworks': savedWifiNetworks
          .map((network) => network.toJson())
          .toList(growable: false),
      'timerEnabled': timerEnabled,
      'timerStartMinutes': timerStartMinutes,
      'timerEndMinutes': timerEndMinutes,
      'timerRepeatDays': timerRepeatDays,
      'manualAirConditioners': manualAirConditioners
          .map((setting) => setting.toJson())
          .toList(growable: false),
      'manualFloorHeatSettings': manualFloorHeatSettings
          .map((setting) => setting.toJson())
          .toList(growable: false),
      'manualFreshAirMode': manualFreshAirMode,
      'manualFreshAirFanLevel': manualFreshAirFanLevel,
      'manualFreshAirTimerEnabled': manualFreshAirTimerEnabled,
      'manualFreshAirTimerStartMinutes': manualFreshAirTimerStartMinutes,
      'manualFreshAirTimerEndMinutes': manualFreshAirTimerEndMinutes,
      'manualFreshAirTimerRepeat': manualFreshAirTimerRepeat,
      'manualHumidifierSetpointPercent': manualHumidifierSetpointPercent,
      'manualHumidifierTimerEnabled': manualHumidifierTimerEnabled,
      'manualHumidifierTimerStartMinutes': manualHumidifierTimerStartMinutes,
      'manualHumidifierTimerEndMinutes': manualHumidifierTimerEndMinutes,
      'manualHumidifierTimerRepeat': manualHumidifierTimerRepeat,
      'smartModes': smartModes.map(
        (mode, setting) => MapEntry<String, dynamic>(mode, setting.toJson()),
      ),
      'filter1RemainingDays': filter1RemainingDays,
      'filter2RemainingDays': filter2RemainingDays,
      'filter3RemainingDays': filter3RemainingDays,
    };
  }

  /// 两秒刷新链路拥有的运行快照；控制动作不直接改写，由轮询统一发布。
  Map<String, dynamic> toRuntimeJson() {
    return <String, dynamic>{
      'areaName': areaName,
      'homeFloorLayeringEnabled': homeFloorLayeringEnabled,
      'outdoorTemperatureC': outdoorTemperatureC,
      'outdoorHumidityPercent': outdoorHumidityPercent,
      'outdoorPm25': outdoorPm25,
      'indoorPm25': indoorPm25,
      'indoorTemperatureC': indoorTemperatureC,
      'indoorHumidityPercent': indoorHumidityPercent,
      'indoorCo2Ppm': indoorCo2Ppm,
      'indoorFormaldehydeMgM3': indoorFormaldehydeMgM3,
      'runningDeviceCount': runningDeviceCount,
      'totalDeviceCount': totalDeviceCount,
      'availableDeviceTypes': availableDeviceTypes,
      'weatherCode': weatherCode,
      'weatherTemperatureRange': weatherTemperatureRange,
      'wifiConnected': wifiConnected,
      'wifiIpAddress': wifiIpAddress,
      'availableWifiSsids': availableWifiSsids,
      'wifiAvailable': wifiAvailable,
      'wifiActualEnabled': wifiActualEnabled,
      'wifiConnectedSsid': wifiConnectedSsid,
      'wifiOperation': wifiOperation,
      'wifiOperationSsid': wifiOperationSsid,
      'wifiError': wifiError,
      'wifiSecuredSsids': wifiSecuredSsids,
      'notificationBellVisible': notificationBellVisible,
      'notifications': notifications
          .map((notification) => notification.toJson())
          .toList(growable: false),
      'faults': faults.map((fault) => fault.toJson()).toList(growable: false),
      'faultServicePhone': faultServicePhone,
      'smartAirConditionerMode': smartAirConditionerMode,
      'smartAirConditionerFanLevel': smartAirConditionerFanLevel,
      'smartFreshAirMode': smartFreshAirMode,
      'smartFreshAirFanLevel': smartFreshAirFanLevel,
      'floorHeatControlMode': floorHeatControlMode,
      'airConditionerZones': airConditionerZones
          .map((zone) => zone.toJson())
          .toList(growable: false),
      'floorHeatZones':
          floorHeatZones.map((zone) => zone.toJson()).toList(growable: false),
      'backendDataStatus': backendDataStatus,
      'screenBrightnessAvailable': screenBrightnessAvailable,
      'screenBrightnessActualPercent': screenBrightnessActualPercent,
      'aqiIndicatorAvailable': aqiIndicatorAvailable,
      'aqiIndicatorActualEnabled': aqiIndicatorActualEnabled,
      'aqiIndicatorActualLevel': aqiIndicatorActualLevel,
      if (homeError != null) 'homeError': homeError,
      'versionUpdateStatus': versionUpdateStatus,
      'latestVersion': latestVersion,
      // 月趋势的年月是本组数据的读取条件，放在趋势数组前便于人工联调。
      'monthlyTrendYear': monthlyTrendYear,
      'monthlyTrendMonth': monthlyTrendMonth,
      // 趋势数据放在文件末尾，便于人工联调时集中修改。
      'dailyTemperatureIndoorC': dailyTemperatureIndoorC,
      'dailyTemperatureOutdoorC': dailyTemperatureOutdoorC,
      'weeklyTemperatureIndoorC': weeklyTemperatureIndoorC,
      'weeklyTemperatureOutdoorC': weeklyTemperatureOutdoorC,
      'monthlyTemperatureIndoorC': monthlyTemperatureIndoorC,
      'monthlyTemperatureOutdoorC': monthlyTemperatureOutdoorC,
      'dailyHumidityIndoorPercent': dailyHumidityIndoorPercent,
      'dailyHumidityOutdoorPercent': dailyHumidityOutdoorPercent,
      'weeklyHumidityIndoorPercent': weeklyHumidityIndoorPercent,
      'weeklyHumidityOutdoorPercent': weeklyHumidityOutdoorPercent,
      'monthlyHumidityIndoorPercent': monthlyHumidityIndoorPercent,
      'monthlyHumidityOutdoorPercent': monthlyHumidityOutdoorPercent,
      'dailyPm25Indoor': dailyPm25Indoor,
      'dailyPm25Outdoor': dailyPm25Outdoor,
      'weeklyPm25Indoor': weeklyPm25Indoor,
      'weeklyPm25Outdoor': weeklyPm25Outdoor,
      'monthlyPm25Indoor': monthlyPm25Indoor,
      'monthlyPm25Outdoor': monthlyPm25Outdoor,
      'dailyCo2Ppm': dailyCo2Ppm,
      'weeklyCo2Ppm': weeklyCo2Ppm,
      'monthlyCo2Ppm': monthlyCo2Ppm,
      // 设备设置与实际运行态分开；控制写成功也不提前修改实际状态。
      'allDevicesRunning': allDevicesRunning,
      'freshAirRunning': freshAirRunning,
      'humidifierRunning': humidifierRunning,
      'pureRunning': pureRunning,
      'freshAirModeActual': freshAirModeActual,
      'freshAirFanLevelActual': freshAirFanLevelActual,
      'humidifierSetpointActualPercent': humidifierSetpointActualPercent,
    };
  }

  static int _readInt(
    Map<String, dynamic> json,
    String key,
    int fallback,
  ) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(
    Map<String, dynamic> json,
    String key,
    double fallback,
  ) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<double> _readDoubleList(
    Map<String, dynamic> json,
    String key,
    List<double> fallback,
  ) {
    final value = json[key];
    if (value is! List || value.any((entry) => entry is! num)) {
      return fallback;
    }
    return value.cast<num>().map((entry) => entry.toDouble()).toList();
  }

  static List<int> _readIntList(
    Map<String, dynamic> json,
    String key,
    List<int> fallback,
  ) {
    final value = json[key];
    if (value is! List || value.any((entry) => entry is! int)) {
      return fallback;
    }
    return value.cast<int>().toList();
  }

  static List<String> _readStringList(
    Map<String, dynamic> json,
    String key,
    List<String> fallback,
  ) {
    final value = json[key];
    if (value is! List ||
        value.any((entry) => entry is! String || entry.trim().isEmpty)) {
      return fallback;
    }
    return value.cast<String>().toList();
  }

  static List<SavedWifiNetwork> _readSavedWifiNetworks(
    Map<String, dynamic> json,
    List<SavedWifiNetwork> fallback,
  ) {
    final value = json['savedWifiNetworks'];
    if (value is! List) {
      return fallback;
    }
    final result = <SavedWifiNetwork>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['ssid'] is! String ||
          entry['password'] is! String) {
        return fallback;
      }
      result.add(
        SavedWifiNetwork(
          ssid: entry['ssid'] as String,
          password: entry['password'] as String,
        ),
      );
    }
    return result;
  }

  static List<ManualAirConditionerSetting> _readManualAirConditioners(
    Map<String, dynamic> json,
    List<ManualAirConditionerSetting> fallback,
  ) {
    final value = json['manualAirConditioners'];
    if (value is! List) {
      return fallback;
    }
    final result = <ManualAirConditionerSetting>[];
    for (final entry in value) {
      if (entry is! Map) {
        return fallback;
      }
      final deviceId = entry['deviceId'];
      final roomName = entry['roomName'];
      final enabled = entry['enabled'];
      final targetTemperatureC = entry['targetTemperatureC'];
      final mode = entry['mode'];
      final fanLevel = entry['fanLevel'];
      final timerEnabled = entry['timerEnabled'];
      final timerStartMinutes = entry['timerStartMinutes'];
      final timerEndMinutes = entry['timerEndMinutes'];
      final timerRepeat = entry['timerRepeat'];
      if (deviceId is! String ||
          roomName is! String ||
          enabled is! bool ||
          targetTemperatureC is! int ||
          mode is! String ||
          fanLevel is! String ||
          timerEnabled is! bool ||
          timerStartMinutes is! int ||
          timerEndMinutes is! int ||
          timerRepeat is! String) {
        return fallback;
      }
      result.add(
        ManualAirConditionerSetting(
          deviceId: deviceId,
          roomName: roomName,
          enabled: enabled,
          targetTemperatureC: targetTemperatureC,
          mode: mode,
          fanLevel: fanLevel,
          timerEnabled: timerEnabled,
          timerStartMinutes: timerStartMinutes,
          timerEndMinutes: timerEndMinutes,
          timerRepeat: timerRepeat,
        ),
      );
    }
    return result;
  }

  static List<ManualFloorHeatSetting> _readManualFloorHeatSettings(
    Map<String, dynamic> json,
    List<ManualFloorHeatSetting> fallback,
  ) {
    final value = json['manualFloorHeatSettings'];
    if (value is! List) {
      return fallback;
    }
    final result = <ManualFloorHeatSetting>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['deviceId'] is! String ||
          entry['enabled'] is! bool ||
          entry['targetTemperatureC'] is! int ||
          entry['timerEnabled'] is! bool ||
          entry['timerStartMinutes'] is! int ||
          entry['timerEndMinutes'] is! int ||
          entry['timerRepeat'] is! String) {
        return fallback;
      }
      result.add(
        ManualFloorHeatSetting(
          deviceId: entry['deviceId'] as String,
          enabled: entry['enabled'] as bool,
          targetTemperatureC: entry['targetTemperatureC'] as int,
          timerEnabled: entry['timerEnabled'] as bool,
          timerStartMinutes: entry['timerStartMinutes'] as int,
          timerEndMinutes: entry['timerEndMinutes'] as int,
          timerRepeat: entry['timerRepeat'] as String,
        ),
      );
    }
    return result;
  }

  static List<FloorHeatZoneSnapshot> _readFloorHeatZones(
    Map<String, dynamic> json,
    List<FloorHeatZoneSnapshot> fallback,
  ) {
    final value = json['floorHeatZones'];
    if (value is! List) {
      return fallback;
    }
    final result = <FloorHeatZoneSnapshot>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['deviceId'] is! String ||
          entry['roomName'] is! String ||
          entry['online'] is! bool) {
        return fallback;
      }
      result.add(
        FloorHeatZoneSnapshot(
          deviceId: entry['deviceId'] as String,
          roomName: entry['roomName'] as String,
          online: entry['online'] as bool,
        ),
      );
    }
    return result;
  }

  static List<AirConditionerZoneSnapshot> _readAirConditionerZones(
    Map<String, dynamic> json,
    List<AirConditionerZoneSnapshot> fallback,
  ) {
    final value = json['airConditionerZones'];
    if (value is! List) {
      return fallback;
    }
    final result = <AirConditionerZoneSnapshot>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['deviceId'] is! String ||
          entry['roomName'] is! String ||
          entry['online'] is! bool) {
        return fallback;
      }
      result.add(
        AirConditionerZoneSnapshot(
          deviceId: entry['deviceId'] as String,
          roomName: entry['roomName'] as String,
          online: entry['online'] as bool,
        ),
      );
    }
    return result;
  }

  static List<DashboardAlertItem> _readAlertItems(
    Map<String, dynamic> json,
    String key,
    List<DashboardAlertItem> fallback,
  ) {
    final value = json[key];
    if (value is! List) {
      return fallback;
    }
    final result = <DashboardAlertItem>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['id'] is! String ||
          entry['title'] is! String ||
          entry['description'] is! String ||
          entry['date'] is! String) {
        return fallback;
      }
      result.add(
        DashboardAlertItem(
          id: entry['id'] as String,
          title: entry['title'] as String,
          description: entry['description'] as String,
          date: entry['date'] as String,
        ),
      );
    }
    return result;
  }

  static Map<String, SmartModeSetting> _readSmartModes(
    Map<String, dynamic> json,
    Map<String, SmartModeSetting> fallback,
  ) {
    final value = json['smartModes'];
    if (value is! Map ||
        value.keys.toSet().length != supportedSmartModes.length ||
        !value.keys.toSet().containsAll(supportedSmartModes)) {
      return fallback;
    }
    final result = <String, SmartModeSetting>{};
    var enabledCount = 0;
    const requiredKeys = <String>{
      'enabled',
      'temperatureSetpointC',
      'humiditySetpointPercent',
    };
    for (final mode in supportedSmartModes) {
      final entry = value[mode];
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys) ||
          entry['enabled'] is! bool ||
          entry['temperatureSetpointC'] is! int ||
          entry['humiditySetpointPercent'] is! int) {
        return fallback;
      }
      final enabled = entry['enabled'] as bool;
      final temperature = entry['temperatureSetpointC'] as int;
      final humidity = entry['humiditySetpointPercent'] as int;
      if (temperature < 16 ||
          temperature > 30 ||
          humidity < 30 ||
          humidity > 70 ||
          (enabled && ++enabledCount > 1)) {
        return fallback;
      }
      result[mode] = SmartModeSetting(
        enabled: enabled,
        temperatureSetpointC: temperature,
        humiditySetpointPercent: humidity,
      );
    }
    return Map<String, SmartModeSetting>.unmodifiable(result);
  }

  static String _readString(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  static String _readStringAllowEmpty(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    return value is String ? value : fallback;
  }

  static bool _readBool(
    Map<String, dynamic> json,
    String key,
    bool fallback,
  ) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  static Map<String, dynamic>? _readObject(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static bool _readWifiConnected(
    Map<String, dynamic> json,
    bool fallback,
  ) {
    if (json.containsKey('wifiConnected')) {
      return _readBool(json, 'wifiConnected', fallback);
    }
    // 兼容上一版 runtime：connected/error 字符串迁移为布尔值。
    return json['wifiState'] == 'error' ? false : fallback;
  }

  static String? _readNullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }
}
