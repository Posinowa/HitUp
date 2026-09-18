import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/training/data/asset_curriculum_repository.dart';
import '../../features/training/domain/repositories/curriculum_repository.dart';
import '../../features/training/domain/today_training_engine.dart';
import 'progress_providers.dart';

/// The bundled curriculum (HIT-024).
///
/// Exposed as the [CurriculumRepository] interface, so a caller cannot reach
/// into the asset bundle and a later remote or cached source can replace it
/// without any caller changing.
final Provider<CurriculumRepository> curriculumRepositoryProvider =
    Provider<CurriculumRepository>((Ref ref) => AssetCurriculumRepository());

/// Today's training (HIT-025).
///
/// Holds no state, so one instance serves every caller:
///
/// ```dart
/// final TodayTraining today =
///     await ref.read(todayTrainingEngineProvider).todayFor(uid);
/// ```
final Provider<TodayTrainingEngine> todayTrainingEngineProvider =
    Provider<TodayTrainingEngine>(
  (Ref ref) => TodayTrainingEngine(
    curriculum: ref.watch(curriculumRepositoryProvider),
    progress: ref.watch(userProgressRepositoryProvider),
  ),
);
