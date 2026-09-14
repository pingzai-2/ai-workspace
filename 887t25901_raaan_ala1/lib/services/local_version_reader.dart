import 'dart:convert';
import 'dart:io';

const String kAppDefaultVersion = 'v0.00.01';
const String kLocalVersionFilePath = '/etc/version';

const int _versionPayloadMaxBytes = 31;
const int _versionReadMaxBytes = _versionPayloadMaxBytes + 1;

/// 读取板端固定版本文件。接口或解码异常回退；可读的空内容保持为空。
Future<String> readLocalVersion({
  String filePath = kLocalVersionFilePath,
  String fallbackVersion = kAppDefaultVersion,
}) async {
  RandomAccessFile? file;
  try {
    file = await File(filePath).open(mode: FileMode.read);
    final bytes = await file.read(_versionReadMaxBytes);
    return _decodeVersion(bytes) ?? fallbackVersion;
  } on Object {
    return fallbackVersion;
  } finally {
    if (file != null) {
      try {
        await file.close();
      } on Object {
        // 读取结果已经确定；关闭失败不改变展示值。
      }
    }
  }
}

String? _decodeVersion(List<int> bytes) {
  final payloadLength = bytes.length < _versionPayloadMaxBytes
      ? bytes.length
      : _versionPayloadMaxBytes;
  final nulIndex = bytes.take(payloadLength).toList().indexOf(0);
  final end = nulIndex >= 0 ? nulIndex : payloadLength;
  final truncatedByLimit = nulIndex < 0 && bytes.length > payloadLength;
  if (end == 0) {
    return '';
  }

  final maxTailBytesToDrop = truncatedByLimit ? 3 : 0;
  for (var tailBytesToDrop = 0;
      tailBytesToDrop <= maxTailBytesToDrop && end > tailBytesToDrop;
      tailBytesToDrop++) {
    try {
      final decoded = utf8.decode(
        bytes.sublist(0, end - tailBytesToDrop),
        allowMalformed: false,
      );
      final normalized = decoded.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      return normalized;
    } on FormatException {
      // 只允许丢弃长度上限截断产生的不完整 UTF-8 尾字节。
    }
  }
  return null;
}
