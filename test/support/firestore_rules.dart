import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The field list a `hasOnly([...])` in `firestore.rules` allows, found by the
/// function it sits in.
///
/// Lets a test hold Dart writes to the rules they have to pass, so a field
/// added on one side and not the other fails a test instead of the first real
/// write.
Set<String> rulesFieldsOf(String function) {
  final String rules = File('firestore.rules').readAsStringSync();
  final RegExpMatch? match = RegExp(
    'function $function\\([^)]*\\)\\s*\\{\\s*return d\\.keys\\(\\)\\.hasOnly\\(\\[([^\\]]*)\\]',
  ).firstMatch(rules);
  expect(match, isNotNull, reason: 'no hasOnly list found in $function');
  return RegExp(r"'([A-Za-z]+)'")
      .allMatches(match!.group(1)!)
      .map((RegExpMatch m) => m.group(1)!)
      .toSet();
}
