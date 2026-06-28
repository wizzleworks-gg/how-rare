-- Api.lua — HowRareAPI: the addon's original public API, kept as a thin back-compat
-- shim. The rarity data + tier opinion now live in the embedded AchievementRarity
-- library, which IS the public surface going forward — new integrators should reach
-- the data directly:
--     local AR = LibStub("AchievementRarity-1.0", true)
-- HowRareAPI remains so anything already gating on `if HowRareAPI then ... end` keeps
-- working; every method forwards to How Rare?'s Core helpers, which delegate to the
-- library and carry How Rare?'s own off-snapshot brand-gold fallback. Rarity data by
-- the Wizzleworks.
local _, G = ...

HowRareAPI = {
    -- Unchanged from before the library split; consumers gate on `>= n`. (The
    -- library carries its own raw/opinion contract version via its LibStub major.)
    version = 1,
    -- The data source, for integrators that want to credit it.
    source = G.AR.source,
}

local API = HowRareAPI

-- Region attainment as a percent (0–100), or nil if the achievement isn't in the
-- shipped snapshot (newer than this release).
function API:GetRarity(achievementID, scope)
    return G.RarityValue(achievementID, scope)
end

-- The raw account count behind the percentage (for "one of only N"), or nil
-- off-snapshot.
function API:GetCount(achievementID, scope)
    return G.AR:GetCount(achievementID, scope or G.Scope())
end

-- The rarity tier name: "legendary" / "epic" / "rare" / "uncommon" / "common" /
-- "junk", or nil off-snapshot.
function API:GetTier(achievementID, scope)
    return G.RarityTier(achievementID, scope)
end

-- r, g, b (each 0–1) of the tier colour (the loot-quality palette), or the brand
-- gold when off-snapshot. Three return values, like Blizzard colour getters.
function API:GetColor(achievementID, scope)
    return G.RarityColor(achievementID, scope)
end

-- Formatted attainment string ("3%", "<1%"), matching the website, or nil
-- off-snapshot.
function API:Format(achievementID, scope)
    return G.RarityFor(achievementID, scope)
end

-- Snapshot metadata: the as-of date, the per-region active-account denominators,
-- the player's home region, the data version (minor), and the user's current scope
-- (How Rare?'s own option). A fresh table each call so consumers can't mutate ours.
function API:GetMeta()
    local meta = G.AR:GetMeta()
    meta.scope = G.Scope()
    return meta
end

-- The tier bands, rarest first: { name, maxPct, r, g, b } — for consumers that want
-- to band rarity themselves. A fresh table each call.
function API:GetTiers()
    return G.AR:GetTiers()
end

-- Casing forgiveness: `HowRareAPI` is canonical (matches the achievementID argument
-- casing), but integrators reach for `Api` by reflex — alias it so a mistyped global
-- resolves to the same table instead of a silent nil.
HowRareApi = HowRareAPI
