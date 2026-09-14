import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/app_logger.dart';
import 'services/dashboard_storage.dart';
import 'services/dashboard_runtime_sync_service.dart';
import 'services/time_source.dart';
import 'pages/home/home_page.dart';
import 'theme/app_fonts.dart';
import 'widgets/design_resolution_scaler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件日志服务：带时间戳、分级输出。
  // 日志目录规则：DASHBOARD_LOG_ROOT > DASHBOARD_CONFIG_ROOT 的父目录 >
  // 应用文档目录；日志文件写入基础目录下的 logs/app.log。
  // release 模式下默认只写文件、不在控制台输出；debug 模式下同时输出到控制台。
  await AppLogger.instance.init(minLevel: LogLevel.info);
  AppLogger.instance.i('应用启动', tag: 'Main');
  AppLogger.instance.w('日志服务已就绪，路径：${AppLogger.instance.logFilePath ?? "未知"}', tag: 'Main');

  // 限制图片缓存，避免连续切页后动态 GIF 和大图长期占用内存。
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 64;
  imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  // 由 Flutter 本地化代理统一装载 intl 日期数据，避免 intl 0.17/0.18
  // 与 initializeDateFormatting() 重复初始化时产生版本相关冲突。
  await GlobalMaterialLocalizations.delegate.load(
    const Locale('zh', 'CN'),
  );

  // 全局语言控制器：根 locale 跟随系统设置页保存的语言，
  // 整 App 一起切换，其它页面无需单独处理。
  final localeController = ValueNotifier<Locale>(const Locale('zh', 'CN'));
  AppLogger.instance.i('使用真实数据源', tag: 'Main');
  runApp(
    HomeDashboardPracticeApp(
      runtimeSyncService: DashboardRuntimeSyncService(),
      localeController: localeController,
    ),
  );
}

class HomeDashboardPracticeApp extends StatelessWidget {
  const HomeDashboardPracticeApp({
    Key? key,
    this.storage,
    this.runtimeSyncService,
    this.timeSource = const SystemTimeSource(),
    this.animateWeather = true,
    this.idleTimeout = const Duration(seconds: 30),
    required this.localeController,
  }) : super(key: key);

  final DashboardDataRepository? storage;
  final DashboardRuntimeSyncService? runtimeSyncService;
  final TimeSource timeSource;
  final bool animateWeather;
  final Duration idleTimeout;
  final ValueNotifier<Locale> localeController;

  @override
  Widget build(BuildContext context) {
    return DesignResolutionScaler(
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeController,
        builder: (context, locale, _) => MaterialApp(
          title: 'flutter_home_dashboard_8cun',
          debugShowCheckedModeBanner: false,
          // 注册全局本地化代理与支持语言。根 locale 由 localeController
          // 驱动，跟随系统设置页保存的语言码，整 App 一起切换。
          locale: locale,
          supportedLocales: const <Locale>[
            Locale('zh'),
            Locale('ja'),
            Locale('en'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF000000),
            primaryColor: Colors.blue.shade400,
            cardColor: const Color(0xFF1E1E1E),
            dividerColor: Colors.grey.shade800,
            // 翻译文字默认使用 SC；数字、符号和大号读数在控件样式中显式使用 HarmonyOS Sans。
            fontFamily: AppFonts.sourceHanSansSc,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(
                color: Colors.white,
              ),
              bodyMedium: TextStyle(
                color: Colors.white,
              ),
              bodySmall: TextStyle(
                color: Colors.white70,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: Colors.blue.shade400,
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: Colors.white,
              overlayColor: Colors.blue.withAlpha(32),
            ),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(size: kDesignResolution),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomePage(
            storage: storage,
            runtimeSyncService: runtimeSyncService,
            timeSource: timeSource,
            animateWeather: animateWeather,
            idleTimeout: idleTimeout,
            localeController: localeController,
          ),
        ),
      ),
    );
  }
}
