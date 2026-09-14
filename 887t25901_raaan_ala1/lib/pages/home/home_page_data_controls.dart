part of 'home_page.dart';

extension _HomePageDataControls on _HomePageState {
  Future<bool> _setHomeFloorSelection(String selection) {
    if (!DashboardData.supportedHomeFloorSelections.contains(selection)) {
      return Future<bool>.value(false);
    }
    return _commitSettingsChange(
      'home-floor-selection',
      (current) => current.copyWith(homeFloorSelection: selection),
    );
  }

  Future<void> _setPower(bool enabled) async {
    if (_data?.availableDeviceTypes.isEmpty ?? true) {
      return;
    }
    await _commitControl(
      'all-devices',
      (current) => current.copyWith(
        allDevicesOn: enabled,
        leaveHomeModeEnabled: false,
      ),
    );
  }

  Future<void> _setFreshAirPower(bool enabled) => _setDevicePower(
        controlKey: 'fresh-air',
        deviceType: 'fresh_air',
        enabled: enabled,
        isEnabled: (current) => current.freshAirEnabled,
        apply: (current, value) => current.copyWith(freshAirEnabled: value),
        submitControl: () => _storage.setFreshAirPower(enabled),
        onBackendUnreachable: () =>
            _storage.recordFreshAirPowerFeedback(enabled),
        afterCommitted: _refreshAfterDeviceControl,
      );

  Future<void> _setFloorHeatPower(bool enabled) => _setDevicePower(
        controlKey: 'floor-heat',
        deviceType: 'floor_heat',
        enabled: enabled,
        isEnabled: (current) => current.floorHeatEnabled,
        apply: (current, value) => current.copyWith(floorHeatEnabled: value),
      );

  Future<void> _setAirConditionerPower(bool enabled) => _setDevicePower(
        controlKey: 'air-conditioner',
        deviceType: 'air_conditioner',
        enabled: enabled,
        isEnabled: (current) => current.airConditionerEnabled,
        apply: (current, value) =>
            current.copyWith(airConditionerEnabled: value),
      );

  Future<void> _setHumidifierPower(bool enabled) => _setDevicePower(
        controlKey: 'humidifier',
        deviceType: 'humidifier',
        enabled: enabled,
        isEnabled: (current) => current.humidifierEnabled,
        apply: (current, value) => current.copyWith(humidifierEnabled: value),
        submitControl: () => _storage.setHumidifierPower(enabled),
        onBackendUnreachable: () =>
            _storage.recordHumidifierPowerFeedback(enabled),
        afterCommitted: _refreshAfterDeviceControl,
      );

  Future<void> _setPurePower(bool enabled) async {
    await _setDevicePower(
      controlKey: 'pure',
      deviceType: 'pure',
      enabled: enabled,
      isEnabled: (current) => current.pureEnabled,
      apply: (current, value) => current.copyWith(pureEnabled: value),
      submitControl: () => _storage.setPurePower(enabled),
      onBackendUnreachable: () => _storage.recordPurePowerFeedback(enabled),
      afterCommitted: _refreshAfterDeviceControl,
    );
  }

  void _refreshAfterDeviceControl() {
    if (_data?.backendDataStatus == 'unreachable') {
      // 后端不存在时使用前端本地反馈，没有 Modbus 写后读回可等。
      unawaited(_refreshRuntime(queueIfBusy: true));
      return;
    }
    _scheduleWriteReadbackRefresh();
  }

  Future<void> _setFreshAirMode(String mode) async {
    final committed = await _commitControl(
      'fresh-air-mode',
      (current) => current.copyWith(manualFreshAirMode: mode),
      submitControl: () => _storage.setFreshAirMode(mode),
    );
    if (committed) _scheduleWriteReadbackRefresh();
  }

  Future<void> _setFreshAirFanLevel(String level) async {
    final committed = await _commitControl(
      'fresh-air-fan-level',
      (current) => current.copyWith(manualFreshAirFanLevel: level),
      submitControl: () => _storage.setFreshAirFanLevel(level),
    );
    if (committed) _scheduleWriteReadbackRefresh();
  }

  Future<void> _setTargetHumidity(int percent) async {
    final committed = await _commitControl(
      'target-humidity',
      (current) => current.copyWith(manualHumidifierSetpointPercent: percent),
      submitControl: () => _storage.setTargetHumidity(percent),
    );
    if (committed) _scheduleWriteReadbackRefresh();
  }

  Future<void> _setDevicePower({
    required String controlKey,
    required String deviceType,
    required bool enabled,
    required bool Function(DashboardData current) isEnabled,
    required DashboardData Function(DashboardData current, bool enabled) apply,
    Future<DashboardControlResult> Function()? submitControl,
    void Function()? onBackendUnreachable,
    VoidCallback? afterCommitted,
  }) async {
    final committed = await _commitControl(controlKey, (current) {
      if (!current.availableDeviceTypes.contains(deviceType)) {
        return current;
      }
      if (enabled) {
        if (current.allDevicesOn) {
          return apply(current, true);
        }

        // 一键关闭只负责暂时关断并保留组合，不能成为单设备总闸。
        // 用户在全关状态下手动开启某台设备时，以这次操作建立新组合：
        // 先清掉旧组合，再只开启本次点击的设备。
        return apply(
          current.copyWith(
            allDevicesOn: true,
            airConditionerEnabled: false,
            floorHeatEnabled: false,
            freshAirEnabled: false,
            humidifierEnabled: false,
            pureEnabled: false,
          ),
          true,
        );
      }

      final enabledByType = <String, bool>{
        'air_conditioner': current.airConditionerEnabled,
        'floor_heat': current.floorHeatEnabled,
        'fresh_air': current.freshAirEnabled,
        'humidifier': current.humidifierEnabled,
        'pure': current.pureEnabled,
      };
      final enabledDeviceCount = current.availableDeviceTypes
          .where((type) => enabledByType[type] ?? false)
          .length;

      // 手动关闭最后一台时，不抹掉最后有效组合：用总开关关断显示，
      // 保留该独立状态，下一次一键开启即可恢复最后一台。
      if (isEnabled(current) && enabledDeviceCount == 1) {
        return current.copyWith(allDevicesOn: false);
      }
      return apply(current, false);
    },
        submitControl: submitControl,
        onBackendUnreachable: onBackendUnreachable);
    if (committed) {
      afterCommitted?.call();
    }
  }

  Future<bool> _commitControl(
    String controlKey,
    DashboardData Function(DashboardData current) change, {
    Future<DashboardControlResult> Function()? submitControl,
    void Function()? onBackendUnreachable,
  }) {
    return _commitSettingsChange(
      controlKey,
      change,
      submitControl: submitControl,
      onBackendUnreachable: onBackendUnreachable,
    );
  }

  Future<bool> _commitSettingsChange(
    String controlKey,
    DashboardData Function(DashboardData current) change, {
    Future<DashboardControlResult> Function()? submitControl,
    void Function()? onBackendUnreachable,
  }) async {
    final current = _data;
    if (_lifecycleDisposing ||
        !mounted ||
        current == null ||
        _engineeringModeActive ||
        _settingsWriteInFlight ||
        _pendingControls.contains(controlKey)) {
      return false;
    }

    _settingsWriteInFlight = true;

    // 系统设置页的开关已经在控件自身维护“处理中”状态。
    // 这里不能为了记录一次写入而刷新 HomePage 根节点，否则设置页的
    // StatusBar、侧栏和面板会一起重新布局，表现为整页抖动。主页设备
    // 控制仍需要根节点刷新，以便把 busy 状态传给对应卡片。
    final notifyRootPending = controlKey != 'system-settings';
    _pendingControls.add(controlKey);
    if (notifyRootPending && mounted) {
      setState(() {});
    }
    try {
      // 顶部状态栏与所有控制共用同一个后端可达状态。轮询已经确认
      // 后端不可达时，不再让每个控制请求各自重复判断或误报“拒绝”。
      final controlResult = submitControl == null
          ? null
          : current.backendDataStatus == 'unreachable'
              ? DashboardControlResult.unreachable
              : await submitControl();
      if (controlResult == DashboardControlResult.rejected) {
        AppLogger.instance.w(
          '主页设备控制被后端拒绝，状态保持不变：$controlKey',
          tag: 'HomeControls',
        );
        return false;
      }
      final backendUnreachable =
          controlResult == DashboardControlResult.unreachable;
      if (backendUnreachable) {
        AppLogger.instance.w(
          'BeiAng8Panel 不可达，等待轮询消费本地状态：$controlKey',
          tag: 'HomeControls',
        );
      }

      final saved = await _storage.save(change(current));
      if (backendUnreachable) {
        onBackendUnreachable?.call();
      }
      final latest = _data;
      if (mounted) {
        final next =
            latest == null ? saved : _withConfirmedSettings(latest, saved);
        final screenOffTimeChanged =
            latest?.screenOffSeconds != next.screenOffSeconds;
        _data = next;
        // 语言在设置页保存后走到这里：语言码变化时同步根 locale，
        // 整棵 widget 树随 MaterialApp 一起重建切换。
        if (latest?.languageCode != next.languageCode) {
          widget.localeController.value = localeFromLanguageCode(
            next.languageCode,
          );
        }
        _publishPageSnapshots(latest, next, force: latest == null);
        if (screenOffTimeChanged) {
          _restartIdleTimer();
        }
      }
      return true;
    } on Object catch (error) {
      AppLogger.instance.e(
        '主页控制保存失败，保留已确认状态：$controlKey',
        tag: 'HomeControls',
        error: error,
      );
      return false;
    } finally {
      _settingsWriteInFlight = false;
      _pendingControls.remove(controlKey);
      if (notifyRootPending && mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _savePersistentConfiguration(
    DashboardPersistentData next,
  ) async {
    if (_lifecycleDisposing ||
        !mounted ||
        !_engineeringModeActive ||
        _persistentWriteInFlight) {
      return false;
    }
    _persistentWriteInFlight = true;
    try {
      final saved = await _storage.savePersistent(next);
      if (mounted) {
        setState(() => _persistentData = saved);
      }
      return true;
    } on Object catch (error) {
      AppLogger.instance.e(
        '长期配置保存失败，保留上次确认配置',
        tag: 'HomeControls',
        error: error,
      );
      return false;
    } finally {
      _persistentWriteInFlight = false;
    }
  }
}

/// 主页显示仍使用一个聚合对象，但 settings 与 runtime 是两个独立分区。
/// 每次回调只用自己的分区更新，不通过时序或版本号互相协调。
