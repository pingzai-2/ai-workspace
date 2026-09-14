import 'package:flutter/material.dart';

/// 工程统一使用的 UI 设计分辨率。
const Size kDesignResolution = Size(1920, 1200);

/// 将固定设计分辨率的完整应用等比缩放到当前窗口。
///
/// UI 始终按 [designSize] 排版，窗口尺寸只影响最终的整体缩放比例。
/// 当窗口宽高比与设计分辨率不同时，空余区域使用 [backgroundColor] 填充，
/// 从而避免界面被拉伸变形或被裁切。
class DesignResolutionScaler extends StatelessWidget {
  const DesignResolutionScaler({
    Key? key,
    required this.child,
    this.designSize = kDesignResolution,
    this.backgroundColor = Colors.black,
  }) : super(key: key);

  final Widget child;
  final Size designSize;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: FittedBox(
          key: const ValueKey<String>('design-resolution-fitted-box'),
          fit: BoxFit.contain,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.fromSize(
            size: designSize,
            child: child,
          ),
        ),
      ),
    );
  }
}
