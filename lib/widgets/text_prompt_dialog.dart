import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'clearable_text_field.dart';

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLines;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ClearableTextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.txt.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.txt.t('common.save')),
        ),
      ],
    );
  }
}
