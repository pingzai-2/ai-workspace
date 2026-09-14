abstract class TimeSource {
  const TimeSource();

  DateTime now();
}

/// 桌面系统和嵌入式 Linux 共用的本地系统时间源。
class SystemTimeSource extends TimeSource {
  const SystemTimeSource();

  @override
  DateTime now() => DateTime.now();
}
