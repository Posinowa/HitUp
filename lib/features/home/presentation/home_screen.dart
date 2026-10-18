import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/cut_paper_scene.dart';
import '../../../shared/providers/clock_provider.dart';
import '../../../shared/providers/progress_providers.dart';
import '../../progress/domain/models/user_profile.dart';
import '../../training/application/today_status.dart';
import '../../training/domain/models/models.dart';
import '../../training/presentation/open_today.dart';
import '../application/home_providers.dart';

/// The home screen's copy.
abstract final class HomeLabelsTr {
  /// The greeting for the hour, with the user's first name when there is one.
  static String greeting(DateTime now, String firstName) {
    final int hour = now.hour;
    final String hello = hour >= 5 && hour < 11
        ? 'Günaydın'
        : hour >= 11 && hour < 17
            ? 'İyi günler'
            : hour >= 17 && hour < 22
                ? 'İyi akşamlar'
                : 'İyi geceler';
    return firstName.isEmpty ? hello : '$hello, $firstName';
  }

  static const List<String> _months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const List<String> _weekdays = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  /// The date, as it is written in Turkish: "5 Ekim Pazar".
  static String date(DateTime now) =>
      '${now.day} ${_months[now.month - 1]} ${_weekdays[now.weekday - 1]}';

  /// The streak, or that there is none yet.
  static String streak(int days) =>
      days > 0 ? '$days günlük seri' : 'Seri henüz yok';

  /// The minutes trained, on the account.
  static String totalMinutes(int minutes) => 'Toplam $minutes dk';

  /// Over the card.
  static const String todayTitle = 'Bugünün antrenmanı';

  /// A day of the programme, by its title, or by its number when the
  /// content gives it none. The titles say the day themselves
  /// ("1. gün: Nefesin temeli").
  static String day(int day, String title) =>
      title.trim().isEmpty ? 'Gün $day' : title.trim();

  /// How much the day holds and takes.
  static String dayLength(int exercises, int minutes) =>
      '$exercises egzersiz · yaklaşık $minutes dk';

  /// Starts the day.
  static const String start = 'Antrenmana başla';

  /// Carries on with the session the device kept.
  static const String resume = 'Kaldığınız yerden devam edin';

  /// How far the kept session got.
  static String resumeProgress(int done, int total) =>
      '$total egzersizin $done tanesi tamam';

  /// The day could not be read from the account.
  static const String dayAssumed =
      'Gününüz bağlantı gelince doğrulanacak; şimdilik ilk günden başlıyor.';

  /// Some of the day's exercises are not in this build.
  static String dayShort(int missing) =>
      '$missing egzersiz bu sürümde yok; gün onlarsız sürüyor.';

  /// A day with nothing to run.
  static const String dayEmpty = 'Bugün çalışılacak egzersiz yok.';

  /// The day was finished today.
  static const String doneTitle = 'Bugünkü antrenman tamam';

  /// What comes next.
  static String nextDay(int day, String title) =>
      'Sıradaki: ${HomeLabelsTr.day(day, title)}';

  /// The finished day is still on its way to the account.
  static const String doneUnrecorded =
      'Bağlantı gelince hesabınıza kaydedilecek.';

  /// Starts the next day straight away, which the programme allows.
  static const String startNext = 'Sıradaki günü şimdi başlat';

  /// The programme is done.
  static const String finishedTitle = 'Programı tamamladınız';

  /// What it came to.
  static String finishedSummary(int minutes, int longest) =>
      'Toplam $minutes dakika çalıştınız; en uzun seriniz $longest gün.';

  /// Where to go on from here.
  static const String finishedNext =
      'Pratik sekmesinden istediğiniz egzersizi çalışmaya devam edebilirsiniz.';
}

/// Where the sun stands at [now], for the scene over the home screen.
///
/// It rises in the morning, is highest early in the afternoon and sets in the
/// evening; at night it is behind the hills. The same shares as
/// `CutPaperScene.sunHeight`: smaller is higher.
double sunHeightAt(DateTime now) {
  final double hour = now.hour + now.minute / 60;
  if (hour < 6 || hour >= 20) {
    return 0.8;
  }
  // From 0 at six in the morning to 1 at eight in the evening.
  final double t = (hour - 6) / 14;
  final double fromNoon = 2 * t - 1;
  return 0.12 + 0.5 * fromNoon * fromNoon;
}

/// The first tab (#23): today's training, with one way into it.
///
/// Under the app's cut paper, with the sun where it is at this hour of the
/// day, the user is greeted and shown their streak, then today's training:
/// the day, how long it takes and one button. The button carries on with a
/// session the device kept for this same day, and starts the day otherwise.
/// A day finished today, a finished programme and a day that could not be
/// read each say so instead.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(clockProvider)();
    final AsyncValue<TodayStatus> today = ref.watch(todayStatusProvider);
    final UserProfile? profile =
        ref.watch(currentUserProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _Header(now: now, profile: profile),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: today.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: LoadingView(),
                ),
                error: (Object error, StackTrace _) => ErrorView(
                  failure: error is Failure ? error : mapErrorToFailure(error),
                  onRetry: () => ref.invalidate(todayStatusProvider),
                ),
                data: (TodayStatus status) => _Today(
                  status: status,
                  profile: profile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for today again.
  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(todayStatusProvider);
      await ref.read(todayStatusProvider.future);
    } on Object {
      // Shown in place of today, with a way to try again. Let through, it
      // would reach the crash reporter as a crash.
    }
  }
}

/// The scene, the greeting and the streak.
class _Header extends StatelessWidget {
  const _Header({required this.now, required this.profile});

  final DateTime now;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final double scene = (media.size.height * 0.2).clamp(120.0, 170.0);
    final String name = profile?.displayName.trim() ?? '';
    final String firstName =
        name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The scene on its own: written over, the greeting met the sun at
        // some hours and the hills with large text.
        SizedBox(
          height: media.padding.top + scene,
          child: CutPaperScene(
            top: media.padding.top,
            sunHeight: sunHeightAt(now),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  HomeLabelsTr.greeting(now, firstName),
                  style: text.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                HomeLabelsTr.date(now),
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (profile != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _Stat(
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.sunrise,
                  label: HomeLabelsTr.streak(profile!.currentStreak),
                ),
                _Stat(
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.primary,
                  label: HomeLabelsTr.totalMinutes(
                    profile!.totalTrainingMinutes,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A figure from the account, as a pill.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(child: Icon(icon, size: 18, color: iconColor)),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Today, in whichever state it is in.
class _Today extends ConsumerWidget {
  const _Today({required this.status, required this.profile});

  final TodayStatus status;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TodayTraining today = status.today;
    if (today.isProgramFinished) {
      // The day past the last is what a finished programme is (`TRAINING.md`).
      ref.watch(programFinishedReportProvider(today.programDay - 1));
      return _Card(
        children: <Widget>[
          const _CardTitle(
            HomeLabelsTr.finishedTitle,
            icon: Icons.emoji_events,
          ),
          if (profile != null)
            _CardLine(
              HomeLabelsTr.finishedSummary(
                profile!.totalTrainingMinutes,
                profile!.longestStreak,
              ),
            ),
          const _CardLine(HomeLabelsTr.finishedNext),
        ],
      );
    }

    if (status.trainedToday(profile) && status.unfinished == null) {
      return _Card(
        children: <Widget>[
          const _CardTitle(HomeLabelsTr.doneTitle, icon: Icons.check_circle),
          if (!today.isEmpty)
            _CardLine(
              HomeLabelsTr.nextDay(today.programDay, today.day?.title ?? ''),
            ),
          if (status.finishedTodayUnrecorded)
            const _CardLine(HomeLabelsTr.doneUnrecorded),
          if (!today.isEmpty && !status.finishedTodayUnrecorded) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => openToday(context, ref, status),
                child: const Text(HomeLabelsTr.startNext),
              ),
            ),
          ],
        ],
      );
    }

    final int minutes = today.estimatedDuration.inMinutes > 0
        ? today.estimatedDuration.inMinutes
        : (today.totalDuration.inSeconds / 60).ceil();
    final int? done = status.unfinished?.completedExerciseIds.length;

    return _Card(
      children: <Widget>[
        Text(
          HomeLabelsTr.todayTitle,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        _CardTitle(HomeLabelsTr.day(today.programDay, today.day?.title ?? '')),
        if (!today.isEmpty)
          _CardLine(HomeLabelsTr.dayLength(today.exercises.length, minutes)),
        if (today.programDayAssumed) const _Note(HomeLabelsTr.dayAssumed),
        if (today.missingExerciseIds.isNotEmpty && !today.isEmpty)
          _Note(HomeLabelsTr.dayShort(today.missingExerciseIds.length)),
        if (today.isEmpty)
          const _CardLine(HomeLabelsTr.dayEmpty)
        else ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          if (done != null) ...<Widget>[
            _CardLine(
              HomeLabelsTr.resumeProgress(done, today.exercises.length),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          ElevatedButton(
            onPressed: () => openToday(context, ref, status),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              done != null ? HomeLabelsTr.resume : HomeLabelsTr.start,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

/// The card today is drawn on.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
}

/// The card's heading.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Text heading = Text(
      title,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(color: AppColors.textPrimary),
    );
    return Semantics(
      header: true,
      child: icon == null
          ? heading
          : Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(icon, color: AppColors.sunrise, size: 28),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: heading),
              ],
            ),
    );
  }
}

/// A line of the card.
class _CardLine extends StatelessWidget {
  const _CardLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
}

/// A note on why the day is not quite as usual.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}
