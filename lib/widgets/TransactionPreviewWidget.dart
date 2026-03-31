import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/TransactionModel.dart';
import '../model/GroupModel.dart';
import '../model/WalletModel.dart';
import '../utils/Utils.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';

class TransactionPreviewWidget extends StatelessWidget {
  final TransactionModel transaction;
  final GroupModel group;

  const TransactionPreviewWidget({
    super.key,
    required this.transaction,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = Utils.currencyFormat(transaction.amount ?? 0);
    final wallet = context.read<WalletModelProxy>().getById(transaction.walletId);
    
    // Format date roughly like "15 thg 3"
    final date = DateTime.parse(transaction.date ?? DateTime.now().toIso8601String());
    final formattedDate = DateFormat('HH:mm, dd/MM/yyyy').format(date); // safe fallback
    final s = S.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${s.get('chatbot_recorded') ?? 'Đã ghi nhận: '}${transaction.type == 'expense' ? (s.get('chatbot_expense_label') ?? 'Chi phí') : (s.get('chatbot_income_label') ?? 'Thu nhập')}",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7FA), // Light cyan
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    IconData(int.tryParse(group.icon ?? '') ?? 0xe532, fontFamily: 'MaterialIcons'),
                    color: transaction.type == 'expense' ? Colors.orange : Colors.green,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Utils.translateGroupName(context, group.name),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      Text(
                        transaction.note!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          Utils.translateWalletName(context, wallet.name),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                formattedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: transaction.type == 'expense' ? Colors.black87 : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.teal),
                  label: Text(s.get('chatbot_transfer_fund') ?? "Di chuyển quỹ", style: const TextStyle(color: Colors.teal, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.teal.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.update, size: 16, color: Colors.teal),
                  label: Text(s.get('chatbot_recurring') ?? "Giao dịch định kỳ", style: const TextStyle(color: Colors.teal, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.teal.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
