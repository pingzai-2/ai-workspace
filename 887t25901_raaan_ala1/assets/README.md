# 资源目录

资源按功能和格式分桶，路径已经被 `pubspec.yaml` 和页面代码使用，后续不要为了统一
命名批量改名：

```text
assets/
├── home/
│   ├── top/           # 状态栏、顶部信息
│   ├── alerts/        # 故障/通知图标
│   ├── weather/       # 天气动态/静态资源
│   ├── pm25_orb/      # PM2.5 圆盘动态/静态资源
│   └── figma_home/    # 主页冻结设计素材
├── history/            # 历史趋势图标与图例
├── manual/             # 手动模式卡片、滚轮和控制素材
├── smart/              # 智能模式素材
├── settings/           # 系统设置素材
├── idle/               # 息屏时钟与天气素材
├── navigation/         # 页面返回与公共导航素材
└── fonts/              # HarmonyOS Sans、Source Han Sans SC（JP 字体仅作工程备份）
```

`home/figma_home/` 只保留当前主页实际使用的 `home_*` 设备图、
`*_active/inactive` 导航图和快捷操作图；旧无前缀设备图与旧导航别名不再打包。

天气和 PM2.5 目前按格式继续保留 `dynamic_gif/`、`static_png/`、`dynamic_svg/`、
`static_svg/`。复杂动态 SVG 在 Flutter/LVGL 目标环境优先使用高分辨率 GIF 或 PNG；
静态 SVG 只在目标渲染链验证通过时使用。

字体目录中的官方文件名和许可证文件保持不变。Source Han Sans VF 必须在代码中显式
指定 `FontVariation('wght', ...)`；中、日、英翻译文字统一使用 Source Han Sans SC，
HarmonyOS Sans 仅用于数字、符号和大号读数。`Source_Han_Sans_JP/` 保留在工程中，
但不在 `pubspec.yaml` 资源列表和字体注册中，不会编译进 App。
