import 'package:flutter/material.dart';
import 'package:onemorecoin/utils/Utils.dart';
import '../../../widgets/ShowSwitch.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class AddNotificationPage extends StatefulWidget {
  final DateTime? selectDate;
  final submitOnPressed;
  final bool isNotification;
  const AddNotificationPage({super.key, this.selectDate, this.submitOnPressed, this.isNotification = false});

  @override
  State<AddNotificationPage> createState() => _AddNotificationPageState();
}

class _AddNotificationPageState extends State<AddNotificationPage> {

  bool isNotification = false;

  DateTime selectedDate = DateTime.now();

  TimeOfDay selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if(widget.selectDate != null){
      selectedDate = widget.selectDate!;
    }
    isNotification = widget.isNotification;
    selectedDate = widget.selectDate ?? DateTime.now();
    selectedTime = TimeOfDay.fromDateTime(selectedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  void setState(fn) {
    super.setState(fn);
      widget.submitOnPressed({
        'dateTime': DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute),
        'isNotification': isNotification
      });
  }

  Future<void> _selectTime(BuildContext context) async {
    ThemeData theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      initialEntryMode: TimePickerEntryMode.input,
      orientation: Orientation.portrait,
      builder: (BuildContext context, Widget? child) {
        // We just wrap these environmental changes around the
        // child in this builder so that we can apply the
        // options selected above. In regular usage, this is
        // rarely necessary, because the default values are
        // usually used as-is.
        return Theme(
          data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
              hourMinuteTextColor: Colors.black,
              hourMinuteColor: Colors.white,
              helpTextStyle: TextStyle(color: Colors.black),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.white),
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            dialogBackgroundColor: Colors.white,
            colorScheme: theme.colorScheme
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: true,
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null && picked != selectedTime){
      setState(() {
        selectedTime = picked;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final Color colorHide = Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : const Color(0xFF8A8787);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(S.of(context).get('set_reminder') ?? 'Đặt nhắc nhở', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
            children: [
              const Padding(padding: EdgeInsets.only(top: 15.0)),
              Container(
                color: Theme.of(context).cardColor,
                child: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: colorHide, //                   <--- border color
                          width: 0.2,
                        ),
                      ),
                    ),
                    child: Material(
                      child:  ListTile(
                        title: Text(S.of(context).get('date') ?? 'Ngày', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(Utils.dateToString(selectedDate)),
                        onTap: () {
                          _selectDate(context);
                          // Navigator.pushNamed(context, '/DateSelectPage');
                        },
                      ),
                    )
                ),
              ),
              const SizedBox(height: 3.0),
              Container(
                color: Theme.of(context).cardColor,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: colorHide, //                   <--- border color
                        width: 0.2,
                      ),
                    ),
                  ),
                  child: Material(
                    child: ListTile(
                      title: Text(S.of(context).get('time') ?? 'Giờ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${selectedTime.hour}:${selectedTime.minute}'),
                      onTap: () {
                        _selectTime(context);
                        // Navigator.pushNamed(context, '/DateSelectPage');
                      },
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 15.0)),
              Container(
                color: Theme.of(context).cardColor,
                child: SizedBox(
                  height: 50.0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                            padding:  EdgeInsets.only(left: 15.0),
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: colorHide, //                   <--- border color
                                  width: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(S.of(context).get('set_reminder') ?? "Đặt nhắc nhở", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Container(
                                      margin: const EdgeInsets.only(right: 10.0),
                                      child: showSwitch(
                                        value: isNotification,
                                        onChanged: (value) {
                                          setState(() {
                                            isNotification = value;
                                          });
                                        },
                                      )
                                  ),
                                ]
                            )
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
        ),
      ),
    );
  }
}
