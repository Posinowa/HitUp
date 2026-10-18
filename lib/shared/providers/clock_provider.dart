import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wall clock, so a test can say what day and hour it is.
///
/// Read where the date or the hour decides what is shown: which day today
/// is for today's training (`todayStatusProvider`), and the greeting, the
/// date and the sun on home.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);
