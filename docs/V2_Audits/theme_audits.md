Light-Grey Theme Adjustments

1. [Fixed] Light-grey theme - Panels for timeframes and indicators need darker background and header and x axis

2. [Fixed] Light-grey theme - Candles should always solid color - im mainly targeting the green bull candles here, but need to make sure they contrast the chart background better

3. [Fixed] Light-grey theme - Cards and list view items can be slightly darker across the whole app

4. [Fixed] Light-grey theme - Chart buttons at bottom need t be dark grey not white - these are the buttons at bottom of main chart above the x axis

5. [Fixed] Light-grey theme - Chart settings pattern background needs to be lighter 

6. [Fixed] Light-grey theme - Not enough contrast between chart info boxes and marker info boxes and their content either make their background lighter and darker text or visa versa

7. [Fixed] Light-grey theme - Green color used for any marker content - text or backgrounds needs to be darker not enough current contrast with the current green and white backgrounds 

8. [Fixed] Light-grey theme - Crosshair dotted lines need to be dark and crosshair info boxes needs to be darker 

9. [Fixed] Light-grey theme - Notifications icons need to be darker background blends too much with white background - almost impossible to see

10. [Fixed] Light-grey theme - Any sub tabs that are  blue color background need different blue, too dark against the white background and black text can’t be seen. Need to be lighter blue 



Mid-Grey theme adjustments

11. [Fixed] Mid-grey theme - Panel headers for indicator and timeframe panels could be slightly lighter

12. [Fixed] Mid-grey theme - Background for markers filter button section at bottom of main chart is a little too dark could be lighter, this is the background that appears when pressing markers button at bottom of chart above the x axis. at the moment it appears as black, could be same color as say the chart info box background





Light grey theme

13. Light-Grey Theme - Chart info boxes too dark

14. Light-Grey Theme - Indicator panels needs stronger coloring to contrast the white

15. Light-Grey Theme - Timeframe panels need stronger blue footer color and subsequent header 

16. Light-Grey Theme - Icons and text in disclosures in marker view and placement mode are still white need to be dark grey

17. Light-Grey Theme - Attachment view background in chat interfaces to select attachment type needs less opacity can see content behind it

18. Light-Grey Theme - Icons and text in components add section still appearing white needs to be grey, 

19. Light-Grey Theme - Colored gradient background and icons in marker placement mode components overview still very light contrast against main white background need darker opaque coloring to contrast 

20. Light-Grey Theme - Any footer section in auth section of app that generally holds continue button or equivalent is too white could do with slight gradient or opacity to allow slight background material show through 




21. All Themes - Panel header in midgrey needs adjustment color wise seems too similar to chart background. Perhaps the timeframe panel header should match the timeframe x axis blue coloring and for indicator panel make it black to match the x axis background - perform similar action to the other themes sticking to same background on respective x axis background in all the dark grey, mid grey and light grey themes





New theme audits

22. **[Done]** Mid-grey and dark grey timeframe x-axis: `timeframePanelAxisGradientTop/Bottom` are neutral dark greys; tick labels unchanged (`statusInfo*`); `timeframePanelAxisFrameBorder` frames the strip (top + bottom). `TimeframePanelView` + `RSIPanelView` timeframe strip updated.

23. **[Done — pass 1]** Light grey: introduced canonical light-grey positive green (`themeAwareGreen`), theme-aware `statusPositive*`, unified marker greens, and systematic token updates below. Further screen-by-screen polish can continue using `AppColors` only.

24. **[Done]** Light grey timeframe x-axis: grey gradient + blue frame lines (aligned with §22).

25. **[Done]** Stronger `indicatorPanelPlotBackground` on light grey.

26. **[Done]** `guildStatisticsCardBackground` / `guildStatisticsCardStroke` on statistics cards.

27. **[Done]** `themeAwareGreen` drives `statusPositive` and ladders on light grey; statistics metrics use `statisticsMetric*` helpers; marker chrome uses the same family.

28. **[Done]** Deeper `symbolSheetHeroBlueGradient*` and `symbolListRowSelectedBlueGradient*` on light grey (no near-white leading stop).

29. **[Done]** `symbolDetailPersonalStarActive` for the Personal star in `ChartSheetSymbolView`.

30. **[Done]** Darker `placementBarSelectedFill` / `placementBarUnselectedFill` (chart sheet / bottom bar chrome).

31. **[Done]** Stronger guild switch selection: `guildSwitchRowSelectedFillOpacity` / `StrokeOpacity` increased on light grey.

32. **[Done]** Tutorial step accents: `tutorialAccent*` + `signupInterestGreen` on light grey.

33. **[Done]** Marker viewing Components tab: `markerViewingTint*` tokens; `componentsOverviewChipFill` strengthened.

34. **[Done]** Lighter orange/green tab gradients on light grey: `chartOrangeGradient*` and `chartGreenGradient*`; `UnifiedTabTheme` borders use the same family.

35. **[Done]** Tracking / marker flows use `markerPositiveForeground` → `themeAwareGreen` (same ladder as place-marker affordance).


36. **[Done]** Lightgrey outgoing chat bubble: `chatOutgoingBubbleFill` (lighter teal on light grey; `tgAccentDark` elsewhere) in `RLChatMessageBubble`.

37. **[Done]** Symbol sheet hero + selected watchlist rows: lightened light-grey `symbolSheetHeroBlueGradient*` / `symbolListRowSelectedBlueGradient*`; bullish tint uses `priceChangePositive`.

38. **[Done]** Adaptive lime green removed for price direction and accuracy: `AppColors.priceChangePositive` / `RLTradingSymbolDTO.changeColor`; `UnifiedComponents` / leaderboards / `RLUserGlobalStatisticsDTO.accuracyColor` use `statusPositive*` / `moderationOrange`; `themeAwareInfoBlue` drives `statusInfo*`.

39. **[Done]** Guild / reputation “light” brand: `guildReputationAccent` (drawers, switch guild, author rows, profile stats, `SwitchGuildView`); `statusInfo` / symbol sheet `.blue` replaced with `AppColors.statusInfo*`.

40. **[Done]** Moderator / moderation orange: `moderationOrange` + `AppColors.memberRoleColor` via `RLMemberRole.color`; report/admin surfaces use tokens.




41. **[Done]** Light grey palette v2 (unification): `LightGreyPalette` in [Color+Theme.swift](../../traders_guild/Extensions/Color+Theme.swift) — **brand teal** (`reputationAccent`, `outgoingChatBubbleFill`); **one nav-blue ramp** for chart tab/subtab/deep gradients, symbol sheet hero/selected row, and `markerViewingTintTimeframe`; anchor shared with `themeAwareInfoBlue`. **Adaptive chrome**: `drawerNeutralActionButton*`, `adaptiveChromeSearchField*`, `adaptiveFormControl*`, `adaptiveSearchAccessoryForeground` (`UserProfileView`, `SwitchGuildView`, `UnifiedSearchBar`). QA: chart blue tabs, symbol sheet header, guild discover search, drawer footers, marker timeframe tint.

42. Light grey - auth section bottom footer holding the continue button etc... is too white, needs a greyer look

43. Light grey add announcement/event bottom footer section 

44. Light Grey - chat options for user and other users is too dark with the text not being visible