import 'package:flutter/material.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/model/BudgetModel.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/Widgets/AlertDiaLog.dart';
import 'package:onemorecoin/Objects/AlertDiaLogItem.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class ListWalletPage extends StatefulWidget {
  const ListWalletPage({
    super.key,
    required this.wallet,
    this.showWalletGlobal = false
  });
  final WalletModel wallet;
  final bool showWalletGlobal;

  @override
  State<ListWalletPage> createState() => _ListWalletPageState();
}

class _ListWalletPageState extends State<ListWalletPage> {

  late WalletModel _globalWallet;
  late WalletModel _wallet;
  List<WalletModel> walletsReport = [];
  List<WalletModel> walletsNotReport = [];

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = S.of(context);
    _globalWallet = WalletModel(0, name: s.get('all_wallets') ?? "Tất cả các ví", icon: null, currency: "VND");
    if(widget.showWalletGlobal){
      double totalAmount = context.read<WalletModelProxy>().getAll().fold(0, (previousValue, element) => previousValue + element.balance!);
      _globalWallet.balance = totalAmount;
    }
  }

  _generateWalletsReport(){
    walletsReport = [];
    walletsNotReport = [];
    var allWallets = context.watch<WalletModelProxy>().getAll();
    for(var i = 0; i < allWallets.length; i++){
      if(allWallets[i].isReport){
        walletsReport.add(allWallets[i]);
      }else{
        walletsNotReport.add(allWallets[i]);
      }
    }
  }

  _navigatorPop(BuildContext context){
    context.read<TransactionModelProxy>().walletModel = _wallet;
    if(Navigator.canPop(context)){
      Navigator.pop(context, {
        'wallet': _wallet,
      });
    }else{
      Navigator.of(context, rootNavigator: true).pop(
          {
            'wallet': _wallet,
          }
      );
    }
  }

  _deleteWallet(WalletModel wallet) {
    final s = S.of(context);
    if (wallet.id == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(s.get('cannot_delete_main_wallet') ?? "Không thể xoá ví chính"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showAlertDialog(
      context: context,
      title: Text("${s.get('confirm_delete_wallet') ?? 'Bạn có chắc chắn muốn xoá ví '}${wallet.name}?"),
      content: Text(s.get('wallet_delete_warning') ?? "Tất cả các giao dịch và ngân sách thuộc ví này cũng sẽ bị thu hồi và xoá vĩnh viễn."),
      optionItems: [
        AlertDiaLogItem(
          text: s.get('delete') ?? "Xoá",
          textStyle: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.normal
          ),
          okOnPressed: () async {
            await context.read<WalletModelProxy>().delete(wallet);
            await context.read<TransactionModelProxy>().fetchAll();
            await context.read<BudgetModelProxy>().fetchAll();

            if (!mounted) return;
            if (_wallet.id == wallet.id) {
              setState(() {
                _wallet = _globalWallet;
              });
              context.read<TransactionModelProxy>().walletModel = _wallet;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${s.get('deleted_wallet_success') ?? 'Đã xoá ví '}${wallet.name}"),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _generateWalletsReport();
            setState(() {});
          },
        ),
      ],
      cancelItem: AlertDiaLogItem(
        text: s.get('cancel') ?? "Huỷ",
        textStyle: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.normal
        ),
        okOnPressed: () {},
      ),
    );
  }

  _showWalletOptions(BuildContext context, WalletModel wallet) {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(s.get('edit_wallet') ?? 'Sửa ví'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, "/AddWalletPage", arguments: wallet).then((_) {
                    setState(() {});
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(s.get('delete') ?? 'Xoá'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteWallet(wallet);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _generateWalletsReport();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // surfaceTintColor: Colors.transparent,
        leadingWidth: 70,
        leading: widget.showWalletGlobal ?  FittedBox(
          fit: BoxFit.scaleDown,
          child: TextButton(
            child: Text(
                S.of(context).get('close') ?? 'Đóng',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                )
            ),
            onPressed: () {
              _navigatorPop(context);
            },
          ),
        ) : null,
        title: Text(S.of(context).get('select_wallet') ?? 'Chọn ví', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Container(
            child: ListView(
              children: [
                if(widget.showWalletGlobal)
                  Container(
                    padding: EdgeInsets.only(top: 20, left: 20),
                    width: double.infinity,
                    child: Text(S.of(context).get('all_wallets') ?? "Tất cả các ví",
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 17
                        )
                    ),
                  ),
                if(widget.showWalletGlobal)
                  Container(
                  color: Theme.of(context).cardColor,
                  child:  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.language_outlined, color: Colors.green, size: 40,)
                    ),
                    title: Text("${_globalWallet.name}", style: TextStyle(fontSize: 20)),
                    subtitle: Text(Utils.currencyFormat(_globalWallet.balance!)),
                    trailing: Icon(Icons.check_circle, color: _wallet.id == _globalWallet.id ? Colors.green : Colors.grey,),
                    onTap: () {
                      setState(() {
                        _wallet = _globalWallet;
                      });
                      _navigatorPop(context);
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.only(top: 20, left: 20),
                  width: double.infinity,
                  child: Text(S.of(context).get('include_in_report') ?? "Tính vào báo cáo",
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 17
                      )
                  ),
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  child:  Column(
                      children: walletsReport.map((e) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: CustomIcon(iconPath: e.icon, size: 40),
                      ),
                      title: Text(Utils.translateWalletName(context, e.name), style: TextStyle(fontSize: 20)),
                      subtitle: Text(Utils.currencyFormat(e.balance!)),
                      trailing: Icon(Icons.check_circle, color: e.id == _wallet.id ? Colors.green : Colors.grey,),
                      onTap: () {
                        setState(() {
                          _wallet = e;
                        });
                        _navigatorPop(context);
                      },
                      onLongPress: () {
                        _showWalletOptions(context, e);
                      },
                    )).toList(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 20, left: 20),
                  width: double.infinity,
                  child: Text(S.of(context).get('exclude_from_report') ?? "Không tính vào báo cáo",
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 17
                      )
                  ),
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  child:  Column(
                    children: walletsNotReport.map((e) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: CustomIcon(iconPath: e.icon, size: 40),
                      ),
                      title: Text(Utils.translateWalletName(context, e.name), style: TextStyle(fontSize: 20)),
                      subtitle: Text(Utils.currencyFormat(e.balance!)),
                      trailing: Icon(Icons.check_circle, color: e.id == _wallet.id ? Colors.green : Colors.grey,),
                      onTap: () {
                        setState(() {
                          _wallet = e;
                        });
                        _navigatorPop(context);
                      },
                      onLongPress: () {
                        _showWalletOptions(context, e);
                      },
                    )).toList(),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20),
                  color: Theme.of(context).cardColor,
                  child:  Column(
                    children: [
                      Material(
                        child: ListTile(
                          leading: const Icon(Icons.add_circle, color: Colors.green),
                          title: Text(S.of(context).get('add_new_wallet') ?? "Thêm ví mới", style: const TextStyle(fontSize: 20, color: Colors.green)),
                          onTap: () {
                            Navigator.pushNamed(context, "/AddWalletPage");
                          },
                        ),
                      )
                    ],
                  ),
                )
              ],
            )
        ),
      ),
    );
  }
}
