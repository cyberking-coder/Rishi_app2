import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// One field in the auth forms: a raised card holding an icon chip, the
/// field's name, and the input itself.
///
/// The name sits *above* the input as a permanent label rather than as a
/// Material floating label. On these screens the label is doing real work
/// — "Name (optional)", "Confirm password" — and a floating label is
/// hidden exactly when the field is filled, which is when someone
/// re-reading the form most needs it.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  /// The chip icon. Defaults to a sensible guess from the field type so
  /// existing call sites don't all have to be updated at once.
  final IconData? icon;

  /// Placeholder inside the input. Falls back to "Enter your <label>".
  final String? hint;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.icon,
    this.hint,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  IconData get _icon {
    if (widget.icon != null) return widget.icon!;
    if (widget.obscureText) return Icons.lock_outline_rounded;
    if (widget.keyboardType == TextInputType.emailAddress) {
      return Icons.mail_outline_rounded;
    }
    return Icons.person_outline_rounded;
  }

  String get _hint =>
      widget.hint ?? 'Enter your ${widget.label.toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: AppTheme.claySurface(radius: AppTheme.radiusRow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppTheme.sageSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: AppTheme.sageDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.sageDark,
                  ),
                ),
                TextFormField(
                  controller: widget.controller,
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  autocorrect: false,
                  style: AppTheme.body.copyWith(fontSize: 15.5),
                  decoration: InputDecoration(
                    hintText: _hint,
                    isDense: true,
                    filled: false,
                    // Every border removed rather than restyled: the card
                    // around this Row is the field's visible edge now, and
                    // a second outline inside it reads as a nested input.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.only(top: 2, bottom: 0),
                    hintStyle: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                    errorStyle: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 12,
                      height: 1.3,
                      color: AppTheme.danger,
                    ),
                  ),
                  validator: widget.validator,
                ),
              ],
            ),
          ),
          // Show/hide toggle only on obscured (password) fields.
          if (widget.obscureText)
            IconButton(
              icon: Icon(
                _obscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textPrimary,
                size: 22,
              ),
              tooltip: _obscured ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscured = !_obscured),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
