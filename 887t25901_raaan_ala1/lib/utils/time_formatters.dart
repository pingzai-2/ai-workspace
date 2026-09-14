import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// 全局时间文本格式。
///
/// 状态栏、主页和息屏页都只显示设备本地时间。12 小时制在待机页
/// 会额外显示"上午/下午"标识（由 idle_page.dart 自行处理），
/// 此处仅返回纯数字，不附加 AM/PM，以免不同平台的本地化设置改变 UI 宽度。
String formatDashboardClock(DateTime value, {bool use24HourFormat = true}) {
  return DateFormat(
    use24HourFormat ? 'HH:mm' : 'hh:mm',
    'en_US',
  ).format(value);
}

String formatDashboardDate(BuildContext context, DateTime value) {
  return DateFormat.MMMd(Localizations.localeOf(context).toString())
      .format(value);
}

String formatDashboardWeekday(BuildContext context, DateTime value) {
  return DateFormat.E(Localizations.localeOf(context).toString())
      .format(value);
}
