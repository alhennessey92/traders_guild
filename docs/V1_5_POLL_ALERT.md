# v1.5: Poll and Alert as Post types

Owner request, 11 October 2026: offer Poll and Alert beside Analysis and Question on the Post screen, each with its own small setting. Built by Claude on `claude/1.5.0-poll-alert`, branched from `release/1.5.0` (`e0683b6`).

**The change is iOS-only.** Poll and Alert already exist on the server, so the backend, the schema and the payloads are all unchanged.

## What the author sees

- **Markers ▸ Add ▸ Post to the chart.** The type picker is four tiles: **Analysis · Question · Poll · Alert**. At accessibility text sizes they stack as capsules.
  - Setup stays its own door.
  - Switching type keeps the text, a poll's choices and an alert's severity. Only the chosen type's setting is sent.
  - Context the new type can't carry (an Analysis source link, support and resistance) uses the existing "remove X and switch?" confirmation.
- **Poll:**
  - The text field is the question: 200 characters, the server's title limit. A counter appears in the last 30 characters.
  - Below it are 2–4 **Choices**, 80 characters each (the server stores up to 200).
  - There is no separate Title, because a poll's question is its title on the server.
  - Context allowed: indicators, drawings and timeframes, as for the legacy poll.
- **Alert:**
  - The text field is the description (at least 10 characters).
  - **How urgent?** offers **Informational · Warning · Severe · Critical**, the four the server and older apps read.
  - Title and context are optional. To mark "an interesting area", use Add context ▸ Drawings ▸ Zone.
- **Review** shows a poll's choices as radio rows, and an alert's urgency as a coloured pill.
- **Editing** uses the same Details → Review → Save changes flow.
  - A poll's question can change. **Its choices are fixed once posted**: the server ignores option changes on update and keeps the votes. The editor says so.
  - An alert's severity and description can each change. "What changes" names the severity change ("Severity: Warning → Critical").

## On the chart and in the view sheet

- **Polls and alerts wear the author's face**, with a ring and a badge, like the other Post types.
  - Poll: a purple ring and a bars badge.
  - Alert: a ring in the severity colour, and a badge with "!" ("i" for Informational) in that colour. With no severity known, both are amber; the legacy grey is kept for the old UI.
  - **This includes existing polls and alerts** (888 and 420 in production on 11 October). News, reactions and personal markers keep their current presentation.
- **The view sheet** uses the face-first layout for both:
  - Poll: the question as the main card, then the choices to vote on. Each choice fills with its share of the votes, and the viewer's own vote is ticked.
  - Alert: the urgency pill, an optional title, then the description card.
- Responses to and from polls and alerts work like any other; the server places no intent restriction on links.

## Wire format (unchanged contract)

| Type | Create request |
|---|---|
| Poll | `intent: "poll"`, `title` = the question, `poll_question` = the question, `poll_options` = the non-empty choices, `note` omitted |
| Alert | `intent: "alert"`, `note` = `"[Severity] description"` (`[Informational]`, `[Warning]`, `[Severe]` or `[Critical]`), optional `title` |

**Updates:**
- A poll sends only `title` when the question changes (the server reads a poll's question from its title; `UpdateMarkerRequest` has no `poll_question`), and never `poll_options`.
- An alert sends the whole prefixed `note` when either its description or its severity changes.

**Server rules mirrored on the client:** chart_schema `validate_marker_content_rules` (a poll needs a question and two options; an alert needs a severity prefix and 10 characters after it) and the 200-character title limit.

**Released apps are unaffected.** They create and read polls and alerts as before. The legacy composer path (flag off) is unchanged and covered by a test.

## Not in this change

- **Share cards** for polls and alerts keep their current (v3-style) design. `AVATAR_MARKER_INTENTS` in `shared/services/og_images.py` covers Analysis, Question and Setup only. Giving polls and alerts the v4 face card is a small backend follow-up that needs a deploy (PROD DEPLOY 2).
- **Android v1.5** needs the same changes for parity:
  - the four Post types and their settings;
  - polls and alerts as faces, with the severity-coloured alert ring and badge;
  - the poll results and alert pill in the view sheet;
  - poll choices fixed on edit.
  The wire format above is the contract.

## Tests

- **Unit:** 930 passed, 1 skipped. New in `MarkerGuidedPollAlertTests`:
  - a poll sends its question as the title, with its choices;
  - a poll's limits and prompts;
  - an alert's severity prefix, for all four;
  - an alert's 10-character rule;
  - switching type keeps the text and each setting;
  - a source link is not carried silently into a poll or alert;
  - the legacy composer is unchanged;
  - a poll edit changes its question only;
  - an alert edit reads the severity apart and sends both back.
  Six scope tests were updated from three intents to five.
- **UI**, in `MarkerPollAlertUITests` through the in-memory submitter:
  - four types and no Setup on the Post screen;
  - a poll journey and an alert journey to the sent request;
  - switching type keeps the text.
- **Simulator check (iPhone 17 Pro Max):** the Post screen, Poll and Alert Details and Review, the poll and alert view sheets, and faces on the chart for a Critical alert and a poll.
