# Flutter Template — Theming Guide

**Status**: ✅ Synchronized with mapanytime-app design system

---

## 📋 Overview

The Flutter template now follows the **mapanytime-app design system** — a clean, ink-on-white palette emphasizing content over brand color. This guide documents the theming structure and design tokens.

---

## 🎨 Design System

### Color Palette

#### Ink (Primary Accent)
- **Ink Primary**: `#0D0D0F` (near-black) — Main accent, buttons, borders
- **Ink Pressed**: `#000000` (pure black) — Pressed/hover state

#### Surfaces
- **Background**: `#F7F7F8` (very light gray) — App background
- **Surface**: `#FFFFFF` (white) — Primary surfaces (cards, input backgrounds)
- **Surface Muted**: `#F5F5F6` (light gray) — Nested surfaces, input fills
- **Border**: `#ECEDF0` (hairline gray) — Subtle borders and dividers

#### Text
- **Primary**: `#14161C` (dark gray) — Body text, headings
- **Secondary**: `#6B7280` (medium gray) — Secondary text, hints
- **Tertiary**: `#9AA0AE` (light gray) — Captions, subtle labels
- **On Ink**: `#FFFFFF` (white) — Text on ink backgrounds

#### Status
- **Error**: `#E5484D` (red)
- **Success**: `#2FA36B` (green)
- **Warning**: `#D89614` (amber)

### Typography

**Font Family**: Inter (via Google Fonts)

| Style | Size | Weight | Height | Letter Spacing |
|-------|------|--------|--------|----------------|
| Display Small | 34 | 800 | 1.1x | -0.5 |
| Headline Large | 28 | 700 | 1.15x | -0.3 |
| Headline Medium | 24 | 700 | 1.2x | — |
| Title Large | 20 | 700 | — | — |
| Title Medium | 16 | 600 | — | — |
| Title Small | 14 | 600 | — | — |
| Body Large | 16 | 500 | 1.4x | — |
| Body Medium | 14 | 500 | 1.45x | — |
| Body Small | 12 | 400 | 1.4x | — |
| Label Large | 14 | 600 | — | — |
| Label Medium | 12 | 600 | — | — |
| Label Small | 11 | 500 | — | 0.3 |

### Spacing

Consistent 8px baseline:
- `xs`: 4px
- `sm`: 8px
- `md`: 16px
- `lg`: 24px
- `xl`: 32px
- `xxl`: 48px
- `xxxl`: 72px

### Border Radius

- `sm`: 12px (small buttons, components)
- `md`: 16px (input fields, small cards)
- `lg`: 20px (larger cards)
- `card`: 24px (default card radius)
- `xl`: 28px (hero panels, sheets)
- `pill`: 999px (fully rounded: pills, chips, FABs)

---

## 🔧 Implementation

### File Structure

```
lib/theme/
├── app_theme.dart           # Central theme facade
├── light_theme.dart         # Light theme configuration
├── dark_theme.dart          # Dark theme (mirrors light)
├── tokens/
│   ├── colors.dart          # Color tokens (ink, ui, text, status)
│   ├── typography.dart      # Text styles, Inter font
│   ├── spacing.dart         # Spacing constants
│   ├── radius.dart          # Border radius tokens
│   └── effects.dart         # Shadows, elevation, effects
└── components/
    ├── button_theme.dart    # Elevated button styling
    ├── card_theme.dart      # Card styling
    └── input_theme.dart     # Input field styling
```

### Component Styling

#### Buttons
- **Style**: Elevated, filled with ink background
- **Text Color**: White (#FFFFFF)
- **Padding**: 24px horizontal × 16px vertical
- **Radius**: Fully rounded (pill radius 999px)
- **Elevation**: None (0)

Example:
```dart
ElevatedButton(
  onPressed: () {},
  child: const Text('Submit'),
)
```

#### Cards
- **Background**: White (#FFFFFF)
- **Radius**: 24px
- **Elevation**: 1
- **Clipping**: Antialiased

Example:
```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Text('Card content'),
  ),
)
```

#### Input Fields
- **Fill Color**: Muted surface (#F5F5F6)
- **Focus Border**: Ink color with 2px width
- **Error Border**: Red (#E5484D) with 2px width
- **Radius**: 20px
- **Padding**: 16px

Example:
```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Enter text',
  ),
)
```

---

## 🎯 Usage Guidelines

### Color Access

Access colors through the design tokens:

```dart
import 'package:flutter_template/theme/tokens/colors.dart';

// Use color tokens
Color primary = AppColors.ink.primary;
Color background = AppColors.ui.background;
Color errorText = AppColors.status.error;
Color hintText = AppColors.text.tertiary;
```

**Do NOT use hardcoded colors**. Always reference `AppColors.*`.

### Typography Access

```dart
import 'package:flutter_template/theme/tokens/typography.dart';

// Get text theme
TextStyle heading = Theme.of(context).textTheme.headlineLarge!;
TextStyle body = Theme.of(context).textTheme.bodyMedium!;
```

### Spacing Access

```dart
import 'package:flutter_template/theme/tokens/spacing.dart';

// Use spacing tokens
Padding(
  padding: EdgeInsets.all(AppSpacing.md),
  child: Text('Padded text'),
)

// Or use extensions
Row(
  children: [
    Text('Left'),
    AppSpacing.hMd, // Horizontal spacer
    Text('Right'),
  ],
)
```

### Radius Access

```dart
import 'package:flutter_template/theme/tokens/radius.dart';

// Use radius tokens
Container(
  decoration: BoxDecoration(
    borderRadius: AppRadius.brCard,
  ),
)
```

---

## 🌓 Theme Switching

The app currently uses **light theme only** (matching mapanytime-app).

To implement a dark theme in the future:

1. Update `DarkTheme.build()` in `lib/theme/dark_theme.dart`
2. Define dark-specific colors in `AppColors` (add `*Dark` variants)
3. Implement a theme provider (using Provider, Riverpod, etc.)
4. Update `app.dart` to use the selected theme

---

## 📱 Responsive Design

Tablet layout breakpoint:

```dart
bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.width >= 840;
}
```

Adapt layouts at this breakpoint for larger screens.

---

## ✨ Design Principles

1. **Content First**: Ink accent doesn't compete with content
2. **Clean & Professional**: Minimal color, maximum clarity
3. **Accessible**: Strong contrast (near-black ink on white)
4. **Consistent**: Centralized tokens ensure uniformity
5. **Performant**: Light color scheme, minimal shadows

---

## 🔄 Synchronization with mapanytime-app

This template matches mapanytime-app v3.44.8:
- ✅ Color palette: Ink-on-white
- ✅ Typography: Inter font, same scale
- ✅ Spacing: 8px baseline system
- ✅ Radius: Card (24px), pill (fully rounded)
- ✅ Components: Button (pill), card (24px), input (20px radius)
- ✅ Material 3: Enabled, light theme

---

## 📖 References

- [Flutter Material Design](https://material.io/design)
- [Google Fonts - Inter](https://fonts.google.com/specimen/Inter)
- [Flutter ThemeData](https://api.flutter.dev/flutter/material/ThemeData-class.html)
- mapanytime-app design system (`lib/theme/`)
