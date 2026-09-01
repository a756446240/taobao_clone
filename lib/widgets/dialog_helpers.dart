import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// 通用对话框：
/// 1. 选项式选择（仿 3.4 APK，如"支付方式""发货方式"）
/// 2. 时间滚动选择器（年/月/日/时/分/秒）
/// 3. 文本输入（兜底）
class DialogHelpers {
  DialogHelpers._();

  /// 选项对话框：返回被选中的字符串
  static Future<String?> showOptionPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final v = options[i];
                    final selected = v == currentValue;
                    return ListTile(
                      title: Text(v,
                          style: TextStyle(
                            color:
                                selected ? const Color(0xFFff5000) : Colors.black87,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                      trailing: selected
                          ? const Icon(Icons.check,
                              color: Color(0xFFff5000))
                          : null,
                      onTap: () => Navigator.of(ctx).pop(v),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 多项选择对话框：返回更新后的 Set
  static Future<Set<String>?> showMultiOptionPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Set<String> initiallySelected,
  }) {
    final selected = Set<String>.from(initiallySelected);
    return showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(selected),
                            child: const Text('确定',
                                style: TextStyle(
                                    color: Color(0xFFff5000),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final v = options[i];
                          return CheckboxListTile(
                            value: selected.contains(v),
                            title: Text(v),
                            activeColor: const Color(0xFFff5000),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selected.add(v);
                                } else {
                                  selected.remove(v);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 滚动选择时间（仿 3.4 APK CupertinoPicker）
  /// initial 形如 "2026-08-26 11:28:56" 或 "8月30日 9:59"
  static Future<String?> showDateTimePicker(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    DateTime init;
    try {
      // 尝试 yyyy-MM-dd HH:mm:ss
      if (initial.contains('-') && initial.length >= 10) {
        final t = initial.replaceFirst(' ', 'T');
        init = DateTime.parse(t.length >= 19 ? t.substring(0, 19) : t);
      } else {
        // 8月30日 9:59
        final m = RegExp(r'(\d+)月(\d+)日\s*(\d+):(\d+)').firstMatch(initial);
        if (m != null) {
          final now = DateTime.now();
          init = DateTime(now.year, int.parse(m.group(1)!),
              int.parse(m.group(2)!), int.parse(m.group(3)!),
              int.parse(m.group(4)!));
        } else {
          init = DateTime.now();
        }
      }
    } catch (_) {
      init = DateTime.now();
    }

    DateTime selected = init;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: StatefulBuilder(
              builder: (ctx2, setState) {
                void onChange(DateTime t) {
                  setState(() => selected = t);
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('取消',
                                style: TextStyle(
                                    color: Color(0xFF666666), fontSize: 14)),
                          ),
                          Expanded(
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                  ctx)
                                  .pop(
                                      _formatDateTime(selected));
                            },
                            child: const Text('确定',
                                style: TextStyle(
                                    color: Color(0xFFff5000),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFfff2e8),
                      child: Text(
                        _formatDateTime(selected),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFff5000),
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _pickerCol(_years(), selected.year, (v) =>
                              onChange(DateTime(
                                  v, selected.month, selected.day,
                                  selected.hour, selected.minute,
                                  selected.second))),
                          _pickerCol(
                              _months(), selected.month,
                              (v) => onChange(DateTime(
                                  selected.year, v, selected.day,
                                  selected.hour, selected.minute,
                                  selected.second))),
                          _pickerCol(_days(selected.year, selected.month),
                              selected.day,
                              (v) => onChange(DateTime(
                                  selected.year, selected.month, v,
                                  selected.hour, selected.minute,
                                  selected.second))),
                          _pickerCol(_hours(), selected.hour,
                              (v) => onChange(DateTime(
                                  selected.year, selected.month,
                                  selected.day, v, selected.minute,
                                  selected.second))),
                          _pickerCol(_minutes(), selected.minute,
                              (v) => onChange(DateTime(
                                  selected.year, selected.month,
                                  selected.day, selected.hour, v,
                                  selected.second))),
                          _pickerCol(_seconds(), selected.second,
                              (v) => onChange(DateTime(
                                  selected.year, selected.month,
                                  selected.day, selected.hour,
                                  selected.minute, v))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  static Widget _pickerCol(List<int> values, int current,
      ValueChanged<int> onSelectedItemChanged) {
    final idx = values.indexOf(current);
    return Expanded(
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
            initialItem: idx >= 0 ? idx : 0),
        itemExtent: 36,
        onSelectedItemChanged: (i) => onSelectedItemChanged(values[i]),
        children: values
            .map((v) => Center(
                  child: Text(v.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 18)),
                ))
            .toList(),
      ),
    );
  }

  static String _formatDateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static List<int> _years() =>
      List.generate(11, (i) => DateTime.now().year - 5 + i);
  static List<int> _months() => List.generate(12, (i) => i + 1);
  static List<int> _days(int y, int m) {
    final max = DateTime(y, m + 1, 0).day;
    return List.generate(max, (i) => i + 1);
  }

  static List<int> _hours() => List.generate(24, (i) => i);
  static List<int> _minutes() => List.generate(60, (i) => i);
  static List<int> _seconds() => List.generate(60, (i) => i);

  /// 滚动式倒计时选择器（仿 3.4 APK：天 + 小时 双滚轮）
  /// initial 形如 "还剩3天21小时自动确认"，返回 "还剩X天Y小时自动确认"
  static Future<String?> showCountdownPicker(
    BuildContext context, {
    required String title,
    required String initial,
    String suffix = '自动确认',
  }) {
    // 解析初始值中的 天/小时
    var days = 3;
    var hours = 0;
    final m = RegExp(r'还剩(\d+)天(?:(\d+)小时)?').firstMatch(initial);
    if (m != null) {
      days = int.tryParse(m.group(1)!) ?? 3;
      if (m.group(2) != null) hours = int.tryParse(m.group(2)!) ?? 0;
    }
    days = days.clamp(1, 30);
    hours = hours.clamp(0, 23);

    int selDays = days;
    int selHours = hours;
    final daysCtrl = FixedExtentScrollController(initialItem: selDays - 1);
    final hoursCtrl = FixedExtentScrollController(initialItem: selHours);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx2, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消',
                              style: TextStyle(
                                  color: Color(0xFF666666), fontSize: 14)),
                        ),
                        Expanded(
                          child: Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx)
                              .pop('还剩${selDays}天${selHours}小时$suffix'),
                          child: const Text('确定',
                              style: TextStyle(
                                  color: Color(0xFFff5000),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  // 预览条
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '还剩 $selDays 天 $selHours 小时后$suffix',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFff5000),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _countdownWheel(
                          ctrl: daysCtrl,
                          label: '天',
                          count: 30,
                          selected: selDays - 1,
                          textBuilder: (i) => '${i + 1} 天',
                          onChanged: (i) => setSheet(() => selDays = i + 1),
                        ),
                        const SizedBox(width: 24),
                        _countdownWheel(
                          ctrl: hoursCtrl,
                          label: '小时',
                          count: 24,
                          selected: selHours,
                          textBuilder: (i) => '$i 小时',
                          onChanged: (i) => setSheet(() => selHours = i),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    ).then((v) {
      daysCtrl.dispose();
      hoursCtrl.dispose();
      return v;
    });
  }

  static Widget _countdownWheel({
    required FixedExtentScrollController ctrl,
    required String label,
    required int count,
    required int selected,
    required String Function(int) textBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        SizedBox(
          height: 180,
          width: 130,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 44,
            physics: const FixedExtentScrollPhysics(),
            controller: ctrl,
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (c, i) {
                final active = i == selected;
                return Center(
                  child: Text(
                    textBuilder(i),
                    style: TextStyle(
                      fontSize: active ? 20 : 15,
                      color: active
                          ? const Color(0xFFff5000)
                          : const Color(0xFF999999),
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                );
              },
              childCount: count,
            ),
          ),
        ),
      ],
    );
  }

  /// 文本输入对话框（兜底）
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    required String initial,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(hintText: '请输入新内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
