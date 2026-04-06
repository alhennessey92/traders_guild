# iOS Toast and Message Security Audit (V2)

## Scope
- Hardcoded UI message strings (alerts, toasts, inline error states).
- Backend/API error payloads displayed to users.
- Localization readiness for high-priority message paths.
- Areas needing toast/message add/remove adjustments for production UX.

## Audit Summary
- Centralized production-safe error mapping has been added.
- Raw `error.localizedDescription` is no longer shown in core/global alerting flows.
- Transport-level error details (URL/routing mode) are no longer propagated to user-facing API errors.
- Missing user feedback was added for silent failure paths in password reset and push preference updates.
- High-priority message keys were centralized and seeded into a localization table.

## Message Surface Inventory (By Channel)

### Global Toast/Alert Infrastructure
- `traders_guild/Environment/RLAppState.swift`
  - `showError`, `showSuccess`, `showInfo`, `showWarning`, `clearAlert`
  - Channel types: `.toast`, `.alert`
  - Risk before: `showError(_:)` used raw `localizedDescription`
  - Risk now: sanitized through centralized mapper
- `traders_guild/Models/RLCoreDTOs.swift`
  - `RLAppAlert`, `RLAlertSeverity`, `RLAlertDisplayStyle`
  - Defines message payload and severity/display type
- `traders_guild/Features/Shared/globalViews/ToastWindowManager.swift`
  - Global toast rendering window
- `traders_guild/App/traders_guildApp.swift`
  - Root blocking `.alert(...)` presentation

### Feature Alert/Confirmation Surfaces (User-Decision Prompts)
- `traders_guild/Features/Messaging/MessagingComponents.swift`
- `traders_guild/TradingChart/overlays/MarkerDetailView.swift`
- `traders_guild/TradingChart/overlays/EmbeddedMarkerDetailView.swift`
- `traders_guild/Features/Core/subViews/chartSheetSubViews/ChartSheetSymbolView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/guildAdmin/ManageMembersView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/guildAdmin/ManageRolesView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/guildAdmin/ManageChatroomsView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/guildEvents/EventsView.swift`
- `traders_guild/Features/Auth/ContentView.swift`

### Inline Error/Status Surfaces
- `traders_guild/TradingChart/viewModels/ChartViewModel.swift`
- `traders_guild/Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift`
- `traders_guild/Features/Core/subViews/chartSheetSubViews/MarkerActivitySheet.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/guildTopMarkers/TopMarkersView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/userProfile/UserProfileView.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/userProfile/BreakdownSheets.swift`
- `traders_guild/Features/Core/subViews/leftDrawerSubViews/userProfile/UserGlobalView.swift`

## Risk Classification

### Security-Sensitive (High)
- Raw backend/system error details shown to users via `showError(_:)` and direct `localizedDescription` UI bindings.
- Network error strings previously contained endpoint URL and routing mode context.
- Server/decode errors previously exposed internals in `APIError.errorDescription`.

### Needs Rewrite (Medium)
- Catch blocks in password reset flow returned silently without user feedback.
- Push preference load/save failures only logged via `print` and did not notify user.

### Safe / Lower Risk
- Confirmation prompts for user actions (delete, block, report, archive) are explicit and non-technical.
- Success toasts such as message sent/deleted/copied are user-focused and low leakage risk.

## Production Hardening Implemented

### 1) Centralized Error Mapper
- Added `traders_guild/Environment/RLUserFacingMessage.swift`:
  - `RLUserMessageKey`
  - `RLUserFacingCopy`
  - `RLUserFacingErrorMapper`
- Enforces safe fallback copy and strips technical/infrastructure details from user-facing text.

### 2) Global Error Display Sanitization
- Updated `traders_guild/Environment/RLAppState.swift`:
  - `showError(_:)` now maps all errors through `RLUserFacingErrorMapper`.
  - Added `userSafeMessage(for:)` helper for UI-level call sites.
  - Biometric unlock fallback now uses sanitized copy.

### 3) API Error Surface Sanitization
- Updated `traders_guild/Services/RealAPIService.swift`:
  - `APIError.errorDescription` now returns safe, generic user text.
  - Removed URL/routing-mode details from thrown network error message.
  - Keeps debug diagnostics in debug logging only.
  - Replaced decode error payload with non-sensitive token (`response_decode_failed`).

### 4) High-Risk UI Call Site Remediation
- Updated direct `localizedDescription` display points in:
  - `Features/Messaging/MessagingComponents.swift`
  - `TradingChart/viewModels/ChartViewModel.swift`
  - `TradingChart/overlays/MarkerDetailView.swift`
  - `Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift`
  - `Features/Core/subViews/chartSheetSubViews/MarkerActivitySheet.swift`
  - `Features/Core/subViews/leftDrawerSubViews/guildTopMarkers/TopMarkersView.swift`
  - `Features/Core/subViews/leftDrawerSubViews/userProfile/UserProfileView.swift`
  - `Features/Core/subViews/leftDrawerSubViews/userProfile/BreakdownSheets.swift`
  - `Features/Core/subViews/leftDrawerSubViews/userProfile/UserGlobalView.swift`

## Toast/Add-Remove Decisions

### Added
- Password reset request failure now displays a toast.
- Password reset completion failure now displays a toast.
- Push preference load/save failures now display warning toasts.

### Removed / Reduced
- Removed technical detail from user-visible error content (primary production-risk reduction).
- Removed backend routing/URL disclosure from network-error user paths.

### Kept Intentionally
- Destructive and confirmation interactions remain blocking alerts/dialogs.
- Non-blocking status/success feedback remains toast-first where already established.

## Localization Readiness
- Added `traders_guild/Localizable.strings` with high-priority message keys used by the new mapper.
- Message key strategy introduced for error/warning/success copy centralization.
- Future migration path: move remaining hardcoded feature strings into keyed localization.

## Remaining Follow-Ups (Recommended)
- Continue migrating all remaining hardcoded user-facing copy to keyed localization.
- Add optional support-facing opaque error codes (e.g., `TG-NET-01`) for troubleshooting without exposing internals.
- Add snapshot/UI tests for critical messaging flows (auth, chart load, messaging edit, profile loaders).
