part of 'home_page.dart';

const Duration _idleDialogExitDuration = Duration(milliseconds: 250);

extension _HomePageIdleController on _HomePageState {
  /// Navigator 弹窗和主页都能收到的全局活动入口。
  void _recordGlobalPointerActivity(PointerEvent event) {
    if (_lifecycleDisposing || !mounted) {
      return;
    }
    if (event is PointerDownEvent) {
      // 息屏或黑屏保护层上的同一组触摸会先经过全局 PointerDown，
      // 再经过页面 onTap。记录指针编号，消费后续 Move/Up，避免一次触摸
      // 在唤醒或清除黑屏后又返回工作页。
      _screenWakePointer = null;
      final consumesSleepTouch =
          _idlePageVisible &&
          (_screenSleeping || _screenBlackOverlayVisible) &&
          !_screenSleepCommandInFlight;
      _recordUserActivity();
      if (consumesSleepTouch) {
        _screenWakePointer = event.pointer;
      }
      return;
    }
    if (_screenWakePointer == event.pointer) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        // onTap 通常紧跟 PointerUp 回调；留下当前标记直到该回调消费，
        // 若手势被取消则在本轮微任务结束后清理，避免影响下一次触摸。
        scheduleMicrotask(() {
          if (_screenWakePointer == event.pointer) {
            _screenWakePointer = null;
          }
        });
      }
      return;
    }
    if (event is PointerMoveEvent) {
      _recordUserActivity();
    }
  }

  /// Idle 页接管触摸：普通 Idle 返回原页面，硬件息屏先唤醒并清黑屏。
  void _recordUserActivity() {
    if (_lifecycleDisposing || !mounted) {
      return;
    }
    if (_idlePageVisible) {
      _handleIdleInteraction();
      return;
    }
    if (_engineeringModeActive || _wifiConnectionLocked) return;
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    if (_idleTransitionInFlight) {
      _idleTransitionSerial++;
      _idleTransitionInFlight = false;
    }
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_lifecycleDisposing ||
        !mounted ||
        _engineeringModeActive ||
        _wifiConnectionLocked) {
      return;
    }
    _idleTimer = Timer(_effectiveIdleTimeout, _enterIdle);
  }

  /// 正常运行使用 settings 中的息屏时间；测试或宿主显式传入非默认值时，
  /// 仍以构造参数为准，保留快速测试和外部定制入口。
  Duration get _effectiveIdleTimeout {
    if (widget.idleTimeout != const Duration(seconds: 30)) {
      return widget.idleTimeout;
    }
    return Duration(seconds: _data?.screenOffSeconds ?? 30);
  }

  Future<void> _enterIdle() async {
    if (_lifecycleDisposing ||
        !mounted ||
        _idlePageVisible ||
        _idleTransitionInFlight ||
        _engineeringModeActive ||
        _wifiConnectionLocked) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = null;

    // 屏保是独立页面，不是覆盖业务页的 Overlay。进入前废止尚未完成的
    // 页面预加载，并关闭临时弹窗；随后用一次互斥重建卸载当前业务页，
    // 让页面自己的 dispose() 释放动画、GIF、控制器和局部监听。
    _idleTransitionInFlight = true;
    final transitionSerial = ++_idleTransitionSerial;
    _navigationRequestSerial++;
    _pageTransitionLoading = false;
    _transitionTargetPageIndex = null;
    final navigator = Navigator.of(context, rootNavigator: true);
    final hasTemporaryRoute = navigator.canPop();
    if (hasTemporaryRoute) {
      navigator.popUntil((route) => route.isFirst);
      // Material 弹窗退场期间仍属于 Navigator Overlay。等待其彻底销毁
      // 后再创建屏保，避免屏保与旧弹窗短暂重叠、共同持有页面资源。
      await Future<void>.delayed(_idleDialogExitDuration);
    }
    if (_lifecycleDisposing ||
        !mounted ||
        transitionSerial != _idleTransitionSerial) {
      return;
    }
    setState(() {
      _idleTransitionInFlight = false;
      _idlePageVisible = true;
    });
    _startIdleScreenSleepTimer();
  }

  void _handleIdleInteraction() {
    if (_screenWakePointer != null) {
      _screenWakePointer = null;
      return;
    }
    if (_screenSleepCommandInFlight) {
      return;
    }
    if (_screenSleeping) {
      unawaited(_wakeScreenAndReturnToIdle());
      return;
    }
    if (_screenBlackOverlayVisible) {
      // 黑屏是残影保护层；如果触摸落在保护层上，直接清层并保持 Idle。
      setState(() => _screenBlackOverlayVisible = false);
      _startIdleScreenSleepTimer();
      return;
    }
    _resumeFromIdle();
  }

  void _resumeFromIdle() {
    if (_lifecycleDisposing || !mounted || !_idlePageVisible) {
      return;
    }
    _idleScreenSleepTimer?.cancel();
    _idleScreenSleepTimer = null;
    _screenSleepRequestSerial++;
    _screenSleepCommandInFlight = false;
    _screenSleeping = false;
    _screenBlackOverlayVisible = false;
    // 同一次重建先卸载 IdlePage（停止时钟和天气 GIF），再重新创建
    // 进入屏保前所在的业务页；两类页面不会同时挂载。
    setState(() => _idlePageVisible = false);
    _restartIdleTimer();
  }

  void _startIdleScreenSleepTimer() {
    _idleScreenSleepTimer?.cancel();
    _idleScreenSleepTimer = Timer(
      _HomePageState._idleScreenSleepDelay,
      () => unawaited(_enterScreenSleep()),
    );
  }

  Future<void> _enterScreenSleep() async {
    if (_lifecycleDisposing ||
        !mounted ||
        !_idlePageVisible ||
        _screenSleeping ||
        _screenSleepCommandInFlight) {
      return;
    }
    _idleScreenSleepTimer = null;
    _screenSleepCommandInFlight = true;
    final requestSerial = ++_screenSleepRequestSerial;
    setState(() => _screenBlackOverlayVisible = true);
    // 先让纯黑画面完成一帧，再通知本机息屏，避免屏幕停在 Idle 画面残影上。
    await WidgetsBinding.instance.endOfFrame;
    if (_lifecycleDisposing ||
        !mounted ||
        requestSerial != _screenSleepRequestSerial ||
        !_idlePageVisible) {
      return;
    }
    // 息屏命令只负责发出，不读取结果；这样无后端模拟端也能保持完整黑屏流程。
    unawaited(_ignoreScreenSleepResult(true));
    _screenSleepCommandInFlight = false;
    setState(() => _screenSleeping = true);
  }

  Future<void> _wakeScreenAndReturnToIdle() async {
    if (_lifecycleDisposing ||
        !mounted ||
        !_idlePageVisible ||
        !_screenSleeping ||
        _screenSleepCommandInFlight) {
      return;
    }
    _screenSleepCommandInFlight = true;
    final requestSerial = ++_screenSleepRequestSerial;
    setState(() => _screenBlackOverlayVisible = true);
    // 唤醒命令只负责发出，不以返回值决定界面状态。
    unawaited(_ignoreScreenSleepResult(false));
    if (_lifecycleDisposing ||
        !mounted ||
        requestSerial != _screenSleepRequestSerial ||
        !_idlePageVisible) {
      return;
    }
    // 保持黑屏完成一帧，清掉唤醒瞬间可能残留的上一画面，再显示 Idle。
    await WidgetsBinding.instance.endOfFrame;
    if (_lifecycleDisposing ||
        !mounted ||
        requestSerial != _screenSleepRequestSerial) {
      return;
    }
    setState(() {
      _screenSleeping = false;
      _screenBlackOverlayVisible = false;
      _screenSleepCommandInFlight = false;
    });
    _startIdleScreenSleepTimer();
  }

  Future<void> _ignoreScreenSleepResult(bool sleep) async {
    try {
      await _storage.setScreenSleep(sleep);
    } on Object {
      // 息屏/唤醒不以 HTTP 或后端结果决定模拟端界面流程。
    }
  }
}
