part of 'home_page.dart';

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.data,
    required this.timeSource,
    required this.animateWeather,
    required this.onNavigate,
    required this.onManualDeviceTap,
    required this.onNotificationBellTap,
    required this.onFaultTap,
    required this.alertTapEnabled,
    required this.onFloorSelectionChanged,
    required this.onPowerChanged,
    required this.onAirConditionerPowerChanged,
    required this.onFloorHeatPowerChanged,
    required this.onFreshAirPowerChanged,
    required this.onHumidifierPowerChanged,
    required this.onPurePowerChanged,
    required this.onLeaveHome,
    required this.allDevicesPowerBusy,
    required this.airConditionerPowerBusy,
    required this.floorHeatPowerBusy,
    required this.freshAirPowerBusy,
    required this.humidifierPowerBusy,
    required this.purePowerBusy,
    required this.leaveHomeBusy,
  });

  final DashboardData data;
  final TimeSource timeSource;
  final bool animateWeather;
  final ValueChanged<int> onNavigate;
  final ValueChanged<int> onManualDeviceTap;
  final VoidCallback onNotificationBellTap;
  final VoidCallback onFaultTap;
  final bool alertTapEnabled;
  final Future<bool> Function(String selection) onFloorSelectionChanged;
  final ValueChanged<bool> onPowerChanged;
  final ValueChanged<bool> onAirConditionerPowerChanged;
  final ValueChanged<bool> onFloorHeatPowerChanged;
  final ValueChanged<bool> onFreshAirPowerChanged;
  final ValueChanged<bool> onHumidifierPowerChanged;
  final ValueChanged<bool> onPurePowerChanged;
  final VoidCallback onLeaveHome;
  final bool allDevicesPowerBusy;
  final bool airConditionerPowerBusy;
  final bool floorHeatPowerBusy;
  final bool freshAirPowerBusy;
  final bool humidifierPowerBusy;
  final bool purePowerBusy;
  final bool leaveHomeBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The global one-key power gates visible device state without discarding
    // each device's independently stored state.
    final airConditionerOn = data.allDevicesOn && data.airConditionerEnabled;
    final floorHeatOn = data.allDevicesOn && data.floorHeatEnabled;
    // 4CP 模块的开关只显示设备运行快照；settings 仅保存用户目标。
    final freshAirOn = data.freshAirRunning;
    final humidifierOn = data.humidifierRunning;
    final pureOn = data.pureRunning;
    final availableDeviceTypes = DashboardData.availableDeviceTypeOrder
        .where(data.availableDeviceTypes.contains)
        .toList(growable: false);
    final deviceCount = availableDeviceTypes.length;
    final deviceCardWidth = deviceCount >= 5
        ? 273.0
        : deviceCount == 4
            ? 328.0
            : 413.0;
    final deviceCardGap = deviceCount >= 5 ? 10.0 : 12.0;
    // 5/4/3 台各用设计稿专用列宽；2/1/0 台沿用 3 台列宽，
    // 从左侧逐列留空，最右设备和一键区的位置保持不动。
    final deviceCardStart =
        deviceCount >= 4 ? 182.0 : 182.0 + (3 - deviceCount) * (413.0 + 12.0);
    final deviceCardLeft = <String, double>{};
    for (var index = 0; index < availableDeviceTypes.length; index++) {
      deviceCardLeft[availableDeviceTypes[index]] =
          deviceCardStart + index * (deviceCardWidth + deviceCardGap);
    }
    final quickActionLeft = deviceCount >= 5
        ? 1597.0
        : deviceCount == 4
            ? 1542.0
            : 1457.0;
    final quickActionWidth = deviceCount >= 5
        ? 273.0
        : deviceCount == 4
            ? 328.0
            : 413.0;
    final quickAssetVariant = deviceCount >= 5
        ? ''
        : deviceCount == 4
            ? '_4'
            : '_3';
    Offset deviceArtworkOffset(String deviceType) {
      if (deviceCount >= 5) {
        return const Offset(48, 140);
      }
      if (deviceCount == 4) {
        return Offset(deviceType == 'air_conditioner' ? 75 : 76, 140);
      }
      // 3/2/1 台沿用 3 台设计稿的 288×288 母图锚点。超净图形的
      // 视觉重心与其余素材不同，因此按 Figma 坐标单独左移 20 px。
      return Offset(deviceType == 'pure' ? 43 : 63, 95);
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 117,
            child: LeftNavBar(
              currentIndex: 0,
              smartModeActive: data.smartModeRunning,
              manualModeActive: data.manualModeRunning,
              onItemSelected: onNavigate,
            ),
          ),
          Positioned(
            left: 560,
            top: 92,
            child: _AirQualityOrb(
              value: data.displayIndoorPm25,
              animate: animateWeather,
            ),
          ),
          const Positioned(
            left: 560,
            top: 92,
            width: 366,
            height: 366,
            child: _FactoryTestEntry(),
          ),
          Positioned(
            left: 430,
            top: 477,
            child: _IndoorMetrics(data: data),
          ),
          // Figma Home - notice list1: the alert triangle sits to the left of
          // the notification bell, not in the top status bar.
          if (data.faults.isNotEmpty)
            Positioned(
              left: 1048,
              top: 119,
              width: 72,
              height: 72,
              child: const IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 42,
                    height: 39,
                    child: Image(
                      image: AssetImage('assets/home/top/notice_triangle.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          // 铃铛本体可独立隐藏；红点和数字只由通知列表派生。
          if (data.notificationBellVisible)
            Positioned(
              left: 1168,
              top: 119,
              width: 72,
              height: 72,
              child: const IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image(
                      image: AssetImage('assets/home/figma_home/notice.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          if (data.notifications.isNotEmpty)
            Positioned(
              // 与原始铃铛右上角叠放位置一致，但不再是铃铛的子控件。
              left: 1198,
              top: 129,
              width: 32,
              height: 32,
              child: IgnorePointer(
                child: _NotificationBadge(
                  count: data.notifications.length,
                ),
              ),
            ),
          // 显示层全部完成后，最后覆盖独立的 72×72 透明点击层。
          if (alertTapEnabled && data.faults.isNotEmpty)
            Positioned(
              left: 1048,
              top: 119,
              width: 72,
              height: 72,
              child: GestureDetector(
                key: const ValueKey<String>('fault-alert-button'),
                behavior: HitTestBehavior.opaque,
                onTap: onFaultTap,
                child: const SizedBox.expand(),
              ),
            ),
          if (alertTapEnabled && data.notificationBellVisible)
            Positioned(
              left: 1168,
              top: 119,
              width: 72,
              height: 72,
              child: GestureDetector(
                key: const ValueKey<String>('notification-bell'),
                behavior: HitTestBehavior.opaque,
                onTap: onNotificationBellTap,
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            left: 1316,
            top: 102,
            child: _WeatherPanel(
              data: data,
              animateWeather: animateWeather,
              timeSource: timeSource,
            ),
          ),
          if (deviceCardLeft.containsKey('air_conditioner'))
            Positioned(
              left: deviceCardLeft['air_conditioner']!,
              top: 750,
              child: _DeviceCard(
                cardKey: const ValueKey<String>('device-card-air-conditioner'),
                width: deviceCardWidth,
                title: l10n.deviceAirConditioner,
                subtitle: airConditionerOn ? l10n.stateCooling : l10n.stateNotOn,
                enabled: airConditionerOn,
                artwork: airConditionerOn
                    ? 'assets/home/figma_home/home_air_conditioner_on.png'
                    : 'assets/home/figma_home/home_air_conditioner_off.png',
                artworkOffset: deviceArtworkOffset('air_conditioner'),
                artworkOpacity: .7,
                artworkKey: const ValueKey<String>('air-conditioner-artwork'),
                onCardTap: () => onManualDeviceTap(0),
                powerKey: const ValueKey<String>('air-conditioner-power'),
                busy: airConditionerPowerBusy,
                onPowerTap: !airConditionerPowerBusy
                    ? () => onAirConditionerPowerChanged(!airConditionerOn)
                    : null,
              ),
            ),
          if (deviceCardLeft.containsKey('floor_heat'))
            Positioned(
              left: deviceCardLeft['floor_heat']!,
              top: 750,
              child: _DeviceCard(
                cardKey: const ValueKey<String>('device-card-floor-heat'),
                width: deviceCardWidth,
                title: l10n.deviceFloorHeat,
                subtitle: floorHeatOn ? l10n.stateOn : l10n.stateNotOn,
                enabled: floorHeatOn,
                artwork: floorHeatOn
                    ? 'assets/home/figma_home/home_floor_heat_on.png'
                    : 'assets/home/figma_home/home_floor_heat_off.png',
                artworkOffset: deviceArtworkOffset('floor_heat'),
                artworkKey: const ValueKey<String>('floor-heat-artwork'),
                onCardTap: () => onManualDeviceTap(1),
                powerKey: const ValueKey<String>('floor-heat-power'),
                busy: floorHeatPowerBusy,
                onPowerTap: !floorHeatPowerBusy
                    ? () => onFloorHeatPowerChanged(!floorHeatOn)
                    : null,
              ),
            ),
          if (deviceCardLeft.containsKey('fresh_air'))
            Positioned(
              left: deviceCardLeft['fresh_air']!,
              top: 750,
              child: _DeviceCard(
                cardKey: const ValueKey<String>('device-card-fresh-air'),
                width: deviceCardWidth,
                title: l10n.deviceFreshAir,
                subtitle: freshAirOn
                    ? '${l10n.freshAirModeInternalCirculation}\n${l10n.fanLevelHigh}'
                    : l10n.stateNotOn,
                enabled: freshAirOn,
                artwork: freshAirOn
                    ? 'assets/home/figma_home/home_fresh_air_on.png'
                    : 'assets/home/figma_home/home_fresh_air_off.png',
                artworkOffset: deviceArtworkOffset('fresh_air'),
                artworkKey: const ValueKey<String>('fresh-air-artwork'),
                onCardTap: () => onManualDeviceTap(2),
                powerKey: const ValueKey<String>('fresh-air-power'),
                busy: freshAirPowerBusy,
                onPowerTap: !freshAirPowerBusy
                    ? () => onFreshAirPowerChanged(!freshAirOn)
                    : null,
              ),
            ),
          if (deviceCardLeft.containsKey('humidifier'))
            Positioned(
              left: deviceCardLeft['humidifier']!,
              top: 750,
              child: _DeviceCard(
                cardKey: const ValueKey<String>('device-card-humidifier'),
                width: deviceCardWidth,
                title: l10n.deviceHumidifier,
                subtitle: humidifierOn ? '50%' : l10n.stateNotOn,
                enabled: humidifierOn,
                artwork: humidifierOn
                    ? 'assets/home/figma_home/home_humidifier_on.png'
                    : 'assets/home/figma_home/home_humidifier_off.png',
                artworkOffset: deviceArtworkOffset('humidifier'),
                artworkKey: const ValueKey<String>('humidifier-artwork'),
                artworkOpacity: .7,
                onCardTap: () => onManualDeviceTap(3),
                powerKey: const ValueKey<String>('humidifier-power'),
                busy: humidifierPowerBusy,
                onPowerTap: !humidifierPowerBusy
                    ? () => onHumidifierPowerChanged(!humidifierOn)
                    : null,
              ),
            ),
          if (deviceCardLeft.containsKey('pure'))
            Positioned(
              left: deviceCardLeft['pure']!,
              top: 750,
              child: _DeviceCard(
                cardKey: const ValueKey<String>('device-card-pure'),
                width: deviceCardWidth,
                title: l10n.devicePure,
                subtitle: pureOn ? l10n.iefStarting : l10n.stateNotOn,
                enabled: pureOn,
                artwork: pureOn
                    ? 'assets/home/figma_home/home_pure_on.png'
                    : 'assets/home/figma_home/home_pure_off.png',
                artworkOffset: deviceArtworkOffset('pure'),
                artworkKey: const ValueKey<String>('pure-artwork'),
                artworkOpacity: .7,
                onCardTap: () => onManualDeviceTap(4),
                powerKey: const ValueKey<String>('pure-power'),
                busy: purePowerBusy,
                onPowerTap:
                    !purePowerBusy ? () => onPurePowerChanged(!pureOn) : null,
              ),
            ),
          Positioned(
            left: quickActionLeft,
            top: 750,
            child: _QuickAction(
              key: const ValueKey<String>('power-card'),
              // Figma node 1:2501 keeps the wording as a stable action name.
              // The background intentionally has no text, so localization or
              // product wording can change without regenerating the PNG.
              label: l10n.quickPowerAll,
              width: quickActionWidth,
              backgroundAsset: 'assets/home/figma_home/quick_power_background$quickAssetVariant.png',
              foregroundAsset: data.allDevicesOn
                  ? 'assets/home/figma_home/quick_power_on.png'
                  : null,
              onTap: allDevicesPowerBusy
                  ? null
                  : () => onPowerChanged(!data.allDevicesOn),
            ),
          ),
          Positioned(
            left: quickActionLeft,
            top: 948,
            child: _QuickAction(
              key: const ValueKey<String>('leave-home-card'),
              label: l10n.quickLeaveHome,
              width: quickActionWidth,
              backgroundAsset: 'assets/home/figma_home/quick_leave_background$quickAssetVariant.png',
              foregroundAsset: data.leaveHomeActive
                  ? 'assets/home/figma_home/quick_leave_on.png'
                  : null,
              onTap: leaveHomeBusy ? null : onLeaveHome,
            ),
          ),
          Positioned.fill(
            child: _HomeFloorSelector(
              layeringEnabled: data.homeFloorLayeringEnabled,
              selection: data.homeFloorSelection,
              onSelected: onFloorSelectionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryTestEntry extends StatefulWidget {
  const _FactoryTestEntry();

  @override
  State<_FactoryTestEntry> createState() => _FactoryTestEntryState();
}

class _FactoryTestEntryState extends State<_FactoryTestEntry> {
  static const int _requiredTapCount = 8;
  static const Duration _tapResetDelay = Duration(seconds: 3);
  static const String _scriptPath = '/usr/bin/factory_test.sh';

  Timer? _tapResetTimer;
  int _tapCount = 0;
  bool _launchRequested = false;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_launchRequested) return;

    _tapCount++;
    _tapResetTimer?.cancel();
    if (_tapCount < _requiredTapCount) {
      _tapResetTimer = Timer(_tapResetDelay, () => _tapCount = 0);
      return;
    }

    _tapCount = 0;
    _launchRequested = true;
    unawaited(_launchFactoryTest());
  }

  Future<void> _launchFactoryTest() async {
    try {
      await Process.start(
        _scriptPath,
        const <String>[],
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
    } on Object catch (error) {
      _launchRequested = false;
      AppLogger.instance.e(
        '产测脚本启动失败',
        tag: 'HomeDashboard',
        error: error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('factory-test-entry'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: const SizedBox.expand(),
    );
  }
}

class _HomeFloorSelector extends StatefulWidget {
  const _HomeFloorSelector({
    required this.layeringEnabled,
    required this.selection,
    required this.onSelected,
  });

  final bool layeringEnabled;
  final String selection;
  final Future<bool> Function(String selection) onSelected;

  @override
  State<_HomeFloorSelector> createState() => _HomeFloorSelectorState();
}

class _HomeFloorSelectorState extends State<_HomeFloorSelector> {
  static String _label(String value, AppLocalizations l10n) {
    switch (value) {
      case 'all':
        return l10n.floorAll;
      case 'basement_1':
        return l10n.floorBasement1;
      case 'basement_2':
        return l10n.floorBasement2;
      case 'floor_1':
        return l10n.floor1;
      case 'floor_2':
        return l10n.floor2;
      case 'floor_3':
        return l10n.floor3;
      default:
        return l10n.floorAll;
    }
  }

  bool _menuOpen = false;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _HomeFloorSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.layeringEnabled) {
      _menuOpen = false;
    }
  }

  void _toggleMenu() {
    if (_saving || !widget.layeringEnabled) return;
    setState(() => _menuOpen = !_menuOpen);
  }

  Future<void> _select(String selection) async {
    if (_saving) return;
    if (selection == widget.selection) {
      setState(() => _menuOpen = false);
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSelected(selection);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _menuOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (_menuOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('home-floor-menu-barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: _saving ? null : () => setState(() => _menuOpen = false),
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          left: 258,
          top: 92,
          width: 235,
          height: 147,
          child: GestureDetector(
            key: const ValueKey<String>('home-floor-selector'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.layeringEnabled ? _toggleMenu : null,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 37,
                  child: Text(
                    AppLocalizations.of(context).floorIndoor,
                    key: const ValueKey<String>('home-floor-title'),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontFamily: AppFonts.sourceHanSansSc,
                      fontVariations: AppFonts.sourceHanSansScRegularWght400,
                      fontSize: 48,
                      height: 56 / 48,
                    ),
                  ),
                ),
                if (widget.layeringEnabled) ...<Widget>[
                  Positioned(
                    left: 117,
                    top: 68,
                    width: 20,
                    height: 10,
                    child: CustomPaint(
                      key: const ValueKey<String>('home-floor-chevron'),
                      painter: _HomeFloorChevronPainter(open: _menuOpen),
                    ),
                  ),
                  if (!_menuOpen)
                    Positioned(
                      left: 0,
                      top: 100,
                      child: Text(
                        _label(
                          widget.selection,
                          AppLocalizations.of(context),
                        ),
                        key: const ValueKey<String>(
                          'home-floor-selection-label',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontVariations:
                              AppFonts.sourceHanSansScRegularWght400,
                          fontSize: 32,
                          height: 46 / 32,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (widget.layeringEnabled && _menuOpen)
          Positioned(
            left: 258,
            top: 193,
            child: _HomeFloorMenu(
              selection: widget.selection,
              saving: _saving,
              onSelected: _select,
            ),
          ),
      ],
    );
  }
}

class _HomeFloorMenu extends StatelessWidget {
  const _HomeFloorMenu({
    required this.selection,
    required this.saving,
    required this.onSelected,
  });

  final String selection;
  final bool saving;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('home-floor-menu'),
      width: 235,
      height: 336,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD9000000),
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ...List<Widget>.generate(DashboardData.homeFloorSelectionOrder.length,
              (index) {
            final value = DashboardData.homeFloorSelectionOrder[index];
            final selected = value == selection;
            return Positioned(
              left: 1,
              top: index * 56,
              width: 233,
              height: 56,
              child: GestureDetector(
                key: ValueKey<String>('home-floor-choice-$value'),
                behavior: HitTestBehavior.opaque,
                onTap: saving ? null : () => onSelected(value),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: Text(
                        _HomeFloorSelectorState._label(
                          value,
                          AppLocalizations.of(context),
                        ),
                        style: TextStyle(
                          color:
                              selected ? const Color(0xFF42CEE9) : Colors.white,
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontSize: 32,
                          height: 46 / 32,
                          fontVariations:
                              AppFonts.sourceHanSansScRegularWght400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        right: 17,
                        top: 19,
                        width: 24,
                        height: 18,
                        child: CustomPaint(painter: _HomeFloorCheckPainter()),
                      ),
                    if (value != DashboardData.homeFloorSelectionOrder.last)
                      const Positioned(
                        left: 16,
                        right: 16,
                        bottom: 0,
                        height: .5,
                        child: ColoredBox(color: Color(0x80FFFFFF)),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HomeFloorChevronPainter extends CustomPainter {
  const _HomeFloorChevronPainter({required this.open});

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (open) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_HomeFloorChevronPainter oldDelegate) =>
      oldDelegate.open != open;
}

class _HomeFloorCheckPainter extends CustomPainter {
  const _HomeFloorCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .52)
        ..lineTo(size.width * .34, size.height)
        ..lineTo(size.width, 0),
      Paint()
        ..color = const Color(0xFF42CEE9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
