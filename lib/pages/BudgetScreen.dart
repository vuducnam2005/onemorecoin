import 'package:flutter/material.dart';
import 'package:onemorecoin/model/BudgetModel.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/utils/MyDateUtils.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/widgets/ShowListWallet.dart';
import 'package:provider/provider.dart';

import '../components/MyButton.dart';
import '../model/TransactionModel.dart';
import '../widgets/CustomLinearProgressIndicator.dart';
import '../widgets/ShowBudgetPage.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/currency_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State createState() => _BudgetScreenState();
}


class _BudgetScreenState extends State<BudgetScreen> {

  String text = 'no data';
  WalletModel _wallet = WalletModel(0, name: null, icon: null, currency: "VND");

  Widget _generateInProcess(BuildContext context, List<BudgetModel> budgetModels){

    budgetModels = budgetModels.where((element) => !MyDateUtils.isAfterDateOnly(DateTime.now(), DateTime.parse(element.toDate!))).toList();

    if(budgetModels.isEmpty){
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        return Center(
          child: ListView(
              shrinkWrap: true,
              children: [
                SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/images/empty-box.png",
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          Text(S.of(context).get('no_budgets') ?? "Bạn chưa có ngân sách nào",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.0
                            ),
                          ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(S.of(context).get('budget_prompt_desc') ?? "Bắt đầu tiết kiệm bằng cách tạo ngân sách và chúng tôi sẽ giúp bạn kiểm soát chi tiêu của mình",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13.0
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 200,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade700 : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  showBudgetPage(context, budgetModel: null);
                                },
                                child: Text(S.of(context).get('create_budget') ?? "TẠO NGÂN SÁCH", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                            ),
                          )
                        ],
                      ),
                    )
                ),
              ]
          ),
        );
      });
    }

    return ListView(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade700 : Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                showBudgetPage(context, budgetModel: null);
              },
              child: Text(S.of(context).get('create_budget') ?? "TẠO NGÂN SÁCH", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))
          ),
        ),
        ..._generateBudget(context, budgetModels),
        const SizedBox(height: 100.0)
      ]
    );
  }

  Widget _generateFinish(BuildContext context, List<BudgetModel> budgetModels){
    budgetModels = budgetModels.where((element) => MyDateUtils.isAfterDateOnly(DateTime.now(), DateTime.parse(element.toDate!))).toList();

    if(budgetModels.isEmpty){
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        return Center(
          child: ListView(
              shrinkWrap: true,
              children: [
                SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/images/empty-box.png",
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          Text(S.of(context).get('no_finished_budgets') ?? "Chưa có ngân sách nào kết thúc",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.0
                            ),
                          ),
                        ],
                      ),
                    )
                ),
              ]
          ),
        );
      });
    }

    Map<String, List<BudgetModel>> mapBudgetFromDate = {};
    for(var budget in budgetModels){
      if(mapBudgetFromDate[budget.fromDate] == null){
        mapBudgetFromDate[budget.fromDate!] = [];
      }
      mapBudgetFromDate[budget.fromDate]!.add(budget);
    }

    return ListView(
        children: [
          for(var key in mapBudgetFromDate.keys)
          ..._generateBudget(context, mapBudgetFromDate[key]!)
        ]
    );
  }

  List<Widget> _generateBudget(BuildContext context, List<BudgetModel> budgetModels){

    List<String> budgetType = ['week', 'month', 'quarter', 'year'];
    Map<String, List<BudgetModel>> mapBudget = {};
    for(var type in budgetType){
      mapBudget[type] = budgetModels.where((element) => element.budgetType == type).toList();
    }
    List<Widget> listWidget = [];

    var transactionModelProxy = context.read<TransactionModelProxy>();
    for(var key in mapBudget.keys) {
      List<BudgetModel> budgets = mapBudget[key]!;
      if(budgets.isEmpty){
        continue;
      }
      double sumBudget = Utils.sumBudget(budgets);
      double sumAmount = Utils.sumBudgetAmountTransaction(budgets, transactionModelProxy);
      listWidget.add(
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(10),
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.of(context).get('start_date') ?? "Ngày bắt đầu", ),
                      Text(S.of(context).get('end_date') ?? "Ngày kết thúc", ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(MyDateUtils.toStringFormat02FromString(budgets.first.fromDate)),
                      Text(MyDateUtils.toStringFormat02FromString(budgets.first.toDate)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(MyDateUtils.isAfterDateOnly(DateTime.now(), DateTime.parse(budgets.first.toDate!)) ? "" :  "${MyDateUtils.parseTypeToString(budgets.first.budgetType, context: context)} ${S.of(context).get('this_period') ?? 'này'}", style: const TextStyle( fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            child: Text("${Utils.currencyFormat(sumBudget)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle( fontWeight: FontWeight.bold)
                            ),
                          )
                      )
                    ],
                  ),
                  Text("${Utils.currencyFormat(sumAmount)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 150
                    ),
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                      height: 1,
                      thickness: 1,
                      indent: 0,
                      endIndent: 0,
                    )
                  ),
                  const SizedBox(height: 3),
                  Text("${Utils.currencyFormat(sumBudget + sumAmount)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: sumBudget + sumAmount > 0 ? Colors.green : Colors.red
                      )
                  )
                ],
              ),
            ),
            Divider(
              color: Theme.of(context).dividerColor,
              height: 1,
              thickness: 1,
              indent: 0,
              endIndent: 0,
            ),
            for(var budget in budgets)
              _generateItemBudget(budget, transactionModelProxy)
          ],
        )
      );
    }
    return listWidget;
  }

  Widget _generateItemBudget(BudgetModel budget, transactionModelProxy){
    List<TransactionModel> transactions = transactionModelProxy.getAllForBudget(budget.groupId, budget.walletId, budget.fromDate, budget.toDate);
    double sumAmount = -1 * Utils.sumAmountTransaction(transactions);
    
    // Safety check for budget.budget (max width)
    double maxBudget = budget.budget ?? 1.0;
    if (maxBudget <= 0) maxBudget = 1.0;
    
    double restAmount = maxBudget - sumAmount;
    double percentage = sumAmount / maxBudget;
    
    Color progressColor = Colors.green;
    if (percentage > 0.9) {
      progressColor = Colors.red;
    } else if (percentage >= 0.5) {
      progressColor = Colors.orange;
    }

    GroupModel? group = budget.group;
    return MyButton(
        onTap: () {
          // showBudgetPage(context, budgetModel: budget);
          Navigator.pushNamed(context, '/DetailBudget', arguments: budget);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 50,
                    child: CircleAvatar(
                      radius: 20.0,
                      backgroundColor: Colors.transparent,
                      child: CustomIcon(iconPath: group?.icon, size: 40),
                    ),
                  ),
                  Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(group?.name ?? "", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                          if(budget.note != null && budget.note!.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(
                                maxWidth: 200,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10, top: 2),
                                child: Text(budget.note!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.grey)
                                ),
                              ),
                            )
                        ],
                      ),
                  ),
                  Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Softened total budget text
                            FittedBox(
                              child: Text(Utils.currencyFormat(maxBudget),
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Bold, larger remaining amount text
                            Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                  child: Text("${restAmount >= 0 ? (S.of(context).get('remaining_colon') ?? "Còn lại:") : (S.of(context).get('overspent_colon') ?? "Bội chi:")} ${Utils.currencyFormat(restAmount)}",
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: restAmount >= 0 ? Theme.of(context).textTheme.bodyMedium?.color : Colors.red,
                                      )
                                  )
                              ),
                            )
                          ],
                        ),
                      )
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 70,
                  ),
                  Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: CustomLinearProgressIndicator(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!,
                          colors: [progressColor],
                          value: sumAmount,
                          maxProgressWidth: maxBudget,
                        ),
                      )
                  )
                ],
              ),
              
              // Top 3 Recent Transactions
              if (transactions.isNotEmpty) ...[
                 const SizedBox(height: 12),
                 Padding(
                   padding: const EdgeInsets.only(left: 70, right: 16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: transactions.take(3).map((t) {
                       return Padding(
                         padding: const EdgeInsets.only(bottom: 4.0),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Expanded(
                               child: Text(
                                 t.note != null && t.note!.isNotEmpty ? t.note! : (t.group?.name ?? ''),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                                 style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                               ),
                             ),
                             Text(
                               "-${Utils.currencyFormat(t.amount ?? 0)}",
                               style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                             )
                           ],
                         ),
                       );
                     }).toList(),
                   )
                 )
              ],
              
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 70,
                  ),
                  Expanded(
                      child: Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1,
                        indent: 0,
                        endIndent: 0,
                      )
                  )
                ],
              ),
            ],
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    print("build budget screen");
    context.watch<CurrencyProvider>();
    var budgets = context.watch<BudgetModelProxy>().getAllByWalletId(_wallet.id);
    _wallet = context.read<TransactionModelProxy>().walletModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(S.of(context).get('budgets') ?? 'Ngân sách', style: const TextStyle(
            fontWeight: FontWeight.bold
        )),
        actions: [
          Material(
            child: Container(
              padding: EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: (){
                  ShowListWalletPage(context, wallet: _wallet).then((value) {
                    if(value != null && value['wallet'] != null){
                      if(value['wallet'].id != _wallet.id){
                        setState(() {
                          _wallet = value['wallet'];
                        });
                      }
                    }
                  });
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _wallet.id == 0 ?  Icon(Icons.language_outlined, color: Colors.green,) : CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 15.0,
                        child: CustomIcon(iconPath: _wallet.icon, size: 40),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_sharp, color: Colors.grey,),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).cardColor,
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: S.of(context).get('in_progress') ?? 'ĐANG ÁP DỤNG'),
                    Tab(text: S.of(context).get('finished') ?? 'ĐÃ KẾT THÚC'),
                  ],
                ),
              ),
              Expanded(
                  child: PageStorage(
                    bucket: PageStorageBucket(),
                    child: TabBarView(
                      children: [
                        PageStorage(
                          bucket: PageStorageBucket(),
                          child: _generateInProcess(context, budgets),
                        ),
                        PageStorage(
                          bucket: PageStorageBucket(),
                          child: _generateFinish(context, budgets),
                        ),
                      ],
                    ),
                  )
              )
            ],
          ),
        ),
      ),
    );
  }
}

Widget bodyWithReturnArgs(context) {
  return Container(
    alignment: Alignment.topCenter,
    child: Column(
      children: [
        IconButton(
            icon: Icon(Icons.close),
            onPressed: () =>
                Navigator.pop(context, 'Data returns from left side sheet')),
        Text('Body')
      ],
    ),
  );
}