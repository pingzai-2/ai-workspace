import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/dashboard_data.dart';
import '../models/history_trend.dart';

/// 后端一次聚合读取形成的同代运行快照。
///
/// [protocol] 和 [localDevice] 保留完整数据字典，便于后续页面逐项接入；
/// [runtimePatch] 只包含当前已经确认、且属于 Flutter runtime 的字段。
class BeiAngRuntimeSnapshot {
  const BeiAngRuntimeSnapshot({
    required this.protocol,
    required this.localDevice,
    required this.runtimePatch,
  });

  final Map<String, dynamic> protocol;
  final Map<String, dynamic> localDevice;
  final Map<String, dynamic> runtimePatch;
}

/// 后端可选的设备存在性信息。
///
/// 字段为 null 表示对应接口不可用，本轮不修改运行时设备列表；只有
/// 明确返回 true/false 时才更新对应设备在 availableDeviceTypes 中的状态。
class BeiAngDevicePresence {
  const BeiAngDevicePresence({
    this.airConditioner,
    this.floorHeating,
  });

  final bool? airConditioner;
  final bool? floorHeating;
}

/// BeiAng8Panel 给 8 寸 UI 使用的接口边界。
///
/// 运行态只做一次聚合读取；UI 不感知 TTY、寄存器批次、sysfs 或状态文件。
abstract class BeiAng8PanelApi {
  Future<BeiAngRuntimeSnapshot> readRuntimeSnapshot();

  /// 读取一段历史趋势。旧后端没有历史接口时返回 null，不影响实时快照。
  Future<HistoryTrendSnapshot?> readHistoryTrend(String range) async => null;

  /// 读取后端的可选设备存在性接口：
  /// `/api/device/air-conditioner/presence` 与
  /// `/api/device/floor-heating/presence`。两个接口都不可用时返回 null。
  /// 默认实现保持旧 API 测试桩和无此能力的后端兼容。
  Future<BeiAngDevicePresence?> readDevicePresence() async => null;

  Future<bool> setFreshAirPower(bool enabled);
  Future<bool> setHumidifierPower(bool enabled);

  /// UI 的“超净”对应 1002H 超净模式，不再借用 1012H IEF。
  Future<bool> setPurePower(bool enabled);

  Future<bool> setLeaveHome();

  Future<bool> setFreshAirMode(String mode);
  Future<bool> setFreshAirFanLevel(String level);
  Future<bool> setTargetHumidity(int percent);

  Future<bool> setScreenBrightnessPercent(int percent);
  /// 只表示息屏/唤醒命令已被后端接受；硬件结果由 runtime 快照反馈。
  Future<bool> setScreenSleep(bool sleep) async => false;
  Future<bool> setAqiIndicatorEnabled(bool enabled) async => false;
  Future<bool> setRadarEnabled(bool enabled);

  Future<bool> setWifiEnabled(bool enabled) async => false;
  Future<bool> scanWifi() async => false;
  Future<bool> connectWifi(String ssid, String password) async => false;
  Future<bool> disconnectWifi() async => false;
}

/// TCP 连接、请求或响应等待失败；表示后端当前不可达。
class BeiAng8PanelUnavailableException implements Exception {
  const BeiAng8PanelUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'BeiAng8PanelUnavailableException: $message';
}

/// 后端已经响应，但 HTTP 状态、JSON 或业务字段不符合接口约定。
class BeiAng8PanelResponseException implements Exception {
  const BeiAng8PanelResponseException(this.message);

  final String message;

  @override
  String toString() => 'BeiAng8PanelResponseException: $message';
}

typedef BeiAng8PanelJsonTransport = Future<Object?> Function(
  String method,
  Uri uri,
  Map<String, dynamic>? body,
);

class _WifiNetwork {
  const _WifiNetwork({
    required this.ssid,
    required this.secured,
    required this.rssi,
  });

  final String ssid;
  final bool secured;
  final int rssi;
}

class BeiAng8PanelHttpApi implements BeiAng8PanelApi {
  static const Duration _wifiScanTimeout = Duration(seconds: 15);
  static const Duration _historyTrendTimeout = Duration(seconds: 10);
  static const int _communicationPort2 = 8081;
  static const int _communicationPort3 = 8082;
  static const int _communicationPort4 = 8083;

  BeiAng8PanelHttpApi({
    Uri? baseUri,
    Duration timeout = const Duration(milliseconds: 500),
    BeiAng8PanelJsonTransport? transport,
  })  : _baseUri = baseUri ??
            Uri.parse(
              const String.fromEnvironment(
                'BEIANG8PANEL_BASE_URL',
                defaultValue: 'http://127.0.0.1:8080',
              ),
            ),
        _timeout = timeout,
        _transport = transport;

  final Uri _baseUri;
  final Duration _timeout;
  final BeiAng8PanelJsonTransport? _transport;
  int? _screenMinBrightness;
  int? _screenMaxBrightness;

  @override
  Future<BeiAngRuntimeSnapshot> readRuntimeSnapshot() async {
    // 扩展通信进程只做可选的存活探测，响应不参与 runtime、连接状态或任何
    // 业务判断；注入测试 transport 时不触发探测。
    unawaited(_readCommunicationPort2());
    unawaited(_readCommunicationPort3());
    unawaited(_readCommunicationPort4());
    final response = await _request('GET', '/api/runtime/snapshot');
    final data = _unwrapData(response);
    final protocol = _requiredMap(data, 'protocol', 'data.protocol');
    final environment = _requiredMap(data, 'environment', 'data.environment');
    final localDevice = _requiredMap(data, 'localDevice', 'data.localDevice');
    final dataFresh = _requiredBool(data, 'dataFresh', 'data.dataFresh');
    final cache = _requiredMap(data, 'cache', 'data.cache');
    final holding = _requiredMap(cache, 'holding', 'data.cache.holding');
    final input = _requiredMap(cache, 'input', 'data.cache.input');
    final discrete = _requiredMap(cache, 'discrete', 'data.cache.discrete');

    final screen = _requiredMap(
      localDevice,
      'screen',
      'data.localDevice.screen',
    );
    final brightnessAvailable = _requiredBool(
      screen,
      'brightnessAvailable',
      'data.localDevice.screen.brightnessAvailable',
    );
    int? brightnessActualPercent;
    if (brightnessAvailable) {
      final minimum = _requiredInt(
        screen,
        'minBrightness',
        'data.localDevice.screen.minBrightness',
      );
      final maximum = _requiredInt(
        screen,
        'maxBrightness',
        'data.localDevice.screen.maxBrightness',
      );
      if (minimum < 0 || maximum <= minimum) {
        throw const BeiAng8PanelResponseException(
          '屏幕亮度范围无效',
        );
      }
      final current = _requiredInt(
        screen,
        'currentBrightness',
        'data.localDevice.screen.currentBrightness',
      );
      if (current < minimum || current > maximum) {
        throw const BeiAng8PanelResponseException(
          '屏幕实际亮度超出当前范围',
        );
      }
      _screenMinBrightness = minimum;
      _screenMaxBrightness = maximum;
      brightnessActualPercent =
          (((current - minimum) * 100) / (maximum - minimum)).round();
    } else {
      _screenMinBrightness = null;
      _screenMaxBrightness = null;
    }

    final aqiLed = _requiredMap(
      localDevice,
      'aqiLed',
      'data.localDevice.aqiLed',
    );
    final aqiAvailable = _requiredBool(
      aqiLed,
      'stateAvailable',
      'data.localDevice.aqiLed.stateAvailable',
    );
    final aqiLevel = _requiredInt(
      aqiLed,
      'level',
      'data.localDevice.aqiLed.level',
    );
    if (aqiLevel < 0 || aqiLevel > 4) {
      throw const BeiAng8PanelResponseException('AQI 指示灯等级必须为 0..4');
    }
    final aqiEnabled = _requiredBool(
      aqiLed,
      'enabled',
      'data.localDevice.aqiLed.enabled',
    );

    final wifi = _requiredMap(
      localDevice,
      'wifi',
      'data.localDevice.wifi',
    );
    final wifiOperation = _requiredString(
      wifi,
      'state',
      'data.localDevice.wifi.state',
    );
    if (!DashboardWifiRuntimeKeys.supportedOperations.contains(wifiOperation)) {
      throw BeiAng8PanelResponseException(
        'data.localDevice.wifi.state 不支持: $wifiOperation',
      );
    }
    final wifiNetworks = _wifiNetworks(wifi);
    final wifiState = DashboardWifiState.normalized(
      available: _requiredBool(
        wifi,
        'available',
        'data.localDevice.wifi.available',
      ),
      enabled: _requiredBool(
        wifi,
        'enabled',
        'data.localDevice.wifi.enabled',
      ),
      connected: _requiredBool(
        wifi,
        'connected',
        'data.localDevice.wifi.connected',
      ),
      ssid: _requiredString(
        wifi,
        'connectedSsid',
        'data.localDevice.wifi.connectedSsid',
      ),
      ipAddress: _requiredString(
        wifi,
        'ipAddress',
        'data.localDevice.wifi.ipAddress',
      ),
      operation: wifiOperation,
      operationSsid: _requiredString(
        wifi,
        'targetSsid',
        'data.localDevice.wifi.targetSsid',
      ),
      error: _requiredString(
        wifi,
        'error',
        'data.localDevice.wifi.error',
      ),
      availableSsids:
          wifiNetworks.map((network) => network.ssid).toList(growable: false),
      securedSsids: wifiNetworks
          .where((network) => network.secured)
          .map((network) => network.ssid)
          .toList(growable: false),
    );

    final holdingValid = _requiredBool(
      holding,
      'valid',
      'data.cache.holding.valid',
    );
    final inputValid = _requiredBool(
      input,
      'valid',
      'data.cache.input.valid',
    );
    final discreteValid = _requiredBool(
      discrete,
      'valid',
      'data.cache.discrete.valid',
    );

    final patch = <String, dynamic>{
      'backendDataStatus': dataFresh ? 'fresh' : 'stale',
      'screenBrightnessAvailable': brightnessAvailable,
      if (brightnessActualPercent != null)
        'screenBrightnessActualPercent': brightnessActualPercent,
      'aqiIndicatorAvailable': aqiAvailable,
      'aqiIndicatorActualEnabled': aqiEnabled,
      'aqiIndicatorActualLevel': aqiLevel,
      ...wifiState.toRuntimePatch(),
    };
    if (inputValid) {
      final indoor = _requiredMap(
        environment,
        'indoorReturnAir',
        'data.environment.indoorReturnAir',
      );
      final outdoor = _requiredMap(
        environment,
        'outdoorAir',
        'data.environment.outdoorAir',
      );
      patch.addAll(<String, dynamic>{
        'indoorTemperatureC': _roundedNumber(
          indoor,
          'temperature',
          'data.environment.indoorReturnAir.temperature',
          -20,
          60,
        ),
        'indoorHumidityPercent': _roundedNumber(
          indoor,
          'humidity',
          'data.environment.indoorReturnAir.humidity',
          0,
          100,
        ),
        'indoorPm25': _roundedNumber(
          indoor,
          'pm25',
          'data.environment.indoorReturnAir.pm25',
          0,
          1000,
        ),
        'indoorCo2Ppm': _roundedNumber(
          indoor,
          'co2',
          'data.environment.indoorReturnAir.co2',
          0,
          10000,
        ),
        'outdoorTemperatureC': _roundedNumber(
          outdoor,
          'temperature',
          'data.environment.outdoorAir.temperature',
          -60,
          80,
        ),
        'outdoorHumidityPercent': _roundedNumber(
          outdoor,
          'humidity',
          'data.environment.outdoorAir.humidity',
          0,
          100,
        ),
        'outdoorPm25': _roundedNumber(
          outdoor,
          'pm25',
          'data.environment.outdoorAir.pm25',
          0,
          1000,
        ),
      });
    }

    if (holdingValid) {
      final control = _requiredMap(
        protocol,
        'controlStatus',
        'data.protocol.controlStatus',
      );
      patch.addAll(<String, dynamic>{
        'allDevicesRunning': _requiredBool(
          control,
          'switchOn',
          'data.protocol.controlStatus.switchOn',
        ),
        'freshAirRunning': _requiredBool(
          control,
          'freshAirModuleOn',
          'data.protocol.controlStatus.freshAirModuleOn',
        ),
        'humidifierRunning': _requiredBool(
          control,
          'humidityModuleOn',
          'data.protocol.controlStatus.humidityModuleOn',
        ),
        'pureRunning': _requiredBool(
          control,
          'superPureOn',
          'data.protocol.controlStatus.superPureOn',
        ),
      });

      final runMode = _requiredInt(
        control,
        'runModeRaw',
        'data.protocol.controlStatus.runModeRaw',
      );
      final fanGear = _requiredInt(
        control,
        'fanGear',
        'data.protocol.controlStatus.fanGear',
      );
      // v1.22 已移除 controlMode，直接按 1007H 的运行模式映射当前 UI。
      switch (runMode) {
        case 0:
          patch['freshAirModeActual'] = 'internal_circulation';
          break;
        case 2:
          patch['freshAirModeActual'] = 'full_heat_exchange';
          break;
        case 3:
          patch['freshAirModeActual'] = 'auto';
          break;
      }
      // 当前 UI 只设计 L1..L5。0（停机）和协议扩展档位不伪装成 UI 档位，
      // 原始值仍完整保留在 protocol 数据字典中。
      if (fanGear >= 1 && fanGear <= 5) {
        patch['freshAirFanLevelActual'] = 'L$fanGear';
      }

      final environmentSettings = _requiredMap(
        protocol,
        'environmentSettings',
        'data.protocol.environmentSettings',
      );
      final targetHumidity = _requiredInt(
        environmentSettings,
        'targetHumidity',
        'data.protocol.environmentSettings.targetHumidity',
      );
      if (targetHumidity >= 30 && targetHumidity <= 70) {
        patch['humidifierSetpointActualPercent'] = targetHumidity;
      }

      final notifications = _requiredMap(
        protocol,
        'notifications',
        'data.protocol.notifications',
      );
      if (!_requiredBool(
        notifications,
        'valid',
        'data.protocol.notifications.valid',
      )) {
        throw const BeiAng8PanelResponseException(
          '保持寄存器缓存有效时通知快照也必须有效',
        );
      }
      patch['notifications'] = _notificationItems(notifications);
    }

    if (discreteValid) {
      final faults = _requiredMap(
        protocol,
        'faults',
        'data.protocol.faults',
      );
      if (!_requiredBool(faults, 'valid', 'data.protocol.faults.valid')) {
        throw const BeiAng8PanelResponseException(
          '离散缓存有效时 data.protocol.faults.valid 也必须为 true',
        );
      }
      patch['faults'] = _faultItems(faults);
    }

    return BeiAngRuntimeSnapshot(
      protocol: Map<String, dynamic>.from(protocol),
      localDevice: Map<String, dynamic>.from(localDevice),
      runtimePatch: patch,
    );
  }

  @override
  Future<BeiAngDevicePresence?> readDevicePresence() async {
    final values = await Future.wait<bool?>(<Future<bool?>>[
      _readOptionalPresence(
        '/api/device/air-conditioner/presence',
        'hasAirConditioner',
      ),
      _readOptionalPresence(
        '/api/device/floor-heating/presence',
        'hasFloorHeating',
      ),
    ]);
    final airConditioner = values[0];
    final floorHeating = values[1];
    if (airConditioner == null && floorHeating == null) {
      return null;
    }
    return BeiAngDevicePresence(
      airConditioner: airConditioner,
      floorHeating: floorHeating,
    );
  }

  @override
  Future<HistoryTrendSnapshot?> readHistoryTrend(String range) async {
    if (range != 'day' && range != 'week' && range != 'month') {
      throw const BeiAng8PanelResponseException('历史趋势范围无效');
    }
    final uri = _baseUri.resolve('/api/history/trend').replace(
      queryParameters: <String, String>{'range': range},
    );
    final response = await _requestDecodedUri(
      'GET',
      uri,
      null,
      _historyTrendTimeout,
    );
    final value = _unwrapDataValue(response);
    if (value is! Map) {
      throw const BeiAng8PanelResponseException('历史趋势 data 必须是对象');
    }
    try {
      return HistoryTrendSnapshot.fromJson(
        Map<String, dynamic>.from(value),
      );
    } on FormatException catch (error) {
      throw BeiAng8PanelResponseException(error.message);
    }
  }

  Future<bool?> _readOptionalPresence(String path, String key) async {
    try {
      final response = await _requestDecoded('GET', path);
      final data = _unwrapDataValue(response);
      if (data is! Map) {
        return null;
      }
      final value = data[key];
      return value is bool ? value : null;
    } on Object {
      // 旧后端没有该接口、请求超时或响应格式不兼容时，不影响主业务。
      return null;
    }
  }

  Future<void> _readCommunicationPort2() {
    return _readCommunicationPort(_communicationPort2);
  }

  Future<void> _readCommunicationPort3() {
    return _readCommunicationPort(_communicationPort3);
  }

  Future<void> _readCommunicationPort4() {
    return _readCommunicationPort(_communicationPort4);
  }

  Future<void> _readCommunicationPort(int port) async {
    if (!Platform.isLinux || _transport != null) {
      return;
    }
    final uri = _baseUri.replace(port: port).resolve('/api/ping');
    final client = HttpClient()..connectionTimeout = _timeout;
    HttpClientRequest? request;
    try {
      request = await client.openUrl('GET', uri);
      request.persistentConnection = false;
      // 只把响应读完释放连接，不解析状态码、JSON 或业务字段。
      await (await request.close()).drain<void>().timeout(_timeout);
    } catch (_) {
      // 扩展通道当前不参与业务，未启动、无数据或超时均静默忽略。
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> setFreshAirPower(bool enabled) {
    return _setBooleanControl('/api/freshair/switch', enabled);
  }

  @override
  Future<bool> setHumidifierPower(bool enabled) {
    return _setBooleanControl('/api/humidity-module/switch', enabled);
  }

  @override
  Future<bool> setPurePower(bool enabled) async {
    return _setBooleanControl('/api/super-pure/switch', enabled);
  }

  @override
  Future<bool> setLeaveHome() async {
    final response = await _request(
      'POST',
      '/api/device/power',
      <String, dynamic>{'power': true},
    );
    final data = _unwrapData(response);
    return data['accepted'] == true;
  }

  @override
  Future<bool> setFreshAirMode(String mode) async {
    final Map<String, dynamic> body;
    switch (mode) {
      case 'internal_circulation':
        body = <String, dynamic>{'automatic': false, 'mode': 0};
        break;
      case 'full_heat_exchange':
        body = <String, dynamic>{'automatic': false, 'mode': 2};
        break;
      case 'auto':
        body = <String, dynamic>{'automatic': true};
        break;
      default:
        return false;
    }
    final response = await _request('POST', '/api/freshair/mode', body);
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> setFreshAirFanLevel(String level) async {
    final match = RegExp(r'^L([1-5])$').firstMatch(level);
    if (match == null) return false;
    final response = await _request(
      'POST',
      '/api/freshair/speed',
      <String, dynamic>{'speed': int.parse(match.group(1)!)},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> setTargetHumidity(int percent) async {
    if (percent < 30 || percent > 70) return false;
    final response = await _request(
      'POST',
      '/api/humidity-module/target',
      <String, dynamic>{'humidity': percent},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> setScreenBrightnessPercent(int percent) async {
    if (percent < 0 || percent > 100) {
      return false;
    }
    final minimum = _screenMinBrightness;
    final maximum = _screenMaxBrightness;
    if (minimum == null || maximum == null) {
      return false;
    }
    final brightness = minimum + ((maximum - minimum) * percent / 100).round();
    final response = await _request(
      'POST',
      '/api/local-device/screen/brightness',
      <String, dynamic>{'brightness': brightness},
    );
    final data = _unwrapData(response);
    return data['accepted'] == true;
  }

  @override
  Future<bool> setScreenSleep(bool sleep) async {
    final response = await _request(
      'POST',
      '/setScreenSleep',
      <String, dynamic>{'sleep': sleep ? 1 : 0},
    );
    final data = _unwrapData(response);
    // 新后端返回 accepted；兼容早期文档/实现返回 success 的形式。
    return data['accepted'] == true || data['success'] == true;
  }

  @override
  Future<bool> setAqiIndicatorEnabled(bool enabled) async {
    final response = await _request(
      'POST',
      '/api/local-device/aqi-led/enabled',
      <String, dynamic>{'enabled': enabled},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> setWifiEnabled(bool enabled) async {
    final response = await _request(
      'POST',
      '/api/local-device/wifi/enabled',
      <String, dynamic>{'enabled': enabled},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> scanWifi() async {
    // 与产测保持一致：异步触发后等待模组完成扫描，再读取结果缓存。
    final accepted = _unwrapData(
      await _request(
        'POST',
        '/scanWifi',
        const <String, dynamic>{},
      ),
    )['accepted'];
    if (accepted != true) {
      return false;
    }

    await Future<void>.delayed(const Duration(seconds: 6));

    final response = await _requestDecoded(
      'GET',
      '/getWifiInfo',
      null,
      _wifiScanTimeout,
    );
    final data = _unwrapDataValue(response);
    if (data is! List) {
      throw const BeiAng8PanelResponseException('WiFi 扫描响应格式无效');
    }
    return true;
  }

  @override
  Future<bool> connectWifi(String ssid, String password) async {
    if (ssid.trim().isEmpty || ssid.length > 64 || password.length > 128) {
      return false;
    }
    final response = await _request(
      'POST',
      '/api/local-device/wifi/connect',
      <String, dynamic>{'ssid': ssid, 'password': password},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> disconnectWifi() async {
    final response = await _request(
      'POST',
      '/api/local-device/wifi/disconnect',
      const <String, dynamic>{},
    );
    return _unwrapData(response)['accepted'] == true;
  }

  @override
  Future<bool> setRadarEnabled(bool enabled) async {
    final response = await _request(
      'POST',
      '/api/local-device/radar/enabled',
      <String, dynamic>{'enable': enabled},
    );
    final data = _unwrapData(response);
    return data['accepted'] == true;
  }

  Future<bool> _setBooleanControl(String path, bool enabled) async {
    final response = await _request(
      'POST',
      path,
      <String, dynamic>{'on': enabled},
    );
    final data = _unwrapData(response);
    return data['accepted'] == true;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Duration? timeout,
  ]) async {
    final response = await _requestDecoded(method, path, body, timeout);
    if (response is! Map) {
      throw const BeiAng8PanelResponseException('HTTP 响应根节点必须是对象');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<Object?> _requestDecoded(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Duration? timeout,
  ]) async {
    final uri = _baseUri.resolve(path);
    final requestTimeout = timeout ?? _timeout;
    final transport = _transport;
    if (transport == null) {
      return _requestOverHttp(method, uri, body, requestTimeout);
    }
    try {
      return await transport(method, uri, body).timeout(requestTimeout);
    } on BeiAng8PanelResponseException {
      rethrow;
    } on TimeoutException {
      throw BeiAng8PanelUnavailableException('请求超时: $uri');
    } on SocketException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    } on HttpException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    }
  }

  Future<Object?> _requestDecodedUri(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
    Duration timeout,
  ) async {
    final transport = _transport;
    if (transport == null) {
      return _requestOverHttp(method, uri, body, timeout);
    }
    try {
      return await transport(method, uri, body).timeout(timeout);
    } on BeiAng8PanelResponseException {
      rethrow;
    } on TimeoutException {
      throw BeiAng8PanelUnavailableException('请求超时: $uri');
    } on SocketException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    } on HttpException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    }
  }

  Future<Object?> _requestOverHttp(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    HttpClientRequest? request;
    try {
      return await (() async {
        request = await client.openUrl(method, uri);
        request!.persistentConnection = false;
        request!.headers.contentType = ContentType.json;
        if (body != null) {
          request!.write(jsonEncode(body));
        }
        final response = await request!.close();
        final responseBody = await utf8.decoder.bind(response).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw BeiAng8PanelResponseException(
            'HTTP ${response.statusCode}: $responseBody',
          );
        }
        return jsonDecode(responseBody);
      })()
          .timeout(timeout);
    } on BeiAng8PanelResponseException {
      rethrow;
    } on TimeoutException catch (error) {
      request?.abort(error);
      throw BeiAng8PanelUnavailableException('请求超时: $uri');
    } on SocketException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    } on HttpException catch (error) {
      throw BeiAng8PanelUnavailableException(error.message);
    } on FormatException catch (error) {
      throw BeiAng8PanelResponseException('JSON 解析失败: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic> response) {
    final data = _unwrapDataValue(response);
    if (data is! Map) {
      throw const BeiAng8PanelResponseException('成功响应的 data 必须是对象');
    }
    return Map<String, dynamic>.from(data);
  }

  Object? _unwrapDataValue(Object? response) {
    if (response is! Map) {
      return response;
    }
    final map = response;
    if (!map.containsKey('code')) {
      return response;
    }
    final code = map['code'];
    if (code != 0 && code != 200) {
      throw BeiAng8PanelResponseException(
        '后端拒绝请求: code=$code, message=${map['message'] ?? map['msg']}',
      );
    }
    return map['data'];
  }

  Map<String, dynamic> _requiredMap(
    Map<dynamic, dynamic> parent,
    String key,
    String path,
  ) {
    final value = parent[key];
    if (value is! Map) {
      throw BeiAng8PanelResponseException('$path 必须是对象');
    }
    return Map<String, dynamic>.from(value);
  }

  bool _requiredBool(
    Map<dynamic, dynamic> parent,
    String key,
    String path,
  ) {
    final value = parent[key];
    if (value is! bool) {
      throw BeiAng8PanelResponseException('$path 必须是布尔值');
    }
    return value;
  }

  int _requiredInt(
    Map<dynamic, dynamic> parent,
    String key,
    String path,
  ) {
    final value = parent[key];
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw BeiAng8PanelResponseException('$path 必须是整数');
    }
    return value.toInt();
  }

  String _requiredString(
    Map<dynamic, dynamic> parent,
    String key,
    String path,
  ) {
    final value = parent[key];
    if (value is! String) {
      throw BeiAng8PanelResponseException('$path 必须是字符串');
    }
    return value;
  }

  List<_WifiNetwork> _wifiNetworks(Map<String, dynamic> wifi) {
    final value = wifi['scanResults'];
    if (value is! List || value.length > 64) {
      throw const BeiAng8PanelResponseException(
        'data.localDevice.wifi.scanResults 必须是最多 64 项的数组',
      );
    }
    final networksBySsid = <String, _WifiNetwork>{};
    for (final item in value) {
      if (item is! Map ||
          item['ssid'] is! String ||
          item['secured'] is! bool ||
          item['rssi'] is! int) {
        throw const BeiAng8PanelResponseException(
          'data.localDevice.wifi.scanResults 项格式无效',
        );
      }
      final ssid = item['ssid'] as String;
      if (ssid.trim().isEmpty || ssid.length > 64) {
        throw const BeiAng8PanelResponseException(
          'data.localDevice.wifi.scanResults 包含无效 SSID',
        );
      }
      final network = _WifiNetwork(
        ssid: ssid,
        secured: item['secured'] as bool,
        rssi: item['rssi'] as int,
      );
      final existing = networksBySsid[ssid];
      if (existing == null || network.rssi > existing.rssi) {
        networksBySsid[ssid] = network;
      }
    }
    final networks = networksBySsid.values.toList()
      ..sort((left, right) => right.rssi.compareTo(left.rssi));
    return List<_WifiNetwork>.unmodifiable(networks.take(20));
  }

  int _roundedNumber(
    Map<dynamic, dynamic> parent,
    String key,
    String path,
    num minimum,
    num maximum,
  ) {
    final value = parent[key];
    if (value is! num ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      throw BeiAng8PanelResponseException(
        '$path 必须是 $minimum..$maximum 的数值',
      );
    }
    return value.round();
  }

  List<Map<String, dynamic>> _faultItems(Map<String, dynamic> faults) {
    final active = faults['active'];
    if (active is! List) {
      throw const BeiAng8PanelResponseException(
        'data.protocol.faults.active 必须是数组',
      );
    }
    final result = <Map<String, dynamic>>[];
    for (final item in active) {
      if (item is! Map || item['bit'] is! num || item['name'] is! String) {
        throw const BeiAng8PanelResponseException(
          'data.protocol.faults.active 项格式无效',
        );
      }
      final bit = (item['bit'] as num).toInt();
      final name = item['name'] as String;
      final title = _faultTitles[name];
      if (title == null || !_confirmedFaultBits.contains(bit)) {
        throw BeiAng8PanelResponseException(
          '后端返回了未确认故障字段: bit=$bit, name=$name',
        );
      }
      result.add(<String, dynamic>{
        'id': '4cp-fault-$bit',
        'title': title,
        'description': '4CP 设备故障（离散输入 bit $bit）',
        // 协议只提供当前故障位，没有可信发生时间；不使用板端系统时间猜测。
        'date': '----/--/--',
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _notificationItems(
    Map<String, dynamic> notifications,
  ) {
    final active = notifications['active'];
    if (active is! List) {
      throw const BeiAng8PanelResponseException(
        'data.protocol.notifications.active 必须是数组',
      );
    }
    final result = <Map<String, dynamic>>[];
    for (final item in active) {
      if (item is! Map ||
          item['address'] is! num ||
          item['name'] is! String ||
          item['remainingHours'] is! num) {
        throw const BeiAng8PanelResponseException(
          'data.protocol.notifications.active 项格式无效',
        );
      }
      final address = (item['address'] as num).toInt();
      final name = item['name'] as String;
      final remainingHours = (item['remainingHours'] as num).toInt();
      final title = _notificationTitles[name];
      if (title == null || !_confirmedNotificationAddresses.contains(address)) {
        throw BeiAng8PanelResponseException(
          '后端返回了未确认通知字段: address=$address, name=$name',
        );
      }
      result.add(<String, dynamic>{
        'id': '4cp-notice-$address',
        'title': title,
        'description': '剩余 $remainingHours 小时，请安排维护',
        'date': '----/--/--',
      });
    }
    return result;
  }

  static const Set<int> _confirmedFaultBits = <int>{
    64,
    65,
    66,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
  };

  static const Map<String, String> _faultTitles = <String, String>{
    'freshAirFanAbnormal': '新风机异常',
    'exhaustFanAbnormal': '排风机异常',
    'boostFanAbnormal': '增压风机异常',
    'humidifierCommunicationLost': '加湿机通信失联',
    'humidifierInletFloatAlarm': '加湿进水槽浮子警报',
    'humidifierDrainFloatAlarm': '加湿排水槽浮子警报',
    'humidifierDrainFloatNotFalling': '加湿排水后浮子不下降',
    'humidifierInletWaterShortage': '加湿进水槽缺水',
    'humidifierAuxHeat1Protection': '加湿电辅热1保护',
    'humidifierAuxHeat2Protection': '加湿电辅热2保护',
    'humidifierInletFloatAbnormal': '加湿进水槽浮子异常',
    'humidifierDrainFloatAbnormal': '加湿排水槽浮子异常',
  };

  static const Set<int> _confirmedNotificationAddresses = <int>{
    0x1031,
    0x1032,
    0x1033,
    0x1034,
    0x1035,
  };

  static const Map<String, String> _notificationTitles = <String, String>{
    'filter1Maintenance': '滤网1维护提醒',
    'filter2Maintenance': '滤网2维护提醒',
    'filter3Maintenance': '滤网3维护提醒',
    'humidityModuleMaintenance': '调湿模块维护提醒',
    'iefCleaning': 'IEF 清洗提醒',
  };
}
