# iOS 1.3.0 production QA

Open `.worktrees/linked-markers-ios/traders_guild.xcodeproj` under sanctuary. Keep branch `feat/1.3.0-linked-markers`; there is no need to switch the protected release checkout to main.

Choose **traders_guild Prod QA** and your iPhone, then Run. The optimized **TG Prod QA** app installs alongside **TG LinkedDev** and the App Store app using `co.tradersguild.app.prodqa` and its own keychain. Automatic signing may need Xcode to provision this new bundle for your connected device. This app always uses `https://api.tradersguild.co/api/v1`, including launches from the home screen; no Mac gateway or LAN connection is needed.

**Do not begin linked-marker production tests until the deployment session confirms enablement.** While the backend flag is off, linking controls are hidden. Use dedicated production QA accounts/guild; local DEV accounts and markers do not exist in production. Changes made here are real production writes.

Email/password login is the supported QA path. Push registration is disabled in this isolated app: the production backend's APNs topic belongs to the shipping app. Test push and universal links separately with the production-signed TestFlight candidate. This configuration has no associated-domain or Apple-sign-in entitlement; its custom link scheme is `tradersguild-prodqa`.

Continue local testing with **traders_guild LinkedDev**. Its endpoint, identity and retained data are unchanged. Do not archive or submit the Prod QA app to Apple. The normal production Release scheme remains the shipping path after acceptance.

Final production readiness still requires backend CI/full-schema/admin/client gates, current live preflight, physical-device performance and manual accessibility acceptance. The unreproduced sheet-presentation warning from the owner's previous log remains a tracked diagnostic item; code 9 alone does not establish why iOS terminated a process.
