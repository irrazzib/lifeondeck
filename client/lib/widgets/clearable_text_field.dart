import 'package:flutter/material.dart';

class ClearableTextField extends StatefulWidget {
  const ClearableTextField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.autofocus = false,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final bool autofocus;
  final int? maxLines;
  final TextInputAction? textInputAction;

  @override
  State<ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<ClearableTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _selectAll() {
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onTap: _selectAll,
      decoration: widget.decoration.copyWith(
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: widget.controller.clear,
              )
            : null,
      ),
    );
  }
}
