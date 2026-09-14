part of 'home_page.dart';

enum _RuntimeAlertDialogType { notification, fault }

/// 两个弹窗共用设计素材与列表骨架，但保留各自的 Figma 绝对坐标。
class _RuntimeAlertDialogLayer extends StatelessWidget {
  const _RuntimeAlertDialogLayer({
    required this.dataListenable,
    required this.type,
  });

  final ValueListenable<DashboardData?> dataListenable;
  final _RuntimeAlertDialogType type;

  @override
  Widget build(BuildContext context) {
    final isFault = type == _RuntimeAlertDialogType.fault;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              // black-cover.png 是整张 1920×1200 的单色透明黑图；
              // 直接绘制等效遮罩，避免解码约 9MB 的图片缓冲。
              child: const ColoredBox(
                color: Color(0x4D000000),
              ),
            ),
          ),
          Positioned(
            // Figma：故障 popup 1:1243 为 x=220；通知 popup 1:1142 为 x=340。
            left: isFault ? 220 : 340,
            top: 227,
            width: 988,
            height: 806,
            child: ValueListenableBuilder<DashboardData?>(
              valueListenable: dataListenable,
              builder: (context, data, _) => _RuntimeAlertPopup(
                key: ValueKey<String>(
                  isFault ? 'fault-alert-dialog' : 'notification-center-dialog',
                ),
                type: type,
                data: data ?? DashboardData.defaults(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeAlertPopup extends StatefulWidget {
  const _RuntimeAlertPopup({
    Key? key,
    required this.type,
    required this.data,
  }) : super(key: key);

  final _RuntimeAlertDialogType type;
  final DashboardData data;

  @override
  State<_RuntimeAlertPopup> createState() => _RuntimeAlertPopupState();
}

class _RuntimeAlertPopupState extends State<_RuntimeAlertPopup> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _confirmedNotificationIds = <String>{};
  late final List<DashboardAlertItem> _notificationSnapshot;

  @override
  void initState() {
    super.initState();
    // 通知在打开瞬间拍一份快照；弹窗内只响应本次“确认”。
    // 故障不使用这份快照，仍随两秒聚合刷新实时变化。
    _notificationSnapshot = List<DashboardAlertItem>.unmodifiable(
      widget.data.notifications,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFault = widget.type == _RuntimeAlertDialogType.fault;
    final alerts = isFault
        ? widget.data.faults
        : _notificationSnapshot
            .where((item) => !_confirmedNotificationIds.contains(item.id))
            .toList(growable: false);
    final rowCount = alerts.isEmpty ? 0 : alerts.length + (isFault ? 1 : 0);
    // 通知弹窗已经过视觉确认，故障弹窗只同步其滚动几何：消息视口
    // 延伸到弹窗底边内侧 2px，滑轨保持 632px，末尾补偿 52px。
    // Scrollbar 仍按各自实际内容自动计算滑块长度和移动比例。
    const scrollbarBottomInset = 52.0;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        const Positioned.fill(
          child: Image(
            image: AssetImage('assets/home/alerts/popup-bg.png'),
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          key: ValueKey<String>(
            isFault
                ? 'fault-alert-title-background'
                : 'notification-alert-title-background',
          ),
          left: 32,
          // 两种弹窗的标题背景统一下移到 y=2。若从 y=0 开始，
          // title-bg 会盖住 popup-bg 顶边中段，只剩两端圆角显得较粗。
          top: 2,
          width: 924,
          height: 120,
          // title-bg.png 是 924×120 的单色 #141414 图片，直接绘制即可。
          child: const ColoredBox(
            color: Color(0xFF141414),
          ),
        ),
        Positioned(
          left: 422,
          top: 34,
          width: 144,
          height: 52,
          child: Text(
            isFault ? l10n.faultAlert : l10n.notificationCenter,
            key: ValueKey<String>(
              isFault ? 'fault-alert-title' : 'notification-center-title',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScBoldWght700,
              fontSize: 36,
              height: 1.448,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        if (rowCount == 0)
          Positioned(
            left: 286,
            top: 373,
            width: 416,
            height: 61,
            child: Text(
              isFault ? l10n.noFaults : l10n.noNotifications,
              key: ValueKey<String>(
                isFault
                    ? 'fault-alert-empty-state'
                    : 'notification-center-empty-state',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 42,
                height: 1.448,
                decoration: TextDecoration.none,
              ),
            ),
          )
        else
          Positioned(
            key: ValueKey<String>(
              isFault
                  ? 'fault-alert-scroll-region'
                  : 'notification-center-scroll-region',
            ),
            left: 44,
            top: 120,
            width: 926,
            // 弹窗高 806，滑动区域从 y=120 延伸到下边框内侧 2px：
            // 806 - 120 - 2 = 684。通知与故障使用同一组范围。
            height: 684,
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: MaterialStateProperty.all(
                  const Color(0xFF858585),
                ),
                thickness: MaterialStateProperty.all(6),
                radius: Radius.zero,
              ),
              child: MediaQuery(
                key: ValueKey<String>(
                  isFault
                      ? 'fault-alert-scrollbar-geometry'
                      : 'notification-alert-scrollbar-geometry',
                ),
                data: MediaQuery.of(context).copyWith(
                  // Material Scrollbar 使用 MediaQuery.padding 作为滑轨的
                  // 绘制内距；ListView 已显式设置 padding，不受此值影响。
                  padding: const EdgeInsets.only(
                    bottom: scrollbarBottomInset,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: rowCount > 4,
                  child: ListView.separated(
                    key: ValueKey<String>(
                      isFault ? 'fault-alert-list' : 'notification-center-list',
                    ),
                    controller: _scrollController,
                    // 消息视口比各自滑轨更长；末尾按差值补偿，保证
                    // 滚到底时最后一条内容与该弹窗的滑轨底边平齐。
                    padding: const EdgeInsets.only(
                      right: 26,
                      bottom: scrollbarBottomInset,
                    ),
                    itemCount: rowCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (isFault && index == alerts.length) {
                        return _FaultServiceRow(
                          phone: widget.data.faultServicePhone,
                        );
                      }
                      final item = alerts[index];
                      return _AlertListRow(
                        key: ValueKey<String>('alert-row-${item.id}'),
                        item: item,
                        isFault: isFault,
                        onConfirm: isFault
                            ? null
                            : () => setState(
                                  () => _confirmedNotificationIds.add(item.id),
                                ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        // popup-bg.png 与最新下载的 popup.png 已校验为同一文件。
        // Figma 1:1142 / 1:1143 原始参数为 1px、70% 白色、8px 圆角。
        // 顶边中段偏细的根因是 title-bg 覆盖，不是描边本身，因此恢复 1px。
        if (!isFault)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey<String>(
                  'notification-alert-popup-border',
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        // 故障弹框与通知中心统一使用 1px 外框。
        if (isFault)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey<String>('runtime-alert-popup-border'),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
