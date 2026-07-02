-- Chat.lua — chat enrichment: append rarity to incoming guild/nearby
-- achievement announcements. Local display only — visible to addon users.
local _, G = ...

-- The chat frame format()s the message AFTER filters run (the %s player-name
-- placeholder is still unfilled here), so any % we append must be escaped.
local function FilterAchievementAnnounce(_, _, msg, author, ...)
    if not G.SurfaceOn("chat") then
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
    -- Appended beats are chained with middle dots (no brackets — they read as an
    -- aside; the dot chain reads as one enriched line). The % takes its rarity-tier
    -- colour; the "· rarity" lead-in is white like the other separators.
    local suffix = string.format(" |cffffffff· rarity|r |cff%s%s|r",
        G.RarityHex(id), rarity)
    -- Your own status on their announcement (not the linker's — a link carries no earn
    -- data): the ready-check tick/cross for whether you hold it, and — when you do and
    -- you were notably early — when you earned it and your rank then. Textures, not ✓/✗
    -- characters: WoW's fonts have no glyph for those, so they render as a missing-glyph
    -- box; :0 sizes the icon to the line height. This filter runs per announcement, so
    -- the earn date is derived once and threaded into both beats. RankPhrase gates
    -- off-snapshot / earner-floor / unreliable-date / not-notably-early, so the
    -- "ago · rank" beat only ever rides a usable rank; EarnedAgo is then known to be a
    -- good date.
    if G.SelfCompleted(id) then
        suffix = suffix .. " |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
        local earnTime = G.AchievementEarnedTime(id)
        local rank = earnTime and G.RankPhrase(id, nil, earnTime)
        if rank then
            suffix = suffix .. string.format(" |cffffffff· %s · %s|r", G.EarnedAgo(id, earnTime), rank)
        end
    else
        suffix = suffix .. " |TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t"
    end
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
        G.ShowToast(id, G.ScreenshotWanted(id))
    end
end)
