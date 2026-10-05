import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/auth/application/auth_form_rules.dart';
import 'package:hitup/features/auth/application/common_passwords.dart';
import 'package:hitup/features/auth/domain/repositories/auth_repository.dart';
import 'package:hitup/features/auth/presentation/auth_labels.dart';

void main() {
  group('email', () {
    test('an empty address is missing, spaces included', () {
      expect(AuthFormRules.email(''), AuthFieldProblem.missing);
      expect(AuthFormRules.email('   '), AuthFieldProblem.missing);
    });

    test('an address with no at sign, no dot or a space is refused', () {
      for (final String bad in <String>[
        'ornek.com',
        'ali@ornek',
        'ali @ornek.com',
        '@ornek.com',
        'ali@.com',
      ]) {
        expect(
          AuthFormRules.email(bad),
          AuthFieldProblem.invalidEmail,
          reason: bad,
        );
      }
    });

    test('an address is trimmed as the repository trims it', () {
      expect(AuthFormRules.email('ali@ornek.com'), isNull);
      expect(AuthFormRules.email('  ali@ornek.com '), isNull);
    });
  });

  group('signing in', () {
    test('any password that was typed is accepted, however short', () {
      expect(AuthFormRules.signInPassword(''), AuthFieldProblem.missing);
      // An account made under Firebase's own minimum of six still signs in.
      expect(AuthFormRules.signInPassword('abc123'), isNull);
      expect(AuthFormRules.signInPassword('12345678'), isNull);
    });
  });

  group('a new password', () {
    test('is at least eight characters, counted as characters', () {
      expect(AuthFormRules.newPassword(''), AuthFieldProblem.missing);
      expect(
        AuthFormRules.newPassword('kalem73'),
        AuthFieldProblem.passwordTooShort,
      );
      expect(AuthFormRules.newPassword('kalem739'), isNull);
      // Seven characters, eight UTF-16 units: still seven.
      expect(
        AuthFormRules.newPassword('kal\u{1F600}m73'),
        AuthFieldProblem.passwordTooShort,
      );
      // Turkish letters count as one each.
      expect(AuthFormRules.newPassword('ğüşiöçı1'), isNull);
    });

    test('needs no mix of letters, digits and symbols', () {
      expect(AuthFormRules.newPassword('dudaklarim'), isNull);
      expect(AuthFormRules.newPassword('dudaklarım bugün çok hızlı'), isNull);
      expect(AuthFormRules.newPassword('7391 2847'), isNull);
    });

    test('is not one of the passwords people use most, in any case', () {
      for (final String common in <String>[
        'password1',
        'PASSWORD1',
        'galatasaray',
        'Galatasaray',
        'qwerty123',
      ]) {
        expect(
          AuthFormRules.newPassword(common),
          AuthFieldProblem.passwordTooCommon,
          reason: common,
        );
      }
    });

    test('is not one character repeated, or a run of digits', () {
      // None of these is in the list: the rule itself refuses them.
      for (final String run in <String>['zzzzzzzz', '23456789', '76543210']) {
        expect(commonPasswords.contains(run), isFalse, reason: run);
        expect(
          AuthFormRules.newPassword(run),
          AuthFieldProblem.passwordTooCommon,
          reason: run,
        );
      }
      // Digits that are not a run are not refused for being digits.
      expect(AuthFormRules.newPassword('73912847'), isNull);
    });

    test('is not the app, or a word for password, dressed in digits', () {
      for (final String guess in <String>[
        'hitup2026',
        'HitUp2026!',
        '!!hitup!!',
        'sifre1234',
        'şifre2024',
        'parola.2026',
      ]) {
        expect(commonPasswords.contains(guess.toLowerCase()), isFalse);
        expect(
          AuthFormRules.newPassword(guess),
          AuthFieldProblem.passwordTooCommon,
          reason: guess,
        );
      }
      // The word inside a longer one is fine.
      expect(AuthFormRules.newPassword('hitupluyorum'), isNull);
    });

    test('is not the email, its name part, or a part of the name given', () {
      AuthFieldProblem? check(String password) => AuthFormRules.newPassword(
            password,
            email: 'Emir.Rende@ornek.com',
            name: ' Emir  Rende ',
          );

      expect(check('emir.rende@ornek.com'), AuthFieldProblem.passwordTooCommon);
      expect(check('emir.rende99'), AuthFieldProblem.passwordTooCommon);
      expect(check('Rende1907'), AuthFieldProblem.passwordTooCommon);
      expect(check('2026emir!'), AuthFieldProblem.passwordTooCommon);
      // Someone else's name is not a guess about this account.
      expect(check('ayse19071'), isNull);
    });

    test('a name part too short to be a guess is not refused', () {
      expect(
        AuthFormRules.newPassword('al123456789', name: 'Al'),
        isNull,
      );
    });
  });

  group('the repetition', () {
    test('has to be typed, and match exactly', () {
      expect(
        AuthFormRules.passwordRepetition('kalem739', ''),
        AuthFieldProblem.missing,
      );
      expect(
        AuthFormRules.passwordRepetition('kalem739', 'kalem738'),
        AuthFieldProblem.passwordMismatch,
      );
      expect(
        AuthFormRules.passwordRepetition('Kalem739', 'kalem739'),
        AuthFieldProblem.passwordMismatch,
      );
      expect(AuthFormRules.passwordRepetition('kalem739', 'kalem739'), isNull);
    });
  });

  group('the name', () {
    test('is required, trimmed, and within the rules limit', () {
      expect(AuthFormRules.displayName(''), AuthFieldProblem.missing);
      expect(AuthFormRules.displayName('   '), AuthFieldProblem.missing);
      expect(AuthFormRules.displayName('Emir'), isNull);

      final String longest = 'a' * maxDisplayNameLength;
      expect(AuthFormRules.displayName(longest), isNull);
      expect(AuthFormRules.displayName('  $longest  '), isNull);
      expect(
        AuthFormRules.displayName('${longest}a'),
        AuthFieldProblem.nameTooLong,
      );
    });
  });

  group('the list', () {
    test('holds only lower case entries the length rule lets through', () {
      expect(commonPasswords.length, greaterThan(300));
      for (final String entry in commonPasswords) {
        expect(entry, entry.toLowerCase());
        expect(
          entry.runes.length,
          greaterThanOrEqualTo(AuthFormRules.minPasswordLength),
          reason: entry,
        );
      }
    });
  });

  group('the copy', () {
    test('every problem has its sentence, with the numbers in it', () {
      for (final AuthFieldProblem problem in AuthFieldProblem.values) {
        expect(AuthFieldLabelsTr.of(problem), isNotEmpty, reason: '$problem');
      }
      expect(AuthFieldLabelsTr.of(null), isNull);
      expect(
        AuthFieldLabelsTr.of(AuthFieldProblem.passwordTooShort),
        'Şifre en az 8 karakter olmalı.',
      );
      expect(
        AuthFieldLabelsTr.of(AuthFieldProblem.nameTooLong),
        'Ad en fazla 100 karakter olabilir.',
      );
    });
  });
}
