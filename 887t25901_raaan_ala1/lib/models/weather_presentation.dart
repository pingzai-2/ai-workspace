import '../l10n/app_localizations.dart';

/// 由 weatherCode 唯一确定的天气展示信息。
///
/// 天气名称、GIF、PNG、动态 SVG 和静态 SVG 是同一个天气语义的不同素材形态，
/// 必须共用这一份映射，不能各自维护另一套编号或名称。
/// 温度范围不在此处处理，仍由 dashboard_runtime.json 的
/// weatherTemperatureRange 独立提供。
class WeatherPresentation {
  const WeatherPresentation._({
    required this.code,
    required this.label,
  });

  static const String fallbackCode = '01_clear_day';

  static const Map<String, String> _labels = <String, String>{
    '01_clear_day': '晴',
    '02_clear_night': '晴夜',
    '03_mostly_clear_day': '晴间多云',
    '04_overcast': '阴',
    '05_cloudy': '多云',
    '06_drizzle': '毛毛雨',
    '07_middle_rain': '中雨',
    '08_heavy_rain': '大雨',
    '09_extreme_rain': '暴雨',
    '10_mostly_clear_day_rain': '晴间多云有雨',
    '11_thunderstorms_rain': '雷阵雨',
    '12_drizzle_to_middle_rain': '小到中雨',
    '13_middle_to_heavy_rain': '中到大雨',
    '14_light_snow': '小雪',
    '15_moderate_snow': '中雪',
    '16_heavy_snow': '大雪',
    '17_wind_snow': '风雪',
    '18_sleet': '雨夹雪',
    '19_fog': '雾',
    '20_haze': '霾',
    '21_dust': '浮尘',
    '22_dust_day': '扬沙',
    '23_wind': '大风',
    '24_cyclone': '台风',
    '25_hail': '冰雹',
    '26_thermometer_warmer': '高温',
    '27_thermometer_colder': '低温',
    '28_weather_alert': '天气预警',
    '29_extreme_snow': '暴雪',
    '30_code_orange': '橙色预警',
    '31_code_red': '红色预警',
  };

  final String code;
  final String label;

  /// 根据当前语言返回天气名称；未知 code 回退中文 label。
  String localizedLabel(AppLocalizations l10n) {
    switch (code) {
      case '01_clear_day':
        return l10n.weatherSunny;
      case '02_clear_night':
        return l10n.weatherClearNight;
      case '03_mostly_clear_day':
        return l10n.weatherMostlyClear;
      case '04_overcast':
        return l10n.weatherOvercast;
      case '05_cloudy':
        return l10n.weatherCloudy;
      case '06_drizzle':
        return l10n.weatherDrizzle;
      case '07_middle_rain':
        return l10n.weatherMiddleRain;
      case '08_heavy_rain':
        return l10n.weatherHeavyRain;
      case '09_extreme_rain':
        return l10n.weatherExtremeRain;
      case '10_mostly_clear_day_rain':
        return l10n.weatherMostlyClearRain;
      case '11_thunderstorms_rain':
        return l10n.weatherThunderstorms;
      case '12_drizzle_to_middle_rain':
        return l10n.weatherDrizzleToMiddleRain;
      case '13_middle_to_heavy_rain':
        return l10n.weatherMiddleToHeavyRain;
      case '14_light_snow':
        return l10n.weatherLightSnow;
      case '15_moderate_snow':
        return l10n.weatherModerateSnow;
      case '16_heavy_snow':
        return l10n.weatherHeavySnow;
      case '17_wind_snow':
        return l10n.weatherWindSnow;
      case '18_sleet':
        return l10n.weatherSleet;
      case '19_fog':
        return l10n.weatherFog;
      case '20_haze':
        return l10n.weatherHaze;
      case '21_dust':
        return l10n.weatherDust;
      case '22_dust_day':
        return l10n.weatherSandstorm;
      case '23_wind':
        return l10n.weatherWindy;
      case '24_cyclone':
        return l10n.weatherCyclone;
      case '25_hail':
        return l10n.weatherHail;
      case '26_thermometer_warmer':
        return l10n.weatherHeatWave;
      case '27_thermometer_colder':
        return l10n.weatherColdWave;
      case '28_weather_alert':
        return l10n.weatherAlert;
      case '29_extreme_snow':
        return l10n.weatherBlizzard;
      case '30_code_orange':
        return l10n.weatherCodeOrange;
      case '31_code_red':
        return l10n.weatherCodeRed;
      default:
        return label;
    }
  }

  String get pngAssetPath => 'assets/home/weather/static_png/$code.png';
  String get gifAssetPath => 'assets/home/weather/dynamic_gif/$code.gif';
  String get dynamicSvgAssetPath => 'assets/home/weather/dynamic_svg/$code.svg';
  String get staticSvgAssetPath => 'assets/home/weather/static_svg/$code.svg';

  static bool isSupportedCode(Object? code) =>
      code is String && _labels.containsKey(code);

  static Iterable<String> get supportedCodes => _labels.keys;

  factory WeatherPresentation.fromCode(String code) {
    final resolvedCode = isSupportedCode(code) ? code : fallbackCode;
    return WeatherPresentation._(
      code: resolvedCode,
      label: _labels[resolvedCode]!,
    );
  }
}
