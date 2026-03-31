import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/model/BudgetModel.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:onemorecoin/utils/MyDateUtils.dart';
import '../Objects/ShowType.dart';
import '../Objects/TabTransaction.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class Utils {

  static String translateTabName(BuildContext context, String name) {
    if (name.startsWith("Tháng ")) {
      return "${S.of(context).get('month') ?? 'Month'} ${name.substring(6)}";
    }
    switch (name) {
      case "HÔM KIA": return S.of(context).get('day_before_yesterday_caps') ?? "DAY BEFORE YESTERDAY";
      case "HÔM QUA": return S.of(context).get('yesterday_caps') ?? "YESTERDAY";
      case "HÔM NAY": return S.of(context).get('today_caps') ?? "TODAY";
      case "TUẦN TRƯỚC": return S.of(context).get('last_week_caps') ?? "TUẦN TRƯỚC";
      case "TUẦN NÀY": return S.of(context).get('this_week_caps') ?? "TUẦN NÀY";
      case "THÁNG TRƯỚC": return S.of(context).get('last_month_caps') ?? "THÁNG TRƯỚC";
      case "THÁNG NÀY": return S.of(context).get('this_month_caps') ?? "THÁNG NÀY";
      case "NĂM TRƯỚC": return S.of(context).get('last_year_caps') ?? "NĂM TRƯỚC";
      case "NĂM NÀY": return S.of(context).get('this_year_caps') ?? "NĂM NÀY";
      case "TƯƠNG LAI": return S.of(context).get('future_caps') ?? "TƯƠNG LAI";
      case "TẤT CẢ GIAO DỊCH": return S.of(context).get('all_transactions_caps') ?? "TẤT CẢ GIAO DỊCH";
      default: return name;
    }
  }

  static String translateWalletName(BuildContext context, String? name) {
    if (name == null || name.isEmpty) return S.of(context).get('all_wallets') ?? 'Tất cả các ví';
    if (name == 'Ví chính' || name == 'Main Wallet') {
      return S.of(context).get('main_wallet') ?? 'Ví chính';
    }
    if (name == 'Tất cả các ví' || name == 'All Wallets') {
      return S.of(context).get('all_wallets') ?? 'Tất cả các ví';
    }
    return name;
  }

  static const Map<String, String> _groupNameTranslations = {
    'Ăn uống': 'Food & Drink',
    'Di chuyển': 'Transport',
    'Mua sắm': 'Shopping',
    'Sức khỏe': 'Health',
    'Giải trí': 'Entertainment',
    'Tiền nhà': 'Rent',
    'Tiền nước': 'Water Bill',
    'Tiền internet': 'Internet',
    'Tiền điện thoại': 'Phone Bill',
    'Tiền học': 'Education',
    'Tiền khác': 'Other Expense',
    'Lương': 'Salary',
    'Thưởng': 'Bonus',
    'Lãi': 'Interest',
    'Bán đồ': 'Selling',
    'Khác': 'Other',
    'Cho vay': 'Lending',
    'Thu nợ': 'Debt Collection',
    'Đi vay': 'Borrowing',
    'Trả nợ': 'Repayment',
    'Thanh toán hóa đơn': 'Bill Payment',
    'Cafe': 'Coffee',
    'Đi lại': 'Transport',
  };

  static String translateGroupName(BuildContext context, String? name) {
    if (name == null) return '';
    final lang = S.of(context).languageCode;
    if (lang == 'en' && _groupNameTranslations.containsKey(name)) {
      return _groupNameTranslations[name]!;
    }
    return name;
  }

  static List<TabTransaction> getListTabShowTypeTransaction(ShowType showType, int totalTab)  {
    List<TabTransaction> listTab = [];
    switch (showType) {
      case ShowType.date:
        listTab = Utils.getListDateBackToNow(totalTab);
        for(int i = 0; i < listTab.length; i++){
          if(i == totalTab - 2){
            listTab[i].name = "HÔM KIA";
          }
          if(i == totalTab - 1){
            listTab[i].name = "HÔM QUA";
          }
          if(i == totalTab){
            listTab[i].name = "HÔM NAY";
          }
        }
        listTab.add(TabTransaction("TƯƠNG LAI", listTab.last.to.add(const Duration(seconds: 1)), listTab.last.to.add(const Duration(seconds: 1)))..isFuture = true);
        break;
      case ShowType.week:
        listTab = Utils.getListWeekBackToNow(totalTab);
        for(int i = 0; i < listTab.length; i++){
          if(i == totalTab - 1){
            listTab[i].name = "TUẦN TRƯỚC";
          }
          if(i == totalTab){
            listTab[i].name = "TUẦN NÀY";
          }
        }
        listTab.add(TabTransaction("TƯƠNG LAI", listTab.last.to.subtract(const Duration(seconds: 1)), listTab.last.to.add(const Duration(seconds: 7)))..isFuture = true);
        break;
      case ShowType.month:
        listTab = Utils.getListMonthBackToNow(totalTab);

        for(int i = 0; i < listTab.length; i++){
          if(i == totalTab - 1){
            listTab[i].name = "THÁNG TRƯỚC";
          }
          if(i == totalTab){
            listTab[i].name = "THÁNG NÀY";
          }
        }
        listTab.add(TabTransaction("TƯƠNG LAI", listTab.last.to.add(const Duration(seconds: 1)), listTab.last.to.add(const Duration(seconds: 1)))..isFuture = true);
         break;
      case ShowType.quarter:
        listTab = Utils.getListQuarterBackToNow(totalTab);
        listTab.add(TabTransaction("TƯƠNG LAI", listTab.last.to.add(const Duration(seconds: 1)), listTab.last.to.add(const Duration(seconds: 1)))..isFuture = true);
        break;
      case ShowType.year:
        listTab = Utils.getListYearBackToNow(totalTab);
        for(int i = 0; i < listTab.length; i++){
          if(i == totalTab - 1){
            listTab[i].name = "NĂM TRƯỚC";
          }
          if(i == totalTab){
            listTab[i].name = "NĂM NÀY";
          }
        }
        listTab.add(TabTransaction("TƯƠNG LAI", listTab.last.to.add(const Duration(seconds: 1)), listTab.last.to.add(const Duration(seconds: 1)))..isFuture = true);
        break;
      case ShowType.all:
        TabTransaction tab = TabTransaction("TẤT CẢ GIAO DỊCH", DateTime(2000, 1, 1), DateTime.now());
        tab.isAll = true;
        listTab.add(tab);
        break;
      // case ShowType.option:
      //   listTab.add("TẤT CẢ GIAO DỊCH");
      //   break;
        // TODO: Handle this case.
      case ShowType.option:
        // TODO: Handle this case.
    }
    return listTab;
  }

  static DateTime convertDateTimeDisplay(DateTime date) {
    return DateUtils.dateOnly(date);
  }

  static DateTime convertDateTimeFullDay(DateTime date) {
    final DateFormat serverFormater = DateFormat('dd-MM-yyyy');
    final String formatted = serverFormater.format(date);
    DateTime dateTime = serverFormater.parse(formatted)
        .add(const Duration(hours: 23))
        .add(const Duration(minutes: 59))
        .add(const Duration(seconds: 59));
    return dateTime;
  }

  static String dateToString(DateTime dateTime){
    return "${dateTime.day}-${dateTime.month}-${dateTime.year}";
  }

  static List<TabTransaction> getListDateBackToNow(int number){
    List<TabTransaction> list = [];
    DateTime now = DateTime.now();
    while(number >= 0){
      DateTime day = now.subtract(Duration(days: number));
      list.add(TabTransaction("${day.day}/${day.month}/${day.year}", convertDateTimeDisplay(day), convertDateTimeFullDay(day)));
      number--;
    }
    return list;
  }

  static List<TabTransaction> getListWeekBackToNow(int number){
    List<TabTransaction> list = [];
    DateTime now = DateTime.now();
    DateTime dayEndWeed = now.add(Duration(days: (DateTime.daysPerWeek - now.weekday - 7)));
    while(number >= 0){
      DateTime start = dayEndWeed.subtract(Duration(days: number * DateTime.daysPerWeek - 1 ));
      DateTime end = start.add(const Duration(days: DateTime.daysPerWeek - 1));
      list.add(TabTransaction("${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}", convertDateTimeDisplay(start), convertDateTimeFullDay(end)));
      number--;
    }
    return list;
  }

  static List<TabTransaction> getListMonthBackToNow(int number){
    List<TabTransaction> list = [];
    DateTime now = DateTime.now();
    DateTime monthStart = DateTime(now.year, now.month, 1);
    while(number >= 0){
      DateTime start = DateTime(monthStart.year, monthStart.month - number, 1);
      list.add(TabTransaction("${start.month}/${start.year}", convertDateTimeDisplay(start), convertDateTimeFullDay(DateTime(start.year, start.month, 1).add(Duration(days: DateUtils.getDaysInMonth(start.year, start.month) - 1)))));
      number--;
    }
    return list;
  }

  static List<TabTransaction> getListQuarterBackToNow(int number){
    List<TabTransaction> list = [];
    DateTime now = DateTime.now();
    DateTime dayStartOfQuarter = now;
    if(now.month % 3 == 0){
      dayStartOfQuarter = DateTime(now.year, now.month - 2, 1);
    }
    if(now.month % 3 == 1){
      dayStartOfQuarter = DateTime(now.year, now.month, 1);
    }
    if(now.month % 3 == 2){
      dayStartOfQuarter = DateTime(now.year, now.month - 1, 1);
    }
    while(number >= 0){
      DateTime start = DateTime(dayStartOfQuarter.year , dayStartOfQuarter.month - number * 3 , 1);
      DateTime end = DateTime(start.year , start.month + 2 , 1);

      list.add(TabTransaction("Q${(start.month / 3).ceil() }/${start.year}", convertDateTimeDisplay(start), convertDateTimeFullDay(end.add(Duration(days: DateUtils.getDaysInMonth(end.year, end.month) - 1)))));
      number--;
    }
    return list;
  }

  static List<TabTransaction> getListYearBackToNow(int number){
    List<TabTransaction> list = [];
    DateTime now = DateTime.now();
    while(number >= 0){
      DateTime start = DateTime(now.year - number, 1 , 1);
      DateTime end = DateTime(now.year - number, 12 , 1).add(Duration(days: DateUtils.getDaysInMonth(start.year, 12) - 1));

      list.add(TabTransaction("${start.year}", convertDateTimeDisplay(start), convertDateTimeFullDay(end)));
      number--;
    }
    return list;
  }

  static String getStringFormatDayOfWeek(DateTime dateTime, {BuildContext? context}){
    String dayName = MyDateUtils.getNameDayOfWeek(dateTime, context: context);
    String monthLabel = context != null ? S.of(context).get('month_label') ?? 'tháng' : 'tháng';
    return "$dayName, ${dateTime.day} $monthLabel ${dateTime.month} ${dateTime.year}";
  }

  static String getStringFormatDateAndTime(DateTime dateTime, {BuildContext? context}){
    String monthLabel = context != null ? S.of(context).get('month_label') ?? 'tháng' : 'tháng';
    return "${dateTime.day} $monthLabel ${dateTime.month} ${dateTime.year} - ${dateTime.hour}:${dateTime.minute}";
  }

  static double sumAmountTransaction(List<TransactionModel> transactionModels){
    double sum = 0;
    for(TransactionModel transactionModel in transactionModels){
      if(transactionModel.type == "expense"){
        sum -= transactionModel.amount!;
      }
      else{
        sum += transactionModel.amount!;
      }
    }
    return sum;
  }

  static double sumExpenseAmountTransaction(List<TransactionModel> transactionModels){
    double sum = 0;
    for(TransactionModel transactionModel in transactionModels){
      if(transactionModel.type == "expense"){
        sum += transactionModel.amount!;
      }
    }
    return sum;
  }

  static double sumIncomeAmountTransaction(List<TransactionModel> transactionModels){
    double sum = 0;
    for(TransactionModel transactionModel in transactionModels){
      if(transactionModel.type == "income"){
        sum += transactionModel.amount!;
      }
    }
    return sum;
  }


  static double sumAmountTransactionToDate(List<TransactionModel> transactionModels, DateTime dateTime){
    double sum = 0;
    for(TransactionModel transactionModel in transactionModels){
      if(transactionModel.type == "expense" && MyDateUtils.isBefore(DateTime.parse(transactionModel.date!), dateTime)){
        sum -= transactionModel.amount!;
      }
      else if(transactionModel.type == "income" && MyDateUtils.isBefore(DateTime.parse(transactionModel.date!), dateTime)){
        sum += transactionModel.amount!;
      }
    }
    return sum;
  }

  static double sumBudget(List<BudgetModel> budgetModels){
    double sum = 0;
    for(BudgetModel budgetModel in budgetModels){
      sum += budgetModel.budget!;
    }
    return sum;
  }

  static double sumBudgetAmountTransaction(List<BudgetModel> budgetModels, TransactionModelProxy transactionModelProxy){
    double sum = 0;
    for(BudgetModel budgetModel in budgetModels){
      sum += sumAmountTransaction(transactionModelProxy.getAllForBudget(budgetModel.groupId, budgetModel.walletId, budgetModel.fromDate, budgetModel.toDate));
    }
    return sum;
  }

  static String currencyFormat(double amount, {bool withoutUnit = false, bool rawFormat = false}) {
    if (!rawFormat && CurrencyProvider.currentCurrency == 'USD') {
      String formatted = NumberFormat.currency(customPattern: '#,##0.00', symbol: "", decimalDigits: 2).format(amount / 26294.0);
      return withoutUnit ? formatted : "\$" + formatted;
    }
    String result =  NumberFormat.currency(customPattern: '###,###', symbol: "", decimalDigits: 0).format(amount);
    return withoutUnit ? result : result + " VND";
  }

  static String currencyFormatShort(double amount) {
    if (CurrencyProvider.currentCurrency == 'USD') {
      return "\$" + NumberFormat.currency(customPattern: '#,##0.00', symbol: "", decimalDigits: 2).format(amount / 26294.0);
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  static double unCurrencyFormat(String amount) {
    String result = amount.replaceAll(RegExp(r'[^\d.-]'), "");
    if (result.isEmpty || result == '-' || result == '.') return 0.0;
    return double.parse(result);
  }


}