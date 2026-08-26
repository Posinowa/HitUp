# Using the design tokens

**STATUS: APPROVED (HIT-008)**

[`IDENTITY.md`](IDENTITY.md) decides *what* the brand looks like. This page is
the practical half: how to consume it while building a screen.

**One rule underneath everything: a widget never names a colour, a font or a
radius directly.** It asks the theme. That is what makes a token change reach
the whole app instead of the one screen someone remembered to update.

```dart
// Wrong. This screen will not follow a brand change.
Container(color: const Color(0xFF257C6C))
Text('Merhaba', style: TextStyle(fontFamily: 'Manrope', fontSize: 22))

// Right.
Container(color: Theme.of(context).colorScheme.primary)
Text('Merhaba', style: Theme.of(context).textTheme.titleLarge)
```

## Colour

Read colours from `Theme.of(context).colorScheme`. Reach for `AppColors`
directly only when no `ColorScheme` slot fits, for example the status colours.

| You want | Use |
|---|---|
| Buttons, links, active state | `colorScheme.primary` with `colorScheme.onPrimary` |
| Soft brand surface: cards, chips, highlighted rows | `colorScheme.primaryContainer` with `colorScheme.onPrimaryContainer` |
| Secondary actions | `colorScheme.secondary` with `colorScheme.onSecondary` |
| Decorative highlight, progress | `colorScheme.tertiary` |
| Cards, sheets, dialogs | `colorScheme.surface` with `colorScheme.onSurface` |
| Page background | `Scaffold` supplies it; do not paint it yourself |
| Borders, dividers | `colorScheme.outline` |
| Destructive, error state | `colorScheme.error` with `colorScheme.onError` |
| Completion, streak kept | `AppColors.success` |
| At risk streak, non blocking issue | `AppColors.warning` |

Always pair a colour with its `on` partner. That pairing is what carries the
contrast guarantee.

### The one trap worth memorising

`AppColors.primaryContainer` is the lighter Seafoam swatch, and **white text on
it fails contrast** (roughly 2.3:1, well under the 4.5:1 minimum). That is why
the darker Deep Teal holds `primary` and Seafoam sits in `primaryContainer`
paired with dark text.

So: **never put white text or a white icon on the Seafoam swatch.** If a design
seems to ask for that, it is asking for `primary` instead. `app_theme_test.dart`
guards this split, so a swap fails the build rather than shipping.

### Status colours are semantic

`success`, `error` and `warning` mean what they say. Do not use them as
decoration because the shade looks nice.

## Type

Use the named slots. Never build a `TextStyle` with a font family by hand.

| Slot | Face | Use for |
|---|---|---|
| `displaySmall` | Manrope | The one big number or word on a screen |
| `headlineMedium` | Manrope | Screen title |
| `titleLarge` | Manrope | Section heading |
| `titleMedium` | Manrope | Card heading, list row title |
| `bodyLarge` | Plus Jakarta Sans | Exercise instructions, primary reading |
| `bodyMedium` | Plus Jakarta Sans | Supporting text, already muted |
| `labelLarge` | Plus Jakarta Sans | Button and tab labels |

To vary one property, copy the slot instead of rebuilding it:

```dart
Theme.of(context).textTheme.bodyLarge?.copyWith(
  color: Theme.of(context).colorScheme.primary,
)
```

## Spacing and radius

These are plain constants, not part of `ThemeData`, so import them directly.

```dart
import 'package:hitup/core/theme/app_spacing.dart';
import 'package:hitup/core/theme/app_radius.dart';

Padding(padding: const EdgeInsets.all(AppSpacing.md), child: ...)
BorderRadius.circular(AppRadius.lg)
```

`AppSpacing`: `xs` 4, `sm` 8, `md` 16, `lg` 24, `xl` 32, `xxl` 48.
`AppRadius`: `sm` 6, `md` 12, `lg` 20, `pill` 999.

Stay on the scale. A one off `EdgeInsets.all(13)` is how a layout starts
drifting.

## When the token you need does not exist

Do not add a local constant and move on. Either an existing token fits and the
design should use it, or the scale genuinely has a gap and
[`IDENTITY.md`](IDENTITY.md) needs updating first, which is an owner decision.
Raise it on the issue rather than deciding it inside a widget.

## Dark mode

`AppColors` already carries the dark values (`backgroundDark`, `surfaceDark`,
`textPrimaryDark`, `textSecondaryDark`), but no dark `ThemeData` is wired yet.
HIT-008 ships light only, on purpose. The values live there so dark mode can be
added later without re-deriving anything.

Because of that, do not write `if (isDark)` branches in widgets today. When dark
mode arrives it arrives through `ThemeData`, and any widget that reads the
theme properly will follow it for free.

## Related docs

- [`IDENTITY.md`](IDENTITY.md), the approved palette, type scale and rationale
- [`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md)
