# App Store "What's New" — Traders Guild 1.2.0 (iOS)

Your calls now show how they ended. When a tracked setup hits its target or its stop, the result travels with it everywhere you share it.

* A resolved setup shares as a result: TARGET HIT or STOPPED OUT, with the P&L, on the share image, on the marker's page and in the post itself.
* The moment a setup resolves you are offered the share, and opening the notification takes you to the marker with the share sheet already up.
* Give your guild a banner across the top of its page and drawer. Upload your own, or keep the one generated from your guild's crest colour and name.
* The crest editor now leads with your own artwork; the shield symbols are there as a fallback.
* A personal marker carries its author's face instead of a generic glyph, and you now choose whether it stays private or goes to your guild — which means a personal marker can be shared for the first time.
* Share destinations sit in the same order on every screen.
* Fixed: the chart's bottom sheet could be left standing open after placing a marker.
* Fixed: a result notification for a marker in another guild opened on "marker unavailable" instead of switching to that guild first.
* Photos from recent phone cameras are no longer refused when you set an avatar, crest or banner, and portrait shots keep the right way up.

## Internal release details

* Marketing version: `1.2.0`
* Build: `20`
* **Requires the 1.2.0 backend, which is deployed.** The outcome on the card, the marker page and the notification copy are all server-rendered — against an older server this build looks unchanged.
* One follow-up core-service deploy landed after the main release: `/users/me/guilds` was omitting `banner_url`, and both clients read their selected guild out of that list. Without it the banner appears to save and then vanishes.
* `banner_url` is additive and optional; it decodes as nil against an older backend, so no response contract changes for any live version.
* Personal markers default to private, so nothing changes visibility on upgrade.
* Crest symbol keys are unchanged on the wire: all eight still render, four are offered in the picker.
* macOS sources, targets and project settings are outside this release — `grep -c TradersGuildMac` on the project file is 0.
* Android ships the same feature set from its own repo as 1.2.0 (version code 16).

### Scope check

Everything in this release, measured against the `1.1.9` cut (`5d6a375`):

| Commit | User-facing |
| --- | --- |
| `6cc0254` guild banner + upload-first crest editors | yes |
| `d2c71c3` personal marker avatar + author-chosen visibility | yes |
| `3888d69` resolved setup shares as a result | yes |
| `ef6c595` one share-channel order everywhere | yes |
| `be038ae` bottom sheet can close again | yes |
| `d3600ed` draw an uploaded banner as a banner, not a disc | no — fix to the unshipped banner |
| `54ece1d` result notification opens in the marker's own guild | yes |
| `ae95bbb` banner picker actually opens | no — fix to the unshipped banner |
| `6530936` stop cropping banners square | no — fix to the unshipped banner |
| `c7985f9` fetch the uploaded banner; drawer header scrolls | no — fix to the unshipped banner |
| `a72ba55` drop the banner diagnostics | no |

The four banner "fixes" are corrections to a feature that has never shipped, so they are
one bullet above, not five.
