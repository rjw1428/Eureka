import 'dart:ui';

import 'package:expense_tracker/providers/note_suggestion_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestionsRow extends ConsumerStatefulWidget {
  const SuggestionsRow(
      {super.key, required this.onClick, required this.categoryId});

  final void Function(String?) onClick;
  final String categoryId;

  @override
  ConsumerState<SuggestionsRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends ConsumerState<SuggestionsRow> {
  final ScrollController _scrollController = ScrollController();
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsObject = ref.watch(noteSuggestionProvider);
    final suggestions = suggestionsObject[widget.categoryId] ?? [];
    if (suggestions.isEmpty) {
      return const SizedBox(height: 1);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suggestions:', style: Theme.of(context).textTheme.titleSmall),
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
            platform: TargetPlatform.linux,
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: kIsWeb,
            thickness: kIsWeb ? 8.0 : 2.0,
            radius: const Radius.circular(4),
            child: Padding(
              padding: EdgeInsets.only(bottom: suggestions.isEmpty ? 0 : 24.0),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions
                      .map((suggestion) => Suggestion(
                            text: suggestion,
                            action: () => widget.onClick(suggestion),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
//

class Suggestion extends StatelessWidget {
  const Suggestion({super.key, required this.text, required this.action});

  final String text;
  final void Function() action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: action,
        child: Text(text),
      ),
    );
  }
}
