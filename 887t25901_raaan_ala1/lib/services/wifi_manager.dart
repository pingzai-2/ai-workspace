import '../models/dashboard_data.dart';
import 'dashboard_storage.dart';

class DashboardWifiAction {
  const DashboardWifiAction(
    this.result, {
    this.proposedSettings,
    this.awaitingConfirmation = false,
  });

  final DashboardControlResult result;
  final DashboardData? proposedSettings;
  final bool awaitingConfirmation;

  bool get accepted => result == DashboardControlResult.success;
}

/// WiFi 的页面无关控制状态机。
///
/// 后端在线时，HTTP 成功只表示命令已接受；密码必须等聚合运行快照确认
/// 同一 SSID 已连接后才写入 settings。后端不可达时才启用本地联调规则。
class DashboardWifiManager {
  DashboardWifiManager(
    this._repository, {
    this.debugConnectionDelay = const Duration(milliseconds: 3000),
    this.connectTimeout = const Duration(seconds: 20),
  });

  static const String debugPassword = '666666';

  final DashboardDataRepository _repository;
  final Duration debugConnectionDelay;
  final Duration connectTimeout;
  String? _pendingSsid;
  String? _pendingPassword;
  bool _pendingSawConnecting = false;
  final Stopwatch _pendingStopwatch = Stopwatch();
  bool? _backendWasReachable;
  bool _savedSwitchSynchronized = false;
  String? _offlineTestSsid;
  String _offlineTestIpAddress = '';
  bool _manualConnectActive = false;

  String? get pendingSsid => _pendingSsid;

  /// 只暴露由用户点选网络产生的待确认连接。
  String? get manualPendingSsid => _manualConnectActive ? _pendingSsid : null;

  /// App 启动时先落实持久化的关闭目标。
  ///
  /// 开启目标只等待真实运行快照，不使用保存的密码主动连接；关闭目标则
  /// 无论后端是否可达，都先把本地测试连接置为断开，后端可用时再补一次
  /// 真实关闭命令。
  Future<DashboardData> applyStartupSwitchState(DashboardData current) async {
    if (current.wifiEnabled) {
      return current;
    }

    _clearPending();
    _clearOfflineTestConnection();

    if (current.backendReachable && current.effectiveWifiState.available) {
      await _repository.setWifiEnabled(false);
      _savedSwitchSynchronized = true;
      _backendWasReachable = true;
    } else {
      _backendWasReachable = current.backendReachable;
    }

    return _repository.save(
      current.copyWith(
        clearWifiSsid: true,
        wifiConnected: false,
        wifiIpAddress: '',
        clearWifiConnectedSsid: true,
      ),
    );
  }

  Future<DashboardWifiAction> setEnabled(
    DashboardData current,
    bool enabled,
  ) async {
    // 开关只表达开启或关闭，不根据保存凭据补发连接命令。
    _clearPending();
    if (!current.backendReachable) {
      if (!enabled) {
        _clearOfflineTestConnection();
      }
      return DashboardWifiAction(
        DashboardControlResult.success,
        proposedSettings: enabled
            ? current.copyWith(wifiEnabled: true)
            : current.copyWith(
                wifiEnabled: false,
                clearWifiSsid: true,
                wifiConnected: false,
                wifiIpAddress: '',
                clearWifiConnectedSsid: true,
              ),
      );
    }

    final result = await _repository.setWifiEnabled(enabled);
    _savedSwitchSynchronized = true;
    if (result != DashboardControlResult.success) {
      return DashboardWifiAction(result);
    }
    return DashboardWifiAction(
      result,
      proposedSettings: current.copyWith(wifiEnabled: enabled),
    );
  }

  Future<DashboardWifiAction> scan(DashboardData current) async {
    if (!current.backendReachable) {
      return const DashboardWifiAction(DashboardControlResult.success);
    }
    return DashboardWifiAction(await _repository.scanWifi());
  }

  Future<DashboardWifiAction> connect(
    DashboardData current,
    String ssid,
    String password,
  ) async {
    final normalizedSsid = ssid.trim();
    if (normalizedSsid.isEmpty) {
      return const DashboardWifiAction(DashboardControlResult.rejected);
    }
    if (_manualConnectActive) {
      return const DashboardWifiAction(DashboardControlResult.rejected);
    }

    final wifi = current.effectiveWifiState;
    if (current.backendReachable &&
        wifi.available &&
        wifi.connected &&
        wifi.ssid == normalizedSsid) {
      // 连接来源不属于当前前端事务时只展示实际状态，不能重复连接，也
      // 不能把用户刚输入的密码写入保存表。
      return const DashboardWifiAction(DashboardControlResult.success);
    }

    if (!current.backendReachable) {
      await Future<void>.delayed(debugConnectionDelay);
      final savedPassword = current.savedWifiPasswordFor(normalizedSsid);
      if (savedPassword == null && password != debugPassword) {
        return const DashboardWifiAction(DashboardControlResult.rejected);
      }
      // 离线联调和真实连接共用同一份凭据表。已保存的 SSID 不再校验
      // 联调密码，也不覆盖原密码；首次出现的 SSID 才要求 666666。
      final confirmedPassword = savedPassword ?? password;
      final fallbackIp = current.wifiIpAddress.isEmpty
          ? '192.168.1.100'
          : current.wifiIpAddress;
      _clearPending();
      _offlineTestSsid = normalizedSsid;
      _offlineTestIpAddress = fallbackIp;
      return DashboardWifiAction(
        DashboardControlResult.success,
        proposedSettings: current.copyWith(
          wifiEnabled: true,
          wifiSsid: normalizedSsid,
          wifiConnected: true,
          wifiIpAddress: fallbackIp,
          savedWifiNetworks: current.rememberSuccessfulWifi(
            normalizedSsid,
            confirmedPassword,
          ),
        ),
      );
    }

    _clearPending();
    _manualConnectActive = true;
    _clearOfflineTestConnection();
    final result = await _repository.connectWifi(normalizedSsid, password);
    if (result == DashboardControlResult.success) {
      _setPending(normalizedSsid, password);
    } else {
      _manualConnectActive = false;
    }
    return DashboardWifiAction(
      result,
      awaitingConfirmation: result == DashboardControlResult.success,
    );
  }

  Future<DashboardWifiAction> disconnect(DashboardData current) async {
    _clearPending();
    _clearOfflineTestConnection();
    if (!current.backendReachable) {
      return DashboardWifiAction(
        DashboardControlResult.success,
        proposedSettings: current.copyWith(
          clearWifiSsid: true,
          wifiConnected: false,
          wifiIpAddress: '',
          clearWifiConnectedSsid: true,
        ),
      );
    }

    // 这次断开本身已经证明后端处于当前在线周期，避免下一份快照再次
    // 被当作恢复边沿而重复同步开关。
    _backendWasReachable = true;
    final result = await _repository.disconnectWifi();
    return DashboardWifiAction(result);
  }

  /// 统一处理后端通断和用户主动连接结果确认。
  ///
  /// 后端连接状态只用于展示，不根据保存凭据主动连接。后端转为不可达
  /// 时只清空一次本地连接态；之后用户主动建立的离线测试连接保持到本次
  /// App 会话结束、主动断开或后端恢复，不被运行快照覆盖。
  Future<DashboardData> reconcileRuntime(DashboardData runtime) async {
    if (!runtime.backendReachable) {
      return _reconcileOfflineRuntime(runtime);
    }

    final wifi = runtime.effectiveWifiState;

    final backendJustBecameReachable = _backendWasReachable != true;
    _backendWasReachable = true;
    _clearOfflineTestConnection();

    final ssid = _pendingSsid;
    final password = _pendingPassword;
    if (ssid != null && password != null) {
      // 连接事务共用一个总期限。即使过期后才读到成功快照，也不能再把
      // 本轮输入当成已确认凭据落盘。
      if (_pendingStopwatch.elapsed >= connectTimeout) {
        _clearPending();
        return runtime;
      }

      if (wifi.available &&
          wifi.operation == 'connecting' &&
          wifi.operationSsid == ssid) {
        _pendingSawConnecting = true;
        // connecting 与 connected 必须来自前后两份完整快照，不能用同一
        // 份内部矛盾的快照同时满足两个阶段。
        return runtime;
      }

      if (wifi.operation == 'failed' && wifi.operationSsid == ssid) {
        _clearPending();
        return runtime;
      }

      if (wifi.available && wifi.connected && wifi.ssid == ssid) {
        final canSavePassword = _pendingSawConnecting;
        _clearPending();
        if (!canSavePassword) {
          return runtime;
        }
        return _repository.save(
          runtime.copyWith(
            wifiSsid: ssid,
            savedWifiNetworks: runtime.rememberSuccessfulWifi(ssid, password),
          ),
        );
      }

      // 后端正常情况下会在同一事务的 20 秒内发布 connected/failed。
      // 前端仍使用单调计时做兜底，避免异常后端让全局状态永久停在
      // connecting。页面退出不会清除此事务，后台仍可继续完成连接。
      return runtime;
    }

    if (!wifi.available) {
      return runtime;
    }

    if (backendJustBecameReachable || !_savedSwitchSynchronized) {
      final enabledResult = await _repository.setWifiEnabled(
        runtime.wifiEnabled,
      );
      _savedSwitchSynchronized = true;
      if (enabledResult != DashboardControlResult.success ||
          !runtime.wifiEnabled) {
        return runtime;
      }
    }
    return runtime;
  }

  Future<DashboardData> _reconcileOfflineRuntime(
    DashboardData runtime,
  ) async {
    final backendJustBecameUnreachable = _backendWasReachable != false;
    _backendWasReachable = false;
    _savedSwitchSynchronized = false;
    _clearPending();

    if (backendJustBecameUnreachable) {
      _clearOfflineTestConnection();
      final disconnected = runtime.copyWith(
        clearWifiSsid: true,
        wifiConnected: false,
        wifiIpAddress: '',
        clearWifiConnectedSsid: true,
      );
      return _repository.save(disconnected);
    }

    final offlineSsid = _offlineTestSsid;
    if (offlineSsid != null) {
      return runtime.copyWith(
        wifiEnabled: true,
        wifiSsid: offlineSsid,
        wifiConnected: true,
        wifiIpAddress: _offlineTestIpAddress,
      );
    }

    return runtime.copyWith(
      clearWifiSsid: true,
      wifiConnected: false,
      wifiIpAddress: '',
      clearWifiConnectedSsid: true,
    );
  }

  void _clearOfflineTestConnection() {
    _offlineTestSsid = null;
    _offlineTestIpAddress = '';
  }

  void _clearPending() {
    _pendingSsid = null;
    _pendingPassword = null;
    _pendingSawConnecting = false;
    _manualConnectActive = false;
    _pendingStopwatch
      ..stop()
      ..reset();
  }

  void _setPending(String ssid, String password) {
    _pendingSsid = ssid;
    _pendingPassword = password;
    _pendingSawConnecting = false;
    _pendingStopwatch
      ..reset()
      ..start();
  }
}
