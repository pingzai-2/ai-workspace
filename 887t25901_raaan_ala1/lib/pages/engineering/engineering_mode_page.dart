import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_persistent_data.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/touch_password_keyboard.dart';

/// 工程施工期使用的本地操作页。
///
/// 搜索结果、试运行开关、工程密码和产测过程数据只保存在内存中。
/// 只有点击“施工完成确认”才会把明确可确认的工程配置写入长期文件。
class EngineeringModePage extends StatefulWidget {
  const EngineeringModePage({
    Key? key,
    required this.engineeringPassword,
    required this.onEngineeringPasswordChanged,
    required this.persistentData,
    required this.onSavePersistentConfiguration,
    required this.onExit,
  }) : super(key: key);

  final String engineeringPassword;
  final ValueChanged<String> onEngineeringPasswordChanged;
  final DashboardPersistentData persistentData;
  final Future<bool> Function(DashboardPersistentData next)
      onSavePersistentConfiguration;
  final VoidCallback onExit;

  @override
  State<EngineeringModePage> createState() => _EngineeringModePageState();
}

enum _EngineeringView {
  home,
  freshAir,
  airConditioner,
  floorHeat,
  system,
  productionTest,
}

enum _EngineeringChoiceKind { area, room }

enum _PasswordEntryStep { first, repeat }

class _EngineeringModePageState extends State<EngineeringModePage> {
  _EngineeringView _view = _EngineeringView.home;
  bool _showNameSettings = false;
  bool? _showRoomNames;
  bool _constructionConfirmed = false;
  bool _savingPersistentConfiguration = false;
  final Set<_EngineeringView> _searchedViews = <_EngineeringView>{};
  final Map<String, bool> _trialRunning = <String, bool>{};
  final Map<String, String> _areas = <String, String>{};
  final Map<String, String> _rooms = <String, String>{};
  _EngineeringChoiceKind? _choiceKind;
  String? _choiceDeviceKey;
  String? _choiceDraft;
  bool _passwordEditorVisible = false;
  _PasswordEntryStep _passwordEntryStep = _PasswordEntryStep.first;
  String _passwordInput = '';
  String? _firstPasswordInput;
  String? _pendingEngineeringPassword;
  String? _passwordMessage;
  bool _passwordMessageIsError = false;

  static const List<String> _areaNames = <String>[
    '地下一层',
    '地下二层',
    '一层',
    '二层',
    '三层',
  ];

  static const List<String> _roomNames = <String>[
    '室外1',
    '室外2',
    '客厅',
    '餐厅',
    '主卧',
    '书房',
    '茶室',
    '儿童房',
    '父母房',
    '次卧1',
    '次卧2',
  ];

  @override
  void initState() {
    super.initState();
    _areas.addAll(widget.persistentData.engineeringDeviceAreas);
    _rooms.addAll(widget.persistentData.engineeringDeviceRooms);
  }

  void _open(_EngineeringView view) {
    setState(() {
      _view = view;
      _searchedViews.remove(view);
      _constructionConfirmed = false;
      _showNameSettings = false;
      _showRoomNames = null;
      _clearChoice();
    });
  }

  void _backToHome() {
    setState(() {
      _view = _EngineeringView.home;
      _showNameSettings = false;
      _showRoomNames = null;
      _clearChoice();
    });
  }

  void _backFromProductionTest() {
    setState(() {
      _view = _EngineeringView.home;
      _constructionConfirmed = false;
      _showNameSettings = false;
      _showRoomNames = null;
      _clearChoice();
    });
  }

  void _openNameSettings() {
    setState(() {
      _showNameSettings = true;
      _showRoomNames = null;
    });
  }

  void _closeNameSettings() {
    setState(() {
      _showNameSettings = false;
      _showRoomNames = null;
    });
  }

  Future<void> _confirmConstruction() async {
    if (_savingPersistentConfiguration) {
      return;
    }
    setState(() => _savingPersistentConfiguration = true);
    final saved = await widget.onSavePersistentConfiguration(
      DashboardPersistentData(
        engineeringDeviceAreas: Map<String, String>.unmodifiable(_areas),
        engineeringDeviceRooms: Map<String, String>.unmodifiable(_rooms),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _savingPersistentConfiguration = false;
      _constructionConfirmed = saved;
    });
  }

  void _openChoice(
    String deviceKey,
    _EngineeringChoiceKind kind,
    String currentValue,
  ) {
    setState(() {
      _choiceDeviceKey = deviceKey;
      _choiceKind = kind;
      _choiceDraft = currentValue;
    });
  }

  void _clearChoice() {
    _choiceDeviceKey = null;
    _choiceKind = null;
    _choiceDraft = null;
  }

  void _confirmChoice() {
    final deviceKey = _choiceDeviceKey;
    final kind = _choiceKind;
    final value = _choiceDraft;
    if (deviceKey == null || kind == null || value == null || value.isEmpty) {
      setState(_clearChoice);
      return;
    }
    setState(() {
      if (kind == _EngineeringChoiceKind.area) {
        _areas[deviceKey] = value;
      } else {
        _rooms[deviceKey] = value;
      }
      _clearChoice();
    });
  }

  void _openPasswordEditor() {
    setState(() {
      _passwordEditorVisible = true;
      _passwordEntryStep = _PasswordEntryStep.first;
      _passwordInput = '';
      _firstPasswordInput = null;
      _pendingEngineeringPassword = null;
      _passwordMessage = null;
      _passwordMessageIsError = false;
    });
  }

  void _changePasswordInput(String value) {
    setState(() {
      _passwordInput = value;
      _passwordMessage = null;
      _passwordMessageIsError = false;
    });
  }

  void _confirmPasswordInput(String value) {
    final valid = value.length == 6 &&
        value.codeUnits.every((code) => code >= 48 && code <= 57);
    if (!valid) {
      setState(() {
        _passwordMessage = AppLocalizations.of(context).engineeringEnter6DigitPassword;
        _passwordMessageIsError = true;
      });
      return;
    }
    if (_passwordEntryStep == _PasswordEntryStep.first) {
      setState(() {
        _firstPasswordInput = value;
        _passwordEntryStep = _PasswordEntryStep.repeat;
        _passwordInput = '';
        _passwordMessage = null;
        _passwordMessageIsError = false;
      });
      return;
    }
    if (value != _firstPasswordInput) {
      setState(() {
        _passwordEntryStep = _PasswordEntryStep.first;
        _passwordInput = '';
        _firstPasswordInput = null;
        _passwordMessage =
            AppLocalizations.of(context).engineeringPasswordMismatch;
        _passwordMessageIsError = true;
      });
      return;
    }
    setState(() {
      _passwordEditorVisible = false;
      _passwordInput = '';
      _firstPasswordInput = null;
      _pendingEngineeringPassword = value;
      _passwordMessage =
          AppLocalizations.of(context).engineeringPasswordMatchConfirm;
      _passwordMessageIsError = false;
    });
  }

  void _cancelPasswordEditor() {
    setState(() {
      _passwordEditorVisible = false;
      _passwordInput = '';
      _firstPasswordInput = null;
      _passwordMessage = null;
      _passwordMessageIsError = false;
    });
  }

  void _applyPendingEngineeringPassword() {
    final password = _pendingEngineeringPassword;
    if (password == null) {
      return;
    }
    widget.onEngineeringPasswordChanged(password);
    setState(() {
      _pendingEngineeringPassword = null;
      _passwordMessage = AppLocalizations.of(context).engineeringApplied;
      _passwordMessageIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_view == _EngineeringView.home) {
      return _EngineeringHome(
        confirmed: _constructionConfirmed,
        saving: _savingPersistentConfiguration,
        onFreshAir: () => _open(_EngineeringView.freshAir),
        onAirConditioner: () => _open(_EngineeringView.airConditioner),
        onFloorHeat: () => _open(_EngineeringView.floorHeat),
        onSystem: () => _open(_EngineeringView.system),
        onProductionTest: () => _open(_EngineeringView.productionTest),
        onConfirm: _confirmConstruction,
        onExit: widget.onExit,
      );
    }
    if (_view == _EngineeringView.productionTest) {
      return _ProductionTestPage(onExit: _backFromProductionTest);
    }
    if (_showNameSettings) {
      return _NameSettingsPage(
        allowRooms: _view == _EngineeringView.airConditioner,
        showRooms: _showRoomNames,
        areaNames: _areaNames,
        roomNames: _roomNames,
        onSelectTab: (showRooms) => setState(() => _showRoomNames = showRooms),
        onBack: _closeNameSettings,
      );
    }
    return _EngineeringConfigurationPage(
      view: _view,
      devicesVisible: _searchedViews.contains(_view),
      trialRunning: _trialRunning,
      areas: _areas,
      rooms: _rooms,
      areaNames: _areaNames,
      roomNames: _roomNames,
      choiceKind: _choiceKind,
      choiceDraft: _choiceDraft,
      onSearch: () => setState(() => _searchedViews.add(_view)),
      onNameSettings: _openNameSettings,
      onConfirmAndBack: _backToHome,
      onTrialChanged: (key) =>
          (value) => setState(() => _trialRunning[key] = value),
      onChoiceRequested: _openChoice,
      onChoiceDraftChanged: (value) => setState(() => _choiceDraft = value),
      onChoiceConfirmed: _confirmChoice,
      onChoiceCancelled: () => setState(_clearChoice),
      passwordEditorVisible: _passwordEditorVisible,
      passwordEntryStep: _passwordEntryStep,
      passwordInput: _passwordInput,
      pendingEngineeringPassword: _pendingEngineeringPassword,
      passwordMessage: _passwordMessage,
      passwordMessageIsError: _passwordMessageIsError,
      onPasswordEditRequested: _openPasswordEditor,
      onPasswordInputChanged: _changePasswordInput,
      onPasswordInputConfirmed: _confirmPasswordInput,
      onPasswordEditCancelled: _cancelPasswordEditor,
      onPasswordApplied: _applyPendingEngineeringPassword,
    );
  }
}

class _EngineeringHome extends StatelessWidget {
  const _EngineeringHome({
    required this.confirmed,
    required this.saving,
    required this.onFreshAir,
    required this.onAirConditioner,
    required this.onFloorHeat,
    required this.onSystem,
    required this.onProductionTest,
    required this.onConfirm,
    required this.onExit,
  });

  final bool confirmed;
  final bool saving;
  final VoidCallback onFreshAir;
  final VoidCallback onAirConditioner;
  final VoidCallback onFloorHeat;
  final VoidCallback onSystem;
  final VoidCallback onProductionTest;
  final Future<void> Function() onConfirm;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 105,
            left: 0,
            right: 0,
            child: Text(
              l10n.menuEngineering,
              textAlign: TextAlign.center,
              style: _engineeringTitle,
            ),
          ),
          // 工程主页固定为 2 列 × 4 行；目前仅启用前五个入口，后三格预留。
          _HomeAction(
            left: 430,
            top: 290,
            height: 150,
            label: l10n.engineeringFreshAirConfig,
            onTap: onFreshAir,
          ),
          _HomeAction(
            left: 990,
            top: 290,
            height: 150,
            label: l10n.engineeringAcConfig,
            onTap: onAirConditioner,
          ),
          _HomeAction(
            left: 430,
            top: 470,
            height: 150,
            label: l10n.engineeringFloorHeatConfig,
            onTap: onFloorHeat,
          ),
          _HomeAction(
            left: 990,
            top: 470,
            height: 150,
            label: l10n.menuSettings,
            onTap: onSystem,
          ),
          _HomeAction(
            left: 430,
            top: 650,
            height: 150,
            label: l10n.engineeringProductionTestConfig,
            onTap: onProductionTest,
          ),
          _EngineeringButton(
            left: 535,
            top: 1044,
            width: 294,
            label: l10n.engineeringCompleteInstallation,
            onTap: () {
              onConfirm();
            },
          ),
          if (confirmed || saving)
            Positioned(
              left: 535,
              top: 998,
              width: 294,
              child: Text(
                saving ? l10n.engineeringSavingConfig : l10n.engineeringConfigConfirmed,
                textAlign: TextAlign.center,
                style: _confirmationText,
              ),
            ),
          _EngineeringButton(
            left: 1091,
            top: 1044,
            width: 294,
            label: l10n.exit,
            onTap: onExit,
          ),
        ],
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.left,
    required this.top,
    this.height = 280,
    required this.label,
    required this.onTap,
  });

  final double left;
  final double top;
  final double height;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 500,
          height: height,
          alignment: Alignment.center,
          color: const Color(0xFF4D4D4D),
          child: Text(label, style: _homeActionText),
        ),
      ),
    );
  }
}

/// 产测当前只保留进入/退出和特殊模式边界，不落盘、不驱动正常数据链路。
class _ProductionTestPage extends StatelessWidget {
  const _ProductionTestPage({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 105,
            left: 0,
            right: 0,
            child: Text(
              l10n.engineeringProductionTestTitle,
              textAlign: TextAlign.center,
              style: _engineeringTitle,
            ),
          ),
          _EngineeringButton(
            left: 813,
            top: 1010,
            width: 294,
            label: l10n.exit,
            onTap: onExit,
          ),
        ],
      ),
    );
  }
}

class _EngineeringConfigurationPage extends StatelessWidget {
  const _EngineeringConfigurationPage({
    required this.view,
    required this.devicesVisible,
    required this.trialRunning,
    required this.areas,
    required this.rooms,
    required this.areaNames,
    required this.roomNames,
    required this.choiceKind,
    required this.choiceDraft,
    required this.onSearch,
    required this.onNameSettings,
    required this.onConfirmAndBack,
    required this.onTrialChanged,
    required this.onChoiceRequested,
    required this.onChoiceDraftChanged,
    required this.onChoiceConfirmed,
    required this.onChoiceCancelled,
    required this.passwordEditorVisible,
    required this.passwordEntryStep,
    required this.passwordInput,
    required this.pendingEngineeringPassword,
    required this.passwordMessage,
    required this.passwordMessageIsError,
    required this.onPasswordEditRequested,
    required this.onPasswordInputChanged,
    required this.onPasswordInputConfirmed,
    required this.onPasswordEditCancelled,
    required this.onPasswordApplied,
  });

  final _EngineeringView view;
  final bool devicesVisible;
  final Map<String, bool> trialRunning;
  final Map<String, String> areas;
  final Map<String, String> rooms;
  final List<String> areaNames;
  final List<String> roomNames;
  final _EngineeringChoiceKind? choiceKind;
  final String? choiceDraft;
  final VoidCallback onSearch;
  final VoidCallback onNameSettings;
  final VoidCallback onConfirmAndBack;
  final ValueChanged<bool> Function(String key) onTrialChanged;
  final void Function(
    String deviceKey,
    _EngineeringChoiceKind kind,
    String currentValue,
  ) onChoiceRequested;
  final ValueChanged<String> onChoiceDraftChanged;
  final VoidCallback onChoiceConfirmed;
  final VoidCallback onChoiceCancelled;
  final bool passwordEditorVisible;
  final _PasswordEntryStep passwordEntryStep;
  final String passwordInput;
  final String? pendingEngineeringPassword;
  final String? passwordMessage;
  final bool passwordMessageIsError;
  final VoidCallback onPasswordEditRequested;
  final ValueChanged<String> onPasswordInputChanged;
  final ValueChanged<String> onPasswordInputConfirmed;
  final VoidCallback onPasswordEditCancelled;
  final VoidCallback onPasswordApplied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSystem = view == _EngineeringView.system;
    final title = isSystem
        ? l10n.menuSettings
        : view == _EngineeringView.freshAir
            ? l10n.engineeringFreshAirConfig
            : view == _EngineeringView.airConditioner
                ? l10n.engineeringAcConfig
                : l10n.engineeringFloorHeatConfig;
    final devices =
        devicesVisible ? _devicesFor(view) : const <_EngineerDevice>[];
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 84,
            left: 0,
            right: 0,
            child: Text(title,
                textAlign: TextAlign.center, style: _engineeringTitle),
          ),
          Positioned(
            left: 100,
            top: 220,
            child: Container(
              width: 1720,
              height: 900,
              color: const Color(0xFF4A4A4A),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 168,
                    child: Stack(
                      children: <Widget>[
                        _OutlineAction(
                            keyName: 'engineering-device-search',
                            left: 76,
                            top: 63,
                            label: l10n.engineeringDeviceSearch,
                            onTap: onSearch),
                        if (!isSystem)
                          _OutlineAction(
                            keyName: 'engineering-name-settings',
                            left: 290,
                            top: 63,
                            label: l10n.engineeringNameSettings,
                            onTap: onNameSettings,
                          ),
                        _OutlineAction(
                          keyName: 'engineering-confirm-and-return',
                          left: 1470,
                          top: 63,
                          label: l10n.engineeringSaveAndReturn,
                          onTap: onConfirmAndBack,
                        ),
                      ],
                    ),
                  ),
                  _ConfigurationTable(
                    view: view,
                    devices: devices,
                    trialRunning: trialRunning,
                    areas: areas,
                    rooms: rooms,
                    onTrialChanged: onTrialChanged,
                    onChoiceRequested: onChoiceRequested,
                    pendingEngineeringPassword: pendingEngineeringPassword,
                    passwordMessage: passwordMessage,
                    passwordMessageIsError: passwordMessageIsError,
                    onPasswordEditRequested: onPasswordEditRequested,
                    onPasswordApplied: onPasswordApplied,
                  ),
                ],
              ),
            ),
          ),
          if (choiceKind != null)
            _EngineeringChoiceOverlay(
              title: choiceKind == _EngineeringChoiceKind.area
                  ? l10n.engineeringAreaSelect
                  : l10n.engineeringRoomSelect,
              values: choiceKind == _EngineeringChoiceKind.area
                  ? areaNames
                  : roomNames,
              selectedValue: choiceDraft ?? '',
              onSelected: onChoiceDraftChanged,
              onConfirm: onChoiceConfirmed,
              onCancel: onChoiceCancelled,
            ),
          if (isSystem && passwordEditorVisible)
            _EngineeringPasswordEditOverlay(
              step: passwordEntryStep,
              value: passwordInput,
              message: passwordMessage,
              messageIsError: passwordMessageIsError,
              onChanged: onPasswordInputChanged,
              onConfirm: onPasswordInputConfirmed,
              onCancel: onPasswordEditCancelled,
            ),
        ],
      ),
    );
  }
}

class _ConfigurationTable extends StatelessWidget {
  const _ConfigurationTable({
    required this.view,
    required this.devices,
    required this.trialRunning,
    required this.areas,
    required this.rooms,
    required this.onTrialChanged,
    required this.onChoiceRequested,
    required this.pendingEngineeringPassword,
    required this.passwordMessage,
    required this.passwordMessageIsError,
    required this.onPasswordEditRequested,
    required this.onPasswordApplied,
  });

  final _EngineeringView view;
  final List<_EngineerDevice> devices;
  final Map<String, bool> trialRunning;
  final Map<String, String> areas;
  final Map<String, String> rooms;
  final ValueChanged<bool> Function(String key) onTrialChanged;
  final void Function(
    String deviceKey,
    _EngineeringChoiceKind kind,
    String currentValue,
  ) onChoiceRequested;
  final String? pendingEngineeringPassword;
  final String? passwordMessage;
  final bool passwordMessageIsError;
  final VoidCallback onPasswordEditRequested;
  final VoidCallback onPasswordApplied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (view == _EngineeringView.system) {
      return Expanded(
        child: _SystemParameterTable(
          devicesVisible: devices.isNotEmpty,
          pendingEngineeringPassword: pendingEngineeringPassword,
          passwordMessage: passwordMessage,
          passwordMessageIsError: passwordMessageIsError,
          onPasswordEditRequested: onPasswordEditRequested,
          onPasswordApplied: onPasswordApplied,
        ),
      );
    }
    final hasFloorHeatColumn = view == _EngineeringView.airConditioner;
    final hasRoomColumn = view != _EngineeringView.freshAir;
    return Expanded(
      child: Column(
        children: <Widget>[
          _TableRow(
            height: 72,
            cells: <Widget>[
              _Cell(text: l10n.engineeringDeviceName, width: 370, header: true),
              if (hasFloorHeatColumn)
                const _Cell(text: '地暖', width: 118, header: true),
              _Cell(
                  text: l10n.engineeringConfigAddress,
                  width: hasFloorHeatColumn ? 250 : 380,
                  header: true),
              _Cell(
                  text: l10n.engineeringAreaName,
                  width: hasRoomColumn ? (hasFloorHeatColumn ? 370 : 360) : 730,
                  header: true),
              if (hasRoomColumn)
                _Cell(
                    text: l10n.engineeringRoomName,
                    width: hasFloorHeatColumn ? 370 : 370,
                    header: true),
              _Cell(
                  text: l10n.engineeringTestRun,
                  width: hasFloorHeatColumn ? 242 : 240,
                  header: true),
            ],
          ),
          for (var index = 0; index < 11; index++)
            _DeviceRow(
              device: index < devices.length ? devices[index] : null,
              view: view,
              trialRunning: trialRunning,
              areas: areas,
              rooms: rooms,
              onTrialChanged: onTrialChanged,
              onChoiceRequested: onChoiceRequested,
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.view,
    required this.trialRunning,
    required this.areas,
    required this.rooms,
    required this.onTrialChanged,
    required this.onChoiceRequested,
  });

  final _EngineerDevice? device;
  final _EngineeringView view;
  final Map<String, bool> trialRunning;
  final Map<String, String> areas;
  final Map<String, String> rooms;
  final ValueChanged<bool> Function(String key) onTrialChanged;
  final void Function(
    String deviceKey,
    _EngineeringChoiceKind kind,
    String currentValue,
  ) onChoiceRequested;

  @override
  Widget build(BuildContext context) {
    final hasFloorHeatColumn = view == _EngineeringView.airConditioner;
    final hasRoomColumn = view != _EngineeringView.freshAir;
    final key = device?.key ?? '';
    final area = areas[key] ?? '';
    final room = rooms[key] ?? '';
    return _TableRow(
      height: 60,
      cells: <Widget>[
        _Cell(text: device?.name ?? '', width: 370),
        if (hasFloorHeatColumn)
          _Cell(text: device?.floorHeat ?? '', width: 118),
        _Cell(
            text: device?.address ?? '', width: hasFloorHeatColumn ? 250 : 380),
        _ChoiceCell(
          keyName: 'engineering-area-choice-$key',
          value: area,
          width: hasRoomColumn ? (hasFloorHeatColumn ? 370 : 360) : 730,
          enabled: device != null,
          onTap: () => onChoiceRequested(
            key,
            _EngineeringChoiceKind.area,
            area,
          ),
        ),
        if (hasRoomColumn)
          _ChoiceCell(
            keyName: 'engineering-room-choice-$key',
            value: room,
            width: hasFloorHeatColumn ? 370 : 370,
            enabled: device != null,
            onTap: () => onChoiceRequested(
              key,
              _EngineeringChoiceKind.room,
              room,
            ),
          ),
        _Cell(
          width: hasFloorHeatColumn ? 242 : 240,
          child: device == null
              ? const SizedBox.shrink()
              : _EngineeringTrialSwitch(
                  keyName: 'engineering-trial-$key',
                  value: trialRunning[key] ?? false,
                  onChanged: onTrialChanged(key),
                ),
        ),
      ],
    );
  }
}

class _EngineeringTrialSwitch extends StatelessWidget {
  const _EngineeringTrialSwitch({
    required this.keyName,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: value,
      child: GestureDetector(
        key: ValueKey<String>(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Image.asset(
          value
              ? 'assets/settings/toggle-button-on.png'
              : 'assets/settings/toggle-button-off.png',
          width: 70,
          height: 34,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _NameSettingsPage extends StatelessWidget {
  const _NameSettingsPage({
    required this.allowRooms,
    required this.showRooms,
    required this.areaNames,
    required this.roomNames,
    required this.onSelectTab,
    required this.onBack,
  });

  final bool allowRooms;
  final bool? showRooms;
  final List<String> areaNames;
  final List<String> roomNames;
  final ValueChanged<bool> onSelectTab;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = showRooms == null
        ? const <String>[]
        : showRooms!
            ? roomNames
            : areaNames;
    final showAddPrompt = showRooms != null && rows.length < 11;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
              top: 84,
              left: 0,
              right: 0,
              child: Text(l10n.engineeringNameSettings,
                  textAlign: TextAlign.center, style: _engineeringTitle)),
          Positioned(
            left: 100,
            top: 220,
            child: Container(
              width: 1720,
              height: 900,
              color: const Color(0xFF4A4A4A),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 76,
                    top: 63,
                    child: Row(
                      children: <Widget>[
                        _NameTab(
                            keyName: 'engineering-area-name-tab',
                            label: l10n.engineeringAreaName,
                            selected: showRooms == false,
                            onTap: () => onSelectTab(false)),
                        if (allowRooms) ...<Widget>[
                          const SizedBox(width: 34),
                          _NameTab(
                              keyName: 'engineering-room-name-tab',
                              label: l10n.engineeringRoomName,
                              selected: showRooms == true,
                              onTap: () => onSelectTab(true)),
                        ],
                      ],
                    ),
                  ),
                  _OutlineAction(
                    keyName: 'engineering-name-settings-return',
                    left: 1470,
                    top: 63,
                    label: l10n.engineeringSaveAndReturn,
                    onTap: onBack,
                  ),
                  Positioned(
                    left: 0,
                    top: 168,
                    child: Column(
                      children: <Widget>[
                        _TableRow(height: 72, cells: <Widget>[
                          _Cell(
                              text: showRooms == null
                                  ? ''
                                  : showRooms!
                                      ? l10n.engineeringRoomId
                                      : l10n.engineeringAreaId,
                              width: 470,
                              header: true),
                          _Cell(
                              text: showRooms == null
                                  ? ''
                                  : showRooms!
                                      ? l10n.engineeringRoomName
                                      : l10n.engineeringAreaName,
                              width: 1250,
                              header: true),
                        ]),
                        for (var index = 0; index < rows.length; index++)
                          _TableRow(height: 60, cells: <Widget>[
                            _Cell(
                                text: '${index + 1}'.padLeft(2, '0'),
                                width: 470),
                            _Cell(text: _areaLabel(rows[index], l10n), width: 1250),
                          ]),
                        if (showAddPrompt)
                          _TableRow(height: 60, cells: <Widget>[
                            const _Cell(text: '', width: 470),
                            _Cell(
                              text: showRooms == true
                                  ? l10n.engineeringAddRoomHint
                                  : l10n.engineeringAddAreaHint,
                              width: 1250,
                              muted: true,
                            ),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemParameterTable extends StatelessWidget {
  const _SystemParameterTable({
    required this.devicesVisible,
    required this.pendingEngineeringPassword,
    required this.passwordMessage,
    required this.passwordMessageIsError,
    required this.onPasswordEditRequested,
    required this.onPasswordApplied,
  });

  final bool devicesVisible;
  final String? pendingEngineeringPassword;
  final String? passwordMessage;
  final bool passwordMessageIsError;
  final VoidCallback onPasswordEditRequested;
  final VoidCallback onPasswordApplied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        _TableRow(height: 72, cells: <Widget>[
          _Cell(text: l10n.engineeringDeviceName, width: 370, header: true),
          _Cell(text: l10n.engineeringSettingItem, width: 380, header: true),
          _Cell(text: l10n.engineeringParameterSettings, width: 970, header: true),
        ]),
        if (!devicesVisible)
          for (var index = 0; index < 11; index++)
            const _TableRow(height: 60, cells: <Widget>[
              _Cell(text: '', width: 370),
              _Cell(text: '', width: 380),
              _Cell(text: '', width: 970),
            ])
        else ...<Widget>[
          _TableRow(height: 60, cells: <Widget>[
            _Cell(text: l10n.engineeringPanelName, width: 370),
            _Cell(text: l10n.engineeringTempHumiditySensor, width: 380),
            _Cell(text: l10n.engineeringTempHumidityParams, width: 970),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringPasswordSetting, width: 380),
            _Cell(
              width: 970,
              child: _EngineeringPasswordSettingRow(
                passwordReady: pendingEngineeringPassword != null,
                message: passwordMessage,
                messageIsError: passwordMessageIsError,
                onRepeatInput: onPasswordEditRequested,
                onConfirm: onPasswordApplied,
              ),
            ),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringFilterLife, width: 380),
            const _Cell(
              width: 970,
              child: _InlineParameters(
                values: <String>['湿膜', 'IEF'],
                placeholders: <String>['100-999', '100-999'],
              ),
            ),
          ]),
          const _TableRow(height: 60, cells: <Widget>[
            _Cell(text: '', width: 370),
            _Cell(text: '', width: 380),
            _Cell(
              width: 970,
              child: _InlineParameters(
                values: <String>['初效', '中效', '高效'],
                placeholders: <String>['100-999', '100-999', '100-999'],
              ),
            ),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringMaintenanceInterval, width: 380),
            const _Cell(
              width: 970,
              child: _MaintenanceParameterRow(),
            ),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringServicePhone, width: 380),
            const _Cell(
              width: 970,
              child: _ParameterBox(text: 'xxx-xxx-xxx-xxx', width: 260),
            ),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '4CP #0', width: 370),
            _Cell(text: l10n.engineeringMotorSpeedTitle(1), width: 380),
            const _Cell(width: 970, child: _MotorParameterRow(levelCount: 5)),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringMotorSpeedTitle(2), width: 380),
            const _Cell(width: 970, child: _MotorParameterRow(levelCount: 5)),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringMotorSpeedTitle(3), width: 380),
            const _Cell(width: 970, child: _MotorParameterRow(levelCount: 3)),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringMotorSpeedTitle(4), width: 380),
            const _Cell(width: 970, child: _MotorParameterRow(levelCount: 3)),
          ]),
          _TableRow(height: 60, cells: <Widget>[
            const _Cell(text: '', width: 370),
            _Cell(text: l10n.engineeringCompressorFreq, width: 380),
            const _Cell(width: 970, child: _MotorParameterRow(levelCount: 1)),
          ]),
        ],
      ],
    );
  }
}

class _EngineeringPasswordSettingRow extends StatelessWidget {
  const _EngineeringPasswordSettingRow({
    required this.passwordReady,
    required this.message,
    required this.messageIsError,
    required this.onRepeatInput,
    required this.onConfirm,
  });

  final bool passwordReady;
  final String? message;
  final bool messageIsError;
  final VoidCallback onRepeatInput;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < 6; index++) ...<Widget>[
            Container(
              key: ValueKey<String>('engineering-password-setting-cell-$index'),
              width: 34,
              height: 38,
              alignment: Alignment.center,
              color: const Color(0xFFE3E3E3),
              child: Text(
                passwordReady ? '*' : '',
                style: const TextStyle(
                  color: Color(0xFF252525),
                  fontSize: 28,
                  height: 1,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontWeight: FontWeight.w400,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                ),
              ),
            ),
            if (index != 5) const SizedBox(width: 8),
          ],
          const SizedBox(width: 26),
          _TableActionButton(
            keyName: 'engineering-password-repeat-input',
            label: l10n.engineeringRepeatInput,
            onTap: onRepeatInput,
          ),
          const SizedBox(width: 18),
          _TableActionButton(
            keyName: 'engineering-password-apply',
            label: l10n.confirm,
            enabled: passwordReady,
            onTap: onConfirm,
          ),
          if (message != null) ...<Widget>[
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                message!,
                key: const ValueKey<String>('engineering-password-message'),
                overflow: TextOverflow.ellipsis,
                style: _tableText.copyWith(
                  fontSize: 21,
                  color: messageIsError
                      ? const Color(0xFFFF5A5A)
                      : const Color(0xFF62D6EE),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.keyName,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String keyName;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 132,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF545454) : const Color(0xFF4A4A4A),
          border: Border.all(
            color: enabled ? const Color(0xFFD6D6D6) : const Color(0xFF777777),
          ),
        ),
        child: Text(
          label,
          style: _tableText.copyWith(
            fontSize: 24,
            color: enabled ? const Color(0xFFF1F1F1) : const Color(0xFF858585),
          ),
        ),
      ),
    );
  }
}

class _InlineParameters extends StatelessWidget {
  const _InlineParameters({required this.values, required this.placeholders});

  final List<String> values;
  final List<String> placeholders;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var index = 0; index < values.length; index++) ...<Widget>[
          Text(values[index], style: _tableText.copyWith(fontSize: 24)),
          const SizedBox(width: 10),
          _ParameterBox(text: placeholders[index]),
          if (index != values.length - 1) const SizedBox(width: 28),
        ],
      ],
    );
  }
}

class _MaintenanceParameterRow extends StatelessWidget {
  const _MaintenanceParameterRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(l10n.engineeringNextMaintenanceDays,
            style: _tableText.copyWith(fontSize: 24)),
        const SizedBox(width: 12),
        const _ParameterBox(text: '100-999'),
        const SizedBox(width: 70),
        _TableActionButton(
          keyName: 'engineering-maintenance-reset',
          label: l10n.engineeringReset,
          onTap: _ignoreEngineeringDisplayAction,
        ),
      ],
    );
  }
}

class _MotorParameterRow extends StatelessWidget {
  const _MotorParameterRow({required this.levelCount});

  final int levelCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var index = 0; index < levelCount; index++) ...<Widget>[
          Text('L${index + 1}', style: _tableText.copyWith(fontSize: 22)),
          const SizedBox(width: 6),
          const _ParameterBox(text: '100-999', width: 100),
          if (index != levelCount - 1) const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class _ParameterBox extends StatelessWidget {
  const _ParameterBox({required this.text, this.width = 106});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.center,
      color: const Color(0xFFE7E7E7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8D8D8D),
          fontSize: 19,
          fontFamily: AppFonts.sourceHanSansSc,
          fontWeight: FontWeight.w400,
          fontVariations: AppFonts.sourceHanSansScRegularWght400,
        ),
      ),
    );
  }
}

void _ignoreEngineeringDisplayAction() {}

class _EngineeringPasswordEditOverlay extends StatelessWidget {
  const _EngineeringPasswordEditOverlay({
    required this.step,
    required this.value,
    required this.message,
    required this.messageIsError,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final _PasswordEntryStep step;
  final String value;
  final String? message;
  final bool messageIsError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        key: const ValueKey<String>('engineering-password-edit-overlay'),
        color: const Color(0xCC000000),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              width: 1360,
              height: 900,
              decoration: BoxDecoration(
                color: const Color(0xFF202020),
                border: Border.all(color: const Color(0xFF9A9A9A)),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 38,
                    child: Text(
                      step == _PasswordEntryStep.first
                          ? l10n.engineeringNewPasswordPrompt
                          : l10n.engineeringReenterPasswordPrompt,
                      textAlign: TextAlign.center,
                      style: _engineeringPasswordEditorTitle,
                    ),
                  ),
                  Positioned(
                    right: 42,
                    top: 32,
                    child: _TableActionButton(
                      keyName: 'engineering-password-edit-cancel',
                      label: l10n.cancel,
                      onTap: onCancel,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 108,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (var index = 0; index < 6; index++) ...<Widget>[
                          Container(
                            key: ValueKey<String>(
                                'engineering-password-edit-cell-$index'),
                            width: 76,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7E7E7),
                              border: Border.all(
                                color: index == value.length
                                    ? const Color(0xFF40CBE8)
                                    : const Color(0xFF8A8A8A),
                                width: index == value.length ? 3 : 1,
                              ),
                            ),
                            child: Text(
                              index < value.length ? '*' : '',
                              style: _engineeringPasswordEditorCell,
                            ),
                          ),
                          if (index != 5) const SizedBox(width: 18),
                        ],
                      ],
                    ),
                  ),
                  if (message != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 208,
                      child: Text(
                        message!,
                        key: const ValueKey<String>(
                            'engineering-password-edit-message'),
                        textAlign: TextAlign.center,
                        style: _tableText.copyWith(
                          fontSize: 24,
                          color: messageIsError
                              ? const Color(0xFFFF5A5A)
                              : const Color(0xFF62D6EE),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 137,
                    top: 278,
                    child: TouchPasswordKeyboard(
                      key: ValueKey<_PasswordEntryStep>(step),
                      initialValue: value,
                      initialLayout: TouchKeyboardLayout.symbols,
                      maxLength: 6,
                      onChanged: onChanged,
                      onConfirm: onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction(
      {this.keyName,
      required this.left,
      required this.top,
      required this.label,
      required this.onTap});
  final String? keyName;
  final double left;
  final double top;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          key: keyName == null ? null : ValueKey<String>(keyName!),
          onTap: onTap,
          child: Container(
            width: 180,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD5D5D5))),
            child: Text(label, style: _tableText),
          ),
        ),
      );
}

class _EngineeringButton extends StatelessWidget {
  const _EngineeringButton(
      {required this.left,
      required this.top,
      required this.width,
      required this.label,
      required this.onTap});
  final double left;
  final double top;
  final double width;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: 66,
            alignment: Alignment.center,
            color: const Color(0xFF4D4D4D),
            child: Text(label, style: _buttonText),
          ),
        ),
      );
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.height, required this.cells});
  final double height;
  final List<Widget> cells;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFD0D0D0), width: 0),
            ),
          ),
          child: Row(children: cells),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell(
      {this.text,
      required this.width,
      this.header = false,
      this.muted = false,
      this.child});
  final String? text;
  final double width;
  final bool header;
  final bool muted;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFFD0D0D0), width: 0),
          ),
        ),
        child: child ??
            Text(
              text ?? '',
              style: header
                  ? _tableHeader
                  : muted
                      ? _tableMutedText
                      : _tableText,
            ),
      );
}

class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell(
      {required this.keyName,
      required this.value,
      required this.width,
      required this.enabled,
      required this.onTap});
  final String keyName;
  final String value;
  final double width;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Cell(
        width: width,
        child: enabled
            ? GestureDetector(
                key: ValueKey<String>(keyName),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: _tableText,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFFD5D5D5),
                        size: 32,
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
}

class _EngineeringChoiceOverlay extends StatelessWidget {
  const _EngineeringChoiceOverlay({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: Container(
            key: const ValueKey<String>('engineering-choice-overlay'),
            width: 1480,
            height: 900,
            color: const Color(0xFF4A4A4A),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 62,
                  left: 0,
                  right: 0,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: _choiceTitle,
                  ),
                ),
                Positioned(
                  left: 190,
                  top: 168,
                  right: 190,
                  child: Wrap(
                    spacing: 38,
                    runSpacing: 32,
                    alignment: WrapAlignment.center,
                    children: values
                        .map(
                          (value) => _ChoiceOption(
                            value: value,
                            selected: value == selectedValue,
                            onTap: () => onSelected(value),
                          ),
                        )
                        .toList(),
                  ),
                ),
                _OutlineAction(
                  keyName: 'engineering-choice-cancel',
                  left: 1040,
                  top: 790,
                  label: l10n.cancel,
                  onTap: onCancel,
                ),
                _OutlineAction(
                  keyName: 'engineering-choice-confirm',
                  left: 1250,
                  top: 790,
                  label: l10n.engineeringSaveAndReturn,
                  onTap: onConfirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      key: ValueKey<String>('engineering-choice-option-$value'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 190,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF42C9E9) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0xFF42C9E9) : const Color(0xFFD5D5D5),
          ),
        ),
        child: Text(_areaLabel(value, l10n), style: _choiceOptionText),
      ),
    );
  }
}

class _NameTab extends StatelessWidget {
  const _NameTab(
      {required this.keyName,
      required this.label,
      required this.selected,
      required this.onTap});
  final String keyName;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: ValueKey<String>(keyName),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 180,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5A5A5A) : Colors.transparent,
            border: Border.all(
              color:
                  selected ? const Color(0xFF42C9E9) : const Color(0xFFD5D5D5),
            ),
          ),
          child: Text(label, style: selected ? _nameTabSelected : _nameTab),
        ),
      );
}

class _EngineerDevice {
  const _EngineerDevice(this.key, this.name, this.address,
      {this.floorHeat = ''});
  final String key;
  final String name;
  final String address;
  final String floorHeat;
}

/// 楼层区域名仅用于展示本地化；房间名与设备名保持中文占位。
String _areaLabel(String name, AppLocalizations l10n) {
  switch (name) {
    case '地下一层':
      return l10n.floorBasement1;
    case '地下二层':
      return l10n.floorBasement2;
    case '一层':
      return l10n.floor1;
    case '二层':
      return l10n.floor2;
    case '三层':
      return l10n.floor3;
    default:
      return name;
  }
}

List<_EngineerDevice> _devicesFor(_EngineeringView view) {
  switch (view) {
    case _EngineeringView.freshAir:
      return const <_EngineerDevice>[
        _EngineerDevice('fresh-0', '4CP #0', '00'),
        _EngineerDevice('fresh-1', '全热新风机 #0', '0-1'),
        _EngineerDevice('fresh-2', '全热新风机 #1', '0-2'),
        _EngineerDevice('fresh-3', '全热调湿新风机 #0', '0-3'),
        _EngineerDevice('fresh-4', '新风除湿机 #0', '0-4'),
      ];
    case _EngineeringView.airConditioner:
      return const <_EngineerDevice>[
        _EngineerDevice('ac-0', '主机 #00', '00'),
        _EngineerDevice('ac-1', '主机 #01', '01'),
        _EngineerDevice('ac-2', '室内机 #00', '02', floorHeat: '◉'),
        _EngineerDevice('ac-3', '室内机 #01', '03'),
        _EngineerDevice('ac-4', '室内机 #02', '04'),
        _EngineerDevice('ac-5', '室内机 #03', '05'),
        _EngineerDevice('ac-6', '室内机 #04', '06', floorHeat: '◉'),
        _EngineerDevice('ac-7', '室内机 #05', '07'),
        _EngineerDevice('ac-8', '室内机 #06', '08', floorHeat: '◉'),
        _EngineerDevice('ac-9', '室内机 #07', '09'),
        _EngineerDevice('ac-10', '室内机 #08', '10'),
      ];
    case _EngineeringView.floorHeat:
      return const <_EngineerDevice>[
        _EngineerDevice('floor-0', '燃气壁挂炉 #00', '00'),
        _EngineerDevice('floor-1', 'Valve #00', '01'),
        _EngineerDevice('floor-2', 'Valve #01', '02'),
        _EngineerDevice('floor-3', 'Valve #02', '03'),
        _EngineerDevice('floor-4', 'Valve #03', '04'),
        _EngineerDevice('floor-5', 'Valve #04', '05'),
      ];
    default:
      return const <_EngineerDevice>[
        _EngineerDevice('system-0', '8寸控制屏', '00'),
      ];
  }
}

const TextStyle _engineeringTitle = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScBoldWght700,
    fontSize: 72,
    height: 1.2);
const TextStyle _engineeringPasswordEditorTitle = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 34,
    height: 1.2);
const TextStyle _engineeringPasswordEditorCell = TextStyle(
    color: Color(0xFF252525),
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScRegularWght400,
    fontSize: 48,
    height: 1);
const TextStyle _homeActionText = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 42);
const TextStyle _buttonText = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 34);
const TextStyle _tableHeader = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 34);
const TextStyle _tableText = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScRegularWght400,
    fontSize: 30);
const TextStyle _tableMutedText = TextStyle(
    color: Color(0xFF9C9C9C),
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScRegularWght400,
    fontSize: 28);
const TextStyle _choiceTitle = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 42);
const TextStyle _choiceOptionText = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 30);
const TextStyle _nameTab = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScRegularWght400,
    fontSize: 30);
const TextStyle _nameTabSelected = TextStyle(
    color: Colors.white,
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScBoldWght700,
    fontSize: 30);
const TextStyle _confirmationText = TextStyle(
    color: Color(0xFF42C9E9),
    fontFamily: AppFonts.sourceHanSansSc,
    fontVariations: AppFonts.sourceHanSansScMediumWght500,
    fontSize: 26);
