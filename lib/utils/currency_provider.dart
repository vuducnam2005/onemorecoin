import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CurrencyProvider extends ChangeNotifier {
  static String currentCurrency = 'VND';
  String _currency = 'VND';

  String get currency => _currency;

  CurrencyProvider() {
    _loadFromPrefs();
  }

  toggleCurrency(String newCurrency) {
    _currency = newCurrency;
    currentCurrency = newCurrency;
    _saveToPrefs();
    notifyListeners();
  }

  _initPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs;
  }

  _loadFromPrefs() async {
    var prefs = await _initPrefs();
    _currency = prefs.getString('currency') ?? 'VND';
    currentCurrency = _currency;
    notifyListeners();
  }

  _saveToPrefs() async {
    var prefs = await _initPrefs();
    prefs.setString('currency', _currency);
  }

  String format(double amount) {
    if (_currency == 'USD') {
      return "\$" + NumberFormat.currency(customPattern: '#,##0.00', symbol: "", decimalDigits: 2).format(amount / 26294.0);
    }
    return NumberFormat.currency(customPattern: '###,###', symbol: "", decimalDigits: 0).format(amount) + " đ";
  }

  double get rate {
    if (_currency == 'USD') return 1 / 26294.0;
    return 1.0;
  }
}
