import '../domain/repositories/auth_repository.dart';
import 'common_passwords.dart';

/// What can be wrong with a field of an account form (HIT-017 to HIT-019).
///
/// A value, not a sentence: the screens turn it into copy, so a wording change
/// never touches a rule.
enum AuthFieldProblem {
  /// Left empty.
  missing,

  /// Not shaped like an email address.
  invalidEmail,

  /// Shorter than [AuthFormRules.minPasswordLength].
  passwordTooShort,

  /// One people use most, or one made from the app's name, the email or the
  /// name given.
  passwordTooCommon,

  /// The repetition is not the password.
  passwordMismatch,

  /// Longer than the security rules allow a name ([maxDisplayNameLength]).
  nameTooLong,
}

/// What the account forms accept.
///
/// **A new password** is at least [minPasswordLength] characters, with no rule
/// about mixing letters, digits and symbols, and no upper limit below what
/// Firebase itself allows: a long sentence is a good password. It must not be
/// one of the passwords people use most ([commonPasswords]), a character
/// repeated, a run of digits such as `12345678`, or the app's name, the email
/// or the name given with digits or symbols added. The current NIST guidance
/// (SP 800-63B, August 2025) asks for no composition rules and for such a list;
/// it asks for 15 characters where a password is the only factor, and the
/// product chose eight for this app, where an account holds a training
/// history rather than anything sensitive.
///
/// **Signing in checks only that a password was typed.** An account made
/// before these rules, under Firebase's own minimum of six, still signs in.
///
/// These rules run on the device. What the server enforces is Firebase's
/// password policy: six characters by default, or what is set in the console.
abstract final class AuthFormRules {
  /// The shortest new password accepted.
  static const int minPasswordLength = 8;

  /// Something, an at sign, something with a dot in it. Firebase checks the
  /// rest; this catches the typing mistakes before a round trip.
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Digits and ASCII punctuation at either end of a password, which turn a
  /// word into what people think is a different password (`hitup2026!`).
  static final RegExp _padding =
      RegExp(r'^[0-9\s!-/:-@\[-`{-~]+|[0-9\s!-/:-@\[-`{-~]+$');

  /// Words a password is not allowed to be built on, whoever the user is.
  static const Set<String> _guessableWords = <String>{
    'hitup',
    'password',
    'parola',
    'sifre',
    'şifre',
    'qwerty',
  };

  /// [value] as an email address, trimmed as the repository trims it.
  static AuthFieldProblem? email(String value) {
    final String address = value.trim();
    if (address.isEmpty) {
      return AuthFieldProblem.missing;
    }
    if (!_emailShape.hasMatch(address)) {
      return AuthFieldProblem.invalidEmail;
    }
    return null;
  }

  /// [value] as the password of an existing account.
  static AuthFieldProblem? signInPassword(String value) =>
      value.isEmpty ? AuthFieldProblem.missing : null;

  /// [value] as a new password, for an account with [email] and [name].
  ///
  /// Passwords are used exactly as typed, so nothing here trims them.
  static AuthFieldProblem? newPassword(
    String value, {
    String email = '',
    String name = '',
  }) {
    if (value.isEmpty) {
      return AuthFieldProblem.missing;
    }
    // Counted in characters, not in the two-byte units a Dart string is made
    // of, so a letter outside the basic range counts as one.
    if (value.runes.length < minPasswordLength) {
      return AuthFieldProblem.passwordTooShort;
    }
    if (_isGuessable(value, email: email, name: name)) {
      return AuthFieldProblem.passwordTooCommon;
    }
    return null;
  }

  /// [repetition] as the password typed a second time.
  static AuthFieldProblem? passwordRepetition(
    String password,
    String repetition,
  ) {
    if (repetition.isEmpty) {
      return AuthFieldProblem.missing;
    }
    return repetition == password ? null : AuthFieldProblem.passwordMismatch;
  }

  /// [value] as the name an account is made with, trimmed.
  ///
  /// Measured as the repository measures it, so a name this accepts is one
  /// the repository and the security rules accept.
  static AuthFieldProblem? displayName(String value) {
    final String name = value.trim();
    if (name.isEmpty) {
      return AuthFieldProblem.missing;
    }
    if (name.length > maxDisplayNameLength) {
      return AuthFieldProblem.nameTooLong;
    }
    return null;
  }

  static bool _isGuessable(
    String value, {
    required String email,
    required String name,
  }) {
    final String lower = value.toLowerCase();
    if (commonPasswords.contains(lower)) {
      return true;
    }
    if (lower.runes.toSet().length == 1 || _isDigitRun(lower)) {
      return true;
    }
    final String word = lower.replaceAll(_padding, '');
    if (word.isEmpty) {
      return false;
    }
    final String address = email.trim().toLowerCase();
    final Set<String> personal = <String>{
      if (address.isNotEmpty) address,
      if (address.contains('@')) address.split('@').first,
      for (final String part in name.trim().toLowerCase().split(RegExp(r'\s+')))
        if (part.length >= 3) part,
    };
    return _guessableWords.contains(word) || personal.contains(word);
  }

  /// Whether [value] is digits that each go up by one, or each down by one.
  static bool _isDigitRun(String value) {
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return false;
    }
    final List<int> digits = value.codeUnits;
    bool up = true;
    bool down = true;
    for (int i = 1; i < digits.length; i++) {
      up = up && digits[i] - digits[i - 1] == 1;
      down = down && digits[i - 1] - digits[i] == 1;
    }
    return up || down;
  }
}
