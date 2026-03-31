
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class MyDateUtils {

  static List<DateTime> getFromToMonth(DateTime dateTime) {
    DateTime start = convertDateTimeDisplay(DateTime(dateTime.year, dateTime.month, 1));
    DateTime end = convertDateTimeFullDay(DateTime(dateTime.year, dateTime.month, getDaysInMonth(dateTime.year, dateTime.month)));
    return [start, end];
  }

  static List<DateTime> getFromToMonthFromString(String dateTime) {
    return getFromToMonth(DateTime.parse(dateTime));
  }

  static List<DateTime> getFromToWeek(DateTime dateTime) {
    DateTime start = convertDateTimeDisplay(dateTime.subtract(Duration(days: dateTime.weekday - 1)));
    DateTime end = convertDateTimeFullDay(dateTime.add(Duration(days: DateTime.daysPerWeek - dateTime.weekday)));
    return [start, end];
  }

  static List<DateTime> getFromToWeekFromString(String dateTime) {
    return getFromToWeek(DateTime.parse(dateTime));
  }

  static List<DateTime> getFromToQuarter(DateTime dateTime) {
    DateTime dayStartOfQuarter = dateTime;
    if(dateTime.month % 3 == 0){
      dayStartOfQuarter = DateTime(dateTime.year, dateTime.month - 2, 1);
    }
    if(dateTime.month % 3 == 1){
      dayStartOfQuarter = DateTime(dateTime.year, dateTime.month, 1);
    }
    if(dateTime.month % 3 == 2){
      dayStartOfQuarter = DateTime(dateTime.year, dateTime.month - 1, 1);
    }

    DateTime start = convertDateTimeDisplay(DateTime(dayStartOfQuarter.year, dayStartOfQuarter.month, 1));
    DateTime end = convertDateTimeFullDay(DateTime(dayStartOfQuarter.year, dayStartOfQuarter.month + 3, 0));
    return [start, end];
  }

  static List<DateTime> getFromToQuarterFromString(String dateTime) {
    return getFromToQuarter(DateTime.parse(dateTime));
  }

  static List<DateTime> getFromToYear(DateTime dateTime) {
    DateTime start = convertDateTimeDisplay(DateTime(dateTime.year, 1, 1));
    DateTime end = convertDateTimeFullDay(DateTime(dateTime.year, 12, 31));
    return [start, end];
  }

  static DateTime dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static int getDateInMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day).day;
  }

  static int getDateInMonthFromString(String dateTime) {
    return DateTime.parse(dateTime).day;
  }

  static String getNameDayOfWeekFromString(String dateTime, {BuildContext? context}) {
    return getNameDayOfWeek(DateTime.parse(dateTime), context: context);
  }

  static String getMonthAndYearFromString(String dateTime, {BuildContext? context}) {
    return getMonthAndYear(DateTime.parse(dateTime), context: context);
  }

  static String getMonthAndYear(DateTime dateTime, {BuildContext? context}) {
    if (context != null) {
      final lang = S.of(context).languageCode;
      if (lang == 'en') {
        return "${DateFormat('MMMM yyyy', 'en').format(dateTime)}";
      }
      return "${S.of(context).get('month_label') ?? 'tháng'} ${dateTime.month} ${dateTime.year}";
    }
    return "tháng ${dateTime.month} ${dateTime.year}";
  }

  static String toStringFormat00(DateTime dateTime, {BuildContext? context}) {
    return "${getNameDayOfWeek(dateTime, context: context)}, ${dateTime.day} ${context != null ? S.of(context).get('month_label') ?? 'tháng' : 'tháng'} ${dateTime.month} ${dateTime.year}";
  }

  static String toStringFormat00FromString(String dateTime, {BuildContext? context}) {
    return toStringFormat00(DateTime.parse(dateTime), context: context);
  }

  static String toStringFormat01(DateTime dateTime, {BuildContext? context}) {
    if (context != null) {
      return "${dateTime.day} ${S.of(context).get('month_label') ?? 'thg'} ${dateTime.month} ${dateTime.year}";
    }
    return "${dateTime.day} thg ${dateTime.month} ${dateTime.year}";
  }

  static String toStringFormat01FromString(String dateTime, {BuildContext? context}) {
    return toStringFormat01(DateTime.parse(dateTime), context: context);
  }

  static String toStringFormat02(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  static String toStringFormat02FromString(String? dateTime) {
    return toStringFormat02(DateTime.parse(dateTime!));
  }

  static String getNameDayOfWeek(DateTime dateTime, {BuildContext? context}) {
    if (context != null) {
      final s = S.of(context);
      final lang = s.languageCode;
      
      final now = dateOnly(DateTime.now());
      final target = dateOnly(dateTime);
      final diff = now.difference(target).inDays;

      if (diff == 0) return s.get('today') ?? (lang == 'vi' ? 'Hôm nay' : 'Today');
      if (diff == 1) return s.get('yesterday') ?? (lang == 'vi' ? 'Hôm qua' : 'Yesterday');
      if (diff == 2) return s.get('day_before_yesterday') ?? (lang == 'vi' ? 'Hôm kia' : 'Day before yesterday');

      if (lang == 'en') {
        switch (dateTime.weekday) {
          case 1: return 'Monday';
          case 2: return 'Tuesday';
          case 3: return 'Wednesday';
          case 4: return 'Thursday';
          case 5: return 'Friday';
          case 6: return 'Saturday';
          case 7: return 'Sunday';
        }
      }
      switch (dateTime.weekday) {
        case 1: return s.get('monday') ?? 'Thứ hai';
        case 2: return s.get('tuesday') ?? 'Thứ ba';
        case 3: return s.get('wednesday') ?? 'Thứ tư';
        case 4: return s.get('thursday') ?? 'Thứ năm';
        case 5: return s.get('friday') ?? 'Thứ sáu';
        case 6: return s.get('saturday') ?? 'Thứ bảy';
        case 7: return s.get('sunday') ?? 'Chủ nhật';
      }
      return '';
    }
    switch (dateTime.weekday) {
      case 1: return "Thứ hai";
      case 2: return "Thứ ba";
      case 3: return "Thứ tư";
      case 4: return "Thứ năm";
      case 5: return "Thứ sáu";
      case 6: return "Thứ bảy";
      case 7: return "Chủ nhật";
    }
    return "";
  }

  static bool isBetween(DateTime dateTime, DateTime start, DateTime end) {
    return dateTime.isAfter(start.subtract( const Duration(seconds: 1))) && dateTime.isBefore(end);
  }

  static bool isBetweenDateOnly(DateTime dateTime, DateTime start, DateTime end) {
    return dateOnly(dateTime).isAfter(dateOnly(start).subtract( const Duration(seconds: 1))) && dateOnly(dateTime).isBefore(dateOnly(end));
  }

  static bool isAfterDateOnly(DateTime dateTime, DateTime start) {
    return dateOnly(dateTime).isAfter(dateOnly(start));
  }

  static bool isAfter(DateTime dateTime, DateTime start) {
    return dateTime.isAfter(start.subtract( const Duration(seconds: 1)));
  }

  static bool isBefore(DateTime dateTime, DateTime end) {
    return dateTime.isBefore(end.add(Duration(seconds: 1)));
  }

  static bool isBeforeDateOnly(DateTime dateTime, DateTime end) {
    return dateOnly(dateTime).isBefore(dateOnly(end));
  }

  static String parseTypeToString(String? budgetType, {BuildContext? context}) {
    if (context != null) {
      final s = S.of(context);
      switch (budgetType) {
        case 'week': return s.get('week') ?? 'Tuần';
        case 'month': return s.get('month') ?? 'Tháng';
        case 'quarter': return s.get('quarter') ?? 'Quý';
        case 'year': return s.get('year') ?? 'Năm';
      }
      return '';
    }
    switch (budgetType) {
      case "week": return "Tuần";
      case "month": return "Tháng";
      case "quarter": return "Quý";
      case "year": return "Năm";
    }
    return "";
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

  static Duration getDuration(DateTime start, DateTime end) {
    return end.difference(start);
  }

  static String getDurationString(DateTime start, DateTime end, {BuildContext? context}) {
    Duration duration = getDuration(start, end);
    String h = context != null ? S.of(context).get('hours') ?? 'giờ' : 'giờ';
    return "${duration.inHours} $h ${duration.inMinutes.remainder(60)} phút";
  }

  static String subtractTimeToDay(DateTime start, DateTime end, {BuildContext? context}) {
    final Duration duration = getDuration(start, end);
    if(duration.inDays == 0){
      return "${duration.inHours} ${context != null ? S.of(context).get('hours') ?? 'giờ' : 'giờ'}";
    }
    return "${duration.inDays} ${context != null ? S.of(context).get('days') ?? 'ngày' : 'ngày'}";
  }

  static int parseBudgetTypeToDay(String s) {
    switch (s) {
      case "week":
        return 6;
      case "month":
        return 30;
      case "quarter":
        return 90;
      case "year":
        return 365;
    }
    return 0;
  }

  static isSameDate(DateTime dateTime, DateTime parse) {
    return dateTime.year == parse.year && dateTime.month == parse.month && dateTime.day == parse.day;
  }
}