-- AchievementUI.lua — rarity in Blizzard's achievement panel: the % painted on
-- every list row (browse-by-rarity while scrolling) plus a hover tooltip with
-- full attribution, via the row's official OnEnter callback event. Augments
-- only the Blizzard frame — KAF's own browser is a separate surface.
local _, G = ...

-- Works on any achievement button with .id and .Icon — the category-list rows
-- (AchievementTemplate) and the Summary screen's recent-achievement buttons
-- (SummaryAchievementTemplate) share that structure. Buttons are pooled and
-- re-filled, so the text must be set (or cleared) on every fill, not just
-- when first created.
local function PaintRarity(button)
    local rarity, rr, rg, rb = G.RarityTextAndColor(button.id)
    if not button.AchRarityText then
        if not rarity then
            return
        end
        local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Centred in the ~15px band between the icon's bottom edge and the
        -- row's bottom (84px row, icon ends at 69).
        fs:SetPoint("TOP", button.Icon, "BOTTOM", 0, 1)
        button.AchRarityText = fs
    end
    if rarity then
        button.AchRarityText:SetTextColor(rr, rg, rb)
    end
    button.AchRarityText:SetText((G.IsEnabled() and rarity) or "")
end

local function OnRowEnter(_, button, achievementId)
    if not G.IsEnabled() then
        return
    end
    local rarity, rr, rg, rb = G.RarityTextAndColor(achievementId)
    if not rarity then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    GameTooltip:AddLine(G.RarityLine(rarity), rr, rg, rb)
    GameTooltip:Show()
    button.AchRarityTipShown = true
end

local function OnRowLeave(_, button)
    if button.AchRarityTipShown then
        button.AchRarityTipShown = nil
        GameTooltip:Hide()
    end
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
    end, G, false)
    scrollBox:ForEachFrame(PaintRarity)
    G.achievementUIHooked = true
    G.Debug("achievement UI hooks installed")
    -- Deliberately NOT painted: the Summary screen (the panel's first-open
    -- landing page). Its recent-achievement buttons are a separate template —
    -- smaller icon, no expander, no room for the % without a layout of its
    -- own. Rarity starts once you're in a category list.
    EventRegistry:RegisterCallback("AchievementFrameAchievement.OnEnter", OnRowEnter, G)
    EventRegistry:RegisterCallback("AchievementFrameAchievement.OnLeave", OnRowLeave, G)
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
