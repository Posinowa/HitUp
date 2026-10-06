import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_presenter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cut_paper_scene.dart';
import '../application/onboarding_controller.dart';
import '../domain/onboarding_answers.dart';

/// Onboarding's copy.
abstract final class OnboardingLabelsTr {
  /// Leaves onboarding without answering.
  static const String skip = 'Atla';

  /// To the next page.
  static const String next = 'İleri';

  /// Finishes onboarding.
  static const String start = 'Başla';

  /// What the finish button says to a screen reader while it works.
  static const String starting = 'Hazırlanıyor';

  /// The page indicator, read out.
  static String page(int current, int total) => 'Sayfa $current / $total';

  /// What the two question pages are for, over each question.
  static const String questionsTitle = 'Size göre ayarlayalım';

  /// The first question, on a page of its own.
  static const String goalsQuestion = 'Neyi geliştirmek istiyorsunuz?';

  /// The line under it.
  static const String goalsHint =
      'Birden fazlasını seçebilirsiniz. İsterseniz boş bırakın.';

  /// The second question, on the page after it.
  static const String minutesQuestion = 'Günde ne kadar zaman ayırabilirsiniz?';

  /// The line under it.
  static const String minutesHint = 'Birini seçin ya da boş bırakın.';

  /// A choice of minutes a day.
  static String minutes(int minutes) => '$minutes dk';

  /// Each goal's words.
  static String goal(SpeakingGoal goal) => switch (goal) {
        SpeakingGoal.clarity => 'Daha net konuşmak',
        SpeakingGoal.confidence => 'Kendimden emin konuşmak',
        SpeakingGoal.publicSpeaking => 'Topluluk önünde konuşmak',
        SpeakingGoal.pronunciation => 'Telaffuzumu düzeltmek',
      };
}

/// One page of what the app is: a heading and a line, under the scene.
class _IntroPage {
  const _IntroPage(this.title, this.body, this.sunHeight);

  final String title;
  final String body;

  /// Where the sun is on this page: it rises from page to page.
  final double sunHeight;
}

/// The three pages, in order (HIT-015): speaking better, a few minutes a
/// day, a habit.
const List<_IntroPage> _pages = <_IntroPage>[
  _IntroPage(
    'Daha net konuşun',
    'Nefes, harf ve tekerleme egzersizleriyle sesinizi adım adım çalıştırın.',
    0.45,
  ),
  _IntroPage(
    'Günde birkaç dakika',
    'Her gün kısa bir antrenman yeter. Ne kadar zaman ayıracağınızı siz '
        'seçersiniz.',
    CutPaperScene.dawn,
  ),
  _IntroPage(
    'Bir alışkanlık edinin',
    'Her gün çalıştıkça seriniz büyür, ilerlemenizi görürsünüz.',
    0.28,
  ),
];

/// The first thing a new device shows (HIT-015): three short pages on what
/// the app is, then two optional questions, one page each: what to get better
/// at, then how many minutes a day.
///
/// Every intro page can be skipped, which finishes with whatever was answered
/// so far, usually nothing: onboarding is not shown again either way
/// (`OnboardingController`). Where the user goes next is the router's guard's
/// (`guardedRoute`): login, or home for an account already signed in.
///
/// The pages are the app's cut paper, with the sun rising from one page to
/// the next. They swipe, and the button under them moves on as well.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pager = PageController();
  int _page = 0;
  OnboardingAnswers _answers = const OnboardingAnswers();

  /// The intro pages, then the two questions.
  static final int _pageCount = _pages.length + 2;

  bool get _onIntro => _page < _pages.length;

  bool get _onLastPage => _page == _pageCount - 1;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() => _pager.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  /// Finishes with the answers as they are, from the last page or from an
  /// intro page skipped after answering.
  Future<void> _finish() =>
      ref.read(onboardingControllerProvider.notifier).finish(_answers);

  @override
  Widget build(BuildContext context) {
    // Only a failure is the screen's to show. A finish that worked is
    // followed by the guard, which knows where to go.
    ref.listen<AsyncValue<bool>>(onboardingControllerProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      final Object? error = next.error;
      if ((previous?.isLoading ?? false) && error is Failure) {
        showFailureSnackBar(context, error, onRetry: _finish);
      }
    });
    final AsyncValue<bool> finishing = ref.watch(onboardingControllerProvider);
    // Working, or finished and about to be taken on.
    final bool busy = finishing.isLoading || (finishing.valueOrNull ?? false);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView(
              controller: _pager,
              onPageChanged: (int page) => setState(() => _page = page),
              children: <Widget>[
                for (final _IntroPage page in _pages)
                  _IntroView(page: page, text: text),
                // Applied to the answers as they are now, not as they were
                // when the page was built: two choices before the next frame
                // both count.
                _GoalsView(
                  goals: _answers.goals,
                  enabled: !busy,
                  onGoal: (SpeakingGoal goal) =>
                      setState(() => _answers = _answers.toggling(goal)),
                ),
                _MinutesView(
                  dailyMinutes: _answers.dailyMinutes,
                  enabled: !busy,
                  onMinutes: (int minutes) =>
                      setState(() => _answers = _answers.choosing(minutes)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  _Dots(current: _page, count: _pageCount),
                  const Spacer(),
                  if (_onIntro)
                    TextButton(
                      onPressed: busy ? null : _finish,
                      child: const Text(OnboardingLabelsTr.skip),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : _onLastPage
                            ? _finish
                            : _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 52),
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              semanticsLabel: OnboardingLabelsTr.starting,
                            ),
                          )
                        : Text(
                            _onLastPage
                                ? OnboardingLabelsTr.start
                                : OnboardingLabelsTr.next,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An intro page: the scene, then its heading and line.
class _IntroView extends StatelessWidget {
  const _IntroView({required this.page, required this.text});

  final _IntroPage page;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double scene = (media.size.height * 0.46).clamp(200.0, 420.0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: media.padding.top + scene,
            child: CutPaperScene(
              top: media.padding.top,
              sunHeight: page.sunHeight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    page.title,
                    style: text.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  page.body,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A question on a page of its own: the scene, the question and a line on
/// how to answer it, then the choices.
class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.hint,
    required this.sunHeight,
    required this.choices,
  });

  final String question;
  final String hint;

  /// Where the sun is: it keeps rising from the intro pages.
  final double sunHeight;

  final Widget choices;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final MediaQueryData media = MediaQuery.of(context);
    final double scene = (media.size.height * 0.2).clamp(120.0, 200.0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: media.padding.top + scene,
            child: CutPaperScene(top: media.padding.top, sunHeight: sunHeight),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  OnboardingLabelsTr.questionsTitle,
                  style: text.labelLarge?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  header: true,
                  child: Text(
                    question,
                    style: text.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hint,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                choices,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The first question: what to get better at, any number of goals.
class _GoalsView extends StatelessWidget {
  const _GoalsView({
    required this.goals,
    required this.enabled,
    required this.onGoal,
  });

  final Set<SpeakingGoal> goals;
  final bool enabled;
  final ValueChanged<SpeakingGoal> onGoal;

  @override
  Widget build(BuildContext context) => _QuestionPage(
        question: OnboardingLabelsTr.goalsQuestion,
        hint: OnboardingLabelsTr.goalsHint,
        sunHeight: 0.24,
        // Rows rather than chips: a goal's words wrap onto a second line on
        // a small phone with large text, where a chip's would be cut off.
        choices: Column(
          children: <Widget>[
            for (final SpeakingGoal goal in SpeakingGoal.values)
              CheckboxListTile(
                value: goals.contains(goal),
                onChanged: enabled ? (_) => onGoal(goal) : null,
                title: Text(OnboardingLabelsTr.goal(goal)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      );
}

/// The second question: how many minutes a day, one choice or none.
class _MinutesView extends StatelessWidget {
  const _MinutesView({
    required this.dailyMinutes,
    required this.enabled,
    required this.onMinutes,
  });

  final int? dailyMinutes;
  final bool enabled;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) => _QuestionPage(
        question: OnboardingLabelsTr.minutesQuestion,
        hint: OnboardingLabelsTr.minutesHint,
        sunHeight: 0.18,
        choices: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final int minutes in dailyMinuteChoices)
              ChoiceChip(
                label: Text(OnboardingLabelsTr.minutes(minutes)),
                selected: dailyMinutes == minutes,
                onSelected: enabled ? (_) => onMinutes(minutes) : null,
              ),
          ],
        ),
      );
}

/// Which page is showing, as dots, read out as "Sayfa 2 / 4".
class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: OnboardingLabelsTr.page(current + 1, count),
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                width: i == current ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == current ? AppColors.primary : AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      );
}
