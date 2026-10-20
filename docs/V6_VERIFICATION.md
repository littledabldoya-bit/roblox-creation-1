# v6 offline verification — 20 October 2026

Artifact: `fartnightv6.rbxlx`  
SHA256: `12afd5c7ac8b788bd22d68f6df0b8560c0bb5d4f5fb1c2d84af4ac97d66cf5d2`

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

## Follow-up camera-fade correction

The reported Studio issue persisted after the accessory/minimum zoom change.
The shoulder-camera render callback now resets LocalTransparencyModifier on the
local Head and crown after the default camera update. Crown parts are welded to
one accessory Handle and the ring sits farther out and above the head. The existing
crown integration scenario now injects camera fade on the Head and every crown part,
invokes the actual render callback, and checks that local visibility is restored.
All 67 offline checks and seven compilations pass. This verifies the code path,
not Roblox rendering; the user has not yet confirmed this follow-up in Studio.
Music authorization remains blocked in the user's unpublished experience 0;
code cannot grant Roblox audio permissions.

## Visible crown badge fallback

The user reported that the crown remained invisible after the camera fade fix. An
always-on-top BillboardGui assembled from ordinary UI shapes now displays a raised
three-point crown above an equipped character. It sits alongside the detailed 3D
crown and is removed with it. The integration scenario checks all three crown tiers
show the badge when equipped and clear it when removed. The full offline release
suite passed again; seven embedded scripts compile. Studio visual confirmation is
still needed.
