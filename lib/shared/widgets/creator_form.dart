import 'package:flutter/material.dart';

import '../../core/constants/layout.dart';
import '../../core/theme/app_theme.dart';

/// Shared building blocks for the creator tools (new story, new post, new
/// chain, edit screens).
///
/// The creator screens each hand-rolled their own label + field + info box,
/// so they drifted apart: some used an outline border, some a filled box;
/// some showed a character count, some did not. These keep them identical and
/// make every form one shape.
class CreatorForm {
  CreatorForm._();

  static const int titleLimit = 120;
  static const int descriptionLimit = 600;
  static const int excerptLimit = 240;

  /// Small uppercase label above a field.
  static Widget label(BuildContext context, String text, {bool required = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          if (required)
            Text(
              '  required',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }

  /// Standard text field, already themed. Call inside a `Form` when
  /// [validator] is supplied.
  static Widget field(
    BuildContext context, {
    required TextEditingController controller,
    String? hint,
    String? helper,
    String? counter,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    IconData? icon,
    bool enabled = true,
  }) {
    if (validator != null) {
      return FormField<String>(
        validator: (_) => validator(controller.text),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldContent(
              controller: controller,
              hint: hint,
              helper: helper,
              counter: counter,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType,
              onChanged: (value) {
                onChanged?.call(value);
                state.didChange(value);
              },
              icon: icon,
              enabled: enabled,
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    }

    return _fieldContent(
      controller: controller,
      hint: hint,
      helper: helper,
      counter: counter,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      icon: icon,
      enabled: enabled,
    );
  }

  static Widget _fieldContent({
    required TextEditingController controller,
    String? hint,
    String? helper,
    String? counter,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    IconData? icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: maxLines > 1 ? 15 : 15,
            fontWeight: maxLines > 1 ? FontWeight.w400 : FontWeight.w500,
            height: maxLines > 1 ? 1.55 : 1.3,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            counterText: counter ?? (maxLength != null ? null : ''),
            prefixIcon: icon == null ? null : Icon(icon, size: 19),
            alignLabelWithHint: maxLines > 1,
          ),
        ),
      ],
    );
  }

  /// Dropdown in the same visual language as [field].
  static Widget dropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    IconData? icon,
    String? Function(T?)? validator,
    String Function(T)? labelOf,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      hint: hint == null ? null : Text(hint),
      icon: const Icon(Icons.expand_more_rounded, size: 20),
      decoration: InputDecoration(
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
      ),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelOf != null ? labelOf(item) : item.toString(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  /// Inline note, used for "you can add chapters next" style guidance.
  static Widget note(BuildContext context, String text, {IconData icon = Icons.info_outline_rounded}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky bottom action bar so the primary action is never scrolled off.
  static Widget actionBar(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
    required bool busy,
    String? busyLabel,
    Widget? secondary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + kShellFabClearance + MediaQuery.of(context).padding.bottom * 0.4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121010) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          if (secondary != null) ...[secondary, const SizedBox(width: 10)],
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(busyLabel ?? 'Saving…'),
                      ],
                    )
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }

  /// Title used at the top of a creator tool.
  static Widget header(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.serifFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
