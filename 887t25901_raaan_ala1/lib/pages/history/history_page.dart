import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/prototype_chrome.dart';

/// 趋势页指标/系列数据内部使用稳定的中文/英文标识作为 key，
/// 渲染时按当前语言解析为 ARB 文案（CO2 保持原样）。
String _historyMetricLabel(String key, AppLocalizations l10n) {
  switch (key) {
    case '温度':
      return l10n.metricTemperature;
    case '湿度':
      return l10n.metricHumidity;
    case 'PM2.5':
      return l10n.metricPm25;
    default:
      return key;
  }
}

String _historySeriesLabel(String key, AppLocalizations l10n) {
  switch (key) {
    case '室内':
      return l10n.floorIndoor;
    case '室外':
      return l10n.idleOutdoor;
    default:
      return key;
  }
}

/// 周视图横轴标签固定从周四开始，顺序与旧常量 ['周四','周五','周六','周日','周一','周二','周三'] 一致。
List<String> _weeklyAxisLabels(String locale) {
  // 2024-01-04 是周四，作为锚点保证首标签为周首日。
  final anchor = DateTime(2024, 1, 4);
  return <String>[
    for (var offset = 0; offset < 7; offset++)
      DateFormat.E(locale).format(anchor.add(Duration(days: offset))),
  ];
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    Key? key,
    required this.data,
    required this.onBack,
    required this.entryToken,
  }) : super(key: key);

  final DashboardData data;
  final VoidCallback onBack;
  final int entryToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _metricIndex = 0;
  int _rangeIndex = 0;
  bool _rangeMenuOpen = false;

  // 曲线显隐属于页面展示策略，不属于 runtime 数据。未来可由页面状态随机切换；
  // false 时图例、平均值与曲线路径均不创建。
  // ignore: prefer_final_fields
  bool _co2ShowIndoor = true;
  // ignore: prefer_final_fields
  bool _co2ShowOutdoor = false;

  static const List<_HistoryMetricDefinition> _metrics =
      <_HistoryMetricDefinition>[
    _HistoryMetricDefinition(
      label: '温度',
      unit: '℃',
      minimum: 0,
      maximum: 40,
      verticalLabels: <String>['40', '30', '20', '10', '0'],
      chartKey: 'daily-temperature-chart',
      showIndoor: true,
      showOutdoor: true,
    ),
    _HistoryMetricDefinition(
      label: '湿度',
      unit: '%',
      minimum: 0,
      maximum: 100,
      verticalLabels: <String>['100', '75', '50', '25', '0'],
      chartKey: 'daily-humidity-chart',
      showIndoor: true,
      showOutdoor: true,
    ),
    _HistoryMetricDefinition(
      label: 'PM2.5',
      unit: 'µg/m³',
      minimum: 0,
      maximum: 200,
      verticalLabels: <String>['200', '150', '100', '50', '0'],
      chartKey: 'daily-pm25-chart',
      showIndoor: true,
      showOutdoor: true,
    ),
  ];

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entryToken != oldWidget.entryToken) {
      _metricIndex = 0;
      _rangeIndex = 0;
      _rangeMenuOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    if (_metricIndex < _metrics.length) {
      final metric = _metrics[_metricIndex];
      final trend = _trendForRange(
        _rangeIndex,
        widget.data,
        _metricIndex,
        locale,
        l10n,
      );
      return _DailyTemperatureHistory(
        onBack: widget.onBack,
        onMetricSelected: _selectMetric,
        rangeIndex: _rangeIndex,
        rangeMenuOpen: _rangeMenuOpen,
        onRangeTap: _toggleRangeMenu,
        onRangeSelected: _selectRange,
        trend: trend,
        metric: metric,
        selectedMetricIndex: _metricIndex,
      );
    }

    const unit = 'ppm';
    final co2Values = _co2ValuesForRange(widget.data, _rangeIndex);
    final co2Axis = _trendForRange(
      _rangeIndex,
      widget.data,
      0,
      locale,
      l10n,
    );
    final co2Series = _co2SeriesForRange(co2Values, l10n);
    return PrototypePageChrome(
      prompt: '',
      onBack: widget.onBack,
      backIconAsset: 'assets/navigation/history_back.png',
      backDividerAsset: 'assets/navigation/history_back_line.png',
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 400,
            top: 212,
            child: Container(
              width: 1470,
              height: 924,
              decoration: BoxDecoration(
                color: prototypePanel,
                borderRadius: BorderRadius.circular(2),
                image: const DecorationImage(
                  image: AssetImage('assets/history/frame-bg.png'),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          HistoryMetricSideMenu(
            selectedIndex: _metricIndex,
            onSelected: _selectMetric,
          ),
          _DailyHistoryLegend(series: co2Series),
          Positioned(
            left: 510,
            top: 320,
            child: SizedBox(
              width: 1180,
              height: 700,
              child: _HistoryChart(
                // CO₂ 趋势同样使用独立的交互状态，进入时不继承
                // 其他指标可能留下的触摸选中点和红色引导线。
                key: const ValueKey<String>('history-co2-chart-state'),
                unit: unit,
                series: co2Series,
                sampleCapacity: co2Axis.sampleCapacity,
                horizontalLabels: co2Axis.horizontalLabels,
                horizontalTitle: co2Axis.horizontalTitle,
                horizontalUnit: co2Axis.horizontalUnit,
              ),
            ),
          ),
          for (var index = 0; index < co2Series.length; index++)
            Positioned(
              left: 1673,
              top: 277 + index * 183,
              child: _AverageValue(
                label: '${_historySeriesLabel(co2Series[index].label, l10n)}'
                    '${l10n.historyAverageSuffix}',
                value: _formatTrendAverage(
                  _averageTrendValue(
                    co2Series[index].values,
                    divisor: co2Series[index].values.length,
                  ),
                ),
                unit: unit,
                color: co2Series[index].color,
              ),
            ),
          Positioned(
            left: 1598,
            top: 121,
            child: _HistoryRangeSelector(
              selectedIndex: _rangeIndex,
              menuOpen: _rangeMenuOpen,
              onToggle: _toggleRangeMenu,
              onSelected: _selectRange,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleRangeMenu() {
    setState(() => _rangeMenuOpen = !_rangeMenuOpen);
  }

  void _selectMetric(int index) {
    setState(() {
      _metricIndex = index;
      // 切换指标后不保留上一个指标打开的周期菜单。
      _rangeMenuOpen = false;
    });
  }

  void _selectRange(int index) {
    setState(() {
      _rangeIndex = index;
      _rangeMenuOpen = false;
    });
  }

  _TemperatureTrendDefinition _trendForRange(
    int rangeIndex,
    DashboardData data,
    int metricIndex,
    String locale,
    AppLocalizations l10n,
  ) {
    final series = _seriesForRange(data, metricIndex, rangeIndex);
    switch (rangeIndex) {
      case 1:
        return _TemperatureTrendDefinition(
          indoorValues: series.indoorValues,
          outdoorValues: series.outdoorValues,
          averageDivisor: series.indoorValues.length,
          sampleCapacity: series.indoorValues.length,
          chartWidth: 1047,
          horizontalLabels: _weeklyAxisLabels(locale),
          horizontalLefts: const <double>[
            569,
            737,
            905,
            1073,
            1241,
            1409,
            1577
          ],
          horizontalLabelWidth: 60,
          horizontalFontFamily: AppFonts.sourceHanSansSc,
          horizontalFontVariations: AppFonts.sourceHanSansScRegularWght400,
          horizontalTitle: l10n.historyWeeklyTitle,
          horizontalUnit: 'W',
          horizontalTitleLeft: 1698,
          horizontalUnitLeft: 1779,
        );
      case 2:
        final monthAxis = _monthAxisFor(data, locale);
        return _TemperatureTrendDefinition(
          indoorValues: series.indoorValues,
          outdoorValues: series.outdoorValues,
          // 月视图只计算当月实际读取的数据，不把预留到 31 日的数据计入平均值。
          averageDivisor: series.indoorValues.length,
          // 横轴固定按 31 天容量布点，曲线末端自然落在当月 28/29/30/31 日。
          sampleCapacity: _monthlySampleCapacity,
          chartWidth: monthAxis.chartWidth,
          horizontalLabels: monthAxis.labels,
          horizontalLefts: monthAxis.lefts,
          horizontalLabelWidth: 36,
          horizontalFontFamily: AppFonts.harmonyRegular,
          horizontalTitle: monthAxis.title,
          horizontalUnit: 'M',
          // 一位或两位月份都维持右侧 M 单位的视觉锚点。
          horizontalTitleLeft: monthAxis.titleLeft,
          horizontalUnitLeft: monthAxis.unitLeft,
        );
      default:
        return _TemperatureTrendDefinition(
          indoorValues: series.indoorValues,
          outdoorValues: series.outdoorValues,
          averageDivisor: series.indoorValues.length,
          sampleCapacity: series.indoorValues.length,
          chartWidth: 1047,
          horizontalLabels: const <String>[
            '10',
            '12',
            '14',
            '16',
            '18',
            '20',
            '22',
            '00',
            '02',
            '04',
            '06',
            '08',
          ],
          horizontalLefts: const <double>[
            581,
            673,
            765,
            857,
            949,
            1041,
            1133,
            1225,
            1317,
            1409,
            1501,
            1593,
          ],
          horizontalLabelWidth: 36,
          horizontalFontFamily: AppFonts.harmonyRegular,
          horizontalTitle: l10n.historyTimeTitle,
          horizontalUnit: 'H',
          horizontalTitleLeft: 1698,
          horizontalUnitLeft: 1782,
        );
    }
  }

  _TrendSeries _seriesForRange(
    DashboardData data,
    int metricIndex,
    int rangeIndex,
  ) {
    late final List<double> indoorValues;
    late final List<double> outdoorValues;
    switch (metricIndex) {
      case 1:
        indoorValues = rangeIndex == 0
            ? data.dailyHumidityIndoorPercent
            : rangeIndex == 1
                ? data.weeklyHumidityIndoorPercent
                : data.monthlyHumidityIndoorPercent;
        outdoorValues = rangeIndex == 0
            ? data.dailyHumidityOutdoorPercent
            : rangeIndex == 1
                ? data.weeklyHumidityOutdoorPercent
                : data.monthlyHumidityOutdoorPercent;
        break;
      case 2:
        indoorValues = rangeIndex == 0
            ? data.dailyPm25Indoor
            : rangeIndex == 1
                ? data.weeklyPm25Indoor
                : data.monthlyPm25Indoor;
        outdoorValues = rangeIndex == 0
            ? data.dailyPm25Outdoor
            : rangeIndex == 1
                ? data.weeklyPm25Outdoor
                : data.monthlyPm25Outdoor;
        break;
      default:
        indoorValues = rangeIndex == 0
            ? data.dailyTemperatureIndoorC
            : rangeIndex == 1
                ? data.weeklyTemperatureIndoorC
                : data.monthlyTemperatureIndoorC;
        outdoorValues = rangeIndex == 0
            ? data.dailyTemperatureOutdoorC
            : rangeIndex == 1
                ? data.weeklyTemperatureOutdoorC
                : data.monthlyTemperatureOutdoorC;
        break;
    }
    if (rangeIndex != 2) {
      return _TrendSeries(
        indoorValues: indoorValues,
        outdoorValues: outdoorValues,
      );
    }
    final visibleCount = DashboardData.monthlyTrendVisibleCount(
      data.monthlyTrendYear,
      data.monthlyTrendMonth,
      indoorValues.length,
    );
    // 月数组可统一预留 31 项；页面只读取当前自然月实际需要的数据。
    return _TrendSeries(
      indoorValues: indoorValues.take(visibleCount).toList(),
      outdoorValues: outdoorValues.take(visibleCount).toList(),
    );
  }

  List<double> _co2ValuesForRange(DashboardData data, int rangeIndex) {
    final values = rangeIndex == 0
        ? data.dailyCo2Ppm
        : rangeIndex == 1
            ? data.weeklyCo2Ppm
            : data.monthlyCo2Ppm;
    if (rangeIndex != 2) {
      return values;
    }
    final visibleCount = DashboardData.monthlyTrendVisibleCount(
      data.monthlyTrendYear,
      data.monthlyTrendMonth,
      values.length,
    );
    return values.take(visibleCount).toList();
  }

  List<_HistoryCurveSeries> _co2SeriesForRange(
    List<double> indoorValues,
    AppLocalizations l10n,
  ) {
    // CO₂ 当前只有室内采样源。若未来补充室外采样，只需在此处按
    // _co2ShowOutdoor 追加一条同结构的 _HistoryCurveSeries。
    return <_HistoryCurveSeries>[
      if (_co2ShowIndoor)
        _HistoryCurveSeries(
          id: 'indoor',
          label: _historySeriesLabel('室内', l10n),
          values: indoorValues,
          color: prototypeCyan,
          gradientColor: prototypeCyan,
        ),
      if (_co2ShowOutdoor) ..._co2OutdoorSeriesForRange(),
    ];
  }

  List<_HistoryCurveSeries> _co2OutdoorSeriesForRange() {
    // 当前没有室外 CO₂ 数据源，所以即使页面策略允许，也不会凭空创建曲线。
    // 将来接入可靠数组后，只需在这里返回一条 label 为“室外”的系列。
    return const <_HistoryCurveSeries>[];
  }

  _MonthAxisDefinition _monthAxisFor(DashboardData data, String locale) {
    // 刻度统一显示到 30，避免二月以 25 收口后造成横轴过短和视觉跳变。
    const labels = <String>['5', '10', '15', '20', '25', '30'];
    const days = <int>[5, 10, 15, 20, 25, 30];
    final lefts = <double>[
      for (final day in days)
        _monthlyChartLeft +
            _monthlyPlotWidth * DashboardData.monthlyTrendDayFraction(day) -
            _monthlyAxisLabelWidth / 2,
    ];
    // 用目标语言显示月份缩写（zh：9月 / ja：9月 / en：Sep）。
    final monthText = DateFormat.MMM(locale).format(
      DateTime(2000, data.monthlyTrendMonth),
    );
    const titleLeft = _monthlyChartLeft + _monthlyChartWidth + 35;
    return _MonthAxisDefinition(
      labels: labels,
      lefts: lefts,
      title: monthText,
      titleLeft: titleLeft,
      unitLeft: titleLeft + (data.monthlyTrendMonth >= 10 ? 114 : 78),
      chartWidth: _monthlyChartWidth,
    );
  }
}

const int _monthlySampleCapacity = 31;
const double _monthlyChartLeft = 598.5;
const double _monthlyChartWidth = 1047;
const double _monthlyPlotWidth = _monthlyChartWidth - 35;
const double _monthlyAxisLabelWidth = 36;

double _trendSampleFraction(int index, int sampleCapacity) {
  return sampleCapacity == _monthlySampleCapacity
      ? DashboardData.monthlyTrendDayFraction(index + 1)
      : index / (sampleCapacity - 1);
}

int _trendSelectionIndex({
  required double localDx,
  required double plotLeft,
  required double plotWidth,
  required int sampleCapacity,
  required int valueCount,
}) {
  final fraction = ((localDx - plotLeft) / plotWidth).clamp(0.0, 1.0);
  final capacityIndex = (fraction * (sampleCapacity - 1)).round();
  return capacityIndex.clamp(0, valueCount - 1).toInt();
}

String _trendSelectionKey(
  String prefix,
  int? selectedIndex,
  int valueCount,
) {
  if (selectedIndex == null || valueCount == 0) {
    return '$prefix-default';
  }
  final state = selectedIndex >= valueCount - 1 ? 'end' : 'guide';
  return '$prefix-$selectedIndex-$state';
}

class _TrendSeries {
  const _TrendSeries({
    required this.indoorValues,
    required this.outdoorValues,
  });

  final List<double> indoorValues;
  final List<double> outdoorValues;
}

/// 一条可绘制的趋势系列。页面先按展示策略组装此列表；不在列表中的
/// 系列不会创建图例、平均值或绘制路径。
class _HistoryCurveSeries {
  const _HistoryCurveSeries({
    required this.id,
    required this.label,
    required this.values,
    required this.color,
    required this.gradientColor,
    this.selectionGuideEnabled = true,
    this.selectionGuideColor = const Color(0xFFFF2424),
    this.selectionGuideWidth = 1,
  });

  final String id;
  final String label;
  final List<double> values;
  final Color color;
  final Color gradientColor;
  final bool selectionGuideEnabled;
  final Color selectionGuideColor;
  final double selectionGuideWidth;
}

class _MonthAxisDefinition {
  const _MonthAxisDefinition({
    required this.labels,
    required this.lefts,
    required this.title,
    required this.titleLeft,
    required this.unitLeft,
    required this.chartWidth,
  });

  final List<String> labels;
  final List<double> lefts;
  final String title;
  final double titleLeft;
  final double unitLeft;
  final double chartWidth;
}

class _HistoryMetricDefinition {
  const _HistoryMetricDefinition({
    required this.label,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.verticalLabels,
    required this.chartKey,
    required this.showIndoor,
    required this.showOutdoor,
  });

  final String label;
  final String unit;
  final double minimum;
  final double maximum;
  final List<String> verticalLabels;
  final String chartKey;
  final bool showIndoor;
  final bool showOutdoor;
}

/// 三个温度周期只替换数据和横轴描述，曲线与动效实现共用。
class _TemperatureTrendDefinition {
  const _TemperatureTrendDefinition({
    required this.indoorValues,
    required this.outdoorValues,
    required this.averageDivisor,
    required this.sampleCapacity,
    required this.chartWidth,
    required this.horizontalLabels,
    required this.horizontalLefts,
    required this.horizontalLabelWidth,
    required this.horizontalFontFamily,
    this.horizontalFontVariations,
    required this.horizontalTitle,
    required this.horizontalUnit,
    required this.horizontalTitleLeft,
    required this.horizontalUnitLeft,
  });

  final List<double> indoorValues;
  final List<double> outdoorValues;
  final int averageDivisor;
  final int sampleCapacity;
  final double chartWidth;
  final List<String> horizontalLabels;
  final List<double> horizontalLefts;
  final double horizontalLabelWidth;
  final String horizontalFontFamily;
  final List<FontVariation>? horizontalFontVariations;
  final String horizontalTitle;
  final String horizontalUnit;
  final double horizontalTitleLeft;
  final double horizontalUnitLeft;
}

/// 温度按日、按周、按月共用同一页面骨架与曲线绘制逻辑。
/// 画板基准分别为 Figma `1:514`、`1:1152`、`1:1267`；周期只替换采样和横轴描述。
class _DailyTemperatureHistory extends StatelessWidget {
  const _DailyTemperatureHistory({
    required this.onBack,
    required this.onMetricSelected,
    required this.rangeIndex,
    required this.rangeMenuOpen,
    required this.onRangeTap,
    required this.onRangeSelected,
    required this.trend,
    required this.metric,
    required this.selectedMetricIndex,
  });

  final VoidCallback onBack;
  final ValueChanged<int> onMetricSelected;
  final int rangeIndex;
  final bool rangeMenuOpen;
  final VoidCallback onRangeTap;
  final ValueChanged<int> onRangeSelected;
  final _TemperatureTrendDefinition trend;
  final _HistoryMetricDefinition metric;
  final int selectedMetricIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final series = _buildVisibleSeries(
      trend: trend,
      showIndoor: metric.showIndoor,
      showOutdoor: metric.showOutdoor,
      l10n: l10n,
    );
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          PrototypeCircularBackControl(
            onTap: onBack,
            iconAsset: 'assets/navigation/history_back.png',
            dividerAsset: 'assets/navigation/history_back_line.png',
          ),
          HistoryMetricSideMenu(
            selectedIndex: selectedMetricIndex,
            onSelected: onMetricSelected,
          ),
          // Figma 1:515，趋势内容底板。
          Positioned(
            left: 400,
            top: 212,
            child: Container(
              width: 1470,
              height: 924,
              decoration: BoxDecoration(
                color: prototypePanel,
                borderRadius: BorderRadius.circular(2),
                image: const DecorationImage(
                  image: AssetImage('assets/history/frame-bg.png'),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          _DailyHistoryLegend(series: series),
          // 同一曲线画板复用温度、湿度、PM2.5；仅替换数据与量纲。
          Positioned(
            left: 559.5,
            top: 334,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConstrainedBox(
                  // 温度/湿度占用原设计稿的 72.5 px 标题槽；PM2.5 超宽后自然扩展。
                  constraints: const BoxConstraints(minWidth: 72.5),
                  child: Text(
                    _historyMetricLabel(metric.label, l10n),
                    key: const ValueKey<String>('history-metric-title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppFonts.sourceHanSansSc,
                      fontVariations: AppFonts.sourceHanSansScRegularWght400,
                      fontSize: 36,
                      height: 1.448,
                    ),
                  ),
                ),
                Padding(
                  // 原单位坐标为 x=640、y=360；标题超宽时仅横向后移。
                  padding: const EdgeInsets.only(left: 8, top: 26),
                  child: Text(
                    metric.unit,
                    key: const ValueKey<String>('history-metric-unit'),
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontFamily: AppFonts.harmonyRegular,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DailyTemperatureAxisLabels(
            verticalLabels: metric.verticalLabels,
            horizontalLabels: trend.horizontalLabels,
            horizontalLefts: trend.horizontalLefts,
            horizontalLabelWidth: trend.horizontalLabelWidth,
            horizontalFontFamily: trend.horizontalFontFamily,
            horizontalFontVariations: trend.horizontalFontVariations,
          ),
          // Figma 1:529~1:531、1:591、1:617：坐标轴与双曲线面积图。
          Positioned(
            left: 598.5,
            top: 419,
            width: trend.chartWidth,
            height: 534,
            child: _DailyTemperatureChart(
              series: series,
              sampleCapacity: trend.sampleCapacity,
              minimum: metric.minimum,
              maximum: metric.maximum,
              chartKey: metric.chartKey,
            ),
          ),
          Positioned(
            left: trend.horizontalTitleLeft,
            top: 925.5,
            child: Text(
              trend.horizontalTitle,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 36,
                height: 1.448,
              ),
            ),
          ),
          Positioned(
            left: trend.horizontalUnitLeft,
            top: 951,
            child: Text(
              trend.horizontalUnit,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.harmonyRegular,
                fontSize: 20,
              ),
            ),
          ),
          for (var index = 0; index < series.length; index++)
            _DailyAverageValue(
              label: '${_historySeriesLabel(series[index].label, l10n)}'
                  '${l10n.historyAverageSuffix}',
              value: _formatTrendAverage(
                _averageTrendValue(
                  series[index].values,
                  divisor: trend.averageDivisor,
                ),
              ),
              unit: metric.unit,
              top: 277 + index * 183,
            ),
          // Figma 1:780：周期选择浮层需压在右侧平均值之上。
          Positioned(
            left: 1598,
            top: 121,
            child: _HistoryRangeSelector(
              selectedIndex: rangeIndex,
              menuOpen: rangeMenuOpen,
              onToggle: onRangeTap,
              onSelected: onRangeSelected,
            ),
          ),
        ],
      ),
    );
  }

  List<_HistoryCurveSeries> _buildVisibleSeries({
    required _TemperatureTrendDefinition trend,
    required bool showIndoor,
    required bool showOutdoor,
    required AppLocalizations l10n,
  }) {
    return <_HistoryCurveSeries>[
      if (showOutdoor)
        _HistoryCurveSeries(
          id: 'outdoor',
          label: _historySeriesLabel('室外', l10n),
          values: trend.outdoorValues,
          color: const Color(0xFFEA8E42),
          gradientColor: const Color(0xFFEA8E42),
        ),
      if (showIndoor)
        _HistoryCurveSeries(
          id: 'indoor',
          label: _historySeriesLabel('室内', l10n),
          values: trend.indoorValues,
          color: prototypeCyan,
          gradientColor: prototypeCyan,
        ),
    ];
  }
}

/// Figma `历史趋势-选择周期` 的右上周期选择器（1:780）。
class _HistoryRangeSelector extends StatelessWidget {
  const _HistoryRangeSelector({
    required this.selectedIndex,
    required this.menuOpen,
    required this.onToggle,
    required this.onSelected,
  });

  static String _label(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.historyDailyView;
      case 1:
        return l10n.historyWeeklyView;
      default:
        return l10n.historyMonthlyView;
    }
  }

  final int selectedIndex;
  final bool menuOpen;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 258,
      height: menuOpen ? 236 : 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            key: const ValueKey<String>('history-range'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: SizedBox(
              width: 258,
              height: 68,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 52,
                    top: 10,
                    child: Text(
                      _label(selectedIndex, l10n),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.sourceHanSansSc,
                        fontVariations: AppFonts.sourceHanSansScRegularWght400,
                        fontSize: 32,
                        height: 1.448,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 207,
                    top: 35,
                    width: 20,
                    height: 9,
                    child: CustomPaint(
                      painter: _DailyRangeArrowPainter(up: menuOpen),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (menuOpen)
            Positioned(
              top: 68,
              child: _HistoryRangeMenu(
                selectedIndex: selectedIndex,
                onSelected: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRangeMenu extends StatelessWidget {
  const _HistoryRangeMenu({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('history-range-menu'),
      width: 258,
      height: 168,
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < 3; index++)
            Positioned(
              top: index * 56,
              width: 258,
              height: 56,
              child: GestureDetector(
                key: ValueKey<String>('history-range-option-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(index),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 52,
                      top: 5,
                      child: Text(
                        _HistoryRangeSelector._label(index, l10n),
                        style: TextStyle(
                          color: index == selectedIndex
                              ? prototypeCyan
                              : Colors.white,
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontVariations:
                              AppFonts.sourceHanSansScRegularWght400,
                          fontSize: 32,
                          height: 1.448,
                        ),
                      ),
                    ),
                    if (index == selectedIndex)
                      const Positioned(
                        left: 202,
                        top: 23,
                        width: 24,
                        height: 18,
                        child: CustomPaint(
                          painter: _HistoryRangeCheckPainter(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          for (final top in <double>[56, 112])
            Positioned(
              left: 12,
              top: top,
              width: 234,
              height: 1,
              child: const ColoredBox(color: Color(0x80FFFFFF)),
            ),
        ],
      ),
    );
  }
}

/// Figma 1:717~1:720：历史趋势四个指标的统一导航。
/// 所有指标页均使用同一组已导出的 active/inactive 图标，避免温度页与其他页出现选中态不一致。
class HistoryMetricSideMenu extends StatelessWidget {
  const HistoryMetricSideMenu({
    Key? key,
    required this.selectedIndex,
    required this.onSelected,
  }) : super(key: key);

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<PrototypeMenuItem> _items = <PrototypeMenuItem>[
    PrototypeMenuItem('温度', PrototypeGlyph.temperature),
    PrototypeMenuItem('湿度', PrototypeGlyph.humidity),
    PrototypeMenuItem('PM2.5', PrototypeGlyph.pm25),
    PrototypeMenuItem('CO2', PrototypeGlyph.co2),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: <Widget>[
        for (var index = 0; index < _items.length; index++)
          Positioned(
            left: 108,
            top: 254 + index * 176,
            child: GestureDetector(
              key: ValueKey<String>('side-menu-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(index),
              child: SizedBox(
                // PM2.5 选中态文字框到 x=302；原 188 px 宽度会截掉右侧字形。
                width: index == 2 ? 194 : 188,
                height: 112,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      // Figma 1:717~1:720：72×72 的历史分类图标。
                      left: -4,
                      top: 14,
                      width: 72,
                      height: 72,
                      child: Image.asset(
                        _iconAsset(index, index == selectedIndex),
                        key: ValueKey<String>(
                          'history-side-menu-icon-$index-${index == selectedIndex}',
                        ),
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      // Figma 1:981：PM2.5 的 active 字形比其它项宽，左边缘要回退 3 px。
                      left: index == 2 && index == selectedIndex ? 85 : 88,
                      // 非首项的文本基线与图标框应对齐到 454/630/806 px。
                      top: index == 0 ? 25 : 24,
                      child: _HistorySideMenuLabel(
                        label: _historyMetricLabel(_items[index].label, l10n),
                        selected: index == selectedIndex,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (final top in <double>[391, 567, 744])
          Positioned(
            left: 108,
            top: top,
            width: 184,
            height: 1,
            // Figma sidebar Line 2~4：白色 25% 的普通细分隔线。
            child: const ColoredBox(color: Color(0x40FFFFFF)),
          ),
      ],
    );
  }

  static String _iconAsset(int index, bool selected) {
    const names = <String>[
      'temperature',
      'humidity',
      'pm25',
      'co2',
    ];
    final state = selected ? 'active' : 'inactive';
    return 'assets/history/${names[index]}_$state.png';
  }
}

class _HistorySideMenuLabel extends StatelessWidget {
  const _HistorySideMenuLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0x80FFFFFF);
    final fontVariations = selected
        ? AppFonts.sourceHanSansScBoldWght700
        : AppFonts.sourceHanSansScRegularWght400;
    if (label == 'CO2') {
      // 板端文本引擎对 Unicode 下标字符 `₂` 的字形支持不稳定。
      // 与已经在板端验证正常的息屏页一致，改用普通数字 2 独立定位；
      // 这样仍保留设计稿的下标外观，但不依赖平台字体回退。
      return SizedBox(
        key: const ValueKey<String>('history-co2-side-label'),
        width: 76,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Text(
              'CO',
              style: TextStyle(
                color: color,
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: fontVariations,
                fontSize: 36,
                height: 1.448,
              ),
            ),
            Positioned(
              left: 52.6,
              top: 22.2,
              child: Text(
                '2',
                style: TextStyle(
                  color: color,
                  fontFamily:
                      selected ? AppFonts.harmonyBold : AppFonts.harmonyRegular,
                  fontSize: 22.2,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: AppFonts.sourceHanSansSc,
        fontVariations: fontVariations,
        fontSize: 36,
        height: 1.448,
      ),
    );
  }
}

class _DailyHistoryLegend extends StatelessWidget {
  const _DailyHistoryLegend({required this.series});

  final List<_HistoryCurveSeries> series;

  @override
  Widget build(BuildContext context) {
    // 图例的视觉顺序固定为室内、室外；曲线与右侧平均值仍按系列列表顺序绘制。
    // 这样增加第三条及后续系列时，不影响现有两条系列的 Figma 坐标。
    final legendSeries = <_HistoryCurveSeries>[
      ...series.where((item) => item.id == 'indoor'),
      ...series.where((item) => item.id == 'outdoor'),
      ...series.where(
        (item) => item.id != 'indoor' && item.id != 'outdoor',
      ),
    ];
    return Stack(
      children: <Widget>[
        for (var index = 0; index < legendSeries.length; index++)
          _DailyLegendEntry(
            seriesId: legendSeries[index].id,
            label: legendSeries[index].label,
            left: 450 + index * 263,
            lineLeft: 550 + index * 263,
            lineAsset: legendSeries[index].id == 'indoor'
                ? 'assets/history/indoor_line.png'
                : 'assets/history/outdoor_line.png',
          ),
      ],
    );
  }
}

class _DailyLegendEntry extends StatelessWidget {
  const _DailyLegendEntry({
    Key? key,
    required this.seriesId,
    required this.label,
    required this.left,
    required this.lineLeft,
    required this.lineAsset,
  }) : super(key: key);

  final String seriesId;
  final String label;
  final double left;
  final double lineLeft;
  final String lineAsset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: left,
          top: 114,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: 42,
              height: 1.448,
            ),
          ),
        ),
        Positioned(
          left: lineLeft,
          top: 142,
          width: 84,
          height: 14,
          child: Image.asset(
            lineAsset,
            key: ValueKey<String>('history-legend-line-$seriesId'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
    );
  }
}

class _DailyTemperatureAxisLabels extends StatelessWidget {
  const _DailyTemperatureAxisLabels({
    required this.verticalLabels,
    required this.horizontalLabels,
    required this.horizontalLefts,
    required this.horizontalLabelWidth,
    required this.horizontalFontFamily,
    this.horizontalFontVariations,
  });

  final List<String> verticalLabels;
  final List<String> horizontalLabels;
  final List<double> horizontalLefts;
  final double horizontalLabelWidth;
  final String horizontalFontFamily;
  final List<FontVariation>? horizontalFontVariations;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (var index = 0; index < verticalLabels.length; index++)
          Positioned(
            // 温度的两位刻度与湿度/PM2.5 的三位刻度共用右对齐锚点。
            left: 507,
            top: 448.5 + index * 120,
            width: 54,
            height: 35,
            child: Text(
              verticalLabels[index],
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.harmonyRegular,
                fontSize: 30,
                height: 1.167,
              ),
            ),
          ),
        for (var index = 0; index < horizontalLabels.length; index++)
          Positioned(
            left: horizontalLefts[index],
            top: 980,
            width: horizontalLabelWidth,
            height: 35,
            child: Text(
              horizontalLabels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xB3FFFFFF),
                fontFamily: horizontalFontFamily,
                fontVariations: horizontalFontVariations,
                fontSize: 30,
                height: 1.167,
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyAverageValue extends StatelessWidget {
  const _DailyAverageValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.top,
  });

  final String label;
  final String value;
  final String unit;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 1673,
          top: top,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: 36,
              height: 1.448,
            ),
          ),
        ),
        Positioned(
          left: 1712,
          top: top + 61,
          child: SizedBox(
            width: 156,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppFonts.harmonyLight,
                      fontSize: 60,
                      height: 1.167,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        color: Color(0x80FFFFFF),
                        fontFamily: AppFonts.harmonyRegular,
                        fontSize: 24,
                        height: 1.167,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyRangeArrowPainter extends CustomPainter {
  const _DailyRangeArrowPainter({required this.up});

  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    if (up) {
      canvas.drawLine(const Offset(0, 9), const Offset(10, 0), paint);
      canvas.drawLine(const Offset(10, 0), const Offset(20, 9), paint);
      return;
    }
    canvas.drawLine(const Offset(0, 0), const Offset(10, 9), paint);
    canvas.drawLine(const Offset(10, 9), const Offset(20, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _DailyRangeArrowPainter oldDelegate) {
    return oldDelegate.up != up;
  }
}

class _HistoryRangeCheckPainter extends CustomPainter {
  const _HistoryRangeCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = prototypeCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(1, size.height * .52)
      ..lineTo(size.width * .35, size.height - 1)
      ..lineTo(size.width - 1, 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HistoryRangeCheckPainter oldDelegate) => false;
}

class _DailyTemperatureChart extends StatefulWidget {
  const _DailyTemperatureChart({
    Key? key,
    required this.series,
    required this.sampleCapacity,
    required this.minimum,
    required this.maximum,
    required this.chartKey,
  }) : super(key: key);

  final List<_HistoryCurveSeries> series;
  final int sampleCapacity;
  final double minimum;
  final double maximum;
  final String chartKey;

  @override
  State<_DailyTemperatureChart> createState() => _DailyTemperatureChartState();
}

class _DailyTemperatureChartState extends State<_DailyTemperatureChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_HistoryCurveSeries> _fromSeries;
  late List<_HistoryCurveSeries> _toSeries;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fromSeries = widget.series;
    _toSeries = widget.series;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _DailyTemperatureChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartKey != widget.chartKey ||
        oldWidget.sampleCapacity != widget.sampleCapacity ||
        !_sameSeriesTopology(oldWidget.series, widget.series)) {
      // 切换温度、湿度或 PM2.5 时清掉上一个指标的触摸选中状态。
      // 红色引导线只由新指标上的再次触摸创建，不从旧指标继承。
      _selectedIndex = null;
    }
    if (_sameSeriesValues(widget.series, _toSeries)) {
      return;
    }
    if (!_sameSeriesTopology(widget.series, _toSeries)) {
      // 周期切换、系列显隐或系列数变化时，直接切换坐标拓扑。
      _fromSeries = widget.series;
      _toSeries = widget.series;
      _controller.value = 1;
      return;
    }
    final progress = Curves.easeOutCubic.transform(_controller.value);
    _fromSeries = _interpolateSeries(_fromSeries, _toSeries, progress);
    _toSeries = widget.series;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('trend-selection-surface'),
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) => _selectAt(details.localPosition.dx),
      onPanUpdate: (details) => _selectAt(details.localPosition.dx),
      child: RepaintBoundary(
        key: ValueKey<String>(
          _trendSelectionKey(
            'trend-selection',
            _selectedIndex,
            _valueCount,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(_controller.value);
            return CustomPaint(
              key: ValueKey<String>(widget.chartKey),
              painter: _DailyTemperatureChartPainter(
                series: _interpolateSeries(_fromSeries, _toSeries, progress),
                sampleCapacity: widget.sampleCapacity,
                selectedIndex: _selectedIndex,
                minimum: widget.minimum,
                maximum: widget.maximum,
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectAt(double localDx) {
    final valueCount = _valueCount;
    if (valueCount == 0) {
      return;
    }
    final selectedIndex = _trendSelectionIndex(
      localDx: localDx,
      plotLeft: 0,
      plotWidth: widget.sampleCapacity == _monthlySampleCapacity
          ? _monthlyPlotWidth
          : _monthlyChartWidth - 35,
      sampleCapacity: widget.sampleCapacity,
      valueCount: valueCount,
    );
    if (_selectedIndex != selectedIndex) {
      setState(() => _selectedIndex = selectedIndex);
    }
  }

  int get _valueCount => widget.series.fold<int>(
        0,
        (maximum, item) =>
            item.values.length > maximum ? item.values.length : maximum,
      );

  List<_HistoryCurveSeries> _interpolateSeries(
    List<_HistoryCurveSeries> from,
    List<_HistoryCurveSeries> to,
    double progress,
  ) {
    return <_HistoryCurveSeries>[
      for (var seriesIndex = 0; seriesIndex < from.length; seriesIndex++)
        _HistoryCurveSeries(
          id: to[seriesIndex].id,
          label: to[seriesIndex].label,
          color: to[seriesIndex].color,
          gradientColor: to[seriesIndex].gradientColor,
          selectionGuideEnabled: to[seriesIndex].selectionGuideEnabled,
          selectionGuideColor: to[seriesIndex].selectionGuideColor,
          selectionGuideWidth: to[seriesIndex].selectionGuideWidth,
          values: <double>[
            for (var valueIndex = 0;
                valueIndex < from[seriesIndex].values.length;
                valueIndex++)
              from[seriesIndex].values[valueIndex] +
                  (to[seriesIndex].values[valueIndex] -
                          from[seriesIndex].values[valueIndex]) *
                      progress,
          ],
        ),
    ];
  }

  bool _sameSeriesTopology(
    List<_HistoryCurveSeries> left,
    List<_HistoryCurveSeries> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].values.length != right[index].values.length) {
        return false;
      }
    }
    return true;
  }

  bool _sameSeriesValues(
    List<_HistoryCurveSeries> left,
    List<_HistoryCurveSeries> right,
  ) {
    return _sameSeriesTopology(left, right) &&
        List<bool>.generate(
          left.length,
          (index) => listEquals(left[index].values, right[index].values),
        ).every((same) => same);
  }
}

class _DailyTemperatureChartPainter extends CustomPainter {
  const _DailyTemperatureChartPainter({
    required this.series,
    required this.sampleCapacity,
    required this.selectedIndex,
    required this.minimum,
    required this.maximum,
  });

  final List<_HistoryCurveSeries> series;
  final int sampleCapacity;
  final int? selectedIndex;
  final double minimum;
  final double maximum;

  @override
  void paint(Canvas canvas, Size size) {
    const chartHeight = 534.0;
    const plotTop = 46.0;
    const plotHeight = 488.0;
    final chartWidth = size.width;
    final plotWidth = chartWidth - 35;
    final axisPaint = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 2;
    final gridPaint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1;

    for (final y in <double>[46, 168, 290, 412]) {
      _drawDashedLine(
          canvas, Offset(0, y), Offset(plotWidth + 16, y), gridPaint);
    }
    canvas.drawLine(
        const Offset(0, chartHeight), const Offset(0, 17), axisPaint);
    canvas.drawLine(
      const Offset(0, chartHeight),
      Offset(chartWidth - 17, chartHeight),
      axisPaint,
    );
    final verticalArrow = Path()
      ..moveTo(0, 0)
      ..lineTo(-10, 17)
      ..lineTo(10, 17)
      ..close();
    final horizontalArrow = Path()
      ..moveTo(chartWidth, chartHeight)
      ..lineTo(chartWidth - 17, chartHeight - 10)
      ..lineTo(chartWidth - 17, chartHeight + 10)
      ..close();
    canvas.drawPath(verticalArrow, axisPaint);
    canvas.drawPath(horizontalArrow, axisPaint);

    final pointsBySeries = <List<Offset>>[
      for (final item in series)
        _points(item.values, plotWidth, plotTop, plotHeight),
    ];
    for (var index = 0; index < series.length; index++) {
      final item = series[index];
      _drawSeries(
        canvas,
        pointsBySeries[index],
        item.color,
        item.gradientColor,
        chartHeight,
        plotWidth,
      );
    }
    for (var index = 0; index < series.length; index++) {
      _drawSelectionIndicator(
        canvas,
        series[index],
        pointsBySeries[index],
        chartHeight,
      );
    }
  }

  List<Offset> _points(
    List<double> values,
    double width,
    double top,
    double height,
  ) {
    return <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          width * _trendSampleFraction(index, sampleCapacity),
          top +
              height *
                  (1 -
                      (values[index].clamp(minimum, maximum).toDouble() -
                              minimum) /
                          (maximum - minimum)),
        ),
    ];
  }

  void _drawSeries(
    Canvas canvas,
    List<Offset> points,
    Color color,
    Color gradientColor,
    double bottom,
    double plotWidth,
  ) {
    final line = _smoothPath(points);
    final area = Path.from(line)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    final bounds = Rect.fromLTWH(0, 0, plotWidth, bottom);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          gradientColor.withOpacity(.46),
          gradientColor.withOpacity(.06),
        ],
      ).createShader(bounds);
    canvas.drawPath(area, fillPaint);

    final glowPaint = Paint()
      ..color = color.withOpacity(.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(line, glowPaint);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(line, linePaint);
  }

  void _drawSelectionIndicator(
    Canvas canvas,
    _HistoryCurveSeries item,
    List<Offset> points,
    double bottom,
  ) {
    final pointIndex = selectedIndex == null
        ? points.length - 1
        : selectedIndex!.clamp(0, points.length - 1).toInt();
    final point = points[pointIndex];
    if (selectedIndex != null &&
        pointIndex < points.length - 1 &&
        item.selectionGuideEnabled) {
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, bottom),
        Paint()
          ..color = item.selectionGuideColor
          ..strokeWidth = item.selectionGuideWidth,
      );
    }
    canvas.drawCircle(point, 7, Paint()..color = Colors.white);
    canvas.drawCircle(point, 5, Paint()..color = item.color);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final middleX = (current.dx + next.dx) / 2;
      path.cubicTo(middleX, current.dy, middleX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 7.0;
    const gap = 8.0;
    for (var x = from.dx; x < to.dx; x += dash + gap) {
      canvas.drawLine(
          Offset(x, from.dy), Offset((x + dash).clamp(x, to.dx), to.dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DailyTemperatureChartPainter oldDelegate) {
    return !_sameSeriesValues(oldDelegate.series, series) ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.sampleCapacity != sampleCapacity ||
        oldDelegate.minimum != minimum ||
        oldDelegate.maximum != maximum;
  }

  bool _sameSeriesValues(
    List<_HistoryCurveSeries> left,
    List<_HistoryCurveSeries> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].color != right[index].color ||
          left[index].gradientColor != right[index].gradientColor ||
          left[index].selectionGuideEnabled !=
              right[index].selectionGuideEnabled ||
          left[index].selectionGuideColor != right[index].selectionGuideColor ||
          left[index].selectionGuideWidth != right[index].selectionGuideWidth ||
          !listEquals(left[index].values, right[index].values)) {
        return false;
      }
    }
    return true;
  }
}

String _formatTrendAverage(double value) {
  // 三类趋势的平均值均展示为整数，避免摘要出现无意义小数。
  return (value + 0.000001).round().toString();
}

double _averageTrendValue(
  List<double> values, {
  required int divisor,
}) {
  assert(divisor > 0);
  return values.reduce((total, value) => total + value) / divisor;
}

class _AverageValue extends StatelessWidget {
  const _AverageValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: AppFonts.harmonyLight,
                    fontSize: 60,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 4),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontFamily: AppFonts.sourceHanSansSc,
                      fontVariations: AppFonts.sourceHanSansScRegularWght400,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatefulWidget {
  const _HistoryChart({
    Key? key,
    required this.unit,
    required this.series,
    required this.sampleCapacity,
    required this.horizontalLabels,
    required this.horizontalTitle,
    required this.horizontalUnit,
  }) : super(key: key);

  final String unit;
  final List<_HistoryCurveSeries> series;
  final int sampleCapacity;
  final List<String> horizontalLabels;
  final String horizontalTitle;
  final String horizontalUnit;

  @override
  State<_HistoryChart> createState() => _HistoryChartState();
}

class _HistoryCo2ChartTitle extends StatelessWidget {
  const _HistoryCo2ChartTitle({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xB3FFFFFF);
    return SizedBox(
      key: const ValueKey<String>('history-co2-chart-title'),
      width: 180,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Text(
            'CO',
            style: TextStyle(
              color: color,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: 28,
              height: 1,
            ),
          ),
          const Positioned(
            left: 40.9,
            top: 17.2,
            child: Text(
              '2',
              style: TextStyle(
                color: color,
                fontFamily: AppFonts.harmonyRegular,
                fontSize: 17.2,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 64,
            top: 0,
            child: Text(
              unit,
              style: const TextStyle(
                color: color,
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 28,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChartState extends State<_HistoryChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sampleCapacity != widget.sampleCapacity ||
        !_sameSeriesTopology(oldWidget.series, widget.series)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 50,
          top: 4,
          child: _HistoryCo2ChartTitle(unit: widget.unit),
        ),
        Positioned(
          left: 0,
          top: 80,
          child: SizedBox(
            width: 1140,
            height: 560,
            child: GestureDetector(
              key: const ValueKey<String>('co2-trend-selection-surface'),
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => _selectAt(details.localPosition.dx),
              onPanUpdate: (details) => _selectAt(details.localPosition.dx),
              child: RepaintBoundary(
                key: ValueKey<String>(
                  _trendSelectionKey(
                    'co2-trend-selection',
                    _selectedIndex,
                    _valueCount,
                  ),
                ),
                child: CustomPaint(
                  key: ValueKey<String>(
                    'co2-history-chart-${widget.series.length}',
                  ),
                  painter: _HistoryChartPainter(
                    series: widget.series,
                    sampleCapacity: widget.sampleCapacity,
                    selectedIndex: _selectedIndex,
                    horizontalLabels: widget.horizontalLabels,
                    horizontalTitle: widget.horizontalTitle,
                    horizontalUnit: widget.horizontalUnit,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectAt(double localDx) {
    final valueCount = _valueCount;
    if (valueCount == 0) {
      return;
    }
    final selectedIndex = _trendSelectionIndex(
      localDx: localDx,
      plotLeft: 90,
      plotWidth: 1140 - 90 - 22,
      sampleCapacity: widget.sampleCapacity,
      valueCount: valueCount,
    );
    if (_selectedIndex != selectedIndex) {
      setState(() => _selectedIndex = selectedIndex);
    }
  }

  int get _valueCount => widget.series.fold<int>(
        0,
        (maximum, item) =>
            item.values.length > maximum ? item.values.length : maximum,
      );

  bool _sameSeriesTopology(
    List<_HistoryCurveSeries> left,
    List<_HistoryCurveSeries> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].values.length != right[index].values.length) {
        return false;
      }
    }
    return true;
  }
}

class _HistoryChartPainter extends CustomPainter {
  const _HistoryChartPainter({
    required this.series,
    required this.sampleCapacity,
    required this.selectedIndex,
    required this.horizontalLabels,
    required this.horizontalTitle,
    required this.horizontalUnit,
  });

  final List<_HistoryCurveSeries> series;
  final int sampleCapacity;
  final int? selectedIndex;
  final List<String> horizontalLabels;
  final String horizontalTitle;
  final String horizontalUnit;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 90.0;
    const top = 20.0;
    final width = size.width - left - 22;
    final height = size.height - 92;
    final bottom = top + height;
    final gridPaint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 2;
    const labelStyle = TextStyle(
      color: Color(0x99FFFFFF),
      fontFamily: AppFonts.sourceHanSansSc,
      fontVariations: AppFonts.sourceHanSansScRegularWght400,
      fontSize: 26,
    );
    const verticalLabels = <String>['800', '600', '400', '200', '0'];
    for (var i = 0; i < verticalLabels.length; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
      _paintText(
        canvas,
        verticalLabels[i],
        Offset(10, y - 17),
        labelStyle,
      );
    }
    canvas.drawLine(
      Offset(left, bottom),
      const Offset(left, 17),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + width - 17, bottom),
      axisPaint,
    );
    final verticalArrow = Path()
      ..moveTo(left, 0)
      ..lineTo(left - 10, 17)
      ..lineTo(left + 10, 17)
      ..close();
    final horizontalArrow = Path()
      ..moveTo(left + width, bottom)
      ..lineTo(left + width - 17, bottom - 10)
      ..lineTo(left + width - 17, bottom + 10)
      ..close();
    canvas.drawPath(verticalArrow, axisPaint);
    canvas.drawPath(horizontalArrow, axisPaint);
    for (var i = 0; i < horizontalLabels.length; i++) {
      final monthDay = sampleCapacity == _monthlySampleCapacity
          ? int.tryParse(horizontalLabels[i])
          : null;
      final x = monthDay == null
          ? left + width * i / (horizontalLabels.length - 1)
          : left + width * DashboardData.monthlyTrendDayFraction(monthDay);
      _paintText(
        canvas,
        horizontalLabels[i],
        Offset(x - 15, top + height + 24),
        labelStyle,
      );
    }
    _paintText(
      canvas,
      '$horizontalTitle $horizontalUnit',
      Offset(left + width + 6, bottom - 34),
      labelStyle,
    );

    final pointsBySeries = <List<Offset>>[
      for (final item in series)
        _curvePoints(item.values, left, top, width, height),
    ];
    for (var index = 0; index < series.length; index++) {
      final item = series[index];
      _drawCurve(
        canvas,
        pointsBySeries[index],
        left,
        top,
        width,
        height,
        item.color,
        item.gradientColor,
      );
    }
    for (var index = 0; index < series.length; index++) {
      _drawSelectionIndicator(
        canvas,
        series[index],
        pointsBySeries[index],
        top,
        height,
      );
    }
  }

  List<Offset> _curvePoints(
    List<double> values,
    double left,
    double top,
    double width,
    double height,
  ) {
    return <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          left + width * _trendSampleFraction(index, sampleCapacity),
          top + height * (1 - values[index].clamp(0, 800) / 800),
        ),
    ];
  }

  void _drawCurve(
    Canvas canvas,
    List<Offset> points,
    double left,
    double top,
    double width,
    double height,
    Color color,
    Color gradientColor,
  ) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }

    // 与温湿度、PM2.5 趋势一致：曲线下方做由实到透明的渐变填充。
    final area = Path.from(path)
      ..lineTo(points.last.dx, top + height)
      ..lineTo(points.first.dx, top + height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          gradientColor.withOpacity(.42),
          gradientColor.withOpacity(.05),
        ],
      ).createShader(Rect.fromLTWH(left, top, width, height));
    canvas.drawPath(area, fillPaint);

    final glowPaint = Paint()
      ..color = color.withOpacity(.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
    canvas.drawPath(path, glowPaint);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawSelectionIndicator(
    Canvas canvas,
    _HistoryCurveSeries item,
    List<Offset> points,
    double top,
    double height,
  ) {
    final pointIndex = selectedIndex == null
        ? points.length - 1
        : selectedIndex!.clamp(0, points.length - 1).toInt();
    final point = points[pointIndex];
    if (selectedIndex != null &&
        pointIndex < points.length - 1 &&
        item.selectionGuideEnabled) {
      canvas.drawLine(
        Offset(point.dx, top),
        Offset(point.dx, top + height),
        Paint()
          ..color = item.selectionGuideColor
          ..strokeWidth = item.selectionGuideWidth,
      );
    }
    canvas.drawCircle(point, 7, Paint()..color = Colors.white);
    canvas.drawCircle(point, 5, Paint()..color = item.color);
  }

  void _paintText(
    Canvas canvas,
    String value,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_HistoryChartPainter oldDelegate) =>
      !_sameSeriesValues(oldDelegate.series, series) ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.sampleCapacity != sampleCapacity ||
      !listEquals(oldDelegate.horizontalLabels, horizontalLabels) ||
      oldDelegate.horizontalTitle != horizontalTitle ||
      oldDelegate.horizontalUnit != horizontalUnit;

  bool _sameSeriesValues(
    List<_HistoryCurveSeries> left,
    List<_HistoryCurveSeries> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].color != right[index].color ||
          left[index].gradientColor != right[index].gradientColor ||
          left[index].selectionGuideEnabled !=
              right[index].selectionGuideEnabled ||
          left[index].selectionGuideColor != right[index].selectionGuideColor ||
          left[index].selectionGuideWidth != right[index].selectionGuideWidth ||
          !listEquals(left[index].values, right[index].values)) {
        return false;
      }
    }
    return true;
  }
}
