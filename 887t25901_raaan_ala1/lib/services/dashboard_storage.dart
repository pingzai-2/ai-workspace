import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/dashboard_data.dart';
import '../models/dashboard_persistent_data.dart';
import '../models/weather_presentation.dart';
import 'app_logger.dart';
import 'beiang8panel_api.dart';
import 'dashboard_runtime_sync_service.dart';

enum DashboardControlResult {
  success,
  rejected,
  unreachable,
}

abstract class DashboardDataRepository {
  /// 应用启动时读取两份文件，创建默认文件并校验当前 Schema。
  Future<DashboardData> loadOrCreate();

  /// 定时刷新先收集外部原始值，再更新并读回运行快照；settings 保持不变。
  Future<DashboardData> refreshRuntime(DashboardData current);

  /// 历史趋势由独立脉搏触发；返回 false 表示已有请求进行中或当前没有后端。
  bool requestHistoryRefresh() => false;

  /// 超净写入样板：成功、后端明确拒绝、后端不可达三类结果必须分开。
  Future<DashboardControlResult> setPurePower(bool enabled);

  /// 默认实现保留旧测试桩和无后端 UI 样板；正式存储会提交后端命令。
  Future<DashboardControlResult> setFreshAirPower(bool enabled) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setHumidifierPower(bool enabled) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setLeaveHome() async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setFreshAirMode(String mode) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setFreshAirFanLevel(String level) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setTargetHumidity(int percent) async =>
      DashboardControlResult.success;

  /// 已确认的板端本机操作集中提交。未变化字段不发请求。
  Future<DashboardControlResult> applyLocalDeviceSettings(
    DashboardData previous,
    DashboardData next,
  ) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> setScreenSleep(bool sleep) async =>
      DashboardControlResult.unreachable;

  Future<DashboardControlResult> setWifiEnabled(bool enabled) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> scanWifi() async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> connectWifi(
    String ssid,
    String password,
  ) async =>
      DashboardControlResult.success;

  Future<DashboardControlResult> disconnectWifi() async =>
      DashboardControlResult.success;

  /// 后端不可达且 settings 已确认保存后，登记一次前端离线反馈。
  void recordFreshAirPowerFeedback(bool enabled) {}

  void recordHumidifierPowerFeedback(bool enabled) {}

  void recordPurePowerFeedback(bool enabled) {}

  /// 只提交应用拥有的 settings 快照，并返回文件读回后的聚合状态。
  ///
  /// UI 必须以返回值更新样式，不能在写入前乐观修改页面状态。
  Future<DashboardData> save(DashboardData data);

  /// 长期配置独立于 settings/runtime；默认实现方便旧测试桩保持只读。
  Future<DashboardPersistentData> loadPersistentOrCreate() async {
    return DashboardPersistentData.defaults();
  }

  /// 只有工程施工确认等明确动作才调用，绝不参与两秒轮询。
  Future<DashboardPersistentData> savePersistent(
    DashboardPersistentData data,
  ) async {
    return data;
  }
}

/// 主页数据的文件边界：
///
/// - dashboard_settings.json：设置目标与用户设置；由应用写入。
/// - dashboard_runtime.json：环境、天气、告警等运行快照；只由轮询链路写入。
/// - dashboard_persistent.json：施工确认后的长期配置；仅显式保存。
/// - JSON 必须可解析且根节点为对象；必需字段缺失、类型或值错误时整份重建。
/// - 合法 JSON 中的多余字段不参与校验，也不会触发重建。
/// - persistent 读取异常时仅在内存使用默认值，绝不在启动/轮询阶段覆盖原文件；
///   只有施工确认等显式保存才允许写入。
class DashboardStorage implements DashboardDataRepository {
  DashboardStorage({
    Future<Directory> Function()? directoryProvider,
    DashboardRuntimeSyncService? runtimeSyncService,
  })  : _directoryProvider = directoryProvider ?? _configuredDirectory,
        _runtimeSyncService = runtimeSyncService;

  static const String _configRoot = String.fromEnvironment(
    'DASHBOARD_CONFIG_ROOT',
  );

  static const String settingsFileName = 'dashboard_settings.json';
  static const String runtimeFileName = 'dashboard_runtime.json';
  static const String persistentFileName = 'dashboard_persistent.json';
  static const Duration _runtimeUpdateLogInterval = Duration(seconds: 30);

  final Future<Directory> Function() _directoryProvider;
  final DashboardRuntimeSyncService? _runtimeSyncService;
  DateTime? _lastRuntimeUpdateLogAt;

  @override
  bool requestHistoryRefresh() =>
      _runtimeSyncService?.requestHistoryRefresh() ?? false;

  static Future<Directory> _configuredDirectory() {
    if (_configRoot.isNotEmpty) {
      return Future<Directory>.value(Directory(_configRoot));
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _localFile(String name) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/$name');
  }

  @override
  Future<DashboardData> loadOrCreate() async {
    final settingsFile = await _localFile(settingsFileName);
    final runtimeFile = await _localFile(runtimeFileName);
    final rawSettings = await _readJsonOrNull(settingsFile);
    final rawRuntime = await _readJsonOrNull(runtimeFile);
    final settings = _currentSettingsOrDefaults(rawSettings);
    final runtime = _currentRuntimeOrDefaults(rawRuntime);

    final merged = <String, dynamic>{
      ...DashboardData.defaults().toJson(),
      ...settings,
      ...runtime,
    };
    final data = DashboardData.fromJson(merged);

    if (!_sameJsonMaps(rawSettings, settings)) {
      await _writeJsonAtomically(settingsFile, settings);
    }
    if (!_sameJsonMaps(rawRuntime, runtime)) {
      await _writeJsonAtomically(runtimeFile, runtime);
    }
    AppLogger.instance.i(
      '主页数据已读取：settings=${settingsFile.path} '
      'runtime=${runtimeFile.path}',
      tag: 'DashboardStorage',
    );
    return data;
  }

  @override
  Future<DashboardData> refreshRuntime(DashboardData current) async {
    final runtimeFile = await _localFile(runtimeFileName);
    var runtimePatch =
        await _runtimeSyncService?.collectRuntimePatch(current) ??
            <String, dynamic>{};
    var rawRuntime = await _readJsonOrNull(runtimeFile);
    var runtime = _currentRuntimeOrDefaults(rawRuntime);

    // 存在性接口是对运行时设备列表的补充；只有明确返回布尔值时才更新
    // availableDeviceTypes。接口不存在或异常时不改 JSON，保留原有本地列表。
    final backendStatus =
        runtimePatch['backendDataStatus'] ?? runtime['backendDataStatus'];
    if (backendStatus != 'unreachable') {
      final presence = await _runtimeSyncService?.readDevicePresence();
      if (presence != null &&
          (presence.airConditioner != null || presence.floorHeating != null)) {
        final source = DashboardData.fromJson(<String, dynamic>{
          ...DashboardData.defaults().toJson(),
          ...runtime,
          ...runtimePatch,
        });
        runtimePatch = <String, dynamic>{
          ...runtimePatch,
          'availableDeviceTypes': _applyDevicePresence(
            source.availableDeviceTypes,
            presence,
          ),
        };
      }
    }

    // 唯一落盘约束：读取任务和设置提交都不得直接写 runtime。
    // 本方法在全部读取结束后统一合并、原子写入并读回校验。
    if (runtimePatch.isNotEmpty) {
      final candidate = <String, dynamic>{...runtime, ...runtimePatch};
      if (!_sameJsonMaps(rawRuntime, candidate)) {
        await _writeJsonAtomically(runtimeFile, candidate);
      }
      rawRuntime = await _readJsonOrNull(runtimeFile);
      runtime = _currentRuntimeOrDefaults(rawRuntime);
    }

    final knownRuntime = DashboardData.fromJson(<String, dynamic>{
      ...DashboardData.defaults().toJson(),
      ...runtime,
    }).toRuntimeJson();
    final runtimeChanged =
        !_sameJsonMaps(current.toRuntimeJson(), knownRuntime);
    final runtimeRebuilt = !_sameJsonMaps(rawRuntime, runtime);
    final data = DashboardData.fromJson(<String, dynamic>{
      ...current.toJson(),
      ...runtime,
    });
    if (runtimeRebuilt) {
      await _writeJsonAtomically(runtimeFile, runtime);
      // 文件异常或必需字段无效时才提示；避免两秒轮询刷屏。
      AppLogger.instance.i(
        '主页运行快照已重建：${runtimeFile.path}',
        tag: 'DashboardStorage',
      );
    } else if (runtimeChanged && _canLogRuntimeUpdate()) {
      // 即使实时数据持续变化，也最多每 30 秒输出一条更新日志。
      AppLogger.instance.i(
        '主页运行快照已更新：${runtimeFile.path}',
        tag: 'DashboardStorage',
      );
    }
    return data;
  }

  @override
  Future<DashboardControlResult> setFreshAirPower(bool enabled) {
    return _submitControl(
      () => _runtimeSyncService?.setFreshAirPower(enabled),
      '新风开关',
    );
  }

  @override
  Future<DashboardControlResult> setHumidifierPower(bool enabled) {
    return _submitControl(
      () => _runtimeSyncService?.setHumidifierPower(enabled),
      '调湿开关',
    );
  }

  @override
  Future<DashboardControlResult> setPurePower(bool enabled) async {
    return _submitControl(
      () => _runtimeSyncService?.setPurePower(enabled),
      '超净开关',
    );
  }

  @override
  Future<DashboardControlResult> setLeaveHome() {
    return _submitControl(
      () => _runtimeSyncService?.setLeaveHome(),
      '一键离家',
    );
  }

  @override
  Future<DashboardControlResult> setFreshAirMode(String mode) {
    return _submitControl(
      () => _runtimeSyncService?.setFreshAirMode(mode),
      '新风模式',
    );
  }

  @override
  Future<DashboardControlResult> setFreshAirFanLevel(String level) {
    return _submitControl(
      () => _runtimeSyncService?.setFreshAirFanLevel(level),
      '新风档位',
    );
  }

  @override
  Future<DashboardControlResult> setTargetHumidity(int percent) {
    return _submitControl(
      () => _runtimeSyncService?.setTargetHumidity(percent),
      '目标湿度',
    );
  }

  Future<DashboardControlResult> _submitControl(
    Future<bool>? Function() submit,
    String name,
  ) async {
    final request = submit();
    if (request == null) return DashboardControlResult.unreachable;
    try {
      return await request
          ? DashboardControlResult.success
          : DashboardControlResult.rejected;
    } on BeiAng8PanelUnavailableException {
      return DashboardControlResult.unreachable;
    } on Object catch (error) {
      AppLogger.instance.e(
        'BeiAng8Panel $name响应无效',
        tag: 'DashboardStorage',
        error: error,
      );
      return DashboardControlResult.rejected;
    }
  }

  @override
  Future<DashboardControlResult> applyLocalDeviceSettings(
    DashboardData previous,
    DashboardData next,
  ) async {
    var result = DashboardControlResult.success;

    Future<void> merge(Future<DashboardControlResult> request) async {
      final current = await request;
      if (current == DashboardControlResult.rejected) {
        result = DashboardControlResult.rejected;
      } else if (current == DashboardControlResult.unreachable &&
          result == DashboardControlResult.success) {
        result = DashboardControlResult.unreachable;
      }
    }

    if (previous.screenBrightnessPercent != next.screenBrightnessPercent) {
      await merge(_submitControl(
        () => _runtimeSyncService
            ?.setScreenBrightnessPercent(next.screenBrightnessPercent),
        '屏幕亮度',
      ));
    }
    if (result != DashboardControlResult.rejected &&
        previous.aqiIndicatorEnabled != next.aqiIndicatorEnabled) {
      await merge(_submitControl(
        () => _runtimeSyncService
            ?.setAqiIndicatorEnabled(next.aqiIndicatorEnabled),
        'AQI指示灯',
      ));
    }
    if (result != DashboardControlResult.rejected &&
        previous.presenceRadarEnabled != next.presenceRadarEnabled) {
      await merge(_submitControl(
        () => _runtimeSyncService?.setRadarEnabled(next.presenceRadarEnabled),
        '人感雷达',
      ));
    }
    return result;
  }

  @override
  Future<DashboardControlResult> setScreenSleep(bool sleep) {
    return _submitControl(
      () => _runtimeSyncService?.setScreenSleep(sleep),
      sleep ? '屏幕息屏' : '屏幕唤醒',
    );
  }

  @override
  Future<DashboardControlResult> setWifiEnabled(bool enabled) {
    return _submitControl(
      () => _runtimeSyncService?.setWifiEnabled(enabled),
      'WiFi开关',
    );
  }

  @override
  Future<DashboardControlResult> scanWifi() {
    return _submitControl(
      () => _runtimeSyncService?.scanWifi(),
      'WiFi扫描',
    );
  }

  @override
  Future<DashboardControlResult> connectWifi(
    String ssid,
    String password,
  ) {
    return _submitControl(
      () => _runtimeSyncService?.connectWifi(ssid, password),
      'WiFi连接',
    );
  }

  @override
  Future<DashboardControlResult> disconnectWifi() {
    return _submitControl(
      () => _runtimeSyncService?.disconnectWifi(),
      'WiFi断开',
    );
  }

  @override
  void recordFreshAirPowerFeedback(bool enabled) {
    _runtimeSyncService?.recordFreshAirPowerFeedback(enabled);
  }

  @override
  void recordHumidifierPowerFeedback(bool enabled) {
    _runtimeSyncService?.recordHumidifierPowerFeedback(enabled);
  }

  @override
  void recordPurePowerFeedback(bool enabled) {
    _runtimeSyncService?.recordPurePowerFeedback(enabled);
  }

  bool _canLogRuntimeUpdate() {
    final now = DateTime.now();
    final last = _lastRuntimeUpdateLogAt;
    if (last != null && now.difference(last) < _runtimeUpdateLogInterval) {
      return false;
    }
    _lastRuntimeUpdateLogAt = now;
    return true;
  }

  @override
  Future<DashboardData> save(DashboardData data) async {
    final settingsFile = await _localFile(settingsFileName);
    final writtenSettings = data.toSettingsJson();
    await _writeJsonAtomically(settingsFile, writtenSettings);
    AppLogger.instance.i(
      '主页控制设置已保存：${settingsFile.path}',
      tag: 'DashboardStorage',
    );
    final readBack = _currentSettingsOrDefaults(
      await _readJsonOrNull(settingsFile),
    );
    if (!_sameJsonMaps(readBack, writtenSettings)) {
      await _writeJsonAtomically(settingsFile, readBack);
    }
    return DashboardData.fromJson(<String, dynamic>{
      ...data.toJson(),
      ...readBack,
    });
  }

  @override
  Future<DashboardPersistentData> loadPersistentOrCreate() async {
    final persistentFile = await _localFile(persistentFileName);
    final rawPersistent = await _readJsonOrNull(persistentFile);
    final persistent = _currentPersistentOrDefaults(rawPersistent);
    if (!_sameJsonMaps(rawPersistent, persistent)) {
      // 长期文件优先保护现场内容：读错时仅让本次内存回退默认，
      // 不在启动时把可能仍有价值的原文件覆盖掉。
      AppLogger.instance.w(
        '长期配置读取异常，本次使用默认值：${persistentFile.path}',
        tag: 'DashboardStorage',
      );
    }
    return DashboardPersistentData.fromJson(persistent);
  }

  @override
  Future<DashboardPersistentData> savePersistent(
    DashboardPersistentData data,
  ) async {
    final persistentFile = await _localFile(persistentFileName);
    final written = data.toJson();
    await _writeJsonAtomically(persistentFile, written);
    final readBack = _currentPersistentOrDefaults(
      await _readJsonOrNull(persistentFile),
    );
    if (!_sameJsonMaps(readBack, written)) {
      await _writeJsonAtomically(persistentFile, readBack);
    }
    AppLogger.instance.i(
      '长期配置已保存：${persistentFile.path}',
      tag: 'DashboardStorage',
    );
    return DashboardPersistentData.fromJson(readBack);
  }

  Map<String, dynamic> _currentPersistentOrDefaults(
    Map<String, dynamic>? document,
  ) {
    final defaults = DashboardPersistentData.defaults().toJson();
    if (document == null) {
      return defaults;
    }
    final normalized = DashboardPersistentData.fromJson(document).toJson();
    return _matchesKnownJsonFields(document, normalized) &&
            _hasValidPersistentValues(document)
        ? document
        : defaults;
  }

  bool _hasValidPersistentValues(Map<String, dynamic> document) {
    return _isPersistentStringMap(document['engineeringDeviceAreas']) &&
        _isPersistentStringMap(document['engineeringDeviceRooms']);
  }

  bool _isPersistentStringMap(Object? value) {
    if (value is! Map || value.length > 100) {
      return false;
    }
    return value.entries.every(
      (entry) =>
          entry.key is String &&
          entry.value is String &&
          (entry.key as String).trim().isNotEmpty &&
          (entry.key as String).length <= 64 &&
          (entry.value as String).trim().isNotEmpty &&
          (entry.value as String).length <= 64,
    );
  }

  Map<String, dynamic> _currentSettingsOrDefaults(
    Map<String, dynamic>? document,
  ) {
    final defaults = DashboardData.defaults().toSettingsJson();
    if (document == null) {
      return defaults;
    }
    // 旧版 settings 没有这些“系统设置-全信息”字段。只对本次新增字段
    // 做默认值补齐，旧有必需字段仍按原校验规则处理，避免升级时整份重置。
    final migrated = <String, dynamic>{...document};
    const addedSystemSettingKeys = <String>{
      'dateYear',
      'dateMonth',
      'dateDay',
      'clockHour',
      'clockMinute',
      'clockSecond',
      'priorityMetric',
      'aqiIndicatorEnabled',
      'presenceRadarEnabled',
      'presenceRadarDistanceMeters',
      'buzzerFeedbackEnabled',
      'buzzerVolume',
      'indicatorLightBrightness',
      'screenOffSeconds',
      'airQualityAutoDetectionEnabled',
    };
    for (final key in addedSystemSettingKeys) {
      migrated.putIfAbsent(key, () => defaults[key]);
    }
    // 主页楼层筛选晚于第一版 settings 加入；旧设备升级时只补默认值，
    // 不因为缺少这一项重置其它已经确认的设置。
    migrated.putIfAbsent(
      'homeFloorSelection',
      () => defaults['homeFloorSelection'],
    );
    final normalized = DashboardData.fromJson(<String, dynamic>{
      ...DashboardData.defaults().toJson(),
      ...migrated,
    }).toSettingsJson();
    return _matchesKnownJsonFields(migrated, normalized) &&
            _hasValidSettingsValues(migrated)
        ? migrated
        : defaults;
  }

  bool _hasValidSettingsValues(Map<String, dynamic> document) {
    final repeatDays = document['timerRepeatDays'];
    final wifiSsid = document['wifiSsid'];
    final savedWifiNetworks = document['savedWifiNetworks'];
    final manualAirConditioners = document['manualAirConditioners'];
    final manualFloorHeatSettings = document['manualFloorHeatSettings'];
    final pureSettings = document['pureSettings'];
    final smartModes = document['smartModes'];
    return DashboardData.supportedHomeFloorSelections
            .contains(document['homeFloorSelection']) &&
        DashboardData.supportedTimeFormats.contains(document['timeFormat']) &&
        _isValidSettingsDate(document) &&
        _isIntInRange(document, 'clockHour', 0, 23) &&
        _isIntInRange(document, 'clockMinute', 0, 59) &&
        _isIntInRange(document, 'clockSecond', 0, 59) &&
        DashboardData.supportedLanguageCodes
            .contains(document['languageCode']) &&
        _isIntInRange(document, 'screenBrightnessPercent', 0, 100) &&
        DashboardData.supportedPriorityMetrics
            .contains(document['priorityMetric']) &&
        document['aqiIndicatorEnabled'] is bool &&
        document['presenceRadarEnabled'] is bool &&
        document['presenceRadarDistanceMeters'] is int &&
        DashboardData.supportedPresenceRadarDistanceMeters
            .contains(document['presenceRadarDistanceMeters']) &&
        document['buzzerFeedbackEnabled'] is bool &&
        DashboardData.supportedBuzzerVolumes
            .contains(document['buzzerVolume']) &&
        document['screenOffSeconds'] is int &&
        DashboardData.supportedScreenOffSeconds
            .contains(document['screenOffSeconds']) &&
        document['airQualityAutoDetectionEnabled'] is bool &&
        document['wifiEnabled'] is bool &&
        wifiSsid is String &&
        wifiSsid.length <= 64 &&
        _isSavedWifiNetworkList(savedWifiNetworks, wifiSsid) &&
        document['timerEnabled'] is bool &&
        _isIntInRange(document, 'timerStartMinutes', 0, 1439) &&
        _isIntInRange(document, 'timerEndMinutes', 0, 1439) &&
        repeatDays is List &&
        repeatDays.isNotEmpty &&
        repeatDays.length <= 7 &&
        repeatDays.every((day) => day is int && day >= 1 && day <= 7) &&
        repeatDays.toSet().length == repeatDays.length &&
        _isSortedIntList(repeatDays) &&
        _isManualAirConditionerList(manualAirConditioners) &&
        _isManualFloorHeatSettingList(manualFloorHeatSettings) &&
        DashboardData.supportedManualFreshAirModes
            .contains(document['manualFreshAirMode']) &&
        DashboardData.supportedManualFreshAirFanLevels
            .contains(document['manualFreshAirFanLevel']) &&
        document['manualFreshAirTimerEnabled'] is bool &&
        _isIntInRange(document, 'manualFreshAirTimerStartMinutes', 0, 1439) &&
        _isIntInRange(document, 'manualFreshAirTimerEndMinutes', 0, 1439) &&
        DashboardData.supportedManualTimerRepeats
            .contains(document['manualFreshAirTimerRepeat']) &&
        _isIntInRange(document, 'manualHumidifierSetpointPercent', 30, 70) &&
        document['manualHumidifierTimerEnabled'] is bool &&
        _isIntInRange(
          document,
          'manualHumidifierTimerStartMinutes',
          0,
          1439,
        ) &&
        _isIntInRange(
          document,
          'manualHumidifierTimerEndMinutes',
          0,
          1439,
        ) &&
        DashboardData.supportedManualTimerRepeats
            .contains(document['manualHumidifierTimerRepeat']) &&
        _isPureSettings(pureSettings) &&
        _isSmartModeMap(smartModes) &&
        _isIntInRange(document, 'filter1RemainingDays', 0, 400) &&
        _isIntInRange(document, 'filter2RemainingDays', 0, 400) &&
        _isIntInRange(document, 'filter3RemainingDays', 0, 400);
  }

  bool _isSavedWifiNetworkList(Object? value, String currentSsid) {
    if (value is! List || value.length > 10) {
      return false;
    }
    final seenSsids = <String>{};
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys
              .toSet()
              .difference(const <String>{'ssid', 'password'}).isNotEmpty ||
          const <String>{'ssid', 'password'}
              .difference(entry.keys.toSet())
              .isNotEmpty) {
        return false;
      }
      final ssid = entry['ssid'];
      final password = entry['password'];
      if (ssid is! String ||
          ssid.trim().isEmpty ||
          ssid.length > 64 ||
          password is! String ||
          password.length > 64 ||
          !seenSsids.add(ssid)) {
        return false;
      }
    }
    return currentSsid.isEmpty || seenSsids.contains(currentSsid);
  }

  bool _isPureSettings(Object? value) {
    if (value is! Map ||
        value['enabled'] is! bool ||
        !DashboardData.supportedManualPureDurations
            .contains(value['duration'])) {
      return false;
    }
    return true;
  }

  bool _isManualAirConditionerList(Object? value) {
    if (value is! List || value.isEmpty || value.length > 20) {
      return false;
    }
    const requiredKeys = <String>{
      'deviceId',
      'roomName',
      'enabled',
      'targetTemperatureC',
      'mode',
      'fanLevel',
      'timerEnabled',
      'timerStartMinutes',
      'timerEndMinutes',
      'timerRepeat',
    };
    final deviceIds = <String>{};
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final deviceId = entry['deviceId'];
      final roomName = entry['roomName'];
      final targetTemperatureC = entry['targetTemperatureC'];
      final mode = entry['mode'];
      final fanLevel = entry['fanLevel'];
      final start = entry['timerStartMinutes'];
      final end = entry['timerEndMinutes'];
      final repeat = entry['timerRepeat'];
      if (deviceId is! String ||
          deviceId.trim().isEmpty ||
          deviceId.length > 64 ||
          !deviceIds.add(deviceId) ||
          roomName is! String ||
          roomName.trim().isEmpty ||
          roomName.length > 32 ||
          entry['enabled'] is! bool ||
          targetTemperatureC is! int ||
          targetTemperatureC < 16 ||
          targetTemperatureC > 30 ||
          mode is! String ||
          !ManualAirConditionerSetting.supportedModes.contains(mode) ||
          fanLevel is! String ||
          !ManualAirConditionerSetting.supportedFanLevels.contains(fanLevel) ||
          entry['timerEnabled'] is! bool ||
          start is! int ||
          start < 0 ||
          start > 1439 ||
          end is! int ||
          end < 0 ||
          end > 1439 ||
          repeat is! String ||
          !ManualAirConditionerSetting.supportedTimerRepeats.contains(repeat)) {
        return false;
      }
    }
    return true;
  }

  bool _isSmartModeMap(Object? value) {
    if (value is! Map ||
        value.keys.toSet().length != DashboardData.supportedSmartModes.length ||
        !value.keys.toSet().containsAll(DashboardData.supportedSmartModes)) {
      return false;
    }
    const requiredKeys = <String>{
      'enabled',
      'temperatureSetpointC',
      'humiditySetpointPercent',
    };
    var enabledCount = 0;
    for (final mode in DashboardData.supportedSmartModes) {
      final setting = value[mode];
      if (setting is! Map ||
          setting.keys.toSet().length != requiredKeys.length ||
          !setting.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final temperature = setting['temperatureSetpointC'];
      final humidity = setting['humiditySetpointPercent'];
      final enabled = setting['enabled'];
      if (enabled is! bool ||
          temperature is! int ||
          temperature < 16 ||
          temperature > 30 ||
          humidity is! int ||
          humidity < 30 ||
          humidity > 70) {
        return false;
      }
      if (enabled && ++enabledCount > 1) {
        return false;
      }
    }
    return true;
  }

  bool _isManualFloorHeatSettingList(Object? value) {
    if (value is! List || value.isEmpty || value.length > 32) {
      return false;
    }
    const requiredKeys = <String>{
      'deviceId',
      'enabled',
      'targetTemperatureC',
      'timerEnabled',
      'timerStartMinutes',
      'timerEndMinutes',
      'timerRepeat',
    };
    final deviceIds = <String>{};
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final deviceId = entry['deviceId'];
      final temperature = entry['targetTemperatureC'];
      final start = entry['timerStartMinutes'];
      final end = entry['timerEndMinutes'];
      final repeat = entry['timerRepeat'];
      if (deviceId is! String ||
          deviceId.trim().isEmpty ||
          deviceId.length > 64 ||
          !deviceIds.add(deviceId) ||
          entry['enabled'] is! bool ||
          temperature is! int ||
          temperature < 16 ||
          temperature > 30 ||
          entry['timerEnabled'] is! bool ||
          start is! int ||
          start < 0 ||
          start > 1439 ||
          end is! int ||
          end < 0 ||
          end > 1439 ||
          repeat is! String ||
          !ManualAirConditionerSetting.supportedTimerRepeats.contains(repeat)) {
        return false;
      }
    }
    return deviceIds.contains(DashboardData.wholeHomeFloorHeatDeviceId);
  }

  bool _isSortedIntList(List<dynamic> values) {
    for (var index = 1; index < values.length; index++) {
      if ((values[index - 1] as int) >= (values[index] as int)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _currentRuntimeOrDefaults(
    Map<String, dynamic>? document,
  ) {
    final defaults = DashboardData.defaults().toRuntimeJson();
    if (document == null) {
      return defaults;
    }
    final migrated = <String, dynamic>{...document};
    migrated.putIfAbsent(
      'screenBrightnessAvailable',
      () => defaults['screenBrightnessAvailable'],
    );
    migrated.putIfAbsent(
      'screenBrightnessActualPercent',
      () => defaults['screenBrightnessActualPercent'],
    );
    for (final key in <String>[
      'aqiIndicatorAvailable',
      'aqiIndicatorActualEnabled',
      'aqiIndicatorActualLevel',
      DashboardWifiRuntimeKeys.available,
      DashboardWifiRuntimeKeys.enabled,
      DashboardWifiRuntimeKeys.connectedSsid,
      DashboardWifiRuntimeKeys.operation,
      DashboardWifiRuntimeKeys.operationSsid,
      DashboardWifiRuntimeKeys.error,
      DashboardWifiRuntimeKeys.securedSsids,
    ]) {
      migrated.putIfAbsent(key, () => defaults[key]);
    }
    final normalized = DashboardData.fromJson(<String, dynamic>{
      ...DashboardData.defaults().toJson(),
      ...migrated,
    }).toRuntimeJson();
    final fieldsKnown = _matchesKnownJsonFields(migrated, normalized);
    final valuesValid = _hasValidRuntimeValues(migrated);
    if (fieldsKnown && valuesValid) {
      return migrated;
    }
    final invalidDescription = _describeInvalidRuntimeValues(migrated);
    AppLogger.instance.w(
      'runtime 数据校验失败，已回退到默认值；$invalidDescription',
      tag: 'DashboardStorage',
    );
    return defaults;
  }

  /// 返回 runtime 中已知枚举字段的无效描述，仅用于日志定位。
  String _describeInvalidRuntimeValues(Map<String, dynamic> document) {
    final invalid = <String>[];
    final floorHeatControlMode = document['floorHeatControlMode'];
    if (!DashboardData.supportedFloorHeatControlModes
        .contains(floorHeatControlMode)) {
      invalid.add('floorHeatControlMode=$floorHeatControlMode');
    }
    final backendDataStatus = document['backendDataStatus'];
    if (!DashboardData.supportedBackendDataStatuses
        .contains(backendDataStatus)) {
      invalid.add('backendDataStatus=$backendDataStatus');
    }
    final weatherCode = document['weatherCode'];
    if (!WeatherPresentation.isSupportedCode(weatherCode)) {
      invalid.add('weatherCode=$weatherCode');
    }
    final freshAirModeActual = document['freshAirModeActual'];
    if (!DashboardData.supportedManualFreshAirModes
        .contains(freshAirModeActual)) {
      invalid.add('freshAirModeActual=$freshAirModeActual');
    }
    final wifiOperation = document[DashboardWifiRuntimeKeys.operation];
    if (!DashboardWifiRuntimeKeys.supportedOperations.contains(wifiOperation)) {
      invalid.add('wifiOperation=$wifiOperation');
    }
    return invalid.isEmpty ? '存在非枚举字段校验失败' : '无效字段：${invalid.join(', ')}';
  }

  bool _hasValidRuntimeValues(Map<String, dynamic> document) {
    final totalDeviceCount = document['totalDeviceCount'];
    final runningDeviceCount = document['runningDeviceCount'];
    final monthlyTrendYear = document['monthlyTrendYear'];
    final monthlyTrendMonth = document['monthlyTrendMonth'];
    final hasValidMonthlyPeriod = monthlyTrendYear is int &&
        monthlyTrendYear >= 2000 &&
        monthlyTrendYear <= 2100 &&
        monthlyTrendMonth is int &&
        monthlyTrendMonth >= 1 &&
        monthlyTrendMonth <= 12;
    final monthlySeriesLength = _monthlySeriesLength(document);
    return DashboardData.supportedFloorHeatControlModes
            .contains(document['floorHeatControlMode']) &&
        document['homeFloorLayeringEnabled'] is bool &&
        _isAvailableDeviceTypeList(document['availableDeviceTypes']) &&
        _isAirConditionerZoneList(document['airConditionerZones']) &&
        _isFloorHeatZoneList(document['floorHeatZones']) &&
        _isNonEmptyString(document, 'areaName') &&
        _isIntInRange(document, 'outdoorTemperatureC', -60, 80) &&
        _isIntInRange(document, 'outdoorHumidityPercent', 0, 100) &&
        _isIntInRange(document, 'outdoorPm25', 0, 1000) &&
        _isIntInRange(document, 'indoorPm25', 0, 1000) &&
        _isIntInRange(document, 'indoorTemperatureC', -20, 60) &&
        _isIntInRange(document, 'indoorHumidityPercent', 0, 100) &&
        _isIntInRange(document, 'indoorCo2Ppm', 0, 10000) &&
        _isNumberInRange(document, 'indoorFormaldehydeMgM3', 0, 10) &&
        _isTemperatureSeries(document, 'dailyTemperatureIndoorC', 12) &&
        _isTemperatureSeries(document, 'dailyTemperatureOutdoorC', 12) &&
        _isTemperatureSeries(document, 'weeklyTemperatureIndoorC', 7) &&
        _isTemperatureSeries(document, 'weeklyTemperatureOutdoorC', 7) &&
        _isTemperatureSeries(
          document,
          'monthlyTemperatureIndoorC',
          monthlySeriesLength,
        ) &&
        _isTemperatureSeries(
          document,
          'monthlyTemperatureOutdoorC',
          monthlySeriesLength,
        ) &&
        _isSeries(document, 'dailyHumidityIndoorPercent', 12, 0, 100) &&
        _isSeries(document, 'dailyHumidityOutdoorPercent', 12, 0, 100) &&
        _isSeries(document, 'weeklyHumidityIndoorPercent', 7, 0, 100) &&
        _isSeries(document, 'weeklyHumidityOutdoorPercent', 7, 0, 100) &&
        _isSeries(
          document,
          'monthlyHumidityIndoorPercent',
          monthlySeriesLength,
          0,
          100,
        ) &&
        _isSeries(
          document,
          'monthlyHumidityOutdoorPercent',
          monthlySeriesLength,
          0,
          100,
        ) &&
        _isSeries(document, 'dailyPm25Indoor', 12, 0, 1000) &&
        _isSeries(document, 'dailyPm25Outdoor', 12, 0, 1000) &&
        _isSeries(document, 'weeklyPm25Indoor', 7, 0, 1000) &&
        _isSeries(document, 'weeklyPm25Outdoor', 7, 0, 1000) &&
        _isSeries(
          document,
          'monthlyPm25Indoor',
          monthlySeriesLength,
          0,
          1000,
        ) &&
        _isSeries(
          document,
          'monthlyPm25Outdoor',
          monthlySeriesLength,
          0,
          1000,
        ) &&
        _isSeries(document, 'dailyCo2Ppm', 12, 0, 10000) &&
        _isSeries(document, 'weeklyCo2Ppm', 7, 0, 10000) &&
        _isSeries(
          document,
          'monthlyCo2Ppm',
          monthlySeriesLength,
          0,
          10000,
        ) &&
        hasValidMonthlyPeriod &&
        totalDeviceCount is int &&
        totalDeviceCount > 0 &&
        totalDeviceCount <= 1000 &&
        runningDeviceCount is int &&
        runningDeviceCount >= 0 &&
        runningDeviceCount <= totalDeviceCount &&
        WeatherPresentation.isSupportedCode(document['weatherCode']) &&
        _isNonEmptyString(document, 'weatherTemperatureRange') &&
        _isNonEmptyString(document, 'smartAirConditionerMode') &&
        _isNonEmptyString(document, 'smartAirConditionerFanLevel') &&
        _isNonEmptyString(document, 'smartFreshAirMode') &&
        _isNonEmptyString(document, 'smartFreshAirFanLevel') &&
        // IP 获取晚于 Wi-Fi 关联是正常情况；空串与 IPv4 均为有效快照。
        (document[DashboardWifiRuntimeKeys.ipAddress] == '' ||
            _isIpv4Address(document[DashboardWifiRuntimeKeys.ipAddress])) &&
        _isWifiSsidList(document[DashboardWifiRuntimeKeys.availableSsids]) &&
        document[DashboardWifiRuntimeKeys.available] is bool &&
        document[DashboardWifiRuntimeKeys.enabled] is bool &&
        document[DashboardWifiRuntimeKeys.connected] is bool &&
        _isShortString(
          document[DashboardWifiRuntimeKeys.connectedSsid],
          64,
        ) &&
        DashboardWifiRuntimeKeys.supportedOperations
            .contains(document[DashboardWifiRuntimeKeys.operation]) &&
        _isShortString(
          document[DashboardWifiRuntimeKeys.operationSsid],
          64,
        ) &&
        _isShortString(document[DashboardWifiRuntimeKeys.error], 256) &&
        _isWifiSsidList(document[DashboardWifiRuntimeKeys.securedSsids]) &&
        _isAlertItemList(document['notifications']) &&
        _isAlertItemList(document['faults']) &&
        _isNonEmptyString(document, 'faultServicePhone') &&
        document['allDevicesRunning'] is bool &&
        document['freshAirRunning'] is bool &&
        document['humidifierRunning'] is bool &&
        document['pureRunning'] is bool &&
        DashboardData.supportedManualFreshAirModes
            .contains(document['freshAirModeActual']) &&
        DashboardData.supportedManualFreshAirFanLevels
            .contains(document['freshAirFanLevelActual']) &&
        _isIntInRange(
          document,
          'humidifierSetpointActualPercent',
          30,
          70,
        ) &&
        DashboardData.supportedBackendDataStatuses
            .contains(document['backendDataStatus']) &&
        document['screenBrightnessAvailable'] is bool &&
        _isIntInRange(document, 'screenBrightnessActualPercent', 0, 100) &&
        document['aqiIndicatorAvailable'] is bool &&
        document['aqiIndicatorActualEnabled'] is bool &&
        _isIntInRange(document, 'aqiIndicatorActualLevel', 0, 4) &&
        _isOptionalNonEmptyString(document, 'homeError');
  }

  bool _isAvailableDeviceTypeList(Object? value) {
    if (value is! List ||
        value.length > DashboardData.availableDeviceTypeOrder.length) {
      return false;
    }
    final deviceTypes = <String>[];
    for (final entry in value) {
      if (entry is! String ||
          !DashboardData.supportedAvailableDeviceTypes.contains(entry) ||
          deviceTypes.contains(entry)) {
        return false;
      }
      deviceTypes.add(entry);
    }
    final canonicalOrder = DashboardData.availableDeviceTypeOrder
        .where(deviceTypes.contains)
        .toList(growable: false);
    return _sameStringLists(deviceTypes, canonicalOrder);
  }

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isFloorHeatZoneList(Object? value) {
    if (value is! List || value.length > 32) {
      return false;
    }
    const requiredKeys = <String>{'deviceId', 'roomName', 'online'};
    final deviceIds = <String>{};
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final deviceId = entry['deviceId'];
      final roomName = entry['roomName'];
      if (deviceId is! String ||
          deviceId.trim().isEmpty ||
          deviceId.length > 64 ||
          !deviceIds.add(deviceId) ||
          roomName is! String ||
          roomName.trim().isEmpty ||
          roomName.length > 32 ||
          entry['online'] is! bool) {
        return false;
      }
    }
    return true;
  }

  bool _isAirConditionerZoneList(Object? value) {
    if (value is! List || value.length > 32) {
      return false;
    }
    const requiredKeys = <String>{'deviceId', 'roomName', 'online'};
    final deviceIds = <String>{};
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final deviceId = entry['deviceId'];
      final roomName = entry['roomName'];
      if (deviceId is! String ||
          deviceId.trim().isEmpty ||
          deviceId.length > 64 ||
          !deviceIds.add(deviceId) ||
          roomName is! String ||
          roomName.trim().isEmpty ||
          roomName.length > 32 ||
          entry['online'] is! bool) {
        return false;
      }
    }
    return true;
  }

  bool _isIpv4Address(Object? value) {
    if (value is! String) {
      return false;
    }
    final parts = value.split('.');
    return parts.length == 4 &&
        parts.every((part) {
          final number = int.tryParse(part);
          return number != null &&
              number >= 0 &&
              number <= 255 &&
              number.toString() == part;
        });
  }

  bool _isShortString(Object? value, int maximumLength) =>
      value is String && value.length <= maximumLength;

  bool _isWifiSsidList(Object? value) {
    return value is List &&
        value.length <= 20 &&
        value.every(
          (entry) =>
              entry is String && entry.trim().isNotEmpty && entry.length <= 64,
        ) &&
        value.toSet().length == value.length;
  }

  bool _isAlertItemList(Object? value) {
    if (value is! List || value.length > 20) {
      return false;
    }
    const requiredKeys = <String>{'id', 'title', 'description', 'date'};
    final ids = <String>{};
    final datePattern = RegExp(r'^\d{4}/\d{2}/\d{2}$');
    for (final entry in value) {
      if (entry is! Map ||
          entry.keys.toSet().length != requiredKeys.length ||
          !entry.keys.toSet().containsAll(requiredKeys)) {
        return false;
      }
      final id = entry['id'];
      final title = entry['title'];
      final description = entry['description'];
      final date = entry['date'];
      if (id is! String ||
          id.trim().isEmpty ||
          id.length > 64 ||
          !ids.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 40 ||
          description is! String ||
          description.trim().isEmpty ||
          description.length > 100 ||
          date is! String ||
          (!datePattern.hasMatch(date) && date != '----/--/--')) {
        return false;
      }
    }
    return true;
  }

  bool _isIntInRange(
    Map<String, dynamic> document,
    String key,
    int minimum,
    int maximum,
  ) {
    final value = document[key];
    return value is int && value >= minimum && value <= maximum;
  }

  bool _isValidSettingsDate(Map<String, dynamic> document) {
    final year = document['dateYear'];
    final month = document['dateMonth'];
    final day = document['dateDay'];
    if (year is! int ||
        month is! int ||
        day is! int ||
        year < 2000 ||
        year > 2099) {
      return false;
    }
    final normalized = DateTime(year, month, day);
    return normalized.year == year &&
        normalized.month == month &&
        normalized.day == day;
  }

  bool _isNumberInRange(
    Map<String, dynamic> document,
    String key,
    double minimum,
    double maximum,
  ) {
    final value = document[key];
    return value is num && value >= minimum && value <= maximum;
  }

  bool _isTemperatureSeries(
    Map<String, dynamic> document,
    String key,
    int expectedLength,
  ) {
    return _isSeries(document, key, expectedLength, -20, 60);
  }

  /// 七条按月数据必须同长且固定为 31 项；界面再按自然月读取前
  /// 28、29、30 或 31 项，确保切换月份时具有完整数据容量。
  int _monthlySeriesLength(Map<String, dynamic> document) {
    const keys = <String>[
      'monthlyTemperatureIndoorC',
      'monthlyTemperatureOutdoorC',
      'monthlyHumidityIndoorPercent',
      'monthlyHumidityOutdoorPercent',
      'monthlyPm25Indoor',
      'monthlyPm25Outdoor',
      'monthlyCo2Ppm',
    ];
    final first = document[keys.first];
    if (first is! List || first.length != 31) {
      return 0;
    }
    final length = first.length;
    return keys.skip(1).every(
              (key) => document[key] is List && document[key].length == length,
            )
        ? length
        : 0;
  }

  bool _isSeries(
    Map<String, dynamic> document,
    String key,
    int expectedLength,
    double minimum,
    double maximum,
  ) {
    final value = document[key];
    return value is List &&
        value.length == expectedLength &&
        value.every(
          (entry) =>
              entry is num &&
              entry.isFinite &&
              entry >= minimum &&
              entry <= maximum,
        );
  }

  bool _sameJsonMaps(
    Map<String, dynamic>? first,
    Map<String, dynamic> second,
  ) {
    if (first == null || first.length != second.length) {
      return false;
    }
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) ||
          !_sameJsonValue(entry.value, second[entry.key])) {
        return false;
      }
    }
    return true;
  }

  bool _matchesKnownJsonFields(
    Map<String, dynamic> document,
    Map<String, dynamic> normalized,
  ) {
    return normalized.entries.every(
      (entry) =>
          document.containsKey(entry.key) &&
          _sameJsonValue(document[entry.key], entry.value),
    );
  }

  List<String> _applyDevicePresence(
    List<String> current,
    BeiAngDevicePresence presence,
  ) {
    final available = current.toSet();
    if (presence.airConditioner != null) {
      if (presence.airConditioner!) {
        available.add('air_conditioner');
      } else {
        available.remove('air_conditioner');
      }
    }
    if (presence.floorHeating != null) {
      if (presence.floorHeating!) {
        available.add('floor_heat');
      } else {
        available.remove('floor_heat');
      }
    }
    return DashboardData.availableDeviceTypeOrder
        .where(available.contains)
        .toList(growable: false);
  }

  bool _sameJsonValue(Object? first, Object? second) {
    if (first is List && second is List) {
      return first.length == second.length &&
          Iterable<int>.generate(first.length).every(
            (index) => _sameJsonValue(first[index], second[index]),
          );
    }
    if (first is Map && second is Map) {
      if (first.length != second.length) {
        return false;
      }
      return first.entries.every(
        (entry) =>
            second.containsKey(entry.key) &&
            _sameJsonValue(entry.value, second[entry.key]),
      );
    }
    return first == second;
  }

  bool _isNonEmptyString(Map<String, dynamic> document, String key) {
    final value = document[key];
    return value is String && value.trim().isNotEmpty;
  }

  bool _isOptionalNonEmptyString(Map<String, dynamic> document, String key) {
    if (!document.containsKey(key)) {
      return true;
    }
    return _isNonEmptyString(document, key);
  }

  Future<Map<String, dynamic>?> _readJsonOrNull(File file) async {
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('JSON 根节点必须是对象');
    } on Object catch (error) {
      AppLogger.instance.e(
        '主页数据读取失败，将重建该文件：${file.path}',
        tag: 'DashboardStorage',
        error: error,
      );
      return null;
    }
  }

  Future<void> _writeJsonAtomically(
    File target,
    Map<String, dynamic> json,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    final temporary = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString('${encoder.convert(json)}\n');
    await temporary.rename(target.path);
  }
}
