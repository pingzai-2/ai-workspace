import 'dashboard_field_table.dart';

typedef DashboardRuntimePatchRead = Future<Map<String, dynamic>> Function();
typedef DashboardRuntimeValueWrite<T> = Future<bool> Function(T value);

/// 读任务只描述一次聚合读取及其 runtime 字段补丁。
class DashboardRuntimeReadTask {
  const DashboardRuntimeReadTask({
    required this.name,
    required this.read,
  });

  final String name;
  final DashboardRuntimePatchRead read;
}

/// 写任务只描述设置目标、运行反馈字段和后端写函数。
class DashboardRuntimeWriteTask<T> {
  const DashboardRuntimeWriteTask({
    required this.name,
    required this.settingsField,
    required this.runtimeField,
    required this.write,
  });

  final String name;
  final DashboardSettingsField<T> settingsField;
  final DashboardRuntimeField<T> runtimeField;
  final DashboardRuntimeValueWrite<T> write;
}
