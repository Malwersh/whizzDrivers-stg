// filepath: /lib/features/authentication/widgets/verification_code_input.dart
// Reusable verification code (OTP) input widget (default 6 digits)
// Handles focus movement, numeric filtering, auto-submit callback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_colors.dart';

class VerificationCodeInput extends StatefulWidget {
  final int length;
  final bool autoSubmit;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final double boxSize;
  final EdgeInsetsGeometry margin;

  const VerificationCodeInput({
    super.key,
    this.length = 6,
    this.autoSubmit = true,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
    this.boxSize = 55,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<VerificationCodeInput> createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (value != cleaned) {
      _controllers[index].text = cleaned;
      _controllers[index].selection = TextSelection.fromPosition(TextPosition(offset: cleaned.length));
    }

    if (cleaned.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (cleaned.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);

    if (widget.autoSubmit && code.length == widget.length && code.replaceAll(RegExp(r'\D'), '').length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  void clear() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Force LTR for verification code boxes
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.length, (index) {
          return SizedBox(
            width: widget.boxSize - 10,
            height: widget.boxSize,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr, // Ensure left-to-right for verification codes
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(1),
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.grey300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _onChanged(index, v),
            ),
          );
        }),
      ),
    );
  }
}
