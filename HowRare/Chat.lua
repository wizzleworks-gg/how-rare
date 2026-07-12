-- Chat.lua — chat enrichment: append rarity to incoming guild/nearby
-- achievement announcements (local display only — visible to addon users), plus
-- the click-to-send [Gz!] reply (the one line that leaves the machine).
local _, G = ...

-- Gz! — congratulate an earner INTO the channel their announcement came from, with
-- the rarity as the hook. This is the addon's only outbound chat and it is strictly
-- click-to-send: the [Gz!] affordance below is locally visible only, and nothing is
-- ever sent without that click (the no-spam rule — an addon that auto-posts on every
-- guildie's earn gets its users muted). The click is a hardware event, so SAY (the
-- nearby-announce channel) is sendable in the open world too. The sent line carries
-- NO addon branding — a congratulation ending in an ad reads as spam; the unexplained
-- precise rarity is itself the curiosity hook. The rarity beat rides only notable
-- earns (IsRareTier, the addon's one notability judgment) — "only 12% have this" would
-- deflate the Gz. A short per-(achievement, channel) cooldown swallows double-clicks.
local GZ_COOLDOWN = 30
-- The only channels a Gz! may ever go to. The channel token round-trips through a
-- chat hyperlink, and hyperlinks can be counterfeited by anything that prints to
-- chat — so the SEND boundary trusts nothing but its own two destinations (a
-- crafted "...:RAID" or "...:YELL" link must die here, not broadcast).
local GZ_CHANNELS = { GUILD = true, SAY = true }
local lastGz = {}
local function SendGz(id, channel)
    if not (G.IsEnabled() and GZ_CHANNELS[channel]) then
        return
    end
    local key = id .. ":" .. channel
    local now = GetTime()
    if lastGz[key] and now - lastGz[key] < GZ_COOLDOWN then
        G.Print("already Gz!'d that one just now.")
        return
    end
    local link = GetAchievementLink(id)
    if not link then
        return
    end
    local msg = "Gz! " .. link
    local pct = G.RarityValue(id)
    if pct and G.IsRareTier(id) then
        msg = string.format("%s — only %s of %s have this!",
            msg, G.FormatPctFine(pct), G.ScopeNoun("accounts"))
    end
    lastGz[key] = now
    SendChatMessage(msg, channel)
end

-- The chat frame format()s the message AFTER filters run (the %s player-name
-- placeholder is still unfilled here), so any % we append must be escaped.
local function FilterAchievementAnnounce(_, event, msg, author, ...)
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
    -- The [Gz!] send affordance, on every enriched announcement of SOMEONE ELSE'S
    -- earn (congratulating is the point; the rarity beat is gated inside SendGz —
    -- and your own announcements get no button, because one accidental click would
    -- publicly congratulate yourself). Locally-visible link only — clicking it
    -- sends the reply toward where the announcement came from: guild earns to
    -- GUILD, nearby ones to SAY. Rides the "garrmission" link type: the client
    -- only makes KNOWN link types clickable, and that one is otherwise-unused
    -- addon-space (the established convention); our SetItemRef hook below routes
    -- it. Ambiguate "short": author arrives realm-qualified for cross-realm
    -- guildies; a same-named stranger merely loses the button — the safe failure.
    if Ambiguate(author or "", "short") ~= UnitName("player") then
        local channel = event == "CHAT_MSG_GUILD_ACHIEVEMENT" and "GUILD" or "SAY"
        suffix = suffix .. string.format(" |Hgarrmission:howrareGz:%d:%s|h|cffffd100[Gz!]|r|h", id, channel)
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
    -- The [Gz!] click (see SendGz above) — plain clicks only: a MODIFIED click on
    -- a chat link is someone using Blizzard's own gestures (shift = insert into
    -- the edit box), never an intentional outbound send.
    -- Deliberately NOT `link and link:match(...)`: an and/or expression truncates
    -- a multi-value match to its FIRST capture — that shipped once, silently
    -- dropping the channel so every click matched and then sent nothing.
    local gzId, gzChannel
    if link then
        gzId, gzChannel = link:match("^garrmission:howrareGz:(%d+):(%u+)$")
    end
    if gzId then
        if not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
            SendGz(tonumber(gzId), gzChannel)
        end
        return
    end
    if not (G.IsEnabled() and G.PreviewModifierHeld()) then
        return
    end
    local id = tonumber(link and link:match("^achievement:(%d+)"))
    if id and G.RarityValue(id) then
        G.ShowToast(id, G.ScreenshotWanted(id))
    end
end)
