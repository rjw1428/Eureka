import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showDialogNotification(String title, String content, BuildContext context) {
  bool isIos = false;
  try {
    isIos = Platform.isIOS;
  } catch (e) {
    isIos = false;
  }

  if (isIos) {
    showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
            ));
  } else {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
            ));
  }
}
