import '../beiang8panel_api.dart';
import 'dashboard_field_table.dart';
import 'dashboard_task.dart';

/// ===== 写任务表：只登记设置字段、运行反馈字段和后端写函数 =====
///
/// 新增普通写入：先在 [BeiAng8PanelApi] 增加写函数和字段配置，再在本表追加一项。
/// settings 保存、pending 消费及 runtime JSON 更新仍由现有公共链路统一处理。
///
/// 当前超净开关是单项写入的通信链路打样。未来控制项增多时，普通独立开关可以
/// 继续单独写入；如果一个 UI 动作对应多个设备字段，或后端提供批量、模式、场景
/// 等聚合控制接口，应优先合并为一次语义化写请求，由后端统一校验、执行并返回结果，
/// 避免 UI 为同一次操作连续发送多次 HTTP。只有必须独立确认的控制项才拆开写入。
class DashboardRuntimeWriteTable {
  DashboardRuntimeWriteTable(BeiAng8PanelApi api)
      : freshAirPower = DashboardRuntimeWriteTask<bool>(
          name: 'fresh-air-power',
          settingsField: DashboardFieldTable.freshAirEnabled,
          runtimeField: DashboardFieldTable.freshAirRunning,
          write: api.setFreshAirPower,
        ),
        humidifierPower = DashboardRuntimeWriteTask<bool>(
          name: 'humidifier-power',
          settingsField: DashboardFieldTable.humidifierEnabled,
          runtimeField: DashboardFieldTable.humidifierRunning,
          write: api.setHumidifierPower,
        ),
        purePower = DashboardRuntimeWriteTask<bool>(
          name: 'pure-power',
          settingsField: DashboardFieldTable.pureEnabled,
          runtimeField: DashboardFieldTable.pureRunning,
          write: api.setPurePower,
        );

  final DashboardRuntimeWriteTask<bool> freshAirPower;
  final DashboardRuntimeWriteTask<bool> humidifierPower;
  final DashboardRuntimeWriteTask<bool> purePower;

  List<DashboardRuntimeWriteTask<dynamic>> get entries =>
      <DashboardRuntimeWriteTask<dynamic>>[
        freshAirPower,
        humidifierPower,
        purePower,
      ];
}
