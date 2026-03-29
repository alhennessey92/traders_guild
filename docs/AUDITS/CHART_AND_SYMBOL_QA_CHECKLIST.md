# Chart And Symbol QA Checklist

Use this checklist to validate the March 29, 2026 chart, symbol-selection, watchlist, and chart-settings audit pass.

Recommended test setup:
- `User A`: normal user with a populated personal watchlist
- One guild with a non-empty guild watchlist
- One admin or owner available to review guild watchlist requests
- At least one symbol that is selectable for the active provider
- At least one symbol that is visible but not selectable for the active provider
- Symbols across multiple asset classes so `Personal`, `Guild`, `Global`, and `Search` tabs can all be exercised
- Live or near-live data on at least one symbol so chart price, timeframe, and panel behavior are observable

Out of scope for this checklist:
- Marker creation, tracking, resolution, and marker-specific tabs. Covered in `MARKER_QA_CHECKLIST.md`.
- Reputation or accuracy consequences of viewing symbol or chart data. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.
- Guild-admin review of watchlist requests. Covered in `GUILD_ADMIN_QA_CHECKLIST.md`.

## Current Symbol Header And Details

- [ ] Symbol header content: open the chart symbol sheet. Expected: the current symbol header shows icon, display name, ticker, asset class, provider, and price/change data.
- [ ] Market status badge: the header reflects whether the current market is open or closed.
- [ ] Provider badge: the active provider label is shown for the symbol.
- [ ] Unsupported symbol badge: for a symbol not selectable on the active provider, the unsupported badge appears.
- [ ] Details expansion: expand and collapse `Symbol Details`. Expected: the section animates cleanly and preserves content state.
- [ ] Symbol details values: provider, market-open state, and related summary fields are consistent with the selected symbol.

## Timeframe And General Chart Interaction

- [ ] Timeframe switching: change chart timeframe from the symbol sheet. Expected: the chart reloads the new timeframe without getting stuck in loading.
- [ ] Multiple timeframe hops: switch rapidly across several timeframes. Expected: the final selected timeframe wins and stale data does not remain visible.
- [ ] Chart responsiveness after symbol change: change symbols repeatedly. Expected: the chart remains pannable/zoomable and the sheet state stays stable.
- [ ] Loading-state clarity: while the chart is loading a new symbol or timeframe, a loading indicator appears instead of a broken chart area.

## Symbol Sheet Watchlists

- [ ] Tab set: the chart symbol sheet exposes `Personal`, `Guild`, `Global`, and `Search`.
- [ ] Personal tab content: personal watchlist symbols render correctly, including the current symbol highlight state.
- [ ] Personal add flow: from search or another list, add a symbol to the personal watchlist. Expected: it appears in `Personal`.
- [ ] Personal remove flow: remove a symbol from personal watchlist. Expected: a confirmation dialog appears and the symbol disappears after confirmation.
- [ ] Guild tab content: guild watchlist symbols render in the guild tab.
- [ ] Global tab content: global symbols load and render in the global tab.
- [ ] Search hint state: in `Search` with no query entered, the sheet shows the hint state instead of a blank list.
- [ ] Search results state: enter a matching query. Expected: symbols appear in results and can be selected.
- [ ] No-results state: enter a query with no matches. Expected: the no-results state appears.
- [ ] Search reset on tab switch: leave `Search` and return. Expected: the previous query is cleared.

## Guild Watchlist Request Flow

- [ ] Guild request prompt: for a symbol not already on the guild watchlist, the guild add/request action opens the request confirmation alert.
- [ ] Guild request success: send a guild-watchlist request. Expected: the request completes and local pending state updates.
- [ ] Pending-request visibility: after requesting, the symbol shows pending-request state rather than a fresh add action.
- [ ] Notification refresh hook: after a guild-watchlist update notification, the symbol sheet refreshes request state and symbol data.
- [ ] Request isolation: sending a guild request does not incorrectly add the symbol straight into personal watchlist unless that action was also taken.

## Left Drawer Watchlists

- [ ] Drawer tab set: the left-drawer watchlist view exposes `Personal`, `Guild`, `Global`, and `Search`.
- [ ] Drawer personal list: personal symbols load in the drawer and match the current account state.
- [ ] Drawer guild list: guild symbols load with the admin-managed notice.
- [ ] Drawer global list: global symbols render grouped correctly and remain scrollable.
- [ ] Drawer search add flow: search for a symbol and add it to personal watchlist from the drawer.
- [ ] Drawer refresh: pull to refresh updates guild, personal, and global watchlists without leaving stale counts behind.
- [ ] Cross-surface parity: add or remove a personal symbol in one watchlist surface and confirm the other surface reflects the change.

## Provider Availability And Empty States

- [ ] Unsupported symbol selection: attempt to open a symbol marked unsupported for the active provider. Expected: the UI blocks unsupported selection and stays stable.
- [ ] Empty personal watchlist: for a user with no personal symbols, the personal empty state explains how to add symbols.
- [ ] Empty guild watchlist: for a guild with no symbols, the guild empty state explains that admins manage it.
- [ ] Empty global list fallback: if no global symbols are available, the empty state renders correctly.

## Chart Settings

- [ ] Settings sheet open: open chart settings from the chart UI. Expected: the settings sheet appears with grid, candle, viewport, and marker-layout sections.
- [ ] Grid-lines toggle: toggle `Show Grid Lines`. Expected: the chart updates and the setting persists while the sheet stays open.
- [ ] Grid opacity slider: with grid lines enabled, adjust opacity. Expected: the previewed chart contrast changes.
- [ ] Candle color customization: change bullish and bearish candle colors. Expected: the chart updates with the selected colors.
- [ ] Candle color reset: use `Reset to Default`. Expected: candle colors return to defaults.
- [ ] Viewport-window toggle: toggle `Show Viewport Window`. Expected: linked timeframe panels respond appropriately.
- [ ] Viewport style picker: change viewport style. Expected: the selected style applies without layout issues.
- [ ] Viewport opacity slider: change viewport opacity. Expected: the overlay intensity updates.
- [ ] Marker layout sliders: adjust candle distance, stack distance, min stack spacing, proximity spread, and placement extra offset. Expected: the settings update without crashing the chart.
- [ ] Marker layout reset: use `Reset Marker Layout`. Expected: layout settings return to defaults.

## Indicator Browser And Panel Limits

- [ ] Indicator browser categories: `Trend`, `Volatility`, `Momentum`, and `Volume` categories are all reachable.
- [ ] Add overlay indicator: enable a non-panel indicator such as a moving average. Expected: it appears on the chart and can be edited or removed.
- [ ] Add panel indicator: enable a panel indicator such as RSI or MACD. Expected: the panel appears below the chart.
- [ ] Panel-limit badge: the indicator browser reflects the current panel count as `x/2`.
- [ ] Panel-limit enforcement: attempt to enable more than two panel indicators. Expected: the UI prevents invalid over-allocation.
- [ ] Indicator settings sheet: open an indicator's edit sheet and change a setting. Expected: the indicator recalculates and remains stable.
- [ ] Indicator removal: remove an active indicator. Expected: the chart and indicator list update immediately.

## Negative Cases And Guard Rails

- [ ] Rapid symbol switching: switch symbols repeatedly across tabs and search. Expected: the final symbol selection wins and the chart remains usable.
- [ ] Search debouncing: rapidly type and clear search text. Expected: the UI does not freeze or show stale grouped results.
- [ ] Confirmation safety: cancel personal-watchlist removal. Expected: the symbol remains in the list.
- [ ] Settings dismissal: dismiss chart settings or indicator sheets mid-edit. Expected: the chart returns to normal interaction without overlay residue.

## Final Sanity Pass

- [ ] Users can inspect a symbol, switch timeframes, browse watchlists, and search symbols from both the chart sheet and left drawer.
- [ ] Personal watchlist changes stay consistent across chart and drawer surfaces.
- [ ] Guild-watchlist requests behave like requests, not direct unauthorized edits.
- [ ] Chart settings and indicator controls change the chart safely and remain reversible.
- [ ] Unsupported-provider symbols are clearly identified and do not break chart navigation.
