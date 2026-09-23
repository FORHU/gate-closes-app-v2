/// Pure form-field validators. Return `null` when valid, else an error string.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$',
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  /// For the *login* field only — just checks it's non-empty. Don't use
  /// [password]'s complexity rules here: an existing account may predate
  /// those rules, and login should never client-side-reject a password the
  /// server would otherwise accept.
  static String? loginPassword(String? value) {
    return (value == null || value.isEmpty) ? 'Password is required' : null;
  }

  /// Mirrors the backend's `passwordSchema` (`password.validator.ts`): min 8
  /// chars, at least one uppercase letter, one digit, one special character.
  /// Client-side validation alone would let a weaker password through only
  /// to be rejected by the server with no field-level feedback.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp('[A-Z]').hasMatch(v)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'\d').hasMatch(v)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[^a-zA-Z0-9\s]').hasMatch(v)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  static final RegExp _usernameRegex = RegExp(r'^[A-Za-z]+\d{1,3}\.\d{2}$');

  /// Mirrors the backend's username pattern (`user.auth.controller.ts`,
  /// `setUsernameGender`) — e.g. `Jane123.45`.
  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required';
    if (!_usernameRegex.hasMatch(v)) {
      return 'Use letters followed by digits, e.g. Jane123.45';
    }
    return null;
  }

  /// 4-digit OTP, used by both the signup and forgot-password wizards.
  static String? otpCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Code is required';
    if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Enter the 4-digit code';
    return null;
  }
}
