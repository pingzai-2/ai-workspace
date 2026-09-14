import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh')
  ];

  /// No description provided for @menuSettings.
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get menuSettings;

  /// No description provided for @menuMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'设备维护'**
  String get menuMaintenance;

  /// No description provided for @menuEngineering.
  ///
  /// In zh, this message translates to:
  /// **'工程模式'**
  String get menuEngineering;

  /// No description provided for @settingsBackHint.
  ///
  /// In zh, this message translates to:
  /// **'※ 返回即自动保存设置'**
  String get settingsBackHint;

  /// No description provided for @generalSettings.
  ///
  /// In zh, this message translates to:
  /// **'通用设置'**
  String get generalSettings;

  /// No description provided for @networkSettings.
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get networkSettings;

  /// No description provided for @timerSettings.
  ///
  /// In zh, this message translates to:
  /// **'定时设置'**
  String get timerSettings;

  /// No description provided for @systemInfo.
  ///
  /// In zh, this message translates to:
  /// **'系统信息'**
  String get systemInfo;

  /// No description provided for @timeFormat.
  ///
  /// In zh, this message translates to:
  /// **'时间格式'**
  String get timeFormat;

  /// No description provided for @timeFormat24h.
  ///
  /// In zh, this message translates to:
  /// **'24 小时'**
  String get timeFormat24h;

  /// No description provided for @timeFormat12h.
  ///
  /// In zh, this message translates to:
  /// **'12 小时'**
  String get timeFormat12h;

  /// No description provided for @dateSetting.
  ///
  /// In zh, this message translates to:
  /// **'日期设置'**
  String get dateSetting;

  /// No description provided for @clockSetting.
  ///
  /// In zh, this message translates to:
  /// **'时钟设置'**
  String get clockSetting;

  /// No description provided for @languageSelection.
  ///
  /// In zh, this message translates to:
  /// **'语言选择'**
  String get languageSelection;

  /// No description provided for @screenBrightness.
  ///
  /// In zh, this message translates to:
  /// **'屏幕亮度'**
  String get screenBrightness;

  /// No description provided for @brightnessPercent.
  ///
  /// In zh, this message translates to:
  /// **'{value} %'**
  String brightnessPercent(int value);

  /// No description provided for @priorityMetric.
  ///
  /// In zh, this message translates to:
  /// **'优先指标'**
  String get priorityMetric;

  /// No description provided for @aqiIndicator.
  ///
  /// In zh, this message translates to:
  /// **'AQI指示灯'**
  String get aqiIndicator;

  /// No description provided for @indicatorLightBrightness.
  ///
  /// In zh, this message translates to:
  /// **'指示灯亮度'**
  String get indicatorLightBrightness;

  /// No description provided for @indicatorLightBright.
  ///
  /// In zh, this message translates to:
  /// **'亮'**
  String get indicatorLightBright;

  /// No description provided for @indicatorLightDark.
  ///
  /// In zh, this message translates to:
  /// **'暗'**
  String get indicatorLightDark;

  /// No description provided for @presenceRadar.
  ///
  /// In zh, this message translates to:
  /// **'人感雷达'**
  String get presenceRadar;

  /// No description provided for @screenOffTime.
  ///
  /// In zh, this message translates to:
  /// **'息屏时间'**
  String get screenOffTime;

  /// No description provided for @screenOffSecondsValue.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String screenOffSecondsValue(int seconds);

  /// No description provided for @airQualityAutoDetection.
  ///
  /// In zh, this message translates to:
  /// **'空气品质自动检测'**
  String get airQualityAutoDetection;

  /// No description provided for @metricTemperature.
  ///
  /// In zh, this message translates to:
  /// **'温度'**
  String get metricTemperature;

  /// No description provided for @metricHumidity.
  ///
  /// In zh, this message translates to:
  /// **'湿度'**
  String get metricHumidity;

  /// No description provided for @metricPm25.
  ///
  /// In zh, this message translates to:
  /// **'PM2.5'**
  String get metricPm25;

  /// No description provided for @metricCo2.
  ///
  /// In zh, this message translates to:
  /// **'CO₂'**
  String get metricCo2;

  /// No description provided for @metricFormaldehyde.
  ///
  /// In zh, this message translates to:
  /// **'甲醛'**
  String get metricFormaldehyde;

  /// No description provided for @network.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get network;

  /// No description provided for @myNetwork.
  ///
  /// In zh, this message translates to:
  /// **'我的网络'**
  String get myNetwork;

  /// No description provided for @ipAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP 地址'**
  String get ipAddress;

  /// No description provided for @notConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get notConnected;

  /// No description provided for @currentNetwork.
  ///
  /// In zh, this message translates to:
  /// **'当前网络'**
  String get currentNetwork;

  /// No description provided for @otherNetworks.
  ///
  /// In zh, this message translates to:
  /// **'其他网络'**
  String get otherNetworks;

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get connecting;

  /// No description provided for @wifiConnectingPrefix.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 '**
  String get wifiConnectingPrefix;

  /// No description provided for @wifiConnectingSuffix.
  ///
  /// In zh, this message translates to:
  /// **' ……'**
  String get wifiConnectingSuffix;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @disconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get disconnect;

  /// No description provided for @timer.
  ///
  /// In zh, this message translates to:
  /// **'定时'**
  String get timer;

  /// No description provided for @timeRangeSetting.
  ///
  /// In zh, this message translates to:
  /// **'时间段设置'**
  String get timeRangeSetting;

  /// No description provided for @timerRangeValue.
  ///
  /// In zh, this message translates to:
  /// **'定时开  {start}～{end}'**
  String timerRangeValue(String start, String end);

  /// No description provided for @repeatCycle.
  ///
  /// In zh, this message translates to:
  /// **'重复周期'**
  String get repeatCycle;

  /// No description provided for @everyDay.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get everyDay;

  /// No description provided for @monday.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get sunday;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本号'**
  String get version;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @update.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get update;

  /// No description provided for @noUpdateMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get noUpdateMessage;

  /// No description provided for @systemUptimePrefix.
  ///
  /// In zh, this message translates to:
  /// **'系统已运行 '**
  String get systemUptimePrefix;

  /// No description provided for @systemUptimeSuffix.
  ///
  /// In zh, this message translates to:
  /// **' 天'**
  String get systemUptimeSuffix;

  /// No description provided for @clockHourHand.
  ///
  /// In zh, this message translates to:
  /// **'时针'**
  String get clockHourHand;

  /// No description provided for @clockMinuteHand.
  ///
  /// In zh, this message translates to:
  /// **'分针'**
  String get clockMinuteHand;

  /// No description provided for @clockSecondHand.
  ///
  /// In zh, this message translates to:
  /// **'秒针'**
  String get clockSecondHand;

  /// No description provided for @am.
  ///
  /// In zh, this message translates to:
  /// **'上午'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In zh, this message translates to:
  /// **'下午'**
  String get pm;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @brightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get brightness;

  /// No description provided for @start.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get start;

  /// No description provided for @end.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get end;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// No description provided for @passwordError.
  ///
  /// In zh, this message translates to:
  /// **'※  密码不正确，请重试'**
  String get passwordError;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'有最新可用版本，更新预计耗时2小时，是否继续？'**
  String get updateAvailableMessage;

  /// No description provided for @updateLater.
  ///
  /// In zh, this message translates to:
  /// **'下次再说'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @updatingMessage.
  ///
  /// In zh, this message translates to:
  /// **'更新过程中请勿断电，更新完成后将自动重启设备'**
  String get updatingMessage;

  /// No description provided for @updateFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'版本下载更新失败，请检查网络连接或稍后再试'**
  String get updateFailedMessage;

  /// No description provided for @exit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// No description provided for @consumableStatus.
  ///
  /// In zh, this message translates to:
  /// **'耗材状态'**
  String get consumableStatus;

  /// No description provided for @maintenance.
  ///
  /// In zh, this message translates to:
  /// **'保养'**
  String get maintenance;

  /// No description provided for @filterName.
  ///
  /// In zh, this message translates to:
  /// **'滤网 {index}'**
  String filterName(int index);

  /// No description provided for @remainingPrefix.
  ///
  /// In zh, this message translates to:
  /// **'余'**
  String get remainingPrefix;

  /// No description provided for @dayUnit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get dayUnit;

  /// No description provided for @dueForMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'待维护'**
  String get dueForMaintenance;

  /// No description provided for @service.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get service;

  /// No description provided for @callServiceProvider.
  ///
  /// In zh, this message translates to:
  /// **'呼叫服务商'**
  String get callServiceProvider;

  /// No description provided for @nextMaintenanceDate.
  ///
  /// In zh, this message translates to:
  /// **'下次保养时间'**
  String get nextMaintenanceDate;

  /// No description provided for @maintenanceResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'该操作将会重置当前滤网使用周期，是否继续？'**
  String get maintenanceResetMessage;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @space.
  ///
  /// In zh, this message translates to:
  /// **'空格'**
  String get space;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navMain.
  ///
  /// In zh, this message translates to:
  /// **'主页'**
  String get navMain;

  /// No description provided for @navSmart.
  ///
  /// In zh, this message translates to:
  /// **'智能'**
  String get navSmart;

  /// No description provided for @navManual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get navManual;

  /// No description provided for @navTrends.
  ///
  /// In zh, this message translates to:
  /// **'趋势'**
  String get navTrends;

  /// No description provided for @navHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @navSettingsAlt.
  ///
  /// In zh, this message translates to:
  /// **'设定'**
  String get navSettingsAlt;

  /// No description provided for @backendOffline.
  ///
  /// In zh, this message translates to:
  /// **'后端服务离线'**
  String get backendOffline;

  /// No description provided for @backendStale.
  ///
  /// In zh, this message translates to:
  /// **'设备数据陈旧'**
  String get backendStale;

  /// No description provided for @notificationCenter.
  ///
  /// In zh, this message translates to:
  /// **'通知中心'**
  String get notificationCenter;

  /// No description provided for @faultAlert.
  ///
  /// In zh, this message translates to:
  /// **'故障提醒'**
  String get faultAlert;

  /// No description provided for @noNotifications.
  ///
  /// In zh, this message translates to:
  /// **'当前无最新通知！'**
  String get noNotifications;

  /// No description provided for @noFaults.
  ///
  /// In zh, this message translates to:
  /// **'当前无故障！'**
  String get noFaults;

  /// No description provided for @contactSupport.
  ///
  /// In zh, this message translates to:
  /// **'联系售后'**
  String get contactSupport;

  /// No description provided for @deviceAirConditioner.
  ///
  /// In zh, this message translates to:
  /// **'空调'**
  String get deviceAirConditioner;

  /// No description provided for @deviceFloorHeat.
  ///
  /// In zh, this message translates to:
  /// **'地暖'**
  String get deviceFloorHeat;

  /// No description provided for @deviceFreshAir.
  ///
  /// In zh, this message translates to:
  /// **'新风'**
  String get deviceFreshAir;

  /// No description provided for @deviceHumidifier.
  ///
  /// In zh, this message translates to:
  /// **'调湿'**
  String get deviceHumidifier;

  /// No description provided for @devicePure.
  ///
  /// In zh, this message translates to:
  /// **'超净'**
  String get devicePure;

  /// No description provided for @stateCooling.
  ///
  /// In zh, this message translates to:
  /// **'制冷'**
  String get stateCooling;

  /// No description provided for @stateNotOn.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get stateNotOn;

  /// No description provided for @stateOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get stateOn;

  /// No description provided for @freshAirModeInternalCirculation.
  ///
  /// In zh, this message translates to:
  /// **'内循环'**
  String get freshAirModeInternalCirculation;

  /// No description provided for @fanLevelHigh.
  ///
  /// In zh, this message translates to:
  /// **'强档'**
  String get fanLevelHigh;

  /// No description provided for @iefStarting.
  ///
  /// In zh, this message translates to:
  /// **'IEF启动中'**
  String get iefStarting;

  /// No description provided for @quickPowerAll.
  ///
  /// In zh, this message translates to:
  /// **'一键\n开关'**
  String get quickPowerAll;

  /// No description provided for @quickLeaveHome.
  ///
  /// In zh, this message translates to:
  /// **'一键\n离家'**
  String get quickLeaveHome;

  /// No description provided for @floorIndoor.
  ///
  /// In zh, this message translates to:
  /// **'室内'**
  String get floorIndoor;

  /// No description provided for @floorAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get floorAll;

  /// No description provided for @floorBasement1.
  ///
  /// In zh, this message translates to:
  /// **'地下一层'**
  String get floorBasement1;

  /// No description provided for @floorBasement2.
  ///
  /// In zh, this message translates to:
  /// **'地下二层'**
  String get floorBasement2;

  /// No description provided for @floor1.
  ///
  /// In zh, this message translates to:
  /// **'一层'**
  String get floor1;

  /// No description provided for @floor2.
  ///
  /// In zh, this message translates to:
  /// **'二层'**
  String get floor2;

  /// No description provided for @floor3.
  ///
  /// In zh, this message translates to:
  /// **'三层'**
  String get floor3;

  /// No description provided for @weatherSunny.
  ///
  /// In zh, this message translates to:
  /// **'晴'**
  String get weatherSunny;

  /// No description provided for @weatherClearNight.
  ///
  /// In zh, this message translates to:
  /// **'晴夜'**
  String get weatherClearNight;

  /// No description provided for @weatherMostlyClear.
  ///
  /// In zh, this message translates to:
  /// **'晴间多云'**
  String get weatherMostlyClear;

  /// No description provided for @weatherOvercast.
  ///
  /// In zh, this message translates to:
  /// **'阴'**
  String get weatherOvercast;

  /// No description provided for @weatherCloudy.
  ///
  /// In zh, this message translates to:
  /// **'多云'**
  String get weatherCloudy;

  /// No description provided for @weatherDrizzle.
  ///
  /// In zh, this message translates to:
  /// **'毛毛雨'**
  String get weatherDrizzle;

  /// No description provided for @weatherMiddleRain.
  ///
  /// In zh, this message translates to:
  /// **'中雨'**
  String get weatherMiddleRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In zh, this message translates to:
  /// **'大雨'**
  String get weatherHeavyRain;

  /// No description provided for @weatherExtremeRain.
  ///
  /// In zh, this message translates to:
  /// **'暴雨'**
  String get weatherExtremeRain;

  /// No description provided for @weatherMostlyClearRain.
  ///
  /// In zh, this message translates to:
  /// **'晴间多云有雨'**
  String get weatherMostlyClearRain;

  /// No description provided for @weatherThunderstorms.
  ///
  /// In zh, this message translates to:
  /// **'雷阵雨'**
  String get weatherThunderstorms;

  /// No description provided for @weatherDrizzleToMiddleRain.
  ///
  /// In zh, this message translates to:
  /// **'小到中雨'**
  String get weatherDrizzleToMiddleRain;

  /// No description provided for @weatherMiddleToHeavyRain.
  ///
  /// In zh, this message translates to:
  /// **'中到大雨'**
  String get weatherMiddleToHeavyRain;

  /// No description provided for @weatherLightSnow.
  ///
  /// In zh, this message translates to:
  /// **'小雪'**
  String get weatherLightSnow;

  /// No description provided for @weatherModerateSnow.
  ///
  /// In zh, this message translates to:
  /// **'中雪'**
  String get weatherModerateSnow;

  /// No description provided for @weatherHeavySnow.
  ///
  /// In zh, this message translates to:
  /// **'大雪'**
  String get weatherHeavySnow;

  /// No description provided for @weatherWindSnow.
  ///
  /// In zh, this message translates to:
  /// **'风雪'**
  String get weatherWindSnow;

  /// No description provided for @weatherSleet.
  ///
  /// In zh, this message translates to:
  /// **'雨夹雪'**
  String get weatherSleet;

  /// No description provided for @weatherFog.
  ///
  /// In zh, this message translates to:
  /// **'雾'**
  String get weatherFog;

  /// No description provided for @weatherHaze.
  ///
  /// In zh, this message translates to:
  /// **'霾'**
  String get weatherHaze;

  /// No description provided for @weatherDust.
  ///
  /// In zh, this message translates to:
  /// **'浮尘'**
  String get weatherDust;

  /// No description provided for @weatherSandstorm.
  ///
  /// In zh, this message translates to:
  /// **'扬沙'**
  String get weatherSandstorm;

  /// No description provided for @weatherWindy.
  ///
  /// In zh, this message translates to:
  /// **'大风'**
  String get weatherWindy;

  /// No description provided for @weatherCyclone.
  ///
  /// In zh, this message translates to:
  /// **'台风'**
  String get weatherCyclone;

  /// No description provided for @weatherHail.
  ///
  /// In zh, this message translates to:
  /// **'冰雹'**
  String get weatherHail;

  /// No description provided for @weatherHeatWave.
  ///
  /// In zh, this message translates to:
  /// **'高温'**
  String get weatherHeatWave;

  /// No description provided for @weatherColdWave.
  ///
  /// In zh, this message translates to:
  /// **'低温'**
  String get weatherColdWave;

  /// No description provided for @weatherAlert.
  ///
  /// In zh, this message translates to:
  /// **'天气预警'**
  String get weatherAlert;

  /// No description provided for @weatherBlizzard.
  ///
  /// In zh, this message translates to:
  /// **'暴雪'**
  String get weatherBlizzard;

  /// No description provided for @weatherCodeOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙色预警'**
  String get weatherCodeOrange;

  /// No description provided for @weatherCodeRed.
  ///
  /// In zh, this message translates to:
  /// **'红色预警'**
  String get weatherCodeRed;

  /// No description provided for @smartStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准模式'**
  String get smartStandard;

  /// No description provided for @smartGuest.
  ///
  /// In zh, this message translates to:
  /// **'会客模式'**
  String get smartGuest;

  /// No description provided for @smartDry.
  ///
  /// In zh, this message translates to:
  /// **'干爽模式'**
  String get smartDry;

  /// No description provided for @smartHumid.
  ///
  /// In zh, this message translates to:
  /// **'温润模式'**
  String get smartHumid;

  /// No description provided for @smartTravel.
  ///
  /// In zh, this message translates to:
  /// **'旅行模式'**
  String get smartTravel;

  /// No description provided for @smartModeActiveHint.
  ///
  /// In zh, this message translates to:
  /// **'※ {mode}已启用'**
  String smartModeActiveHint(String mode);

  /// No description provided for @smartExitMessage.
  ///
  /// In zh, this message translates to:
  /// **'该操作将会退出当前智能模式，是否继续？'**
  String get smartExitMessage;

  /// No description provided for @manualMode.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get manualMode;

  /// No description provided for @manualFanSpeed.
  ///
  /// In zh, this message translates to:
  /// **'风量'**
  String get manualFanSpeed;

  /// No description provided for @manualDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get manualDuration;

  /// No description provided for @manualHold.
  ///
  /// In zh, this message translates to:
  /// **'保持'**
  String get manualHold;

  /// No description provided for @manualRoom.
  ///
  /// In zh, this message translates to:
  /// **'房间'**
  String get manualRoom;

  /// No description provided for @manualTimerOn.
  ///
  /// In zh, this message translates to:
  /// **'定时开'**
  String get manualTimerOn;

  /// No description provided for @manualTimerOff.
  ///
  /// In zh, this message translates to:
  /// **'定时关'**
  String get manualTimerOff;

  /// No description provided for @manualRepeat.
  ///
  /// In zh, this message translates to:
  /// **'循环'**
  String get manualRepeat;

  /// No description provided for @manualFreshAirMode.
  ///
  /// In zh, this message translates to:
  /// **'新风模式'**
  String get manualFreshAirMode;

  /// No description provided for @manualFreshAirFanSpeed.
  ///
  /// In zh, this message translates to:
  /// **'新风风量'**
  String get manualFreshAirFanSpeed;

  /// No description provided for @modeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get modeAuto;

  /// No description provided for @modeHeating.
  ///
  /// In zh, this message translates to:
  /// **'制热'**
  String get modeHeating;

  /// No description provided for @modeFan.
  ///
  /// In zh, this message translates to:
  /// **'送风'**
  String get modeFan;

  /// No description provided for @freshAirModeFullHeatExchange.
  ///
  /// In zh, this message translates to:
  /// **'全热交换'**
  String get freshAirModeFullHeatExchange;

  /// No description provided for @repeatOnce.
  ///
  /// In zh, this message translates to:
  /// **'单次'**
  String get repeatOnce;

  /// No description provided for @repeatWeekdays.
  ///
  /// In zh, this message translates to:
  /// **'工作日'**
  String get repeatWeekdays;

  /// No description provided for @repeatOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get repeatOff;

  /// No description provided for @timerNotSet.
  ///
  /// In zh, this message translates to:
  /// **'定时  未设置'**
  String get timerNotSet;

  /// No description provided for @timerSummaryValue.
  ///
  /// In zh, this message translates to:
  /// **'定时  {start}-{end}（{repeat}）'**
  String timerSummaryValue(String start, String end, String repeat);

  /// No description provided for @runningDeviceCount.
  ///
  /// In zh, this message translates to:
  /// **'※ 当前 {count} 台设备运行中'**
  String runningDeviceCount(int count);

  /// No description provided for @manualWholeHomeFloorHeat.
  ///
  /// In zh, this message translates to:
  /// **'将控制全屋地暖'**
  String get manualWholeHomeFloorHeat;

  /// No description provided for @manualWholeHomeFreshAir.
  ///
  /// In zh, this message translates to:
  /// **'将控制全屋新风'**
  String get manualWholeHomeFreshAir;

  /// No description provided for @manualWholeHomeHumidity.
  ///
  /// In zh, this message translates to:
  /// **'将控制全屋湿度'**
  String get manualWholeHomeHumidity;

  /// No description provided for @manualWholeHomePure.
  ///
  /// In zh, this message translates to:
  /// **'已开启全屋超净'**
  String get manualWholeHomePure;

  /// No description provided for @manualExitMessage.
  ///
  /// In zh, this message translates to:
  /// **'该操作将会退出当前手动模式，是否继续？'**
  String get manualExitMessage;

  /// No description provided for @freshAirTimerSetting.
  ///
  /// In zh, this message translates to:
  /// **'新风定时设置'**
  String get freshAirTimerSetting;

  /// No description provided for @humidifierTimerSetting.
  ///
  /// In zh, this message translates to:
  /// **'调湿定时设置'**
  String get humidifierTimerSetting;

  /// No description provided for @floorHeatTimerSetting.
  ///
  /// In zh, this message translates to:
  /// **'地暖定时设置'**
  String get floorHeatTimerSetting;

  /// No description provided for @acTimerSettingTitle.
  ///
  /// In zh, this message translates to:
  /// **'{room}空调定时设置'**
  String acTimerSettingTitle(String room);

  /// No description provided for @acAdjustTitle.
  ///
  /// In zh, this message translates to:
  /// **'{room}空调调节'**
  String acAdjustTitle(String room);

  /// No description provided for @floorHeatRoomTimerTitle.
  ///
  /// In zh, this message translates to:
  /// **'{room}地暖定时设置'**
  String floorHeatRoomTimerTitle(String room);

  /// No description provided for @idleNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无实时数据'**
  String get idleNoData;

  /// No description provided for @idleAdviceGoodGood.
  ///
  /// In zh, this message translates to:
  /// **'室内外空气质量良好，可适当开窗通风'**
  String get idleAdviceGoodGood;

  /// No description provided for @idleAdviceOutdoorBetter.
  ///
  /// In zh, this message translates to:
  /// **'室外空气质量优于室内，建议适当开窗通风'**
  String get idleAdviceOutdoorBetter;

  /// No description provided for @idleAdviceGoodFair.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量优良，室外空气质量一般，建议减少室外活动'**
  String get idleAdviceGoodFair;

  /// No description provided for @idleAdviceGoodPoor.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量优良，室外空气质量较差，建议减少室外活动'**
  String get idleAdviceGoodPoor;

  /// No description provided for @idleAdviceFairFair.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量一般，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动'**
  String get idleAdviceFairFair;

  /// No description provided for @idleAdviceFairPoor.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量一般，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动'**
  String get idleAdviceFairPoor;

  /// No description provided for @idleAdvicePoorFair.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量较差，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动'**
  String get idleAdvicePoorFair;

  /// No description provided for @idleAdvicePoorPoor.
  ///
  /// In zh, this message translates to:
  /// **'室内空气质量较差，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动'**
  String get idleAdvicePoorPoor;

  /// No description provided for @idleOutdoor.
  ///
  /// In zh, this message translates to:
  /// **'室外'**
  String get idleOutdoor;

  /// No description provided for @historyWeeklyTitle.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get historyWeeklyTitle;

  /// No description provided for @historyTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get historyTimeTitle;

  /// No description provided for @historyAverageSuffix.
  ///
  /// In zh, this message translates to:
  /// **'平均'**
  String get historyAverageSuffix;

  /// No description provided for @historyDailyView.
  ///
  /// In zh, this message translates to:
  /// **'按日查看'**
  String get historyDailyView;

  /// No description provided for @historyWeeklyView.
  ///
  /// In zh, this message translates to:
  /// **'按周查看'**
  String get historyWeeklyView;

  /// No description provided for @historyMonthlyView.
  ///
  /// In zh, this message translates to:
  /// **'按月查看'**
  String get historyMonthlyView;

  /// No description provided for @engineeringFreshAirConfig.
  ///
  /// In zh, this message translates to:
  /// **'新风子系统配置'**
  String get engineeringFreshAirConfig;

  /// No description provided for @engineeringAcConfig.
  ///
  /// In zh, this message translates to:
  /// **'空调子系统配置'**
  String get engineeringAcConfig;

  /// No description provided for @engineeringFloorHeatConfig.
  ///
  /// In zh, this message translates to:
  /// **'地暖子系统配置'**
  String get engineeringFloorHeatConfig;

  /// No description provided for @engineeringProductionTestConfig.
  ///
  /// In zh, this message translates to:
  /// **'产测模式配置'**
  String get engineeringProductionTestConfig;

  /// No description provided for @engineeringCompleteInstallation.
  ///
  /// In zh, this message translates to:
  /// **'施工完成确认'**
  String get engineeringCompleteInstallation;

  /// No description provided for @engineeringSavingConfig.
  ///
  /// In zh, this message translates to:
  /// **'正在保存配置…'**
  String get engineeringSavingConfig;

  /// No description provided for @engineeringConfigConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'本次配置已确认'**
  String get engineeringConfigConfirmed;

  /// No description provided for @engineeringProductionTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'产测模式'**
  String get engineeringProductionTestTitle;

  /// No description provided for @engineeringDeviceSearch.
  ///
  /// In zh, this message translates to:
  /// **'设备搜索'**
  String get engineeringDeviceSearch;

  /// No description provided for @engineeringNameSettings.
  ///
  /// In zh, this message translates to:
  /// **'名称设置'**
  String get engineeringNameSettings;

  /// No description provided for @engineeringSaveAndReturn.
  ///
  /// In zh, this message translates to:
  /// **'确定并返回'**
  String get engineeringSaveAndReturn;

  /// No description provided for @engineeringAreaSelect.
  ///
  /// In zh, this message translates to:
  /// **'区域选择'**
  String get engineeringAreaSelect;

  /// No description provided for @engineeringRoomSelect.
  ///
  /// In zh, this message translates to:
  /// **'房间选择'**
  String get engineeringRoomSelect;

  /// No description provided for @engineeringDeviceName.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get engineeringDeviceName;

  /// No description provided for @engineeringConfigAddress.
  ///
  /// In zh, this message translates to:
  /// **'配置地址'**
  String get engineeringConfigAddress;

  /// No description provided for @engineeringAreaName.
  ///
  /// In zh, this message translates to:
  /// **'区域名称'**
  String get engineeringAreaName;

  /// No description provided for @engineeringRoomName.
  ///
  /// In zh, this message translates to:
  /// **'房间名称'**
  String get engineeringRoomName;

  /// No description provided for @engineeringTestRun.
  ///
  /// In zh, this message translates to:
  /// **'试运行'**
  String get engineeringTestRun;

  /// No description provided for @engineeringAreaId.
  ///
  /// In zh, this message translates to:
  /// **'区域ID'**
  String get engineeringAreaId;

  /// No description provided for @engineeringRoomId.
  ///
  /// In zh, this message translates to:
  /// **'房间ID'**
  String get engineeringRoomId;

  /// No description provided for @engineeringAddRoomHint.
  ///
  /// In zh, this message translates to:
  /// **'点击输入新增房间'**
  String get engineeringAddRoomHint;

  /// No description provided for @engineeringAddAreaHint.
  ///
  /// In zh, this message translates to:
  /// **'点击输入新增区域'**
  String get engineeringAddAreaHint;

  /// No description provided for @engineeringSettingItem.
  ///
  /// In zh, this message translates to:
  /// **'设置项'**
  String get engineeringSettingItem;

  /// No description provided for @engineeringParameterSettings.
  ///
  /// In zh, this message translates to:
  /// **'参数设置'**
  String get engineeringParameterSettings;

  /// No description provided for @engineeringPanelName.
  ///
  /// In zh, this message translates to:
  /// **'8寸控制屏'**
  String get engineeringPanelName;

  /// No description provided for @engineeringTempHumiditySensor.
  ///
  /// In zh, this message translates to:
  /// **'温湿度传感器'**
  String get engineeringTempHumiditySensor;

  /// No description provided for @engineeringTempHumidityParams.
  ///
  /// In zh, this message translates to:
  /// **'温度：25℃        湿度：56%'**
  String get engineeringTempHumidityParams;

  /// No description provided for @engineeringPasswordSetting.
  ///
  /// In zh, this message translates to:
  /// **'工程模式密码设置'**
  String get engineeringPasswordSetting;

  /// No description provided for @engineeringFilterLife.
  ///
  /// In zh, this message translates to:
  /// **'滤网寿命'**
  String get engineeringFilterLife;

  /// No description provided for @engineeringMaintenanceInterval.
  ///
  /// In zh, this message translates to:
  /// **'保养时间'**
  String get engineeringMaintenanceInterval;

  /// No description provided for @engineeringServicePhone.
  ///
  /// In zh, this message translates to:
  /// **'服务商电话'**
  String get engineeringServicePhone;

  /// No description provided for @engineeringMotorSpeedTitle.
  ///
  /// In zh, this message translates to:
  /// **'电机{index}转速设置'**
  String engineeringMotorSpeedTitle(int index);

  /// No description provided for @engineeringCompressorFreq.
  ///
  /// In zh, this message translates to:
  /// **'压缩机频率设置'**
  String get engineeringCompressorFreq;

  /// No description provided for @engineeringRepeatInput.
  ///
  /// In zh, this message translates to:
  /// **'重复输入'**
  String get engineeringRepeatInput;

  /// No description provided for @engineeringNextMaintenanceDays.
  ///
  /// In zh, this message translates to:
  /// **'下次保养天数'**
  String get engineeringNextMaintenanceDays;

  /// No description provided for @engineeringReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get engineeringReset;

  /// No description provided for @engineeringEnter6DigitPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位数字密码'**
  String get engineeringEnter6DigitPassword;

  /// No description provided for @engineeringPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次密码不一致，请重新输入'**
  String get engineeringPasswordMismatch;

  /// No description provided for @engineeringPasswordMatchConfirm.
  ///
  /// In zh, this message translates to:
  /// **'两次输入一致，请点击确认'**
  String get engineeringPasswordMatchConfirm;

  /// No description provided for @engineeringApplied.
  ///
  /// In zh, this message translates to:
  /// **'本次运行已生效'**
  String get engineeringApplied;

  /// No description provided for @engineeringNewPasswordPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入新的 6 位密码'**
  String get engineeringNewPasswordPrompt;

  /// No description provided for @engineeringReenterPasswordPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入新的 6 位密码'**
  String get engineeringReenterPasswordPrompt;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
