import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onemorecoin/commons/Constants.dart';
import 'package:provider/provider.dart';

import '../../../model/WalletModel.dart';
import '../../../utils/Utils.dart';
import '../../../widgets/ShowSwitch.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class AddWalletPage extends StatefulWidget {
  final WalletModel? editWallet;
  const AddWalletPage({super.key, this.editWallet});

  @override
  State<AddWalletPage> createState() => _AddWalletPageState();
}

class _AddWalletPageState extends State<AddWalletPage> {
  // _isSubmit is no longer needed with Form validate
  String _icon = "assets/images/vietnam.png";
  String _currency = "VND" ;
  String _iconCurrency = "assets/images/vietnam.png" ;
  bool _isAddToReport = true;

  final inputName = TextEditingController();
  final inputBalance = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _balance = 0;

  void _onCreateWallet(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      var wallets = context.read<WalletModelProxy>();
      
      if (widget.editWallet != null) {
        // Edit Mode
        var updatedWallet = widget.editWallet!;
        updatedWallet.name = inputName.text;
        updatedWallet.icon = _icon;
        updatedWallet.currency = _currency;
        updatedWallet.isReport = _isAddToReport;
        wallets.update(updatedWallet);
      } else {
        // Create Mode
        wallets.add(
            WalletModel(
                wallets.getId(),
                name: inputName.text,
                icon: _icon,
                currency: _currency,
                balance: _balance,
                isReport: _isAddToReport,
            )
        );
      }

      Navigator.pop(context, {
        'name': inputName.text,
        'icon': _icon,
      });
    }
  }

  // Removed checkSubmit as we use Form validate now

  @override
  void initState() {
    super.initState();
    if (widget.editWallet != null) {
      inputName.text = widget.editWallet!.name ?? "";
      _icon = widget.editWallet!.icon ?? "assets/images/vietnam.png";
      _currency = widget.editWallet!.currency ?? "VND";
      _isAddToReport = widget.editWallet!.isReport;
      // Convert balance to string without formatting for the input, or just raw formatting
      inputBalance.text = Utils.currencyFormat(widget.editWallet!.balance ?? 0, withoutUnit: true, rawFormat: true);
      _balance = widget.editWallet!.balance ?? 0;
      
      if (_currency == "USD") {
        _iconCurrency = "assets/images/icon_wallet_primary.png";
      } else {
        _iconCurrency = "assets/images/vietnam.png";
      }
    } else {
      inputBalance.text = "0";
    }

    inputBalance.addListener(() {
          double parsedBalance = inputBalance.text.isEmpty ? 0 : Utils.unCurrencyFormat(inputBalance.text);
          _balance = _currency == 'USD' ? parsedBalance * 26294.0 : parsedBalance;
        }
    );
  }

  @override
  void dispose() {
    inputName.dispose();
    inputBalance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // hide keyboard
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.editWallet != null ? (S.of(context).get('edit_wallet') ?? "Sửa ví") : (S.of(context).get('add_wallet') ?? "Thêm ví"), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.0),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    Container(
                      width: 80.0,
                      child: Material(
                        child: InkWell(
                            onTap: () async {
                              dynamic result = await Navigator.of(context).pushNamed("/ListIconPage");
                              if(result != null){
                                setState(() {
                                  _icon = result['icon'];
                                });
                              }
                            },
                            child: CircleAvatar(
                                backgroundColor: !_icon.isEmpty ? Colors.transparent : Colors.grey,
                                radius: 30.0,
                                child: _icon.isEmpty ? Icon(Icons.add, size: 30.0, color: Colors.white) : CustomIcon(iconPath: _icon, size: 40)
                            )
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: inputName,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: S.of(context).get('wallet_name') ?? 'Tên ví',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return S.of(context).get('please_enter_wallet_name') ?? 'Vui lòng nhập tên ví';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 5.0)),
              Container(
                height: 50.0,
                color: Theme.of(context).cardColor,
                child: Material(
                  child: InkWell(
                    onTap: () async {
                      dynamic result = await Navigator.of(context).pushNamed("/ListCurrencyPage");
                      if(result != null){
                        setState(() {
                          _currency = result['currency'];
                          _iconCurrency = result['icon'];
                          double parsedBalance = inputBalance.text.isEmpty ? 0 : Utils.unCurrencyFormat(inputBalance.text);
                          _balance = _currency == 'USD' ? parsedBalance * 26294.0 : parsedBalance;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 80.0,
                          child: CustomIcon(iconPath: _iconCurrency, size: 40),
                        ),
                        Expanded(
                            child: Text(_currency, style: TextStyle(fontSize: 20.0))
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 5.0)),
              Container(
                height: 50.0,
                color: Theme.of(context).cardColor,
                child: Material(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80.0,
                      ),
                      Expanded(
                        child: TextFormField(
                          enabled: widget.editWallet == null, // Disable editing balance
                          keyboardType: TextInputType.number,
                          controller: inputBalance,
                          maxLength: Constants.MAX_LENGTH_AMOUNT_INPUT,
                          inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue)  {
                                String value = newValue.text.isEmpty ? "0" : Utils.currencyFormat(Utils.unCurrencyFormat(newValue.text), withoutUnit: true, rawFormat: true);
                            return newValue.copyWith(
                                text: value,
                                selection: TextSelection.collapsed(offset: value.length)
                            );
                          })],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).get('please_enter_balance') ?? 'Vui lòng nhập số dư';
                            }
                            double? amount = double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
                            if (amount == null || amount < 0) {
                              return S.of(context).get('invalid_balance') ?? 'Số dư không hợp lệ';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            counterText: "",
                            border: const OutlineInputBorder(),
                            labelText: S.of(context).get('initial_balance') ?? 'Số dư ban đầu',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 10.0)),
              Container(
                color: Theme.of(context).cardColor,
                height: 50.0,
                padding: const EdgeInsets.only(left: 15.0),
                child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment
                              .centerLeft,
                          child: Text(
                              S.of(context).get('include_in_report') ?? "Tính vào báo cáo"),
                        ),
                      ),
                      Container(
                          margin: const EdgeInsets
                              .only(right: 10.0),
                          child: showSwitch(
                            value: _isAddToReport,
                            onChanged: (value) {
                              setState(() {
                                _isAddToReport =
                                    value;
                              });
                            },
                          )
                      ),
                    ]
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 10.0)),
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    _onCreateWallet(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    fixedSize: Size(MediaQuery.of(context).size.width - 30, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32.0),
                    ),
                  ),
                  child: Text(widget.editWallet != null ? (S.of(context).get('save') ?? 'Lưu') : (S.of(context).get('create_wallet') ?? 'Tạo ví')),
                ),
              )
            ],
          ),
          ),
        ),
      ),
    );
  }
}
