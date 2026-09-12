import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/persistence_service.dart';
import '../../providers/product_image_provider.dart';
import '../../utils/simple_zip.dart';

/// 淘宝订单同步导入页（我的 → 工具卡片「同步订单」进入）
/// 电脑端脚本抓取真实淘宝订单生成 JSON → 微信传到手机 → 这里导入。
/// 规则：按订单号去重，只增不改——已在列表里的订单（含手动编辑过的）绝不覆盖。
class TaobaoSyncImportScreen extends StatefulWidget {
  const TaobaoSyncImportScreen({super.key});

  @override
  State<TaobaoSyncImportScreen> createState() => _TaobaoSyncImportScreenState();
}

class _TaobaoSyncImportScreenState extends State<TaobaoSyncImportScreen> {
  bool _busy = false;
  // v1.9.103：强制覆盖绿色标签——导入时所有匹配订单的服务标签
  // 无条件以抓包为准（含手动改过的；抓包无标签=该商品真没有标签）
  bool _forceTags = false;
  // v1.9.107：强制覆盖店铺头像——修正旧抓包/兜底链抓到的错版头像
  // （红底 logo 等），以本次抓包 newShopImg 为准
  bool _forceAvatar = false;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 从 JSON 文本解析店铺订单列表（支持 {"version":n,"orders":[...]} 与纯数组两种格式）
  List<ShoppingCartShop> _parse(String raw) {
    final decoded = jsonDecode(raw);
    List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      final orders = decoded['orders'];
      if (orders is! List) throw const FormatException('JSON 里找不到 orders 数组');
      list = orders;
    } else if (decoded is List) {
      list = decoded;
    } else {
      throw const FormatException('JSON 格式不对');
    }
    final shops = list
        .map((e) => PersistenceService.shopFromJson(e as Map<String, dynamic>))
        .where((s) => s.items.isNotEmpty)
        .toList();
    if (shops.isEmpty) throw const FormatException('没有解析到有效订单');
    return shops;
  }

  /// 预览 → 确认 → 导入
  Future<void> _previewAndImport(String raw, String sourceDesc) async {
    List<ShoppingCartShop> shops;
    try {
      shops = _parse(raw);
    } catch (e) {
      _toast('解析失败：$e');
      return;
    }
    final provider = context.read<CartProvider>();
    final existingNos = <String>{
      for (final s in provider.shops)
        for (final it in s.items) it.orderNo,
    };
    var total = 0;
    final dupItems = <Map<String, String>>[];
    for (final s in shops) {
      for (final it in s.items) {
        total++;
        if (it.orderNo.isNotEmpty && existingNos.contains(it.orderNo)) {
          dupItems.add({
            'no': it.orderNo,
            'shop': s.shopName,
            'title': it.title,
          });
        }
      }
    }
    final dup = dupItems.length;
    // v1.9.95：按单选择要覆盖的已有订单（替代旧的整批强制刷新开关）
    final selected = <String>{};

    Future<void> pickOverwrite() async {
      await showDialog<void>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c2, setState2) => AlertDialog(
            title: Text('选择要覆盖的订单（${selected.length}/$dup）',
                style: const TextStyle(fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  CheckboxListTile(
                    value: dup > 0 && selected.length == dup,
                    onChanged: (v) => setState2(() {
                      selected.clear();
                      if (v == true) {
                        selected.addAll(dupItems.map((e) => e['no']!));
                      }
                    }),
                    title: const Text('全选', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: dupItems.length,
                      itemBuilder: (_, i) {
                        final d = dupItems[i];
                        final no = d['no']!;
                        final tail = no.length > 6
                            ? no.substring(no.length - 6)
                            : no;
                        return CheckboxListTile(
                          value: selected.contains(no),
                          onChanged: (v) => setState2(() {
                            v == true
                                ? selected.add(no)
                                : selected.remove(no);
                          }),
                          title: Text(d['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text('${d['shop']} · 单号…$tail',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('完成')),
            ],
          ),
        ),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setState2) => AlertDialog(
          title: const Text('确认导入？', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '来源：$sourceDesc\n'
                '解析到 ${shops.length} 家店铺 / $total 条订单\n\n'
                '✅ 新增导入：${total - dup} 条\n'
                '⏭ 已存在：$dup 条（默认跳过，只补空字段）',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              // v1.9.103：强制覆盖绿色标签开关（配合 taobao_tags_*.json 使用）
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState2(() => _forceTags = !_forceTags),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _forceTags,
                        onChanged: (v) =>
                            setState2(() => _forceTags = v ?? false),
                        activeColor: const Color(0xFFFF5000),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('强制覆盖绿色标签（以抓包为准）',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              if (_forceTags)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ 所有匹配订单的服务标签将被抓包数据覆盖，'
                    '手动改过的标签也会冲掉；抓包没有标签的商品将不显示标签。',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFF5000)),
                  ),
                ),
              // v1.9.107：强制覆盖店铺头像——旧抓包/兜底链抓到的错版头像
              // （如红底 logo）会被本次抓包的 newShopImg 白底正版覆盖
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState2(() => _forceAvatar = !_forceAvatar),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _forceAvatar,
                        onChanged: (v) =>
                            setState2(() => _forceAvatar = v ?? false),
                        activeColor: const Color(0xFFFF5000),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('强制覆盖店铺头像（以本次抓包为准）',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              if (_forceAvatar)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ 同名店铺所有订单的头像都会被本次抓包头像覆盖，'
                    '用于修正以前抓错的头像（红底/错版）。',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFF5000)),
                  ),
                ),
              if (dup > 0) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await pickOverwrite();
                    setState2(() {});
                  },
                  icon: const Icon(Icons.checklist, size: 16),
                  label: Text(
                    selected.isEmpty
                        ? '按单选择覆盖（$dup 条已存在）'
                        : '已选 ${selected.length} 条覆盖',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5000),
                    side: const BorderSide(color: Color(0xFFFF5000)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selected.isEmpty
                      ? '不选择则已有订单保持原样（你的手动修改全部保留）。'
                      : '⚠️ 选中订单将被抓包数据整单覆盖，手动修改会丢失。',
                  style: TextStyle(
                      fontSize: 12,
                      color: selected.isEmpty
                          ? Colors.black54
                          : const Color(0xFFFF5000)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('导入',
                    style: TextStyle(color: Color(0xFFFF5000)))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    // v1.9.95：覆盖前二次确认——选中订单的手动修改将被冲掉
    if (selected.isNotEmpty) {
      final ok2 = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('确认覆盖选中订单？', style: TextStyle(fontSize: 16)),
          content: Text(
            '将用抓包数据整单覆盖 ${selected.length} 个已存在订单。\n\n'
            '⚠️ 你在这些订单上手动改过的内容（价格/文案/优惠/赠品等）'
            '会全部丢失，且不可恢复。',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('再想想')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('确定覆盖',
                    style: TextStyle(color: Color(0xFFFF5000)))),
          ],
        ),
      );
      if (ok2 != true) return;
    }

    final result = provider.importSyncedShops(shops,
        forceOrderNos: selected,
        forceTags: _forceTags,
        forceAvatar: _forceAvatar);
    // v1.9.102：抓包真实店铺头像「强制覆盖」——清掉同名店铺的手动换头像
    // 覆盖层（用户反馈之前手动换的头像不理想，以抓包真实头像为准）；
    // 覆盖层清除后详情页/退款页立即显示抓包头像
    final imgProvider = context.read<ProductImageProvider>();
    for (final s in shops) {
      if (s.shopAvatar.isNotEmpty) {
        imgProvider.removeOverride('shop_avatar:${s.shopName}');
      }
    }
    final tail = result.blocked > 0 ? '，拦截已删除 ${result.blocked} 条' : '';
    final cover = selected.isNotEmpty ? '，其中覆盖 ${selected.length} 条' : '';
    if (result.added > 0) {
      _toast('已导入 ${result.added} 条$cover（跳过 ${result.skipped} 条$tail）');
      if (mounted) Navigator.of(context).pop();
    } else if (_forceTags) {
      _toast('绿色标签已按抓包强制覆盖（无新订单，${result.skipped} 条已存在）');
    } else {
      _toast('没有新订单，${result.skipped} 条已存在$tail');
    }
  }

  /// 选择文件导入（支持抓包 JSON / 备份 ZIP）
  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'zip'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) {
        _toast('读不到文件路径');
        return;
      }
      // v1.9.102：备份 ZIP（订单 JSON + 本地图片）先还原图片再导订单
      if (path.toLowerCase().endsWith('.zip')) {
        await _restoreFromZip(path);
        return;
      }
      final raw = await File(path).readAsString();
      await _previewAndImport(raw, res.files.single.name);
    } catch (e) {
      _toast('读取文件失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 从备份 ZIP 恢复（v1.9.102）：先把图片写回 Documents 各目录
  /// （手动换的商品图/店铺头像/赠品图/消息头像/首页banner），
  /// 再走 JSON 订单导入流程；图片覆盖层重新加载让恢复的头像立即生效
  Future<void> _restoreFromZip(String path) async {
    try {
      final entries = await SimpleZip.extract(path);
      if (entries.isEmpty) {
        _toast('ZIP 里没有可恢复的内容');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      String? jsonStr;
      var imgCount = 0;
      for (final e in entries.entries) {
        if (e.key.endsWith('.json')) {
          jsonStr = utf8.decode(e.value);
          continue;
        }
        final safe = e.key.replaceAll('..', ''); // 防路径穿越
        final f = File('${dir.path}/$safe');
        f.parent.createSync(recursive: true);
        await f.writeAsBytes(e.value, flush: true);
        imgCount++;
      }
      if (imgCount > 0) {
        _toast('已恢复 $imgCount 张本地图片');
        // 重新扫描图片覆盖层（启动时文件缺失被丢弃的映射现在能命中了）
        await context.read<ProductImageProvider>().load();
      }
      if (jsonStr == null) {
        _toast('ZIP 里没有订单数据');
        return;
      }
      await _previewAndImport(jsonStr, '备份ZIP');
    } catch (e) {
      _toast('恢复失败：$e');
    }
  }

  /// 粘贴 JSON 文本导入
  Future<void> _pasteText() async {
    final ctl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
      ctl.text = clip.text!;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('粘贴订单 JSON', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctl,
            maxLines: 8,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              hintText: '把电脑脚本生成的 JSON 内容粘贴到这里',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('解析',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await _previewAndImport(ctl.text.trim(), '粘贴的文本');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('同步淘宝订单',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 使用说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DCFF)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync, size: 16, color: Color(0xFF1976D2)),
                    SizedBox(width: 6),
                    Text('怎么同步',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '1. 在电脑上运行抓单脚本（扫码登录淘宝一次）\n'
                  '2. 把生成的 JSON 文件用微信发到手机\n'
                  '3. 回到这里点「选择文件导入」\n\n'
                  '默认只新增订单：已有订单（包括你改过的）原样保留。'
                  '想用抓包数据覆盖某几单，导入时点「按单选择覆盖」勾选即可，覆盖前会再确认一次。',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF0D47A1), height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.file_open),
              label: Text(_busy ? '读取中...' : '选择 JSON 文件导入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pasteText,
              icon: const Icon(Icons.content_paste),
              label: const Text('粘贴 JSON 文本导入'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5000),
                side: const BorderSide(color: Color(0xFFFF5000)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildBackupCard(),
          const SizedBox(height: 10),
          _buildClearAllCard(),
          const SizedBox(height: 10),
          _buildBlacklistCard(),
        ],
      ),
    );
  }

  /// 备份卡片（v1.9.96）：导出全部订单（含手动编辑）为 JSON 文件，
  /// 防证书过期删 App 丢编辑记录；文件在 系统「文件」App 可见，
  /// 恢复 = 本页「选择文件导入」（v1.9.102 起 ZIP 含全部本地图片）
  Widget _buildBackupCard() {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final count = provider.shops.length;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_download_outlined,
                  size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '备份全部订单（含你的编辑）防掉签丢数据',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: () => _exportBackup(provider),
                  child: const Text('导出备份',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF5000))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportBackup(CartProvider provider) async {
    try {
      final data = {
        'version': 1,
        'orders':
            provider.shops.map(PersistenceService.shopToJson).toList(),
      };
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final jsonStr = const JsonEncoder.withIndent(' ').convert(data);

      // v1.9.102：备份升级为 ZIP——JSON + 全部本地图片一起打包。
      // 手动换的商品图/店铺头像/赠品图/消息头像/首页banner/个人头像都存
      // 在这些目录里，证书过期删 App 重装后导入 ZIP 可原样恢复（含图片）
      final entries = <String, List<int>>{
        'taobao_backup.json': utf8.encode(jsonStr),
      };
      var imgCount = 0;
      for (final sub in const [
        'order_images',
        'product_images',
        'shop_avatars',
        'gift_images',
        'message_avatars',
        'banner_materials',
        'profile_avatars',
        'profile_backgrounds',
        'materials',
      ]) {
        final d = Directory('${dir.path}/$sub');
        if (!d.existsSync()) continue;
        for (final f in d.listSync(recursive: true).whereType<File>()) {
          final rel =
              f.path.replaceAll('\\', '/').split('${dir.path}/').last;
          try {
            entries[rel] = await f.readAsBytes();
            imgCount++;
          } catch (_) {}
        }
      }
      final zipName = 'taobao_backup_$stamp.zip';
      await SimpleZip.create('${dir.path}/$zipName', entries);
      // 同步保留一份纯 JSON（老习惯/跨版本兼容）
      await File('${dir.path}/taobao_backup_$stamp.json')
          .writeAsString(jsonStr);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('备份已生成', style: TextStyle(fontSize: 16)),
          content: Text(
            '文件：$zipName\n'
            '（${provider.shops.length} 家店铺 + $imgCount 张本地图片）\n\n'
            '发送到微信保存：打开系统「文件」App → 我的 iPhone → 淘宝 → '
            '长按该文件 → 共享 → 微信（文件传输助手）。\n\n'
            '证书过期换签重装后：回到本页点「选择文件导入」，选中这个 ZIP，'
            '全部订单、你的编辑记录和换过的图片一起恢复。',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('知道了',
                    style: TextStyle(color: Color(0xFFFF5000)))),
          ],
        ),
      );
    } catch (e) {
      _toast('备份失败：$e');
    }
  }

  /// 一键清空全部商品订单（仅淘宝商品订单，不影响闪购/飞猪；
  /// 不写入已删黑名单，清空后可立即重新导入抓包 JSON）
  Widget _buildClearAllCard() {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final count = provider.shops.length;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.cleaning_services_outlined,
                  size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 0 ? '当前商品订单 $count 单' : '当前没有商品订单',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: () => _confirmClearAll(provider, count),
                  child: const Text('一键清空',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF5000))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(CartProvider provider, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部商品订单？', style: TextStyle(fontSize: 16)),
        content: Text(
          '将删除当前 $count 单商品订单（不含闪购/飞猪）。\n\n'
          '清空后这些订单不会进已删黑名单，可立即重新导入抓包 JSON 全量恢复。',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true) {
      final n = provider.clearAllShops();
      _toast('已清空 $n 单商品订单');
    }
  }

  /// 已删除订单黑名单卡片：用户删掉的订单不会再被同步导入复活
  Widget _buildBlacklistCard() {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final count = provider.deletedTradeNosCount;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 0
                      ? '已删除订单 $count 条（导入时永久跳过）'
                      : '已删除订单黑名单为空',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: () => _confirmClearBlacklist(provider),
                  child: const Text('清空',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF5000))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearBlacklist(CartProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空已删除黑名单？', style: TextStyle(fontSize: 16)),
        content: const Text(
          '清空后，下次同步导入会把你在淘宝里仍存在、但之前在本 App 删除过的订单重新导进来。',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true) {
      await provider.clearDeletedTradeNos();
      _toast('黑名单已清空');
    }
  }
}
