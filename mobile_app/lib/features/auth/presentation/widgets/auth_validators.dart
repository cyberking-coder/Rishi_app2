/// Shared form-field validators for the auth screens.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Email is required';
  if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
  return null;
}

/// Required, at least 6 characters — matches Supabase's own minimum. Used
/// for login, where we shouldn't retroactively enforce today's complexity
/// rules on a password created under older/looser rules.
String? validatePasswordRequired(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  return null;
}

/// Enforced when a user is choosing a new password (sign up): at least 8
/// characters, containing a letter, a number, and a symbol.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Password is required';
  if (password.length < 8) return 'Password must be at least 8 characters';
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  if (!hasLetter || !hasDigit || !hasSymbol) {
    return 'Password must include a letter, a number, and a symbol';
  }
  return null;
}
