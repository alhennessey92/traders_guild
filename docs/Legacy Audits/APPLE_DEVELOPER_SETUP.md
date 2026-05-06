# Apple Developer Account Setup for Sign In with Apple

This document lists the steps required once the Apple Developer account is active.
All iOS code changes are already in place and ready to test.

## Prerequisites

- Active Apple Developer Program membership ($99/year)
- Access to https://developer.apple.com/account

## 1. Register App ID

1. Go to **Certificates, Identifiers & Profiles** > **Identifiers**
2. Select (or register) the App ID for Traders Guild
3. The Bundle ID should match `AppConfig.appleSignInClientID`: currently set to `co.tradersguild.app`
4. Under **Capabilities**, enable **Sign In with Apple**
5. Save

**Note:** If the production Bundle ID differs from `co.tradersguild.app`, update
`AppConfig.appleSignInClientID` in `traders_guild/App/AppConfig.swift` to match.

## 2. Add Entitlement in Xcode

The entitlements file already exists at `traders_guild/traders_guild.entitlements`.

Add the Sign In with Apple entitlement:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

Alternatively, in Xcode:
1. Select the project target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Search for and add **Sign in with Apple**

## 3. Configure Services ID (for Backend Token Validation)

If the backend validates Apple identity tokens server-side (it does, via `POST /auth/apple`):

1. Go to **Identifiers** > **Services IDs** > register a new one
2. Set the identifier (e.g. `com.tradersguild.auth`)
3. Enable **Sign In with Apple**
4. Configure the **Domains and Subdomains** and **Return URLs** for the backend
5. Provide the Services ID to the backend team for token audience validation

## 4. Verify Info.plist Entries

Already configured:

- `NSFaceIDUsageDescription`: "Traders Guild uses Face ID for quick and secure sign-in."
- No additional plist entries needed for Sign In with Apple

## 5. Testing Checklist

Once the developer account is active:

- [ ] Sign In with Apple button triggers the native Apple auth sheet
- [ ] New Apple user is routed to Apple profile completion view (name, DOB)
- [ ] New Apple user continues through username > basics > interests > guild > profile
- [ ] Returning Apple user skips onboarding and enters guild selection
- [ ] Face ID enrollment prompt appears after first successful auth (either method)
- [ ] Face ID toggle works in Settings > Security
- [ ] Face ID login from WelcomeView restores session correctly
- [ ] Logout clears biometric token from Keychain
- [ ] Email auth flow remains fully working and unchanged

## 6. Backend Considerations

The backend `POST /auth/apple` endpoint should ideally return:

```json
{
  "user": { ... },
  "tokens": { "access_token": "...", "refresh_token": "..." },
  "is_new_user": true,
  "onboarding_state": "account_created"
}
```

Until `is_new_user` is added to the backend response, the iOS app falls back to
heuristic detection (checking if the username is empty or uses a placeholder prefix
like `apple_user_` or `user_`).
