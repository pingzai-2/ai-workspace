import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../models/weather_presentation.dart';
import '../../services/time_source.dart';
import '../../theme/app_fonts.dart';

/// 空闲待机页。
///
/// 时间来自设备本地时间；环境与天气数据只读复用主页已经确认的运行快照，
/// 不在本页面读取、修改或保存 JSON。
class IdlePage extends StatefulWidget {
  const IdlePage({
    Key? key,
    required this.data,
    required this.timeSource,
    this.use24HourFormat = true,
    this.animateWeather = true,
  }) : super(key: key);

  final DashboardData data;
  final TimeSource timeSource;
  final bool use24HourFormat;
  final bool animateWeather;

  @override
  State<IdlePage> createState() => _IdlePageState();
}

class _IdlePageState extends State<IdlePage> {
  Timer? _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.timeSource.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = widget.timeSource.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final displayHour =
        widget.use24HourFormat ? _now.hour : ((_now.hour + 11) % 12) + 1;
    final hour = displayHour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final month = _now.month.toString().padLeft(2, '0');
    final day = _now.day.toString().padLeft(2, '0');
    final weather = WeatherPresentation.fromCode(widget.data.weatherCode);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          if (!widget.use24HourFormat)
            Positioned(
              // 与 Figma 设计一致：上午 y=202，下午 y=263。
              left: 233,
              top: _now.hour < 12 ? 202 : 263,
              child: Text(
                _now.hour < 12 ? l10n.am : l10n.pm,
                style: const TextStyle(
                  color: Color(0xFFF4F4F4),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 28,
                  height: 1,
                ),
              ),
            ),
          Positioned(
            left: 301,
            top: 193,
            child: Text(
              '$hour:$minute',
              style: const TextStyle(
                color: Color(0xFFF4F4F4),
                fontFamily: AppFonts.harmonyLight,
                fontSize: 120,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 655,
            top: 208,
            child: Text(
              DateFormat.EEEE(locale).format(_now),
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 32,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 655,
            top: 262,
            child: Text(
              '${_now.year}/$month/$day',
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.harmonyLight,
                fontSize: 32,
                height: 1,
              ),
            ),
          ),
          if (widget.data.effectiveWifiConnected) ...<Widget>[
            Positioned(
              left: 1467,
              top: 189,
              width: 120,
              height: 120,
              child: Image.asset(
                widget.animateWeather
                    ? weather.gifAssetPath
                    : weather.pngAssetPath,
                key: const ValueKey<String>('idle-weather-artwork'),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                // 母版天气 GIF 为 512×512，待机页只显示 120×120。
                // 按显示尺寸解码，减少旧嵌入式 GPU/DDR 的纹理压力。
                cacheWidth: 120,
                cacheHeight: 120,
              ),
            ),
            Positioned(
              left: 1607,
              top: 215,
              width: 250,
              child: Text(
                weather.localizedLabel(l10n),
                key: const ValueKey<String>('idle-weather-label'),
                style: const TextStyle(
                  color: Color(0xFFF4F4F4),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 32,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: 1607,
              top: 260,
              width: 250,
              child: Text(
                widget.data.displayWeatherTemperatureRange.replaceAll('～', '~'),
                key: const ValueKey<String>('idle-weather-range'),
                style: const TextStyle(
                  color: Color(0xFFF4F4F4),
                  fontFamily: AppFonts.harmonyLight,
                  fontSize: 32,
                  height: 1,
                ),
              ),
            ),
          ],
          Positioned(
            left: 170,
            top: 450,
            child: _IdleAirCard.indoor(data: widget.data, l10n: l10n),
          ),
          Positioned(
            left: 976,
            top: 450,
            child: _IdleAirCard.outdoor(data: widget.data, l10n: l10n),
          ),
          Positioned(
            left: 360,
            top: 1085,
            width: 1200,
            child: Text(
              _airAdvice(widget.data, l10n),
              key: const ValueKey<String>('idle-air-advice'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 30,
                height: 43 / 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _airAdvice(DashboardData data, AppLocalizations l10n) {
    if (data.backendDataStatus == 'stale') {
      return l10n.idleNoData;
    }

    // PM2.5 分档：优/良 ≤ 35，中度 36~75，重度 > 75
    final indoorGood = data.indoorPm25 <= 35;
    final indoorModerate = data.indoorPm25 > 35 && data.indoorPm25 <= 75;
    final indoorBad = data.indoorPm25 > 75;

    final outdoorModerate =
        data.outdoorPm25 > 35 && data.outdoorPm25 <= 75;
    final outdoorBad = data.outdoorPm25 > 75;

    if (indoorGood && outdoorModerate) {
      return l10n.idleAdviceGoodFair;
    }
    if (indoorGood && outdoorBad) {
      return l10n.idleAdviceGoodPoor;
    }
    if (indoorModerate && outdoorModerate) {
      return l10n.idleAdviceFairFair;
    }
    if (indoorModerate && outdoorBad) {
      return l10n.idleAdviceFairPoor;
    }
    if (indoorBad && outdoorModerate) {
      return l10n.idleAdvicePoorFair;
    }
    if (indoorBad && outdoorBad) {
      return l10n.idleAdvicePoorPoor;
    }

    // 剩余情况：室外优/良，或室内外均优/良
    if (data.indoorPm25 > 75 && data.outdoorPm25 < data.indoorPm25) {
      return l10n.idleAdviceOutdoorBetter;
    }
    return l10n.idleAdviceGoodGood;
  }
}

class _IdleAirCard extends StatelessWidget {
  const _IdleAirCard._({
    required this.pm25,
    required this.pm25Display,
    required this.iconAsset,
    required this.title,
    required this.metrics,
    required this.useCloseReflection,
  });

  factory _IdleAirCard.indoor({
    required DashboardData data,
    required AppLocalizations l10n,
  }) {
    return _IdleAirCard._(
      pm25: data.backendDataStatus != 'stale' ? data.indoorPm25 : 0,
      pm25Display: data.displayIndoorPm25,
      iconAsset: 'assets/idle/indoor.png',
      title: l10n.floorIndoor,
      useCloseReflection: true,
      metrics: <_IdleMetricData>[
        // 设计稿 1-31：左→中→右 为 温度→湿度→CO₂
        _IdleMetricData(l10n.metricTemperature, data.displayIndoorTemperatureC, '℃'),
        _IdleMetricData(l10n.metricHumidity, data.displayIndoorHumidityPercent, '%'),
        _IdleMetricData('CO2', data.displayIndoorCo2Ppm, 'ppm'),
      ],
    );
  }

  factory _IdleAirCard.outdoor({
    required DashboardData data,
    required AppLocalizations l10n,
  }) {
    return _IdleAirCard._(
      pm25: data.backendDataStatus != 'stale' ? data.outdoorPm25 : 0,
      pm25Display: data.displayOutdoorPm25,
      iconAsset: 'assets/idle/outdoor.png',
      title: l10n.idleOutdoor,
      useCloseReflection: true,
      metrics: <_IdleMetricData>[
        _IdleMetricData(l10n.metricTemperature, data.displayOutdoorTemperatureC, '℃'),
        _IdleMetricData(l10n.metricHumidity, data.displayOutdoorHumidityPercent, '%'),
      ],
    );
  }

  final int pm25;
  final String pm25Display;
  final String iconAsset;
  final String title;
  final List<_IdleMetricData> metrics;
  final bool useCloseReflection;

  @override
  Widget build(BuildContext context) {
    final level = _AirQualityLevel.fromPm25(pm25);
    // 设计稿 1-31：三列中心为 157.2/386/614.2，两列中心为 285.2/509.2
    final metricWidth = metrics.length == 3 ? 228.5 : 224.0;
    final metricsLeft = metrics.length == 3 ? 43.0 : 173.2;

    return SizedBox(
      width: 774,
      height: 550,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          // Figma `1:33` / `1:52` 的卡片背景是纯色 #171717，描边
          // opacity 为 0；直接绘制，避免为纯色背景解码 PNG。
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: -21,
            width: 774,
            height: level.blurHeight,
            child: Image.asset(
              level.blurAsset,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
          ),
          // 四档 blurbg PNG 使用同一叠加规则：第一层 100%，第二层 30%。
          Positioned(
            left: 0,
            top: -21,
            width: 774,
            height: level.blurHeight,
            child: Opacity(
              opacity: .3,
              child: Image.asset(
                level.blurAsset,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 2,
            width: 774,
            height: 3,
            child: Image.asset(level.lineAsset, fit: BoxFit.fill),
          ),
          Positioned(
            left: 680,
            top: 18,
            width: 75,
            height: 75,
            child: Image.asset(iconAsset, fit: BoxFit.contain),
          ),
          Positioned(
            left: 693,
            top: 86.8736,
            width: 49,
            height: 34.95,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF4F4F4),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 24.3,
                height: 34.95 / 24.3,
              ),
            ),
          ),
          const Positioned(
            left: 132,
            top: 120,
            child: Text(
              'PM2.5',
              style: TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 26,
                height: 38 / 26,
              ),
            ),
          ),
          Positioned(
            left: 115,
            top: 96,
            width: 544,
            height: 190,
            child: _CenteredReading(
              value: pm25Display,
              unit: 'ug/m³',
              valueColor: level.color,
              unitColor: const Color(0xB3FFFFFF),
              valueSize: 162,
              unitSize: 24,
              gap: 24,
              valueTop: 21,
            ),
          ),
          Positioned(
            left: 115,
            top: useCloseReflection ? 197 : 259,
            width: 544,
            height: useCloseReflection ? 230 : 104,
            child: _ReflectedReading(
              value: pm25Display,
              color: level.color,
              extendFade: useCloseReflection,
            ),
          ),
          for (var index = 0; index < metrics.length; index++) ...<Widget>[
            Positioned(
              left: metricsLeft + metricWidth * index,
              top: 358,
              width: metricWidth,
              child: metrics[index].label == 'CO2'
                  ? const _Co2Label()
                  : Text(
                      metrics[index].label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontFamily: AppFonts.sourceHanSansSc,
                        fontVariations: AppFonts.sourceHanSansScRegularWght400,
                        fontSize: 26,
                        height: 38 / 26,
                      ),
                    ),
            ),
            Positioned(
              left: metricsLeft + metricWidth * index,
              top: 399,
              width: metricWidth,
              height: 100,
              child: _CenteredReading(
                value: metrics[index].value,
                unit: metrics[index].unit,
                valueColor: const Color(0xFFF4F4F4),
                unitColor: const Color(0xB3FFFFFF),
                valueSize: 56,
                unitSize: 24,
                gap: 8,
                unitBelow: true,
                valueTop: 5,
              ),
            ),
          ],
          if (metrics.length == 3) ...<Widget>[
            _metricDivider(271),
            _metricDivider(504),
          ] else
            _metricDivider(399),
        ],
      ),
    );
  }

  Widget _metricDivider(double left) => Positioned(
        left: left,
        top: 369,
        width: 1,
        height: 126,
        child: const ColoredBox(color: Color(0x40FFFFFF)),
      );
}

class _IdleMetricData {
  const _IdleMetricData(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;
}

class _Co2Label extends StatelessWidget {
  const _Co2Label();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 52,
        height: 38,
        child: Stack(
          children: const <Widget>[
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(
                'CO',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 26,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: 38,
              bottom: 0,
              child: Text(
                '2',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontFamily: AppFonts.harmonyRegular,
                  fontSize: 15,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredReading extends StatelessWidget {
  const _CenteredReading({
    required this.value,
    required this.unit,
    required this.valueColor,
    required this.unitColor,
    required this.valueSize,
    required this.unitSize,
    required this.gap,
    this.unitBelow = false,
    this.valueTop = 0,
  });

  final String value;
  final String unit;
  final Color valueColor;
  final Color unitColor;
  final double valueSize;
  final double unitSize;
  final double gap;
  final bool unitBelow;
  final double valueTop;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      color: valueColor,
      fontFamily:
          valueSize >= 100 ? AppFonts.harmonyLight : AppFonts.harmonyRegular,
      fontSize: valueSize,
      height: 1,
    );
    final unitStyle = TextStyle(
      color: unitColor,
      fontFamily: AppFonts.harmonyRegular,
      fontSize: unitSize,
      height: 1,
    );
    final valuePainter = TextPainter(
      text: TextSpan(text: value, style: valueStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return LayoutBuilder(
      builder: (context, constraints) {
        final valueLeft = (constraints.maxWidth - valuePainter.width) / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: valueLeft,
              top: valueTop,
              child: Text(value, style: valueStyle),
            ),
            if (unitBelow)
              Positioned(
                left: 0,
                right: 0,
                top: 71,
                child:
                    Text(unit, textAlign: TextAlign.center, style: unitStyle),
              )
            else
              Positioned(
                left: valueLeft + valuePainter.width + gap,
                top: 132,
                child: Text(unit, style: unitStyle),
              ),
          ],
        );
      },
    );
  }
}

class _ReflectedReading extends StatelessWidget {
  const _ReflectedReading({
    required this.value,
    required this.color,
    required this.extendFade,
  });

  final String value;
  final Color color;
  final bool extendFade;

  @override
  Widget build(BuildContext context) {
    final reflectedText = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1, -1, 1),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: AppFonts.harmonyLight,
          fontSize: 162,
          height: 1,
        ),
      ),
    );
    return ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: extendFade ? 190 : 104,
            child: Opacity(
              opacity: .24,
              child: reflectedText,
            ),
          ),
          // 卡片底色为固定深灰；覆盖一层同色渐变即可形成向下消失的
          // 倒影，不使用 dstIn，避免某些旧版 Flutter 软件渲染器污染整帧 alpha。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: extendFade
                      ? const <Color>[
                          Color(0x00171717),
                          Color(0x00171717),
                          Color(0xFF171717),
                        ]
                      : const <Color>[
                          Color(0x00171717),
                          Color(0xFF171717),
                        ],
                  stops: extendFade
                      ? const <double>[0, .24, .65]
                      : const <double>[0, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirQualityLevel {
  const _AirQualityLevel(this.index, this.color);

  final int index;
  final Color color;

  String get blurAsset => 'assets/idle/blurbg-l$index.png';
  String get lineAsset => 'assets/idle/topline$index.png';
  double get blurHeight => 83;

  factory _AirQualityLevel.fromPm25(int value) {
    if (value <= 35) {
      return const _AirQualityLevel(1, Color(0xFF00C853));
    }
    if (value <= 75) {
      return const _AirQualityLevel(2, Color(0xFFC6E600));
    }
    if (value <= 150) {
      return const _AirQualityLevel(3, Color(0xFFF8B62D));
    }
    // 第 4 档以最新切图 topline4.png 的中心像素为准：
    // srgba(239, 68, 68, 0.749)，保证数字、单位、倒影与顶部条纹一致。
    return const _AirQualityLevel(4, Color(0xBFEF4444));
  }
}
