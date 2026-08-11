import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? errorText;
  final bool readOnly;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.autofocus = false,
    this.focusNode,
    this.errorText,
    this.readOnly = false,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.inputFormatters,
  });
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller,
        obscureText: widget.obscureText && !_show,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        enabled: widget.enabled,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        style: AppTextStyles.inputText,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: widget.errorText,
          counterText: '',
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: AppColors.primary.withValues(alpha: 0.7),
                  size: 20,
                )
              : null,
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                )
              : widget.suffix,
        ),
      ),
    ],
  );
}
