import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/model/LoanModel.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/notification_helper.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:onemorecoin/model/AppNotificationModel.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:onemorecoin/model/TransactionModel.dart';

class AddLoanScreen extends StatefulWidget {
  final String? defaultType;
  final LoanModel? editLoan;

  const AddLoanScreen({super.key, this.defaultType, this.editLoan});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _phoneController = TextEditingController();
  String _type = 'borrow';
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _isEdit = false;
  WalletModel? _selectedWallet;
  
  int _remindBeforeDays = 0;
  TimeOfDay _remindTime = const TimeOfDay(hour: 8, minute: 0);
  final List<int> _daysList = [0, 1, 2, 3, 7];

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType ?? 'borrow';

    // Initialize selected wallet
    final wallets = context.read<WalletModelProxy>().getAll();
    if (wallets.isNotEmpty) {
      _selectedWallet = wallets.first;
    }

    if (widget.editLoan != null) {
      _isEdit = true;
      final loan = widget.editLoan!;
      _personController.text = loan.personName ?? '';
      _amountController.text = Utils.currencyFormat(loan.amount ?? 0, withoutUnit: true);
      _noteController.text = loan.note ?? '';
      _phoneController.text = loan.phoneNumber ?? '';
      _type = loan.type ?? 'borrow';
      _date = DateTime.parse(loan.date ?? DateTime.now().toString());
      if (loan.dueDate != null) {
        _dueDate = DateTime.parse(loan.dueDate!);
      }
      if (loan.walletId != null && wallets.isNotEmpty) {
        try {
          _selectedWallet = context.read<WalletModelProxy>().getById(loan.walletId!);
        } catch (e) {
          _selectedWallet = wallets.first;
        }
      }
      
      _remindBeforeDays = loan.remindBeforeDays ?? 0;
      if (loan.remindTime != null) {
        final parts = loan.remindTime!.split(':');
        if (parts.length == 2) {
          _remindTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? DateTime.now().add(const Duration(days: 30))) : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final s = S.of(context);
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = double.tryParse(amountText) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.get('amount_greater_than_0') ?? 'Số tiền phải lớn hơn 0')),
      );
      return;
    }

    // Capture references before async gap
    final provider = context.read<LoanProvider>();
    final walletProxy = context.read<WalletModelProxy>();
    final transactionProxy = context.read<TransactionModelProxy>();
    final notificationProxy = context.read<AppNotificationProvider>();
    final groupProxy = context.read<GroupModelProxy>();
    final navigator = Navigator.of(context);

    LoanModel currentLoan;
    if (_isEdit) {
      currentLoan = widget.editLoan!;
      currentLoan.personName = _personController.text.trim();
      currentLoan.amount = amount;
      currentLoan.type = _type;
      currentLoan.date = _date.toString();
      currentLoan.dueDate = _dueDate?.toString();
      currentLoan.note = _noteController.text.trim();
      currentLoan.walletId = _selectedWallet?.id;
      currentLoan.phoneNumber = _phoneController.text.trim();
      currentLoan.remindBeforeDays = _remindBeforeDays;
      currentLoan.remindTime = '${_remindTime.hour.toString().padLeft(2, '0')}:${_remindTime.minute.toString().padLeft(2, '0')}';
      await provider.update(currentLoan);
    } else {
      currentLoan = LoanModel(
        const Uuid().v4(),
        personName: _personController.text.trim(),
        amount: amount,
        type: _type,
        date: _date.toString(),
        dueDate: _dueDate?.toString(),
        note: _noteController.text.trim(),
        status: 'unpaid',
        walletId: _selectedWallet?.id,
        phoneNumber: _phoneController.text.trim(),
        remindBeforeDays: _remindBeforeDays,
        remindTime: '${_remindTime.hour.toString().padLeft(2, '0')}:${_remindTime.minute.toString().padLeft(2, '0')}',
      );
      await provider.add(currentLoan);

      final groups = groupProxy.getAll();
      final targetType = _type == 'borrow' ? 'income' : 'expense';
      final targetName = _type == 'borrow' ? (s.get('loan_borrow') ?? 'Đi vay') : (s.get('loan_lend') ?? 'Cho vay');
      int defaultGroupId = 1;

      try {
        defaultGroupId = groups.firstWhere((g) => g.name == targetName && g.type == targetType).id;
      } catch (e) {
        final newGroup = GroupModel(
          groupProxy.getId(),
          groups.length + 1,
          name: targetName,
          type: targetType,
          icon: Icons.account_balance.codePoint.toString(),
          color: _type == 'borrow' ? "#4CAF50" : "#F44336",
        );
        await groupProxy.add(newGroup);
        defaultGroupId = newGroup.id;
      }

      final transaction = TransactionModel(
        const Uuid().v4(),
        walletId: _selectedWallet?.id ?? 0,
        groupId: defaultGroupId,
        title: _type == 'borrow' ? (s.get('loan_borrow') ?? 'Đi vay') : (s.get('loan_lend') ?? 'Cho vay'),
        amount: amount,
        unit: 'VND',
        type: targetType,
        date: _date.toString(),
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : '${_type == 'borrow' ? 'Vay từ' : 'Cho'} ${_personController.text.trim()}',
        addToReport: true,
      );
      await transactionProxy.add(transaction);

      String notifTitle = _type == 'borrow' ? 'Đã tạo khoản vay' : 'Đã tạo khoản cho vay';
      String notifBody = _type == 'borrow'
          ? 'Bạn đã vay ${Utils.currencyFormat(amount, withoutUnit: true)} từ ${_personController.text.trim()}'
          : 'Bạn đã cho ${_personController.text.trim()} vay ${Utils.currencyFormat(amount, withoutUnit: true)}';

      final notification = AppNotificationModel(
        id: const Uuid().v4(),
        title: notifTitle,
        body: notifBody,
        type: 'loan',
        date: DateTime.now().toIso8601String(),
        isRead: false,
      );
      await notificationProxy.addNotification(notification);

      String translatedNotifTitle = _type == 'borrow' ? (s.get('loan_created_borrow') ?? 'Đã tạo khoản vay') : (s.get('loan_created_lend') ?? 'Đã tạo khoản cho vay');
      String translatedNotifBody = _type == 'borrow'
          ? (s.get('loan_created_borrow_body') ?? 'Bạn đã vay {0} từ {1}')
              .replaceAll('{0}', Utils.currencyFormat(amount, withoutUnit: true))
              .replaceAll('{1}', _personController.text.trim())
          : (s.get('loan_created_lend_body') ?? 'Bạn đã cho {0} vay {1}')
              .replaceAll('{0}', _personController.text.trim())
              .replaceAll('{1}', Utils.currencyFormat(amount, withoutUnit: true));

      await NotificationHelper.instance.showInstantNotification(
        id: notification.id.hashCode,
        title: translatedNotifTitle,
        body: translatedNotifBody,
      );

      // Update wallet balance
      if (_selectedWallet != null) {
        final wallet = walletProxy.getById(_selectedWallet!.id);
        double newBalance;
        if (_type == 'lend') {
          // Cho vay: tiền đi ra → trừ ví
          newBalance = (wallet.balance ?? 0) - amount;
        } else {
          // Đi vay: tiền vào → cộng ví
          newBalance = (wallet.balance ?? 0) + amount;
        }
        await walletProxy.updateBalance(wallet, newBalance);
      }
    }

    // Schedule notification
    if (currentLoan.dueDate != null && currentLoan.status != 'paid') {
      final dueDateParsed = DateTime.parse(currentLoan.dueDate!);
      final reminderDate = dueDateParsed.subtract(Duration(days: currentLoan.remindBeforeDays ?? 0));
      final parts = (currentLoan.remindTime ?? '08:00').split(':');
      final scheduleDate = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        int.tryParse(parts[0]) ?? 8,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );

      if (scheduleDate.isAfter(DateTime.now())) {
        String title = _type == 'borrow' 
            ? (s.get('debt_due_title') ?? 'Khoản nợ đến hạn') 
            : (s.get('loan_due_title') ?? 'Khoản cho vay đến hạn');
        
        String bodyTemplate = _type == 'borrow'
            ? (s.get('debt_payment_body') ?? 'Bạn cần trả {0} cho {1}')
            : (s.get('loan_collection_body') ?? 'Đến hạn thu {0} từ {1}');
            
        String body = bodyTemplate
            .replaceAll('{0}', Utils.currencyFormat(amount, withoutUnit: true))
            .replaceAll('{1}', _personController.text.trim());
        
        await NotificationHelper.instance.scheduleReminderNotification(
          id: currentLoan.id.hashCode,
          title: title,
          body: body,
          scheduledDate: scheduleDate,
        );
      } else {
        await NotificationHelper.instance.cancelNotification(currentLoan.id.hashCode);
      }
    } else {
      await NotificationHelper.instance.cancelNotification(currentLoan.id.hashCode);
    }

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);


    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            _isEdit
                ? (s.get('edit_loan') ?? 'Sửa khoản vay')
                : (s.get('add_loan') ?? 'Thêm khoản vay'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: Text(
                s.get('save') ?? 'Lưu',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Type selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = 'borrow'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == 'borrow' ? Colors.red.shade50 : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _type == 'borrow'
                                  ? Border.all(color: Colors.red.shade200, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward,
                                    color: _type == 'borrow' ? Colors.red : Colors.grey, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  s.get('loan_borrow') ?? 'Đi vay',
                                  style: TextStyle(
                                    color: _type == 'borrow' ? Colors.red : Colors.grey,
                                    fontWeight: _type == 'borrow' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = 'lend'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == 'lend' ? Colors.blue.shade50 : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _type == 'lend'
                                  ? Border.all(color: Colors.blue.shade200, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward,
                                    color: _type == 'lend' ? Colors.blue : Colors.grey, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  s.get('loan_lend') ?? 'Cho vay',
                                  style: TextStyle(
                                    color: _type == 'lend' ? Colors.blue : Colors.grey,
                                    fontWeight: _type == 'lend' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Person name
                TextFormField(
                  controller: _personController,
                  decoration: InputDecoration(
                    labelText: _type == 'borrow'
                        ? (s.get('loan_creditor') ?? 'Người cho vay')
                        : (s.get('loan_borrower') ?? 'Người vay'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.get('please_enter_person') ?? 'Vui lòng nhập tên người';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: s.get('phone_number') ?? 'Số điện thoại',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
                      if (cleanText.indexOf('.') != cleanText.lastIndexOf('.')) {
                        return oldValue;
                      }
                      double? val = double.tryParse(cleanText);
                      if (val != null && !cleanText.endsWith('.')) {
                        String formatted = NumberFormat.currency(
                          customPattern: '###,###',
                          symbol: "",
                          decimalDigits: 0,
                        ).format(val);
                        return newValue.copyWith(
                          text: formatted.trim(),
                          selection: TextSelection.collapsed(offset: formatted.trim().length),
                        );
                      }
                      return newValue.copyWith(text: cleanText);
                    }),
                  ],
                  decoration: InputDecoration(
                    labelText: s.get('amount') ?? 'Số tiền',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'VND',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.get('please_enter_amount') ?? 'Vui lòng nhập số tiền';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  tileColor: Theme.of(context).cardColor,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(s.get('loan_date') ?? 'Ngày vay'),
                  trailing: Text(
                    DateFormat('dd/MM/yyyy').format(_date),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => _selectDate(context, false),
                ),
                const SizedBox(height: 12),

                // Due date
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  tileColor: Theme.of(context).cardColor,
                  leading: const Icon(Icons.event),
                  title: Text(s.get('loan_due_date') ?? 'Hạn trả'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dueDate != null
                            ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                            : (s.get('not_set') ?? 'Chưa đặt'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _dueDate != null ? null : Colors.grey,
                        ),
                      ),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                  onTap: () => _selectDate(context, true),
                ),
                const SizedBox(height: 12),
                
                if (_dueDate != null) ...[
                  // Remind before days
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    tileColor: Theme.of(context).cardColor,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(s.get('remind_before_days') ?? 'Nhắc trước (ngày)'),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _remindBeforeDays,
                        items: _daysList.map((d) {
                          return DropdownMenuItem<int>(
                            value: d,
                            child: Text(
                              '$d ${s.get('x_days') ?? 'ngày'}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _remindBeforeDays = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Notification Time
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    tileColor: Theme.of(context).cardColor,
                    leading: const Icon(Icons.access_time),
                    title: Text(s.get('notification_time') ?? 'Thời gian nhắc'),
                    trailing: Text(
                      _remindTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _remindTime,
                      );
                      if (picked != null) {
                        setState(() => _remindTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Wallet selector
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  tileColor: Theme.of(context).cardColor,
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(s.get('select_wallet') ?? 'Chọn ví'),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedWallet?.id,
                      items: context.watch<WalletModelProxy>().getAll().map((w) {
                        return DropdownMenuItem<int>(
                          value: w.id,
                          child: Text(
                            w.name ?? 'Ví',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedWallet = context.read<WalletModelProxy>().getById(value);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s.get('note') ?? 'Ghi chú',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
