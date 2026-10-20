-- FART-NIGHT / ReplicatedStorage / FN_Config
-- Replace all 0 IDs with your OWN Roblox Creator Hub monetization IDs.
local Config = {}

Config.GameName = "FART-NIGHT"
Config.Version = "3.3.0"
Config.ArenaRadius = 255
Config.RespawnSeconds = 3
Config.CoinPickupValue = 5
Config.KillCoins = 25
Config.TargetCoins = 5
Config.CoinRespawnSeconds = 16
Config.SpawnShieldSeconds = 6
-- A safe inner spawn circle never touches the looping gas storm.
Config.SafeSpawnRadius = 74
Config.StormPeriod = 240
Config.StormMaxRadius = 275
Config.StormMinRadius = 190
Config.StormCenterWander = 20

Config.Weapons = {
    BeanBlaster = { Display = "BEAN BLASTER", Damage = 12, FireDelay = 0.14, Magazine = 32, Reload = 1.9, Range = 380, Pellets = 1, Spread = 0.012, Color = Color3.fromRGB(70, 255, 119), Automatic = true },
    BurpCannon = { Display = "BURP CANNON", Damage = 9, FireDelay = 0.88, Magazine = 7, Reload = 2.2, Range = 120, Pellets = 8, Spread = 0.095, Color = Color3.fromRGB(244, 222, 69), Automatic = false },
    ToxicTagger = { Display = "TOXIC TAGGER", Damage = 46, FireDelay = 1.10, Magazine = 8, Reload = 2.6, Range = 650, Pellets = 1, Spread = 0.001, Color = Color3.fromRGB(175, 99, 254), Automatic = false },
}
Config.WeaponOrder = {"BeanBlaster", "BurpCannon", "ToxicTagger"}

-- Owned/equipped outfit accent colors; these are the fun unlocks, not stat buffs.
Config.Cosmetics = {
    {Id = "Mint", Name = "MINT CLOUD", Cost = 0, Color = Color3.fromRGB(77, 255, 156)},
    {Id = "Berry", Name = "BERRY BLAST", Cost = 120, Color = Color3.fromRGB(214, 96, 255)},
    {Id = "Bubblegum", Name = "BUBBLEGUM", Cost = 220, Color = Color3.fromRGB(255, 123, 196)},
    {Id = "Electric", Name = "ELECTRIC BLUE", Cost = 380, Color = Color3.fromRGB(75, 182, 255)},
    {Id = "Lime", Name = "RADIOACTIVE LIME", Cost = 650, Color = Color3.fromRGB(226, 255, 61)},
    {Id = "Golden", Name = "GOLDEN TOOT", Cost = 900, Color = Color3.fromRGB(255, 204, 75)},
    {Id = "Prismatic", Name = "VIP PRISM", Cost = -1, Color = Color3.fromRGB(255, 255, 255)},
}

Config.Passes = {
    VIP = 0, -- exclusive VIP Prism cosmetic + golden VIP tag (no damage buffs)
    DoubleCoins = 0, -- 2x coins earned from gameplay; no combat stat advantage
}
-- Each wearable crown is a permanent game pass, not a repeatable product.
Config.Crowns = {
    {Id = "Vanguard", Name = "VANGUARD CROWN", PassId = 0, Color = Color3.fromRGB(109, 186, 210)},
    {Id = "Sovereign", Name = "SOVEREIGN CROWN", PassId = 0, Color = Color3.fromRGB(213, 166, 66)},
    {Id = "Eclipse", Name = "ECLIPSE CROWN", PassId = 0, Color = Color3.fromRGB(159, 124, 203)},
}

Config.Products = {
    Coin250 = 0, -- Creator Hub developer product; repeatable
    Coin1200 = 0,
    Coin4000 = 0,
}
-- Creator Hub launch prices (Robux). Metadata only: Roblox remains authoritative.
Config.LaunchPrices = {
    VIP = 149, DoubleCoins = 99,
    Vanguard = 49, Sovereign = 99, Eclipse = 149,
    Coin250 = 19, Coin1200 = 79, Coin4000 = 199,
}
-- Upload assets/music/NeonCircuit.mp3 under the experience owner, grant the
-- experience permission to use it, and put the resulting audio asset ID here.
Config.Music = {SoundId = 0, Volume = 0.22}
-- Built-in Roblox character audio used as processed percussion fallbacks.
-- Replace SoundId strings with uploaded custom assets later if desired.
Config.Audio = {
    Volume = 0.75,
    Footsteps = "rbxasset://sounds/action_footsteps_plastic.mp3",
    Reload = "rbxasset://sounds/action_get_up.mp3",
    Hit = "rbxasset://sounds/action_jump_land.mp3",
    Weapons = {
        BeanBlaster = {SoundId = "rbxasset://sounds/action_jump_land.mp3", Speed = 1.8, Volume = .6},
        BurpCannon = {SoundId = "rbxasset://sounds/action_jump_land.mp3", Speed = .65, Volume = .8},
        ToxicTagger = {SoundId = "rbxasset://sounds/action_jump_land.mp3", Speed = 2.5, Volume = .7},
    },
}

Config.ProductAwards = {Coin250 = 250, Coin1200 = 1200, Coin4000 = 4000}
return Config
