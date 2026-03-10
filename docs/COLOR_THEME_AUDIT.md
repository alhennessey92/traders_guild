# Color Theme Audit

Date: 2026-03-09

## Goal
- Make [`Color+Theme.swift`](/Users/alhennessey/Desktop/traders_guild/sanctuary/traders_guild_ios/traders_guild/Extensions/Color+Theme.swift) the single source of truth for static colors.
- Preserve visual output (zero-delta migration).

## Source Of Truth
- Canonical file: `traders_guild/Extensions/Color+Theme.swift`
- Public API: `AppColors` (backward-compatible aliases retained)

## Foundation Asset Tokens
- `tgGradientBackground` -> `TGGradientBackground` (`#010105`, a=1.0)
- `tgGradientBackgroundMid` -> `TGGradientBackgroundMid` (`#111111`, a=1.0)
- `tgGradientBackgroundLight` -> `TGGradientBackgroundLight` (`#000127`, a=1.0)
- `tgSheetBackground` -> `TGSheetBackground` (`#1B1A1F`, a=1.0)
- `tgSheetDarkBackground` -> `TGSheetDarkBackground` (`#1F1E1A`, a=1.0)
- `tgDrawerBackground` -> `TGDrawerBackground` (`#00000A`, a=1.0)
- `tgToolbarBackground` -> `TGToolbarBackground` (`#00000E`, a=0.35)
- `tgWhiteText` -> `TGWhiteText` (`#ECECEC`, a=1.0)
- `tgWhite` -> `TGWhite` (`#FFFFFF`, a=1.0)
- `tgMidGrey` -> `TGMidGrey` (`#7A7878`, a=1.0)
- `tgGrey` -> `TGGrey` (`#A9A9A9`, a=1.0)
- `tgAccent` -> `TGAccent` (`#0F9EB4`, a=1.0)
- `tgAccentDark` -> `TGAccentDark` (`#026675`, a=1.0)
- `tgFriend` -> `TGFriend` (`#0574D5`, a=1.0)
- `tgBull` -> `TGBull` (`#4A9476`, a=1.0)
- `tgBear` -> `TGBear` (`#A62C2B`, a=1.0)
- `tgButtonSearchBackground` -> `TGButtonSearchBackground` (`#191921`, a=1.0)
- `tgUnhighlightedWhite` -> `TGUnhighlightedWhite` (`#C3C3C3`, a=1.0)
- `tgFadedBackground` -> `TGFadedBackground` (`#3F404D`, a=1.0)
- `tgChartLogo` -> `TGChartLogo` (`#7A7878`, a=1.0)
- `tgGreen` -> `TGGreen` (`#089B1C`, a=1.0)

## Migration Coverage
- `Color.<systemColor>` and `Color(...static literal...)` usage in app code now resolves through `AppColors` wrappers/tokens.
- `UnifiedColorPalette.swift` and chart extension palettes now point at `AppColors` tokens.
- Backward-compatible names (`accentColor`, `sheetBackground`, `whiteText`, etc.) still compile and route to canonical tokens.
- Fixed incorrect dark sheet mapping: `sheetBackgroundDark` now maps to `TGSheetDarkBackground`.

## Exceptions (Intentional)
- Dynamic color constructors are preserved where values are computed at runtime (for example color math in chart rendering, decoded colors from backend payloads, `CodableColor` conversions).
- Shorthand color literals (for example `.white`, `.red`) remain in some call sites; they are currently value-equivalent and non-breaking, and can be migrated in a follow-up pass if desired.

## Guardrail Checks
- Check for new explicit static `Color.<system>`/literal constructors outside theme file:
```bash
cd traders_guild_ios
rg -n "Color\.(white|black|gray|red|green|blue|orange|yellow|purple|cyan|teal|pink|mint|indigo|brown)(\.opacity\([0-9.]+\))?|Color\((red|white):" traders_guild --glob '*.swift' -S | rg -v 'Extensions/Color\+Theme.swift'
```
Expected output should only contain dynamic conversion/math call sites:
- `TradingChart/indicators/IndicatorModels.swift` (`Color(red: red, ...)` from decoded values)
- `TradingChart/indicators/IndicatorManager.swift` (`CodableColor(red: red, ...)`)
- `TradingChart/overlays/MarkerPlacementIndicatorsTab.swift` (`CodableColor(red: red, ...)`)
- `TradingChart/overlays/ChartMarkerSystem.swift` (runtime blend/darken/lighten color math)

- Monitor remaining shorthand literal usage distribution:
```bash
cd traders_guild_ios
rg --no-filename -o "\.(white|black|gray|red|green|blue|orange|yellow|purple|cyan|teal|pink|mint|indigo|brown)(\.opacity\([0-9.]+\))?" traders_guild --glob '*.swift' -S | sort | uniq -c | sort -nr
```
