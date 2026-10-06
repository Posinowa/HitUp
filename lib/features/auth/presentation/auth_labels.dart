import '../application/auth_form_rules.dart';
import '../domain/repositories/auth_repository.dart';

/// The account forms' Turkish copy for what is wrong with a field.
///
/// Failures that come back from Firebase have their own sentences
/// (`failure_messages.dart`); these are the ones a form finds before it sends
/// anything. They name the problem and how to fix it, without addressing the
/// reader as "sen" or "siz", so they sit beside either.
abstract final class AuthFieldLabelsTr {
  /// An empty field.
  static const String missing = 'Bu alan boş bırakılamaz.';

  /// An address that is not shaped like one.
  static const String invalidEmail = 'E-posta adresi geçerli görünmüyor.';

  /// A new password under the minimum.
  static const String passwordTooShort =
      'Şifre en az ${AuthFormRules.minPasswordLength} karakter olmalı.';

  /// A new password that is easy to guess.
  static const String passwordTooCommon =
      'Bu şifre çok yaygın ya da kolay tahmin edilir. '
      'Başka bir şifre gerekiyor.';

  /// A repetition that does not match.
  static const String passwordMismatch = 'Şifreler birbirini tutmuyor.';

  /// A name over the limit.
  static const String nameTooLong =
      'Ad en fazla $maxDisplayNameLength karakter olabilir.';

  /// The sentence for [problem], or null when there is none.
  static String? of(AuthFieldProblem? problem) => switch (problem) {
        null => null,
        AuthFieldProblem.missing => missing,
        AuthFieldProblem.invalidEmail => invalidEmail,
        AuthFieldProblem.passwordTooShort => passwordTooShort,
        AuthFieldProblem.passwordTooCommon => passwordTooCommon,
        AuthFieldProblem.passwordMismatch => passwordMismatch,
        AuthFieldProblem.nameTooLong => nameTooLong,
      };
}
