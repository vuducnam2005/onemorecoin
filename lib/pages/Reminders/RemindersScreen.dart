import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../model/ReminderModel.dart';
import '../../model/TransactionModel.dart';
import '../../model/WalletModel.dart';
import '../../model/GroupModel.dart';
import '../../utils/currency_provider.dart';
import 'AddReminderScreen.dart';
import '../../utils/notification_helper.dart';
import '../../utils/app_localizations.dart';
import '../../model/AppNotificationModel.dart';
import 'package:uuid/uuid.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String _searchQuery = '';
  String _statusFilter = ''; // '', 'paid', 'unpaid', 'overdue'
  bool _sortNewestFirst = false; // false = sắp đến hạn trước
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter and sort reminders
  List<Reminder> _filterAndSort(List<Reminder> reminders) {
    var filtered = reminders.where((r) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!r.title.toLowerCase().contains(q) &&
            !(r.type.toLowerCase().contains(q)) &&
            !(r.note.toLowerCase().contains(q))) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter == 'paid' && r.isPaid != 1) return false;
      if (_statusFilter == 'unpaid' && r.isPaid == 1) return false;
      if (_statusFilter == 'overdue') {
        if (r.isPaid == 1) return false;
        try {
          final dueDate = DateTime.parse(r.dueDate);
          if (!dueDate.isBefore(DateTime.now())) return false;
        } catch (_) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by due date
    filtered.sort((a, b) {
      DateTime dateA, dateB;
      try { dateA = DateTime.parse(a.dueDate); } catch (_) { dateA = DateTime.now(); }
      try { dateB = DateTime.parse(b.dueDate); } catch (_) { dateB = DateTime.now(); }
      return _sortNewestFirst ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    return filtered;
  }

  /// Returns urgency color based on how close the due date is
  Color _getDueDateColor(DateTime dueDate, bool isPaid, bool isDark) {
    if (isPaid) return isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return const Color(0xFFE53935);
    if (daysLeft <= 2) return const Color(0xFFE53935);
    if (daysLeft <= 5) return const Color(0xFFFFA726);
    return isDark ? Colors.grey[400]! : Colors.grey[600]!;
  }

  String _getDueDateLabel(BuildContext context, DateTime dueDate, bool isPaid) {
    if (isPaid) return '';
    final s = S.of(context);
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return ' · ${s.get('loan_overdue') ?? 'Quá hạn!'}';
    if (daysLeft == 0) return ' · ${s.get('today') ?? 'Hôm nay'}';
    if (daysLeft == 1) return ' · ${s.get('tomorrow') ?? 'Ngày mai'}';
    if (daysLeft <= 5) return ' · $daysLeft ${s.get('x_days') ?? 'ngày'}';
    return '';
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'Điện': return Icons.electric_bolt_rounded;
      case 'Nước': return Icons.water_drop_rounded;
      case 'Internet': return Icons.wifi_rounded;
      case 'Tiền nhà': return Icons.house_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'Điện': return const Color(0xFFFFA726);
      case 'Nước': return const Color(0xFF42A5F5);
      case 'Internet': return const Color(0xFF66BB6A);
      case 'Tiền nhà': return const Color(0xFFAB47BC);
      default: return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = context.watch<ReminderProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final s = S.of(context);
    final allReminders = reminderProvider.reminders;
    final filteredReminders = _filterAndSort(allReminders);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          s.get('payment_reminders') ?? 'Nhắc nhở thanh toán',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── Search Bar ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: s.get('search_reminder') ?? 'Tìm kiếm nhắc nhở...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18,
                            color: isDark ? Colors.grey[400] : Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),

          // ─── Filter Chips + Sort ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: s.get('all') ?? 'Tất cả',
                          value: '',
                          icon: Icons.list_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: s.get('loan_unpaid') ?? 'Chưa trả',
                          value: 'unpaid',
                          icon: Icons.warning_amber_rounded,
                          statusColor: const Color(0xFFEF5350),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: s.get('loan_paid') ?? 'Đã trả',
                          value: 'paid',
                          icon: Icons.check_circle_rounded,
                          statusColor: const Color(0xFF4CAF50),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: s.get('loan_overdue') ?? 'Quá hạn',
                          value: 'overdue',
                          icon: Icons.schedule_rounded,
                          statusColor: const Color(0xFFE53935),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _sortNewestFirst = !_sortNewestFirst);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortNewestFirst
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s.get('date') ?? 'Ngày',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Results count ───
          if (allReminders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${filteredReminders.length} ${s.get('results') ?? 'kết quả'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  if (_sortNewestFirst) ...[
                    Text(
                      ' · ${s.get('sort_newest') ?? 'Mới nhất'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ] else ...[
                    Text(
                      ' · ${s.get('sort_due_soon') ?? 'Sắp đến hạn'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ─── Reminder List ───
          Expanded(
            child: allReminders.isEmpty
                ? _buildEmptyState(s, isDark)
                : filteredReminders.isEmpty
                    ? _buildNoResults(s, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredReminders.length,
                        itemBuilder: (context, index) {
                          final reminder = filteredReminders[index];
                          return _buildReminderCard(
                            reminder, reminderProvider, currencyProvider, s, isDark,
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReminderScreen()),
          );
        },
        backgroundColor: const Color(0xFFE53935),
        elevation: 6,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? statusColor,
    required bool isDark,
  }) {
    final isSelected = _statusFilter == value;
    final chipColor = statusColor ?? const Color(0xFFE53935);

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = isSelected ? '' : value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(isDark ? 0.25 : 0.15)
              : isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(0.6)
                : isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? chipColor
                  : isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? chipColor
                    : isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(S s, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: const Color(0xFFE53935).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.get('no_reminders_yet') ?? 'Chưa có nhắc nhở nào.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.get('reminder_hint') ?? 'Nhấn + để thêm nhắc nhở mới',
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(S s, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            s.get('no_results_found') ?? 'Không tìm thấy kết quả',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    Reminder reminder,
    ReminderProvider reminderProvider,
    CurrencyProvider currencyProvider,
    S s,
    bool isDark,
  ) {
    final isPaid = reminder.isPaid == 1;

    // Format amount
    final format = NumberFormat.decimalPattern();
    final amountString =
        '${format.format(reminder.amount)} ${currencyProvider.currency}';

    // Parse due date
    DateTime dueDate;
    try {
      dueDate = DateTime.parse(reminder.dueDate);
    } catch (e) {
      dueDate = DateTime.now();
    }
    final dueDateString = DateFormat('dd/MM/yyyy').format(dueDate);
    final dueDateColor = _getDueDateColor(dueDate, isPaid, isDark);
    final urgencyLabel = _getDueDateLabel(context, dueDate, isPaid);

    final typeColor = _getTypeColor(reminder.type);
    final typeIcon = _getTypeIcon(reminder.type);

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.get('delete_reminder') ?? 'Xóa nhắc nhở'),
            content: Text(s.get('confirm_delete') ?? 'Bạn có chắc chắn muốn xóa?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.get('cancel') ?? 'Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.get('delete') ?? 'Xóa',
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        NotificationHelper.instance.cancelNotification(reminder.id.hashCode);
        reminderProvider.deleteReminder(reminder.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPaid
                ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
                : dueDateColor.withOpacity(0.2),
            width: isPaid ? 0.8 : 1.2,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddReminderScreen(reminder: reminder),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPaid
                          ? (isDark ? Colors.grey[800] : Colors.grey[100])
                          : typeColor.withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      typeIcon,
                      color: isPaid
                          ? (isDark ? Colors.grey[500] : Colors.grey[400])
                          : typeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            decoration: isPaid ? TextDecoration.lineThrough : null,
                            color: isPaid
                                ? (isDark ? Colors.grey[500] : Colors.grey[400])
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.get('amount') ?? 'Số tiền'}: $amountString',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: dueDateColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueDateString,
                              style: TextStyle(
                                fontSize: 13,
                                color: dueDateColor,
                                fontWeight: urgencyLabel.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (urgencyLabel.isNotEmpty)
                              Text(
                                urgencyLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dueDateColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  Column(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final newVal = !isPaid;
                              final transProxy = context.read<TransactionModelProxy>();
                              final walletProxy = context.read<WalletModelProxy>();
                              final groupProxy = context.read<GroupModelProxy>();
                              final format = NumberFormat.decimalPattern();
                              final amountStr = '${format.format(reminder.amount)} ${currencyProvider.currency}';

                              await reminderProvider.togglePaidStatus(
                                reminder.id,
                                newVal,
                                transactionProxy: transProxy,
                                walletProxy: walletProxy,
                                groupProxy: groupProxy,
                              );

                              if (newVal) {
                                NotificationHelper.instance
                                    .cancelNotification(reminder.id.hashCode);

                                String notifTitle = 'Đã thanh toán hoá đơn';
                                String notifBody = 'Thanh toán thành công $amountStr cho ${reminder.title}';
                                
                                if (context.mounted) {
                                  await context.read<AppNotificationProvider>().addNotification(
                                    AppNotificationModel(
                                      id: const Uuid().v4(),
                                      title: notifTitle,
                                      body: notifBody,
                                      type: 'reminder',
                                      date: DateTime.now().toIso8601String(),
                                      isRead: false,
                                    )
                                  );
                                }
                                
                                await NotificationHelper.instance.showInstantNotification(
                                  id: const Uuid().v4().hashCode,
                                  title: notifTitle,
                                  body: notifBody,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã trừ $amountStr từ ví'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã hoàn $amountStr vào ví'),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isPaid
                                  ? const Color(0xFF4CAF50)
                                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      if (isPaid)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            s.get('loan_paid') ?? 'Đã trả',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
