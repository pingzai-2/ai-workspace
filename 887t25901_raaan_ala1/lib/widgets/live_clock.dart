import 'dart:async';

import 'package:flutter/material.dart';

import '../services/time_source.dart';
import '../theme/app_fonts.dart';
import '../utils/time_formatters.dart';

class LiveClock extends StatefulWidget {
  const LiveClock({
    Key? key,
    this.timeSource = const SystemTimeSource(),
    this.style,
    this.showDateAndWeekday = true,
    this.use24HourFormat = true,
  }) : super(key: key);

  final TimeSource timeSource;
  final TextStyle? style;
  final bool showDateAndWeekday;
  final bool use24HourFormat;

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = widget.timeSource.now();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LiveClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeSource != widget.timeSource) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    final next = widget.timeSource.now();
    if (!mounted) {
      return;
    }
    setState(() {
      _now = next;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 12 小时制只改变小时数字（01～12），不显示 AM/PM；
    // 保持状态栏、主页和待机页的时间文本风格一致。
    final time = formatDashboardClock(
      _now,
      use24HourFormat: widget.use24HourFormat,
    );
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final timeText = Text(
      time,
      style: baseStyle.copyWith(
        fontFamily: AppFonts.harmonyRegular,
        fontWeight: FontWeight.w400,
      ),
    );
    if (!widget.showDateAndWeekday) {
      return timeText;
    }
    final date = formatDashboardDate(context, _now);
    final weekday = formatDashboardWeekday(context, _now);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$date $weekday',
          style: baseStyle.copyWith(
            fontFamily: AppFonts.harmonyRegular,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 22),
        timeText,
      ],
    );
  }
}
