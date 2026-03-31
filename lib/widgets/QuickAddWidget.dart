import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/utils/Utils.dart';

class QuickAddPreset {
  final int groupId;
  final double amount;
  
  QuickAddPreset(this.groupId, this.amount);
  
  Map<String, dynamic> toJson() => {'groupId': groupId, 'amount': amount};
  factory QuickAddPreset.fromJson(Map<String, dynamic> json) => QuickAddPreset(json['groupId'], json['amount']);
}

class QuickAddWidget extends StatefulWidget {
  const QuickAddWidget({super.key});

  @override
  State<QuickAddWidget> createState() => _QuickAddWidgetState();
}

class _QuickAddWidgetState extends State<QuickAddWidget> {
  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  // Default fallback preset amounts
  double _foodAmount = 20000;
  double _cafeAmount = 30000;
  double _transportAmount = 50000;

  List<QuickAddPreset> _customPresets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _foodAmount = prefs.getDouble('qa_food') ?? 20000;
      _cafeAmount = prefs.getDouble('qa_cafe') ?? 30000;
      _transportAmount = prefs.getDouble('qa_transport') ?? 50000;

      final presetsData = prefs.getString('qa_custom_presets');
      if (presetsData != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(presetsData);
          _customPresets = jsonList.map((e) => QuickAddPreset.fromJson(e)).toList();
        } catch (e) {
          _customPresets = [];
        }
      }
    });
  }

  Future<void> _saveAmount(String key, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, amount);
  }

  Future<void> _saveCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qa_custom_presets', jsonEncode(_customPresets.map((e) => e.toJson()).toList()));
  }

  void _showPopupNotification(String title, String message, bool isError) {
    showDialog(
      context: context,
      builder: (context) {
        final s = S.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: isError ? Colors.red : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(s.get('close') ?? 'Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _addQuickTransactionFromDefault(String originalTitle, double amount, String type, String iconString) async {
    final groupProxy = context.read<GroupModelProxy>();
    final groups = groupProxy.getAll();
    int groupId = 1;
    try {
      groupId = groups.firstWhere((g) => g.name == originalTitle && g.type == type).id;
    } catch (e) {
      if (groups.isNotEmpty) groupId = groups.first.id;
    }
    _addQuickTransaction(originalTitle, amount, groupId, "expense");
  }

  void _addQuickTransaction(String title, double amount, int groupId, String type) async {
    final proxy = context.read<TransactionModelProxy>();
    final walletProxy = context.read<WalletModelProxy>();
    final wallet = proxy.walletModel;
    final s = S.of(context);
    
    if (wallet.id == 0) {
      _showPopupNotification(s.get('error') ?? 'Lỗi', s.get('notification_select_wallet') ?? 'Vui lòng chọn ví trước khi thêm!', true);
      return;
    }

    final transaction = TransactionModel(
      DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      unit: "VND",
      type: type, // generally expense
      date: DateTime.now().toString(),
      note: title,
      walletId: wallet.id,
      groupId: groupId,
      addToReport: true,
    );
    
    await proxy.add(transaction);

    var currentWallet = walletProxy.getById(wallet.id);
    double newBalance = type == 'expense' ? (currentWallet.balance ?? 0) - amount : (currentWallet.balance ?? 0) + amount;
    await walletProxy.updateBalance(currentWallet, newBalance);

    if (!mounted) return;
    _showPopupNotification(s.get('success') ?? 'Thành công', '${s.get('chatbot_recorded') ?? 'Đã ghi nhận '} $title!', false);
  }

  void _editAmountDialog(String title, double currentAmount, String key, {int? customIndex}) {
    final initialText = NumberFormat('#,###', 'en_US').format(currentAmount);
    final TextEditingController controller = TextEditingController(text: initialText);
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${s.get('edit') ?? 'Sửa mặ định'} - $title'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                final intValue = int.tryParse(newValue.text.replaceAll(',', ''));
                if (intValue == null) return oldValue;
                final newText = NumberFormat('#,###', 'en_US').format(intValue);
                return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
              }),
            ],
            decoration: InputDecoration(
              labelText: s.get('amount') ?? 'Số tiền (VND)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            if (customIndex != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _customPresets.removeAt(customIndex);
                  });
                  _saveCustomPresets();
                  Navigator.pop(context); // close dialog
                },
                child: Text(s.get('delete') ?? 'Xóa', style: const TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.get('cancel') ?? 'Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.replaceAll(',', ''));
                if (amount != null && amount > 0) {
                  setState(() {
                    if (customIndex != null) {
                      _customPresets[customIndex] = QuickAddPreset(_customPresets[customIndex].groupId, amount);
                      _saveCustomPresets();
                    } else {
                      _saveAmount(key, amount);
                      if (key == 'qa_food') _foodAmount = amount;
                      if (key == 'qa_cafe') _cafeAmount = amount;
                      if (key == 'qa_transport') _transportAmount = amount;
                    }
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(s.get('save') ?? 'Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPresetDialog() {
    final groups = context.read<GroupModelProxy>().getAll();
    GroupModel? selectedGroup = groups.isNotEmpty ? groups.first : null;
    final TextEditingController amountController = TextEditingController();
    final s = S.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // allow custom shape
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.get('add_widget') ?? 'Thêm Widget', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text(s.get('select_group') ?? 'Chọn nhóm', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<GroupModel>(
                          value: selectedGroup,
                          isExpanded: true,
                          items: groups.map((g) {
                            return DropdownMenuItem<GroupModel>(
                              value: g,
                              child: Row(
                                children: [
                                  Icon(IconData(int.parse(g.icon ?? '57234'), fontFamily: 'MaterialIcons'), color: _colorFromHex(g.color ?? '#000000')),
                                  const SizedBox(width: 10),
                                  Text(Utils.translateGroupName(context, g.name)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedGroup = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(s.get('amount') ?? 'Số tiền định mức', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          final intValue = int.tryParse(newValue.text.replaceAll(',', ''));
                          if (intValue == null) return oldValue;
                          final newText = NumberFormat('#,###', 'en_US').format(intValue);
                          return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
                        }),
                      ],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'VD: 50000',
                        suffixText: 'VND',
                        prefixIcon: const Icon(Icons.attach_money)
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedGroup == null) return;
                          final amount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                          if (amount > 0) {
                            setState(() {
                              _customPresets.add(QuickAddPreset(selectedGroup!.id, amount));
                            });
                            _saveCustomPresets();
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(s.get('save') ?? 'Lưu', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildDefaultButton(String title, String icon, double amount, String type, String prefKey, Color color, {String? originalName}) {
    return Container(
      width: 85,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _addQuickTransactionFromDefault(originalName ?? title, amount, type, icon),
        onLongPress: () => _editAmountDialog(title, amount, prefKey),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                Utils.currencyFormatShort(amount),
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomListItem(QuickAddPreset preset, int index) {
    final groupProxy = context.read<GroupModelProxy>();
    final group = groupProxy.getById(preset.groupId);
    if (group.id == 0 && preset.groupId != 0) {
      // Group not found, might have been deleted. Skip or show placeholder.
      return const SizedBox.shrink();
    }
    
    final color = _colorFromHex(group.color ?? '#FF0000');
    final iconData = IconData(int.parse(group.icon ?? '57234'), fontFamily: 'MaterialIcons');
    final title = Utils.translateGroupName(context, group.name);

    return Container(
      width: 85,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _addQuickTransaction(title, preset.amount, preset.groupId, group.type ?? 'expense'),
        onLongPress: () => _editAmountDialog(title, preset.amount, 'custom_$index', customIndex: index),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 28, color: color),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Utils.currencyFormatShort(preset.amount),
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddWidgetButton() {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[400]! : Theme.of(context).primaryColor;
    
    return Container(
      width: 85,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: _showAddPresetDialog,
        child: Container(
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: baseColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withOpacity(0.2),
                ),
                child: Icon(Icons.add, color: baseColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                s.get('add_widget') ?? 'Thêm',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: baseColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    final s = S.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.get('quick_add') ?? 'Thêm nhanh',
            style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10.0),
          SizedBox(
            height: 100, // Fixed height for horizontal list
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildDefaultButton(s.get('food') ?? 'Ăn uống', '🍜', _foodAmount, 'expense', 'qa_food', Colors.orange, originalName: 'Ăn uống'),
                _buildDefaultButton(s.get('coffee') ?? 'Cafe', '☕', _cafeAmount, 'expense', 'qa_cafe', Colors.brown, originalName: 'Cafe'),
                _buildDefaultButton(s.get('transport') ?? 'Đi lại', '🚗', _transportAmount, 'expense', 'qa_transport', Colors.blue, originalName: 'Đi lại'),
                for (var i = 0; i < _customPresets.length; i++)
                  _buildCustomListItem(_customPresets[i], i),
                _buildAddWidgetButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
