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

class LoanDetailScreen extends StatefulWidget {
  final LoanModel loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  late LoanModel _loan;
  List<LoanPayment> _payments = [];
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final provider = context.read<LoanProvider>();
    final payments = await provider.getPayments(_loan.id);
    setState(() {
      _payments = payments;
      _loadingPayments = false;
    });
  }

  void _refreshLoan() {
    final provider = context.read<LoanProvider>();
    final updated = provider.getById(_loan.id);
    if (updated != null) {
      setState(() {
        _loan = updated;
      });
    }
    _loadPayments();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'partial': return Colors.orange;
      default: return Colors.red;
    }
  }

  void _showAddPaymentDialog() {
    final s = S.of(context);
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    final wallets = context.read<WalletModelProxy>().getAll();
    WalletModel? selectedWallet = wallets.isNotEmpty ? wallets.first : null;
    // If loan has a walletId, pre-select that wallet
    if (_loan.walletId != null) {
      try {
        selectedWallet = context.read<WalletModelProxy>().getById(_loan.walletId!);
      } catch (e) {
        // fallback to first wallet
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(s.get('loan_add_payment') ?? 'Ghi nhận trả nợ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
                          double? val = double.tryParse(cleanText);
                          if (val != null) {
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
                          return newValue;
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: s.get('amount') ?? 'Số tiền',
                        hintText: s.get('enter_amount') ?? 'Nhập số tiền',
                        suffixText: 'VND',
                        helperText: '${s.get('loan_remaining') ?? 'Còn lại'}: ${Utils.currencyFormat(_loan.remainingAmount)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Wallet selector
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(s.get('select_wallet') ?? 'Chọn ví', style: TextStyle(color: Colors.grey[600])),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedWallet?.id,
                            items: wallets.map((w) {
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
                                setDialogState(() {
                                  selectedWallet = context.read<WalletModelProxy>().getById(value);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: Text(DateFormat('dd/MM/yyyy').format(paymentDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            paymentDate = picked;
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: s.get('note') ?? 'Ghi chú',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(s.get('cancel') ?? 'Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amountText = amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
                    final amount = double.tryParse(amountText) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.get('amount_greater_than_0') ?? 'Số tiền phải lớn hơn 0')),
                      );
                      return;
                    }

                    // Capture before async gap
                    final loanProvider = context.read<LoanProvider>();
                    final walletProxy = context.read<WalletModelProxy>();
                    final transactionProxy = context.read<TransactionModelProxy>();
                    final notificationProxy = context.read<AppNotificationProvider>();
                    final groupProxy = context.read<GroupModelProxy>();
                    final nav = Navigator.of(dialogContext);

                    final payment = LoanPayment(
                      id: const Uuid().v4(),
                      loanId: _loan.id,
                      amount: amount,
                      date: paymentDate.toString(),
                      note: noteController.text.trim(),
                      walletId: selectedWallet?.id,
                    );

                    await loanProvider.addPayment(payment);

                    final groups = groupProxy.getAll();
                    final targetType = _loan.type == 'borrow' ? 'expense' : 'income';
                    final targetName = _loan.type == 'borrow' ? (s.get('loan_repayment') ?? 'Trả nợ') : (s.get('loan_collection') ?? 'Thu nợ');
                    int defaultGroupId = 1;

                    try {
                      defaultGroupId = groups.firstWhere((g) => g.name == targetName && g.type == targetType).id;
                    } catch (e) {
                      final newGroup = GroupModel(
                        groupProxy.getId(),
                        groups.length + 1,
                        name: targetName,
                        type: targetType,
                        icon: _loan.type == 'borrow' ? Icons.outbox.codePoint.toString() : Icons.move_to_inbox.codePoint.toString(),
                        color: _loan.type == 'borrow' ? "#FF9800" : "#8BC34A",
                      );
                      await groupProxy.add(newGroup);
                      defaultGroupId = newGroup.id;
                    }

                    final transaction = TransactionModel(
                      const Uuid().v4(),
                      walletId: selectedWallet?.id ?? 0,
                      groupId: defaultGroupId,
                      title: _loan.type == 'borrow' ? (s.get('loan_repayment') ?? 'Trả nợ') : (s.get('loan_collection') ?? 'Thu nợ'),
                      amount: amount,
                      unit: 'VND',
                      type: targetType,
                      date: paymentDate.toString(),
                      note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : '${_loan.type == 'borrow' ? 'Trả nợ cho' : 'Thu nợ từ'} ${_loan.personName ?? ''}',
                      addToReport: true,
                    );
                    await transactionProxy.add(transaction);

                    String notifTitle = _loan.type == 'borrow' ? 'Đã trả nợ' : 'Đã thu nợ';
                    String notifBody = _loan.type == 'borrow'
                        ? 'Bạn đã trả ${Utils.currencyFormat(amount, withoutUnit: true)} cho ${_loan.personName ?? ''}'
                        : 'Bạn đã thu ${Utils.currencyFormat(amount, withoutUnit: true)} từ ${_loan.personName ?? ''}';

                    final notification = AppNotificationModel(
                      id: const Uuid().v4(),
                      title: notifTitle,
                      body: notifBody,
                      type: 'loan',
                      date: DateTime.now().toIso8601String(),
                      isRead: false,
                    );
                    await notificationProxy.addNotification(notification);

                    await NotificationHelper.instance.showInstantNotification(
                      id: notification.id.hashCode,
                      title: notifTitle,
                      body: notifBody,
                    );

                    // Update wallet balance
                    if (selectedWallet != null) {
                      final wallet = walletProxy.getById(selectedWallet!.id);
                      double newBalance;
                      if (_loan.type == 'borrow') {
                        // Trả nợ đi vay: tiền đi ra → trừ ví
                        newBalance = (wallet.balance ?? 0) - amount;
                      } else {
                        // Nhận trả cho vay: tiền vào → cộng ví
                        newBalance = (wallet.balance ?? 0) + amount;
                      }
                      await walletProxy.updateBalance(wallet, newBalance);
                    }

                    nav.pop();
                    _refreshLoan();
                  },
                  child: Text(s.get('save') ?? 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.get('confirm_delete') ?? 'Xác nhận xóa'),
        content: Text(s.get('confirm_delete_loan') ?? 'Bạn có chắc muốn xóa khoản vay này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.get('cancel') ?? 'Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<LoanProvider>().delete(_loan.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close detail screen
            },
            child: Text(s.get('delete') ?? 'Xóa', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Listen for changes to refresh the loan
    final provider = context.watch<LoanProvider>();
    final updatedLoan = provider.getById(_loan.id);
    if (updatedLoan != null) {
      _loan = updatedLoan;
    }

    final progress = (_loan.amount ?? 0) > 0
        ? ((_loan.paidAmount ?? 0) / (_loan.amount ?? 1)).clamp(0.0, 1.0)
        : 0.0;

    final bool isBorrow = _loan.type == 'borrow';
    final Color themeColor = isBorrow ? Colors.red : Colors.blue;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.get('loan_detail') ?? 'Chi tiết khoản vay',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(context, '/AddLoan', arguments: _loan);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isBorrow
                      ? [Colors.red.shade400, Colors.red.shade700]
                      : [Colors.blue.shade400, Colors.blue.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      isBorrow ? Icons.arrow_downward : Icons.arrow_upward,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loan.personName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBorrow
                        ? (s.get('loan_borrow') ?? 'Đi vay')
                        : (s.get('loan_lend') ?? 'Cho vay'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Utils.currencyFormat(_loan.amount ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${s.get('loan_paid_amount') ?? 'Đã trả'}: ${Utils.currencyFormat(_loan.paidAmount ?? 0)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '${s.get('loan_remaining') ?? 'Còn lại'}: ${Utils.currencyFormat(_loan.remainingAmount)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.calendar_today,
                    s.get('loan_date') ?? 'Ngày vay',
                    _loan.date != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_loan.date!))
                        : '-',
                  ),
                  const Divider(),
                  _buildInfoRow(
                    Icons.event,
                    s.get('loan_due_date') ?? 'Hạn trả',
                    _loan.dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_loan.dueDate!))
                        : (s.get('not_set') ?? 'Chưa đặt'),
                  ),
                  const Divider(),
                  _buildInfoRow(
                    Icons.phone,
                    s.get('phone_number') ?? 'Số điện thoại',
                    _loan.phoneNumber != null && _loan.phoneNumber!.isNotEmpty
                        ? _loan.phoneNumber!
                        : (s.get('not_set') ?? 'Chưa đặt'),
                  ),
                  const Divider(),
                  _buildInfoRow(
                    _loan.status == 'paid'
                        ? Icons.check_circle
                        : _loan.status == 'partial'
                            ? Icons.timelapse
                            : Icons.warning,
                    s.get('status') ?? 'Trạng thái',
                    _loan.statusDisplay,
                    valueColor: _getStatusColor(_loan.status),
                  ),
                  if (_loan.isOverdue && _loan.status != 'paid') ...[
                    const Divider(),
                    _buildInfoRow(
                      Icons.schedule,
                      s.get('loan_overdue') ?? 'Quá hạn',
                      '${DateTime.now().difference(DateTime.parse(_loan.dueDate!)).inDays} ${s.get('days') ?? 'ngày'}',
                      valueColor: Colors.red,
                    ),
                  ],
                  if (_loan.note != null && _loan.note!.isNotEmpty) ...[
                    const Divider(),
                    _buildInfoRow(
                      Icons.notes,
                      s.get('note') ?? 'Ghi chú',
                      _loan.note!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.get('loan_payment_history') ?? 'Lịch sử trả nợ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loan.status != 'paid')
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.get('loan_add_payment') ?? 'Ghi nhận trả'),
                    onPressed: _showAddPaymentDialog,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loadingPayments)
              const Center(child: CircularProgressIndicator())
            else if (_payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        s.get('no_payments') ?? 'Chưa có lịch sử trả nợ',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._payments.map((payment) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Dismissible(
                  key: Key(payment.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(s.get('confirm_delete') ?? 'Xác nhận xóa'),
                        content: Text(s.get('confirm_delete_payment') ?? 'Xóa lần trả này?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(s.get('cancel') ?? 'Hủy'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(s.get('delete') ?? 'Xóa',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    await context.read<LoanProvider>().deletePayment(payment);
                    _refreshLoan();
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: const Icon(Icons.payment, color: Colors.green),
                    ),
                    title: Text(
                      Utils.currencyFormat(payment.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(payment.date)),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: payment.note != null && payment.note!.isNotEmpty
                        ? Tooltip(
                            message: payment.note!,
                            child: const Icon(Icons.info_outline, size: 18),
                          )
                        : null,
                  ),
                ),
              )),
          ],
        ),
      ),
      // FAB for adding payment
      floatingActionButton: _loan.status != 'paid'
          ? FloatingActionButton.extended(
              onPressed: _showAddPaymentDialog,
              backgroundColor: themeColor,
              icon: const Icon(Icons.payment, color: Colors.white),
              label: Text(
                s.get('loan_add_payment') ?? 'Ghi nhận trả',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
