-- Chat.lua — chat enrichment: append rarity to incoming guild/nearby
-- achievement announcements. Local display only — visible to addon users.
local _, G = ...

-- The chat frame format()s the message AFTER filters run (the %s player-name
-- placeholder is still unfilled here), so any % we append must be escaped.
local function FilterAchievementAnnounce(_, _, msg, author, ...)
    if not G.IsEnabled() then
        return false
    end
    local idStr = msg:match("|Hachievement:(%d+)")
    if not idStr then
        return false
    end
    local id = tonumber(idStr)
    local rarity = G.RarityFor(id)
    if not rarity then
        return false
    end
    -- The % takes its rarity-tier colour; "(rarity …)" is white.
    local suffix = string.format(" |cffffffff(rarity |r|cff%s%s|r|cffffffff)|r",
        G.RarityHex(id), rarity)
    return false, msg .. suffix:gsub("%%", "%%%%"), author, ...
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", FilterAchievementAnnounce)
ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", FilterAchievementAnnounce)

-- Click-to-preview from a chat link: a modifier-click (HowRareDB.previewModifier) on
-- a linked achievement pops its rarity toast — the same gesture as on a panel row, so
-- it works everywhere an achievement appears. A post-hook (the standard SetItemRef
-- hook), so Blizzard still opens the panel to the achievement and we add the toast on
-- top — the panel opening is useful navigation from a link, unlike the in-panel expand
-- we suppress on a row. Only our Alt/Ctrl modifier is taken; Blizzard's own
-- modified-clicks (link / track, whichever the client binds) pass through untouched.
hooksecurefunc("SetItemRef", function(link)
    if not (G.IsEnabled() and G.PreviewModifierHeld()) then
        return
    end
    local id = tonumber(link and link:match("^achievement:(%d+)"))
    if id and G.RarityValue(id) then
        G.ShowToast(id, HowRareDB.screenshot)
    end
end)
