import 'package:flutter/widgets.dart';

/// 将持久化的语言码映射为根 locale。
///
/// 存储层使用带地区的完整语言码（zh_CN / ja_JP / en_US），
/// 而 gen-l10n 与 Flutter 原生本地化按基础语言码注册，
/// 因此这里返回带地区的 Locale，解析时会回退到基础语言码。
Locale localeFromLanguageCode(String code) {
  switch (code) {
    case 'ja_JP':
      return const Locale('ja', 'JP');
    case 'en_US':
      return const Locale('en', 'US');
    default:
      return const Locale('zh', 'CN');
  }
}

/// 全局语言控制器：整 App 的根 locale 由它驱动。
///
/// 系统设置页保存语言后由 HomePage 同步此值，根 `MaterialApp`
/// 通过 [ListenableBuilder] 监听它重建，从而让所有页面一起切换。
typedef LocaleController = ValueNotifier<Locale>;
