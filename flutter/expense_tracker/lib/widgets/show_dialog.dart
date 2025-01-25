import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showDialogNotification(
  String title,
  Widget content,
  BuildContext context, [
  Widget? callback,
  Widget? reject,
]) {
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
        content: content,
        actions: callback == null
            ? [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))]
            : reject == null
                ? [
                    callback,
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))
                  ]
                : [callback, reject],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [content],
          ),
        ),
        actions: callback == null
            ? [
                TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Okay'))
              ]
            : reject == null
                ? [
                    callback,
                    TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Cancel'))
                  ]
                : [callback, reject],
      ),
    );
  }
}
