-- AchievementRarity-1.0 — an embeddable achievement-rarity data library by the Wizzleworks.
--
-- Two layers, cleanly separable; the raw layer never depends on the opinion layer:
--   Raw (the hard contract)  GetRarity / GetCount / GetData / GetMeta — the share of
--                            accounts that hold an achievement, the account counts behind
--                            it, and the snapshot metadata. Region-scoped, zero house
--                            opinion. A consumer can get the % without ever touching bands.
--   Opinion (optional)       GetTier / GetColor / GetTiers / Format / FormatPct — our tier
--                            bands, borrowed from WoW's loot-quality palette, plus the
--                            display format. Exposed (GetTiers) so a consumer that
--                            disagrees can re-band straight from the raw number.
--
-- Off-snapshot: for an achievement newer than this data file, every getter returns nil.
-- The library imposes no fallback — each consumer decides its own (How Rare?, for example,
-- tints such rows its brand gold; a stranger may prefer to hide them).
--
-- All getters take an optional `scope`: "region" (the player's home region — the default)
-- or "global". The data file (loaded first) registers the library and installs the numbers;
-- this file attaches the read API. MIT licensed; the rarity numbers are facts compiled by
-- the Wizzleworks. Distribution + methodology:
-- https://github.com/wizzleworks-gg/achievement-rarity

assert(LibStub, "AchievementRarity-1.0 requires LibStub")
local lib = LibStub:GetLibrary("AchievementRarity-1.0", true)
if not lib then return end -- the data file registers the library; nothing to attach to without it

-- The data source, for integrators that want to credit it.
lib.source = "the Wizzleworks"

-- {us, eu, global} column order of the packed count triples the data file installs.
local REGION_INDEX = { us = 1, eu = 2, global = 3 }

-- The player's home region: own region for US/EU, "global" for everyone else (kr/tw/cn).
-- The "region" scope reads this column; "global" always reads the global column.
local REGION_BY_ID = { [1] = "us", [3] = "eu" }
lib.region = REGION_BY_ID[GetCurrentRegion()] or "global"

-- The data region a scope reads: "global" → global; "region"/default/nil → home region.
local function scopeRegion(scope)
    if scope == "global" then
        return "global"
    end
    return lib.region
end

--[[ Raw layer — the hard contract. ]]

-- Attainment as a percent (0–100) under a scope, or nil when the achievement isn't in this
-- snapshot (newer than the data file). The numeric basis everything else derives from.
function lib:GetRarity(achievementID, scope)
    local counts = self.counts[achievementID]
    if not counts then
        return nil
    end
    local region = scopeRegion(scope)
    local denom = self.accounts[region]
    if not denom or denom == 0 then
        return nil
    end
    return counts[REGION_INDEX[region]] / denom * 100
end

-- The raw account count behind the percentage (for "one of only N"), or nil off-snapshot.
function lib:GetCount(achievementID, scope)
    local counts = self.counts[achievementID]
    if not counts then
        return nil
    end
    return counts[REGION_INDEX[scopeRegion(scope)]]
end

-- The whole { [achievementID] = {us, eu, global} } table, for consumers that scan every id
-- (e.g. "your rarest earned achievement"). A live reference to ours — treat it read-only.
function lib:GetData()
    return self.counts
end

-- Snapshot metadata: the as-of date, the per-region active-account denominators, the
-- player's home region, and this data's `minor` (the freshness version). A fresh table each
-- call so consumers can't mutate ours.
function lib:GetMeta()
    return {
        asOf = self.asOf,
        accounts = {
            us = self.accounts.us,
            eu = self.accounts.eu,
            global = self.accounts.global,
        },
        region = self.region,
        minor = self.minor,
    }
end

--[[ Opinion layer — house style, optional and overridable. ]]

-- Rarity tiers, rarest first — the loot-quality idiom: the rarer the achievement, the higher
-- the band. Each carries the attainment % below which it applies and the ITEM_QUALITY_COLORS
-- index it borrows. Legendary is deliberately tight (<0.1%, ~1 in 1,000) so orange stays
-- special; junk (grey) is the ubiquitous tail almost everyone holds. An optional `color`
-- overrides the borrowed quality colour for that one tier.
local TIERS = {
    { name = "legendary", max = 0.1,       quality = 5 }, -- orange
    { name = "epic",      max = 5,         quality = 4 }, -- purple
    { name = "rare",      max = 15,        quality = 3 }, -- blue
    { name = "uncommon",  max = 40,        quality = 2 }, -- green
    { name = "common",    max = 70,        quality = 1 }, -- white
    -- Junk overrides the loot palette's quality-0 grey (0.62 — washed out on light
    -- backgrounds) with a darker grey so it reads cleanly.
    { name = "junk",      max = math.huge, quality = 0, color = { r = 0.5, g = 0.5, b = 0.5 } }, -- grey
}

local function tierColor(t)
    return t.color or ITEM_QUALITY_COLORS[t.quality]
end

local function tierForPct(pct)
    for _, t in ipairs(TIERS) do
        if pct < t.max then
            return t
        end
    end
    return TIERS[#TIERS]
end

-- pct, the tier entry, and the tier's colour for an id under a scope; nil off-snapshot.
local function resolve(self, achievementID, scope)
    local pct = self:GetRarity(achievementID, scope)
    if not pct then
        return nil
    end
    local t = tierForPct(pct)
    return pct, t, tierColor(t)
end

-- The tier name ("legendary".."junk") for an achievement, or nil off-snapshot.
function lib:GetTier(achievementID, scope)
    local _, t = resolve(self, achievementID, scope)
    return t and t.name
end

-- r, g, b (each 0–1) of the tier colour (the loot-quality palette), or nil off-snapshot.
-- Three return values, like Blizzard's colour getters.
function lib:GetColor(achievementID, scope)
    local _, _, c = resolve(self, achievementID, scope)
    if not c then
        return nil
    end
    return c.r, c.g, c.b
end

-- The tier bands, rarest first: { name, maxPct, r, g, b } — for consumers that want to band
-- rarity themselves. maxPct is the attainment % below which the tier applies (the open-ended
-- top tier reports 100). A fresh table each call.
function lib:GetTiers()
    local out = {}
    for i, t in ipairs(TIERS) do
        local c = tierColor(t)
        out[i] = { name = t.name, maxPct = math.min(t.max, 100), r = c.r, g = c.g, b = c.b }
    end
    return out
end

-- No false precision: whole-% at/above 1%, "<1%" below. pct is 0–100. The raw display
-- convention, for a percent you already hold.
function lib:FormatPct(pct)
    if pct < 1 then
        return "<1%"
    end
    return math.floor(pct + 0.5) .. "%"
end

-- Formatted attainment ("3%", "<1%") for an achievement under a scope, or nil off-snapshot.
function lib:Format(achievementID, scope)
    local pct = self:GetRarity(achievementID, scope)
    if not pct then
        return nil
    end
    return self:FormatPct(pct)
end
