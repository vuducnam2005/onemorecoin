import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ListCurrencyPage extends StatelessWidget {
  const ListCurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    Map<String, String> currency = {
      "VND": "assets/images/vietnam.png",
      "USD": "assets/images/icon_wallet_primary.png",
    };
    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text('Đơn vị tiền tệ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: ListView(
            controller: ModalScrollController.of(context),
            primary: false,
            children: [
            for (MapEntry<String, String> item in currency.entries)
                Container(
                  margin: EdgeInsets.only(top: 5.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context, {
                        'currency': item.key,
                        'icon': item.value,
                      });
                    },
                    child: Container(
                      height: 50.0,
                      color: Colors.white,
                      child: Row(
                        children: [
                          Container(
                            width: 80.0,
                            child: Image.asset(item.value),
                          ),
                          Text(item.key)
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        )
    );
  }
}
