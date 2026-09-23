import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/text/turkish_case.dart';

void main() {
  group('turkishLowerCase', () {
    test('pairs the four Turkish i letters correctly', () {
      expect(turkishLowerCase('I'), 'ı');
      expect(turkishLowerCase('İ'), 'i');
      expect(turkishLowerCase('ı'), 'ı');
      expect(turkishLowerCase('i'), 'i');
    });

    test('is what Dart would get wrong on its own', () {
      // Left in as the reason these functions exist, and as a tripwire if a
      // later SDK changes the neutral mapping. Each direction gets one pair
      // wrong: I lowercases to i, and i uppercases to I.
      expect('I'.toLowerCase(), 'i');
      expect(turkishLowerCase('I'), 'ı');
      expect('i'.toUpperCase(), 'I');
      expect(turkishUpperCase('i'), 'İ');
      // And one pair per direction it happens to get right, which is why
      // turkishLowerCase does not map İ and turkishUpperCase does not map ı.
      // These two are the tripwire: if an SDK ever changes them, the fold has
      // to gain the replacement it does not need today.
      expect('İ'.toLowerCase(), 'i');
      expect('ı'.toUpperCase(), 'I');
    });

    test('upper case keeps the dotted i dotted', () {
      expect(turkishUpperCase('ışık'), 'IŞIK');
      expect(turkishUpperCase('iyi'), 'İYİ');
      expect(turkishUpperCase('İ'), 'İ');
      expect(turkishUpperCase('I'), 'I');
      expect(turkishUpperCase(''), '');
      // Round trip: folding down and back up returns the same letters.
      for (final String word in <String>['IŞIK', 'İYİ', 'ÇÖĞÜŞ']) {
        expect(turkishUpperCase(turkishLowerCase(word)), word, reason: word);
      }
    });

    test('lowercases the rest as usual, Turkish letters included', () {
      expect(turkishLowerCase('IŞIK'), 'ışık');
      expect(turkishLowerCase('ÇÖĞÜŞ'), 'çöğüş');
      expect(turkishLowerCase('Kırmızı Şemsiye'), 'kırmızı şemsiye');
      expect(turkishLowerCase(''), '');
    });

    test('equality ignores case in both directions', () {
      expect(turkishEqualsIgnoringCase('I', 'ı'), isTrue);
      expect(turkishEqualsIgnoringCase('İ', 'i'), isTrue);
      expect(turkishEqualsIgnoringCase('ışık', 'IŞIK'), isTrue);
      // The pairs do not cross: I is not i in Turkish.
      expect(turkishEqualsIgnoringCase('I', 'i'), isFalse);
      expect(turkishEqualsIgnoringCase('İ', 'ı'), isFalse);
      expect(turkishEqualsIgnoringCase('r', 'ş'), isFalse);
    });
  });
}
