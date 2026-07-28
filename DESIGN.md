---
name: EL7REEF
description: Arabic-first street football tournament app.
colors:
  background: "#EEF2F6"
  surface: "#F8FAFC"
  surface-raised: "#FDFBF6"
  surface-sunken: "#E7ECF2"
  text-primary: "#17202C"
  text-secondary: "#46566A"
  text-muted: "#617187"
  action: "#315CC6"
  social: "#C84232"
  tactical: "#167247"
  competitive: "#6746B8"
  achievement: "#8A5A00"
  border: "#CDD6E2"
  border-strong: "#8292A7"
typography:
  display:
    fontFamily: "Cairo, sans-serif"
    fontSize: "32px"
    fontWeight: 800
  headline:
    fontFamily: "Cairo, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  title:
    fontFamily: "Cairo, sans-serif"
    fontSize: "16px"
    fontWeight: 700
  body:
    fontFamily: "Cairo, sans-serif"
    fontSize: "14px"
    fontWeight: 400
  label:
    fontFamily: "Cairo, sans-serif"
    fontSize: "12px"
    fontWeight: 700
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  glass-toolbar: "20px"
  glass-preview: "24px"
  glass-navigation: "28px"
  glass-hero: "30px"
spacing:
  space1: "4px"
  space2: "8px"
  space3: "16px"
  space4: "24px"
  space5: "32px"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "#F8FAFC"
    rounded: "{rounded.md}"
    height: "48px"
  card:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.border}"
    rounded: "{rounded.lg}"
  input:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.border-strong}"
    rounded: "{rounded.md}"
  chip:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
---

# Design System: EL7REEF

## 1. Creative North Star

**Daylight Street Glass — زجاج خط التماس**

The governing scene is an organizer using one hand beside a football pitch in
daylight. Content is high-contrast and grounded; Liquid Glass gives navigation,
heroes, transient controls, and previews a clear spatial layer. It never makes
dense tournament data harder to scan.

- Arabic RTL first and Android light-only.
- One obvious next action per operational state.
- Names, scores, qualification, and earned pride own the visual hierarchy.
- Real team marks, player photos, and match data provide variety; decoration
  does not compete with them.
- Pride exports and pitch/camera canvases keep their stable dark media palette.

## 2. Chalk & Cobalt palette

The static app background runs from `#F6F8FB` to `#EEF2F6`. It may contain one
contextual radial glow at 7% opacity. Backgrounds never animate.

- **Action Cobalt (`#315CC6`)**: primary action, current focus, and active
  navigation.
- **Social Heat (`#C84232`)**: invitations and share-first actions, never errors.
- **Verified Turf (`#167247`)**: approved results and completed tactical states.
- **Knockout Violet (`#6746B8`)**: unresolved and current knockout paths.
- **Earned Gold (`#8A5A00`)**: champion, MVP, hat-trick, and real milestones only.
- **Daylight Chalk (`#EEF2F6`)**: app background.
- **Paper Card (`#F8FAFC`)**: cards, rows, tables, and forms.
- **Warm Raised Surface (`#FDFBF6`)**: dialogs and short sheets.
- **Ink (`#17202C`)**: primary text.
- **Steel (`#CDD6E2` / `#8292A7`)**: separators and clear control borders.

Only one saturated accent may dominate a functional region. Secondary actions
remain neutral until selected.

## 3. Functional Liquid Glass

Glass is a functional layer, not a card style. Screens select a semantic role
from `AppGlassTheme`; they cannot invent blur or opacity values.

| Role | Fill | Blur | Radius | Usage |
|---|---|---:|---:|---|
| navigation | `#F8FAFC` 78% | 18 | 28 | floating app navigation |
| hero | `#F8FAFC` 70% | 16 | 30 | one identity/next-action hero |
| floatingToolbar | `#F8FAFC` 72% | 12 | 20 | filters, bracket, pitch controls |
| compactSheet | `#FDFBF6` 91% | 16 | 28 | short sheets without keyboard |
| previewToolbar | `#F8FAFC` 74% | 14 | 24 | Pride composer controls |
| mediaOverlay | `#17202C` 58% | 10 | 20 | controls over pitch/image/camera |

Every role uses a 1dp outer edge (`#8292A7` at 24%), a 0.75dp top reflection,
opaque text/icons, and a restrained charcoal shadow at 10–13%. Semantic tint is
at most 8%.

### Interaction

- Press: scale to `0.98` with a 10% cobalt state layer over 150ms.
- Selection: 220ms using `easeOutQuart`.
- Short sheet: 250ms using `easeOutQuart`.
- Never animate blur or run continuous shine.
- Never nest glass inside glass.

### Layer budget and fallback

- Use `BackdropFilter.grouped` inside one `El7reefGlassScope`.
- At most two glass filters may be visible on an operational route.
- A covered route stops its backdrop filters while a modal sheet is open.
- `El7reefLens` expresses repeated selected states without blur.
- `El7reefSolidSurface` owns cards, forms, errors, rows, and tables.
- Render the same solid fallback geometry when functional glass is disabled,
  reduced effects/high contrast is enabled, animations are disabled, or a
  keyboard is visible in a long sheet.

## 4. Typography and accessibility

Cairo is bundled locally. Operational text is never smaller than 12sp. Scores
use tabular figures and LTR direction only for the numeric score.

- Small text contrast: at least 4.5:1.
- Large text and essential non-text boundaries: at least 3:1.
- Android touch targets: at least 48×48dp.
- Text and icons on glass remain fully opaque.
- `disableAnimations`, `accessibleNavigation`, high contrast, and the glass
  kill switch all select the solid fallback.

## 5. Screen grammar

- **Login / Splash:** one light-surface brand Hero.
- **Home / Explore:** floating glass navigation; one featured/next-action Hero;
  all tournament and match cards are solid.
- **Tournament list:** glass search/filter toolbar; solid tournament cards.
- **Tournament detail / operations:** one glass identity/progress/next-action
  Hero, then solid data and action surfaces.
- **Groups / standings:** glass group selector and progress control; solid table.
- **Bracket:** light canvas, solid match nodes, and one glass round/zoom toolbar.
- **Lineup:** stable dark pitch; glass header/formation/CTA chrome; solid bench
  and player data.
- **Result:** glass step/navigation chrome; solid goals, MVP, and penalties.
- **Pride composer:** glass controls around a solid preview. Export output never
  includes live glass or a `BackdropFilter`.
- **Camera / QR:** dark camera canvas with `mediaOverlay` controls. QR modules and
  quiet zone stay opaque black and white.

## 6. Stable media palette

`AppMediaColors` is independent from the light operational theme. It owns Pride
exports, dark lineup/pitch canvases, camera overlays, and code-native identity
art. A theme refactor must not alter exported pixels.

Do not use operational `AppColors` inside pure export render trees. Do not use
glass, network-dependent decoration, or hidden animations during capture.

## 7. Built-in identity presets

- Team captains choose original badges or street pennants; tournament
  organizers choose tournament emblems.
- Presets use flat silhouettes, at most two accents plus a neutral, and must
  remain legible at 32dp and 1080px export size.
- Gold, crowns, stars, and trophies remain earned and are not generic presets.
- References stay versioned (`preset://v1/...`) so saved identities survive
  asset reorganization.
- The picker is full-screen RTL, with live preview, a three-column grid, 48dp
  targets, cobalt selection, and one primary confirmation action.
- National flags must come from a verified source. AI-generated real flags are
  forbidden; generation may explore only original fictional marks.

## 8. Do / Do not

**Do** keep most of every operational screen neutral, use one clear primary
action, and let real football data carry the excitement.

**Do** reserve coral for sharing, green for verified state, violet for knockout,
and gold for earned pride.

**Do not** turn lists, tables, player cards, or exported Pride files into glass.

**Do not** replace the previous green dominance with cobalt dominance.

**Do not** expose fake features, dead buttons, decorative tactical analysis, or
an unfinished logo builder.
