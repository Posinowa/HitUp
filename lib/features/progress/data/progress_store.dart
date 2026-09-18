import 'package:flutter/foundation.dart';

/// The document reads and writes `FirebaseUserProgressRepository` needs, with
/// no Firestore type in them.
///
/// The repository holds every decision: which path, which fields, what a
/// missing document means, when a refusal is really "already saved". This
/// seam only carries documents to and from storage, which is what lets those
/// decisions be tested without Firebase, as `AuthGateway` does for auth.
abstract interface class ProgressStore {
  /// Reads a document, from the server when it can be reached and from the
  /// local copy otherwise.
  Future<StoredDocument> read(String path);

  /// Reads a document from the local copy only, or null if the local copy
  /// cannot answer.
  ///
  /// Never goes to the network, so it answers at once, online or not.
  Future<StoredDocument?> readCached(String path);

  /// A document and every later change to it, local writes included.
  Stream<StoredDocument> watch(String path);

  /// Reads every document in a collection, optionally ordered by one field,
  /// newest first, and limited.
  Future<StoredQuery> readCollection(
    String path, {
    String? descendingBy,
    int? limit,
  });

  /// Applies [writes] as one atomic batch: all of them or none.
  Future<void> commit(List<StoredWrite> writes);

  /// Reads and writes inside one transaction.
  ///
  /// What a batch cannot do: decide what to write from what was read. The
  /// store re-reads at write time and runs [body] again if another writer got
  /// in between, so [body] must be safe to run more than once and must not
  /// have an effect of its own beyond the writes it asks for.
  ///
  /// A transaction needs the server, so it fails offline rather than queuing
  /// (`USER_PROGRESS.md`).
  Future<T> transaction<T>(Future<T> Function(StoredTransaction tx) body);
}

/// The reads and writes available inside a transaction.
///
/// Every read comes before every write, which is Firestore's rule, not this
/// project's: a write followed by a read in the same transaction is refused.
abstract interface class StoredTransaction {
  /// Reads a document as the transaction sees it.
  Future<StoredDocument> read(String path);

  /// Changes the given fields of a document that must already exist.
  void update(String path, Map<String, Object> fields);
}

/// A document as read. Timestamps arrive as [DateTime].
@immutable
class StoredDocument {
  /// Creates a document.
  const StoredDocument({
    required this.id,
    required this.exists,
    required this.data,
    required this.fromCache,
  });

  /// The last segment of the path.
  final String id;

  /// Whether the document exists, as far as this read could tell.
  final bool exists;

  /// The fields. Empty when [exists] is false.
  final Map<String, Object?> data;

  /// True when this came from the local copy rather than the server.
  final bool fromCache;
}

/// The documents a collection read returned.
@immutable
class StoredQuery {
  /// Creates a result.
  const StoredQuery({required this.documents, required this.fromCache});

  /// In the order asked for.
  final List<StoredDocument> documents;

  /// True when the server could not be asked, so the list is only what the
  /// local copy happened to hold.
  final bool fromCache;
}

/// How a [StoredWrite] treats a document that already exists.
enum StoredWriteMode {
  /// Replace the whole document, or create it.
  set,

  /// Change only the given fields, creating the document if needed.
  merge,

  /// Change only the given fields of a document that must already exist.
  update,
}

/// One write in a batch.
@immutable
class StoredWrite {
  /// Creates a write.
  const StoredWrite(this.mode, this.path, this.fields);

  /// How an existing document is treated.
  final StoredWriteMode mode;

  /// The document path, `users/{uid}/...`.
  final String path;

  /// Field values: plain values, or a [StoredIncrement] or [storedServerTime].
  final Map<String, Object> fields;

  @override
  String toString() => 'StoredWrite(${mode.name} $path ${fields.keys})';
}

/// Adds [by] to a number where it is stored, instead of writing a value read
/// earlier. Starts from 0 when the field is absent.
@immutable
class StoredIncrement {
  /// Creates an increment.
  const StoredIncrement(this.by);

  /// The amount to add.
  final int by;

  @override
  bool operator ==(Object other) => other is StoredIncrement && other.by == by;

  @override
  int get hashCode => by.hashCode;

  @override
  String toString() => 'StoredIncrement($by)';
}

/// The server's clock at the moment the write is applied.
@immutable
class StoredServerTime {
  const StoredServerTime._();

  @override
  String toString() => 'StoredServerTime';
}

/// The one [StoredServerTime] value.
const StoredServerTime storedServerTime = StoredServerTime._();
