import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ListIconPage extends StatelessWidget {
  const ListIconPage({super.key});


  @override
  Widget build(BuildContext context) {
    List<IconData> icons = [
      Icons.fastfood,
      Icons.local_cafe,
      Icons.restaurant,
      Icons.directions_car,
      Icons.local_taxi,
      Icons.directions_bus,
      Icons.flight,
      Icons.shopping_cart,
      Icons.shopping_bag,
      Icons.local_mall,
      Icons.home,
      Icons.weekend,
      Icons.tv,
      Icons.local_hospital,
      Icons.medical_services,
      Icons.school,
      Icons.menu_book,
      Icons.monetization_on,
      Icons.attach_money,
      Icons.account_balance,
      Icons.pets,
      Icons.fitness_center,
      Icons.sports_esports,
      Icons.group,
      Icons.favorite,
      Icons.card_giftcard,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: ModalScrollController.of(context),
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid.count(
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                crossAxisCount: 5,
                children: <Widget>[
                  for (var i = 0; i < icons.length; i++)
                    InkWell(
                      onTap: () {
                        Navigator.pop(context, {
                          'icon': icons[i].codePoint.toString()
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(icons[i], size: 40, color: Colors.blueGrey),
                        color: Colors.grey[100],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }
}
