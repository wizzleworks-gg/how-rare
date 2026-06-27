-- Tooltip.lua — rarity line on achievement tooltips (achievement UI + chat
-- links). Same mechanism KAF uses (TooltipDataProcessor on the Achievement
-- tooltip data type); we use the post-call since the line appends at the end.
local _, G = ...

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
    if not G.IsEnabled() then
        return
    end
    local rarity, rr, rg, rb = G.RarityTextAndColor(data.id)
    if not rarity then
        return
    end
    tooltip:AddLine(G.RarityLine(rarity), rr, rg, rb)
    tooltip:Show()
end)
