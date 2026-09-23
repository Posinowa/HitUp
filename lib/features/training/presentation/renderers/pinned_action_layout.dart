import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_spacing.dart';

/// A renderer's body when it has an action the user takes again and again,
/// such as counting one more saying.
///
/// Where they fit, the content and the action sit together in the middle of
/// the room. Where the content is taller than the room, it scrolls in what
/// the action leaves, and the action stays in view at the bottom. Scrolled
/// together with the content, the action would end up below the fold on a
/// small phone, and would have to be scrolled to before every tap.
///
/// Needs a bounded height, which the exercise screen gives every renderer.
class PinnedActionLayout extends StatelessWidget {
  /// Lays out [content] above [action].
  const PinnedActionLayout({
    required this.content,
    required this.action,
    super.key,
  });

  /// What the drill shows. Scrolled when it does not fit.
  final Widget content;

  /// What the user does. Always in view, under the content.
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Loose, so content that fits takes only its own height and stays
          // next to the action; content that does not fit takes the rest.
          Flexible(
            child: SingleChildScrollView(child: content),
          ),
          const SizedBox(height: AppSpacing.md),
          action,
        ],
      );
}
