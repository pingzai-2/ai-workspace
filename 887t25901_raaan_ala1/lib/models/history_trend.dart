import 'dashboard_data.dart';

/// 后端历史趋势接口的一次响应。
///
/// 时间戳只用于同步层定位前端槽位，页面和 runtime JSON 仍只保存数值数组。
class HistoryTrendSnapshot {
  const HistoryTrendSnapshot({
    required this.range,
    required this.anchorDate,
    required this.timestamps,
    required this.indoor,
    required this.outdoor,
    this.intervalSeconds,
  });

  final String range;
  final DateTime anchorDate;
  final List<int> timestamps;
  final int? intervalSeconds;
  final Map<String, List<double?>> indoor;
  final Map<String, List<double?>> outdoor;

  static HistoryTrendSnapshot fromJson(Map<String, dynamic> data) {
    final range = data['range'];
    if (range is! String ||
        (range != 'day' && range != 'week' && range != 'month')) {
      throw const FormatException('历史趋势 range 无效');
    }

    final anchorDate = _parseDate(data['anchorDate']);
    final timestamps = _readTimestamps(data['timestamps']);
    final intervalSeconds = _readOptionalInt(data['intervalSeconds']);
    return HistoryTrendSnapshot(
      range: range,
      anchorDate: anchorDate,
      timestamps: timestamps,
      intervalSeconds: intervalSeconds,
      indoor: _readSeriesGroup(data['indoor']),
      outdoor: _readSeriesGroup(data['outdoor']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('历史趋势 anchorDate 无效');
    }
    final parts = value.split('-').map(int.parse).toList(growable: false);
    final date = DateTime(parts[0], parts[1], parts[2]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2]) {
      throw const FormatException('历史趋势 anchorDate 不存在');
    }
    return date;
  }

  static List<int> _readTimestamps(Object? value) {
    if (value is! List) {
      throw const FormatException('历史趋势 timestamps 必须是数组');
    }
    final result = <int>[];
    for (final entry in value) {
      if (entry is! num || !entry.isFinite || entry.toInt() != entry) {
        throw const FormatException('历史趋势 timestamp 无效');
      }
      result.add(entry.toInt());
    }
    return result;
  }

  static int? _readOptionalInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! num || !value.isFinite || value.toInt() != value) {
      throw const FormatException('历史趋势 intervalSeconds 无效');
    }
    return value.toInt();
  }

  static Map<String, List<double?>> _readSeriesGroup(Object? value) {
    if (value is! Map) {
      return const <String, List<double?>>{};
    }
    final group = <String, List<double?>>{};
    for (final key in const <String>[
      'temperature',
      'humidity',
      'pm25',
      'co2',
    ]) {
      final raw = value[key];
      if (raw is! List) {
        continue;
      }
      group[key] = <double?>[
        for (final entry in raw)
          entry is num && entry.isFinite ? entry.toDouble() : null,
      ];
    }
    return group;
  }
}

/// 把一次后端趋势响应映射到现有 DashboardData 槽位。
///
/// 这是纯转换逻辑，不发 HTTP、不读写文件、不触发页面刷新。
class HistoryTrendMapper {
  const HistoryTrendMapper._();

  static Map<String, dynamic> merge(
    DashboardData current,
    HistoryTrendSnapshot snapshot,
  ) {
    final expectedInterval = snapshot.range == 'day' ? 7200 : 86400;
    if (snapshot.intervalSeconds != null &&
        snapshot.intervalSeconds != expectedInterval) {
      return const <String, dynamic>{};
    }
    final slots = _slotIndexes(snapshot);
    final patch = <String, dynamic>{};
    final defaults = DashboardData.defaults();
    final capacity = snapshot.range == 'day'
        ? 12
        : snapshot.range == 'week'
            ? 7
            : 31;

    for (final metric in const <String>[
      'temperature',
      'humidity',
      'pm25',
      'co2',
    ]) {
      final indoorKey = _fieldName(snapshot.range, metric, true);
      final indoor = _mergeValues(
        _listField(current, indoorKey),
        _listField(defaults, indoorKey),
        snapshot.indoor[metric],
        slots,
        capacity,
      );
      if (indoor != null) {
        patch[indoorKey] = indoor;
      }

      // CO2 当前页面只显示室内；其它指标保留室外序列。
      if (metric != 'co2') {
        final outdoorKey = _fieldName(snapshot.range, metric, false);
        final outdoor = _mergeValues(
          _listField(current, outdoorKey),
          _listField(defaults, outdoorKey),
          snapshot.outdoor[metric],
          slots,
          capacity,
        );
        if (outdoor != null) {
          patch[outdoorKey] = outdoor;
        }
      }
    }

    if (snapshot.range == 'month' && snapshot.timestamps.isNotEmpty) {
      patch['monthlyTrendYear'] = snapshot.anchorDate.year;
      patch['monthlyTrendMonth'] = snapshot.anchorDate.month;
    }
    return patch;
  }

  static String _fieldName(String range, String metric, bool indoor) {
    final prefix = range == 'day'
        ? 'daily'
        : range == 'week'
            ? 'weekly'
            : 'monthly';
    final name = metric == 'temperature'
        ? 'Temperature'
        : metric == 'humidity'
            ? 'Humidity'
            : metric == 'pm25'
                ? 'Pm25'
                : 'Co2Ppm';
    if (metric == 'co2') {
      return '$prefix$name';
    }
    final unit = metric == 'temperature'
        ? 'C'
        : metric == 'humidity'
            ? 'Percent'
            : '';
    return '$prefix$name${indoor ? 'Indoor' : 'Outdoor'}$unit';
  }

  static List<double> _listField(DashboardData data, String key) {
    switch (key) {
      case 'dailyTemperatureIndoorC':
        return data.dailyTemperatureIndoorC;
      case 'dailyTemperatureOutdoorC':
        return data.dailyTemperatureOutdoorC;
      case 'weeklyTemperatureIndoorC':
        return data.weeklyTemperatureIndoorC;
      case 'weeklyTemperatureOutdoorC':
        return data.weeklyTemperatureOutdoorC;
      case 'monthlyTemperatureIndoorC':
        return data.monthlyTemperatureIndoorC;
      case 'monthlyTemperatureOutdoorC':
        return data.monthlyTemperatureOutdoorC;
      case 'dailyHumidityIndoorPercent':
        return data.dailyHumidityIndoorPercent;
      case 'dailyHumidityOutdoorPercent':
        return data.dailyHumidityOutdoorPercent;
      case 'weeklyHumidityIndoorPercent':
        return data.weeklyHumidityIndoorPercent;
      case 'weeklyHumidityOutdoorPercent':
        return data.weeklyHumidityOutdoorPercent;
      case 'monthlyHumidityIndoorPercent':
        return data.monthlyHumidityIndoorPercent;
      case 'monthlyHumidityOutdoorPercent':
        return data.monthlyHumidityOutdoorPercent;
      case 'dailyPm25Indoor':
        return data.dailyPm25Indoor;
      case 'dailyPm25Outdoor':
        return data.dailyPm25Outdoor;
      case 'weeklyPm25Indoor':
        return data.weeklyPm25Indoor;
      case 'weeklyPm25Outdoor':
        return data.weeklyPm25Outdoor;
      case 'monthlyPm25Indoor':
        return data.monthlyPm25Indoor;
      case 'monthlyPm25Outdoor':
        return data.monthlyPm25Outdoor;
      case 'dailyCo2Ppm':
        return data.dailyCo2Ppm;
      case 'weeklyCo2Ppm':
        return data.weeklyCo2Ppm;
      case 'monthlyCo2Ppm':
        return data.monthlyCo2Ppm;
      default:
        return const <double>[];
    }
  }

  static List<int?> _slotIndexes(HistoryTrendSnapshot snapshot) {
    switch (snapshot.range) {
      case 'day':
        return _daySlots(snapshot);
      case 'week':
        return <int?>[
          for (final timestamp in snapshot.timestamps) _weekdaySlot(timestamp),
        ];
      case 'month':
        final maxDays = DateTime(
          snapshot.anchorDate.year,
          snapshot.anchorDate.month + 1,
          0,
        ).day;
        final used = <int>{};
        return <int?>[
          for (final timestamp in snapshot.timestamps)
            _monthSlot(timestamp, maxDays, used),
        ];
    }
    return const <int?>[];
  }

  static List<int?> _daySlots(HistoryTrendSnapshot snapshot) {
    final anchor = DateTime(
      snapshot.anchorDate.year,
      snapshot.anchorDate.month,
      snapshot.anchorDate.day,
    );
    final target = <String, int>{};
    const hours = <int>[10, 12, 14, 16, 18, 20, 22, 0, 2, 4, 6, 8];
    for (var index = 0; index < hours.length; index++) {
      final hour = hours[index];
      final date =
          hour >= 10 ? anchor.subtract(const Duration(days: 1)) : anchor;
      target[_dateHourKey(date, hour)] = index;
    }
    return <int?>[
      for (final timestamp in snapshot.timestamps)
        target[_timestampDateHourKey(timestamp)],
    ];
  }

  static int? _weekdaySlot(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    if (date.minute != 0 || date.second != 0) {
      return null;
    }
    // DateTime.weekday: Monday=1 ... Sunday=7; UI 固定 Thursday -> Wednesday。
    return (date.weekday - DateTime.thursday + 7) % 7;
  }

  static int? _monthSlot(int timestamp, int maxDays, Set<int> used) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final slot = date.day - 1;
    if (slot < 0 || slot >= maxDays || !used.add(slot)) {
      return null;
    }
    return slot;
  }

  static String _timestampDateHourKey(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return _dateHourKey(date, date.hour);
  }

  static String _dateHourKey(DateTime date, int hour) {
    return '${date.year}-${date.month}-${date.day}-$hour';
  }

  static List<double>? _mergeValues(
    List<double> current,
    List<double> fallback,
    List<double?>? incoming,
    List<int?> slots,
    int capacity,
  ) {
    if (incoming == null || incoming.isEmpty || slots.isEmpty) {
      return null;
    }
    final merged = List<double>.generate(
      capacity,
      (index) => index < current.length
          ? current[index]
          : index < fallback.length
              ? fallback[index]
              : 0,
    );
    var changed = false;
    final count =
        incoming.length < slots.length ? incoming.length : slots.length;
    for (var index = 0; index < count; index++) {
      final slot = slots[index];
      final value = incoming[index];
      if (slot == null || value == null || slot < 0 || slot >= capacity) {
        continue;
      }
      if (merged[slot] != value) {
        merged[slot] = value;
        changed = true;
      }
    }
    return changed ? merged : null;
  }
}
