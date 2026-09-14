import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dashboard_data.dart';
import '../services/time_source.dart';
import '../theme/app_fonts.dart';
import 'live_clock.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    Key? key,
    required this.data,
    this.timeSource = const SystemTimeSource(),
  }) : super(key: key);

  final DashboardData data;
  final TimeSource timeSource;

  // Figma 1:2449 "08:30" 24px Regular HarmonyOS Sans
  static const TextStyle _dateTextStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w400,
    fontFamily: AppFonts.harmonyRegular,
  );

  @override
  Widget build(BuildContext context) {
    // 设计标准：StatusBar 仅右上角显示 时钟+wifi+时间，整体 opacity 0.7 (Figma 1:2483)
    return Opacity(
      opacity: 0.7,
      child: SizedBox(
        width: 1920,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.only(right: 42),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              const _StatusImage(
                'assets/home/top/clock.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 16),
              _StatusImage(
                data.effectiveWifiConnected
                    ? 'assets/home/top/wifi_correct.png'
                    : 'assets/home/top/wifi_error.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 16),
              LiveClock(
                timeSource: timeSource,
                style: _dateTextStyle,
                showDateAndWeekday: false,
                use24HourFormat: data.timeFormat == '24h',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全局后端数据状态提示层。
///
/// 这一层与业务页面、工程模式和息屏页解耦，由 HomePage
/// 根层统一挂载。[enabled] 是独立总开关；关闭后不影响状态采集和
/// 其他页面。组件只显示已有快照，不启动定时器或任何 I/O。
class BackendStatusOverlay extends StatelessWidget {
  const BackendStatusOverlay({
    Key? key,
    required this.data,
    this.enabled = true,
  }) : super(key: key);

  final DashboardData data;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }
    if (data.backendDataStatus == 'fresh') {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return _buildOverlay(
      data.backendDataStatus == 'unreachable'
          ? l10n.backendOffline
          : l10n.backendStale,
    );
  }

  Widget _buildOverlay(String message) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.7,
        child: SizedBox(
          width: 1920,
          height: 48,
          child: Padding(
            padding: const EdgeInsets.only(right: 42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  height: 40,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, 0),
                      child: Text(
                        message,
                        style: StatusBar._dateTextStyle.copyWith(
                          color: const Color(0xFFFFB067),
                          fontSize: 20,
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontVariations:
                              AppFonts.sourceHanSansScRegularWght400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // 与原状态栏的时钟、Wi-Fi和时间占位保持一致，
                // 使提示位置不因从页面状态栏抽出而变化。
                const SizedBox(width: 52),
                const SizedBox(width: 16),
                const SizedBox(width: 52),
                const SizedBox(width: 16),
                const Opacity(
                  opacity: 0,
                  child: Text('00:00', style: StatusBar._dateTextStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 五个主业务页面统一使用的右上角状态栏壳层。
///
/// 继承旧版公共页面壳“只挂载一次顶部状态”的做法，但只保留设计稿确认的
/// 右侧定时、Wi-Fi 和时间；左侧主页内容不属于公共状态栏。
class DashboardStatusBarFrame extends StatelessWidget {
  const DashboardStatusBarFrame({
    Key? key,
    required this.data,
    required this.timeSource,
    required this.child,
  }) : super(key: key);

  final DashboardData data;
  final TimeSource timeSource;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Positioned(
          top: 24,
          child: StatusBar(data: data, timeSource: timeSource),
        ),
      ],
    );
  }
}

class _StatusImage extends StatelessWidget {
  const _StatusImage(
    this.assetPath, {
    this.width = 48,
    this.height = 48,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
