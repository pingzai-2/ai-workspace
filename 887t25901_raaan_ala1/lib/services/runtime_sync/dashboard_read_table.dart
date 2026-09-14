import '../beiang8panel_api.dart';
import 'dashboard_task.dart';

/// ===== 读任务表：只登记读取函数及其 runtime 字段 =====
///
/// 后端运行态始终只登记一个聚合读取任务。新增确认字段时扩展聚合响应和
/// runtimePatch，不为每个字段增加 HTTP 请求；外部网络服务也先在后端缓存，
/// 再随同一快照返回。
class DashboardRuntimeReadTable {
  DashboardRuntimeReadTable(BeiAng8PanelApi api)
      : api = api,
        entries = <DashboardRuntimeReadTask>[
          DashboardRuntimeReadTask(
            name: 'backend-runtime-snapshot',
            read: () async {
              final snapshot = await api.readRuntimeSnapshot();
              return snapshot.runtimePatch;
            },
          ),
        ];

  final BeiAng8PanelApi api;
  final List<DashboardRuntimeReadTask> entries;
}
