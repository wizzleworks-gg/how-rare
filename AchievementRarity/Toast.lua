-- Toast.lua — the achievement-earned toast: achievement + points + rarity, styled
-- to be screenshotted. REPLACES Blizzard's own achievement alert (suppressed while
-- this is on) and shows in the bottom alert area, one at a time. Centre-screen
-- collided too often with Blizzard's error/zone/boss text, and a second toast
-- beside Blizzard's in the same spot would only duplicate — ours is a superset, so
-- for this one surface we replace rather than augment.
local _, G = ...

-- Blizzard's own achievement-alert timing, kept so the toast feels native: hold
-- 4.05s, then fade over 1.5s (~5.5s on screen).
local TOAST_SECONDS = 4.05
local FADE_SECONDS = 1.5
-- Delay from a toast appearing to the screenshot — long enough for the glow/sweep
-- flourish to finish (it runs ~1s) so the card is caught settled at full opacity,
-- not washed out mid-effect. Still well inside the 4.05s hold before it fades.
local SHOT_DELAY = 1.5

-- One toast at a time (we replace Blizzard's alert rather than sit beside it, so
-- there's no 2-up to mirror); the rest queue and pump in as it frees. The pool and
-- queue stay general, so the visible count is just MAX_VISIBLE.
local MAX_VISIBLE = 1
local TOAST_W, TOAST_H = 380, 100
local ICON = 50
-- Card insets the name column is measured against. Named so the anchor SetPoints and
-- NAME_AVAIL (which FitName measures against) share one source and can't drift: the
-- icon's left inset, the gap from icon to the name column, and the text/brand inset
-- from the right edge.
local ICON_INSET = 14
local NAME_GAP = 12
local EDGE_INSET = 14
-- Gold achievement icon-frame ring + points shield, both reused from Blizzard's
-- achievement art so the icon reads as native achievement loot, not a bare square.
-- Ring 1.25x the icon (Blizzard's own 72-over-58 ratio, so its inner hole hugs the
-- icon edge — derived from ICON so the two can't drift); shield a small upper-right
-- badge.
local ICON_RING = math.floor(ICON * 1.25)
local SHIELD_W, SHIELD_H = 36, 38
-- Points number a point smaller than GameFontNormalSmall's 10 so two digits don't
-- crowd the shrunk shield.
local POINTS_PT = 9
-- Even gap between the three text rows (name / rarity / earn time).
local LINE_GAP = 5
-- The approximate "~" drops this many px so it reads centred against the digits
-- instead of floating at the top (its font glyph sits high). Scaled for the
-- rarity row's GameFontNormal (one notch up from the metadata rows).
local TILDE_NUDGE = 4
local GAP = 16
-- Default toast spot when the player hasn't moved it (the mover overrides it via
-- AchievementRarityDB.toastPos): top-left of the screen, inset from the corner.
-- These three values are the whole default, so they're easy to tune.
local DEFAULT_POINT = "TOPLEFT"
local DEFAULT_X, DEFAULT_Y = 16, -200

-- The name auto-shrinks from NAME_MAX_PT (GameFontHighlightLarge's 16) down toward
-- NAME_MIN_PT to keep a long achievement name — the thing being celebrated — whole
-- on one line before the engine's ellipsis truncation has to kick in. Below the
-- floor it truncates as before. NAME_AVAIL is the name column's width, derived from
-- the same inset constants the name's anchors use (left edge = icon inset + icon +
-- gap; right edge = frame right − edge inset).
local NAME_MAX_PT = 16
local NAME_MIN_PT = 13
local NAME_AVAIL = TOAST_W - ICON_INSET - ICON - NAME_GAP - EDGE_INSET

-- The celebratory glint (shine) is SHINE_W wide and sweeps left→right, fully inside
-- the card and symmetric: its left edge starts SHINE_MARGIN in from the card's left
-- edge and its right edge ends SHINE_MARGIN in from the right. SHINE_MARGIN = 0 is
-- edge-to-edge — the longest a symmetric sweep can be without either end hanging off
-- the card. Raise it for a visible inside gap at both ends (which shortens the
-- sweep). The setup below derives the start anchor (SHINE_MARGIN) and the travel
-- (TOAST_W - SHINE_W - 2*SHINE_MARGIN) from it, so one number moves both ends.
local SHINE_W = 60
local SHINE_MARGIN = 0

-- Reused Blizzard achievement-toast art (the same atlas its own alert draws from):
-- a radial glow and a vertical shine, so our flourish reads as the same
-- celebration rather than a competing one.
local TOAST_ART = "Interface\\AchievementFrame\\AchievementToast"

-- Below this region attainment the rarity line reads as a population count ("one
-- of only ~N players") — which lands harder than a sub-1% figure on a rare earn;
-- at or above it, the percentage (a count in the millions is no brag).
local COUNT_BELOW_PCT = 5

local PumpQueue -- forward declaration (the release closure calls it before it's defined)

-- One pooled toast frame: framed icon + points badge + header/name/rarity + a
-- footer row (earn time · provenance) + the fade timer + the optional glow/sweep.
-- The fader finishing (or a click) frees the slot and pumps the next queued id in.
local function CreateToastFrame(index)
    local f = CreateFrame("Button", "AchievementRarityToast" .. index, UIParent, "BackdropTemplate")
    f:SetSize(TOAST_W, TOAST_H)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(ICON, ICON)
    f.icon:SetPoint("LEFT", ICON_INSET, 0)

    -- Blizzard's gold achievement icon-frame ring around the icon, so it reads as
    -- native achievement art rather than a bare square. Inner hole sized to hug the
    -- icon edge; drawn above the icon (OVERLAY) but below the shield.
    f.iconFrame = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.iconFrame:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    f.iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625)
    f.iconFrame:SetSize(ICON_RING, ICON_RING)
    f.iconFrame:SetPoint("CENTER", f.icon, "CENTER", -1, 1)

    -- Achievement points on Blizzard's gold shield, as a badge on the icon's upper-
    -- right — the native "this many points" glyph every WoW player already parses,
    -- so the number can't be misread as a rank or level (which a bare number under
    -- the icon was). Earned-shield texcoords. Seated onto the icon corner: pulled in
    -- (-7) so it clears the name beside it and down (-6) so it doesn't clip the frame
    -- top. Shield + number both hidden for 0-point achievements (Populate decides).
    -- Drawn above the ring; the number above the shield. Offsets are eyeball-tuned.
    f.shield = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.shield:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
    f.shield:SetTexCoord(0, 0.5, 0, 0.45)
    f.shield:SetSize(SHIELD_W, SHIELD_H)
    f.shield:SetPoint("CENTER", f.icon, "TOPRIGHT", -7, -6)

    -- Points number centred on the shield's number plate, sized POINTS_PT (same font
    -- path/flags — size only, so the locale font and shadow hold).
    f.points = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.points:SetDrawLayer("OVERLAY", 3)
    local pf, _, pflags = f.points:GetFont()
    f.points:SetFont(pf, POINTS_PT, pflags)
    f.points:SetPoint("CENTER", f.shield, "CENTER", 0, 0)
    f.points:SetTextColor(unpack(G.GOLD))

    -- Three rows beside the icon — name, rarity, earn time — stacked from the icon's
    -- top and evenly spaced by LINE_GAP. The name (the hero) takes the earn's
    -- rarity-tier colour the way a WoW item name does (Populate sets it) and
    -- truncates rather than wraps.
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", NAME_GAP, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", -EDGE_INSET, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)

    -- The rarity row is three chained pieces (prefix / "~" / rest) so the approximate
    -- tilde can drop by TILDE_NUDGE to sit centred against the digits while the rest
    -- stays on the baseline. Populate fills all three; the tilde is empty for the
    -- percentage and off-snapshot forms. A notch larger than the date/brand rows
    -- (GameFontNormal vs ...Small) so the brag — the toast's payload — outweighs the
    -- metadata beneath it.
    f.rarityPre = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.rarityPre:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -LINE_GAP)
    f.rarityPre:SetJustifyH("LEFT")
    f.rarityPre:SetWordWrap(false)

    f.rarityTilde = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.rarityTilde:SetPoint("LEFT", f.rarityPre, "RIGHT", 0, -TILDE_NUDGE)

    f.rarityPost = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.rarityPost:SetPoint("LEFT", f.rarityTilde, "RIGHT", 0, TILDE_NUDGE)
    f.rarityPost:SetJustifyH("LEFT")
    f.rarityPost:SetWordWrap(false)

    -- Earn time, third row — disable-grey so this metadata recedes beneath the name
    -- and the (now larger) rarity brag, matching the addon's other secondary text.
    f.stamp = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.stamp:SetPoint("TOPLEFT", f.rarityPre, "BOTTOMLEFT", 0, -LINE_GAP - 2)

    -- gratz.gg watermark at the bottom — bottom-right corner, in brand gold, below
    -- the rows and off the earn-time line. The toast is the highest-reach surface
    -- (built to be screenshotted), so it carries the data attribution.
    f.brand = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.brand:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -EDGE_INSET, 9)
    f.brand:SetTextColor(unpack(G.GOLD))
    f.brand:SetText(G.BRAND)

    -- Glow flashes behind the text (sublevel below it, so it brightens without
    -- washing it); the shine sweeps across in front. Both reuse Blizzard's atlas;
    -- the sizes and sweep distance are fitted to our frame by eye. Start invisible.
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, -8)
    f.glow:SetTexture(TOAST_ART)
    f.glow:SetTexCoord(0.0009765625, 0.3076171875, 0.169921875, 0.302734375)
    f.glow:SetBlendMode("ADD")
    f.glow:SetSize(TOAST_W + 50, TOAST_H + 56)
    f.glow:SetPoint("CENTER")
    f.glow:SetAlpha(0)
    f.glowAnim = f.glow:CreateAnimationGroup()
    local gi = f.glowAnim:CreateAnimation("Alpha")
    gi:SetFromAlpha(0); gi:SetToAlpha(1); gi:SetDuration(0.2); gi:SetOrder(1)
    local go = f.glowAnim:CreateAnimation("Alpha")
    go:SetFromAlpha(1); go:SetToAlpha(0); go:SetDuration(0.5); go:SetOrder(2)
    f.glowAnim:SetScript("OnFinished", function() f.glow:SetAlpha(0) end)

    f.shine = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.shine:SetTexture(TOAST_ART)
    f.shine:SetTexCoord(0.9296875, 0.9951171875, 0.169921875, 0.2529296875)
    f.shine:SetBlendMode("ADD")
    f.shine:SetSize(SHINE_W, TOAST_H)
    f.shine:SetPoint("LEFT", SHINE_MARGIN, 0)
    f.shine:SetAlpha(0)
    f.shineAnim = f.shine:CreateAnimationGroup()
    local si = f.shineAnim:CreateAnimation("Alpha")
    si:SetFromAlpha(0); si:SetToAlpha(1); si:SetDuration(0.2); si:SetOrder(1)
    local stx = f.shineAnim:CreateAnimation("Translation")
    stx:SetOffset(TOAST_W - SHINE_W - 2 * SHINE_MARGIN, 0); stx:SetDuration(0.85); stx:SetOrder(2)
    local so = f.shineAnim:CreateAnimation("Alpha")
    so:SetFromAlpha(1); so:SetToAlpha(0); so:SetStartDelay(0.35); so:SetDuration(0.5); so:SetOrder(2)
    f.shineAnim:SetScript("OnFinished", function() f.shine:SetAlpha(0) end)

    function f.PlayEffects()
        f.glow:SetAlpha(0); f.glowAnim:Stop(); f.glowAnim:Play()
        f.shine:SetAlpha(0); f.shineAnim:Stop(); f.shineAnim:Play()
    end

    -- Hide frees the slot (PumpQueue/Layout key off IsShown); pumping in turn
    -- fills it from the queue and re-centres the survivors.
    local function release(self)
        self.fader:Stop()
        self:Hide()
        PumpQueue()
    end

    f.fader = f:CreateAnimationGroup()
    local fade = f.fader:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(TOAST_SECONDS)
    fade:SetDuration(FADE_SECONDS)
    f.fader:SetScript("OnFinished", function() release(f) end)
    f:SetScript("OnClick", release)

    return f
end

local frames = {}
for i = 1, MAX_VISIBLE do
    frames[i] = CreateToastFrame(i)
end

local queue = {}

-- The rarity row as three left-to-right pieces — prefix, the approximate "~", and
-- the rest — so Populate can drop the tilde a couple of px to sit centred against
-- the digits. Rare tiers (under COUNT_BELOW_PCT) read as a population count
-- ("one of only ~N players" — lands harder than "<1%" on a rare earn, and stays
-- truthful as a share of the accounts gratz.gg tracks). The snapshot's as-of is
-- deliberately not shown: the earn timestamp already dates the toast, and a second
-- date would only muddy it. The count takes the rarity-tier colour, the rest stays
-- gold. Common tiers keep the percentage and the off-snapshot fallback its grey
-- note — both carry no tilde, so the prefix holds the whole line and the other two
-- are empty.
-- "EU players" / "accounts worldwide" — the scope-region noun the rarity line
-- ends on. Follows the user's chosen scope (region/global) like every figure here.
local function scopeFor(noun)
    local region = G.ScopeRegion()
    return region == "global" and (noun .. " worldwide") or (region:upper() .. " " .. noun)
end

local function RarityText(achievementId)
    local pct = G.RarityValue(achievementId)
    if not pct then
        return "|cff999999Rarity not in this data snapshot yet.|r", "", ""
    end
    local hex = G.RarityHex(achievementId)
    if pct < COUNT_BELOW_PCT then
        local n = BreakUpLargeNumbers(G.RarityCounts[achievementId][G.ScopeIndex()])
        return "|cffffd100One of only |r",
            string.format("|cff%s~|r", hex),
            string.format("|cff%s%s|r|cffffd100 %s.|r", hex, n, scopeFor("players"))
    end
    return string.format(
        "|cffffd100Held by |r|cff%s%s|r|cffffd100 of %s.|r", hex, G.FormatPct(pct), scopeFor("accounts")), "", ""
end

-- Shrink the name in 1pt steps from NAME_MAX_PT toward NAME_MIN_PT until its
-- unbounded width fits the column on one line; at the floor the engine's width +
-- no-wrap truncation (ellipsis) takes over for the truly enormous. Always restarts
-- from the max so a pooled frame never inherits the previous earn's shrunk size.
-- Size only — same font path/flags — so the colour, shadow and tier tint hold.
local function FitName(f)
    local path, _, flags = f.name:GetFont()
    for size = NAME_MAX_PT, NAME_MIN_PT, -1 do
        f.name:SetFont(path, size, flags)
        if f.name:GetUnboundedStringWidth() <= NAME_AVAIL then
            return
        end
    end
end

-- Fill a frame's regions for an achievement; false if the id is unknown to this
-- client build (shipped rarity ids can run ahead of the client).
local function Populate(f, achievementId)
    local achName, points, _, achIcon = G.AchievementInfo(achievementId)
    if not achName then
        return false
    end
    f.icon:SetTexture(achIcon)
    f.name:SetText(achName)
    -- Name in the earn's rarity-tier colour (the WoW item-name idiom); brand gold
    -- when the achievement is outside the shipped rarity snapshot.
    f.name:SetTextColor(G.RarityColor(achievementId))
    FitName(f)
    if points and points > 0 then
        f.points:SetText(tostring(points))
        f.points:Show()
        f.shield:Show()
    else
        f.points:Hide()
        f.shield:Hide()
    end
    local pre, tilde, post = RarityText(achievementId)
    f.rarityPre:SetText(pre)
    f.rarityTilde:SetText(tilde)
    f.rarityPost:SetText(post)
    -- Two clearly-separated dates: when you earned it (the client's real
    -- completion date — today for a live earn, the true past date for a re-share
    -- via /rarity share) and that the rarity figure is the current snapshot's, not
    -- the rarity back when you earned it. The earn date is dropped when unknown
    -- (e.g. an unearned preview), leaving just the rarity's as-of.
    local earned = G.AchievementEarnedShort(achievementId)
    local asOf = "Rarity as of " .. G.AsOfShort()
    f.stamp:SetText(earned and (string.format("Earned %s  ·  %s", earned, asOf)) or asOf)
    return true
end

-- The base anchor every toast hangs off: the player's saved spot (the mover writes
-- AchievementRarityDB.toastPos in the shared SavePoint shape) or, when unset, the
-- default spot (DEFAULT_POINT/X/Y above). Returns point, relPoint, x, y.
local function ToastAnchor()
    local pos = AchievementRarityDB and AchievementRarityDB.toastPos
    if pos then
        return pos.point, pos.relPoint, pos.x, pos.y
    end
    return DEFAULT_POINT, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y
end

-- Centre the showing frames on the base anchor. One at a time today, but kept
-- general (a horizontal centred row) in case the visible count grows again.
local function Layout()
    local showing = {}
    for _, f in ipairs(frames) do
        if f:IsShown() then
            showing[#showing + 1] = f
        end
    end
    local n = #showing
    local point, relPoint, baseX, y = ToastAnchor()
    for i, f in ipairs(showing) do
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, relPoint, baseX + (i - (n + 1) / 2) * (TOAST_W + GAP), y)
    end
end

-- Schedule a screenshot of the toast just shown. We never hide the UI (that's
-- what made other addons drop the achievement from the shot) — the card sits over
-- your normal screen and is captured there. shotPending coalesces a double-request
-- inside the delay window; sequential toasts (one at a time, ~5.5s apart) each
-- clear it well before the next, so a multi-achievement earn captures every card
-- in turn. After the shot we confirm to the player a tick later — printed AFTER
-- the capture, so the confirmation line isn't itself in the shot. The confirm is
-- optimistic (paired with the Screenshot call we just made): SCREENSHOT_SUCCEEDED
-- doesn't reliably fire for a scripted screenshot on this client.
local shotPending = false
local function CaptureSoon(name)
    if shotPending or type(Screenshot) ~= "function" then
        return
    end
    shotPending = true
    C_Timer.After(SHOT_DELAY, function()
        shotPending = false
        Screenshot()
        C_Timer.After(0.3, function()
            print(string.format("|cffffd100Achievement Rarity|r screenshot saved%s", name and (": " .. name) or ""))
        end)
    end)
end

-- Fill every free slot from the queue, skipping ids unknown to this client. Each
-- queue entry is { id, capture } — capture toasts (a real earn with the option
-- on, or a /rarity share) snap a screenshot once shown.
function PumpQueue()
    for _, f in ipairs(frames) do
        while not f:IsShown() and #queue > 0 do
            local rec = table.remove(queue, 1)
            if Populate(f, rec.id) then
                f:SetAlpha(1)
                f:Show()
                f.fader:Stop()
                f.fader:Play()
                f.PlayEffects()
                if rec.capture then
                    CaptureSoon(f.name:GetText())
                end
            end
        end
    end
    Layout()
end

-- Enqueue an achievement for a toast. Kept as G.ShowToast so the real-earn handler
-- and /rarity toast both feed the queue through one path, and the documented
-- /run AchievementRarity.ShowToast(id) preview still works (one id → one toast).
-- capture (optional) snaps a screenshot once the toast shows — set by a real earn
-- when the screenshot option is on, and by the share action.
local function ShowToast(achievementId, capture)
    queue[#queue + 1] = { id = achievementId, capture = capture }
    PumpQueue()
end

G.ShowToast = ShowToast

-- Client-known ids from the rarity snapshot for the debug/sample toasts, rarest
-- (count-form, under COUNT_BELOW_PCT) first so a debug toast shows the "one of
-- only ~N players" count rather than a percentage. Bounded by DEBUG_ID_CAP — the
-- debug/sample paths need only a handful — so it stops once it has enough rather
-- than scanning the whole snapshot. Rare ids come first; a few percentage-form ids
-- follow as a fallback when too few rare ones are client-known.
local DEBUG_ID_CAP = 12
local function DebugIds()
    local rare, rest = {}, {}
    for id in pairs(G.RarityCounts) do
        if G.AchievementInfo(id) then
            local pct = G.RarityValue(id)
            if pct and pct < COUNT_BELOW_PCT then
                rare[#rare + 1] = id
                if #rare >= DEBUG_ID_CAP then
                    break
                end
            elseif #rest < DEBUG_ID_CAP then
                rest[#rest + 1] = id
            end
        end
    end
    for _, id in ipairs(rest) do
        if #rare >= DEBUG_ID_CAP then
            break
        end
        rare[#rare + 1] = id
    end
    return rare
end

-- The toast to pin for a clean showcase / screenshot: the rarest client-known
-- achievement (across the whole snapshot) whose name fits the card at full size,
-- so the rarity reads impressively without the name shrinking or truncating.
-- "Fits" is approximated by name length (rendered width isn't measured here);
-- falls back to the rarest known if none clear the budget.
local SHOWCASE_NAME_MAX = 22
local function ShowcaseId()
    local best, bestVal, fallback, fallbackVal
    for id in pairs(G.RarityCounts) do
        local name = G.AchievementInfo(id)
        if name then
            local val = G.RarityValue(id) or 100
            if not fallbackVal or val < fallbackVal then
                fallback, fallbackVal = id, val
            end
            if #name <= SHOWCASE_NAME_MAX and (not bestVal or val < bestVal) then
                best, bestVal = id, val
            end
        end
    end
    return best or fallback
end

-- Show one persistent (non-fading) sample toast alone in slot 1: drop the queue,
-- stop every fader, clear the other slot, then populate and show id without arming
-- the fader. Shared by the showcase pin and the position mover. Returns the
-- frame, or nil if id is nil (no client-known achievement to show).
local function ShowSample(id)
    if not id then
        return nil
    end
    local f = frames[1]
    wipe(queue)
    for _, g in ipairs(frames) do
        g.fader:Stop()
        if g ~= f then
            g:Hide()
        end
    end
    Populate(f, id)
    f:SetAlpha(1)
    f:Show() -- no fader:Play(), so it persists
    Layout()
    return f
end

-- A standard push-button (UIPanelButtonTemplate) tucked just under the toast's
-- bottom edge at its left or right corner — the shape every toast-attached control
-- (the pin's Replay/Close, the mover's Lock/Reset) shares. side is "LEFT"/"RIGHT".
local function ToastButton(parent, side, width, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetPoint("TOP" .. side, parent, "BOTTOM" .. side, 0, -6)
    b:SetScript("OnClick", onClick)
    return b
end

-- Debug: /rarity toast pin — show one toast that does NOT fade, with Replay/Close
-- buttons beneath it, so the card can be studied or screenshotted at leisure. Uses
-- the rarest achievement whose name fits, so the pinned toast reads as an
-- impressive, well-fitting earn. Holds slot 1 until you Close it.
local function DebugPin()
    local f = ShowSample(ShowcaseId())
    if not f then
        print("|cffffd100Achievement Rarity|r toast pin: no client-known achievement.")
        return
    end

    if not f.pinReplay then
        f.pinReplay = ToastButton(f, "LEFT", 110, "Replay effect", function() f.PlayEffects() end)
        f.pinClose = ToastButton(f, "RIGHT", 70, "Close", function()
            f.pinReplay:Hide()
            f.pinClose:Hide()
            f:Hide()
            Layout()
        end)
    end
    f.pinReplay:Show()
    f.pinClose:Show()
    f.PlayEffects()
    print("|cffffd100Achievement Rarity|r toast pinned — Replay effect / Close beneath it.")
end

-- Move mode (the options "Move toast" button): a draggable sample toast so the
-- player can place where earned toasts appear. Closes the settings panel so the
-- sample is visible, drops a real-rarity sample, and lets you drag it; the spot
-- persists to AchievementRarityDB.toastPos (the same SavePoint shape) and every
-- real toast then anchors there (Layout → ToastAnchor). Lock ends the mode and
-- tears the dragging back down, so real toasts are never draggable; Reset clears
-- the saved spot back to the default.
function G.ToastMoveMode()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    local f = ShowSample(DebugIds()[1])
    if not f then
        print("|cffffd100Achievement Rarity|r move toast: no client-known achievement to show.")
        return
    end

    -- Arm dragging on every entry (Lock tears it down below, so it must be re-armed
    -- next time); the Lock/Reset buttons are created once, further down.
    G.MakeDraggable(f, "toastPos")

    if not f.moveLock then
        f.moveLock = ToastButton(f, "LEFT", 70, "Lock", function()
            f:SetScript("OnDragStart", nil)
            f:SetScript("OnDragStop", nil)
            f:RegisterForDrag()
            f:SetMovable(false)
            f.moveLock:Hide()
            f.moveReset:Hide()
            f:Hide()
            Layout()
            print("|cffffd100Achievement Rarity|r toast position saved.")
        end)
        f.moveReset = ToastButton(f, "RIGHT", 110, "Reset position", function()
            AchievementRarityDB.toastPos = nil
            Layout() -- back to the default spot; the sample follows
        end)
    end
    f.moveLock:Show()
    f.moveReset:Show()
    print("|cffffd100Achievement Rarity|r drag the toast to place it, then Lock. Reset returns it to default.")
end

-- Debug: /rarity toast [count] — fire `count` (default 1) toasts, mirroring a
-- real earn now that we replace Blizzard's alert. Uses the rarest distinct
-- client-known ids (count-form first) so the rarity lines are real and show the
-- "one of only ~N" count. /rarity toast pin pins one that doesn't fade, for
-- studying the layout.
local function DebugToast(rest)
    rest = rest and strtrim(rest):lower() or ""
    if rest == "pin" then
        DebugPin()
        return
    end
    local count = tonumber(rest:match("%d+")) or 1
    count = math.max(1, math.min(count, 10))

    local known = DebugIds()
    local ids = {}
    for _, id in ipairs(known) do
        if #ids >= count then
            break
        end
        ids[#ids + 1] = id
    end

    if #ids == 0 then
        print("|cffffd100Achievement Rarity|r debug toast: no client-known achievement to show.")
        return
    end

    for _, id in ipairs(ids) do
        ShowToast(id)
    end
    print(string.format("|cffffd100Achievement Rarity|r debug toast: fired %d.", #ids))
end

G.DebugToast = DebugToast

-- Share your rarest earned achievement: re-pop that card and let the capture path
-- screenshot it. Both the /rarity share command and the "Share rarest achievement"
-- keybind call this. Prints a note if none of your earned achievements are in the
-- snapshot yet.
function G.ShareRarest()
    local _, _, id = G.RarestEarned()
    if not id then
        print("|cffffd100Achievement Rarity|r nothing to share yet — none of your earned achievements are in this data snapshot.")
        return
    end
    ShowToast(id, true)
end

-- Replace Blizzard's achievement alert with ours: while our toast is on, stop
-- Blizzard's alert frame from popping the achievement alert; when off, hand it
-- back so the player still gets one. (The earn fanfare is the engine's, not the
-- alert frame's — VERIFY in-game that it still plays after suppression.)
function G.ApplyToastMode()
    if not AlertFrame then
        return
    end
    if G.IsEnabled() and AchievementRarityDB.toast then
        AlertFrame:UnregisterEvent("ACHIEVEMENT_EARNED")
    else
        AlertFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ACHIEVEMENT_EARNED")
events:RegisterEvent("PLAYER_LOGIN")
-- No alreadyEarned skip: the event's second arg is true when the account already
-- had the achievement (an alt earned it first), and that earn still deserves its
-- moment.
events:SetScript("OnEvent", function(_, event, achievementId)
    if event == "PLAYER_LOGIN" then
        G.ApplyToastMode()
        return
    end
    if not G.IsEnabled() or not AchievementRarityDB.toast then
        return
    end
    ShowToast(achievementId, AchievementRarityDB.screenshot)
end)
