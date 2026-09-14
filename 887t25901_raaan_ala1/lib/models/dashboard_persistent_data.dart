/// 工程施工确认后长期保存的配置。
///
/// 这份数据独立于 settings/runtime：不参与两秒轮询，也不在普通
/// 设置保存时写入。当前仅包含已经有明确 UI 编辑入口的设备区域和房间。
class DashboardPersistentData {
  const DashboardPersistentData({
    required this.engineeringDeviceAreas,
    required this.engineeringDeviceRooms,
  });

  final Map<String, String> engineeringDeviceAreas;
  final Map<String, String> engineeringDeviceRooms;

  factory DashboardPersistentData.defaults() {
    return const DashboardPersistentData(
      engineeringDeviceAreas: <String, String>{},
      engineeringDeviceRooms: <String, String>{},
    );
  }

  factory DashboardPersistentData.fromJson(Map<String, dynamic> json) {
    return DashboardPersistentData(
      engineeringDeviceAreas: _readStringMap(json['engineeringDeviceAreas']),
      engineeringDeviceRooms: _readStringMap(json['engineeringDeviceRooms']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'engineeringDeviceAreas': engineeringDeviceAreas,
        'engineeringDeviceRooms': engineeringDeviceRooms,
      };

  DashboardPersistentData copyWith({
    Map<String, String>? engineeringDeviceAreas,
    Map<String, String>? engineeringDeviceRooms,
  }) {
    return DashboardPersistentData(
      engineeringDeviceAreas:
          engineeringDeviceAreas ?? this.engineeringDeviceAreas,
      engineeringDeviceRooms:
          engineeringDeviceRooms ?? this.engineeringDeviceRooms,
    );
  }

  static Map<String, String> _readStringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return Map<String, String>.unmodifiable(
      Map<String, String>.fromEntries(
        value.entries
            .where(
              (entry) => entry.key is String && entry.value is String,
            )
            .map(
              (entry) => MapEntry<String, String>(
                entry.key as String,
                entry.value as String,
              ),
            ),
      ),
    );
  }
}
