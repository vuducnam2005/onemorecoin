import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onemorecoin/Objects/AlertDiaLogItem.dart';

Future<void> showAlertDialog({
  required BuildContext context,
    Widget? title,
    Widget? content,
    String? cancelActionText,
    String? defaultActionText,
    VoidCallback? defaultAction,
    List<AlertDiaLogItem>? optionItems,
    AlertDiaLogItem? cancelItem,
}) async {
  TextStyle textStyle = const TextStyle(color: Colors.blue, fontWeight: FontWeight.normal);
  if (!Platform.isIOS) {
    if (optionItems != null && optionItems.isNotEmpty) {
      return showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          title: title,
          children: [
            ...optionItems.map((item) => SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop(true);
                item.okOnPressed.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(item.text, style: item.textStyle ?? textStyle),
              ),
            )),
            if (cancelItem != null || cancelActionText != null)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  cancelItem?.okOnPressed.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(cancelActionText ?? cancelItem?.text ?? "Huỷ", style: cancelItem?.textStyle ?? const TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: title,
        content: content,
        actions: <Widget>[
          if (cancelActionText != null || cancelItem != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                cancelItem?.okOnPressed.call();
              },
              child: Text(cancelActionText ?? cancelItem?.text ?? "Huỷ", style: cancelItem?.textStyle),
            ),
          if (defaultActionText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                defaultAction?.call();
              },
              child: Text(defaultActionText, style: textStyle),
           ),
        ],
      ),
    );
  }

  // todo : showDialog for ios
  return showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: title,
      message: content,
      actions: <Widget>[
          if (defaultActionText != null)
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                defaultAction?.call();
                Navigator.of(context).pop(context);
              },
              child: Text(defaultActionText, style: textStyle),
            ),

          if (optionItems != null)
          for (final item in optionItems)
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop(context);
                item.okOnPressed.call();
              },
              child: Text(item.text, style: item.textStyle ?? textStyle),
            ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(context).pop(context);
          cancelItem?.okOnPressed.call();
        },
        child: Text(cancelItem?.text ?? "Huỷ",
          style: cancelItem?.textStyle
        ),
      ),
    ),
  );
}
