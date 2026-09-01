import 'package:flutter/material.dart';

/// 退款原因选择弹窗（完整版：Tab 切换 + 12 个原因 + 上一步/下一步）
/// 参考图 11-14：退款/退货退款 两个 Tab，原因列表 + 单选
///
/// 使用：
///   showRefundReasonPicker(context, currentReason: '...').then((v) { ... })
/// 返回：选中的原因字符串，取消返回 null
Future<String?> showRefundReasonPicker(BuildContext context,
    {String? currentReason}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RefundReasonSheet(currentReason: currentReason),
  );
}

class _RefundReasonSheet extends StatefulWidget {
  final String? currentReason;

  const _RefundReasonSheet({this.currentReason});

  @override
  State<_RefundReasonSheet> createState() => _RefundReasonSheetState();
}

class _RefundReasonSheetState extends State<_RefundReasonSheet> {
  // 0=退款 1=退货退款
  int _tab = 0;
  String? _selected;

  // 退款原因列表（参考图 13）
  static const List<String> _refundOnlyReasons = [
    '过敏包退服务',
    '与商家协商一致退款',
    '七天无理由退货',
    '包装/商品破损',
    '成分与商品描述不符',
    '少件/漏发',
    '标签/规格/包装等与商品描述不符',
    '卖家发错货',
    '商品变质/发霉/有异物',
    '假冒品牌',
    '生产日期/保质期与商品描述不符',
    '商品临近保质期/过期',
    '其他问题',
  ];

  // 退货退款原因列表（参考图 14）
  static const List<String> _refundReturnReasons = [
    '协商一致退款',
    '买贵了/少用优惠',
    '不喜欢/不想要',
  ];

  // 未收到货 / 已收到货 子 tab（参考图 12）
  bool _notReceived = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentReason?.isEmpty ?? true
        ? null
        : widget.currentReason;
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _tab == 0 ? _refundOnlyReasons : _refundReturnReasons;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部标题
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('选择售后原因',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close,
                        size: 20, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            // Tab 切换
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _tabButton('退款', 0, showRecommend: true),
                  const SizedBox(width: 8),
                  _tabButton('退货退款', 1),
                ],
              ),
            ),
            // 子 tab：未收到货 / 已收到货（仅"退款"tab 显示，参考图 12）
            if (_tab == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Bebady男性复合维生素',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF666666))),
                    const SizedBox(width: 12),
                    _subTabButton('未收到货', _notReceived, () {
                      setState(() => _notReceived = true);
                    }),
                    const SizedBox(width: 8),
                    _subTabButton('已收到货', !_notReceived, () {
                      setState(() => _notReceived = false);
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // 原因列表（可滚动）
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: reasons.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, i) {
                  final r = reasons[i];
                  final checked = _selected == r;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(r,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: checked
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF333333),
                                    fontWeight: checked
                                        ? FontWeight.w500
                                        : FontWeight.normal)),
                          ),
                          Icon(
                            checked
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: checked
                                ? const Color(0xFFFF5000)
                                : const Color(0xFFCCCCCC),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text('上一步',
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _selected == null
                          ? null
                          : () => Navigator.of(context).pop(_selected),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selected == null
                                ? [
                                    const Color(0xFFFFD1B8),
                                    const Color(0xFFFFC2A3)
                                  ]
                                : [
                                    const Color(0xFFFF9A56),
                                    const Color(0xFFFF5000)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text('下一步',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int tab, {bool showRecommend = false}) {
    final active = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF1E8) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: active
                  ? const Color(0xFFFF5000)
                  : const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? const Color(0xFFFF5000)
                        : const Color(0xFF666666),
                    fontWeight:
                        active ? FontWeight.w500 : FontWeight.normal)),
            if (showRecommend) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5000),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text('荐',
                    style: TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subTabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF1E8) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: active
                  ? const Color(0xFFFF5000)
                  : const Color(0xFFE5E5E5)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active
                    ? const Color(0xFFFF5000)
                    : const Color(0xFF666666))),
      ),
    );
  }
}
