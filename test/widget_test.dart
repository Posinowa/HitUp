import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/core/theme/app_theme.dart';

void main() {
  testWidgets('foundation app builds and shows HitUp placeholder',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HitUpApp()));
    await tester.pumpAndSettle();

    expect(find.text('HitUp'), findsOneWidget);
    expect(find.text('Project foundation initialized.'), findsOneWidget);
  });

  test('AppTheme.light provides Material 3 ColorScheme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
  });
}
