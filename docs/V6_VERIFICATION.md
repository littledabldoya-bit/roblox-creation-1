# v6 offline verification — 20 October 2026

Artifact: `fartnightv6.rbxlx`  
SHA256: `38075d21b9ccce2f9a743bb310edbc47e61e52e71f9c5da1c9fa0544475fc174`

**67 checks passed**, plus compilation of all seven embedded Luau scripts.
Reproduce with `python3 tools/verify_release.py`. The saved cloud installer also
runs this command. Build output is deterministic and embedded scripts match src/.

| Suite | Passed |
| --- | ---: |
| XML preservation/build + MP3 decoding | 7 |
| Economy/receipt normalization | 11 |
| Persistence, interrupted saves, receipt replay and entitlements | 19 |
| Actual catalog IDs/prices and quantities | 4 |
| Sound triggering, movement and cleanup using service doubles | 5 |
| Combat, shotgun direction, damage and entitlement rules | 7 |
| Complete shipped script integration using service/model doubles | 14 |

The generated place contains 693 original/map/module instances,
including 634 Parts and 12 SpawnLocations.
Original scene structure and non-script properties match the upload after the
explicit visual material/color adjustments; only the two helper modules are added.
Detailed gun/crown geometry, store UI and audio instances are constructed by the
embedded scripts at runtime. No separate weapon/crown model downloads are required.

The full-source integration simulation loads the generated XML dependency tree and
executes FN_Server, FN_WorldDetail, FN_Client and FN_ShoulderAim_v2 with the actual
Config/Economy/Combat modules. It confirms five detailed gun templates, three crown
templates, five owned versus three free tools, all ten paid cards and seven cloud
cards, five actual-model shop previews, product prompt cancellation, all three
receipt quantities and replays, crown equip/remove, assigned shop sizes at four
viewport sizes, soundtrack ID/playback request/mute, firing all guns, eight shotgun
rays, reload across respawn, premium shield piercing/spawn protection and purchased
gun/crown delivery. It caught and fixed unsupported math.tau calls in spawning,
crowns and storm generation, in addition to the stale reload callback.

These checks are **not Roblox engine tests**. Service responses and raycast hits
are controlled inputs; there is no real physics, rendering, avatar animation,
audio delivery, production DataStore or real purchase transaction. GUI size checks
inspect assigned properties rather than rendered pixels. Creator Hub IDs/prices
are compared to the owner's screenshots, not independently authenticated online.
The model geometry is procedural and is not guaranteed to match promotional JPGs.

Remaining checks: two-client Studio/private playtest, mobile/controller rendering,
actual soundtrack permissions/playback and SFX mix, R6/R15 crowns, real ownership
and receipt delivery/rejoin. Upload any still-blank Creator Hub item icons from
assets/shop-icons. Publish the v6 place over the existing experience only after
private verification. This cloud build does not change the live Roblox place.

## Crown/music correction

Crown equip checks now require an Accessory with 24 visible pieces, an invisible
noncolliding Handle, unchanged Head transparency, and a third-person minimum camera
zoom. Music simulation also forces a failed load, checks Retry Music stays enabled,
retries, and recovers after the Loaded event. All 67 checks and seven script
compilations passed after the correction. Actual wearables/camera rendering and
audio authorization still require a Roblox engine test.
