import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 极简 ZIP 读写（仅 store 不压缩格式，v1.9.102）
///
/// 为什么不能引依赖：本项目离线环境 pub get 不通，无法新增 archive 包；
/// 备份文件是图片为主（本身已压缩），store 模式体积损失可忽略。
/// 自己写自己读，格式标准——Windows/macOS 解压软件也能直接打开。
class SimpleZip {
  SimpleZip._();

  static final _crcTable = _buildCrcTable();

  static List<int> _buildCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
      table[i] = c;
    }
    return table;
  }

  static int _crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// 打包：entries = { zip内路径(用/分隔): 文件字节 }
  static Future<void> create(
      String zipPath, Map<String, List<int>> entries) async {
    final out = BytesBuilder();
    final central = BytesBuilder();
    var count = 0;

    for (final e in entries.entries) {
      final nameBytes = utf8.encode(e.key);
      final data = e.value;
      final crc = _crc32(data);
      final offset = out.length;

      // Local file header
      final lh = ByteData(30);
      lh.setUint32(0, 0x04034b50, Endian.little);
      lh.setUint16(4, 20, Endian.little); // version needed
      lh.setUint16(6, 0x0800, Endian.little); // flags: UTF-8 文件名
      lh.setUint16(8, 0, Endian.little); // method: store
      lh.setUint16(10, 0, Endian.little); // mod time
      lh.setUint16(12, 0x21, Endian.little); // mod date (1980-01-01)
      lh.setUint32(14, crc, Endian.little);
      lh.setUint32(18, data.length, Endian.little);
      lh.setUint32(22, data.length, Endian.little);
      lh.setUint16(26, nameBytes.length, Endian.little);
      lh.setUint16(28, 0, Endian.little); // extra len
      out.add(lh.buffer.asUint8List());
      out.add(nameBytes);
      out.add(data);

      // Central directory record
      final ch = ByteData(46);
      ch.setUint32(0, 0x02014b50, Endian.little);
      ch.setUint16(4, 20, Endian.little); // version made by
      ch.setUint16(6, 20, Endian.little); // version needed
      ch.setUint16(8, 0x0800, Endian.little); // flags: UTF-8
      ch.setUint16(10, 0, Endian.little); // method: store
      ch.setUint16(12, 0, Endian.little); // mod time
      ch.setUint16(14, 0x21, Endian.little); // mod date
      ch.setUint32(16, crc, Endian.little);
      ch.setUint32(20, data.length, Endian.little);
      ch.setUint32(24, data.length, Endian.little);
      ch.setUint16(28, nameBytes.length, Endian.little);
      ch.setUint16(30, 0, Endian.little); // extra
      ch.setUint16(32, 0, Endian.little); // comment
      ch.setUint16(34, 0, Endian.little); // disk number
      ch.setUint16(36, 0, Endian.little); // internal attrs
      ch.setUint32(38, 0, Endian.little); // external attrs
      ch.setUint32(42, offset, Endian.little); // local header offset
      central.add(ch.buffer.asUint8List());
      central.add(nameBytes);
      count++;
    }

    final cdOffset = out.length;
    final cdBytes = central.toBytes();
    out.add(cdBytes);

    // End of central directory
    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, count, Endian.little);
    eocd.setUint16(10, count, Endian.little);
    eocd.setUint32(12, cdBytes.length, Endian.little);
    eocd.setUint32(16, cdOffset, Endian.little);
    eocd.setUint16(20, 0, Endian.little);
    out.add(eocd.buffer.asUint8List());

    await File(zipPath).writeAsBytes(out.toBytes(), flush: true);
  }

  /// 解包：返回 { zip内路径: 文件字节 }（仅支持 store 不压缩条目，
  /// 遇到压缩条目会跳过——本工具自己打的包全部是 store）
  static Future<Map<String, List<int>>> extract(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final data = ByteData.sublistView(bytes);
    final result = <String, List<int>>{};

    // 从尾部找 EOCD
    var eocdPos = -1;
    for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 66000; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50) {
        eocdPos = i;
        break;
      }
    }
    if (eocdPos < 0) return result;

    final count = data.getUint16(eocdPos + 10, Endian.little);
    var pos = data.getUint32(eocdPos + 16, Endian.little);

    for (var n = 0; n < count; n++) {
      if (pos + 46 > bytes.length) break;
      if (data.getUint32(pos, Endian.little) != 0x02014b50) break;
      final method = data.getUint16(pos + 10, Endian.little);
      final size = data.getUint32(pos + 24, Endian.little);
      final nameLen = data.getUint16(pos + 28, Endian.little);
      final extraLen = data.getUint16(pos + 30, Endian.little);
      final commentLen = data.getUint16(pos + 32, Endian.little);
      final localOffset = data.getUint32(pos + 42, Endian.little);
      final name = utf8.decode(
          bytes.sublist(pos + 46, pos + 46 + nameLen),
          allowMalformed: true);
      pos += 46 + nameLen + extraLen + commentLen;

      if (method != 0) continue; // 只支持 store

      // 读 local header 找数据起点
      if (localOffset + 30 > bytes.length) continue;
      if (data.getUint32(localOffset, Endian.little) != 0x04034b50) continue;
      final lNameLen = data.getUint16(localOffset + 26, Endian.little);
      final lExtraLen = data.getUint16(localOffset + 28, Endian.little);
      final dataStart = localOffset + 30 + lNameLen + lExtraLen;
      if (dataStart + size > bytes.length) continue;
      result[name] = bytes.sublist(dataStart, dataStart + size);
    }
    return result;
  }
}
