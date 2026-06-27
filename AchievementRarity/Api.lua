-- Api.lua — the public, read-only, versioned API other addons build on. Thin
-- wrappers over the same internals our own surfaces use, so the API and the addon
-- can never disagree. Consumers gate on `if AchievementRarityAPI then ... end` and
-- may check `.version`. All getters take an optional `scope`: "region" (the
-- player's home region, the user's default) or "global". Rarity data by gratz.gg.
local _, G = ...

AchievementRarityAPI = {
    -- Bump on breaking changes; additive changes keep the version. Consumers
    -- gate on `>= n`.
    version = 1,
    -- The data source, for integrators that want to credit it.
    source = "gratz.gg",
}

local API = AchievementRarityAPI

-- Region attainment as a percent (0–100), or nil if the achievement isn't in the
-- shipped snapshot (newer than this release).
function API:GetRarity(achievementID, scope)
    return G.RarityValue(achievementID, scope)
end

-- The raw account count behind the percentage (for "one of only N"), or nil
-- off-snapshot.
function API:GetCount(achievementID, scope)
    local counts = G.RarityCounts[achievementID]
    if not counts then
        return nil
    end
    return counts[G.ScopeIndex(scope)]
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

-- Formatted attainment string ("3%", "<1%"), matching the gratz.gg site, or nil
-- off-snapshot.
function API:Format(achievementID, scope)
    return G.RarityFor(achievementID, scope)
end

-- Snapshot metadata: the as-of date, the per-region active-account denominators,
-- the player's home region, and the user's current scope. A fresh table each call
-- so consumers can't mutate ours.
function API:GetMeta()
    return {
        asOf = G.Meta.asOf,
        accounts = {
            us = G.Meta.accounts.us,
            eu = G.Meta.accounts.eu,
            global = G.Meta.accounts.global,
        },
        region = G.region,
        scope = G.Scope(),
    }
end

-- The tier bands, rarest first: { name, maxPct, r, g, b } — for consumers that
-- want to band rarity themselves. maxPct is the attainment % below which the tier
-- applies (the open-ended top tier reports 100). A fresh table each call.
function API:GetTiers()
    local out = {}
    for i, t in ipairs(G.TIERS) do
        local c = ITEM_QUALITY_COLORS[t.quality]
        out[i] = {
            name = t.name,
            maxPct = math.min(t.max, 100),
            r = c.r, g = c.g, b = c.b,
        }
    end
    return out
end
