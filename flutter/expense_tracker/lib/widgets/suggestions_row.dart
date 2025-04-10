import 'dart:ui';

import 'package:expense_tracker/providers/note_suggestion_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestionsRow extends ConsumerStatefulWidget {
  const SuggestionsRow({super.key, required this.textField});

  final TextEditingController textField;

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
    final suggestions$ = ref.watch(noteSuggestionProvider);
    return suggestions$.when(
      loading: () => const SizedBox(height: 1),
      error: (error, stack) {
        print(error);
        return const SizedBox(height: 1);
      },
      data: (suggestions) {
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
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions
                        .map(
                          (suggestion) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8.0),
                            child: OutlinedButton(
                              onPressed: () =>
                                  widget.textField.text = '${widget.textField.text} $suggestion',
                              child: Text(suggestion),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
