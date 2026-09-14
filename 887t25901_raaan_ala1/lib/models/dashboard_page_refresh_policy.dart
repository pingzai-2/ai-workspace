import 'dashboard_data.dart';

/// 两秒运行快照刷新时，可被独立通知重建的 UI 范围。
enum DashboardPageScope {
  home,
  smart,
  manual,
  history,
  settings,
  idle,
  alerts,
}

/// 判断一份新的 [DashboardData] 是否真正影响某个页面。
///
/// 维护规则（新增 DashboardData 字段时必须阅读）：
///
/// 1. 先判断新字段实际参与哪些页面的文字、图片、显隐、颜色、布局或交互状态。
/// 2. 把字段加入这些页面在 [_signature] 中的刷新签名；同一字段可以属于多个页面。
/// 3. 不要按字段来自 settings/runtime 哪个 JSON 来分类。刷新归属只看“哪个页面用了它”。
/// 4. 页面通过子组件或公共组件间接使用字段，也必须登记。例如各页状态栏间接使用
///    `timeFormat` 和生效中的 Wi-Fi 快照，所以两项出现在多个页面签名中。
/// 5. 同步补测试：相关字段变化应返回 true，无关字段变化应返回 false。
///
/// 如果只给 DashboardData 增加字段，却漏掉这里，JSON 会正常读入，业务层也能拿到新值，
/// 但依赖该字段的已显示页面不会收到两秒刷新通知。这不是轮询故障，而是刷新签名漏登记。
class DashboardPageRefreshPolicy {
  const DashboardPageRefreshPolicy._();

  static bool shouldRefresh(
    DashboardPageScope scope,
    DashboardData previous,
    DashboardData next,
  ) {
    return !_deepEquals(
      _signature(scope, previous),
      _signature(scope, next),
    );
  }

  /// 每个列表就是对应页面的“刷新签名”。只列实际影响该页面的字段。
  ///
  /// 复杂对象先转成普通 Map/List，再做值比较，避免 JSON 每次重新解析后仅因对象实例
  /// 不同而误判为页面变化。
  static List<Object?> _signature(
    DashboardPageScope scope,
    DashboardData data,
  ) {
    final statusBar = <Object?>[
      data.timeFormat,
      data.effectiveWifiState.connected,
    ];
    switch (scope) {
      case DashboardPageScope.home:
        return <Object?>[
          ...statusBar,
          data.areaName,
          data.outdoorTemperatureC,
          data.outdoorHumidityPercent,
          data.outdoorPm25,
          data.indoorPm25,
          data.indoorTemperatureC,
          data.indoorHumidityPercent,
          data.indoorCo2Ppm,
          data.indoorFormaldehydeMgM3,
          data.availableDeviceTypes,
          data.homeFloorLayeringEnabled,
          data.allDevicesOn,
          data.leaveHomeModeEnabled,
          data.homeFloorSelection,
          data.airConditionerEnabled,
          data.floorHeatEnabled,
          data.freshAirEnabled,
          data.humidifierEnabled,
          data.pureEnabled,
          data.smartModeRunning,
          data.manualModeRunning,
          data.freshAirRunning,
          data.humidifierRunning,
          data.pureRunning,
          data.freshAirModeActual,
          data.freshAirFanLevelActual,
          data.humidifierSetpointActualPercent,
          data.weatherCode,
          data.weatherTemperatureRange,
          data.notificationBellVisible,
          data.notifications.map((item) => item.toJson()).toList(),
          data.faults.map((item) => item.toJson()).toList(),
        ];
      case DashboardPageScope.smart:
        return <Object?>[
          ...statusBar,
          data.smartModes.map(
            (key, value) => MapEntry<String, Object?>(key, value.toJson()),
          ),
          data.smartAirConditionerMode,
          data.smartAirConditionerFanLevel,
          data.smartFreshAirMode,
          data.smartFreshAirFanLevel,
        ];
      case DashboardPageScope.manual:
        return <Object?>[
          ...statusBar,
          data.manualAirConditioners.map((item) => item.toJson()).toList(),
          data.manualFloorHeatSettings.map((item) => item.toJson()).toList(),
          data.manualFreshAirMode,
          data.manualFreshAirFanLevel,
          data.manualFreshAirTimerEnabled,
          data.manualFreshAirTimerStartMinutes,
          data.manualFreshAirTimerEndMinutes,
          data.manualFreshAirTimerRepeat,
          data.manualHumidifierSetpointPercent,
          data.manualHumidifierTimerEnabled,
          data.manualHumidifierTimerStartMinutes,
          data.manualHumidifierTimerEndMinutes,
          data.manualHumidifierTimerRepeat,
          data.manualPureDuration,
          data.allDevicesOn,
          data.airConditionerEnabled,
          data.floorHeatEnabled,
          data.freshAirEnabled,
          data.humidifierEnabled,
          data.pureEnabled,
          data.freshAirRunning,
          data.humidifierRunning,
          data.pureRunning,
          data.floorHeatControlMode,
          data.airConditionerZones.map((item) => item.toJson()).toList(),
          data.floorHeatZones.map((item) => item.toJson()).toList(),
        ];
      case DashboardPageScope.history:
        return <Object?>[
          ...statusBar,
          data.dailyTemperatureIndoorC,
          data.dailyTemperatureOutdoorC,
          data.weeklyTemperatureIndoorC,
          data.weeklyTemperatureOutdoorC,
          data.monthlyTemperatureIndoorC,
          data.monthlyTemperatureOutdoorC,
          data.monthlyTrendYear,
          data.monthlyTrendMonth,
          data.dailyHumidityIndoorPercent,
          data.dailyHumidityOutdoorPercent,
          data.weeklyHumidityIndoorPercent,
          data.weeklyHumidityOutdoorPercent,
          data.monthlyHumidityIndoorPercent,
          data.monthlyHumidityOutdoorPercent,
          data.dailyPm25Indoor,
          data.dailyPm25Outdoor,
          data.weeklyPm25Indoor,
          data.weeklyPm25Outdoor,
          data.monthlyPm25Indoor,
          data.monthlyPm25Outdoor,
          data.dailyCo2Ppm,
          data.weeklyCo2Ppm,
          data.monthlyCo2Ppm,
        ];
      case DashboardPageScope.settings:
        return <Object?>[
          ...statusBar,
          data.dateYear,
          data.dateMonth,
          data.dateDay,
          data.clockHour,
          data.clockMinute,
          data.clockSecond,
          data.languageCode,
          data.effectiveScreenBrightnessPercent,
          data.priorityMetric,
          data.effectiveAqiIndicatorEnabled,
          data.indicatorLightBrightness,
          data.presenceRadarEnabled,
          data.screenOffSeconds,
          data.airQualityAutoDetectionEnabled,
          data.effectiveWifiState.signature,
          data.savedWifiNetworks.map((item) => item.toJson()).toList(),
          data.timerEnabled,
          data.timerStartMinutes,
          data.timerEndMinutes,
          data.timerRepeatDays,
          data.filter1RemainingDays,
          data.filter2RemainingDays,
          data.filter3RemainingDays,
          data.versionUpdateStatus,
        ];
      case DashboardPageScope.idle:
        return <Object?>[
          data.timeFormat,
          data.effectiveWifiState.connected,
          data.indoorPm25,
          data.indoorTemperatureC,
          data.indoorHumidityPercent,
          data.indoorCo2Ppm,
          data.outdoorPm25,
          data.outdoorTemperatureC,
          data.outdoorHumidityPercent,
          data.weatherCode,
          data.weatherTemperatureRange,
        ];
      case DashboardPageScope.alerts:
        return <Object?>[
          data.notifications.map((item) => item.toJson()).toList(),
          data.faults.map((item) => item.toJson()).toList(),
          data.faultServicePhone,
        ];
    }
  }

  static bool _deepEquals(Object? left, Object? right) {
    if (identical(left, right)) {
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var index = 0; index < left.length; index++) {
        if (!_deepEquals(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }
}
