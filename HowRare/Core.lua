-- Core.lua — shared namespace: region resolution, rarity lookup, formatting.
-- Formatting mirrors the website: whole percents at/above 1%, "<1%" below —
-- same numbers, same formatting, both sides.
local _, G = ...

HowRare = G -- global handle for /dump debugging

-- The rarity data + the loot-quality tier opinion now live in the embedded
-- AchievementRarity library; How Rare? is its reference consumer. Core keeps the
-- same G.* helper names every surface already calls, but their bodies delegate to
-- the library — one source of truth, and a fresher standalone copy can supersede
-- the embedded one at runtime, so we hold the stable lib handle and call it live,
-- never caching its data. Loaded before Core via the Libs block in the .toc.
local AR = assert(LibStub and LibStub:GetLibrary("AchievementRarity-1.0", true),
    "How Rare? needs the embedded AchievementRarity-1.0 library loaded first (Libs before Core in the .toc)")
G.AR = AR

-- The player's home region (own region for US/EU, "global" for kr/tw/cn) — the
-- library resolves it the way the site's standingRegionFor does. Stable, so read
-- once; "global" scope always reads the global column.
G.region = AR:GetMeta().region

-- Rarity scope: "region" (the player's home region, default) or "global". A saved
-- option (Options.lua); every rarity surface and the public API read it through
-- G.Scope(), and the API also accepts a per-call override. Defensive against a
-- not-yet-loaded saved-vars table (treated as the region default until loaded).
function G.Scope()
    return (HowRareDB and HowRareDB.scope == "global") and "global" or "region"
end

-- The data region a scope reads: "global" → global; "region"/default → home.
-- The toast's scope-region noun reads this; the library does its own column
-- resolution internally, so there's no ScopeIndex here any more.
function G.ScopeRegion(scope)
    if (scope or G.Scope()) == "global" then
        return "global"
    end
    return G.region
end

-- The addon-wide master switch (the "How Rare? enabled" option). Off
-- silences every automatic surface — tooltip / chat / panel rarity and the earned
-- toast. Defensive against a not-yet-loaded saved-vars table (treated as off until
-- ADDON_LOADED applies the default), mirroring the per-feature gates. Default on
-- once loaded.
function G.IsEnabled()
    return HowRareDB ~= nil and HowRareDB.enabled ~= false
end

-- True when the user's chosen click-to-preview modifier (HowRareDB.previewModifier:
-- "alt"/"ctrl", or "off") is the only modifier held — isolating the gesture from
-- Blizzard's own modified-clicks (shift links an achievement into chat). Shared by
-- the panel-row click intercept (AchievementUI) and the chat-link one (Chat).
function G.PreviewModifierHeld()
    local mod = HowRareDB and HowRareDB.previewModifier
    if mod == "alt" then
        return IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown()
    elseif mod == "ctrl" then
        return IsControlKeyDown() and not IsAltKeyDown() and not IsShiftKeyDown()
    end
    return false
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

-- Verbose diagnostics, persisted via /howrare debug. Cheap when off; callers pay
-- only the call. Errors are NOT routed here — enable them with
-- /console scriptErrors 1 (or BugSack).
function G.Debug(...)
    if HowRareDB and HowRareDB.debug then
        print("|cffff7700How Rare? dbg:|r", ...)
    end
end

-- Branded chat line: the gold "How Rare?" prefix every player-facing print shares,
-- so the brand can't drift across call sites. (Diagnostics use G.Debug.)
function G.Print(msg)
    print("|cffffd100How Rare?|r " .. msg)
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
-- Parse the snapshot's ISO date into y, m, d numbers (nil if unparseable). Read
-- live from the library's meta each call rather than memoised: a fresher standalone
-- copy can supersede the embedded snapshot at runtime, and the parse is cheap on
-- the cold paths this serves (login line / options page / per-toast stamp).
local function SnapshotYMD()
    local y, m, d = (AR:GetMeta().asOf or ""):match("(%d+)-(%d+)-(%d+)")
    return tonumber(y), tonumber(m), tonumber(d)
end

function G.AsOfLong()
    local y, m, d = SnapshotYMD()
    if y and MONTHS[m] then
        return string.format("%d %s %d", d, MONTHS[m], y)
    end
    return AR:GetMeta().asOf or ""
end

-- The snapshot date in the compact "Jun 26" form (abbreviated month + 2-digit
-- year) the toast uses to mark its rarity as current — a shareable card wants the
-- month, not a precise day. Falls back to the raw ISO string.
function G.AsOfShort()
    local y, m = SnapshotYMD()
    if y and ABBR_MONTHS[m] then
        return string.format("%s %02d", ABBR_MONTHS[m], y % 100)
    end
    return AR:GetMeta().asOf or ""
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

-- The rarity line's "Rarity:" label ink — white, so only the % carries the tier
-- colour. White (not a brand colour): the label is just the noun, and the tooltip
-- stays a neutral functional surface. Matches Chat.lua's enrichment.
local LABEL_HEX = "ffffff"

-- The standard rarity line — every tooltip surface renders this exact string, so
-- the wording AND its colour treatment can't drift between them. Two inks: the
-- "Rarity:" label white, the % in its rarity-tier colour, so the eye lands on
-- the number. The "of active accounts" qualifier and the snapshot date live on the
-- options page, not on every hover. Callers AddLine this with a neutral (white)
-- base; each run carries its own |cff..|r, so the base shows only on an uncoloured run.
function G.RarityLine(rarity, achievementId, scope)
    local hex = G.RarityHex(achievementId, scope)
    return string.format("|cff%sRarity:|r |cff%s%s|r", LABEL_HEX, hex, rarity)
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

-- The rarity helpers below delegate to the library. Each defaults an unspecified
-- scope to the user's saved option (G.Scope()) — the same default every surface has
-- always used — then hands the library an explicit "region"/"global". The
-- off-snapshot fallback (brand gold) is How Rare?'s own; the library returns nil.

-- No false precision: whole-% at/above 1%, "<1%" below. pct is 0–100.
function G.FormatPct(pct)
    return AR:FormatPct(pct)
end

-- The attainment as a raw percent (0–100) under a scope (default: the user's saved
-- scope), or nil when the achievement isn't in the library's snapshot.
function G.RarityValue(achievementId, scope)
    return AR:GetRarity(achievementId, scope or G.Scope())
end

-- Your rank-at-earn percentile (0–100) for an achievement under a scope (default: the
-- saved scope) — "you were in the first N% of holders to earn this" — or nil when not
-- completed, off-snapshot, below the scope's holder floor, or the recorded earn date is
-- unreliable (at/below the system-launch floor; the library suppresses it). Reads the
-- player's OWN recorded earn date (month/day/year from GetAchievementInfo, like
-- AchievementEarnedShort), so it's retroactive — it works for achievements earned long
-- before How Rare? was installed. pcall: GetAchievementInfo hard-errors on ids unknown to
-- this client build. The library owns the interpolation + floor; this just sources the
-- date. (Wording/surfacing is a later track — this is the value, unformatted.)
function G.RankAtEarn(achievementId, scope)
    local ok, _, _, _, completed, month, day, year = pcall(GetAchievementInfo, achievementId)
    if not ok or not completed or not month or month == 0 then
        return nil
    end
    -- GetAchievementInfo's year is 2-digit on some builds, full on others (mirrors
    -- AchievementEarnedShort's year % 100); time{} needs a full year.
    local fullYear = year < 100 and (2000 + year) or year
    local earnTime = time({ year = fullYear, month = month, day = day })
    return AR:RankAtEarn(achievementId, earnTime, scope or G.Scope())
end

-- Formatted attainment ("3%", "<1%") under a scope, or nil off-snapshot.
function G.RarityFor(achievementId, scope)
    return AR:Format(achievementId, scope or G.Scope())
end

-- The one brand gold (ffd100): the toast points-shield number, and the fallback
-- tint for rarity outside the library's snapshot. The loot-quality tier palette
-- itself now lives in the library (AR:GetColor / AR:GetTier / AR:GetTiers); this
-- gold is the product's own off-snapshot choice, so it stays here, not in the lib.
G.GOLD = { 1, 0.82, 0 }

-- The brand gold as a "rrggbb" hex, derived from G.GOLD so the two can't drift —
-- the off-snapshot fallback for RarityHex.
local GOLD_HEX = string.format("%02x%02x%02x",
    math.floor(G.GOLD[1] * 255 + 0.5), math.floor(G.GOLD[2] * 255 + 0.5), math.floor(G.GOLD[3] * 255 + 0.5))

-- The tier name ("legendary".."junk") for an achievement under a scope, or nil
-- off-snapshot. Backs the API's GetTier.
function G.RarityTier(achievementId, scope)
    return AR:GetTier(achievementId, scope or G.Scope())
end

-- r, g, b (0–1) for an achievement's rarity tier; brand gold when off-snapshot.
function G.RarityColor(achievementId, scope)
    local r, g, b = AR:GetColor(achievementId, scope or G.Scope())
    if not r then
        return G.GOLD[1], G.GOLD[2], G.GOLD[3]
    end
    return r, g, b
end

-- "rrggbb" hex of the same tier colour, for inline |cff..|r colouring in strings;
-- brand gold when off-snapshot. Built from the same r,g,b RarityColor uses, so the
-- inline and SetTextColor paths stay byte-identical.
function G.RarityHex(achievementId, scope)
    local r, g, b = AR:GetColor(achievementId, scope or G.Scope())
    if not r then
        return GOLD_HEX
    end
    return string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- One lookup, both outputs a list row needs: the formatted attainment string (or
-- nil, off-snapshot) and the tier colour r, g, b (brand gold off-snapshot). Saves
-- calling RarityFor and RarityColor separately on the same id per row.
function G.RarityTextAndColor(achievementId, scope)
    scope = scope or G.Scope()
    local text = AR:Format(achievementId, scope)
    local r, g, b = AR:GetColor(achievementId, scope)
    if not r then
        return text, G.GOLD[1], G.GOLD[2], G.GOLD[3]
    end
    return text, r, g, b
end

-- Your rarest *earned* achievement across the whole shipped rarity snapshot: of
-- every achievement the Wizzleworks ships a rarity for that you've completed, the one
-- with the lowest region attainment. Returns (name, formattedPct, id), or nil when
-- none of your earned achievements are in the snapshot. The id lets callers tint
-- the line by its rarity tier. Shared by the share keybind and the showcase toast.
-- SelfCompleted (a pcall'd GetAchievementInfo) is only tested when an id's rarity
-- beats the current best, so the per-id cost is a cheap table lookup and the
-- completion calls are bounded to genuine improvements, not the whole snapshot.
function G.RarestEarned(scope)
    local rarestId, rarestVal
    for id in pairs(AR:GetData()) do
        local val = G.RarityValue(id, scope)
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
-- x, y} in HowRareDB[key]) for every draggable frame (today: the toast).
function G.SavePoint(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    HowRareDB[key] = { point = point, relPoint = relPoint, x = x, y = y }
end

-- Make `frame` drag-to-move (left button) and persist its point under
-- HowRareDB[key] in the SavePoint shape. Clamped to screen so a frame
-- can't be dragged off an edge and lost.
function G.MakeDraggable(frame, key)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        G.SavePoint(self, key)
    end)
end
