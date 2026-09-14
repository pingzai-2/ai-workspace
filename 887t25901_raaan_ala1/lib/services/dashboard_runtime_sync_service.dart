import 'dart:async';

import 'app_logger.dart';
import 'beiang8panel_api.dart';
import '../models/dashboard_data.dart';
import '../models/history_trend.dart';
import 'runtime_sync/dashboard_read_table.dart';
import 'runtime_sync/dashboard_task.dart';
import 'runtime_sync/dashboard_write_table.dart';

/// 任务 A：快速、顺序地读取外部数据并形成字段补丁。
///
/// 文件读取、Schema 校验、完整 JSON 生成和原子替换属于任务 B，由
/// DashboardStorage 在所有读取函数退出后统一执行一次。
/// 扩展约束：每个读取函数只做一次快速外部读取并返回字段补丁，不读写 JSON、
/// 不更新 UI，也不在函数内部创建周期任务。
class DashboardRuntimeSyncService {
  DashboardRuntimeSyncService({BeiAng8PanelApi? api}) {
    final resolvedApi = api ?? BeiAng8PanelHttpApi();
    _readTable = DashboardRuntimeReadTable(resolvedApi);
    _writeTable = DashboardRuntimeWriteTable(resolvedApi);
  }

  late final DashboardRuntimeReadTable _readTable;
  late final DashboardRuntimeWriteTable _writeTable;
  final Map<String, dynamic> _pendingOfflineRuntimePatch = <String, dynamic>{};
  final Map<String, HistoryTrendSnapshot> _pendingHistorySnapshots =
      <String, HistoryTrendSnapshot>{};
  final Set<String> _failedReadTasks = <String>{};
  final Set<String> _failedHistoryRanges = <String>{};
  bool _historyReadInFlight = false;

  List<String> get readTaskNames => List<String>.unmodifiable(
        _readTable.entries.map((task) => task.name),
      );

  List<String> get writeTaskNames => List<String>.unmodifiable(
        _writeTable.entries.map((task) => task.name),
      );

  Future<bool> setFreshAirPower(bool enabled) {
    return _executeWriteTask<bool>(_writeTable.freshAirPower, enabled);
  }

  Future<bool> setHumidifierPower(bool enabled) {
    return _executeWriteTask<bool>(_writeTable.humidifierPower, enabled);
  }

  Future<bool> setPurePower(bool enabled) {
    return _executeWriteTask<bool>(_writeTable.purePower, enabled);
  }

  Future<bool> setLeaveHome() => _readTable.api.setLeaveHome();

  Future<bool> setFreshAirMode(String mode) {
    return _writeDirectly(() => _readTable.api.setFreshAirMode(mode));
  }

  Future<bool> setFreshAirFanLevel(String level) {
    return _writeDirectly(() => _readTable.api.setFreshAirFanLevel(level));
  }

  Future<bool> setTargetHumidity(int percent) {
    return _writeDirectly(() => _readTable.api.setTargetHumidity(percent));
  }

  Future<bool> setScreenBrightnessPercent(int percent) {
    return _writeDirectly(
        () => _readTable.api.setScreenBrightnessPercent(percent));
  }

  Future<bool> setScreenSleep(bool sleep) {
    return _writeDirectly(() => _readTable.api.setScreenSleep(sleep));
  }

  Future<bool> setAqiIndicatorEnabled(bool enabled) {
    return _writeDirectly(() => _readTable.api.setAqiIndicatorEnabled(enabled));
  }

  Future<bool> setRadarEnabled(bool enabled) {
    return _writeDirectly(() => _readTable.api.setRadarEnabled(enabled));
  }

  Future<bool> setWifiEnabled(bool enabled) {
    return _writeDirectly(() => _readTable.api.setWifiEnabled(enabled));
  }

  Future<bool> scanWifi() => _writeDirectly(_readTable.api.scanWifi);

  Future<bool> connectWifi(String ssid, String password) {
    return _writeDirectly(() => _readTable.api.connectWifi(ssid, password));
  }

  Future<bool> disconnectWifi() =>
      _writeDirectly(_readTable.api.disconnectWifi);

  /// 读取后端提供的可选设备存在性。接口不可用时回退到本地设备配置，
  /// 因此该信息不参与后端三态；由存储层合并后写入 runtime JSON。
  Future<BeiAngDevicePresence?> readDevicePresence() async {
    try {
      return await _readTable.api.readDevicePresence();
    } on Object {
      return null;
    }
  }

  /// 按独立历史脉搏发起一次 day/week/month 读取。
  ///
  /// 返回 false 表示已有历史请求进行中，本次触发被跳过；调用方不应排队。
  /// 响应只暂存到下一次统一 runtime 刷新，由 [collectRuntimePatch] 合并并落盘，
  /// 避免历史请求与实时快照同时写 runtime JSON。
  bool requestHistoryRefresh() {
    if (_historyReadInFlight) {
      return false;
    }
    _historyReadInFlight = true;
    unawaited(_readHistorySnapshots());
    return true;
  }

  Future<void> _readHistorySnapshots() async {
    try {
      final snapshots = await Future.wait<
          HistoryTrendSnapshot?>(<Future<HistoryTrendSnapshot?>>[
        _readHistoryRange('day'),
        _readHistoryRange('week'),
        _readHistoryRange('month'),
      ]);
      for (final snapshot in snapshots) {
        if (snapshot != null) {
          _pendingHistorySnapshots[snapshot.range] = snapshot;
        }
      }
    } finally {
      _historyReadInFlight = false;
    }
  }

  Future<HistoryTrendSnapshot?> _readHistoryRange(String range) async {
    try {
      final snapshot = await _readTable.api.readHistoryTrend(range);
      if (snapshot != null && _failedHistoryRanges.remove(range)) {
        AppLogger.instance.i('历史趋势读取已恢复：$range', tag: 'HistorySync');
      }
      return snapshot;
    } on Object catch (error) {
      if (_failedHistoryRanges.add(range)) {
        AppLogger.instance.e(
          '历史趋势读取失败，保留已有数据：$range',
          tag: 'HistorySync',
          error: error,
        );
      }
      return null;
    }
  }

  /// 后端不可达且 settings 已完整保存后，登记一次前端离线反馈。
  ///
  /// 后端可达但设备数据陈旧时不得调用；那种情况必须保持最后一次设备值。
  void recordFreshAirPowerFeedback(bool enabled) {
    _recordOfflineFeedback(_writeTable.freshAirPower, enabled);
  }

  void recordHumidifierPowerFeedback(bool enabled) {
    _recordOfflineFeedback(_writeTable.humidifierPower, enabled);
  }

  void recordPurePowerFeedback(bool enabled) {
    _recordOfflineFeedback(_writeTable.purePower, enabled);
  }

  void _recordOfflineFeedback<T>(
    DashboardRuntimeWriteTask<T> task,
    T value,
  ) {
    _pendingOfflineRuntimePatch[task.runtimeField.jsonKey] = value;
  }

  Future<bool> _executeWriteTask<T>(
    DashboardRuntimeWriteTask<T> task,
    T value,
  ) async {
    final runtimeKey = task.runtimeField.jsonKey;
    try {
      final accepted = await task.write(value);
      if (!accepted) {
        _pendingOfflineRuntimePatch.remove(runtimeKey);
      }
      return accepted;
    } on BeiAng8PanelUnavailableException {
      // 由上层在 settings 保存并读回成功后登记离线反馈。
      rethrow;
    } on Object {
      // 后端已明确响应但内容无效，不能保留同字段的旧离线意向。
      _pendingOfflineRuntimePatch.remove(runtimeKey);
      rethrow;
    }
  }

  Future<bool> _writeDirectly(Future<bool> Function() write) => write();

  Future<Map<String, dynamic>> collectRuntimePatch([
    DashboardData? current,
  ]) async {
    // 只消费进入本轮前已经登记的离线反馈；刷新期间的新点击留到下一轮。
    final pendingOfflinePatch =
        Map<String, dynamic>.from(_pendingOfflineRuntimePatch);
    _pendingOfflineRuntimePatch.clear();
    final externalPatch = <String, dynamic>{};
    if (current != null && _pendingHistorySnapshots.isNotEmpty) {
      final snapshots = Map<String, HistoryTrendSnapshot>.from(
        _pendingHistorySnapshots,
      );
      _pendingHistorySnapshots.clear();
      for (final snapshot in snapshots.values) {
        externalPatch.addAll(HistoryTrendMapper.merge(current, snapshot));
      }
    }
    for (final task in _readTable.entries) {
      try {
        final patch = await task.read();
        externalPatch.addAll(patch);
        if (_failedReadTasks.remove(task.name)) {
          AppLogger.instance
              .i('BeiAng8Panel 读取已恢复：${task.name}', tag: 'RuntimeSync');
        }
      } on Object catch (error) {
        externalPatch.putIfAbsent(
          'backendDataStatus',
          () => error is BeiAng8PanelUnavailableException
              ? 'unreachable'
              : 'stale',
        );
        if (_failedReadTasks.add(task.name)) {
          AppLogger.instance.e(
            'BeiAng8Panel 读取失败，保留本地 runtime：${task.name}',
            tag: 'RuntimeSync',
            error: error,
          );
        }
      }
    }

    // 只有后端进程不可达时才退化到前端本地反馈。后端可达但 485 数据
    // 陈旧时保持最后一次设备值，绝不能把本地意向冒充为设备实际状态。
    if (externalPatch['backendDataStatus'] == 'unreachable') {
      for (final entry in pendingOfflinePatch.entries) {
        externalPatch.putIfAbsent(entry.key, () => entry.value);
      }
    }

    return externalPatch;
  }
}
