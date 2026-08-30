# App Store "What's New" - Traders Guild 1.1.9 (iOS)

Share your markers and guild invites straight to Reddit and Telegram, alongside X and Discord.

* Reddit and Telegram join X, Discord and Guild DM on every share sheet, for both markers and guild invites.
* Share destinations now look the same wherever you find them, each with its own brand mark.
* A shared marker now leads with its instrument's cashtag, so your post reaches people following that market and not only your followers.
* Sharing to Discord from a guild with no channel connected now explains what is happening and offers to copy the message, instead of opening Discord with nothing posted.
* Editing an indicator while placing a marker now updates that indicator instead of adding a second copy of it.

## Internal release details

* Marketing version: `1.1.9`
* Build: `19`
* **No backend deploy.** Reddit and Telegram read the Open Graph tags the landing pages already serve, and use the existing server-issued marker and invite links. No endpoint, schema or response field changes.
* No new permissions, and no `LSApplicationQueriesSchemes` entries: both channels open through `UIApplication.open`, with Telegram falling back from `tg://` to the `t.me` universal link and Reddit going straight to its own submit page.
* The marketing site's privacy policy names the two new destinations, matching the in-app disclosure. Deploy `traders-guild-website` alongside this release.
* Android ships the same two channels and the same icon set from its own repo.
* Older app versions are unaffected: nothing they send or receive changes.

### Scope check

Everything in this release, measured against the `1.1.8` cut (`fca9990`):

| Commit | User-facing |
| --- | --- |
| `2a358dc` correct preview asset path | no |
| `0c1c181` preserve marker indicator identity on edit | yes — see note |
| `844b02d` cashtag on shared markers | yes |
| `615a0e4` Discord share no longer strands the user | yes |
| `1d42633` Reddit + Telegram, unified channel icons | yes |

`0c1c181` was committed while the project still read `1.1.8` / build 18. If build 18
went to Apple on or after 23 August it already shipped, and the indicator bullet
should be dropped from the copy above.
