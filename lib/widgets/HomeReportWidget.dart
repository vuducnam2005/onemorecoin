import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:provider/provider.dart';
import 'package:slide_switcher/slide_switcher.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../Objects/ShowType.dart';
import '../Objects/TabTransaction.dart';
import '../model/TransactionModel.dart';
import '../utils/MyDateUtils.dart';
import '../utils/Utils.dart';
import '../widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/currency_provider.dart';

class HomeReportWidget extends StatefulWidget {

  const HomeReportWidget({super.key,
  });

  @override
  State<HomeReportWidget> createState() => _HomeReportWidgetState();
}

class _HomeReportWidgetState extends State<HomeReportWidget> {
  int chartType = 0;
  List<TabTransaction> listTab = [];
  int totalTab = 20;
  double totalSpent = 0;
  List<ChartData> chartData = [];
  Map<GroupModel, double> mostGroupExpense = {};
  int limitMostGroupExpense = 3;
  double percent = 0;
  List<TransactionModel> transactions = [];

  @override
  void initState() {
    super.initState();
    List<TabTransaction> ls = Utils.getListTabShowTypeTransaction(ShowType.week, totalTab);
    // ls.removeLast();
    listTab = [ls[ls.length - 3], ls[ls.length - 2]];

  }

  void _generateListTab(int index){
    if (index == 0) {
      List<TabTransaction> ls = Utils.getListTabShowTypeTransaction(ShowType.week, totalTab);
      // ls.removeLast();
      ls = [ls[ls.length - 3], ls[ls.length - 2]];
      setState(() {
        chartType = 0;
        listTab = ls;
        // chartData = _generateChartData(transactions);
      });
    }

    if(index == 1){
      List<TabTransaction> ls = Utils.getListTabShowTypeTransaction(ShowType.month, totalTab);
      // ls.removeLast();
      ls = [ls[ls.length - 3], ls[ls.length - 2]];
      setState(() {
        chartType = 1;
        listTab = ls;
        // chartData = _generateChartData(transactions);
      });
    }

  }

  _generateChartData(List<TransactionModel> transactions ) {
    mostGroupExpense = {};
    for (final item in listTab) {
      item.transactions.clear();
    }
    transLoop:
    for(var tran in transactions){
      tabLoop:
      for(var tab in listTab){
        if(tab.isAll){
          tab.transactions.add(tran);
          break tabLoop;
        }
        if(tab.isFuture){
          if(MyDateUtils.isAfter(DateTime.parse(tran.date!), tab.from)){
            tab.transactions.add(tran);
            break tabLoop;
          }
        }
        else{
          if(MyDateUtils.isBetween(DateTime.parse(tran.date!), tab.from, tab.to)){
            tab.transactions.add(tran);
            break tabLoop;
          }
        }
      }
    }

    List<ChartData> chartData = [];
    for (final tab in listTab) {
      double expense = 0;
      double income = 0;
      for(final item in tab.transactions){
        if(item.type == "expense"){
          expense += item.amount!;
        }else{
          income += item.amount!;
        }
      }
      if (CurrencyProvider.currentCurrency == 'USD') {
        chartData.add(ChartData(Utils.translateTabName(context, tab.name), expense / 26294.0, income / 26294.0, expense, income));
      } else {
        chartData.add(ChartData(Utils.translateTabName(context, tab.name), expense, income, expense, income));
      }
    }

    ////// tìm nhóm chi nhiều nhất //////
    Map<int, double> mostExpenseByGroup = {};
    if (listTab.isNotEmpty && listTab.last.transactions.isNotEmpty) {
      for(final item in listTab.last.transactions){
        if(item.type == "expense"){
          if(mostExpenseByGroup.containsKey(item.groupId)){
            mostExpenseByGroup[item.groupId] = mostExpenseByGroup[item.groupId]! + item.amount!;
          }
          else{
            mostExpenseByGroup[item.groupId] = item.amount!;
          }
        }
      }
    }
    mostExpenseByGroup = Map.fromEntries(
        mostExpenseByGroup.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));

    if(mostExpenseByGroup.isNotEmpty){
      for(final key in mostExpenseByGroup.keys){
        if(mostGroupExpense.length == limitMostGroupExpense){
          break;
        }
        mostGroupExpense[context.read<GroupModelProxy>().getById(key)] = mostExpenseByGroup[key]!;
      }
    }
    /////////////////////////////////////////////

    if (chartData.isNotEmpty) {
      totalSpent = chartData.last.rawExpense;
      if(chartData.length < 2 || chartData[chartData.length - 2].expense == 0){
        percent = 100;
      }else{
        percent = double.parse(((chartData.last.expense - chartData[chartData.length - 2].expense) / chartData[chartData.length - 2].expense).toStringAsFixed(3)) * 100;
      }
    } else {
      totalSpent = 0;
      percent = 0;
    }
    
    return chartData.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GroupModelProxy>(); // Watch for group changes so UI updates from "Loading..."
    transactions = context.watch<TransactionModelProxy>().getAll();
    chartData = _generateChartData(transactions);

    return Container(
      margin: const EdgeInsets.symmetric( horizontal: 10.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        children: [
          LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SlideSwitcher(
                  onSelect: (int index) => _generateListTab(index),
                  containerColor: Theme.of(context).scaffoldBackgroundColor,
                  slidersColors: [Theme.of(context).cardColor],
                  containerBorderRadius: 5,
                  indents: 3,
                  containerHeight: 30,
                  containerWight: constraints.maxWidth - 60,
                  children: [
                    Text(S.of(context).get('week') ?? "Tuần",
                      style: TextStyle(
                        color: chartType == 0 ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey,
                      ),
                    ),
                    Text(S.of(context).get('month') ?? "Tháng",
                      style: TextStyle(
                        color: chartType == 1 ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey,
                      ),
                    ),
                  ],
                );
              }
          ),
          Container(
            margin: const EdgeInsets.only(top: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Utils.currencyFormat(totalSpent),
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(chartType == 0 ? (S.of(context).get('total_spent_this_week') ?? "Tổng đã chi tuần này") : (S.of(context).get('total_spent_this_month') ?? "Tổng đã chi tháng này"),
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                        child: percent < 0 ?
                            Icon(Icons.arrow_drop_down, color: Colors.green)
                            : Icon(Icons.arrow_drop_up, color: Colors.red)
                    ),
                    Text("${percent}%",
                      style: TextStyle(
                        fontSize: 13.0,
                        color: percent < 0 ? Colors.green : Colors.red,
                      ),
                    ),

                  ],
                )
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10.0),
            child: SfCartesianChart(
                // zoomPanBehavior: ZoomPanBehavior(
                //   enablePanning: true,
                // ),
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  // initialZoomFactor: 0.1,
                ),
                primaryYAxis: NumericAxis(
                  // opposedPosition: true,
                  axisLine: const AxisLine(width: 0),
                  numberFormat: CurrencyProvider.currentCurrency == 'USD' 
                      ? NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0) 
                      : NumberFormat.compact(locale: 'vi'),
                  majorTickLines: const MajorTickLines(size: 0),
                  majorGridLines: const MajorGridLines(width: 0),
                  minimum: 0,
                ),
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  // Legend will be placed at the bottom
                  overflowMode: LegendItemOverflowMode.wrap,
                  // To place legend items in multiple rows
                  alignment: ChartAlignment.center,
                  // To align the legend at center
                  itemPadding: 10,
                  // Padding between each legend item
                  toggleSeriesVisibility: true,
                  // To show/hide series on legend click
                  // Spacing between columns
                  textStyle: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                series: <CartesianSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                      legendItemText: S.of(context).get('income_item') ?? "Khoản thu",
                      dataSource:  chartData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.income,
                      color: Colors.green,
                      // Width of the columns
                      width: 0.8,
                      // Spacing between the columns
                      spacing: 0.2,
                      animationDuration: 0,
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.outer,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                          final chartItem = data as ChartData;
                          if (chartItem.rawIncome == 0) return const SizedBox.shrink();
                          return Text(
                            Utils.currencyFormat(chartItem.rawIncome),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          );
                        },
                      ),
                  ),
                  ColumnSeries<ChartData, String>(
                    legendItemText: S.of(context).get('expense_item') ?? "Khoản chi",
                    dataSource:  chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.expense,
                    color: Colors.red,
                    // Width of the columns
                    width: 0.8,
                    // Spacing between the columns
                    spacing: 0.2,
                    animationDuration: 0,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.outer,
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        final chartItem = data as ChartData;
                        if (chartItem.rawExpense == 0) return const SizedBox.shrink();
                        return Text(
                          Utils.currencyFormat(chartItem.rawExpense),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                        );
                      },
                    ),
                  ),
                  // SplineSeries<ChartData, String>(
                  //   dataSource:  chartData,
                  //   splineType: SplineType.cardinal,
                  //   xValueMapper: (ChartData data, _) => data.x,
                  //   yValueMapper: (ChartData data, _) => ((data.income - data.expense) / data.income * 100)  * data.income,
                  //
                  //   color: Colors.blueAccent,
                  //   width: 0.8,
                  //   // Spacing between the columns
                  //   animationDuration: 0,
                  //   // Width of the columns
                  // ),
                ]
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chartType == 0 ? (S.of(context).get('most_spent_group_in_week') ?? "Nhóm chi nhiều nhất trong tuần") : (S.of(context).get('most_spent_group_in_month') ?? "Nhóm chi nhiều nhất trong tháng"),
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if(mostGroupExpense.isNotEmpty)
                  for(final item in mostGroupExpense.entries)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 20.0,
                        child: CustomIcon(iconPath: item.key.icon, size: 40),
                      ),
                      title: Text(Utils.translateGroupName(context, item.key.name),
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text("-${Utils.currencyFormat(item.value)}",
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                if(!mostGroupExpense.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    margin: const EdgeInsets.only(top: 10.0),
                    child: Center(
                      child: Text(S.of(context).get('most_spent_group_empty') ?? "Nhóm chi tiêu nhiều nhất sẽ được hiển thị ở đây!",
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  ChartData(this.x, this.expense, this.income, this.rawExpense, this.rawIncome);
  final String x;
  final double expense;
  final double income;
  final double rawExpense;
  final double rawIncome;
}

