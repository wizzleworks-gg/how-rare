-- CharacterSheet.lua — the collection verdict on the Character Info window: one
-- stat-style row in the right-hand stats pane ("Achievements — Epic", value in its
-- tier colour), with the full standing on hover. Own character only — another
-- player's earned list isn't available from an inspect, and the standing is
-- account-level anyway. Toggleable (characterSheet, default on); absent entirely
-- when the data snapshot ships no standing distribution.
local _, G = ...

-- Row geometry, eyeball-tuned in-game like AchievementUI's % offsets: the row sits
-- at the pane's bottom, clear of the stacked stat categories above (whose height
-- varies with gear enhancements).
local ROW_H = 20
local ROW_INSET_X = 8   -- side inset, matching the stat rows' text margin
local ROW_BOTTOM_Y = 8  -- lift from the pane's bottom edge

-- The verdict comes from G.CollectionVerdict — Core's cached copy (one cold ~8k
-- scan shared with /howrare me and the standing card). This file owns the
-- invalidation: its ACHIEVEMENT_EARNED handler below is the addon's one earn
-- listener for verdict state.

local row

local function ShowRowTooltip(self)
    local score, tier, standing, r, g, b = G.CollectionVerdict()
    if not tier then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Your achievements are " .. G.TierLabel(tier), r, g, b)
    GameTooltip:AddLine(string.format("Rarer than %s of %s (top %s).",
        G.FormatStandingPct(standing), G.ScopeNoun("accounts"),
        G.FormatPctFine(100 - standing)), 1, 1, 1, true)
    GameTooltip:AddLine(string.format("Collection score ~%s — %s",
        BreakUpLargeNumbers(math.floor(score + 0.5)), G.SCORE_NOTE), 1, 1, 1, true)
    GameTooltip:AddLine(string.format("Rarity as of %s · /howrare me for the card", G.AsOfLong()),
        0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- Create the row once, parented to the stats pane so it shows/hides with the
-- paperdoll tab for free. A plain frame of our own — no Blizzard stat internals
-- touched, so pane rebuilds can't orphan or taint it.
local function EnsureRow()
    if row or not CharacterStatsPane then
        return
    end
    row = CreateFrame("Frame", nil, CharacterStatsPane)
    row:SetHeight(ROW_H)
    row:SetPoint("BOTTOMLEFT", ROW_INSET_X, ROW_BOTTOM_Y)
    row:SetPoint("BOTTOMRIGHT", -ROW_INSET_X, ROW_BOTTOM_Y)
    row:EnableMouse(true)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT")
    row.label:SetText("Achievements")
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT")
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    row:Hide()
end

-- The row is a passive flex surface on YOUR character sheet — a "Junk" or "Common"
-- verdict sitting there reads as an insult, not information — so it shows for
-- anything ABOVE the held-by-most tiers. A denylist of the bottom two, not an
-- allowlist: a tier the library adds above legendary someday keeps showing (an
-- allowlist would hide the row for exactly the best collections). /howrare me
-- (an explicit ask) still reports every tier honestly.
local function PassiveWorthy(tier)
    return tier ~= nil and tier ~= "junk" and tier ~= "common"
end

-- Re-dress (or hide) the row from the cached verdict. Runs on pane show, on the
-- option/scope callbacks (Options.lua), and (coalesced) after an earn. Only when
-- the pane is on screen: the verdict scan is heavy, a hidden row re-dresses on the
-- pane's OnShow anyway — so option/scope flips made with the sheet closed cost
-- nothing.
function G.RefreshCharacterSheet()
    if not (row and CharacterStatsPane and CharacterStatsPane:IsVisible()) then
        return
    end
    if G.SurfaceOn("characterSheet") then
        local _, tier, _, r, g, b = G.CollectionVerdict()
        if PassiveWorthy(tier) then
            row.value:SetText(G.TierLabel(tier))
            row.value:SetTextColor(r, g, b)
            row:Show()
            return
        end
    end
    row:Hide()
end

-- The stats pane lives in Blizzard_UIPanels_Game on modern clients; guard for it
-- arriving after us. Refresh on every pane show — the verdict itself is cached, so
-- this is just a text/visibility pass.
local function Install()
    EnsureRow()
    if not row then
        return false
    end
    CharacterStatsPane:HookScript("OnShow", G.RefreshCharacterSheet)
    if CharacterStatsPane:IsVisible() then
        G.RefreshCharacterSheet()
    end
    return true
end

local events = CreateFrame("Frame")
local refreshPending = false
if not Install() then
    events:RegisterEvent("ADDON_LOADED")
end
events:RegisterEvent("ACHIEVEMENT_EARNED")
events:SetScript("OnEvent", function(self, event)
    if event == "ADDON_LOADED" then
        if Install() then
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end
    -- A new earn changes the score. Invalidate now; recompute AT MOST once next
    -- frame — meta chains fire several ACHIEVEMENT_EARNED in one frame, and
    -- without coalescing each would rerun the full scan mid-celebration. Refresh
    -- itself no-ops unless the pane is on screen.
    G.InvalidateCollectionVerdict()
    if not refreshPending then
        refreshPending = true
        C_Timer.After(0, function()
            refreshPending = false
            G.RefreshCharacterSheet()
        end)
    end
end)
