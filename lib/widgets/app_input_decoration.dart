import 'package:flutter/material.dart';

/// Returns a consistent [InputDecoration] used across all form fields in the app.
InputDecoration appInputDecoration({
  required String hint,
  Widget? prefix,
  Widget? suffix,
  bool filled = true,
  Color? fillOverride,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    prefixIcon: prefix != null
        ? Padding(
            padding: const EdgeInsets.only(left: 12, right: 8), child: prefix)
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix != null
        ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
        : null,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: filled,
    fillColor: fillOverride ?? const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
  );
}