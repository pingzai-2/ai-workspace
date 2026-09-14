part of 'home_page.dart';

extension _HomePageNavigationController on _HomePageState {
  void _handleShortcut(RawKeyEvent event) {
    if (_lifecycleDisposing ||
        !mounted ||
        _wifiConnectionLocked ||
        event is! RawKeyDownEvent) {
      return;
    }
    if (_idlePageVisible) {
      _handleIdleInteraction();
      return;
    }
    _recordUserActivity();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _returnHome();
      return;
    }
    final index = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.digit5: 4,
    }[key];
    if (index != null) {
      _navigateTo(index);
    }
  }

  void _navigateTo(int index) {
    if (_lifecycleDisposing || !mounted || _wifiConnectionLocked) {
      return;
    }
    final serial = ++_navigationRequestSerial;
    final manualDeviceIndex = index == 2 ? 0 : _manualEntryDeviceIndex;
    _showPageTransition(
      targetPageIndex: index,
      manualDeviceIndex: manualDeviceIndex,
    );
    unawaited(
      _preparePageAndNavigate(
        serial: serial,
        targetPageIndex: index,
        manualDeviceIndex: manualDeviceIndex,
      ),
    );
  }

  Future<void> _preparePageAndNavigate({
    required int serial,
    required int targetPageIndex,
    required int manualDeviceIndex,
  }) async {
    // 页面数据和首屏素材都是“进入页面”的前置条件。这样按钮当前应为
    // 开启时，页面首帧直接显示开启，不会先挂载默认关闭再被轮询改正。
    if (!await _waitForPageDataSnapshot(targetPageIndex)) {
      return;
    }
    // 手动页还额外遵守“第一页稳定 -> 释放旧页 -> 预加载相邻页”；
    // 其它页面也等待自己的首屏资源，避免只把空壳页面先挂上去。
    await _precachePageAssets(
      targetPageIndex,
      manualDeviceIndex: manualDeviceIndex,
    );
    if (_lifecycleDisposing || !mounted || serial != _navigationRequestSerial) {
      return;
    }
    setState(() {
      _pageTransitionLoading = false;
      _pageIndex = targetPageIndex;
      _manualEntryDeviceIndex = manualDeviceIndex;
      _transitionTargetPageIndex = null;
      if (targetPageIndex != 0) {
        _pageEntryTokens[targetPageIndex]++;
      }
    });
    _trimImageCacheAfterPageChange(targetPageIndex);
  }

  Future<bool> _waitForPageDataSnapshot(int pageIndex) async {
    late final ValueNotifier<DashboardData?> notifier;
    switch (pageIndex) {
      case 0:
        notifier = _homePageData;
        break;
      case 1:
        notifier = _smartPageData;
        break;
      case 2:
        notifier = _manualPageData;
        break;
      case 3:
        notifier = _historyPageData;
        break;
      case 4:
        notifier = _settingsPageData;
        break;
      default:
        notifier = _homePageData;
        break;
    }
    for (var attempt = 0; attempt < 40; attempt++) {
      if (_lifecycleDisposing || !mounted) {
        return false;
      }
      if (notifier.value != null) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    // 数据未准备好时宁可停留在旧页面，也不能用默认数据抢先进入目标页。
    AppLogger.instance.w(
      '页面 $pageIndex 数据快照未就绪，取消本次导航',
      tag: 'HomeNavigation',
    );
    return false;
  }

  Future<void> _precacheManualCardBackgrounds(int manualDeviceIndex) async {
    final assets = <String>{};
    // 状态栏也是首屏的一部分，必须和卡片按钮一起完成解码，避免目标页
    // 已经挂载后时钟/Wi‑Fi 才补出，形成“先默认、后正确”的半成品首帧。
    assets.addAll(<String>[
      'assets/home/top/clock.png',
      'assets/home/top/wifi_correct.png',
      'assets/home/top/wifi_error.png',
    ]);
    if (manualDeviceIndex == 0) {
      // 首屏的 4 张卡片可能在本次交互中切换开关，亮/灭两套
      // 背景都先解码，避免点击后才出现底图。
      assets.addAll(<String>[
        'assets/manual/ac-cardbg.png',
        'assets/manual/ac-cardbg-off.png',
      ]);
    } else if (manualDeviceIndex == 1) {
      assets.addAll(<String>[
        'assets/manual/fh-cardbg.png',
        'assets/manual/fh-cardbg-off.png',
      ]);
    }
    assets.addAll(<String>[
      'assets/manual/frame-bg.png',
      'assets/manual/card-空调.png',
      'assets/manual/card-风量.png',
      'assets/manual/check-box-on.png',
      'assets/manual/check-box-off.png',
      'assets/manual/vertical_stepper_on.png',
      'assets/manual/vertical_stepper_off.png',
      'assets/manual/vertical_stepper_press_up.png',
      'assets/manual/vertical_stepper_press_down.png',
      'assets/settings/toggle-button-on.png',
      'assets/settings/toggle-button-off.png',
      'assets/navigation/manual_back.png',
      'assets/navigation/common_back_line.png',
      'assets/navigation/manual_air_conditioner_active.png',
      'assets/navigation/manual_air_conditioner_inactive.png',
      'assets/navigation/manual_floor_heat_active.png',
      'assets/navigation/manual_floor_heat_inactive.png',
      'assets/navigation/manual_fresh_air_active.png',
      'assets/navigation/manual_fresh_air_inactive.png',
      'assets/navigation/manual_humidity_active.png',
      'assets/navigation/manual_humidity_inactive.png',
      'assets/navigation/manual_clean_active.png',
      'assets/navigation/manual_clean_inactive.png',
    ]);
    await _precacheAssetBatchAndWait(assets, '手动页首屏');
  }

  Future<void> _precacheHomeAssets({bool waitForAssets = true}) async {
    final data = _data;
    if (data == null) {
      return;
    }
    final preload =
        waitForAssets ? _precacheAssetBatchAndWait : _precacheAssetBatch;
    await preload(<String>[
      'assets/home/top/clock.png',
      'assets/home/top/wifi_correct.png',
      'assets/home/top/wifi_error.png',
      'assets/home/top/notice_triangle.png',
      'assets/home/top/notification_badge.png',
      'assets/home/figma_home/notice.png',
      'assets/home/figma_home/home_active.png',
      'assets/home/figma_home/home_inactive.png',
      'assets/home/figma_home/smart_active.png',
      'assets/home/figma_home/smart_inactive.png',
      'assets/home/figma_home/manual_active.png',
      'assets/home/figma_home/manual_inactive.png',
      'assets/home/figma_home/history_active.png',
      'assets/home/figma_home/history_inactive.png',
      'assets/home/figma_home/settings_active.png',
      'assets/home/figma_home/settings_inactive.png',
    ], '主页公共素材');
    await _precacheInitialHomeSurface(data, waitForAssets: waitForAssets);
    final weather = WeatherPresentation.fromCode(data.weatherCode);
    if (data.effectiveWifiConnected) {
      await preload(<String>[weather.gifAssetPath], '主页天气');
    }
    if (widget.animateWeather) {
      await preload(<String>[
        'assets/home/pm25_orb/dynamic_gif/pm25_orb_1x.gif',
      ], '主页 PM2.5');
    }
  }

  Future<void> _precachePageAssets(
    int pageIndex, {
    required int manualDeviceIndex,
  }) async {
    if (pageIndex == 0) {
      await _precacheHomeAssets(waitForAssets: true);
      return;
    }
    if (pageIndex == 2) {
      await _precacheManualCardBackgrounds(manualDeviceIndex);
      return;
    }

    // 其它内页也会复用顶部时钟和 Wi‑Fi 状态栏。它们属于每个页面的
    // 首屏公共层，必须和页面自己的背景/导航素材一起完成预加载，不能
    // 进入后再补出状态栏图标而产生一帧“默认/缺图”的页面。
    await _precacheAssetBatchAndWait(
      const <String>[
        'assets/home/top/clock.png',
        'assets/home/top/wifi_correct.png',
        'assets/home/top/wifi_error.png',
      ],
      '页面公共状态栏',
    );

    final pageBatches = <int, List<List<String>>>{
      1: <List<String>>[
        <String>['assets/smart/frame-bg2.png'],
        <String>[
          'assets/navigation/smart_back.png',
          'assets/navigation/wide_back_line.png',
          'assets/navigation/smart_standard_active.png',
          'assets/navigation/smart_standard_inactive.png',
          'assets/navigation/smart_guest_active.png',
          'assets/navigation/smart_guest_inactive.png',
          'assets/navigation/smart_dry_active.png',
          'assets/navigation/smart_dry_inactive.png',
          'assets/navigation/smart_warm_active.png',
          'assets/navigation/smart_warm_inactive.png',
          'assets/navigation/smart_travel_active.png',
          'assets/navigation/smart_travel_inactive.png',
        ],
        <String>[
          'assets/smart/standard_stepper_on.png',
          'assets/smart/standard_stepper_off.png',
          'assets/smart/standard_stepper_press_left.png',
          'assets/smart/standard_stepper_press_right.png',
          'assets/smart/standard_toggle_on.png',
          'assets/smart/standard_toggle_off.png',
        ],
      ],
      3: <List<String>>[
        <String>['assets/history/frame-bg.png'],
        <String>[
          'assets/navigation/history_back.png',
          'assets/navigation/history_back_line.png',
        ],
        <String>[
          'assets/history/temperature_active.png',
          'assets/history/temperature_inactive.png',
          'assets/history/humidity_active.png',
          'assets/history/humidity_inactive.png',
          'assets/history/pm25_active.png',
          'assets/history/pm25_inactive.png',
          'assets/history/co2_active.png',
          'assets/history/co2_inactive.png',
          'assets/history/indoor_line.png',
          'assets/history/outdoor_line.png',
        ],
      ],
      4: <List<String>>[
        <String>['assets/settings/frame-bg2.png'],
        <String>[
          'assets/navigation/common_back.png',
          'assets/navigation/settings_back_line.png',
          'assets/navigation/settings_system_active.png',
          'assets/navigation/settings_system_inactive.png',
          'assets/navigation/settings_maintenance_active.png',
          'assets/navigation/settings_maintenance_inactive.png',
          'assets/navigation/settings_engineering_active.png',
          'assets/navigation/settings_engineering_inactive.png',
        ],
        <String>[
          'assets/settings/next.png',
          'assets/settings/next-press.png',
          'assets/settings/toggle-button-on.png',
          'assets/settings/toggle-button-off.png',
        ],
      ],
    }[pageIndex];
    if (pageBatches == null) {
      return;
    }
    for (var index = 0; index < pageBatches.length; index++) {
      await _precacheAssetBatchAndWait(
        pageBatches[index],
        '页面 $pageIndex 第 ${index + 1} 批素材',
      );
    }
  }

  Future<void> _precacheAssetBatch(
    Iterable<String> assets,
    String label,
  ) async {
    final uniqueAssets = assets.toSet();
    if (uniqueAssets.isEmpty) {
      return;
    }
    // 预加载是后台暖缓存，不属于页面进入的必要条件。不同平台的
    // 图片解码回调返回时机不同，不能让导航、返回或 dispose 等待它。
    unawaited(() async {
      try {
        await Future.wait(
          uniqueAssets.map(
            (asset) => precacheImage(AssetImage(asset), context),
          ),
        );
      } on Object catch (error) {
        // 素材异常只记录；页面本身仍按业务数据完成挂载。
        AppLogger.instance.w(
          '$label预加载失败',
          tag: 'HomeNavigation',
          error: error,
        );
      }
    }());
  }

  Future<void> _precacheAssetBatchAndWait(
    Iterable<String> assets,
    String label,
  ) async {
    final uniqueAssets = assets.toSet();
    if (uniqueAssets.isEmpty) {
      return;
    }
    try {
      await Future.wait(
        uniqueAssets.map(
          (asset) => precacheImage(AssetImage(asset), context),
        ),
      ).timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      // 单个素材异常不能让页面永远停在旧页；记录后继续提交，
      // 正常素材仍保持“首屏资源先完成”的顺序。
      AppLogger.instance.w(
        '$label预加载失败',
        tag: 'HomeNavigation',
        error: error,
      );
    }
  }

  void _openManualDevice(int deviceIndex) {
    final serial = ++_navigationRequestSerial;
    _showPageTransition(
      targetPageIndex: 2,
      manualDeviceIndex: deviceIndex,
    );
    unawaited(
      _preparePageAndNavigate(
        serial: serial,
        targetPageIndex: 2,
        manualDeviceIndex: deviceIndex,
      ),
    );
  }

  void _showPageTransition({
    required int targetPageIndex,
    required int manualDeviceIndex,
  }) {
    if (_lifecycleDisposing || !mounted) {
      return;
    }
    setState(() {
      _pageTransitionLoading = true;
      _transitionTargetPageIndex = targetPageIndex;
      _transitionTargetManualDeviceIndex = manualDeviceIndex;
    });
  }

  void _trimImageCacheAfterPageChange(int pageIndex) {
    // 目标页已经完成预加载并切换显示；此时旧页面才退出树。
    // 不能在这里调用 imageCache.clear()：Flutter 的全量清理会把刚
    // 预加载好的目标页图片一并驱逐，下一帧重新解码就会造成“底图先出、
    // 卡片/一键区后出”的半成品画面。缓存由 Flutter 的容量策略自然回收。
    // 保留方法名和调用点，避免改变页面切换状态机。
    if (pageIndex < 0) {
      return;
    }
  }

  void _returnHome() {
    if (_lifecycleDisposing || !mounted || _wifiConnectionLocked) {
      return;
    }
    if (_engineeringModeActive) {
      // 键盘 Esc 与页面上的“退出”保持同一条特殊模式收尾链路：
      // 先重新准备正常数据，再回到普通首页。
      unawaited(_returnHomeAfterSpecialMode());
      return;
    }
    // 返回请求在页面切换期间可能被重复触发；同一个目标只保留第一次，
    // 避免旧页面/目标页面交替复用而出现一帧错误页面。
    if ((!_pageTransitionLoading && _pageIndex == 0) ||
        (_pageTransitionLoading && _transitionTargetPageIndex == 0)) {
      return;
    }
    // 已确认返回闪页来自“目标页后台挂载”链路；所有内页返回首页
    // 统一先直接切换，页面之间的正向切换仍保留原有预加载策略。
    if (!_pageTransitionLoading && _pageIndex != 0) {
      ++_navigationRequestSerial;
      setState(() {
        _pageIndex = 0;
        _transitionTargetPageIndex = null;
      });
      _restartIdleTimer();
      return;
    }
    final serial = ++_navigationRequestSerial;
    _showPageTransition(
      targetPageIndex: 0,
      manualDeviceIndex: _manualEntryDeviceIndex,
    );
    unawaited(
      _preparePageAndNavigate(
        serial: serial,
        targetPageIndex: 0,
        manualDeviceIndex: _manualEntryDeviceIndex,
      ),
    );
    _restartIdleTimer();
  }

  Future<void> _returnHomeAfterSpecialMode() async {
    await _setEngineeringModeActive(false);
    if (!mounted) {
      return;
    }
    // 特殊模式退出也走统一的“保留旧页 -> 预加载首页 -> 原子切换”链路，
    // 不因重新读取数据而突然出现黑屏或半成品首页。
    _navigateTo(0);
  }

  Future<void> _setEngineeringModeActive(bool active) async {
    if (_lifecycleDisposing || !mounted) {
      return;
    }
    if (active) {
      if (_engineeringModeActive) {
        return;
      }
      setState(() => _engineeringModeActive = true);
      _idleTimer?.cancel();
      return;
    }
    if (!_engineeringModeActive) {
      return;
    }
    // 退出工程/产测等特殊模式后，先重新读取三份独立数据，再展示普通页。
    // 这样特殊模式的内存草稿不会与正常 settings/runtime 链路交叉。
    while (_reloadInFlight) {
      if (_lifecycleDisposing || !mounted) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await _loadInitialData();
    if (!mounted) {
      return;
    }
    setState(() => _engineeringModeActive = false);
    _restartIdleTimer();
  }

  void _setWifiConnectionLocked(bool active) {
    if (_lifecycleDisposing || !mounted || _wifiConnectionLocked == active) {
      return;
    }
    setState(() => _wifiConnectionLocked = active);
    if (active) {
      _idleTimer?.cancel();
      _idleTimer = null;
    } else {
      _restartIdleTimer();
    }
  }

  void _setEngineeringPassword(String password) {
    if (_lifecycleDisposing || !mounted || _engineeringPassword == password) {
      return;
    }
    // 工程模式密码仅属于本次 App 进程，不进入 dashboard 两份 JSON。
    // App 重新启动后由字段初始值恢复为 666666。
    setState(() => _engineeringPassword = password);
  }
}
