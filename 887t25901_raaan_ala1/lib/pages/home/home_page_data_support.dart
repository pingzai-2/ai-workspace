part of 'home_page.dart';

extension _HomePageDataSupport on _HomePageState {
  DashboardData _withConfirmedSettings(
    DashboardData runtimeData,
    DashboardData confirmedSettings,
  ) {
    return runtimeData.copyWith(
      allDevicesOn: confirmedSettings.allDevicesOn,
      leaveHomeModeEnabled: confirmedSettings.leaveHomeModeEnabled,
      homeFloorSelection: confirmedSettings.homeFloorSelection,
      timeFormat: confirmedSettings.timeFormat,
      dateYear: confirmedSettings.dateYear,
      dateMonth: confirmedSettings.dateMonth,
      dateDay: confirmedSettings.dateDay,
      clockHour: confirmedSettings.clockHour,
      clockMinute: confirmedSettings.clockMinute,
      clockSecond: confirmedSettings.clockSecond,
      languageCode: confirmedSettings.languageCode,
      screenBrightnessPercent: confirmedSettings.screenBrightnessPercent,
      priorityMetric: confirmedSettings.priorityMetric,
      aqiIndicatorEnabled: confirmedSettings.aqiIndicatorEnabled,
      indicatorLightBrightness:
          confirmedSettings.indicatorLightBrightness,
      presenceRadarEnabled: confirmedSettings.presenceRadarEnabled,
      screenOffSeconds: confirmedSettings.screenOffSeconds,
      airQualityAutoDetectionEnabled:
          confirmedSettings.airQualityAutoDetectionEnabled,
      wifiEnabled: confirmedSettings.wifiEnabled,
      wifiSsid: confirmedSettings.wifiSsid,
      savedWifiNetworks: confirmedSettings.savedWifiNetworks,
      timerEnabled: confirmedSettings.timerEnabled,
      timerStartMinutes: confirmedSettings.timerStartMinutes,
      timerEndMinutes: confirmedSettings.timerEndMinutes,
      timerRepeatDays: confirmedSettings.timerRepeatDays,
      manualAirConditioners: confirmedSettings.manualAirConditioners,
      manualFloorHeatSettings: confirmedSettings.manualFloorHeatSettings,
      manualFreshAirMode: confirmedSettings.manualFreshAirMode,
      manualFreshAirFanLevel: confirmedSettings.manualFreshAirFanLevel,
      manualFreshAirTimerEnabled: confirmedSettings.manualFreshAirTimerEnabled,
      manualFreshAirTimerStartMinutes:
          confirmedSettings.manualFreshAirTimerStartMinutes,
      manualFreshAirTimerEndMinutes:
          confirmedSettings.manualFreshAirTimerEndMinutes,
      manualFreshAirTimerRepeat: confirmedSettings.manualFreshAirTimerRepeat,
      manualHumidifierSetpointPercent:
          confirmedSettings.manualHumidifierSetpointPercent,
      manualHumidifierTimerEnabled:
          confirmedSettings.manualHumidifierTimerEnabled,
      manualHumidifierTimerStartMinutes:
          confirmedSettings.manualHumidifierTimerStartMinutes,
      manualHumidifierTimerEndMinutes:
          confirmedSettings.manualHumidifierTimerEndMinutes,
      manualHumidifierTimerRepeat:
          confirmedSettings.manualHumidifierTimerRepeat,
      manualPureDuration: confirmedSettings.manualPureDuration,
      smartModes: confirmedSettings.smartModes,
      filter1RemainingDays: confirmedSettings.filter1RemainingDays,
      filter2RemainingDays: confirmedSettings.filter2RemainingDays,
      filter3RemainingDays: confirmedSettings.filter3RemainingDays,
      airConditionerEnabled: confirmedSettings.airConditionerEnabled,
      floorHeatEnabled: confirmedSettings.floorHeatEnabled,
      freshAirEnabled: confirmedSettings.freshAirEnabled,
      humidifierEnabled: confirmedSettings.humidifierEnabled,
      pureEnabled: confirmedSettings.pureEnabled,
    );
  }

  /// 把统一业务快照按页面依赖定向发布。
  ///
  /// 新增 DashboardData 字段时，不能在这里随意增加“全页刷新”。必须先去
  /// DashboardPageRefreshPolicy 判断字段影响哪些页面，并把它加入对应刷新签名和测试。
  /// 否则会重新退化成任意字段变化都重建整屏，或出现字段已读入但页面不刷新的问题。
  void _publishPageSnapshots(
    DashboardData? previous,
    DashboardData next, {
    bool force = false,
  }) {
    void publish(
      DashboardPageScope scope,
      ValueNotifier<DashboardData?> notifier,
    ) {
      if (force ||
          previous == null ||
          DashboardPageRefreshPolicy.shouldRefresh(scope, previous, next)) {
        notifier.value = next;
      }
    }

    publish(DashboardPageScope.home, _homePageData);
    publish(DashboardPageScope.smart, _smartPageData);
    publish(DashboardPageScope.manual, _manualPageData);
    publish(DashboardPageScope.history, _historyPageData);
    publish(DashboardPageScope.settings, _settingsPageData);
    publish(DashboardPageScope.idle, _idlePageData);
    publish(DashboardPageScope.alerts, _dialogData);

    // 全局提示层独立于所有页面，只在后端链路三态变化时重建。
    if (force ||
        previous == null ||
        previous.backendDataStatus != next.backendDataStatus) {
      _backendStatusOverlayData.value = next;
    }
  }

  Future<void> _onLeaveHome() async {
    if (_data?.availableDeviceTypes.isEmpty ?? true) {
      return;
    }
    await _commitControl('leave-home', (current) {
      final available = current.availableDeviceTypes.toSet();
      final hasFreshAir = available.contains('fresh_air');
      return current.copyWith(
        leaveHomeModeEnabled: true,
        allDevicesOn: hasFreshAir,
        airConditionerEnabled: available.contains('air_conditioner')
            ? false
            : current.airConditionerEnabled,
        floorHeatEnabled:
            available.contains('floor_heat') ? false : current.floorHeatEnabled,
        freshAirEnabled: hasFreshAir ? true : current.freshAirEnabled,
        humidifierEnabled: available.contains('humidifier')
            ? false
            : current.humidifierEnabled,
        pureEnabled: available.contains('pure') ? false : current.pureEnabled,
      );
    }, submitControl: _storage.setLeaveHome);
  }

  Future<void> _showNotificationCenter() async {
    if (_lifecycleDisposing || !mounted || _runtimeAlertDialogVisible) {
      return;
    }
    setState(() => _runtimeAlertDialogVisible = true);
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => _RuntimeAlertDialogLayer(
          dataListenable: _dialogData,
          type: _RuntimeAlertDialogType.notification,
        ),
      );
    } finally {
      if (mounted) setState(() => _runtimeAlertDialogVisible = false);
    }
  }

  Future<void> _showFaultCenter() async {
    if (_lifecycleDisposing || !mounted || _runtimeAlertDialogVisible) {
      return;
    }
    setState(() => _runtimeAlertDialogVisible = true);
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => _RuntimeAlertDialogLayer(
          dataListenable: _dialogData,
          type: _RuntimeAlertDialogType.fault,
        ),
      );
    } finally {
      if (mounted) setState(() => _runtimeAlertDialogVisible = false);
    }
  }
}
