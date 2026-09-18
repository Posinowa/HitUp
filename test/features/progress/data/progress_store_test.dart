import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/data/progress_store.dart';

void main() {
  group('write values', () {
    test('increments compare by amount', () {
      expect(const StoredIncrement(1), const StoredIncrement(1));
      expect(
        const StoredIncrement(1).hashCode,
        const StoredIncrement(1).hashCode,
      );
      expect(const StoredIncrement(1), isNot(const StoredIncrement(2)));
      expect(const StoredIncrement(13), isNot('13'));
    });

    test('write values print what they are, for a failed expectation', () {
      expect(const StoredIncrement(13).toString(), 'StoredIncrement(13)');
      expect(storedServerTime.toString(), 'StoredServerTime');
      expect(
        const StoredWrite(
          StoredWriteMode.merge,
          'users/u/exerciseProgress/a',
          <String, Object>{'exerciseId': 'a'},
        ).toString(),
        'StoredWrite(merge users/u/exerciseProgress/a (exerciseId))',
      );
    });
  });

  test('a query result carries its documents and where they came from', () {
    const StoredQuery result = StoredQuery(
      documents: <StoredDocument>[
        StoredDocument(
          id: '2026-09-07',
          exists: true,
          data: <String, Object?>{'trainingDate': '2026-09-07'},
          fromCache: true,
        ),
      ],
      fromCache: true,
    );
    expect(result.documents.single.id, '2026-09-07');
    expect(result.documents.single.data['trainingDate'], '2026-09-07');
    expect(result.fromCache, isTrue);
  });
}
