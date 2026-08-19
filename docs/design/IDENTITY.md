# HitUp Corporate Identity

**STATUS: BASELINE SELECTED (HIT-007)**

Deliver binary logo/app icons under **HIT-081**. Do not implement Flutter theme code from this document; that is **HIT-008**.

## Selected baseline: "Seafoam" variant

Rationale: HitUp's core exercises are breathing, articulation, and voice training, so a calm, breath-associated palette fits the product better than a generic wellness-app blue or a warm, attention-grabbing yellow. Among the proposed variants, this one also has the best text contrast profile without any color changes, only a role split (see "Accessibility note" below).

### Color tokens

| Token | Role | Hex | Notes |
|---|---|---|---|
| Primary | Interactive (buttons, links, active states) | `#257C6C` | Deep Teal. Paired with white text/icons, contrast ratio approx 5.0:1, passes WCAG AA for normal text. |
| Primary Container | Soft brand surface (cards, chips, highlighted rows) | `#48BCA2` | Seafoam Green. Paired with dark text (`#132522`), contrast ratio approx 6.8:1. Do not pair this with white text, contrast fails (approx 2.3:1). |
| Secondary | Supporting brand color, secondary buttons | `#48BCA2` (Seafoam Green, reused as Secondary when Primary Container role is not applicable) |
| Accent | Decorative highlight, illustrations, progress indicators | `#A3E4D7` | Pale Aqua |
| Background (Light) | App background, light mode | `#F4F9F7` | Mint Mist |
| Surface (Light) | Cards, sheets, dialogs, light mode | `#FFFFFF` | Pure White |
| Background (Dark) | App background, dark mode | `#101A18` | Dark Pine |
| Surface (Dark) | Cards, sheets, dialogs, dark mode | `#1B2A27` | Deep Jade Gray |
| Text Primary (Light) | Body/heading text on light backgrounds | `#132522` | Deep Forest Ink |
| Text Secondary (Light) | Muted/supporting text on light backgrounds | `#516B66` | Slate Teal |
| Text Primary (Dark) | Body/heading text on dark backgrounds | `#E8F6F3` | Ice Mint |
| Text Secondary (Dark) | Muted/supporting text on dark backgrounds | `#8EABA5` | Muted Teal Gray |
| Success | Positive state, completion, streak kept | `#2ECC71` | Emerald |
| Error | Errors, destructive actions | `#E74C3C` | Coral Red |
| Warning | Warnings, at-risk streak, non-blocking issues | `#F39C12` | Soft Ochre |

### Accessibility note

Material 3's `ColorScheme.primary` role is used directly for filled buttons with white foreground text, so it needs a contrast ratio of at least 4.5:1 against white. The raw Seafoam Green swatch (`#48BCA2`) does not meet that on its own (approx 2.3:1), so it is used as **Primary Container** instead (paired with dark text, which does pass), while the darker **Deep Teal** (`#257C6C`) fills the **Primary** role. No hex values were changed from the original proposal, only which role each color plays. This split should carry through unchanged into HIT-008's `ColorScheme` mapping.

### Typography

| Role | Font | Notes |
|---|---|---|
| Headings | Manrope | Expressive geometric sans, not a system default. |
| Body | Plus Jakarta Sans | Neutral, highly legible at small sizes for exercise instructions. |

Both are available on Google Fonts and free for commercial use.

### Spacing scale

| Token | Value |
|---|---|
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |
| xxl | 48px |

### Radius scale

| Token | Value |
|---|---|
| sm | 6px |
| md | 12px |
| lg | 20px |
| pill | 999px |

### Logo / icon direction

A seafoam-gradient sound and breath cycle mark: a simple looping wave form that reads at once as a voice waveform and a breathing rhythm, on a white or dark-pine background depending on context. Keep it legible at launcher-icon size (avoid fine gradient detail that disappears when scaled down); HIT-081 delivers the final production asset.

### UI personality notes

Calm, encouraging, and unhurried. This is a daily practice habit app, not a clinical tool, so surfaces should feel airy (generous spacing, soft container colors) rather than dense or alarming. Reserve Error/Warning colors strictly for their semantic meaning; do not use them decoratively.

### Dark mode readiness

Dark-mode tokens are defined above so the design system is future-friendly, but per HIT-007 scope, shipping dark mode in the MVP is optional and can be scheduled as a later issue.

---

## Other variants considered

The intern proposed three initial directions; all three are documented below with the same accessibility-driven role split applied (original hex values unchanged, only role assignment corrected so buttons stay readable). A fourth variant was added as an alternative with a different thematic direction. None of these is the baseline; they are kept here for context on why "Seafoam" was chosen and as a reference if the baseline is revisited later.

### Variant: "Butter Yellow"

| Token | Role | Hex |
|---|---|---|
| Primary | Interactive | `#D97706` (Warm Amber; use dark text `#262320` as foreground, not white; contrast approx 4.9:1) |
| Primary Container | Soft brand surface | `#FEF3C7` (Soft Butter Tint) |
| Secondary | Supporting | `#84A98C` (Soft Sage) |
| Accent | Decorative | `#FDE68A` (Butter Yellow) |
| Background / Surface (Light) | `#FAFAF5` / `#FFFFFF` |
| Background / Surface (Dark) | `#1C1917` / `#292524` |
| Text Primary / Secondary (Light) | `#262320` / `#6B635B` |
| Text Primary / Secondary (Dark) | `#F5F5F4` / `#A8A29E` |
| Success / Error / Warning | `#43A047` / `#E53935` / `#FB8C00` |
| Fonts | Plus Jakarta Sans (headings), Outfit (body) |

Not selected because a yellow-family Primary sits visually close to the Warning color, which risks buttons being misread as warning states, and the palette reads as generic "friendly habit app" rather than something specific to voice/speech training.

### Variant: "Baby Blue"

| Token | Role | Hex |
|---|---|---|
| Primary | Interactive | `#3A6B88` (Royal Slate; white foreground, contrast approx 5.8:1) |
| Primary Container | Soft brand surface | `#89CFF0` (Baby Blue) |
| Secondary | Supporting | `#B0C4DE` (Soft Periwinkle) |
| Accent | Decorative | `#E1F0F8` (Ice Sky) |
| Background / Surface (Light) | `#F5F9FC` / `#FFFFFF` |
| Background / Surface (Dark) | `#0F172A` / `#1E293B` |
| Text Primary / Secondary (Light) | `#0F172A` / `#475569` |
| Text Primary / Secondary (Dark) | `#F8FAFC` / `#94A3B8` |
| Success / Error / Warning | `#10B981` / `#EF4444` / `#F59E0B` |
| Fonts | Outfit (headings), Nunito Sans (body) |

Not selected because pale blue plus navy is one of the most common palettes in health and productivity apps, so it is the least distinctive option, even though it tested well for contrast and calm tone.

### Variant: "Velvet Stage" (added for contrast against the other three)

The other variants all sit in the same "calm pastel wellness app" register. This one instead draws on HitUp's public-speaking/oratory side (stage presence, being heard, confidence) rather than only the breathing/calm side.

| Token | Role | Hex |
|---|---|---|
| Primary | Interactive | `#5C2A52` (Deep Plum; white foreground, contrast approx 11:1) |
| Primary Container | Soft brand surface | `#EDE1EA` (Soft Lilac Mist) |
| Secondary | Supporting | `#3B1A38` (Aubergine Ink) |
| Accent | Decorative, achievement highlights | `#C9974A` (Brass Gold) |
| Background / Surface (Light) | `#FBF7F2` / `#FFFFFF` |
| Background / Surface (Dark) | `#17111A` / `#241A29` |
| Text Primary / Secondary (Light) | `#241220` / `#6B5F68` |
| Text Primary / Secondary (Dark) | `#F5EFE9` / `#A8969F` |
| Success / Error / Warning | `#3F9142` / `#D63447` / `#E27A33` (kept separate from Accent gold so achievement badges and warnings stay visually distinct) |
| Fonts | Fraunces (headings, serif), Work Sans (body) |
| Logo direction | A minimalist standing-microphone silhouette catching a single spotlight beam, deliberately different from the sound-wave motif shared by the other variants. |

Not selected as the baseline because it is a bigger brand swing (serif display font, darker overall palette) than an M0 foundation issue needs, but kept documented as a strong option if the product direction leans further into the confidence/oratory angle later.
