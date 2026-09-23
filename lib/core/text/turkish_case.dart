/// Case folding that follows Turkish rules.
///
/// Turkish uses four letters where most languages use two: `I` pairs with `ı`,
/// and `İ` pairs with `i`. Dart's own `toLowerCase` and `toUpperCase` follow
/// the language-neutral Unicode mapping, which gets one pair right and the
/// other wrong in each direction. Measured on the SDK this project pins:
///
/// | Input | Dart lower | Dart upper | Turkish wants | Fixed here |
/// |---|---|---|---|---|
/// | `I` | `i` | `I` | lower `ı` | yes |
/// | `İ` | `i` | `İ` | lower `i` | already right |
/// | `ı` | `ı` | `I` | upper `I` | already right |
/// | `i` | `i` | `I` | upper `İ` | yes |
///
/// In an app about Turkish diction that is not a detail: a drill for `I` must
/// not answer a request for `i`, and a letter shown in upper case has to keep
/// its dot. The content tests already fold this way; this is that rule in one
/// place for the app to use as well.
library;

/// [value] in lower case, Turkish rules.
///
/// `I` becomes `ı`. The replacement runs before `toLowerCase`, because
/// afterwards `I` has already become `i` and the two letters can no longer be
/// told apart.
///
/// `İ` needs no replacement: the neutral mapping already lowercases it to a
/// single `i`, which is the Turkish answer too. That is an SDK behaviour rather
/// than a promise of this function, so the test pins it; if it ever changes,
/// `İ` gets a replacement here like `I` has.
String turkishLowerCase(String value) =>
    value.replaceAll('I', 'ı').toLowerCase();

/// [value] in upper case, Turkish rules.
///
/// `i` becomes `İ`; `ı` becomes `I`, which the neutral mapping already does.
String turkishUpperCase(String value) =>
    value.replaceAll('i', 'İ').toUpperCase();

/// Whether [a] and [b] are the same text ignoring case, in Turkish.
bool turkishEqualsIgnoringCase(String a, String b) =>
    turkishLowerCase(a) == turkishLowerCase(b);
