part of 'home_page.dart';

class _WeatherPanel extends StatelessWidget {
  const _WeatherPanel({
    required this.data,
    required this.animateWeather,
    required this.timeSource,
  });

  final DashboardData data;
  final bool animateWeather;
  final TimeSource timeSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weather = WeatherPresentation.fromCode(data.weatherCode);
    return Container(
      width: 554,
      height: 604,
      decoration: BoxDecoration(
        color: const Color(0xB3171717),
        borderRadius: BorderRadius.circular(2),
      ),
      // Figma node 1:2536 and direct children 1:2537–1:2554.
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 32,
            top: 36,
            child: Text(data.areaName, style: _weatherSmall),
          ),
          Positioned(
            left: 308,
            top: 36,
            width: 214,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(_formattedDate(context), style: _weatherSmall),
            ),
          ),
          if (data.effectiveWifiConnected) ...<Widget>[
            Positioned(
              left: 217,
              top: 110,
              width: 120,
              height: 120,
              child: Image.asset(
                animateWeather ? weather.gifAssetPath : weather.pngAssetPath,
                key: const ValueKey<String>('weather-artwork'),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                // 天气 GIF 母版为高分辨率素材，界面实际只显示 120×120。
                // 这里只引用当前 weatherCode 对应的 GIF，并按控件尺寸解码，
                // 避免嵌入式设备保留整张大图。
                cacheWidth: 120,
                cacheHeight: 120,
              ),
            ),
            Positioned(
              left: 137,
              top: 265,
              width: 280,
              child: Text(
                weather.localizedLabel(l10n),
                key: const ValueKey<String>('weather-label'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 32,
                ),
              ),
            ),
            Positioned(
              left: 137,
              top: 314,
              width: 280,
              child: Text(
                data.displayWeatherTemperatureRange,
                key: const ValueKey<String>('weather-temperature-range'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.harmonyRegular,
                  fontSize: 32,
                ),
              ),
            ),
          ],
          _WeatherMetric(
            top: 402,
            label: l10n.metricTemperature,
            value: data.displayOutdoorTemperatureC,
            unit: '℃',
            valueTopOffset: 2,
            unitTopOffset: 6,
            unitLeft: 420,
          ),
          _WeatherMetric(
            top: 462,
            label: l10n.metricHumidity,
            value: data.displayOutdoorHumidityPercent,
            unit: '%',
            valueTopOffset: 1,
            unitTopOffset: 5,
            unitLeft: 420,
          ),
          _WeatherMetric(
            top: 522,
            label: l10n.metricPm25,
            value: data.displayOutdoorPm25,
            unit: 'ug/m³',
            valueLeft: 291,
            unitLeft: 375,
            valueWidth: 66,
            valueTopOffset: 0,
            unitTopOffset: 3,
          ),
          // User visual adjustment: move all three outdoor dividers down 2 px
          // without changing the surrounding labels, values or line style.
          for (final top in const <double>[444, 504, 564])
            Positioned(
              key: ValueKey<String>(
                'outdoor-metric-divider-${top.toInt()}',
              ),
              left: 123,
              top: top,
              child: Container(
                width: 309,
                height: 1,
                color: const Color(0x40FFFFFF),
              ),
            ),
        ],
      ),
    );
  }

  String _formattedDate(BuildContext context) {
    final now = timeSource.now();
    final locale = Localizations.localeOf(context).toString();
    // Figma 1:2553 keeps three literal spaces before the weekday.
    return '${DateFormat('yyyy/MM/dd', locale).format(now)}   '
        '${DateFormat.E(locale).format(now)}';
  }
}

const TextStyle _weatherSmall = TextStyle(
  color: Color(0xD9FFFFFF),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 24,
);

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.top,
    required this.label,
    required this.value,
    required this.unit,
    this.valueLeft = 340,
    this.unitLeft = 405,
    this.valueWidth = 61,
    this.valueTopOffset = 0,
    this.unitTopOffset = 4,
  });

  final double top;
  final String label;
  final String value;
  final String unit;
  final double valueLeft;
  final double unitLeft;
  final double valueWidth;
  final double valueTopOffset;
  final double unitTopOffset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 128,
          top: top,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: 26,
            ),
          ),
        ),
        Positioned(
          left: valueLeft,
          top: top + valueTopOffset,
          child: SizedBox(
            width: valueWidth,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: AppFonts.harmonyRegular,
                fontSize: 36,
              ),
              textAlign: TextAlign.right,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
        Positioned(
          left: unitLeft,
          top: top + unitTopOffset,
          child: Text(
            unit,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontFamily: AppFonts.harmonyRegular,
              fontSize: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// 红点由 runtime 的通知列表派生；数字是当前通知条数。
class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/home/top/notification_badge.png',
            fit: BoxFit.contain,
          ),
          if (count > 0)
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.harmonyRegular,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
