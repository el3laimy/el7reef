# Friendly Match Core Loop QA Checklist

## 1. Purpose

This checklist validates the V1 friendly match journey in El7reef:

Create Match -> Add Players -> Optional Lineup -> Start Match -> Submit Result -> Share Lineup/Result

Use it after Friendly Match Core Loop changes to confirm that organizers can complete the MVP journey without misleading counts, hidden share actions, blocked optional lineups, dead buttons, or broken Arabic RTL UI.

Temporary players must be treated as real match participants throughout the flow. Lineups are optional, but the UI should clearly encourage creating and sharing them. Result sharing must be available immediately after score submission and later from the match list.

## 2. Test Setup

- Use a test account that is logged in.
- Use an Android device or Android emulator when possible.
- Confirm the account can create a friendly match.
- If available, prepare at least one registered friend account.
- Temporary players must still be tested even if no registered friends exist.
- Recommended test match size: 7v7.
- Test both sides: Team A and Team B, including temporary sides.
- Keep a note of any known unrelated automated test failures. Manual QA remains required for this core flow when `flutter test` has unrelated failures.

## 3. Core Scenario Summary

Run the full happy path once before detailed edge checks:

1. Create a 7v7 friendly match.
2. Add registered players if available.
3. Add temporary players to both Team A and Team B.
4. Verify participant counts in Home, Discover, and Lobby.
5. Open the lineup editor.
6. Save a lineup.
7. Share the lineup.
8. Start the match.
9. Submit a score.
10. Share the result immediately after score submission.
11. Return later and share the result from the match list/discover card.

Recommended data set:

- Add 2 registered players if available.
- Add 6 temporary players total.
- Make sure temporary players are present on both A and B sides.
- Include at least one long temporary player name to check layout resilience.

## 4. Checklist Sections

### A. Create Friendly Match

Steps:

- Open the matches/discover area.
- Tap the create/start match action.
- Create a friendly match with size 7v7.
- Leave optional location empty once, then repeat with a location if time allows.

Expected result:

- A friendly match is created successfully.
- The app opens the match lobby or provides a clear way to enter it.
- The match shows the selected 7v7 size.
- Arabic text is readable and aligned RTL.

Red flags / failure signs:

- The user is pushed into tournament, fantasy, or unrelated social flows.
- The match size is wrong or silently resets without explanation.
- Create action is hidden, dead, or shows a misleading "قريبًا" message.
- Buttons or Arabic labels are clipped on mobile.

### B. Add Registered Players

Steps:

- In the friendly match lobby, open Team A.
- Add registered players if friends are available.
- Repeat for Team B if possible.
- Target case: add 2 registered players total across the match.

Expected result:

- Registered players can be added to the intended side.
- Players do not appear duplicated on both sides.
- The lobby updates counts and player lists without a full restart.
- Arabic side labels and player names remain readable.

Red flags / failure signs:

- Registered player add action is disabled without explanation.
- Adding a player changes the wrong side.
- A player appears twice or is counted twice.
- The UI suggests registered players are required before temporary players can be used.

### C. Add Temporary Players

Steps:

- In the lobby, use Team A -> "أضف لاعب مؤقت".
- Add multiple temporary players.
- Use Team B -> "أضف لاعب مؤقت".
- Add temporary players to Team B too.
- Include a long name, for example a multi-word Arabic name with a nickname.

Expected result:

- Temporary players can be added to both A and B sides.
- Temporary players appear in the side player list.
- Temporary players are visually distinguishable where the UI supports it.
- No flow requires these players to have accounts.

Red flags / failure signs:

- Temporary player action is missing from either side.
- Temporary player action shows "قريبًا".
- Temporary players are saved but not displayed.
- Long temporary player names overflow badly or break the row/card.

### D. Verify Participant Counts

Steps:

- With the recommended data, check the Lobby side counts.
- Go to Home and check recent/live match cards.
- Go to Discover/match list and check match cards.
- Refresh the list while temporary counts load.

Expected result:

- Temporary players are counted as real participants.
- Home, Discover, and Lobby counts are not misleading registered-only totals.
- If temporary counts are still loading or failed outside the lobby, a safe fallback like "N+ لاعب" is acceptable.
- Once temporary counts load, exact totals include registered + temporary players for each side.

Red flags / failure signs:

- A card shows only `teamAPlayerIds.length + teamBPlayerIds.length` as an exact total when temporary players exist.
- A side with temporary players appears empty.
- Home and Discover disagree after refresh when data is loaded.
- The fallback lacks the plus sign and looks like an exact registered-only count.

### E. Open Lineup Editor

Steps:

- From the lobby, open the lineup action for Team A.
- Return to the lobby.
- Open the lineup action for Team B.
- Test official team side route if available.
- Test temporary/friendly side route if using temporary sides.

Expected result:

- The correct lineup editor opens for the selected side.
- Temporary-side lineup editor works when no official team exists.
- Existing players are available for placement.
- The AppBar share icon is visible but should require save before sharing.

Red flags / failure signs:

- Opening lineup from Team A opens Team B or the wrong route.
- Temporary players are missing from the available lineup pool when they should be usable.
- Share before saving does not explain that the lineup must be saved first.
- The editor layout is unusable on mobile.

### F. Save Complete Lineup

Steps:

- Place enough players to complete the lineup for the selected side if available.
- Save the lineup.
- Repeat for the other side if time allows.

Expected result:

- Save succeeds.
- The confirmed lineup/snapshot is persisted.
- A post-save success surface appears with a clear share CTA.
- The success copy is Arabic and readable.

Red flags / failure signs:

- Save silently succeeds without any clear next action.
- Save fails without an actionable Arabic error.
- The post-save share CTA does not appear.
- Saving changes formation or player placement unexpectedly.

### G. Save Incomplete Lineup If Allowed

Steps:

- Open a lineup editor with fewer players than required or leave some slots empty.
- Attempt to save.
- If the app allows incomplete saves after confirmation, continue.

Expected result:

- The app warns before saving an incomplete lineup.
- If the user cancels the warning, no post-save share CTA appears.
- If the user confirms the incomplete save, the post-save copy mentions that the lineup still has empty slots.

Red flags / failure signs:

- Incomplete lineup saves without warning.
- Canceling the incomplete warning still shows a success/share sheet.
- The copy implies the lineup is complete when it is not.
- Empty slots make the share card unreadable.

### H. Share Lineup After Save

Steps:

- Save a lineup successfully.
- On the post-save success sheet, tap "شارك التشكيلة".
- Return to the editor.
- Tap the AppBar share icon.

Expected result:

- The post-save share CTA opens the existing system share flow.
- The AppBar share action still works after save.
- Share card uses the existing lineup share card/capture flow.
- Arabic text and team names render correctly in the share preview/output.

Red flags / failure signs:

- Share CTA does nothing.
- Share CTA is hidden behind only a small icon.
- AppBar share regressed after adding the post-save CTA.
- Share before save does not show "احفظ التشكيلة أولًا قبل مشاركتها." or equivalent.

### I. Start Match With Lineup

Steps:

- Save at least one lineup/snapshot.
- Return to the lobby.
- Tap "ابدأ المباراة ⚽".

Expected result:

- If a saved lineup exists, the app should not add unnecessary friction.
- Existing start validation still applies.
- The match starts when readiness conditions are met.

Red flags / failure signs:

- The no-lineup nudge appears even though a lineup was saved.
- The match starts when readiness says it should not.
- Starting the match removes players or lineup data.

### J. Start Match Without Lineup And Verify Nudge

Steps:

- Create another friendly match or use a match with no saved lineup/snapshot.
- Add enough players to satisfy start readiness.
- Tap "ابدأ المباراة ⚽".
- In the nudge, tap "ابدأ بدون تشكيلة".

Expected result:

- A nudge appears with the title "تبدأ من غير تشكيلة؟".
- The nudge explains that lineup is optional but useful for a professional, shareable match.
- The user can choose a lineup action for sides with players.
- Tapping "ابدأ بدون تشكيلة" starts the match.
- Lineup remains encouraged, not required.

Red flags / failure signs:

- Start is blocked only because no lineup exists.
- No nudge appears for a friendly match without lineup.
- The nudge traps the user without a start-without-lineup path.
- Tournament/fantasy copy appears in the friendly flow.

### K. Submit Score

Steps:

- Open the score submit screen from a live friendly match.
- Enter an invalid score, such as empty values or invalid negative values if the UI allows input.
- Tap "حفظ النتيجة ⚽".
- Then enter a valid score.
- Tap "حفظ النتيجة ⚽" again.

Expected result:

- Invalid score shows validation/error feedback.
- Invalid score does not show the success/share sheet.
- Valid score is submitted through existing settlement behavior.
- Button text is "حفظ النتيجة ⚽".

Red flags / failure signs:

- Invalid score shows "تم تسجيل النتيجة ✅".
- The screen immediately pops after valid save with no result share CTA.
- Score save bypasses existing permissions or settlement checks.
- Error messages are not Arabic-readable.

### L. Share Result Immediately After Score Submission

Steps:

- Submit a valid score.
- On the success sheet, verify the title and copy.
- Check the score line if team names and score are available.
- Tap "مشاركة النتيجة".

Expected result:

- A result success/share sheet appears with "تم تسجيل النتيجة ✅".
- The body says the result is ready to share.
- The score line is correct when available.
- "مشاركة النتيجة" opens the existing result lineup/share screen.
- "العودة للمباراة" returns safely without double-pop behavior.

Red flags / failure signs:

- The success sheet does not appear after valid score.
- The score line reverses teams or scores.
- Tapping share opens a new/duplicate share implementation instead of the existing result screen.
- Back/return closes multiple screens unexpectedly.

### M. Share Result Later From Match List/Discover Card

Steps:

- Return to the matches/discover list after a result exists.
- Find the completed/scored match card.
- Verify the score is visible.
- Tap "عرض ومشاركة النتيجة".
- Also check a match without score.

Expected result:

- Completed/scored match cards show "عرض ومشاركة النتيجة".
- Match cards without scores do not show "عرض ومشاركة النتيجة".
- The CTA opens the existing match result lineup/share screen.
- Existing fan voting, approval, and review controls remain visible under their normal conditions.

Red flags / failure signs:

- The CTA appears on matches with no score.
- The CTA is missing from a scored match card.
- The CTA opens the wrong match or a broken route.
- Fan voting or organizer approval actions disappear because of the new CTA.

### N. Invite/Copy/Share Link Basic Check

Steps:

- In an open friendly match lobby, locate the invite section.
- Copy the invite link.
- If share/invite friend actions are available, open them.
- Confirm Team A and Team B invite actions still work where present.

Expected result:

- Invite link is visible and copyable.
- Copy action provides feedback.
- Invite controls remain Arabic-first and do not block player management.
- Temporary player flow remains available even when invite/friend flows are unavailable.

Red flags / failure signs:

- Invite link is clipped or unreadable.
- Copy action does nothing.
- Invite UI replaces or hides temporary player actions.
- The user is pushed into broad social features to complete the friendly match.

### O. Arabic RTL And Mobile Usability

Steps:

- Run the full flow on a phone-size viewport.
- Check every core screen: create match, lobby, lineup editor, save/share sheet, start nudge, score submit, result share screen, match list.
- Use long Arabic names for temporary players and sides.

Expected result:

- Arabic text is readable and RTL-safe.
- Buttons are not clipped.
- Icons and text spacing look natural in RTL.
- Bottom sheets fit on mobile and remain scrollable when needed.
- Long temporary player names degrade gracefully with wrapping or ellipsis.

Red flags / failure signs:

- Arabic text is left-aligned in core flow surfaces where RTL is expected.
- Button labels overflow or become unreadable.
- Bottom sheet actions are off-screen with no scrolling.
- Long temporary player names break lineup or share surfaces badly.

### P. No Misleading Coming-Soon/Dead Buttons

Steps:

- Search the friendly match core flow manually for "قريبًا" or disabled actions.
- Check create match, lobby team sections, formation preview, lineup editors, score submit, result share screen, and match cards.
- Specifically inspect temporary players, lineups, results, and sharing surfaces.

Expected result:

- No "قريبًا" appears for temporary players, lineups, results, or sharing inside the friendly match core flow.
- Every visible core action either works or clearly explains a real current limitation.
- Temporary players are added from the team sections in the lobby.

Red flags / failure signs:

- Temporary player action says "قريبًا".
- Share action exists but is disabled with no explanation.
- A core action opens a placeholder screen.
- The user sees fake tournament/fantasy/social prompts while trying to complete the friendly flow.

## 5. Required Pass Criteria

The Friendly Match Core Loop passes manual QA only if:

- A 7v7 friendly match can be created.
- Registered players can be added when available.
- Temporary players can be added to both A and B sides.
- Temporary players are counted as real participants in visible counts.
- Home, Discover, and Lobby counts are not misleading.
- Safe loading fallback labels like "N+ لاعب" are used when exact temporary counts are not ready.
- A lineup can be saved and the post-save share CTA appears.
- The AppBar share action still works after saving a lineup.
- Starting without lineup shows encouragement but does not block.
- "ابدأ بدون تشكيلة" starts the match when readiness allows.
- Invalid score does not show success sharing UI.
- Valid score shows immediate result sharing UI.
- "مشاركة النتيجة" opens the result lineup/share screen.
- Scored match cards show "عرض ومشاركة النتيجة".
- Unscored match cards do not show "عرض ومشاركة النتيجة".
- No misleading "قريبًا" remains for temporary players, lineups, results, or sharing in the core flow.
- Arabic text is readable, RTL-safe, and not clipped on mobile.

## 6. Notes For QA Runs

- Temporary players are first-class participants. Treat any registered-only exact count as a bug when temporary players are present.
- Lineup is optional. A blocker that requires lineup before start is a bug unless another readiness rule applies.
- Sharing is core. Hidden-only share actions should be flagged when a clear CTA is expected.
- Result sharing must be available both immediately after score submission and later from the match list.
- If automated tests have known unrelated failures, do not use that as a reason to skip this manual QA flow.
