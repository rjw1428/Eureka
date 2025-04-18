import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SuggestionFom extends StatefulWidget {
  const SuggestionFom({
    super.key,
    required this.onSubmit,
  });

  final void Function(String) onSubmit;

  @override
  State<StatefulWidget> createState() {
    return _SuggestionFormState();
  }
}

class _SuggestionFormState extends State<SuggestionFom> {
  String formTitle = 'Add Note Shortcut';
  String actionButtonLabel = 'Save';
  final _label = TextEditingController();

  void _showDialog(String title, String content) {
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
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))
                ],
              ));
    } else {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))
                ],
              ));
    }
  }

  void _submit() {
    final enteredText = _label.text.trim();

    if (enteredText.isEmpty) {
      _showDialog(
        'Invalid Shortcut text',
        'Value is required',
      );
      return;
    }

    widget.onSubmit(enteredText);

    Navigator.pop(context);
    return;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
        child: Column(
          children: [
            Text(
              formTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.words,
                      controller: _label,
                      decoration: const InputDecoration(
                        label: Text('Note Shortcut'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(actionButtonLabel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
