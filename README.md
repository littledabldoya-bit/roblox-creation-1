# FartNight v6 — Neon City Arena

Open **fartnightv6.rbxlx** in Roblox Studio, playtest, then publish over the existing
Fart-Night experience. This is the near-final private-playtest candidate. The cloud
workspace does not edit the published Roblox place automatically.

Latest v6 correction: crowns use wearable Accessory instances without changing the
Head, shoulder-camera zoom stays outside first person, and failed music loads offer
Retry Music instead of permanently disabling the control. A denied audio asset still
requires the correct Roblox experience permission; check Studio Output for the cause.

## Included in the game

- Preserved original arena geometry, balanced cyan/purple accents, subdued bloom,
  district signage, practice targets, coins, health/shield pickups and moving storm.
- Three free starter weapons: Bean Blaster, Burp Cannon and Toxic Tagger. Burp
  Cannon's center pellet follows the crosshair; tracers follow actual server rays.
- Detailed Ion Striker and Void Reaper models, entitlement-checked delivery,
  five-slot loadout, server ammo, reloads and hit confirmation. Ion deals 50 HP per
  hit; Void deals 100 HP per hit, piercing shields. Spawn protection still applies.
- Three wearable crown models with wear/remove controls and saved selection;
  seven cloud cosmetics, VIP Prism/name tag, Double Coins, and repeatable coin packs.
- Armory tabs, live Roblox price lookup with retries, actual 3D previews for both
  premium guns and all three crowns, native purchase prompts, and cancellation.
- Health/stamina/ammo HUD, progression, elimination feed, first-spawn briefing,
  keyboard/touch/controller bindings, reduced-motion/effects options.
- Original 152 BPM, 3:24 soundtrack connected to asset **86882641437260**;
  gunfire, reload, hit and movement sounds, positional remote shots, independent
  music/SFX muting and menu music ducking. SFX use processed bundled Roblox sounds.
- Durable coin receipts with replay protection, profile session leases, save retries,
  and spending disabled when persistence is unavailable. Bought coin packs are not
  multiplied by Double Coins. Premium Studio preview is disabled in this release.

## Connected Creator Hub catalog

These IDs and base prices match the owner's supplied screenshots. Managed/regional
prices can vary; the shop fetches Roblox metadata and the native prompt confirms
what the player actually pays. Config values cannot change Creator Hub prices.

| Item | Type | ID | Base Robux |
| --- | --- | ---: | ---: |
| Double Coins | Pass | 2036219448 | 99 |
| VIP | Pass | 2040029198 | 149 |
| Ion Striker | Pass | 2040425005 | 249 |
| Void Reaper | Pass | 2037023377 | 499 |
| Vanguard Crown | Pass | 2040730906 | 499 |
| Sovereign Crown | Pass | 2041832815 | 799 |
| Eclipse Crown | Pass | 2037179505 | 999 |
| 250 Coins | Developer product | 3720387393 | 19 |
| 1,200 Coins | Developer product | 3720387708 | 79 |
| 4,000 Coins | Developer product | 3720387802 | 189 |

All ten are connected in the game. Creator Hub item artwork is a separate upload:
`assets/shop-icons/` and `fartnight-all-shop-icons.zip` contain the ten JPGs.
Gun/crown shop previews use game models directly. VIP/coin cards use Roblox item
icons when supplied, with text badges as a fallback. Shopify/Commerce is unnecessary
for these in-game purchases. Keep old product ID/award mappings if retiring products
so pending receipts can still be fulfilled.

## Build and verify

Editable sources are in `src/`. `tools/build_place.py` embeds all seven scripts in
the original map and applies the documented material adjustments. Preserve
`assets/FartNight.original.rbxlx`. Reconcile Studio-only edits before rebuilding.

```bash
cd /workspace/roblox-creation-1
python3 tools/verify_release.py
```

The cloud Luau toolchain is installed by `/workspace/roblox-tools/install.sh`
(Luau 0.690, pinned source commit). No background server is needed. Use the existing
isolated checkout; do not create a Git worktree unless requested.

Verification rebuilds the place, checks scene preservation/source embedding and
MP3 decoding, compiles all scripts, then runs economy, persistence, catalog, audio,
combat and full-source integration simulations. The latter execute the actual
server/client/world/camera sources against deterministic service doubles and an
instance tree loaded from the generated XML. They cover content presence, owned
and free loadouts, catalog cards, preview creation, prompt cancellation, exact
receipt delivery/replays, crowns, assigned shop dimensions, music playback requests,
all weapon ray counts, premium damage/protection, purchase delivery and a reload
across respawn regression. They do not emulate rendering, physics, audio delivery,
real DataStores or live Roblox commerce.

## Required private Studio playtest

1. Open `fartnightv6.rbxlx`, start a server with two clients and inspect both Outputs.
   Check all five weapons, crosshair/tracers, reloads, spawn protection, KOs, respawn,
   pickups, practice targets, and storm damage. Nonowners should get three guns.
2. Use device emulation for phone portrait/landscape, tablet and desktop. Check
   readable cards and previews, scrolling, safe insets, controller/touch controls,
   crown placement on R6/R15 avatars, and lighting after an actual play session.
3. Verify soundtrack moderation/experience permission and audible music, local/remote
   shots and footsteps, volume balance and both mute settings. Offline tests verify
   SoundId assignment and playback requests, not whether Roblox delivers audio.
4. Publish privately over the existing experience. Check pass ownership, purchase
   cancellation, newly purchased guns/crowns, exact coin delivery and rejoining with
   saved coins/XP/equipped cosmetics. Real purchases may spend Robux. Studio API
   access is needed for Studio persistence tests; a crashed-server lease can take
   up to three minutes to expire.
5. Finish Creator Hub gun/coin icons if still blank, experience thumbnails, description,
   supported devices and content maturity. Complete private testing before making
   the experience public. Cloud simulations cannot certify a public launch.
