part of 'home_page.dart';

extension _HomePageDataController on _HomePageState {
  Future<void> _loadInitialData() async {
    if (_lifecycleDisposing || !mounted || _reloadInFlight) {
      return;
    }
    _reloadInFlight = true;
    try {
      final loaded = await Future.wait<Object>(<Future<Object>>[
        _storage.loadOrCreate(),
        _storage.loadPersistentOrCreate(),
      ]);
      var value = loaded[0] as DashboardData;
      final persistent = loaded[1] as DashboardPersistentData;
      value = await _wifiManager.applyStartupSwitchState(value);
      if (!_lifecycleDisposing && mounted) {
        // 首帧即按持久化语言码对齐整 App 根 locale。
        widget.localeController.value = localeFromLanguageCode(
          value.languageCode,
        );
        final previous = _data;
        setState(() {
          _data = value;
          _persistentData = persistent;
        });
        _publishPageSnapshots(previous, value, force: true);
        _restartIdleTimer();
        if (!_homeInitialSurfaceReady && !_lifecycleDisposing && mounted) {
          // 首屏数据已经完整，页面可以先挂载；素材预加载只负责暖缓存，
          // 不能成为页面生命周期的阻塞点。否则某个平台的图片解码回调
          // 不返回时，页面会永久停在黑色基础层，导航和息屏都无法接管。
          setState(() => _homeInitialSurfaceReady = true);
          unawaited(_precacheInitialHomeSurface(value));
        }
      }
    } on Object catch (error) {
      AppLogger.instance.e(
        '主页状态读取失败，保留当前已确认状态',
        tag: 'HomeData',
        error: error,
      );
    } finally {
      _reloadInFlight = false;
    }
  }

  Future<void> _precacheInitialHomeSurface(
    DashboardData data, {
    bool waitForAssets = false,
  }) async {
    final assets = <String>{};

    for (final deviceType in data.availableDeviceTypes) {
      final artworkName = <String, String>{
        'air_conditioner': 'air_conditioner',
        'floor_heat': 'floor_heat',
        'fresh_air': 'fresh_air',
        'humidifier': 'humidifier',
        'pure': 'pure',
      }[deviceType];
      if (artworkName == null) {
        continue;
      }
      // 返回首页时开/关状态可能在上一页刚刚改变；两套状态都先解码，
      // 避免卡片或右上角电源图标在首帧之后才补出来。
      assets.add(
        'assets/home/figma_home/home_${artworkName}_on.png',
      );
      assets.add(
        'assets/home/figma_home/home_${artworkName}_off.png',
      );
      assets.add('assets/home/figma_home/power_on.png');
      assets.add('assets/home/figma_home/power_off.png');
    }

    final deviceCount = data.availableDeviceTypes.length;
    final quickAssetVariant = deviceCount >= 5
        ? ''
        : deviceCount == 4
            ? '_4'
            : '_3';
    for (final action in const <String>['power', 'leave']) {
      assets.add(
        'assets/home/figma_home/quick_${action}_background$quickAssetVariant.png',
      );
      assets.add(
        'assets/home/figma_home/quick_${action}_on.png',
      );
    }

    // 手动空调/地暖进入时必须先显示完整第一页。这里只提前暖第一页
    // 的公共资源，不创建 PageView，也不预热相邻页；真正进入手动页后，
    // 仍按“首帧稳定 -> 相邻页”顺序维护资源窗口。
    if (data.availableDeviceTypes.contains('air_conditioner')) {
      assets.addAll(<String>[
        'assets/manual/frame-bg.png',
        'assets/manual/ac-cardbg.png',
        'assets/manual/ac-cardbg-off.png',
        'assets/manual/card-空调.png',
        'assets/manual/card-风量.png',
        'assets/manual/vertical_stepper_on.png',
        'assets/manual/vertical_stepper_off.png',
        'assets/manual/vertical_stepper_press_up.png',
        'assets/manual/vertical_stepper_press_down.png',
      ]);
    }
    if (data.availableDeviceTypes.contains('floor_heat')) {
      assets.addAll(<String>[
        'assets/manual/frame-bg.png',
        'assets/manual/fh-cardbg.png',
        'assets/manual/fh-cardbg-off.png',
        'assets/manual/vertical_stepper_on.png',
        'assets/manual/vertical_stepper_off.png',
        'assets/manual/vertical_stepper_press_up.png',
        'assets/manual/vertical_stepper_press_down.png',
      ]);
    }

    // 首页只是后台暖缓存；真正进入手动页时，导航协程会再次以可等待的
    // 首屏资源清单作为门槛。这里不创建超时计时器，避免页面在测试或
    // 快速退出时留下尚未完成的解码 Future。
    if (waitForAssets) {
      await _precacheAssetBatchAndWait(assets, '首页/手动首屏');
    } else {
      await _precacheAssetBatch(assets, '首页/手动首屏');
    }
  }

  void _scheduleWriteReadbackRefresh() {
    if (_lifecycleDisposing || !mounted) {
      return;
    }
    // 以末次写入为起点重新计时：例如 0ms 写入后原定 350ms 补读，
    // 100ms 再写入则顺延到 450ms。这可以合并连续操作，只读最终稳定结果。
    _writeReadbackRefreshTimer?.cancel();
    _writeReadbackRefreshTimer =
        Timer(_HomePageState._writeReadbackRefreshDelay, () {
      _writeReadbackRefreshTimer = null;
      unawaited(_refreshRuntime(queueIfBusy: true));
    });
  }

  Future<void> _refreshRuntime({bool queueIfBusy = false}) async {
    final current = _data;
    // 维护约束：周期刷新和写后主动刷新都走此入口，页面不得另建设备轮询。
    // 周期读遇到上一轮未结束仍直接跳过；写后确认读不能丢失，只合并为
    // 当前请求结束后的一个补读。成功后只替换 runtime，不覆盖 settings。
    if (_lifecycleDisposing ||
        !mounted ||
        current == null ||
        _engineeringModeActive) {
      return;
    }
    if (_reloadInFlight) {
      if (queueIfBusy) {
        _writeReadbackRefreshPending = true;
      }
      return;
    }
    _reloadInFlight = true;
    try {
      final value = await _storage.refreshRuntime(current);
      final latest = _data;
      if (!_lifecycleDisposing && mounted && latest != null) {
        final merged = _withConfirmedSettings(value, latest);
        final next = await _wifiManager.reconcileRuntime(merged);
        if (_lifecycleDisposing || !mounted) {
          return;
        }
        // 两秒轮询只替换统一业务快照，不再 setState 整个 HomePage。
        // 各页面是否重建由刷新签名决定；无关字段变化不会惊动当前页面。
        _data = next;
        _publishPageSnapshots(latest, next);
      }
    } on Object catch (error) {
      AppLogger.instance.e(
        '主页运行快照读取失败，保留当前已确认状态',
        tag: 'HomeData',
        error: error,
      );
    } finally {
      _reloadInFlight = false;
      if (_writeReadbackRefreshPending &&
          !_lifecycleDisposing &&
          mounted &&
          !_engineeringModeActive) {
        _writeReadbackRefreshPending = false;
        // 离开当前 async finally 后再进入统一刷新入口，避免函数内死等，
        // 也避免和刚释放的 in-flight 状态发生重入。
        scheduleMicrotask(
          () => unawaited(_refreshRuntime(queueIfBusy: true)),
        );
      }
    }
  }
}
