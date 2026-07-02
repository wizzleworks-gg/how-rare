-- Tooltip.lua — rarity line on achievement tooltips (achievement UI + chat
-- links). Same mechanism KAF uses (TooltipDataProcessor on the Achievement
-- tooltip data type); we use the post-call since the line appends at the end.
local _, G = ...

-- Below this attainment the rarity line carries the account count too — at the
-- rare end the count ("one of ~830") is the number that lands, and a bare "<1%"
-- erases the difference between 1-in-110 and 1-in-10,000.
local COUNT_BELOW_PCT = 1

-- The shift-detail scope columns: display label + the library's explicit-region
-- scope name (the library resolves the column; no packed-layout knowledge here).
local SCOPE_COLS = {
    { "US", "us" },
    { "EU", "eu" },
    { "Global", "global" },
}

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
    if not G.SurfaceOn("tooltip") then
        return
    end
    -- One rarity resolve feeds the formatted line, the count threshold, and the
    -- colour lookup below — this fires on every achievement hover.
    local pct = G.RarityValue(data.id)
    if not pct then
        return
    end
    -- A blank line sets the rarity off from the achievement's own tooltip text; it
    -- always lands last. Neutral white base; RarityLine carries the per-run colours.
    tooltip:AddLine(" ")
    local line = G.RarityLine(G.FormatPct(pct), data.id)
    if pct < COUNT_BELOW_PCT then
        line = line .. string.format(" |cffffffff(one of ~%s)|r",
            BreakUpLargeNumbers(G.AR:GetCount(data.id, G.Scope())))
    end
    tooltip:AddLine(line, 1, 1, 1)
    -- When you've earned it early enough that the rank says something the rarity
    -- doesn't, your rank-at-earn rides beneath it. RankPhrase is nil for unearned
    -- achievements and not-notably-early earns, so this only ever shows on your own
    -- genuinely-early earns. Neutral white, like the row. The earn date is derived
    -- once and threaded through the rank and the shift block below.
    local earnTime = G.AchievementEarnedTime(data.id)
    local rank = earnTime and G.RankPhrase(data.id, nil, earnTime)
    if rank then
        tooltip:AddLine("you were in the " .. rank .. " to earn this", 1, 1, 1)
    end
    -- Shift-held detail (the WoW "more info" idiom — hold Shift, then hover): the
    -- tier by name, the rarity in every scope, and your earn date. Built at hover
    -- time; pressing/releasing Shift mid-hover doesn't rebuild, which is fine for a
    -- glance surface. Fine-formatted %s — detail means precision.
    if IsShiftKeyDown() then
        local parts = {}
        local tier = G.RarityTier(data.id)
        if tier then
            parts[#parts + 1] = string.format("|cff%s%s|r",
                G.RarityHex(data.id), tier:gsub("^%l", string.upper))
        end
        for _, col in ipairs(SCOPE_COLS) do
            local scopePct = G.RarityValue(data.id, col[2])
            if scopePct then
                parts[#parts + 1] = string.format("%s %s", col[1], G.FormatPctFine(scopePct))
            end
        end
        if #parts > 0 then
            tooltip:AddLine(table.concat(parts, " · "), 1, 1, 1)
        end
        local earned = G.AchievementEarnedShort(data.id)
        if earned then
            local ago = G.EarnedAgo(data.id, earnTime)
            tooltip:AddLine(string.format("Earned %s%s", earned, ago and (" (" .. ago .. ")") or ""), 1, 1, 1)
        end
    end
    tooltip:Show()
end)
