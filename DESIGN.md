---
name: EL7REEF
description: The ultimate street football tournament app.
colors:
  primary: "#7ED957"
  primary-dark: "#1F7A3E"
  primary-light: "#4ADE80"
  neutral-bg: "#121212"
  neutral-surface: "#1E1E1E"
  neutral-border: "#2A2A2A"
  text-primary: "#FFFFFF"
  text-secondary: "#A0A0A0"
  text-muted: "#64748B"
  secondary: "#F5A623"
  accent: "#4A90D9"
typography:
  display:
    fontFamily: "Cairo, sans-serif"
    fontSize: "32px"
    fontWeight: 700
  headline:
    fontFamily: "Cairo, sans-serif"
    fontSize: "20px"
    fontWeight: 600
  title:
    fontFamily: "Cairo, sans-serif"
    fontSize: "16px"
    fontWeight: 600
  body:
    fontFamily: "Cairo, sans-serif"
    fontSize: "14px"
    fontWeight: 400
  label:
    fontFamily: "Cairo, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    letterSpacing: "0.5px"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
spacing:
  space1: "4px"
  space2: "8px"
  space3: "16px"
  space4: "24px"
  space5: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#0B0B0B"
    rounded: "{rounded.md}"
    height: "48px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    height: "48px"
  card:
    backgroundColor: "{colors.neutral-surface}"
    rounded: "{rounded.lg}"
  input:
    backgroundColor: "{colors.neutral-surface}"
    rounded: "{rounded.md}"
  chip:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
---

# Design System: EL7REEF

## 1. Overview

**Creative North Star: "The Champion's Hub"**

The EL7REEF UI is designed to feel highly aggressive and competitive. It channels the raw energy of street football into a structured, professional, and imposing digital arena. We embrace high contrast, bold typography, and a dark, moody environment to make every tournament feel like a high-stakes championship. The design explicitly rejects boring data-entry tables and generic SaaS styling, opting instead for a street-authentic, hype-driven aesthetic that makes players feel like true stars.

**Key Characteristics:**
- **Aggressive & Competitive:** High contrast and bold elements that demand attention.
- **Ego-Driven:** Big typography and prominent player cards to amplify pride.
- **Deep & Moody:** A dark canvas that makes the bright turf green pop intensely.
- **Tactile:** Elements you want to press, with satisfying, chunky interactions.

## 2. Colors

A deep, imposing dark canvas punctuated by aggressive, electric accents.

### Primary
- **Electric Pitch** (#7ED957): The lifeblood of the app. Used for primary actions, active states, and to draw the eye immediately to the most critical interactive elements.
- **Neon Glow** (#4ADE80): A lighter, hotter green used for gradients and hover states to give elements a radioactive lift.
- **Deep Turf** (#1F7A3E): A darker, more grounded green for pressed states or subtle background tints behind primary text.

### Secondary
- **Championship Gold** (#F5A623): Reserved exclusively for moments of high achievement—ranks, MVP badges, and tournament victories.

### Tertiary
- **Electric Blue** (#4A90D9): Used sparingly for secondary ratings or to contrast against the primary green in data visualizations.

### Neutral
- **Midnight Asphalt** (#121212): The absolute background of the app. It absorbs light and creates a void that makes the electric accents shine.
- **Stadium Shadow** (#1E1E1E): Used for elevated surfaces like cards and dialogs, lifting them slightly off the asphalt.
- **Chalk Line** (#2A2A2A): The subtle border color used to define edges without distracting from the content.
- **Bright White** (#FFFFFF): Primary text color for maximum legibility against the dark backgrounds.
- **Muted Dust** (#A0A0A0): Secondary text for less critical information.

**The Electric Focus Rule.** The primary green (Electric Pitch) is incredibly powerful. Use it deliberately for primary CTAs and active states. Do not wash the screen in it; its impact comes from its contrast against the Midnight Asphalt.

## 3. Typography

**Display Font:** Cairo (with system sans-serif fallback)
**Body Font:** Cairo (with system sans-serif fallback)

**Character:** Cairo provides a strong, legible Arabic and Latin presence. It feels modern, structural, and slightly aggressive in its heavier weights, perfect for a sports context.

### Hierarchy
- **Display** (Bold 700, 32px): Massive impact. Used for hero numbers, final scores, and top-level tournament names.
- **Headline** (SemiBold 600, 20px): Section headers and prominent card titles.
- **Title** (SemiBold 600, 16px): Standard list items, player names in rosters.
- **Body** (Regular 400, 14px): General descriptive text, secondary stats.
- **Label** (Bold 700, 12px, 0.5px letter-spacing): Small, uppercase/distinct tags, status indicators, and button text.

**The Ego Type Rule.** Names and scores are the most important data in the app. They should always be typeset larger and bolder than standard data-entry labels.

## 4. Elevation

The system is generally grounded, but uses subtle neon glows and shadows to make important elements "lift" off the screen, emphasizing interactivity and status.

### Shadow Vocabulary
- **Neon Lift** (`box-shadow: 0 4px 12px rgba(126, 217, 87, 0.25)`): Applied to primary buttons or active elements to give them an electric, glowing hover state.
- **Card Shadow** (`box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4)`): A deep, heavy drop shadow used for floating dialogs and elevated hero cards to pull them out of the Midnight Asphalt.

**The Tactical Glow Rule.** Glows are earned, not given. Only the most important, interactive elements (like the "Start Match" button or an MVP card) get the Neon Lift. Everything else remains grounded with subtle borders.

## 5. Components

### Buttons
- **Shape:** Tactile and chunky with medium rounded corners (12px).
- **Primary:** Electric Pitch background with stark black text (#0B0B0B). Thick padding, minimum height of 48px.
- **Hover / Focus:** Receives the Neon Lift glow, background shifts slightly to Neon Glow.
- **Secondary (Outlined):** Transparent background with a 1px Electric Pitch border and Electric Pitch text.

### Cards / Containers
- **Corner Style:** Slightly softer than buttons (16px radius) to contain complex content.
- **Background:** Stadium Shadow (#1E1E1E).
- **Shadow Strategy:** Grounded by default (flat with Chalk Line border). Hero cards receive Card Shadow.
- **Internal Padding:** 16px standard, utilizing the 8px grid.

### Inputs / Fields
- **Style:** Filled with Stadium Shadow, 12px radius, and a subtle Chalk Line border.
- **Focus:** Border snaps to a 2px Electric Pitch stroke, bringing the input into sharp focus.

### Chips (Tags)
- **Style:** 15% opacity primary background with Electric Pitch text. Small 8px radius.
- **State:** Used for statuses (e.g., "Guest", "Pending").

## 6. Do's and Don'ts

### Do:
- **Do** use Electric Pitch (#7ED957) sparingly but aggressively for primary actions to maximize its punch.
- **Do** use large, bold Cairo typography for player names, team names, and match scores.
- **Do** make interactive elements feel tactile and chunky, with 48px minimum hit areas.
- **Do** apply subtle neon glows to highlight the most critical actions on the screen.

### Don't:
- **Don't** use boring, generic SaaS tables for standings; make them feel like a sports leaderboard.
- **Don't** build complex admin dashboard layouts; maintain a street-authentic, mobile-first vibe.
- **Don't** include fake features or "coming soon" buttons that dilute the app's real value.
- **Don't** wash the screen in green; let the Midnight Asphalt dominate so the accents shine.
- **Don't** use border-left greater than 1px as a colored stripe on cards.
- **Don't** use glassmorphism as a default decorative element unless it specifically serves a tactical purpose (like a modal overlay).
