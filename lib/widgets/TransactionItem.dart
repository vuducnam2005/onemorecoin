import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onemorecoin/model/TransactionModel.dart';

import '../utils/MyDateUtils.dart';
import '../utils/Utils.dart';
import '../widgets/CustomIcon.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/utils/currency_provider.dart';

class TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final String? showType;
  const TransactionItem({super.key,
    required this.transaction,
    this.showType = 'date'
  });

  String _buildSubtitle(BuildContext context) {
    List<String> parts = [];
    if (transaction.date != null) {
      parts.add(DateFormat('HH:mm').format(DateTime.parse(transaction.date!)));
    }
    if (transaction.wallet?.name != null) {
      parts.add(Utils.translateWalletName(context, transaction.wallet!.name));
    }
    if (transaction.note != null && transaction.note!.isNotEmpty) {
      parts.add(transaction.note!);
    }
    return parts.join(" • ");
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    bool isWalletDeleted = transaction.wallet == null && transaction.walletId != 0;
    
    if(showType == 'date'){
      return Material(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            onTap: () {
              Navigator.pushNamed(context, '/DetailTransaction', arguments: transaction);
            },
            leading: Container(
              width: 40,
              height: 40,
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: CustomIcon(iconPath: transaction.group?.icon, size: 40),
              ),
            ),
            title: Row(
              children: [
                Text(Utils.translateGroupName(context, transaction.group?.name)),
                if (isWalletDeleted)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      "(Ví đã bị xóa)",
                      style: TextStyle(color: Colors.red, fontSize: 12.0),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              _buildSubtitle(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[500]),
            ),
            trailing: Text(Utils.currencyFormat(transaction.amount!),
                style: TextStyle(
                    color: transaction.type == "income" ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0
                )
            ),
          )
      );
    }
    return Material(
      child: Container(
        color: Theme.of(context).cardColor,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
          onTap: () {
            Navigator.pushNamed(context, '/DetailTransaction', arguments: transaction);
          },
          leading: Container(
            width: 40,
            height: 40,
          ),
          title: Row(
            children: [
              Text("${MyDateUtils.toStringFormat01FromString(transaction.date!, context: context)}, ${MyDateUtils.getNameDayOfWeekFromString(transaction.date!, context: context)}",
                style: const TextStyle(
                  fontSize: 13.0,
                ),
              ),
              if (isWalletDeleted)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text(
                    "(Ví đã bị xóa)",
                    style: TextStyle(color: Colors.red, fontSize: 12.0),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            _buildSubtitle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[500]),
          ),
          trailing: Text(Utils.currencyFormat(transaction.amount!),
              style: TextStyle(
                  color: transaction.type == "income" ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0
              )

          ),
        ),
      ),
    );
  }
}
