import 'dart:math';
import 'package:flutter/material.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:provider/provider.dart';

class WeeklyInsightWidget extends StatelessWidget {
  const WeeklyInsightWidget({Key? key}) : super(key: key);

  String _generateInsight(List<TransactionModel> weekExpenses, BuildContext context) {
    if (weekExpenses.length < 3) {
      return "💡 Khởi đầu tuần mới! Hãy tiếp tục theo dõi để AI hiển thị phân tích.";
    }

    double totalExpense = weekExpenses.fold(0, (sum, item) => sum + (item.amount ?? 0));
    
    // Calculate category spending
    Map<String, double> categorySpending = {};
    for (var t in weekExpenses) {
      String groupName = t.group?.name ?? "Khác";
      categorySpending[groupName] = (categorySpending[groupName] ?? 0) + (t.amount ?? 0);
    }
    
    var sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Calculate daily spending
    Map<int, double> dailySpending = {};
    for (var t in weekExpenses) {
       if (t.date != null) {
         DateTime d = DateTime.parse(t.date!);
         dailySpending[d.weekday] = (dailySpending[d.weekday] ?? 0) + (t.amount ?? 0);
       }
    }
    
    var sortedDays = dailySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Randomize insight
    int randomType = Random().nextInt(3);
    
    if (randomType == 0 && sortedCategories.isNotEmpty) {
      String topCategory = sortedCategories.first.key;
      double amount = sortedCategories.first.value;
      double percent = (amount / totalExpense) * 100;
      return "💡 Tuần này bạn chi nhiều nhất vào $topCategory, chiếm ${percent.toStringAsFixed(0)}% tổng chi tiêu.";
    } 
    else if (randomType == 1 && sortedDays.isNotEmpty) {
      int topDay = sortedDays.first.key;
      List<String> days = ["", "Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"];
      return "💡 Ngày bạn tiêu nhiều tiền nhất trong tuần là ${days[topDay]}.";
    }
    else {
      return "💡 Theo dõi thu chi mỗi ngày giúp bạn tiết kiệm được thêm 20% mỗi tháng!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxy = context.watch<TransactionModelProxy>();
    final wallet = proxy.walletModel;
    
    List<TransactionModel> currentWeekExpenses = [];
    
    if (wallet.id != 0) {
      final now = DateTime.now();
      // Calculate Monday of current week
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);
      final list = proxy.getTransactionByWalletId(wallet.id);
      
      currentWeekExpenses = list.where((t) {
        if (t.type != 'expense' || t.date == null) return false;
        DateTime d = DateTime.parse(t.date!);
        return d.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
      }).toList();
    }

    String insightStr = _generateInsight(currentWeekExpenses, context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích tuần này',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0083B0).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    insightStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
