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

-- The data region a scope reads: "global" → global; an explicit region name
-- ("us"/"eu") → itself (mirroring the library's explicit-region scopes);
-- "region"/default → home. The toast's scope-region noun and the count-form
-- denominators read this; the library does its own column resolution internally.
function G.ScopeRegion(scope)
    scope = scope or G.Scope()
    if scope == "global" or scope == "us" or scope == "eu" then
        return scope
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

-- Whether an automatic surface is on: the master switch plus the surface's own
-- toggle (key: "tooltip" / "chat" / "panel" / "toast" in HowRareDB, default on).
-- Read at use-time by each surface, so flipping an option needs no re-hooking. A
-- missing key reads as on — defaults are only written at ADDON_LOADED, and
-- IsEnabled already guards the not-yet-loaded window.
function G.SurfaceOn(key)
    return G.IsEnabled() and HowRareDB[key] ~= false
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

-- Age of the loaded snapshot in whole days, or nil if the as-of date is
-- unparseable. The login line uses it to flag staleness — freshness is a rarity
-- product's core promise, so an aging embed deserves a quiet nudge toward a newer
-- release rather than silently presenting old numbers as current.
function G.SnapshotAgeDays()
    local y, m, d = SnapshotYMD()
    if not y then
        return nil
    end
    return math.max(0, math.floor((time() - time({ year = y, month = m, day = d })) / 86400))
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

-- The player's own earn date as epoch seconds, or nil when the achievement isn't
-- completed (or the id is unknown to this client build, or the date is absent). The
-- single earn-date-to-time source RankAtEarn and EarnedAgo both build on, so the
-- date extraction lives once. pcall: GetAchievementInfo hard-errors on ids unknown
-- to this client build. The year is 2-digit on some builds, full on others (mirrors
-- AchievementEarnedShort's year % 100); time{} needs a full year.
function G.AchievementEarnedTime(id)
    local ok, _, _, _, completed, month, day, year = pcall(GetAchievementInfo, id)
    if not ok or not completed or not month or month == 0 then
        return nil
    end
    local fullYear = year < 100 and (2000 + year) or year
    return time({ year = fullYear, month = month, day = day })
end

-- The player's own earn date as a rough relative span — "~3 weeks ago", "~6 months
-- ago", "~2 years ago" — or nil when not completed. Coarse by design (the chat beat
-- wants the gist, not a precise date), bucketing to days/weeks/months/years. Callers
-- pair it with RankPhrase, which already suppresses the unreliable-date floor, so
-- this doesn't re-check it. earnTime (optional) skips the re-derivation when the
-- caller already extracted the earn date — the chat filter runs per announcement,
-- so it derives once and threads it through here and RankPhrase.
function G.EarnedAgo(id, earnTime)
    earnTime = earnTime or G.AchievementEarnedTime(id)
    if not earnTime then
        return nil
    end
    local days = math.max(0, math.floor((time() - earnTime) / 86400))
    if days < 1 then
        return "~today"
    elseif days < 14 then
        return string.format("~%d day%s ago", days, days == 1 and "" or "s")
    elseif days < 56 then
        return string.format("~%d weeks ago", math.floor(days / 7))
    elseif days < 730 then
        local mo = math.floor(days / 30)
        return string.format("~%d month%s ago", mo, mo == 1 and "" or "s")
    else
        return string.format("~%d years ago", math.floor(days / 365))
    end
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

-- Fine-grained % for the surfaces that live at the rare end (the rank phrase, the
-- top list, the shift-detail view): whole percents at/above 1%, one decimal down to
-- 0.1%, "<0.1%" below. The site-convention FormatPct clamps everything under 1% to
-- "<1%" — right for browse surfaces, but it erases 1-in-110 vs 1-in-10,000 exactly
-- where this product is most interesting.
function G.FormatPctFine(pct)
    if pct >= 0.95 then
        return math.floor(pct + 0.5) .. "%"
    elseif pct >= 0.095 then
        return string.format("%.1f%%", pct)
    end
    return "<0.1%"
end

-- Display form of a standing share ("rarer than N%"): one decimal normally, two at
-- the extreme top — where a bare %.1f would round the library's never-100 ceiling
-- up to a flat "100.0%", claiming the player out-ranks themselves on the exact
-- card built to be screenshotted. The min() keeps even 99.999… at a truthful
-- "99.99%". The one formatter for every standing display (command, card, tooltip).
function G.FormatStandingPct(standing)
    if standing >= 99.95 then
        return string.format("%.2f%%", math.min(standing, 99.99))
    end
    return string.format("%.1f%%", standing)
end

-- A tier name as display copy ("epic" → "Epic") — the one owner of tier
-- capitalisation across surfaces.
function G.TierLabel(tier)
    return (tier:gsub("^%l", string.upper))
end

-- The attainment as a raw percent (0–100) under a scope (default: the user's saved
-- scope), or nil when the achievement isn't in the library's snapshot.
function G.RarityValue(achievementId, scope)
    return AR:GetRarity(achievementId, scope or G.Scope())
end

-- Your rank-at-earn for an achievement under a scope (default: the saved scope), as
-- TWO returns straight from the library: the share (0–100) of ALL tracked accounts
-- that earned it before you (the headline number — same denominator as the rarity %,
-- so the two read consistently side by side), and your percentile among its earners
-- only (the gate signal: were you notably early?). nil when not completed; on a
-- library suppression the second return is the library's reason ("off-snapshot" /
-- "no-curve" / "date-floor" — /howrare why reads it). Reads the player's OWN recorded
-- earn date (via AchievementEarnedTime, or the optional pre-derived earnTime), so
-- it's retroactive — it works for achievements earned long before How Rare? was
-- installed. The library owns the interpolation + floor; this just sources the date.
-- (Raw values; the formatted brag is RankPhrase.)
function G.RankAtEarn(achievementId, scope, earnTime)
    earnTime = earnTime or G.AchievementEarnedTime(achievementId)
    if not earnTime then
        return nil
    end
    return AR:RankAtEarn(achievementId, earnTime, scope or G.Scope())
end

-- The rank line's job is to say something the rarity line doesn't already say. For a
-- late earner the two collapse — the last earner's "first N%" IS the rarity — so the
-- phrase only shows when you were earlier than this share of the achievement's
-- earners. A redundancy gate, not an embarrassment gate: since the metric is measured
-- against all accounts it is always honest; late earns just add nothing. Exposed on G
-- so the /howrare why report can explain a suppression with the real number.
G.RANK_EARLY_MAX = 75

-- Below this many accounts, a figure reads better as the count than as a share —
-- "one of ~830" / "first ~2,300" land where "1%" / "first 0.3%" flatten. ONE knob
-- drives every count form (the tooltip's "(one of ~N)" parenthetical, RankPhrase's
-- absolute form, and the toast's "One of only ~N people" line) so the "small club"
-- boundaries can't drift apart. A saved option (HowRareDB.countFormMax, the options
-- dropdown): the default 2,500 keeps counts special — a genuinely small club — and
-- 0 turns count forms off. Defensive pre-load fallback, like the other option reads.
local COUNT_FORM_DEFAULT = 2500
function G.CountFormMax()
    local v = HowRareDB and HowRareDB.countFormMax
    return type(v) == "number" and v or COUNT_FORM_DEFAULT
end

-- The share (0–100) of a scope's tracked accounts, as the account count it stands
-- for (min 1 — a rounded 0 would read as nobody). The absolute form of any
-- percentage under the same denominators the library's figures use; RankPhrase and
-- /howrare why read it.
function G.CountForPct(pct, scope)
    local denom = AR:GetMeta().accounts[G.ScopeRegion(scope)]
    return math.max(1, math.floor(pct / 100 * denom + 0.5))
end

-- The rank-at-earn brag as a ready phrase — or nil when there's no usable rank
-- (RankAtEarn nil) or you weren't notably early among the achievement's earners
-- (RANK_EARLY_MAX). The one shared wording + threshold source: every surface
-- composes its line from this ("you were in the <phrase> to earn this", "· <phrase>"),
-- so the phrasing and the gates can't drift between tooltip, chat, and toast. Two
-- forms, split at CountFormMax accounts-before-you: a small club reads as the
-- count ("first ~2,300" — lands harder than a sliver of a percent), a big one as the
-- share ("first 3%"; fine-formatted — rank shares live at the rare end, where "<1%"
-- would flatten real differences). earnTime (optional) threads a caller's
-- already-derived earn date through, like EarnedAgo.
-- Besides the phrase, the count form also returns its pieces around the "~"
-- (pre, post) so a typography-conscious consumer (the toast's nudged tilde) can
-- compose structurally instead of parsing the rendered string — a wording edit
-- here can then never silently break the card's tilde alignment. The percent
-- form returns just the phrase.
function G.RankPhrase(achievementId, scope, earnTime)
    local pct, earnerPct = G.RankAtEarn(achievementId, scope, earnTime)
    if not pct or earnerPct > G.RANK_EARLY_MAX then
        return nil
    end
    local before = G.CountForPct(pct, scope)
    if before < G.CountFormMax() then
        local n = BreakUpLargeNumbers(before)
        return "first ~" .. n, "first ", n
    end
    return "first " .. G.FormatPctFine(pct)
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

-- r,g,b (0–1) as a "rrggbb" hex for inline |cff..|r colouring — the one conversion,
-- so inline-string and SetTextColor paths of the same colour stay byte-identical.
function G.RGBHex(r, g, b)
    return string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- "rrggbb" hex of an achievement's tier colour; brand gold when off-snapshot.
function G.RarityHex(achievementId, scope)
    local r, g, b = AR:GetColor(achievementId, scope or G.Scope())
    if not r then
        return GOLD_HEX
    end
    return G.RGBHex(r, g, b)
end

-- "EU accounts" / "accounts worldwide" — the scope-region population noun a sentence
-- ends on, following the user's chosen scope like every figure. Shared by the toast's
-- rarity line, the standing card/command, and the outbound Gz! reply.
function G.ScopeNoun(noun, scope)
    local region = G.ScopeRegion(scope)
    return region == "global" and (noun .. " worldwide") or (region:upper() .. " " .. noun)
end

-- Your whole-collection verdict, from the library under the saved scope: the
-- collection score (surprise points over the shipped snapshot), and — when this
-- snapshot ships a standing distribution — the tier verdict ("epic"), the standing
-- (rarer than N% of tracked accounts), and the tier colour. tier is nil (score
-- still returned) on a data file without standing.
--
-- CACHED: the underlying scan (one completion check per ~8k snapshot achievements)
-- is far too heavy to repeat per surface, and three surfaces read the verdict
-- (/howrare me, the standing card, the character-sheet row). Keyed by scope — the
-- score is scope-blind but the standing/tier are not. Invalidated on
-- ACHIEVEMENT_EARNED by CharacterSheet's event frame (the addon's one earn
-- listener for verdict state) via InvalidateCollectionVerdict.
local verdictCache = {}
function G.CollectionVerdict(scope)
    scope = scope or G.Scope()
    local v = verdictCache[scope]
    if not v then
        local score = AR:CollectionScore(G.SelfCompleted)
        v = { score, AR:CollectionTier(score, scope) }
        verdictCache[scope] = v
    end
    return v[1], v[2], v[3], v[4], v[5], v[6]
end

function G.InvalidateCollectionVerdict()
    wipe(verdictCache)
end

-- The one-line score explainer, shared verbatim by /howrare me and the
-- character-sheet tooltip so the two can't drift.
G.SCORE_NOTE = "every earned achievement adds points for how surprising it is to hold; rare earns add more."

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

-- Whether a tier NAME is "rare or rarer" — the addon's ONE judgment of notability
-- (worth an auto-screenshot, worth the tier-tinted flourish, worth the Gz! rarity
-- beat), held in a single predicate so no consumer can drift. Name-level so both
-- id-keyed callers (via IsRareTier) and verdict-keyed ones (the standing card)
-- share the same boundary.
function G.IsRareTierName(tier)
    return tier == "legendary" or tier == "epic" or tier == "rare"
end

-- The id-keyed form: resolves the achievement's tier, then applies the one
-- boundary above. Returns the tier as a second value for callers that need it.
function G.IsRareTier(achievementId, scope)
    local tier = G.RarityTier(achievementId, scope)
    return G.IsRareTierName(tier), tier
end

-- Whether an earn/preview of this achievement should auto-screenshot, per the
-- screenshot mode (HowRareDB.screenshot): "all" shoots every toast, "rare" only the
-- rare-and-rarer tiers (IsRareTier — captures the brag shots without filling the
-- folder), "off" never. The explicit share action bypasses this — asking for a
-- share IS asking for the capture.
function G.ScreenshotWanted(achievementId)
    local mode = HowRareDB and HowRareDB.screenshot
    if mode == "all" then
        return true
    end
    if mode == "rare" then
        return (G.IsRareTier(achievementId))
    end
    return false
end

-- Every earned achievement in the shipped snapshot with its rarity, sorted
-- rarest-first ({ id, val } records). The ONE snapshot-wide earned scan — the share
-- path reads [1], /howrare top prints the head, the showcase pin walks it for the
-- best card — so the enumerate-filter loop lives once instead of three near-copies.
-- Cold-path only: the full scan pcalls completion for every rarity-bearing id, fine
-- for commands and debug tools, never for per-event surfaces.
function G.EarnedRarities(scope)
    local earned = {}
    for id in pairs(AR:GetData()) do
        local val = G.RarityValue(id, scope)
        if val and G.SelfCompleted(id) then
            earned[#earned + 1] = { id = id, val = val }
        end
    end
    table.sort(earned, function(a, b)
        return a.val < b.val
    end)
    return earned
end

-- Your rarest *earned* achievement — EarnedRarities' head. Returns
-- (name, formattedPct, id), or nil when none of your earned achievements are in
-- the snapshot. The id lets callers tint the line by its rarity tier. Shared by
-- the share keybind and the showcase toast.
function G.RarestEarned(scope)
    local e = G.EarnedRarities(scope)[1]
    if not e then
        return nil
    end
    local name = G.AchievementInfo(e.id)
    return name, G.FormatPct(e.val), e.id
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
