import 'package:cloud_firestore/cloud_firestore.dart';

import 'progress_store.dart';

/// [ProgressStore] backed by Cloud Firestore.
///
/// Makes the calls and converts the types, and nothing else: every decision
/// about what a document means lives in the repository above it.
class FirestoreProgressStore implements ProgressStore {
  /// Creates a store over [firestore].
  FirestoreProgressStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<StoredDocument> read(String path) async =>
      documentFrom(await _firestore.doc(path).get());

  @override
  Future<StoredDocument?> readCached(String path) async {
    try {
      return documentFrom(
        await _firestore.doc(path).get(const GetOptions(source: Source.cache)),
      );
    } on FirebaseException {
      // The SDK reports "the cache has nothing to say about this document" as
      // an error. That is not a failure here, only an unknown.
      return null;
    }
  }

  @override
  Stream<StoredDocument> watch(String path) =>
      _firestore.doc(path).snapshots().map(documentFrom);

  @override
  Future<StoredQuery> readCollection(
    String path, {
    String? descendingBy,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(path);
    if (descendingBy != null) {
      query = query.orderBy(descendingBy, descending: true);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return StoredQuery(
      documents: snapshot.docs.map(documentFrom).toList(growable: false),
      fromCache: snapshot.metadata.isFromCache,
    );
  }

  @override
  Future<void> commit(List<StoredWrite> writes) async {
    final WriteBatch batch = _firestore.batch();
    for (final StoredWrite write in writes) {
      final DocumentReference<Map<String, dynamic>> ref =
          _firestore.doc(write.path);
      final Map<String, Object> fields = <String, Object>{
        for (final MapEntry<String, Object> entry in write.fields.entries)
          entry.key: valueFor(entry.value),
      };
      switch (write.mode) {
        case StoredWriteMode.set:
          batch.set(ref, fields);
        case StoredWriteMode.merge:
          batch.set(ref, fields, SetOptions(merge: true));
        case StoredWriteMode.update:
          batch.update(ref, fields);
      }
    }
    await batch.commit();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(StoredTransaction tx) body) =>
      _firestore.runTransaction<T>(
        (Transaction tx) => body(_FirestoreTransaction(tx, _firestore)),
      );

  /// Converts one field value into what Firestore expects.
  static Object valueFor(Object value) => switch (value) {
        final StoredIncrement increment => FieldValue.increment(increment.by),
        StoredServerTime() => FieldValue.serverTimestamp(),
        _ => value,
      };

  /// Converts a snapshot into a [StoredDocument].
  static StoredDocument documentFrom(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) =>
      StoredDocument(
        id: snapshot.id,
        exists: snapshot.exists,
        data: <String, Object?>{
          for (final MapEntry<String, dynamic> entry
              in (snapshot.data() ?? const <String, dynamic>{}).entries)
            entry.key: _fromFirestore(entry.value),
        },
        fromCache: snapshot.metadata.isFromCache,
      );

  static Object? _fromFirestore(Object? value) => switch (value) {
        final Timestamp timestamp => timestamp.toDate(),
        final List<Object?> list => List<Object?>.unmodifiable(list),
        _ => value,
      };
}

/// [StoredTransaction] over a Firestore transaction.
class _FirestoreTransaction implements StoredTransaction {
  const _FirestoreTransaction(this._tx, this._firestore);

  final Transaction _tx;
  final FirebaseFirestore _firestore;

  @override
  Future<StoredDocument> read(String path) async =>
      FirestoreProgressStore.documentFrom(await _tx.get(_firestore.doc(path)));

  @override
  void update(String path, Map<String, Object> fields) {
    _tx.update(_firestore.doc(path), <String, Object>{
      for (final MapEntry<String, Object> entry in fields.entries)
        entry.key: FirestoreProgressStore.valueFor(entry.value),
    });
  }
}
