-- AchievementUI.lua — rarity in Blizzard's achievement panel: the % painted on
-- every list row (browse-by-rarity while scrolling) and, toggleable, the row title
-- tinted by rarity tier. Augments only the Blizzard frame — KAF's own browser is a
-- separate surface.
local _, G = ...

-- Tier-colouring of the row's title (button.Label), toggleable via
-- HowRareDB.titleColor (default on). Uses SetVertexColor, the same channel
-- Blizzard's Saturate/Desaturate drive on the white GameFontHighlightMedium label,
-- so the tier colour lands true and the default restores exactly (white earned /
-- grey not). We restore only buttons we coloured (HowRareTitleColored) so Blizzard's
-- own colour is left alone when the option's off, and we restore them ourselves
-- because Blizzard re-saturates only on a saturated-style change, not on every
-- pooled refill. rarity/rr/rg/rb are PaintRarity's single RarityTextAndColor lookup,
-- threaded through so this costs no extra query.
local TITLE_DESAT = 0.65
local function PaintTitle(button, rarity, rr, rg, rb)
    local label = button.Label
    if not label then
        return
    end
    if rarity and G.IsEnabled() and HowRareDB and HowRareDB.titleColor then
        label:SetVertexColor(rr, rg, rb)
        button.HowRareTitleColored = true
    elseif button.HowRareTitleColored then
        local v = G.SelfCompleted(button.id) and 1 or TITLE_DESAT
        label:SetVertexColor(v, v, v)
        button.HowRareTitleColored = nil
    end
end

-- The % rides the header line, just left of the points shield. One spot for every
-- row — earned or not (you can track earned achievements too, so earned-vs-unearned
-- is no basis for it) — always clear of the track control under the icon and the
-- completion date under the shield. The shield doesn't move when a row drills in, so
-- the position holds collapsed or expanded. Offsets are first-cut; tune in-game.
local RARITY_DX = -4  -- gap to the left of the shield
local RARITY_DY = 17  -- up from the shield's vertical centre, inline with the header text
local function AnchorRarity(button)
    local fs = button.HowRareText
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", button.Shield, "LEFT", RARITY_DX, RARITY_DY)
end

-- Works on any achievement button with .id and .Icon — the category-list rows
-- (AchievementTemplate) and the Summary screen's recent-achievement buttons
-- (SummaryAchievementTemplate) share that structure. Buttons are pooled and
-- re-filled, so the text must be set (or cleared) on every fill, not just
-- when first created; the % is created and anchored once (AnchorRarity) by the shield.
local function PaintRarity(button)
    local rarity, rr, rg, rb = G.RarityTextAndColor(button.id)
    -- The % — created and anchored lazily on the first row that has a rarity, then
    -- re-set (or cleared) on every fill of that pooled button.
    if button.HowRareText or rarity then
        if not button.HowRareText then
            button.HowRareText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            AnchorRarity(button)
        end
        if rarity then
            button.HowRareText:SetTextColor(rr, rg, rb)
        end
        button.HowRareText:SetText((G.SurfaceOn("panel") and rarity) or "")
    end
    PaintTitle(button, rarity, rr, rg, rb)
end

-- Modifier-click a rarity-bearing row → preview its earned toast instead of
-- selecting/expanding it (and screenshot it too, if that option is on). We wrap the
-- frame's own OnClick (an ordinary Button, so this is taint-safe) and swallow the
-- click on our modifier; every other click — Blizzard's shift-link, a plain select —
-- calls through to the original. Wrapped once per pooled frame (HowRareClickHooked);
-- the wrapper reads self.id live, so it stays correct as the frame is reused.
local function HookRowClick(button)
    if button.HowRareClickHooked then
        return
    end
    button.HowRareClickHooked = true
    local base = button:GetScript("OnClick")
    button:SetScript("OnClick", function(self, mouseButton, down)
        if mouseButton == "LeftButton" and G.IsEnabled() and G.PreviewModifierHeld()
            and G.RarityValue(self.id) then
            if not down then
                G.ShowToast(self.id, G.ScreenshotWanted(self.id))
            end
            return
        end
        if base then
            base(self, mouseButton, down)
        end
    end)
end

local function InstallHooks()
    local scrollBox = AchievementFrameAchievements and AchievementFrameAchievements.ScrollBox
    if not scrollBox then
        return
    end
    -- Category-list rows: fires on every row fill, no matter when the pooled
    -- frame was created.
    ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame)
        PaintRarity(frame)
        HookRowClick(frame)
    end, G, false)
    scrollBox:ForEachFrame(function(frame)
        PaintRarity(frame)
        HookRowClick(frame)
    end)
    G.achievementUIHooked = true
    G.Debug("achievement UI hooks installed")
    -- Deliberately NOT painted: the Summary screen (the panel's first-open
    -- landing page). Its recent-achievement buttons are a separate template —
    -- smaller icon, no expander, no room for the % without a layout of its
    -- own. Rarity starts once you're in a category list.
end

-- Re-run the rarity paint over the currently-shown rows — used when the scope
-- option flips so the visible %/colours update without waiting for a refill.
function G.RepaintRows()
    local scrollBox = AchievementFrameAchievements and AchievementFrameAchievements.ScrollBox
    if scrollBox and G.achievementUIHooked then
        scrollBox:ForEachFrame(PaintRarity)
    end
end

G.OnAchievementUILoaded(InstallHooks)
