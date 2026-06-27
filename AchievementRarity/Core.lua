-- Core.lua — shared namespace: region resolution, rarity lookup, formatting.
-- Formatting mirrors the gratz.gg site: whole percents at/above 1%, "<1%" below —
-- same numbers, same formatting, both sides.
local _, G = ...

AchievementRarity = G -- global handle for /dump debugging

-- The player's rarity denominator: own region for US/EU, global for everyone
-- else (kr/tw/cn) — mirrors the site's standingRegionFor.
local REGION_BY_ID = { [1] = "us", [3] = "eu" }
G.region = REGION_BY_ID[GetCurrentRegion()] or "global"

-- Index into the packed {us, eu, global} count triples in Data/Rarity.lua.
local REGION_INDEX = { us = 1, eu = 2, global = 3 }
G.regionIndex = REGION_INDEX[G.region]

G.BRAND = "gratz.gg"

-- The addon-wide master switch (the "Achievement Rarity enabled" option). Off
-- silences every automatic surface — tooltip / chat / panel rarity and the earned
-- toast. Defensive against a not-yet-loaded saved-vars table (treated as off until
-- ADDON_LOADED applies the default), mirroring the per-feature gates. Default on
-- once loaded.
function G.IsEnabled()
    return AchievementRarityDB ~= nil and AchievementRarityDB.enabled ~= false
end

-- pcall: GetAchievementInfo hard-errors on ids unknown to this client build (the
-- shipped rarity ids come from the web API, which can run ahead of the client); a
-- stray id must degrade at the call site, never error. Nil name = unknown.
function G.AchievementInfo(id)
    local ok, _, name, points, completed, _, _, _, _, _, icon = pcall(GetAchievementInfo, id)
    if not ok then
        return nil
    end
    return name, points, completed, icon
end

-- Whether the player has completed an achievement (account-wide flag). The
-- completion test "rarest earned" sums over.
function G.SelfCompleted(id)
    local _, _, completed = G.AchievementInfo(id)
    return completed
end

-- Verbose diagnostics, persisted via /rarity debug. Cheap when off; callers pay
-- only the call. Errors are NOT routed here — enable them with
-- /console scriptErrors 1 (or BugSack).
function G.Debug(...)
    if AchievementRarityDB and AchievementRarityDB.debug then
        print("|cffff7700Achievement Rarity dbg:|r", ...)
    end
end

-- The snapshot date as an exact "11 June 2026", parsed from the ISO date the
-- data file ships — one precise form everywhere. Memoised; falls back to the raw
-- ISO string if it can't be parsed.
local MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}
local ABBR_MONTHS = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}
-- Parse the snapshot's ISO date once into y, m, d numbers (nil if unparseable),
-- so the long and short formatters below share a single parse of G.Meta.asOf.
local parsedY, parsedM, parsedD, parsed
local function SnapshotYMD()
    if not parsed then
        parsed = true
        local y, m, d = (G.Meta.asOf or ""):match("(%d+)-(%d+)-(%d+)")
        parsedY, parsedM, parsedD = tonumber(y), tonumber(m), tonumber(d)
    end
    return parsedY, parsedM, parsedD
end

local asOfLong
function G.AsOfLong()
    if asOfLong then
        return asOfLong
    end
    local y, m, d = SnapshotYMD()
    if y and MONTHS[m] then
        asOfLong = string.format("%d %s %d", d, MONTHS[m], y)
    else
        asOfLong = G.Meta.asOf or ""
    end
    return asOfLong
end

-- The snapshot date in the compact "Jun 26" form (abbreviated month + 2-digit
-- year) the toast uses to mark its rarity as current — a shareable card wants the
-- month, not a precise day. Memoised; falls back to the raw ISO string.
local asOfShort
function G.AsOfShort()
    if asOfShort then
        return asOfShort
    end
    local y, m = SnapshotYMD()
    if y and ABBR_MONTHS[m] then
        asOfShort = string.format("%s %02d", ABBR_MONTHS[m], y % 100)
    else
        asOfShort = G.Meta.asOf or ""
    end
    return asOfShort
end

-- The date an achievement was earned, as "18 Jun 26", or nil if it isn't
-- completed (or is unknown to this client build). The client records the real
-- completion date, so this is the true earn date even for an achievement earned
-- long before the current rarity snapshot — letting the toast separate when you
-- earned it from when the rarity was measured. year % 100 is encoding-agnostic
-- (the field is a 2-digit year on some builds, a full year on others).
function G.AchievementEarnedShort(id)
    local ok, _, _, _, completed, month, day, year = pcall(GetAchievementInfo, id)
    if not ok or not completed or not month or month == 0 then
        return nil
    end
    local m = ABBR_MONTHS[month]
    if not m then
        return nil
    end
    return string.format("%d %s %02d", day, m, year % 100)
end

-- The standard attributed rarity line — every tooltip surface renders this
-- exact string, so the wording can't drift between them.
function G.RarityLine(rarity)
    return string.format("Rarity: %s of active accounts — %s (%s)",
        rarity, G.BRAND, G.AsOfLong())
end

-- Run a callback once Blizzard_AchievementUI is available. It's
-- load-on-demand: possibly already in (another addon, e.g. KAF, can force
-- it), otherwise arriving on the panel's first open.
function G.OnAchievementUILoaded(callback)
    if C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        callback()
        return
    end
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, loadedName)
        if loadedName ~= "Blizzard_AchievementUI" then
            return
        end
        self:UnregisterEvent("ADDON_LOADED")
        callback()
    end)
end

-- No false precision: whole-% at/above 1%, "<1%" below. pct is 0–100.
function G.FormatPct(pct)
    if pct < 1 then
        return "<1%"
    end
    return math.floor(pct + 0.5) .. "%"
end

-- The player's region attainment as a raw percent (0–100), or nil when the
-- achievement isn't in the shipped snapshot. The numeric basis for both the
-- formatted line and the achievement-panel row paint — one source so they can't drift.
function G.RarityValue(achievementId)
    local counts = G.RarityCounts[achievementId]
    if not counts then
        return nil
    end
    local denom = G.Meta.accounts[G.region]
    if not denom or denom == 0 then
        return nil
    end
    return counts[G.regionIndex] / denom * 100
end

-- Formatted attainment ("3%", "<1%") for the player's region, or nil when the
-- achievement isn't in the shipped snapshot (newer than the data files).
function G.RarityFor(achievementId)
    local pct = G.RarityValue(achievementId)
    if not pct then
        return nil
    end
    return G.FormatPct(pct)
end

-- Rarity as a WoW item-quality colour, so rarity reads at a glance the way loot
-- does: the rarer the achievement, the higher the quality band. Bands by region
-- attainment — under 1% legendary, under 5% epic, under 15% rare, under 40%
-- uncommon, else common. Achievements outside the rarity snapshot fall back to
-- the brand gold below.
-- The one brand gold (ffd100): the gratz.gg watermark / attribution colour, and
-- the fallback tint for rarity outside the snapshot.
G.GOLD = { 1, 0.82, 0 }

local function QualityForPct(pct)
    if pct < 1 then return 5 end   -- legendary (orange)
    if pct < 5 then return 4 end   -- epic (purple)
    if pct < 15 then return 3 end  -- rare (blue)
    if pct < 40 then return 2 end  -- uncommon (green)
    return 1                       -- common (white)
end

-- The brand gold as a "rrggbb" hex, derived from G.GOLD so the two can't drift —
-- the off-snapshot fallback for RarityHex.
local GOLD_HEX = string.format("%02x%02x%02x",
    math.floor(G.GOLD[1] * 255 + 0.5), math.floor(G.GOLD[2] * 255 + 0.5), math.floor(G.GOLD[3] * 255 + 0.5))

-- The pct and the ITEM_QUALITY_COLORS entry for an achievement's rarity tier, or
-- nil when it's outside the shipped snapshot. One place for the band → quality
-- mapping; the three public helpers below just shape its output.
local function rarityQuality(achievementId)
    local pct = G.RarityValue(achievementId)
    if not pct then
        return nil
    end
    return pct, ITEM_QUALITY_COLORS[QualityForPct(pct)]
end

-- r, g, b (0–1) for an achievement's rarity tier; brand gold when off-snapshot.
function G.RarityColor(achievementId)
    local _, c = rarityQuality(achievementId)
    if not c then
        return G.GOLD[1], G.GOLD[2], G.GOLD[3]
    end
    return c.r, c.g, c.b
end

-- "rrggbb" hex of the same tier colour, for inline |cff..|r colouring in strings.
-- Built from the same r,g,b RarityColor uses — not sliced from the engine's own
-- .hex, whose markup form varies by client ("ffRRGGBB" vs "|cffRRGGBB", the latter
-- leaving stray chars after a fixed sub) — so the inline and SetTextColor paths
-- stay byte-identical; brand gold when off-snapshot.
function G.RarityHex(achievementId)
    local _, c = rarityQuality(achievementId)
    if not c then
        return GOLD_HEX
    end
    return string.format("%02x%02x%02x",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- One lookup, both outputs a list row needs: the formatted attainment string (or
-- nil, off-snapshot) and the tier colour r, g, b. Saves calling RarityFor and
-- RarityColor separately on the same id per row.
function G.RarityTextAndColor(achievementId)
    local pct, c = rarityQuality(achievementId)
    if not c then
        return nil, G.GOLD[1], G.GOLD[2], G.GOLD[3]
    end
    return G.FormatPct(pct), c.r, c.g, c.b
end

-- Your rarest *earned* achievement across the whole shipped rarity snapshot: of
-- every achievement gratz.gg ships a rarity for that you've completed, the one
-- with the lowest region attainment. Returns (name, formattedPct, id), or nil when
-- none of your earned achievements are in the snapshot. The id lets callers tint
-- the line by its rarity tier. Shared by the share keybind and the showcase toast.
-- SelfCompleted (a pcall'd GetAchievementInfo) is only tested when an id's rarity
-- beats the current best, so the per-id cost is a cheap table lookup and the
-- completion calls are bounded to genuine improvements, not the whole snapshot.
function G.RarestEarned()
    local rarestId, rarestVal
    for id in pairs(G.RarityCounts) do
        local val = G.RarityValue(id)
        if val and (not rarestVal or val < rarestVal) and G.SelfCompleted(id) then
            rarestVal, rarestId = val, id
        end
    end
    if not rarestId then
        return nil
    end
    local name = G.AchievementInfo(rarestId)
    return name, G.FormatPct(rarestVal), rarestId
end

-- Movable-frame position persistence — one saved shape ({point, relPoint,
-- x, y} in AchievementRarityDB[key]) for every draggable frame (today: the toast).
function G.SavePoint(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    AchievementRarityDB[key] = { point = point, relPoint = relPoint, x = x, y = y }
end

-- Make `frame` drag-to-move (left button) and persist its point under
-- AchievementRarityDB[key] in the SavePoint shape. Clamped to screen so a frame
-- can't be dragged off an edge and lost. The `dragging` flag it sets lets a frame
-- that is also clickable tell a drag-release from a click in its own handler.
function G.MakeDraggable(frame, key)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        G.SavePoint(self, key)
    end)
end
