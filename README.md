# FartNight: Neon City Arena

Version 3.3 — gun/footstep effects, balanced neon accents, original soundtrack, and launch pricing.

Competitive sci-fi free-for-all built from the supplied Roblox Studio place.
Open **FartNight.rbxlx** in Roblox Studio. The unchanged upload is retained in
`assets/FartNight.original.rbxlx`.

## This version

- Navy/cyan combat HUD, health and stamina meters, XP progression, low-ammo feedback,
  confirmed hit markers, elimination feed, and a first-spawn briefing.
- Responsive Armory with separate Skins, Crowns, Passes, Coins, and Settings tabs.
  Paid offers show Roblox prices when configured; unconfigured offers say Coming Soon.
- Keyboard, touch, and controller bindings; subtle recoil with a reduced-motion option;
  reduced impact-particle option. Preferences currently last for the session.
- Subdued cyan accents, non-emissive broad surfaces, low bloom, gentler lamps, consistent district signage, and proximity health/shield labels.
- Three permanent wearable crown passes (Vanguard, Sovereign, Eclipse), VIP cloud color/name tag and Double Coins passes, plus three repeatable coin packs. Crowns have wear/remove controls, survive respawn, and save the equipped selection; entitlement comes from Roblox.
  All weapons are free; paid items do not change weapon damage or health.
- Persistent, idempotent receipt fulfillment, session leases, deferred fulfillment
  during storage failures, save retries on departure, and shutdown save completion.

## Editing and rebuilding

The editable scripts are in `src/`. The place is generated from those scripts and
the original map, without changing its geometry. Explicit material/color overrides soften the original neon surfaces in both the generated place and at runtime.

```bash
cd /workspace/roblox-creation-1
python3 tools/build_place.py
python3 -m unittest discover -s tests -p 'test_*.py'
/workspace/roblox-tools/luau/build/luau tests/economy.luau
python3 tests/run_server_tests.py
python3 tests/run_catalog_tests.py
python3 tests/run_audio_tests.py
python3 /workspace/roblox-tools/check_place.py FartNight.rbxlx
```

Cloud tools are outside the checkout in `/workspace/roblox-tools`. Rebuild before
opening the place in Studio. Changes made only inside Studio are not automatically
exported to `src/`; reconcile them before rebuilding. Keep the original upload intact.

## Enable real purchases

The experience is not published and **all product/pass IDs remain zero**.
The current place is a development candidate, not a verified live release.

1. Open the updated place in Studio and publish it as a **private test experience**
   under the intended Roblox account/group.
2. In that experience's Creator Hub monetization settings, create the items below,
   choose their prices, and make them available for sale.
3. Put their real numeric IDs in `src/ReplicatedStorage/FN_Config.luau`, rebuild,
   and publish the updated place to the same experience. Use unique IDs; do not use
   asset IDs or IDs belonging to another experience.

| Config key | Roblox item | Delivery | Launch price (Robux) |
| --- | --- | --- | ---: |
| `Passes.VIP` | Game pass | Permanent Prism cloud color and gold overhead tag | 149 |
| `Passes.DoubleCoins` | Game pass | Permanent 2× earned gameplay coins | 99 |
| `Crowns[1].PassId` | Game pass | Permanent wearable Vanguard crown | 49 |
| `Crowns[2].PassId` | Game pass | Permanent wearable Sovereign crown | 99 |
| `Crowns[3].PassId` | Game pass | Permanent wearable Eclipse crown | 149 |
| `Products.Coin250` | Developer product | 250 coins per purchase | 19 |
| `Products.Coin1200` | Developer product | 1,200 coins per purchase | 79 |
| `Products.Coin4000` | Developer product | 4,000 coins per purchase | 199 |

These are the chosen base launch prices; enter them in Creator Hub when creating
items. `Config.LaunchPrices` records the plan and supplies prelaunch labels only;
it cannot change Roblox prices. Once real IDs are present, the shop fetches live
prices and Roblox's native purchase prompt remains authoritative (including any
regional pricing). Crown tiers provide 49/99/149 Robux entry points; bulk coin
packs have progressively lower per-coin costs. Existing earned cosmetic costs
are unchanged.

Purchased coin packs are never multiplied by Double Coins. Currency is used for
cloud cosmetic unlocks. Wearable crowns are direct Robux game-pass purchases, not coin purchases or premium currency. A newly confirmed crown purchase equips it automatically; owned crowns can be worn or removed from the Crowns tab. Crown PassId values remain zero until configured, so they show Coming Soon. The shop reads prices from Roblox; the native Roblox confirmation
prompt determines the final price. A prompt-finished event never awards product
currency: the server waits for a durable receipt commit before acknowledging it.
Old product IDs/awards must remain mapped if products are ever retired, so outstanding
receipts can still be fulfilled. Do not delete an old mapping to replace a product.

No password, API key, or cloud secret is required. Creator Hub access is needed to
create the experience and items; publishing was not performed from this workspace.

## Required Studio checks before a public release

Offline compilation and simulated persistence tests do **not** validate the Roblox
engine, screen layout, live purchases, or actual DataStore behavior.

- Start a server with two clients. Check spawn protection, all three weapons,
  reloading, hits/headshots, KOs, respawn, coins, health/shield pickups, and the storm.
- Use the device emulator for phone portrait/landscape, tablet, desktop, and
  controller. Check the Armory scroll area, safe screen insets, aim/crosshair
  alignment, touch controls, and that opening the menu stops firing/sprinting.
- Inspect server and client Output for runtime errors. Check reduced-motion and
  effects options. Tune recoil/lighting after an actual playtest.
- In the private test experience, configure Studio API access as needed for
  persistence testing. Confirm coins, cosmetic purchases/equips, XP, and KOs survive
  leaving/rejoining. Simulate unavailable storage: gameplay continues, but spending
  stays disabled. A stale crashed-server lease may take up to three minutes to expire;
  rejoin afterward if the profile remains unavailable.
- With real IDs, test crown purchase/wear/remove, respawn, hat compatibility on R6/R15 avatars, selected crown after rejoin, pass ownership, product coin delivery,
  cancellation, unavailable items, repeated receipt delivery, and interrupted saves.
  Use Roblox-supported test flows where available; real purchases may spend Robux.
  Keep price labels synchronized with the native confirmation prompt.
- Set the experience icon, thumbnails, description, supported devices, and accurate
  content-maturity information in Creator Hub, then complete a private playtest
  before changing public availability. Icon/thumbnail setup and live
  publication remain Creator Hub tasks.

The cloud task is already isolated. Use its existing checkout; create a Git worktree
only when explicitly requested.

## Original soundtrack

`assets/music/NeonCircuit.mp3` is an original 152 BPM, 3:24 stereo instrumental,
with changing lead sections, breakdowns, fills, and a fade at the loop boundary.
It was synthesized for this project without third-party samples. Arena Music in
Settings provides muting and the Armory ducks its volume; respawning does not
restart it. Audio is mastered near -16 LUFS and -1.5 dBTP, with default in-game
volume 0.22. See `assets/music/README.md` for regeneration and upload details.

**One-time Roblox activation is required:** upload the MP3 as audio under the
experience owner, wait for approval, grant the experience access, and put its
numeric asset ID in `Config.Music.SoundId`. Rebuild and publish the place afterward.
The ID is currently zero, so music shows Coming Soon until that is done. Audio
playback, music/combat balance and the revised neon appearance still require a
Studio/private-server playtest; offline checks cannot judge the final game mix.

## Gunfire and movement audio

Gunfire, reload-start feedback and confirmed-hit feedback now have audio. Gunfire
uses distinct pitch/EQ/distortion profiles per weapon. The shooter hears a local
predicted shot immediately; the server includes its player ID in broadcast FX so
the same client does not play it twice. Other players hear positional shots, with
distance culling and a 24-voice cap. Footstep loops start only while grounded and
moving, change cadence for sprinting, and clean up on respawn. Default Running
sounds are suppressed while the custom loop is active to avoid double footsteps.
Armory → Settings → Mute Sound Effects controls this effect group independently.

These effects use processed engine-bundled character/percussion sounds as
fallbacks; no separate audio upload is needed for them. They are not bespoke
recorded gun samples. Their paths are documented in Roblox's Core-Scripts:
https://github.com/Roblox/Core-Scripts/blob/425d2d641bdc4b6c1104a9d5f6c53c9ea758c5cb/PlayerScripts/StarterCharacterScripts/Sound.server.lua
Config.Audio exposes the IDs, pitches and volumes for future custom samples.

**Music remains a separate upload requirement.** The original music is in
`assets/music/NeonCircuit.mp3` in this repository/ZIP. Local files cannot be used
as SoundId values in a published Roblox place. Upload that MP3 through Creator
Hub Audio, grant the experience access, and supply the numeric asset ID so it can
be connected to Config.Music.SoundId. It is still zero; do not expect music yet.

Simulated-service tests cover effect triggering, voice culling/cleanup and
footstep movement/airborne/respawn behavior. Verify actual asset playback and
mixing in Studio, with Roblox Settings volume above zero, plus two clients for
remote footsteps/shots. Audio playback has not been tested in the Roblox engine.
