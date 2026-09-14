/// settings JSON 中的类型化字段路径。
class DashboardSettingsField<T> {
  const DashboardSettingsField(this.jsonPath);

  final List<String> jsonPath;
}

/// runtime JSON 中的类型化根字段。
class DashboardRuntimeField<T> {
  const DashboardRuntimeField(this.jsonKey);

  final String jsonKey;
}

/// ===== 字段配置表：只登记 Dart 数据与 JSON 字段的对应关系 =====
///
/// 新增普通设备字段时先在这里登记。字段表不读取设备、不生成 JSON，也不写文件。
class DashboardFieldTable {
  DashboardFieldTable._();

  static const DashboardRuntimeField<String> backendDataStatus =
      DashboardRuntimeField<String>('backendDataStatus');

  static const DashboardRuntimeField<int> indoorTemperatureC =
      DashboardRuntimeField<int>('indoorTemperatureC');

  static const DashboardRuntimeField<int> indoorHumidityPercent =
      DashboardRuntimeField<int>('indoorHumidityPercent');

  static const DashboardRuntimeField<int> indoorPm25 =
      DashboardRuntimeField<int>('indoorPm25');

  static const DashboardRuntimeField<int> indoorCo2Ppm =
      DashboardRuntimeField<int>('indoorCo2Ppm');

  static const DashboardRuntimeField<int> outdoorTemperatureC =
      DashboardRuntimeField<int>('outdoorTemperatureC');

  static const DashboardRuntimeField<int> outdoorHumidityPercent =
      DashboardRuntimeField<int>('outdoorHumidityPercent');

  static const DashboardRuntimeField<int> outdoorPm25 =
      DashboardRuntimeField<int>('outdoorPm25');

  static const DashboardRuntimeField<bool> pureRunning =
      DashboardRuntimeField<bool>('pureRunning');

  static const DashboardRuntimeField<bool> freshAirRunning =
      DashboardRuntimeField<bool>('freshAirRunning');

  static const DashboardRuntimeField<bool> humidifierRunning =
      DashboardRuntimeField<bool>('humidifierRunning');

  static const DashboardRuntimeField<List<Map<String, dynamic>>> faults =
      DashboardRuntimeField<List<Map<String, dynamic>>>('faults');

  static const DashboardSettingsField<bool> pureEnabled =
      DashboardSettingsField<bool>(<String>['pureSettings', 'enabled']);

  static const DashboardSettingsField<bool> freshAirEnabled =
      DashboardSettingsField<bool>(<String>['freshAirEnabled']);

  static const DashboardSettingsField<bool> humidifierEnabled =
      DashboardSettingsField<bool>(<String>['humidifierEnabled']);
}
