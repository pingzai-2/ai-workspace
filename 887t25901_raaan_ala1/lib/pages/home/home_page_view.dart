part of 'home_page.dart';

extension _HomePageViewController on _HomePageState {
  Widget _buildHomePageRoot(BuildContext context) {
    final data = _data;
    final persistentData = _persistentData;
    if (data == null || persistentData == null || !_homeInitialSurfaceReady) {
      return const ColoredBox(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RawKeyboardListener(
          focusNode: _shortcutFocusNode,
          autofocus: true,
          onKey: _handleShortcut,
          child: Scaffold(
            backgroundColor: Colors.black,
            // 屏保和业务页面严格互斥。切换时旧分支从组件树移除并执行
            // dispose()，不通过 Overlay、Offstage 或 Visibility 后台保活。
            body: _idlePageVisible
                ? _buildIdlePage(data)
                : _buildActivePage(data, persistentData),
          ),
        ),
        Positioned(
          top: 24,
          child: ValueListenableBuilder<DashboardData?>(
            valueListenable: _backendStatusOverlayData,
            builder: (context, overlayData, _) => BackendStatusOverlay(
              data: overlayData ?? data,
              enabled: widget.showBackendStatusOverlay,
            ),
          ),
        ),
        if (_screenBlackOverlayVisible)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('screen-black-overlay'),
              behavior: HitTestBehavior.opaque,
              onTap: _handleIdleInteraction,
              child: const ColoredBox(color: Color(0xFF000000)),
            ),
          ),
      ],
    );
  }

  Widget _buildIdlePage(DashboardData fallback) {
    return ValueListenableBuilder<DashboardData?>(
      key: const ValueKey<String>('idle-surface'),
      valueListenable: _idlePageData,
      builder: (context, idleData, _) {
        final snapshot = idleData ?? fallback;
        return GestureDetector(
          key: const ValueKey<String>('idle-page'),
          behavior: HitTestBehavior.opaque,
          onTap: _handleIdleInteraction,
          child: IdlePage(
            key: const ValueKey<String>('idle-page-content'),
            data: snapshot,
            timeSource: widget.timeSource,
            use24HourFormat: snapshot.timeFormat == '24h',
            animateWeather: widget.animateWeather,
          ),
        );
      },
    );
  }

  /// 顶层页面按需创建。
  ///
  /// 旧实现使用 IndexedStack，会同时创建五个完整页面；页面内部的动效、
  /// PageView 和局部状态即使不可见也可能继续占用资源。这里保留原有页面
  /// 组件和数据通知器，只把挂载边界改成“当前页面一个”。
  Widget _buildActivePage(
    DashboardData data,
    DashboardPersistentData persistentData,
  ) {
    final activePage = _buildPageByIndex(
      pageIndex: _pageIndex,
      data: data,
      persistentData: persistentData,
      manualDeviceIndex: _manualEntryDeviceIndex,
    );

    // 页面切换期间保留旧页面可见，同时在后台挂载目标页面的完整 Widget
    // 树。目标页面使用 TickerMode(false) 和 IgnorePointer：可以完成布局、
    // 图片解析和首帧准备，但不会响应点击，也不会运行重动画。
    // 目标页准备完毕后只切换可见性，再释放旧页面，避免黑屏闪烁。
    final targetPageIndex = _transitionTargetPageIndex;
    if (!_pageTransitionLoading || targetPageIndex == null) {
      return activePage;
    }

    // 手动空调/地暖的首屏资源由导航协程完整等待；准备期间不再
    // 后台挂载目标页，避免目标页的 PageView 抢先预热相邻页。旧页
    // 保持可见，首屏准备完成后一次性切换，随后旧页才会释放。
    if (targetPageIndex == 2) {
      return activePage;
    }

    final preparingPage = _buildPageByIndex(
      pageIndex: targetPageIndex,
      data: data,
      persistentData: persistentData,
      manualDeviceIndex: _transitionTargetManualDeviceIndex,
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        IgnorePointer(child: activePage),
        Offstage(
          offstage: true,
          child: TickerMode(
            enabled: false,
            child: IgnorePointer(child: preparingPage),
          ),
        ),
      ],
    );
  }

  Widget _buildPageByIndex({
    required int pageIndex,
    required DashboardData data,
    required DashboardPersistentData persistentData,
    required int manualDeviceIndex,
  }) {
    switch (pageIndex) {
      case 0:
        return _buildHomePage(data);
      case 1:
        return _pageSnapshotBuilder(
          listenable: _smartPageData,
          fallback: data,
          builder: (pageData) => SmartPage(
            key: const ValueKey<String>('dashboard-page-smart'),
            data: pageData,
            onBack: _returnHome,
            onCommitSettingsChange: _commitSettingsChange,
            entryToken: _pageEntryTokens[1],
          ),
        );
      case 2:
        return _pageSnapshotBuilder(
          listenable: _manualPageData,
          fallback: data,
          builder: (pageData) => ManualPage(
            key: ValueKey<String>(
              'dashboard-page-manual-$manualDeviceIndex',
            ),
            data: pageData,
            onBack: _returnHome,
            onCommitSettingsChange: _commitSettingsChange,
            onSetFreshAirPower: _setFreshAirPower,
            onSetHumidifierPower: _setHumidifierPower,
            onSetPurePower: _setPurePower,
            onSetFreshAirMode: _setFreshAirMode,
            onSetFreshAirFanLevel: _setFreshAirFanLevel,
            onSetTargetHumidity: _setTargetHumidity,
            entryToken: _pageEntryTokens[2],
            initialDeviceIndex: manualDeviceIndex,
          ),
        );
      case 3:
        return _pageSnapshotBuilder(
          listenable: _historyPageData,
          fallback: data,
          builder: (pageData) => HistoryPage(
            key: const ValueKey<String>('dashboard-page-history'),
            data: pageData,
            onBack: _returnHome,
            entryToken: _pageEntryTokens[3],
          ),
        );
      case 4:
        return _pageSnapshotBuilder(
          listenable: _settingsPageData,
          fallback: data,
          builder: (pageData) => SystemSettingsPage(
            key: const ValueKey<String>('dashboard-page-settings'),
            data: pageData,
            engineeringPassword: _engineeringPassword,
            onEngineeringPasswordChanged: _setEngineeringPassword,
            persistentData: persistentData,
            onSavePersistentConfiguration: _savePersistentConfiguration,
            onBack: _returnHome,
            wifiManager: _wifiManager,
            onSaveSettings: (next) async {
              final previous = _data ?? pageData;
              final localDeviceSettingChanged = previous
                          .screenBrightnessPercent !=
                      next.screenBrightnessPercent ||
                  previous.presenceRadarEnabled != next.presenceRadarEnabled;
              final aqiIndicatorSettingChanged =
                  previous.aqiIndicatorEnabled != next.aqiIndicatorEnabled;
              final committed = await _commitSettingsChange(
                'system-settings',
                (_) => next,
                submitControl: () =>
                    _storage.applyLocalDeviceSettings(previous, next),
              );
              if (committed &&
                  (localDeviceSettingChanged || aqiIndicatorSettingChanged) &&
                  previous.backendDataStatus != 'unreachable') {
                _scheduleWriteReadbackRefresh();
              }
              return committed;
            },
            onEngineeringModeChanged: _setEngineeringModeActive,
            onWifiConnectionLockChanged: _setWifiConnectionLocked,
            entryToken: _pageEntryTokens[4],
          ),
        );
      default:
        return _buildHomePage(data);
    }
  }

  Widget _buildHomePage(DashboardData data) {
    return _pageSnapshotBuilder(
      listenable: _homePageData,
      fallback: data,
      builder: (pageData) => _HomeDashboard(
        data: pageData,
        timeSource: widget.timeSource,
        animateWeather: widget.animateWeather,
        onNavigate: _navigateTo,
        onManualDeviceTap: _openManualDevice,
        onNotificationBellTap: _showNotificationCenter,
        onFaultTap: _showFaultCenter,
        alertTapEnabled: !_runtimeAlertDialogVisible,
        onFloorSelectionChanged: _setHomeFloorSelection,
        onPowerChanged: _setPower,
        onAirConditionerPowerChanged: _setAirConditionerPower,
        onFloorHeatPowerChanged: _setFloorHeatPower,
        onFreshAirPowerChanged: _setFreshAirPower,
        onHumidifierPowerChanged: _setHumidifierPower,
        onPurePowerChanged: _setPurePower,
        onLeaveHome: _onLeaveHome,
        allDevicesPowerBusy: _pendingControls.contains('all-devices'),
        airConditionerPowerBusy: _pendingControls.contains('air-conditioner'),
        floorHeatPowerBusy: _pendingControls.contains('floor-heat'),
        freshAirPowerBusy: _pendingControls.contains('fresh-air'),
        humidifierPowerBusy: _pendingControls.contains('humidifier'),
        purePowerBusy: _pendingControls.contains('pure'),
        leaveHomeBusy: _pendingControls.contains('leave-home'),
      ),
    );
  }

  Widget _pageSnapshotBuilder({
    required ValueListenable<DashboardData?> listenable,
    required DashboardData fallback,
    required Widget Function(DashboardData data) builder,
  }) {
    return ValueListenableBuilder<DashboardData?>(
      valueListenable: listenable,
      builder: (context, pageData, _) {
        final snapshot = pageData ?? fallback;
        return DashboardStatusBarFrame(
          data: snapshot,
          timeSource: widget.timeSource,
          child: builder(snapshot),
        );
      },
    );
  }
}
