/// User-safe failure representation for presentation layers.
class Failure {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'Failure($code): $message';
}
