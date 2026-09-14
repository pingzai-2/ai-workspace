import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 应用日志级别。
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 应用文件日志服务。
///
/// 单例使用，支持时间戳、分级、文件落盘和控制台输出。
/// 日志目录规则：
/// 1. 优先使用编译时环境变量 `DASHBOARD_LOG_ROOT`；
/// 2. 否则若设置了 `DASHBOARD_CONFIG_ROOT`，使用其上一级目录；
/// 3. 否则回退到 `getApplicationDocumentsDirectory()`。
/// 最终写入基础目录下的 `logs/app.log`。
///
/// 例如 `DASHBOARD_CONFIG_ROOT=/mnt/UDISK/app/config` 时，日志写入
/// `/mnt/UDISK/app/logs/app.log`，与配置文件分开放置。
class AppLogger {
  AppLogger._();

  static final AppLogger _instance = AppLogger._();

  /// 全局日志实例。
  static AppLogger get instance => _instance;

  /// 当前最低输出级别，低于此级别的日志不会写入文件或控制台。
  LogLevel _minLevel = LogLevel.info;

  /// 日志文件最大大小（字节），超过后重命名为带时间戳的备份并创建新文件。
  /// 默认 2MB。
  int _maxFileSize = 2 * 1024 * 1024;

  /// 是否同时在控制台输出，release 模式下默认关闭。
  bool _consoleOutput = kDebugMode;

  File? _logFile;
  final List<String> _pendingLines = <String>[];
  bool _flushInProgress = false;
  bool _initialized = false;

  /// 初始化日志服务。
  ///
  /// [minLevel]      最低输出级别，默认 info。
  /// [maxFileSize]   单个日志文件大小上限，默认 2MB。
  /// [consoleOutput] 是否同时输出到控制台，release 模式默认 false。
  Future<void> init({
    LogLevel minLevel = LogLevel.info,
    int maxFileSize = 2 * 1024 * 1024,
    bool? consoleOutput,
  }) async {
    if (_initialized) return;
    _minLevel = minLevel;
    _maxFileSize = maxFileSize;
    _consoleOutput = consoleOutput ?? kDebugMode;

    final directory = await _logDirectory();
    _logFile = File('${directory.path}/app.log');
    await _rotateIfNeeded();
    _initialized = true;
  }

  /// 记录 verbose 级别日志。
  void v(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.verbose, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录 debug 级别日志。
  void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录 info 级别日志。
  void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录 warning 级别日志。
  void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录 error 级别日志。
  void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 获取日志文件路径；未初始化时返回 null。
  String? get logFilePath => _logFile?.path;

  static const String _logRoot = String.fromEnvironment(
    'DASHBOARD_LOG_ROOT',
  );
  static const String _configRoot = String.fromEnvironment(
    'DASHBOARD_CONFIG_ROOT',
  );

  Future<Directory> _logDirectory() async {
    final Directory baseDir;
    if (_logRoot.isNotEmpty) {
      baseDir = Directory(_logRoot);
    } else if (_configRoot.isNotEmpty) {
      baseDir = Directory(_configRoot).parent;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    final logsDir = Directory('${baseDir.path}/logs');
    if (!logsDir.existsSync()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final timestamp = _formatTimestamp(DateTime.now());
    final levelLabel = _levelLabel(level);
    final buffer = StringBuffer()
      ..write('[$timestamp]')
      ..write('[$levelLabel]');
    if (tag != null && tag.isNotEmpty) {
      buffer.write('[$tag]');
    }
    buffer.write(' $message');
    if (error != null) {
      buffer.write('\nERROR_OBJECT: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nSTACK_TRACE: $stackTrace');
    }
    final line = buffer.toString();

    if (_consoleOutput) {
      // 控制台输出保留 Flutter 的 debugPrint 行为，release 模式下不输出。
      debugPrint(line);
    }

    _pendingLines.add(line);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushInProgress || _pendingLines.isEmpty) return;
    _flushInProgress = true;
    scheduleMicrotask(() async {
      try {
        await _flush();
      } finally {
        _flushInProgress = false;
        if (_pendingLines.isNotEmpty) {
          _scheduleFlush();
        }
      }
    });
  }

  Future<void> _flush() async {
    if (_logFile == null) return;
    final lines = _pendingLines.toList(growable: false);
    _pendingLines.clear();
    final content = '${lines.join('\n')}\n';
    await _rotateIfNeeded();
    await _logFile!.writeAsString(
      content,
      mode: FileMode.append,
      encoding: utf8,
      flush: true,
    );
  }

  Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null) return;
    if (!file.existsSync()) return;
    final length = await file.length();
    if (length < _maxFileSize) return;

    final directory = file.parent;
    // 日志只保留 app.log 和一个备份；轮转前清掉旧备份即可避免长期堆积。
    for (final entity in directory.listSync()) {
      if (entity is File && _isBackupFile(entity)) {
        try {
          await entity.delete();
        } catch (_) {
          // 删除失败不阻断轮转；下一次轮转会继续清理。
        }
      }
    }
    final timestamp = _formatTimestampForFileName(DateTime.now());
    final backupName = 'app_$timestamp.log';
    await file.rename('${directory.path}/$backupName');
  }

  bool _isBackupFile(File file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith('app_') && name.endsWith('.log');
  }

  String _formatTimestamp(DateTime time) {
    final sb = StringBuffer()
      ..write(_twoDigits(time.year))
      ..write('-')
      ..write(_twoDigits(time.month))
      ..write('-')
      ..write(_twoDigits(time.day))
      ..write(' ')
      ..write(_twoDigits(time.hour))
      ..write(':')
      ..write(_twoDigits(time.minute))
      ..write(':')
      ..write(_twoDigits(time.second))
      ..write('.')
      ..write(_threeDigits(time.millisecond));
    return sb.toString();
  }

  String _formatTimestampForFileName(DateTime time) {
    final sb = StringBuffer()
      ..write(time.year)
      ..write(_twoDigits(time.month))
      ..write(_twoDigits(time.day))
      ..write('_')
      ..write(_twoDigits(time.hour))
      ..write(_twoDigits(time.minute))
      ..write(_twoDigits(time.second));
    return sb.toString();
  }

  String _levelLabel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
  String _threeDigits(int n) {
    if (n >= 100) return '$n';
    if (n >= 10) return '0$n';
    return '00$n';
  }
}
