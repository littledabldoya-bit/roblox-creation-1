# FartNight v6 — Neon City Arena

Open **fartnightv6.rbxlx** in Roblox Studio, playtest, then publish over the existing
Fart-Night experience. The cloud workspace does not edit the published Roblox place
automatically.

Crown cosmetics and their pass offers have been removed from the game. There is no
crown tab, purchase, model, or equip action. Old saved crown selections are ignored.
The already-created Creator Hub passes remain on Roblox; this change removes their
game functionality and listing only.

## Included in the game

- Preserved original arena geometry, toned-down cyan/purple accents, district signs,
  practice targets, coins, health/shield pickups and moving storm.
- Three free starter weapons plus detailed Ion Striker and Void Reaper models,
  entitlement checks, five-slot loadout, server ammo, reloads and hit confirmation.
  Ion deals 50 HP per hit; Void deals 100 HP per hit and pierces shields.
- Seven cloud cosmetics, VIP Prism/name tag, Double Coins and repeatable coin packs.
- Armory tabs for skins, guns, passes, coins and settings; live price lookup, previews
  for premium guns, purchase prompts, cancellation and responsive controls.
- HUD, progression, elimination feed, input for keyboard/touch/controller, options for
  reduced motion/effects, and the original 152 BPM soundtrack (audio asset
  **86882641437260**) with gunfire, reload, hit and movement sounds.
- Persistent profiles, session leases, receipt replay protection and save retries.
  Spending is disabled when persistence is unavailable. Double Coins does not
  multiply purchased coin packs.

## In-game Creator Hub items

| Item | Type | ID | Base Robux |
| --- | --- | ---: | ---: |
| Double Coins | Pass | 2036219448 | 99 |
| VIP | Pass | 2040029198 | 149 |
| Ion Striker | Pass | 2040425005 | 249 |
| Void Reaper | Pass | 2037023377 | 499 |
| 250 Coins | Developer product | 3720387393 | 19 |
| 1,200 Coins | Developer product | 3720387708 | 79 |
| 4,000 Coins | Developer product | 3720387802 | 189 |

These seven items are connected in game. Roblox's live pricing and native purchase
prompt are authoritative. The sales-art ZIP contains JPGs for the remaining offers;
retired crown artwork is excluded. Keep old developer-product ID/award mappings if
retiring a product so outstanding receipts can still be fulfilled.

## Build and verify

Editable sources are in `src/`. `tools/build_place.py` embeds the scripts in the
original map and applies the documented material adjustments. Preserve
`assets/FartNight.original.rbxlx` and reconcile Studio-only edits before rebuilding.
Use the existing checkout; do not create a worktree unless requested.

```bash
cd /workspace/roblox-creation-1
python3 tools/verify_release.py
```

The offline suite exercises economy, persistence, catalog, audio, combat, actual
source integration against simulated Roblox services, XML preservation and script
compilation. The simulation does not emulate Roblox rendering, physics, sound
delivery, live DataStores or purchases. Test those in a private Studio session before
making the experience public. For soundtrack playback, confirm experience audio
permission. Use two clients to check multiplayer combat and items.
