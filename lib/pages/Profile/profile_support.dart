import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class ProfileSupportPage extends StatelessWidget {
  const ProfileSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(s.get('support') ?? "Hỗ trợ"),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(Icons.support_agent, color: Theme.of(context).iconTheme.color),
                title: Text("0362183511",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () async {
                  _makePhoneCall("0362183511");
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(Icons.facebook, color: Theme.of(context).iconTheme.color),
                title: Text(
                  "Fanpage OneMoreCoin",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
                onTap: () async {
                  launchUrl(Uri.parse(
                      "https://www.facebook.com/ucnam.382441"));
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(Icons.share, color: Theme.of(context).iconTheme.color),
                title: Text(
                  s.get('share_app') ?? "Chia sẻ ứng dụng",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
                onTap: () async {
                  Share.share(s.get('share_message') ?? 'Quản lý tài chính dễ dàng hơn cùng OneMoreCoin! Tải ngay để trải nghiệm nhé.');
                },
              ),
            )
          ],
        ));
  }
}

Future<void> _makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: phoneNumber,
  );
  await launchUrl(launchUri);
}
