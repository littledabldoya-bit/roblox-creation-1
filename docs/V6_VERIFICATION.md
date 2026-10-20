# FartNight v6 release verification

The current build removes crown cosmetics, all three crown pass offers, previews,
models, saved equip state and equip remotes. Previously saved crown selections are
dropped during profile normalization. The corresponding Creator Hub passes still
exist in Roblox, but the game no longer lists or grants them.

`python3 tools/verify_release.py` passed **63 offline checks** and compiled all seven
embedded scripts. The full-source simulator loads the generated Roblox XML and runs
the shipped server, world, client and camera scripts against simulated services. It
checks five gun models, seven paid listings, seven cloud skin offers, absence of
crown content, rejection of retired crown pass IDs, receipts, combat, audio control
and viewport properties.

Service doubles do not emulate Roblox rendering, physics, sound delivery, live
DataStores or real purchases. Studio/private testing is still necessary for those
engine behaviors. The owner publishes the generated place to Roblox.
