-- AchievementRarity-1.0 — an embeddable achievement-rarity data library by the Wizzleworks.
--
-- Two layers, cleanly separable; the raw layer never depends on the opinion layer:
--   Raw (the hard contract)  GetRarity / GetCount / GetData / GetMeta / RankAtEarn — the
--                            share of accounts that hold an achievement, the account counts
--                            behind it, the snapshot metadata, and how early a given earn
--                            date was. Region-scoped, zero house opinion. A consumer can
--                            get the % without ever touching bands.
--   Opinion (optional)       GetTier / GetColor / GetTiers / Format / FormatPct — our tier
--                            bands, borrowed from WoW's loot-quality palette, plus the
--                            display format. Exposed (GetTiers) so a consumer that
--                            disagrees can re-band straight from the raw number.
--
-- Off-snapshot: for an achievement newer than this data file, every getter returns nil.
-- The library imposes no fallback — each consumer decides its own (How Rare?, for example,
-- tints such rows its brand gold; a stranger may prefer to hide them).
--
-- All getters take an optional `scope`: "region" (the player's home region — the default),
-- "global", or an explicit region name ("us" / "eu") for consumers that want a specific
-- column regardless of where the player plays. The data file (loaded first) registers the
-- library and installs the numbers; this file attaches the read API. MIT licensed; the
-- rarity numbers are facts compiled by the Wizzleworks. Distribution + methodology:
-- https://github.com/wizzleworks-gg/achievement-rarity

assert(LibStub, "AchievementRarity-1.0 requires LibStub")
local lib = LibStub:GetLibrary("AchievementRarity-1.0", true)
if not lib then return end -- the data file registers the library; nothing to attach to without it

-- Freshest-API-wins, the read-API analogue of the data file's freshest-snapshot-wins.
-- LibStub arbitrates the DATA half by snapshot minor, but this static half attaches via
-- GetLibrary unconditionally — so when several consumers embed DIFFERENT API versions,
-- whichever static file loads last would otherwise clobber a newer one (a mixed-version
-- API). Gate on our own API minor, orthogonal to the snapshot minor: a client ends up
-- with the newest data AND the newest API, each arbitrated independently. Bump API_MINOR
-- on any change to the methods below; `_apiMinor` is owned solely here (the data file
-- never sets it). With a single consumer this never fires.
local API_MINOR = 4 -- 4: collection standing (CollectionWeight/Score/Standing/Tier); 3: junk 0.75 grey; 2: RankAtEarn re-base
if lib._apiMinor and lib._apiMinor >= API_MINOR then return end
lib._apiMinor = API_MINOR

-- The data source, for integrators that want to credit it.
lib.source = "the Wizzleworks"

-- {us, eu, global} column order of the packed count triples the data file installs.
local REGION_INDEX = { us = 1, eu = 2, global = 3 }

-- The player's home region: own region for US/EU, "global" for everyone else (kr/tw/cn).
-- The "region" scope reads this column; "global" always reads the global column.
local REGION_BY_ID = { [1] = "us", [3] = "eu" }
lib.region = REGION_BY_ID[GetCurrentRegion()] or "global"

-- The data region a scope reads: "region" (or nil) → the player's home region; an
-- explicit region name ("us" / "eu" / "global") → itself, so a consumer can ask for
-- a specific column (e.g. a tooltip showing all three side by side) without touching
-- the packed count layout. Anything unrecognised falls back to the home region — the
-- behaviour before explicit regions existed.
local function scopeRegion(scope)
    if scope and REGION_INDEX[scope] then
        return scope
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
-- player's home region, this data's `minor` (the freshness version), and the rank floor
-- (the system-launch date the rank-at-earn metric measures from, nil if this data file
-- predates rank support). A fresh table each call so consumers can't mutate ours.
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
        rankFloor = self.rankFloor,
    }
end

--[[ Rank-at-earn — raw layer, no house opinion. ]]

-- How early you earned an achievement, measured against ALL tracked accounts: "you were
-- in the first N% to earn this", where N is the share of the whole active population
-- that earned it before you. An account that never earned it cannot have earned it
-- before you, so non-earners count after every earner and the metric is simply your
-- position in the earn order over the population — the same denominator as GetRarity,
-- so the two read consistently side by side (every earner of a 4%-rarity achievement is
-- somewhere within its "first ~4%"; the earliest are "first <0.1%"). Ranking within
-- earners only was considered and rejected: it punishes exactly the rare achievements
-- the metric exists for (a mid-pack earner of a top-4% achievement is still ahead of
-- the 96% who never earned it at all).
--
-- Mechanically: the data file ships, per achievement per scope, a small array of
-- day-offsets (from lib.rankFloor) marking the date by which each lib.rankLadder
-- percentile of current earners had earned it; the player's own earn date interpolates
-- against those to an earner-percentile, which is then scaled by the achievement's
-- rarity. Reads only the player's recorded earn date, so it's retroactive — it works
-- for achievements earned long before this addon was installed, with no client-side
-- stamp.

-- lib.rankFloor parsed to epoch seconds, memoised per-lib. WoW's retail launch date: an
-- earn date at or below it predates the game, can't be real, and the rank is suppressed.
-- (Dates the game back-credits to the achievement system's 2008 launch day are NOT
-- suppressed — they rank within that day's pile-up.) `false` once we've found the
-- field absent/unparseable, so we don't re-parse every call.
local function floorTime(self)
    local t = self._rankFloorTime
    if t == nil then
        local y, m, d = (self.rankFloor or ""):match("(%d+)-(%d+)-(%d+)")
        t = y and time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) }) or false
        self._rankFloorTime = t
    end
    return t or nil
end

-- Your rank-at-earn under a scope, as TWO returns:
--   1. the share (0–100) of ALL tracked accounts that earned it before you — the headline
--      metric, denominator-consistent with GetRarity (it can never exceed the rarity);
--   2. your percentile (0–100) among the achievement's earners only — the raw curve
--      position, for consumers that want to gate on "was I notably early?" (a late earner
--      of a rare achievement has a small first return but a large second one, and a line
--      built from it would only restate the rarity).
-- On suppression the first return is nil and the SECOND is the reason, so a consumer can
-- explain a missing rank without reaching into the data tables:
--   "off-snapshot" — the achievement isn't in this data file;
--   "no-curve"     — no breakpoints for this scope (too few earners for a stable
--                    percentile, or a data file without rank support);
--   "date-floor"   — the earn date is at/below rankFloor (WoW's launch): it predates
--                    the game, so it can't be real.
-- earnTime is the earn date as epoch seconds (os.time-style). Output is continuous —
-- interpolated between the ladder breakpoints — so "first 0.3%" is meaningful, not just
-- the ladder values. The caller decides display.
function lib:RankAtEarn(achievementID, earnTime, scope)
    local rarity = self:GetRarity(achievementID, scope)
    if not rarity then
        return nil, "off-snapshot"
    end
    local entry = self.ranks and self.ranks[achievementID]
    if not entry then
        return nil, "no-curve"
    end
    local offs = entry[REGION_INDEX[scopeRegion(scope)]]
    if not offs or #offs == 0 then
        return nil, "no-curve"
    end
    local floor = floorTime(self)
    if not floor then
        return nil, "no-curve"
    end
    -- Day-offset of the earn date from the floor (rounded; the curve is week-granular, so a
    -- sub-day DST wobble is immaterial). At/below the floor → impossible date → suppress.
    local days = math.floor((earnTime - floor) / 86400 + 0.5)
    if days <= 0 then
        return nil, "date-floor"
    end
    local ladder = self.rankLadder
    local n = #offs
    local earnerPct
    if days <= offs[1] then
        earnerPct = ladder[1]         -- earlier than the earliest recorded earner
    elseif days >= offs[n] then
        earnerPct = ladder[n]         -- later than the last recorded earner
    else
        for i = 1, n - 1 do
            local hi = offs[i + 1]
            if days <= hi then
                local lo = offs[i]
                local pLo, pHi = ladder[i], ladder[i + 1]
                if hi == lo then
                    earnerPct = pHi   -- a flat step (tied dates); take the higher percentile
                else
                    earnerPct = pLo + (pHi - pLo) * (days - lo) / (hi - lo)
                end
                break
            end
        end
        earnerPct = earnerPct or ladder[n]
    end
    return earnerPct * rarity / 100, earnerPct
end

--[[ Collection standing — "how rare are you": a rarity-weighted score for a player's
     whole collection, placed against the shipped distribution of the same score across
     every tracked account. The score rule: each earned achievement contributes
     -log2(its global attainment share) — "surprise" points, so every earn counts, rare
     earns count more, and no single achievement can dominate (a straight 1/share
     would be winner-take-all). The data file ships, per scope, the score at each
     lib.standingLadder percentile of tracked accounts, computed by the same producer
     over the same snapshot counts — so a score recomputed here from lib.counts lands
     on that distribution exactly. Raw layer; the tier verdict below is opinion. ]]

local LN2 = math.log(2)

-- The score contribution of one achievement (its "surprise" in bits): -log2(global
-- attainment share). Always the GLOBAL column — corpus scores are computed with one
-- weight set so they're comparable across scopes; the scope choice belongs to the
-- standing lookup, not the weights. Derived through GetRarity (the raw numeric basis
-- everything else builds on) rather than a parallel counts/denominator read, so a
-- change to the packed layout or denominator rules can never give weights a second,
-- drifting derivation. nil when there is nothing to weigh: off-snapshot, or zero
-- recorded global holders.
function lib:CollectionWeight(achievementID)
    local pct = self:GetRarity(achievementID, "global")
    if not pct or pct == 0 then
        return nil
    end
    return -math.log(pct / 100) / LN2
end

-- A player's whole-collection score: the summed CollectionWeight of every snapshot
-- achievement for which isEarned(achievementID) returns true. The loop lives here so
-- the score rule stays in one place across consumers; the earned test is a callback so
-- the library stays free of game-API calls (How Rare? passes its completed check).
-- Cold-path: one isEarned call per snapshot achievement (~8k) — commands and cards,
-- never per-event surfaces.
function lib:CollectionScore(isEarned)
    local total = 0
    for id in pairs(self.counts) do
        if isEarned(id) then
            total = total + (self:CollectionWeight(id) or 0)
        end
    end
    return total
end

-- Where a collection score stands among tracked accounts under a scope: the share
-- (0–100) of accounts whose score falls below it — "your achievements are rarer than
-- N% of accounts". Interpolated between the shipped ladder breakpoints, so the output
-- is continuous. At/above the recorded top the share is everyone-but-you (never a
-- flat 100 — you can't out-rank yourself). nil when this data file (or this scope)
-- carries no standing distribution.
function lib:CollectionStanding(score, scope)
    local region = scopeRegion(scope)
    local bps = self.standing and self.standing[REGION_INDEX[region]]
    if not bps or #bps == 0 then
        return nil
    end
    local ladder = self.standingLadder
    local n = #bps
    if score < bps[1] then
        return 0
    end
    -- The ceiling: in a finite population you can only ever out-score everyone
    -- ELSE — never 100. Applied to every exit below, including the interpolated
    -- ones: the last ladder segment's upper anchor is 100, so near-top scores
    -- would otherwise interpolate ABOVE this ceiling — reading higher than the
    -- top scorer itself and breaking monotonicity right where it matters most.
    local denom = self.accounts[region]
    local cap = (denom and denom > 1) and (100 - 100 / denom) or ladder[n]
    if score >= bps[n] then
        return cap
    end
    for i = 1, n - 1 do
        local hi = bps[i + 1]
        if score < hi then
            local lo = bps[i]
            local pLo, pHi = ladder[i], ladder[i + 1]
            if hi == lo then
                return math.min(pHi, cap) -- a flat step (tied scores); higher share
            end
            return math.min(pLo + (pHi - pLo) * (score - lo) / (hi - lo), cap)
        end
    end
    return cap -- unreachable (score < bps[n] always brackets); the safe exit
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
    -- Junk overrides the loot palette's quality-0 grey (0.62) with a LIGHTER grey:
    -- in-game testing found darker greys blend into the achievement panel's dark row
    -- background. Lighter than stock but clearly dimmer than common's white, so the
    -- bottom two tiers stay distinct.
    { name = "junk",      max = math.huge, quality = 0, color = { r = 0.75, g = 0.75, b = 0.75 } }, -- grey
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

-- The tier verdict for a whole collection — "your achievements are Epic" — banding a
-- CollectionStanding through the SAME tier scale as single achievements: the share of
-- accounts scoring at/above you plays the role the attainment share plays for one
-- achievement (top 0.1% of accounts = legendary, top 5% = epic, …). Returns the tier
-- name, the standing (the "rarer than N%" share) it was banded from, and the tier's
-- r, g, b; nil when this data file carries no standing distribution.
function lib:CollectionTier(score, scope)
    local standing = self:CollectionStanding(score, scope)
    if not standing then
        return nil
    end
    local t = tierForPct(100 - standing)
    local c = tierColor(t)
    return t.name, standing, c.r, c.g, c.b
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
