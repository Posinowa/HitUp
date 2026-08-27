import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';

void main() {
  group('coverage', () {
    test('every declared constant is listed in FailureCode.all', () {
      // `all` is maintained by hand because Dart cannot enumerate static
      // constants at runtime without mirrors. Reading the source closes that
      // gap: a constant added without being listed fails here rather than
      // quietly escaping both checks below.
      final source = File(
        'lib/core/errors/failure_code.dart',
      ).readAsStringSync();

      final declared = RegExp(r"static const \w+ = '([^']+)';")
          .allMatches(source)
          .map((match) => match.group(1)!)
          .toSet();

      expect(
        declared,
        isNotEmpty,
        reason: 'the source parser matched nothing, so this test proves '
            'nothing. Check the constant declaration style.',
      );
      expect(
        declared.difference(FailureCode.all.toSet()),
        isEmpty,
        reason: 'declared but missing from FailureCode.all',
      );
    });

    test('every failure code has copy behind it', () {
      final missing = FailureCode.all
          .where((code) => !failureMessagesTr.containsKey(code))
          .toList();

      expect(
        missing,
        isEmpty,
        reason: 'these codes would fall back to the generic message: $missing',
      );
    });

    test('the table has no entries that no code refers to', () {
      final orphans = failureMessagesTr.keys
          .where((code) => !FailureCode.all.contains(code))
          .toList();

      expect(orphans, isEmpty, reason: 'unreachable copy: $orphans');
    });
  });

  group('copy quality', () {
    test('no message is empty or padded', () {
      failureMessagesTr.forEach((code, message) {
        expect(message.trim(), isNotEmpty, reason: code);
        expect(message, message.trim(), reason: '$code has stray whitespace');
      });
    });

    test('messages read as sentences, not error codes', () {
      failureMessagesTr.forEach((code, message) {
        expect(
          message,
          isNot(contains('Exception')),
          reason: '$code leaks a type name',
        );
        expect(
          message,
          isNot(matches(RegExp(r'\[[a-z_]+/'))),
          reason: '$code leaks a plugin error code',
        );
      });
    });

    test('user copy avoids em and en dashes', () {
      // House style: user copy uses commas, full stops or a rewritten
      // sentence instead. Referenced by code point so the characters
      // themselves never appear in the source.
      final emDash = String.fromCharCode(0x2014);
      final enDash = String.fromCharCode(0x2013);

      failureMessagesTr.forEach((code, message) {
        expect(message, isNot(contains(emDash)),
            reason: '$code has an em dash');
        expect(message, isNot(contains(enDash)),
            reason: '$code has an en dash');
      });
    });
  });

  group('lookup', () {
    test('a known code returns its own message', () {
      const failure = NetworkFailure(code: FailureCode.networkOffline);
      expect(failureMessage(failure),
          failureMessagesTr[FailureCode.networkOffline]);
    });

    test('an unmapped code falls back instead of failing', () {
      const failure = UnknownFailure(code: 'code.that.does.not.exist');
      expect(failureMessage(failure), failureMessagesTr[FailureCode.unknown]);
    });

    test('technical detail never reaches the user message', () {
      const detail = '[firebase_auth/wrong-password] The password is invalid.';
      const failure = AuthFailure(
        code: FailureCode.authInvalidCredentials,
        technicalDetail: detail,
      );

      final message = failureMessage(failure);
      expect(message, isNot(contains(detail)));
      expect(message, isNot(contains('firebase')));
      expect(message, failureMessagesTr[FailureCode.authInvalidCredentials]);
    });
  });
}
