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
