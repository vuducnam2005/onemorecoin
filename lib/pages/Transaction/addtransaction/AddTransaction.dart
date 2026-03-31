import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/commons/Constants.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/widgets/AlertDiaLog.dart';
import 'package:onemorecoin/widgets/ShowSwitch.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/Utils.dart' show Utils;

import '../../../Objects/AlertDiaLogItem.dart';
import '../../../model/TransactionModel.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import 'package:intl/intl.dart';
import 'ReceiptScanScreen.dart';

class AddTransaction extends StatefulWidget {
  final TransactionModel? transactionModel;
  const AddTransaction({super.key, this.transactionModel});

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  final amountField = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _amount = 0;
  String _currency = "VND";
  late final FocusNode _amountFocusNode = FocusNode();
  String _noteValue = '';
  bool _isCleanAmount = false;
  late GroupModel _selectedGroup;
  DateTime _dateTime = DateTime.now();

  DateTime _notificationDateTime = DateTime.now();
  bool _isNotification = false;
  // Initialize to a dummy wallet initially, will be overridden in initState
  late WalletModel _selectedWallet;
  bool _isShowFull = false;
  bool _isAddToReport = false;
  bool _isEdit = false;
  bool _isSubmitEdit = false;
  bool _loading = false;

  // Predefined quick chips using Material Icons and solid colors
  final List<Map<String, dynamic>> _quickCategories = [
    {'label': 'Ăn uống', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'label': 'Di chuyển', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'label': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.purple},
    {'label': 'Bills', 'icon': Icons.receipt_long, 'color': Colors.green},
    {'label': 'Giải trí', 'icon': Icons.movie, 'color': Colors.indigo},
  ];

  final List<String> _quickNotes = ['Ăn sáng', 'Tiền taxi', 'Cafe', 'Đổ xăng', 'Mua đồ'];

  void isShowFull() {
    setState(() {
      _isShowFull = true;
    });
  }

  void _moveToListGroupPage(BuildContext context) async {
    final s = S.of(context);
    dynamic result = await Navigator.of(context).pushNamed("/ListGroupPage", arguments: {
      'title': s.get('select_group') ?? "Chọn nhóm",
    });

    if (result != null) {
      setState(() {
        _selectedGroup = result['item'];
      });
    }
  }

  void _moveToAddNotePage(BuildContext context) async {
    dynamic result = await Navigator.of(context).pushNamed("/AddNotePage", arguments: {
      'note': _noteValue,
      'groupId': _selectedGroup.id,
    });

    if (result != null) {
      if (_amount == 0 && result['amount'] != null) {
        _amount = result['amount'];
        amountField.text = Utils.currencyFormat(_amount, withoutUnit: true);
      }
      if (_selectedGroup.id == 0 && result['groupModel'] != null) {
        _selectedGroup = result['groupModel'];
      }
      setState(() {
        _noteValue = result['note'];
      });
    }
  }

  List<AlertDiaLogItem> _getListAlertDialogSelectDate(BuildContext context) {
    final s = S.of(context);
    return [
      AlertDiaLogItem(
          text: s.get('today') ?? "Hôm nay",
          okOnPressed: () async {
            setState(() {
              _dateTime = DateTime.now();
            });
          }),
      AlertDiaLogItem(
          text: s.get('yesterday') ?? "Hôm qua",
          okOnPressed: () async {
            setState(() {
              _dateTime = DateTime.now().subtract(const Duration(days: 1));
            });
          }),
      AlertDiaLogItem(
          text: s.get('custom') ?? "Tuỳ chọn",
          okOnPressed: () async {
            _moveToDateSelectPage(context);
          }),
    ];
  }

  void _moveToDateSelectPage(BuildContext context) async {
    dynamic result = await Navigator.of(context).pushNamed("/DateSelectPage", arguments: {
      'selectDate': _dateTime,
    });
    if (result != null) {
      setState(() {
        _dateTime = result['selectDate'];
      });
    }
  }

  void _moveToListWalletPage(BuildContext context) async {
    dynamic result = await Navigator.of(context).pushNamed("/ListWalletPage", arguments: {
      'wallet': _selectedWallet,
    });
    if (result != null) {
      setState(() {
        _selectedWallet = result['wallet'];
        _currency = _selectedWallet.currency!;
      });
    }
  }

  void _moveToAddNotificationPage(BuildContext context) async {
    dynamic result = await Navigator.of(context).pushNamed("/AddNotificationPage", arguments: {
      'selectDate': _notificationDateTime,
      'isNotification': _isNotification,
      'submitOnPressed': (value) {
        setState(() {
          _notificationDateTime = value['dateTime'];
          _isNotification = value['isNotification'];
        });
      }
    });

    if (result != null) {
      // It returns wallet, but we only really care about notify date changes
      setState(() {
        if(result['wallet'] != null) {
          _selectedWallet = result['wallet'];
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final wallets = context.read<WalletModelProxy>().getAll();
    if (wallets.isNotEmpty) {
      _selectedWallet = wallets.first;
    } else {
      _selectedWallet = WalletModel(0, name: "Cash", balance: 0); // Failsafe
    }
    
    if (widget.transactionModel != null) {
      _isEdit = true;
      _isShowFull = true;
      amountField.text = Utils.currencyFormat(widget.transactionModel!.amount!, withoutUnit: true);
      _amount = widget.transactionModel!.amount!;
      _noteValue = widget.transactionModel!.note ?? "";
      _selectedGroup = widget.transactionModel!.group!;
      _dateTime = DateTime.parse(widget.transactionModel!.date!);
      _selectedWallet = context.read<WalletModelProxy>().getById(widget.transactionModel!.walletId!);
      _currency = CurrencyProvider.currentCurrency;
      _isNotification = widget.transactionModel!.notifyDate != null;
      if (_isNotification) {
        _notificationDateTime = DateTime.parse(widget.transactionModel!.notifyDate!);
      }
      _isAddToReport = widget.transactionModel!.addToReport!;
    } else {
      amountField.text = '0';
      _selectedGroup = GroupModel(0, 0, name: null, icon: null, type: "expense");
      _currency = CurrencyProvider.currentCurrency;
    }
    amountField.addListener(() {
      setState(() {
        double parsedAmount = amountField.text.isEmpty ? 0 : Utils.unCurrencyFormat(amountField.text);
        _amount = _currency == 'USD' ? parsedAmount * 26294.0 : parsedAmount;
        _isCleanAmount = amountField.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    amountField.dispose();
    super.dispose();
  }

  void _checkSubmitEdit() {
    if (_isEdit) {
      if ((_amount - widget.transactionModel!.amount!).abs() > 0.01) {
        _isSubmitEdit = true;
        return;
      }
      if (_selectedGroup.id != widget.transactionModel!.groupId) {
        _isSubmitEdit = true;
        return;
      }
      if (_selectedWallet.id != widget.transactionModel!.walletId) {
        _isSubmitEdit = true;
        return;
      }
      if (_dateTime.toString() != widget.transactionModel!.date) {
        _isSubmitEdit = true;
        return;
      }
      if (_noteValue != widget.transactionModel!.note) {
        _isSubmitEdit = true;
        return;
      }
      if (_isNotification != (widget.transactionModel!.notifyDate != null)) {
        _isSubmitEdit = true;
        return;
      }
      if (_isNotification && _notificationDateTime.toString() != widget.transactionModel!.notifyDate) {
        _isSubmitEdit = true;
        return;
      }
      if (_isAddToReport != widget.transactionModel!.addToReport) {
        _isSubmitEdit = true;
        return;
      }
      _isSubmitEdit = false;
    }
  }

  _addTransaction(BuildContext context) async {
    final s = S.of(context);
    if (_formKey.currentState!.validate() && !_isEdit) {
      if (_selectedGroup.id == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('please_select_group') ?? "Vui lòng chọn nhóm")));
        return;
      }
      if (_selectedWallet.id == 0 && context.read<WalletModelProxy>().getAll().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('please_select_wallet') ?? "Vui lòng chọn ví")));
        return;
      }

      var transactions = context.read<TransactionModelProxy>();
      await transactions.add(TransactionModel(
        const Uuid().v4(),
        walletId: _selectedWallet.id,
        groupId: _selectedGroup.id,
        title: _selectedGroup.name ?? "title",
        amount: _amount,
        unit: _currency,
        type: _selectedGroup.type ?? "expense",
        date: _dateTime.toString(),
        note: _noteValue,
        addToReport: _isAddToReport,
        notifyDate: _isNotification ? _notificationDateTime.toString() : null,
      ));

      var wallets = context.read<WalletModelProxy>().getById(_selectedWallet.id);
      double balance = _selectedGroup.type == "expense" ? (wallets.balance ?? 0) - _amount : (wallets.balance ?? 0) + _amount;
      await context.read<WalletModelProxy>().updateBalance(wallets, balance);
      Navigator.of(context, rootNavigator: true).pop(context);
    }
  }

  _updateTransaction(BuildContext context) async {
    final s = S.of(context);
    if (_formKey.currentState!.validate() && _isSubmitEdit && _isEdit) {
      if (_selectedGroup.id == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('please_select_group') ?? "Vui lòng chọn nhóm")));
        return;
      }
      var transactions = context.read<TransactionModelProxy>();
      var originalTransaction = transactions.getById(widget.transactionModel!.id);
      var oldWallet = context.read<WalletModelProxy>().getById(originalTransaction.walletId);
      
      double revertedOldBalance = (originalTransaction.type == "expense")
          ? (oldWallet.balance ?? 0) + originalTransaction.amount!
          : (oldWallet.balance ?? 0) - originalTransaction.amount!;
      
      if (_selectedWallet.id != originalTransaction.walletId) {
        await context.read<WalletModelProxy>().updateBalance(oldWallet, revertedOldBalance);
        var newWallet = context.read<WalletModelProxy>().getById(_selectedWallet.id);
        double newBalance = (_selectedGroup.type == "expense") 
            ? (newWallet.balance ?? 0) - _amount 
            : (newWallet.balance ?? 0) + _amount;
        await context.read<WalletModelProxy>().updateBalance(newWallet, newBalance);
      } else {
        double newBalance = (_selectedGroup.type == "expense")
            ? revertedOldBalance - _amount
            : revertedOldBalance + _amount;
        await context.read<WalletModelProxy>().updateBalance(oldWallet, newBalance);
      }

      transactions.update(TransactionModel(
        widget.transactionModel!.id,
        walletId: _selectedWallet.id,
        groupId: _selectedGroup.id,
        title: "title",
        amount: _amount,
        unit: _currency,
        type: _selectedGroup.type ?? "expense",
        date: _dateTime.toString(),
        note: _noteValue,
        addToReport: _isAddToReport,
        notifyDate: _isNotification ? _notificationDateTime.toString() : null,
      ));

      Navigator.of(context, rootNavigator: true).pop(context);
    }
  }

  void _handleQuickCategory(String label) {
    // Try to find an existing group that matches
    final allGroups = context.read<GroupModelProxy>().getAll();
    GroupModel? matchedGroup;
    
    for (var group in allGroups) {
      if (group.name?.toLowerCase().contains(label.toLowerCase()) ?? false) {
        matchedGroup = group;
        break;
      }
    }
    
    if (matchedGroup != null) {
      setState(() => _selectedGroup = matchedGroup!);
    } else {
      // If not found, open the selection page so they can map or create it
      _moveToListGroupPage(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Set default empty category group with a pleasant fallback icon
    if (!_isEdit && _selectedGroup.id == 0) {
      _selectedGroup = GroupModel(0, 0, name: s.get('select_group') ?? "Chọn nhóm", icon: null, type: "expense");
    }
    
    _checkSubmitEdit();

    // Theming Colors
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final hintColor = isDark ? Colors.grey[500]! : Colors.grey[400]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final accentColor = const Color(0xFF1976D2); // Brand Blue

    // Setup input formatter logic extracted from the original code
    final amountInputFormatters = [
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (newValue.text.isEmpty) {
          return newValue.copyWith(text: "0", selection: const TextSelection.collapsed(offset: 1));
        }
        String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
        if (cleanText.indexOf('.') != cleanText.lastIndexOf('.')) return oldValue;
        if (cleanText.startsWith('.')) cleanText = '0$cleanText';
        if (cleanText.endsWith('.') || cleanText.contains('.0')) {
            return newValue.copyWith(text: cleanText, selection: TextSelection.collapsed(offset: cleanText.length));
        }
        double? val = double.tryParse(cleanText);
        if (val != null) {
          String formatted;
          if (cleanText.contains('.')) {
            List<String> parts = cleanText.split('.');
            String wholePart = parts[0];
            String decimalPart = parts.length > 1 ? parts[1] : '';
            if (decimalPart.length > 2) decimalPart = decimalPart.substring(0, 2);
            double wholeVal = double.tryParse(wholePart) ?? 0;
            String formattedWhole = NumberFormat.currency(customPattern: '###,###', symbol: "", decimalDigits: 0).format(wholeVal);
            formatted = '$formattedWhole.$decimalPart';
          } else {
            formatted = NumberFormat.currency(customPattern: '###,###', symbol: "", decimalDigits: 0).format(val);
          }
          return newValue.copyWith(text: formatted.trim(), selection: TextSelection.collapsed(offset: formatted.trim().length));
        }
        return newValue;
      })
    ];

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leadingWidth: 80,
          title: Text(!_isEdit ? (s.get('add_transaction') ?? 'Thêm giao dịch') : (s.get('edit_transaction') ?? 'Sửa giao dịch'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          leading: TextButton(
            child: Text(s.get('cancel') ?? 'Hủy', style: const TextStyle(fontSize: 16.0)),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(context),
          ),
          actions: [
            if (!_isEdit)
              IconButton(
                tooltip: s.get('scan_receipt') ?? 'Quét hóa đơn',
                icon: const Icon(Icons.document_scanner_outlined, color: Colors.orange),
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptScanScreen()));
                  if (result != null && result is Map) {
                    setState(() {
                      if (result['amount'] != null && result['amount'] > 0) {
                        _amount = (result['amount'] as double);
                        amountField.text = Utils.currencyFormat(_amount, withoutUnit: true);
                      }
                      _noteValue = 'Hóa đơn'; // Default note from OCR
                      
                      // Find or set "Hóa đơn" category
                      final groups = context.read<GroupModelProxy>().getAll();
                      bool foundCategory = false;
                      for (var g in groups) {
                        if (g.name?.toLowerCase().contains('hóa đơn') == true || g.name?.toLowerCase().contains('bill') == true) {
                          _selectedGroup = g;
                          foundCategory = true;
                          break;
                        }
                      }
                      if (!foundCategory && groups.isNotEmpty) {
                        // Fallback to first expense group if bill not found
                        try {
                           _selectedGroup = groups.firstWhere((g) => g.type == 'expense');
                        } catch(e) {}
                      }
                    });
                  }
                },
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Card 1: Amount & Category
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                        border: isDark ? Border.all(color: Colors.grey[800]!) : null,
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount Input Header
                          Text(s.get('amount') ?? "Số tiền", style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          
                          // Amount Input Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: amountField,
                                  focusNode: _amountFocusNode,
                                  maxLength: Constants.MAX_LENGTH_AMOUNT_INPUT,
                                  inputFormatters: amountInputFormatters,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(fontSize: 34.0, fontWeight: FontWeight.bold, color: textColor),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                                    suffixIcon: _isCleanAmount ? IconButton(
                                      icon: Icon(Icons.cancel, color: hintColor, size: 20),
                                      onPressed: () => amountField.clear(),
                                      padding: EdgeInsets.zero,
                                    ) : null,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return s.get('please_enter_amount') ?? 'Vui lòng nhập số tiền';
                                    double? val = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
                                    if (val == null || val <= 0) return s.get('amount_greater_than_0') ?? 'Số tiền phải > 0';
                                    return null;
                                  },
                                ),
                              ),
                              // Currency Selector Toggle
                              GestureDetector(
                                onTap: () async {
                                  dynamic result = await Navigator.of(context).pushNamed("/ListCurrencyPage");
                                  if (result != null) {
                                    setState(() {
                                      _currency = result['currency'];
                                      double parsedAmount = amountField.text.isEmpty ? 0 : Utils.unCurrencyFormat(amountField.text);
                                      _amount = _currency == 'USD' ? parsedAmount * 26294.0 : parsedAmount;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(_currency, style: TextStyle(fontWeight: FontWeight.w600, color: labelColor)),
                                ),
                              ),
                            ],
                          ),
                          
                          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 24),
                          
                          // Category Select
                          InkWell(
                            onTap: () => _moveToListGroupPage(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Category Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _selectedGroup.id == 0 
                                          ? (isDark ? Colors.grey[800] : Colors.blue[50]) // Colorful fallback
                                          : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: CustomIcon(
                                        iconPath: _selectedGroup.icon, 
                                        size: 32, 
                                        color: _selectedGroup.id == 0 ? Colors.orange : null
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _selectedGroup.id == 0 ? (s.get('select_group') ?? 'Chọn nhóm') : Utils.translateGroupName(context, _selectedGroup.name),
                                      style: TextStyle(fontSize: 18, color: _selectedGroup.id == 0 ? hintColor : textColor, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: hintColor),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          // Quick Category Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                                children: _quickCategories.map((cat) {
                                  final Color chipColor = (cat['color'] as Color?) ?? Colors.blue;
                                  return Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                                  child: ActionChip(
                                    backgroundColor: isDark ? chipColor.withOpacity(0.2) : chipColor.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12), 
                                      side: BorderSide(color: isDark ? chipColor.withOpacity(0.3) : chipColor.withOpacity(0.2))
                                    ),
                                    avatar: Icon(cat['icon'], size: 16, color: chipColor),
                                    label: Text(
                                      cat['label'], 
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isDark ? Colors.white : chipColor.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => _handleQuickCategory(cat['label']),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 2: Details
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                        border: isDark ? Border.all(color: Colors.grey[800]!) : null,
                      ),
                      child: Column(
                        children: [
                          // Note field
                          InkWell(
                            onTap: () => _moveToAddNotePage(context),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notes_rounded, color: iconColor),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          _noteValue.isNotEmpty ? _noteValue : (s.get('note') ?? "Ghi chú"),
                                          style: TextStyle(fontSize: 16, color: _noteValue.isEmpty ? hintColor : textColor),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: hintColor),
                                    ],
                                  ),
                                  // Note Quick Tags
                                  if (_noteValue.isEmpty) ...[
                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _quickNotes.map((tag) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6.0, left: 44.0),
                                            child: ActionChip(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                              backgroundColor: isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue.shade50,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8), 
                                                side: BorderSide(color: isDark ? Colors.blueAccent.withOpacity(0.3) : Colors.blue.shade100)
                                              ),
                                              label: Text(
                                                tag, 
                                                style: TextStyle(
                                                  fontSize: 12, 
                                                  color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700,
                                                  fontWeight: FontWeight.w500,
                                                )
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _noteValue = _noteValue.isEmpty ? tag : '$_noteValue, $tag';
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ),
                          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1, indent: 56),

                          // Date Field
                          InkWell(
                            onTap: () => showAlertDialog(context: context, optionItems: _getListAlertDialogSelectDate(context)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, color: isDark ? Colors.purple.shade300 : Colors.purple),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      Utils.getStringFormatDayOfWeek(_dateTime, context: context),
                                      style: TextStyle(fontSize: 16, color: textColor),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: hintColor),
                                ],
                              ),
                            ),
                          ),
                          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1, indent: 56),

                          // Wallet Field
                          InkWell(
                            onTap: () => _moveToListWalletPage(context),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_rounded, color: isDark ? Colors.teal.shade300 : Colors.teal),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      Utils.translateWalletName(context, _selectedWallet.name ?? 'Cash'),
                                      style: TextStyle(fontSize: 16, color: textColor),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: hintColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add Details Toggle
                    if (!_isShowFull)
                      OutlinedButton.icon(
                        onPressed: isShowFull,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(s.get('add_details') ?? "Thêm chi tiết"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      )
                    else 
                      // Extra Details Card
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark ? [] : [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                          border: isDark ? Border.all(color: Colors.grey[800]!) : null,
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => _moveToAddNotificationPage(context),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.alarm_rounded, color: iconColor),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _isNotification ? Utils.getStringFormatDateAndTime(_notificationDateTime) : (s.get('set_reminder') ?? "Đặt nhắc nhở"),
                                        style: TextStyle(fontSize: 16, color: textColor),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: hintColor),
                                  ],
                                ),
                              ),
                            ),
                            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1, indent: 56),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.notes, color: isDark ? Colors.orange.shade300 : Colors.orange),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(s.get('exclude_from_report') ?? "Không tính vào báo cáo", style: TextStyle(fontSize: 16, color: textColor)),
                                  ),
                                  showSwitch(
                                    value: _isAddToReport,
                                    onChanged: (value) => setState(() => _isAddToReport = value),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    const SizedBox(height: 100), // padding for bottom bar
                  ],
                ),
              ),
              
              // Bottom Action Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(color: (isDark ? Colors.black : Colors.grey).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4))
                  ]
                ),
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 12, 
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 32
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.get('scan_receipt_tip') ?? "Tip: Nhấn quét hóa đơn để nhập liệu nhanh",
                      style: TextStyle(color: labelColor, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withBlue(255)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            context.loaderOverlay.show();
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (!_isEdit) {
                              await _addTransaction(context);
                            } else {
                              await _updateTransaction(context);
                            }
                            try { context.loaderOverlay.hide(); } catch (_) {}
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _loading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(!_isEdit ? (s.get('create_transaction') ?? 'Tạo giao dịch') : (s.get('save') ?? 'Lưu'), 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    if (!_isEdit) const SizedBox(width: 8),
                                    if (!_isEdit) const Icon(Icons.auto_awesome_rounded, size: 18),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
