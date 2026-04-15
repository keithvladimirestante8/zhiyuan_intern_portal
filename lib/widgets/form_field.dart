import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Custom form field with corporate styling and validation
class CustomFormField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? icon;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final FieldVariant variant;
  final double? width;
  final double? height;

  const CustomFormField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.variant = FieldVariant.outlined,
    this.width,
    this.height,
  });

  @override
  State<CustomFormField> createState() => _CustomFormFieldState();
}

class _CustomFormFieldState extends State<CustomFormField> {
  late bool _obscureText;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasError = widget.errorText != null;
    final bool isFocused = _focusNode.hasFocus;

    return SizedBox(
      width: widget.width,
      height: widget.height ?? _getHeight(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hasError
                    ? AppTheme.error
                    : isFocused
                        ? AppTheme.primaryGold
                        : AppTheme.getTextColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildFormField(isDark, hasError, isFocused),
          if (widget.errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.errorText!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormField(bool isDark, bool hasError, bool isFocused) {
    switch (widget.variant) {
      case FieldVariant.outlined:
        return _buildOutlinedField(isDark, hasError, isFocused);
      case FieldVariant.filled:
        return _buildFilledField(isDark, hasError, isFocused);
      case FieldVariant.underlined:
        return _buildUnderlinedField(isDark, hasError, isFocused);
    }
  }

  Widget _buildOutlinedField(bool isDark, bool hasError, bool isFocused) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      style: _getTextStyle(isDark),
      decoration: _getInputDecoration(isDark, hasError, isFocused),
    );
  }

  Widget _buildFilledField(bool isDark, bool hasError, bool isFocused) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      style: _getTextStyle(isDark),
      decoration: _getFilledDecoration(isDark, hasError, isFocused),
    );
  }

  Widget _buildUnderlinedField(bool isDark, bool hasError, bool isFocused) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      style: _getTextStyle(isDark),
      decoration: _getUnderlinedDecoration(isDark, hasError, isFocused),
    );
  }

  InputDecoration _getInputDecoration(bool isDark, bool hasError, bool isFocused) {
    return InputDecoration(
      hintText: widget.hint,
      prefixIcon: widget.prefixIcon ?? _buildPrefixIcon(isDark),
      suffixIcon: widget.suffixIcon ?? _buildSuffixIcon(),
      filled: true,
      fillColor: _getFillColor(isDark),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.getBorderColor(isDark),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? AppTheme.error : AppTheme.primaryGold,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(
        color: AppTheme.getTextHierarchyColor('hint'),
        fontSize: 14,
      ),
    );
  }

  InputDecoration _getFilledDecoration(bool isDark, bool hasError, bool isFocused) {
    return InputDecoration(
      hintText: widget.hint,
      prefixIcon: widget.prefixIcon ?? _buildPrefixIcon(isDark),
      suffixIcon: widget.suffixIcon ?? _buildSuffixIcon(),
      filled: true,
      fillColor: _getFillColor(isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? AppTheme.error : AppTheme.primaryGold,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(
        color: AppTheme.getTextHierarchyColor('hint'),
        fontSize: 14,
      ),
    );
  }

  InputDecoration _getUnderlinedDecoration(bool isDark, bool hasError, bool isFocused) {
    return InputDecoration(
      hintText: widget.hint,
      prefixIcon: widget.prefixIcon ?? _buildPrefixIcon(isDark),
      suffixIcon: widget.suffixIcon ?? _buildSuffixIcon(),
      filled: false,
      border: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppTheme.getBorderColor(isDark),
          width: 1,
        ),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppTheme.getBorderColor(isDark),
          width: 1,
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: hasError ? AppTheme.error : AppTheme.primaryGold,
          width: 2,
        ),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      hintStyle: TextStyle(
        color: AppTheme.getTextHierarchyColor('hint'),
        fontSize: 14,
      ),
    );
  }

  Widget? _buildPrefixIcon(bool isDark) {
    if (widget.icon == null) return null;
    return Icon(
      widget.icon,
      color: AppTheme.primaryGold,
      size: 20,
    );
  }

  Widget? _buildSuffixIcon() {
    if (!widget.obscureText) return null;
    return IconButton(
      icon: Icon(
        _obscureText ? Icons.visibility_off : Icons.visibility,
        color: Colors.grey,
        size: 20,
      ),
      onPressed: () {
        setState(() {
          _obscureText = !_obscureText;
        });
      },
    );
  }

  TextStyle _getTextStyle(bool isDark) {
    return TextStyle(
      fontSize: 16,
      color: widget.enabled
          ? AppTheme.getTextColor(isDark)
          : AppTheme.getTextHierarchyColor('disabled'),
      fontWeight: FontWeight.w500,
    );
  }

  Color _getFillColor(bool isDark) {
    return isDark
        ? AppTheme.getSidebarCardColor(true)
        : Colors.white.withOpacity(0.8);
  }

  double _getHeight() {
    if (widget.maxLines != null && widget.maxLines! > 1) {
      return widget.maxLines! * 24.0 + 32; // Approximate height for multiline
    }
    return 56.0;
  }
}

/// Field variants for different styling
enum FieldVariant {
  outlined,   // Standard outlined field
  filled,     // Filled background field
  underlined, // Underlined field
}

/// Specialized form fields for common use cases

/// Email field with built-in validation
class EmailField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const EmailField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFormField(
      label: label ?? 'Email Address',
      hint: hint ?? 'Enter your email address',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      icon: Icons.email_outlined,
      onChanged: onChanged,
      validator: validator ?? _defaultEmailValidator,
    );
  }

  String? _defaultEmailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }
}

/// Password field with built-in validation
class PasswordField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const PasswordField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFormField(
      label: label ?? 'Password',
      hint: hint ?? 'Enter your password',
      controller: controller,
      obscureText: true,
      icon: Icons.lock_outlined,
      onChanged: onChanged,
      validator: validator ?? _defaultPasswordValidator,
    );
  }

  String? _defaultPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }
}

/// Phone number field with formatting
class PhoneField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const PhoneField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFormField(
      label: label ?? 'Phone Number',
      hint: hint ?? 'Enter your phone number',
      controller: controller,
      keyboardType: TextInputType.phone,
      icon: Icons.phone_outlined,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      onChanged: onChanged,
      validator: validator ?? _defaultPhoneValidator,
    );
  }

  String? _defaultPhoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Please enter a valid 11-digit phone number';
    }
    if (!value.startsWith('09')) {
      return 'Phone number must start with 09';
    }
    return null;
  }
}

/// Search field with search icon
class SearchField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchField({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFormField(
      hint: hint ?? 'Search...',
      controller: controller,
      icon: Icons.search,
      onChanged: onChanged,
      suffixIcon: controller?.text.isNotEmpty == true
          ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: onClear,
            )
          : null,
    );
  }
}
