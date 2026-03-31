import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../model/ReminderModel.dart';
import '../../utils/notification_helper.dart';
import '../../utils/app_localizations.dart';
import '../../utils/currency_provider.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  const AddReminderScreen({super.key, this.reminder});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedType = 'Điện';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  int _remindBeforeDays = 1;
  TimeOfDay _remindTime = const TimeOfDay(hour: 8, minute: 0);

  final List<String> _types = ['Điện', 'Nước', 'Internet', 'Tiền nhà', 'Khác'];
  final List<int> _daysList = [0, 1, 2, 3, 5, 7];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;

      // Format initial amount
      final formatter = NumberFormat('#,###');
      _amountController.text = formatter.format(widget.reminder!.amount);

      _noteController.text = widget.reminder!.note;
      if (_types.contains(widget.reminder!.type)) {
        _selectedType = widget.reminder!.type;
      }
      try {
        _dueDate = DateTime.parse(widget.reminder!.dueDate);
      } catch (_) {}
      if (_daysList.contains(widget.reminder!.remindBeforeDays)) {
        _remindBeforeDays = widget.reminder!.remindBeforeDays;
      }
      try {
        final timeParts = widget.reminder!.remindTime.split(':');
        _remindTime = TimeOfDay(
            hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveReminder() async {
    if (_formKey.currentState!.validate()) {
      final textAmount = _amountController.text.replaceAll(',', '');
      final amount = double.tryParse(textAmount) ?? 0.0;
      final isNew = widget.reminder == null;
      final id = isNew ? const Uuid().v4() : widget.reminder!.id;

      final reminder = Reminder(
        id: id,
        title: _titleController.text,
        amount: amount,
        type: _selectedType,
        dueDate: _dueDate.toIso8601String(),
        remindBeforeDays: _remindBeforeDays,
        remindTime:
            '${_remindTime.hour.toString().padLeft(2, '0')}:${_remindTime.minute.toString().padLeft(2, '0')}',
        isPaid: widget.reminder?.isPaid ?? 0,
        note: _noteController.text,
      );

      final provider = context.read<ReminderProvider>();
      if (isNew) {
        await provider.addReminder(reminder);
      } else {
        await provider.updateReminder(reminder);
      }

      var notifyDate = _dueDate.subtract(Duration(days: _remindBeforeDays));
      notifyDate = DateTime(notifyDate.year, notifyDate.month, notifyDate.day,
          _remindTime.hour, _remindTime.minute);

      if (notifyDate.isAfter(DateTime.now()) && reminder.isPaid == 0) {
        final s = S.of(context);
        String displayType = _selectedType;
        switch (_selectedType) {
          case 'Điện':
            displayType = s.get('type_electricity') ?? 'Điện';
            break;
          case 'Nước':
            displayType = s.get('type_water') ?? 'Nước';
            break;
          case 'Internet':
            displayType = s.get('type_internet') ?? 'Internet';
            break;
          case 'Tiền nhà':
            displayType = s.get('type_rent') ?? 'Tiền nhà';
            break;
          case 'Khác':
            displayType = s.get('type_other') ?? 'Khác';
            break;
        }

        await NotificationHelper.instance.scheduleReminderNotification(
          id: id.hashCode,
          title:
              '${s.get('payment_reminders') ?? 'Nhắc nhở'}: ${_titleController.text}',
          body:
              '${s.get('due_date_label') ?? 'Hạn thanh toán'} $displayType: ${DateFormat('dd/MM/yyyy').format(_dueDate)}.',
          scheduledDate: notifyDate,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _getDisplayType(String type, S s) {
    switch (type) {
      case 'Điện':
        return s.get('type_electricity') ?? 'Điện';
      case 'Nước':
        return s.get('type_water') ?? 'Nước';
      case 'Internet':
        return s.get('type_internet') ?? 'Internet';
      case 'Tiền nhà':
        return s.get('type_rent') ?? 'Tiền nhà';
      case 'Khác':
        return s.get('type_other') ?? 'Khác';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Điện':
        return Icons.electric_bolt_rounded;
      case 'Nước':
        return Icons.water_drop_rounded;
      case 'Internet':
        return Icons.wifi_rounded;
      case 'Tiền nhà':
        return Icons.house_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required bool isDark,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[500])
          : null,
      suffix: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE53935),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyProvider = context.watch<CurrencyProvider>();
    final currencySymbol = currencyProvider.currency;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.reminder == null
              ? (s.get('add_reminder') ?? 'Thêm Nhắc Nhở')
              : (s.get('edit_reminder') ?? 'Sửa Nhắc Nhở'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Title ───
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration(
                  label: s.get('reminder_title_hint') ??
                      'Tiêu đề (VD: Tiền điện tháng 3)',
                  isDark: isDark,
                  prefixIcon: Icons.edit_rounded,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? (s.get('enter_title') ?? 'Vui lòng nhập tiêu đề')
                    : null,
              ),
              const SizedBox(height: 20),

              // ─── Bill Type ───
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: _buildInputDecoration(
                  label: s.get('bill_type') ?? 'Loại hoá đơn',
                  isDark: isDark,
                  prefixIcon: _getTypeIcon(_selectedType),
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_getDisplayType(t, s))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 20),

              // ─── Amount ───
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: s.get('expected_amount') ?? 'Số tiền dự kiến',
                  isDark: isDark,
                  prefixIcon: Icons.payments_rounded,
                  suffix: Text(
                    currencySymbol,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    value = value.replaceAll(',', '');
                    final number = double.tryParse(value);
                    if (number != null) {
                      final formatter = NumberFormat('#,###');
                      final newText = formatter.format(number);
                      if (newText != _amountController.text) {
                        _amountController.value = TextEditingValue(
                          text: newText,
                          selection:
                              TextSelection.collapsed(offset: newText.length),
                        );
                      }
                    }
                  }
                },
                validator: (val) => val == null || val.isEmpty
                    ? (s.get('enter_amount') ?? 'Vui lòng nhập số tiền')
                    : null,
              ),
              const SizedBox(height: 20),

              // ─── Due Date ───
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: s.get('due_date_label') ?? 'Hạn thanh toán',
                    isDark: isDark,
                    prefixIcon: Icons.calendar_month_rounded,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_dueDate),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Remind Before Days ───
              DropdownButtonFormField<int>(
                value: _remindBeforeDays,
                decoration: _buildInputDecoration(
                  label: s.get('remind_before_days') ?? 'Nhắc trước (ngày)',
                  isDark: isDark,
                  prefixIcon: Icons.notifications_active_rounded,
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: _daysList
                    .map((d) => DropdownMenuItem(
                        value: d,
                        child:
                            Text('$d ${s.get('x_days') ?? 'ngày'}')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _remindBeforeDays = val);
                },
              ),
              const SizedBox(height: 20),

              // ─── Notification Time ───
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _remindTime,
                  );
                  if (picked != null) {
                    setState(() => _remindTime = picked);
                  }
                },
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: s.get('notification_time') ??
                        'Giờ thông báo (mặc định 08:00)',
                    isDark: isDark,
                    prefixIcon: Icons.access_time_rounded,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _remindTime.format(context),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Notes ───
              TextFormField(
                controller: _noteController,
                decoration: _buildInputDecoration(
                  label: s.get('additional_notes') ?? 'Ghi chú thêm',
                  isDark: isDark,
                  prefixIcon: Icons.sticky_note_2_rounded,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // ─── Save Button ───
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFE53935).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    s.get('save_reminder') ?? 'Lưu Nhắc Nhở',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
