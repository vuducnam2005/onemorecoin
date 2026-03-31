import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/model/AppNotificationModel.dart';
import 'package:onemorecoin/model/LoanModel.dart';
import 'package:onemorecoin/pages/Reminders/RemindersScreen.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

import '../../commons/Constants.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  String _currentFilter = 'all'; // all, unread, reminder, loan

  String _getTranslatedTitle(String title, String type, BuildContext context) {
    if (type == 'reminder' && title == 'Nhắc thanh toán hoá đơn') {
      return S.of(context).get('reminder_payment_title') ?? 'Nhắc thanh toán hoá đơn';
    }
    if (type == 'loan') {
      if (title == 'Khoản nợ đến hạn') return S.of(context).get('debt_due_title') ?? 'Khoản nợ đến hạn';
      if (title == 'Khoản cho vay đến hạn') return S.of(context).get('loan_due_title') ?? 'Khoản cho vay đến hạn';
      if (title == 'Đã tạo khoản vay') return S.of(context).get('loan_created_borrow') ?? 'Đã tạo khoản vay';
      if (title == 'Đã tạo khoản cho vay') return S.of(context).get('loan_created_lend') ?? 'Đã tạo khoản cho vay';
    }
    return title;
  }

  String _getTranslatedBody(String body, String type, BuildContext context) {
    if (type == 'reminder') {
      final RegExp reminderRegex = RegExp(r'^Đến hạn thanh toán (.*) số tiền (.*)$');
      final match = reminderRegex.firstMatch(body);
      if (match != null) {
        String title = match.group(1)!;
        String amount = match.group(2)!;
        String template = S.of(context).get('reminder_payment_body') ?? 'Đến hạn thanh toán {0} số tiền {1}';
        return template.replaceAll('{0}', title).replaceAll('{1}', amount);
      }
    } else if (type == 'loan') {
      final RegExp borrowRegex = RegExp(r'^Bạn cần trả (.*) cho (.*)$');
      final borrowMatch = borrowRegex.firstMatch(body);
      if (borrowMatch != null) {
        String amount = borrowMatch.group(1)!;
        String person = borrowMatch.group(2)!;
        String template = S.of(context).get('debt_payment_body') ?? 'Bạn cần trả {0} cho {1}';
        return template.replaceAll('{0}', amount).replaceAll('{1}', person);
      }
      
      final RegExp lendRegex = RegExp(r'^Đến hạn thu (.*) từ (.*)$');
      final lendMatch = lendRegex.firstMatch(body);
      if (lendMatch != null) {
        String amount = lendMatch.group(1)!;
        String person = lendMatch.group(2)!;
        String template = S.of(context).get('loan_collection_body') ?? 'Đến hạn thu {0} từ {1}';
        return template.replaceAll('{0}', amount).replaceAll('{1}', person);
      }
      
      final RegExp borrowCreatedRegex = RegExp(r'^Bạn đã vay (.*) từ (.*)$');
      final borrowCreatedMatch = borrowCreatedRegex.firstMatch(body);
      if (borrowCreatedMatch != null) {
        String amount = borrowCreatedMatch.group(1)!;
        String person = borrowCreatedMatch.group(2)!;
        String template = S.of(context).get('loan_created_borrow_body') ?? 'Bạn đã vay {0} từ {1}';
        return template.replaceAll('{0}', amount).replaceAll('{1}', person);
      }
      
      final RegExp lendCreatedRegex = RegExp(r'^Bạn đã cho (.*) vay (.*)$');
      final lendCreatedMatch = lendCreatedRegex.firstMatch(body);
      if (lendCreatedMatch != null) {
        String person = lendCreatedMatch.group(1)!;
        String amount = lendCreatedMatch.group(2)!;
        String template = S.of(context).get('loan_created_lend_body') ?? 'Bạn đã cho {0} vay {1}';
        return template.replaceAll('{0}', person).replaceAll('{1}', amount);
      }
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AppNotificationProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(S.of(context).get('notifications') ?? 'Thông báo'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              tooltip: S.of(context).get('mark_all_read') ?? 'Đánh dấu tất cả đã đọc',
              icon: const Icon(Icons.done_all),
              onPressed: () {
                provider.markAllAsRead();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip(S.of(context).get('all') ?? 'Tất cả', 'all', isDark),
                _buildFilterChip(S.of(context).get('unread') ?? 'Chưa đọc', 'unread', isDark, count: provider.unreadCount),
                _buildFilterChip(S.of(context).get('bill') ?? 'Hoá đơn', 'reminder', isDark),
                _buildFilterChip(S.of(context).get('debt') ?? 'Khoản nợ', 'loan', isDark),
              ],
            ),
          ),
          
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      List<AppNotificationModel> filteredList = provider.notifications;
                      if (_currentFilter == 'unread') {
                        filteredList = filteredList.where((n) => !n.isRead).toList();
                      } else if (_currentFilter != 'all') {
                        filteredList = filteredList.where((n) => n.type == _currentFilter).toList();
                      }

                      if (filteredList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                S.of(context).get('no_notifications') ?? 'Không có thông báo nào',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notif = filteredList[index];
                          return Dismissible(
                            key: Key(notif.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              provider.delete(notif.id);
                            },
                            child: _buildNotificationItem(notif, isDark, provider),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark, {int? count}) {
    final isSelected = _currentFilter == value;
    final bgColor = isDark
        ? (isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.grey[800]!)
        : (isSelected ? Colors.blue.shade100 : Colors.grey.shade200);
    final textColor = isDark
        ? (isSelected ? Colors.blueAccent.shade100 : Colors.grey[300]!)
        : (isSelected ? Colors.blue.shade800 : Colors.grey.shade800);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        backgroundColor: bgColor,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
        onPressed: () {
          setState(() {
            _currentFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildNotificationItem(AppNotificationModel notif, bool isDark, AppNotificationProvider provider) {
    IconData iconData = Icons.notifications;
    Color iconColor = Colors.grey;
    Color iconBgColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    if (notif.type == 'reminder') {
      iconData = Icons.receipt_long_rounded;
      iconColor = Colors.orange;
      iconBgColor = isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50;
    } else if (notif.type == 'loan') {
      iconData = Icons.account_balance_wallet_rounded;
      iconColor = Colors.green;
      iconBgColor = isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50;
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(notif.date);
    } catch (e) {
      parsedDate = DateTime.now();
    }
    String timeFormatted = DateFormat('dd/MM HH:mm').format(parsedDate);

    // Unread item styling
    final itemBgColor = notif.isRead 
        ? Colors.transparent 
        : (isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.shade50.withOpacity(0.5));

    return Material(
      color: itemBgColor,
      child: InkWell(
        onTap: () {
          if (!notif.isRead) {
            provider.markAsRead(notif.id);
          }
          // Navigate to respective feature
          if (notif.type == 'reminder') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
          } else if (notif.type == 'loan' && notif.referenceId != null) {
            final loanProvider = context.read<LoanProvider>();
            final loan = loanProvider.getById(notif.referenceId!);
            if (loan != null) {
              Navigator.pushNamed(context, '/LoanDetail', arguments: loan);
            } else {
              Navigator.pushNamed(context, '/LoanList');
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _getTranslatedTitle(notif.title, notif.type, context),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: notif.isRead ? Colors.grey : (isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700),
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTranslatedBody(notif.body, notif.type, context),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
