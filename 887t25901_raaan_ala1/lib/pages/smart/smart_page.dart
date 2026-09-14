import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_data.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/horizontal_stepper.dart';
import '../../widgets/prototype_chrome.dart';
import '../../widgets/semicircle_gauge_interaction.dart';

typedef SmartSettingsCommit = Future<bool> Function(
  String controlKey,
  DashboardData Function(DashboardData current) change,
);

class SmartPage extends StatefulWidget {
  const SmartPage({
    Key? key,
    required this.data,
    required this.onBack,
    required this.onCommitSettingsChange,
    required this.entryToken,
  }) : super(key: key);

  final DashboardData data;
  final VoidCallback onBack;
  final SmartSettingsCommit onCommitSettingsChange;
  final int entryToken;

  @override
  State<SmartPage> createState() => _SmartPageState();
}

class _SmartPageState extends State<SmartPage> {
  static const Duration _stepSaveDelay = Duration(milliseconds: 500);

  static const List<_SmartModeProfile> _profiles = <_SmartModeProfile>[
    _SmartModeProfile(
      code: 'standard',
      label: '标准模式',
      temperatureC: 25,
      humidityPercent: 60,
      adjustable: true,
      showsRuntimeFeedback: true,
    ),
    _SmartModeProfile(
      code: 'guest',
      label: '会客模式',
      temperatureC: 24,
      humidityPercent: 55,
      adjustable: true,
      showsRuntimeFeedback: true,
    ),
    _SmartModeProfile(
      code: 'dry',
      label: '干爽模式',
      temperatureC: 24,
      humidityPercent: 40,
    ),
    _SmartModeProfile(
      code: 'warm',
      label: '温润模式',
      temperatureC: 26,
      humidityPercent: 55,
    ),
    _SmartModeProfile(
      code: 'travel',
      label: '旅行模式',
      temperatureC: 25,
      humidityPercent: 55,
      showsTemperature: false,
    ),
  ];

  static String _modeLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'standard':
        return l10n.smartStandard;
      case 'guest':
        return l10n.smartGuest;
      case 'dry':
        return l10n.smartDry;
      case 'warm':
        return l10n.smartHumid;
      case 'travel':
        return l10n.smartTravel;
      default:
        return code;
    }
  }

  static List<PrototypeMenuItem> _sideMenuItems(AppLocalizations l10n) {
    return <PrototypeMenuItem>[
      PrototypeMenuItem(
        _modeLabel('standard', l10n),
        PrototypeGlyph.standard,
        activeIconAsset: 'assets/navigation/smart_standard_active.png',
        inactiveIconAsset: 'assets/navigation/smart_standard_inactive.png',
      ),
      PrototypeMenuItem(
        _modeLabel('guest', l10n),
        PrototypeGlyph.guest,
        activeIconAsset: 'assets/navigation/smart_guest_active.png',
        inactiveIconAsset: 'assets/navigation/smart_guest_inactive.png',
      ),
      PrototypeMenuItem(
        _modeLabel('dry', l10n),
        PrototypeGlyph.dry,
        activeIconAsset: 'assets/navigation/smart_dry_active.png',
        inactiveIconAsset: 'assets/navigation/smart_dry_inactive.png',
      ),
      PrototypeMenuItem(
        _modeLabel('warm', l10n),
        PrototypeGlyph.warm,
        activeIconAsset: 'assets/navigation/smart_warm_active.png',
        inactiveIconAsset: 'assets/navigation/smart_warm_inactive.png',
      ),
      PrototypeMenuItem(
        _modeLabel('travel', l10n),
        PrototypeGlyph.travel,
        activeIconAsset: 'assets/navigation/smart_travel_active.png',
        inactiveIconAsset: 'assets/navigation/smart_travel_inactive.png',
      ),
    ];
  }

  late int _modeIndex;
  late int _draftTemperatureC;
  late int _draftHumidityPercent;
  bool _saving = false;
  bool _temperatureDragging = false;
  bool _humidityDragging = false;
  Timer? _stepSaveTimer;
  bool _stepSaveInFlight = false;
  String? _pendingStepProfileCode;
  int? _pendingTemperatureC;
  int? _pendingHumidityPercent;

  @override
  void initState() {
    super.initState();
    _modeIndex = 0;
    final standard = widget.data.smartModeSetting(_profiles.first.code);
    _draftTemperatureC = standard.temperatureSetpointC;
    _draftHumidityPercent = standard.humiditySetpointPercent;
  }

  @override
  void didUpdateWidget(covariant SmartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryToken != widget.entryToken) {
      _modeIndex = 0;
      final standard = widget.data.smartModeSetting(_profiles.first.code);
      _draftTemperatureC = standard.temperatureSetpointC;
      _draftHumidityPercent = standard.humiditySetpointPercent;
      return;
    }
    // 与手动、历史、设置页保持一致：导航索引只由本地点击和重新进入控制。
    // settings/runtime 刷新不能反向改变导航。
    final selectedProfile = _profiles[_modeIndex];
    final selectedSetting = widget.data.smartModeSetting(selectedProfile.code);
    if (!_temperatureDragging &&
        _pendingTemperatureC == null &&
        !_stepSaveInFlight) {
      _draftTemperatureC = selectedSetting.temperatureSetpointC;
    }
    if (!_humidityDragging &&
        _pendingHumidityPercent == null &&
        !_stepSaveInFlight) {
      _draftHumidityPercent = selectedSetting.humiditySetpointPercent;
    }
  }

  @override
  void dispose() {
    _stepSaveTimer?.cancel();
    super.dispose();
  }

  void _syncSelectedProfileState() {
    final profile = _profiles[_modeIndex];
    final setting = widget.data.smartModeSetting(profile.code);
    _draftTemperatureC = setting.temperatureSetpointC;
    _draftHumidityPercent = setting.humiditySetpointPercent;
  }

  Future<bool> _commit(
    String key,
    DashboardData Function(DashboardData current) change,
  ) async {
    if (_saving) {
      return false;
    }
    setState(() => _saving = true);
    final saved = await widget.onCommitSettingsChange(key, change);
    if (!mounted) {
      return saved;
    }
    setState(() {
      _saving = false;
      if (!saved) {
        _syncSelectedProfileState();
      }
    });
    return saved;
  }

  Future<void> _selectMode(int index) async {
    if (_saving || index < 0 || index >= _profiles.length) {
      return;
    }
    await _flushStepperChanges();
    if (!mounted || _saving) {
      return;
    }
    final profile = _profiles[index];
    if (_modeIndex == index) {
      return;
    }
    setState(() {
      _modeIndex = index;
      final setting = widget.data.smartModeSetting(profile.code);
      _draftTemperatureC = setting.temperatureSetpointC;
      _draftHumidityPercent = setting.humiditySetpointPercent;
    });
  }

  Future<void> _toggleMode() async {
    await _flushStepperChanges();
    if (!mounted || _saving) {
      return;
    }
    final profile = _profiles[_modeIndex];
    final enabled = widget.data.smartModeSetting(profile.code).enabled;
    if (enabled) {
      // ON → OFF：显示退出确认弹窗
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x4D000000),
        builder: (context) => const _SmartExitDialog(),
      );
      if (confirmed != true || !mounted) return;
    }
    // OFF → ON 或确认退出后：切换模式开关状态，不返回上级页面
    await _commit(
      'smart-mode-enable',
      (current) => current.copyWithSmartMode(
        profile.code,
        current.smartModeSetting(profile.code).copyWith(
              enabled: !enabled,
              temperatureSetpointC: _draftTemperatureC,
              humiditySetpointPercent: _draftHumidityPercent,
            ),
      ),
    );
  }

  void _queueTemperatureStep(int delta) {
    final next = (_draftTemperatureC + delta).clamp(16, 30).toInt();
    if (next == _draftTemperatureC) {
      return;
    }
    setState(() => _draftTemperatureC = next);
    _pendingStepProfileCode = _profiles[_modeIndex].code;
    _pendingTemperatureC = next;
    _scheduleStepperSave();
  }

  void _queueHumidityStep(int delta) {
    final next = (_draftHumidityPercent + delta).clamp(30, 70).toInt();
    if (next == _draftHumidityPercent) {
      return;
    }
    setState(() => _draftHumidityPercent = next);
    _pendingStepProfileCode = _profiles[_modeIndex].code;
    _pendingHumidityPercent = next;
    _scheduleStepperSave();
  }

  void _scheduleStepperSave() {
    _stepSaveTimer?.cancel();
    _stepSaveTimer = Timer(_stepSaveDelay, _flushStepperChanges);
  }

  Future<void> _flushStepperChanges() async {
    _stepSaveTimer?.cancel();
    _stepSaveTimer = null;
    if (_stepSaveInFlight || _pendingStepProfileCode == null) {
      return;
    }
    final profileCode = _pendingStepProfileCode!;
    final temperatureC = _pendingTemperatureC;
    final humidityPercent = _pendingHumidityPercent;
    _pendingStepProfileCode = null;
    _pendingTemperatureC = null;
    _pendingHumidityPercent = null;
    _stepSaveInFlight = true;
    await _commit(
      'smart-setpoint-stepper',
      (current) {
        final setting = current.smartModeSetting(profileCode);
        return current.copyWithSmartMode(
          profileCode,
          setting.copyWith(
            temperatureSetpointC: temperatureC ?? setting.temperatureSetpointC,
            humiditySetpointPercent:
                humidityPercent ?? setting.humiditySetpointPercent,
          ),
        );
      },
    );
    _stepSaveInFlight = false;
    if (_pendingStepProfileCode != null && mounted) {
      _stepSaveTimer = Timer(Duration.zero, _flushStepperChanges);
    }
  }

  void _previewTemperature(int value) {
    setState(() {
      _temperatureDragging = true;
      _draftTemperatureC = value.clamp(16, 30).toInt();
    });
  }

  void _previewHumidity(int value) {
    setState(() {
      _humidityDragging = true;
      _draftHumidityPercent = value.clamp(30, 70).toInt();
    });
  }

  Future<void> _finishTemperatureDrag() async {
    _temperatureDragging = false;
    _pendingStepProfileCode = _profiles[_modeIndex].code;
    _pendingTemperatureC = _draftTemperatureC;
    _stepSaveTimer?.cancel();
    await _flushStepperChanges();
  }

  Future<void> _finishHumidityDrag() async {
    _humidityDragging = false;
    _pendingStepProfileCode = _profiles[_modeIndex].code;
    _pendingHumidityPercent = _draftHumidityPercent;
    _stepSaveTimer?.cancel();
    await _flushStepperChanges();
  }

  Future<void> _requestBack() async {
    await _flushStepperChanges();
    if (!mounted || _saving) {
      return;
    }
    // 直接返回，不弹出退出确认弹窗
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = _profiles[_modeIndex];
    final enabled = widget.data.smartModeSetting(profile.code).enabled;
    final editable = profile.adjustable && enabled && !_saving;
    final temperature =
        profile.adjustable ? _draftTemperatureC : profile.temperatureC;
    final humidity =
        profile.adjustable ? _draftHumidityPercent : profile.humidityPercent;
    final gaugeTop = profile.adjustable ? 314.0 : 414.0;

    return PrototypePageChrome(
      prompt: enabled
          ? l10n.smartModeActiveHint(_modeLabel(profile.code, l10n))
          : '',
      onBack: _requestBack,
      backIconAsset: 'assets/navigation/smart_back.png',
      backDividerAsset: 'assets/navigation/wide_back_line.png',
      backLeft: 146,
      backDividerWidth: 232,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 440,
            top: 212,
            child: _SmartContentPanel(modeIndex: _modeIndex),
          ),
          PrototypeSideMenu(
            items: _sideMenuItems(l10n),
            selectedIndex: _modeIndex,
            onSelected: _selectMode,
            top: 254,
            itemGap: 176,
            dividerWidth: 232,
          ),
          Positioned(
            left: 1742,
            top: 244,
            child: GestureDetector(
              key: const ValueKey<String>('smart-enable-switch'),
              behavior: HitTestBehavior.opaque,
              onTap: _saving ? null : _toggleMode,
              child: _Switch(value: enabled),
            ),
          ),
          IgnorePointer(
            ignoring: !editable,
            child: Opacity(
              key: const ValueKey<String>('smart-mode-controls'),
              opacity: enabled ? 1 : .3,
              child: Stack(
                children: <Widget>[
                  if (profile.showsTemperature)
                    Positioned(
                      left: 596 - semicircleGaugeHitPadding,
                      top: gaugeTop,
                      child: SemicircleGauge(
                        gaugeKey: const ValueKey<String>(
                          'smart-temperature-track',
                        ),
                        title: l10n.metricTemperature,
                        titleStyle: _smartGaugeTitleStyle,
                        value: temperature.toString(),
                        valueStyle: _smartGaugeValueStyle,
                        valueTop: 247,
                        unit: '℃',
                        unitStyle: _smartGaugeUnitStyle,
                        currentValue: temperature,
                        minValue: 16,
                        maxValue: 30,
                        minLabel: '16',
                        maxLabel: '30',
                        endpointStyle: _smartTemperatureEndpointStyle,
                        trackColor: const Color(0x4D409EFF),
                        activeColor: const Color(0xFF3370AE),
                        dotColor: const Color(0xFF409EFF),
                        interactionEnabled: editable,
                        onPreviewChanged: editable ? _previewTemperature : null,
                        onInteractionEnd:
                            editable ? _finishTemperatureDrag : null,
                      ),
                    ),
                  Positioned(
                    left: (profile.showsTemperature ? 1252 : 924) -
                        semicircleGaugeHitPadding,
                    top: gaugeTop,
                    child: SemicircleGauge(
                      gaugeKey: const ValueKey<String>(
                        'smart-humidity-track',
                      ),
                      title: l10n.metricHumidity,
                      titleStyle: _smartGaugeTitleStyle,
                      value: humidity.toString(),
                      valueStyle: _smartGaugeValueStyle,
                      valueTop: 243.5,
                      unit: '%',
                      unitStyle: _smartGaugeUnitStyle,
                      currentValue: humidity,
                      minValue: 30,
                      maxValue: 70,
                      minLabel: '30',
                      maxLabel: '70',
                      endpointStyle: _smartHumidityEndpointStyle,
                      trackColor: const Color(0x4D67C23A),
                      activeColor: const Color(0xFF4C872F),
                      dotColor: const Color(0xFF67C23A),
                      interactionEnabled: editable,
                      onPreviewChanged: editable ? _previewHumidity : null,
                      onInteractionEnd: editable ? _finishHumidityDrag : null,
                    ),
                  ),
                  if (profile.adjustable) ...<Widget>[
                    Positioned(
                      left: 696,
                      top: 808,
                      child: HorizontalStepper(
                        keyPrefix: 'temperature',
                        enabled: profile.adjustable && enabled,
                        interactionEnabled: editable,
                        onMinus: () => _queueTemperatureStep(-1),
                        onPlus: () => _queueTemperatureStep(1),
                      ),
                    ),
                    Positioned(
                      left: 1352,
                      top: 808,
                      child: HorizontalStepper(
                        keyPrefix: 'humidity',
                        enabled: profile.adjustable && enabled,
                        interactionEnabled: editable,
                        onMinus: () => _queueHumidityStep(-1),
                        onPlus: () => _queueHumidityStep(1),
                      ),
                    ),
                  ],
                  if (profile.showsRuntimeFeedback) ...<Widget>[
                    Positioned(
                      left: 747,
                      top: 962,
                      child: _BottomMode(
                        label: l10n.manualMode,
                        value: widget.data.smartAirConditionerMode,
                      ),
                    ),
                    Positioned(
                      left: 747,
                      top: 1040,
                      child: _BottomMode(
                        label: l10n.manualFanSpeed,
                        value: widget.data.smartAirConditionerFanLevel,
                      ),
                    ),
                    Positioned(
                      left: 1339,
                      top: 962,
                      child: _BottomMode(
                        label: l10n.manualFreshAirMode,
                        value: widget.data.smartFreshAirMode,
                      ),
                    ),
                    Positioned(
                      left: 1339,
                      top: 1040,
                      child: _BottomMode(
                        label: l10n.manualFreshAirFanSpeed,
                        value: widget.data.smartFreshAirFanLevel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartModeProfile {
  const _SmartModeProfile({
    required this.code,
    required this.label,
    required this.temperatureC,
    required this.humidityPercent,
    this.adjustable = false,
    this.showsRuntimeFeedback = false,
    this.showsTemperature = true,
  });

  final String code;
  final String label;
  final int temperatureC;
  final int humidityPercent;
  final bool adjustable;
  final bool showsRuntimeFeedback;
  final bool showsTemperature;
}

class _SmartContentPanel extends StatelessWidget {
  const _SmartContentPanel({required this.modeIndex});

  final int modeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>(
        modeIndex == 0 ? 'smart-standard-page' : 'smart-mode-page-$modeIndex',
      ),
      width: 1430,
      height: 924,
      decoration: BoxDecoration(
        color: prototypePanel,
        borderRadius: BorderRadius.circular(2),
        image: const DecorationImage(
          image: AssetImage('assets/smart/frame-bg2.png'),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      value
          ? 'assets/smart/standard_toggle_on.png'
          : 'assets/smart/standard_toggle_off.png',
      width: 96,
      height: 48,
      filterQuality: FilterQuality.high,
    );
  }
}

const TextStyle _smartGaugeTitleStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 48,
);
const TextStyle _smartGaugeValueStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyLight,
  fontSize: 150,
  height: 1,
);
const TextStyle _smartGaugeUnitStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 54,
);
const TextStyle _smartTemperatureEndpointStyle = TextStyle(
  color: Color(0xFF3370AE),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 30,
);
const TextStyle _smartHumidityEndpointStyle = TextStyle(
  color: Color(0xFF4C872F),
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScRegularWght400,
  fontSize: 30,
);

class _BottomMode extends StatelessWidget {
  const _BottomMode({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontFamily: AppFonts.sourceHanSansSc,
            fontVariations: AppFonts.sourceHanSansScRegularWght400,
            fontSize: 32,
          ),
        ),
        const SizedBox(width: 36),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.sourceHanSansSc,
            // Figma 65:1667/65:1671：HarmonyOS Sans Regular 42。
            // 嵌入字体中的 HarmonyOS Sans 不含中文字形，因此以
            // Source Han Sans SC Regular 400 显式映射，禁止系统回退。
            fontVariations: AppFonts.sourceHanSansScRegularWght400,
            fontWeight: FontWeight.w400,
            fontSize: 42,
          ),
        ),
      ],
    );
  }
}

class _SmartExitDialog extends StatelessWidget {
  const _SmartExitDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey<String>('smart-exit-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 1440,
        height: 524,
        decoration: BoxDecoration(
          color: prototypePanel,
          border: Border.all(color: const Color(0xFF676767)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 321,
              top: 160,
              width: 798,
              child: Text(
                l10n.smartExitMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 42,
                ),
              ),
            ),
            Positioned(
              left: 400,
              top: 336,
              child: _DialogButton(
                keyName: 'smart-exit-cancel',
                label: l10n.cancel,
                color: const Color(0xFF555555),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            Positioned(
              left: 820,
              top: 336,
              child: _DialogButton(
                keyName: 'smart-exit-confirm',
                label: l10n.confirm,
                color: const Color(0xFF3478D4),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.keyName,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 220,
        height: 100,
        color: color,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.sourceHanSansSc,
            fontVariations: AppFonts.sourceHanSansScRegularWght400,
            fontSize: 36,
          ),
        ),
      ),
    );
  }
}
