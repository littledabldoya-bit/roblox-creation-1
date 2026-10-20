-- Pure economy operations. All persistence and authorization live on the server.
local Economy = {}

local function integer(value)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
    return math.max(0, math.floor(value))
end

function Economy.normalize(value, cosmetics)
    local old = type(value) == "table" and value or {}
    local data = {
        Coins = integer(old.Coins), XP = integer(old.XP),
        KOs = integer(old.KOs), Deaths = integer(old.Deaths),
        Unlocks = {Mint = true}, Equipped = "Mint", Receipts = {},
    }
    if type(old.Unlocks) == "table" then
        for id, owned in pairs(old.Unlocks) do
            if owned == true and cosmetics[id] then data.Unlocks[id] = true end
        end
    end
    if type(old.Receipts) == "table" then
        for id, granted in pairs(old.Receipts) do
            if type(id) == "string" and granted == true then data.Receipts[id] = true end
        end
    end
    if cosmetics[old.Equipped] then data.Equipped = old.Equipped end
    if type(old.LastSaveId)=="string" then data.LastSaveId=old.LastSaveId end
    if type(old.Session) == "table" then data.Session = table.clone(old.Session) end
    return data
end

function Economy.canClaim(data, owner, now)
    local lease = data.Session
    return not lease or lease.Owner == owner or type(lease.Expires) ~= "number" or lease.Expires <= now
end

function Economy.grantReceipt(data, purchaseId, award)
    assert(type(purchaseId) == "string" and #purchaseId > 0, "Invalid receipt ID")
    assert(type(award) == "number" and award > 0 and award % 1 == 0, "Invalid receipt award")
    if data.Receipts[purchaseId] then return false end
    data.Coins += award
    data.Receipts[purchaseId] = true
    return true
end

function Economy.productAward(config, productId)
    if type(productId) ~= "number" or productId <= 0 then return nil end
    local found
    for key, id in pairs(config.Products) do
        if id == productId then
            local amount = config.ProductAwards[key]
            -- Ambiguous or malformed catalogs must never grant the wrong product.
            if found or type(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then return nil end
            found = amount
        end
    end
    return found
end

return Economy
