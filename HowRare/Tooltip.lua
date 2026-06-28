-- Tooltip.lua — rarity line on achievement tooltips (achievement UI + chat
-- links). Same mechanism KAF uses (TooltipDataProcessor on the Achievement
-- tooltip data type); we use the post-call since the line appends at the end.
local _, G = ...

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
    if not G.IsEnabled() then
        return
    end
    local rarity = G.RarityFor(data.id)
    if not rarity then
        return
    end
    -- A blank line sets the rarity off from the achievement's own tooltip text; it
    -- always lands last. Neutral white base; RarityLine carries the per-run colours.
    tooltip:AddLine(" ")
    tooltip:AddLine(G.RarityLine(rarity, data.id), 1, 1, 1)
    tooltip:Show()
end)
