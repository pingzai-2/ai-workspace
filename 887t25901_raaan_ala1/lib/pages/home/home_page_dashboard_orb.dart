part of 'home_page.dart';

class _AirQualityOrb extends StatelessWidget {
  const _AirQualityOrb({required this.value, required this.animate});

  final String value;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 366,
      // 使用和实际控件尺寸一致的 GIF，避免无谓的高分辨率帧解码与缓存。
      height: animate ? 366 : 326,
      child: Stack(
        children: <Widget>[
          if (animate)
            Positioned(
              left: 0,
              top: 0,
              width: 366,
              height: 366,
              child: Image.asset(
                'assets/home/pm25_orb/dynamic_gif/pm25_orb_1x.gif',
                key: const ValueKey<String>('air-quality-orb-artwork'),
                fit: BoxFit.fill,
                gaplessPlayback: true,
                // 明确按控件尺寸解码，限制动画帧进入缓存时的像素量。
                cacheWidth: 366,
                cacheHeight: 366,
              ),
            ),
          // Golden 和禁用动效的场景保持原有确定性画面；工程原 PNG
          // pm25_orb/static_png/pm25_orb.png 作为完整静态素材保留，
          // 不拿它重写现有基准图。
          if (!animate) ...const <Widget>[
            Positioned(left: 39, top: 47, child: _OrbBack()),
            Positioned(left: 77, top: 47, child: _OrbBack()),
            Positioned(left: 58, top: 17, child: _OrbBack()),
          ],
          Positioned(
            left: 68,
            top: 48,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xE673D1E4), Color(0xE64B95A4)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const Positioned(
                    top: 30,
                    child: Text(
                      'PM2.5',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.sourceHanSansSc,
                        fontVariations: AppFonts.sourceHanSansScRegularWght400,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  Positioned(
                    // Figma 1:2581: 28 is (60,65), 111×117. Do not
                    // compress HarmonyOS Sans Light line metrics here.
                    top: 65,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.harmonyLight,
                        fontSize: 100,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 172,
                    child: Text(
                      'ug/m³',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontFamily: AppFonts.harmonyRegular,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbBack extends StatelessWidget {
  const _OrbBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: const BoxDecoration(
        color: Color(0x3373D1E4),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _IndoorMetrics extends StatelessWidget {
  const _IndoorMetrics({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Figma node 1:2557 and direct text children 1:2560–1:2573.
    return SizedBox(
      width: 626,
      height: 188,
      child: Stack(
        children: <Widget>[
          // Latest Figma cache nodes 1:334–1:337: both indoor columns use
          // 260 px dividers centered at y=67 and y=187. A 2 px Flutter box
          // starts one pixel above the design center so the bottom pair stays
          // inside this widget instead of being clipped at its lower edge.
          for (final left in const <double>[0, 366])
            for (final top in const <double>[66, 186])
              Positioned(
                key: ValueKey<String>(
                  'indoor-metric-divider-${left.toInt()}-${top.toInt()}',
                ),
                left: left,
                top: top,
                child: Container(
                  width: 260,
                  height: 2,
                  color: const Color(0x40FFFFFF),
                ),
              ),
          _IndoorMetricText.label(
            left: 3,
            top: 21,
            text: l10n.metricTemperature,
          ),
          _IndoorMetricText.value(
            left: 75,
            top: 0,
            width: 92,
            text: data.displayIndoorTemperatureC,
          ),
          const _IndoorMetricText.unit(left: 185, top: 30, text: '℃'),
          // 湿度移至右上（原 CO₂ 位置）
          _IndoorMetricText.label(
            left: 371,
            top: 21,
            text: l10n.metricHumidity,
          ),
          _IndoorMetricText.value(
            left: 435,
            top: 0,
            width: 92,
            text: data.displayIndoorHumidityPercent,
          ),
          const _IndoorMetricText.unit(left: 555, top: 30, text: '%'),
          // CO₂ 移至左下（原湿度位置）
          const _IndoorCo2Label(),
          _IndoorMetricText.value(
            left: 75,
            top: 120,
            width: 126,
            text: data.displayIndoorCo2Ppm,
          ),
          const _IndoorMetricText.unit(left: 219, top: 151, text: 'ppm'),
          _IndoorMetricText.label(
            left: 371,
            top: 141,
            text: l10n.metricFormaldehyde,
          ),
          _IndoorMetricText.value(
            left: 435,
            top: 120,
            width: 110,
            text: data.displayIndoorFormaldehydeMgM3,
          ),
          const _IndoorMetricText.unit(left: 555, top: 151, text: 'mg/m³'),
        ],
      ),
    );
  }
}

class _IndoorMetricText extends StatelessWidget {
  const _IndoorMetricText._({
    required this.left,
    required this.top,
    required this.text,
    required this.style,
    this.width,
  });

  const _IndoorMetricText.label({
    required double left,
    required double top,
    required String text,
  }) : this._(
          left: left,
          top: top,
          text: text,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontFamily: AppFonts.sourceHanSansSc,
            fontVariations: AppFonts.sourceHanSansScRegularWght400,
            fontSize: 26,
          ),
        );

  const _IndoorMetricText.value({
    required double left,
    required double top,
    required String text,
    required double width,
  }) : this._(
          left: left,
          top: top,
          text: text,
          width: width,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.harmonyLight,
            fontSize: 56,
          ),
        );

  const _IndoorMetricText.unit({
    required double left,
    required double top,
    required String text,
  }) : this._(
          left: left,
          top: top,
          text: text,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontFamily: AppFonts.harmonyRegular,
            fontSize: 24,
          ),
        );

  final double left;
  final double top;
  final String text;
  final TextStyle style;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final child = width != null
        ? SizedBox(
            width: width,
            child: Text(
              text,
              style: style,
              textAlign: TextAlign.right,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          )
        : Text(text, style: style);
    return Positioned(left: left, top: top, child: child);
  }
}

/// Figma node 964:6335 的 CO₂ 标签：CO (26px) 与 2 (15px) 内联排列，
/// 下标 "2" 基线对齐 "CO" 基线，使用 Source Han Sans SC Regular。
class _IndoorCo2Label extends StatelessWidget {
  const _IndoorCo2Label();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 3,
      top: 141,
      child: CustomPaint(
        size: Size(44, 38),
        painter: _IndoorCo2Painter(),
      ),
    );
  }
}

class _IndoorCo2Painter extends CustomPainter {
  const _IndoorCo2Painter();

  static const Color _color = Color(0xB3FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    _textPainter('CO', 26).paint(canvas, Offset.zero);
    // Figma 964:6335："2" 为 15px，下标基线略低于 "CO" 基线。
    _textPainter('2', 15).paint(canvas, const Offset(35.04, 16));
  }

  TextPainter _textPainter(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _color,
          fontFamily: AppFonts.sourceHanSansSc,
          fontVariations: AppFonts.sourceHanSansScRegularWght400,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  @override
  bool shouldRepaint(covariant _IndoorCo2Painter oldDelegate) => false;
}
