# FartNight: Neon City Arena

Version 3.1 — softer lighting and wearable crowns.

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

| Config key | Roblox item | Delivery |
| --- | --- | --- |
| `Passes.VIP` | Game pass | Permanent Prism cloud color and gold overhead tag |
| `Passes.DoubleCoins` | Game pass | Permanent 2× earned gameplay coins |
| `Crowns[1].PassId` | Game pass | Permanent wearable Vanguard crown |
| `Crowns[2].PassId` | Game pass | Permanent wearable Sovereign crown |
| `Crowns[3].PassId` | Game pass | Permanent wearable Eclipse crown |
| `Products.Coin250` | Developer product | 250 coins per purchase |
| `Products.Coin1200` | Developer product | 1,200 coins per purchase |
| `Products.Coin4000` | Developer product | 4,000 coins per purchase |

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
  before changing public availability. No icon, audio pack, thumbnails, or live
  publication is included in this source update.

The cloud task is already isolated. Use its existing checkout; create a Git worktree
only when explicitly requested.
