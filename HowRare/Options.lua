-- Options.lua — SavedVariables defaults + the Settings panel (one checkbox per
-- feature) + /howrare slash. HowRareDB holds the feature toggles and the
-- saved toast position.
local addonName, G = ...

local DEFAULTS = {
    enabled = true, -- master switch: off silences every automatic surface (G.IsEnabled)
    tooltip = true, -- rarity (and your rank) on achievement tooltips (G.SurfaceOn)
    chat = true, -- rarity + your status on incoming achievement announcements
    panel = true, -- the rarity % painted on achievement-panel rows
    rowTooltip = true, -- hover tooltip on achievement-panel rows (Blizzard shows none)
    characterSheet = true, -- "Achievements — <tier>" row on the Character Info stats pane
    titleColor = true, -- tier-colour panel-row titles by rarity
    toast = true, -- companion toast on ACHIEVEMENT_EARNED (replaces Blizzard's alert)
    screenshot = "off", -- auto-screenshot mode: "off" / "rare" (rare-and-rarer tiers) / "all"
    scope = "region", -- rarity scope: "region" (your own) or "global" (everyone tracked)
    countFormMax = 2500, -- small-club boundary: counts below it ("one of ~830"), shares above; 0 = off
    previewModifier = "alt", -- click-to-preview modifier: "alt" / "ctrl" / "off"
}

local function ApplyDefaults()
    HowRareDB = HowRareDB or {}
    -- The screenshot option grew from a checkbox into a mode dropdown; carry an old
    -- boolean forward rather than silently resetting the user's choice.
    if type(HowRareDB.screenshot) == "boolean" then
        HowRareDB.screenshot = HowRareDB.screenshot and "all" or "off"
    end
    for key, value in pairs(DEFAULTS) do
        if HowRareDB[key] == nil then
            HowRareDB[key] = value
        end
    end
end

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("How Rare?")
    G.settingsCategory = category

    -- The data strap, first element on the page so it rides the "How Rare?" title:
    -- denominator · snapshot date · credit (the lowercase display wordmark in brand
    -- gold; running prose keeps "the Wizzleworks"). Same small white font as the
    -- about paragraph at the bottom — a fact line, not a header.
    local meta = G.AR:GetMeta()
    local scope
    if G.region == "global" then
        scope = string.format("%s active accounts worldwide",
            BreakUpLargeNumbers(meta.accounts.global))
    else
        scope = string.format("%s active %s accounts",
            BreakUpLargeNumbers(meta.accounts[G.region]), G.region:upper())
    end
    if Settings.CreateElementInitializer then
        layout:AddInitializer(Settings.CreateElementInitializer("HowRareHeaderLineTemplate",
            { text = string.format("%s · %s · Data by |cffffd100wizzleworks|r", scope, meta.asOf) }))
    end

    local function AddCheckbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(
            category, "HOWRARE_" .. key:upper(), key, HowRareDB,
            Settings.VarType.Boolean, label, DEFAULTS[key])
        return setting, Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Nest a child checkbox under a parent: greys out (and stays indented) when
    -- the predicate is false. Guarded so a client build without the dependency
    -- API still renders the panel rather than erroring.
    local function DependOn(child, parent, predicate)
        if child.SetParentInitializer then
            child:SetParentInitializer(parent, predicate)
        end
    end

    -- Master switch. Off silences every automatic surface — tooltip / chat /
    -- panel rarity and the toast; the sub-toggles below grey out under it.
    local master, masterInit = AddCheckbox("enabled", "How Rare? enabled",
        "Master switch for How Rare?. Off silences every automatic surface — rarity on tooltips, chat and panel rows, and the earned toast. On by default.")
    local function MasterOn()
        return master:GetValue()
    end
    -- Re-apply each automatic surface the moment the master flips: suppress or
    -- restore Blizzard's alert, and re-dress the character-sheet row. Tooltip /
    -- chat / panel rarity read the master at use-time, so need no callback.
    Settings.SetOnValueChangedCallback("HOWRARE_ENABLED", function()
        G.ApplyToastMode()
        if G.RefreshCharacterSheet then
            G.RefreshCharacterSheet()
        end
    end)

    -- Per-surface switches, nested under the master: each automatic surface can be
    -- turned off alone (chat enrichment is the classic "love the tooltips, hate the
    -- noise" case). Read at use-time (G.SurfaceOn), so only the panel paint needs a
    -- repaint callback to update already-visible rows.
    local _, tooltipInit = AddCheckbox("tooltip", "Rarity on tooltips",
        "Add each achievement's rarity — and, when you were notably early, how early (\"first ~230\" / \"first 3%\") — to achievement tooltips. Hold Shift while hovering for detail: tier, every region, and your earn date.")
    DependOn(tooltipInit, masterInit, MasterOn)

    local _, chatInit = AddCheckbox("chat", "Rarity on chat announcements",
        "Append rarity to guild and nearby achievement announcements, plus whether you already have it — and how early you earned it, when you were notably early.")
    DependOn(chatInit, masterInit, MasterOn)

    local _, panelInit = AddCheckbox("panel", "Rarity % on achievement rows",
        "Paint every achievement-panel row with its rarity %, so you can browse by rarity while scrolling.")
    DependOn(panelInit, masterInit, MasterOn)
    Settings.SetOnValueChangedCallback("HOWRARE_PANEL", function()
        if G.RepaintRows then
            G.RepaintRows()
        end
    end)

    -- The row hover tooltip (AchievementUI's HookRowTooltip). Blizzard's panel shows
    -- no tooltip of its own; ours pops the standard achievement tooltip with the
    -- rarity block. Its own switch, because Krowi / Overachiever users already get a
    -- row tooltip from those addons and shouldn't see two.
    local _, rowTipInit = AddCheckbox("rowTooltip", "Tooltip on achievement rows",
        "Show the standard achievement tooltip — with its rarity — when hovering achievement-panel rows. Blizzard shows none there by itself. Turn this off if you prefer another addon's tooltip there.")
    DependOn(rowTipInit, masterInit, MasterOn)

    -- The Character Info stats-pane row (CharacterSheet.lua). Refresh immediately on
    -- flip so the row appears/disappears without reopening the sheet.
    local _, sheetInit = AddCheckbox("characterSheet", "Achievements tier on character",
        "Add an Achievements row to the Character Info stats pane showing your collection's tier — hover it for your full standing. Appears once your collection rates Uncommon or better (and this data snapshot ships a standing distribution).")
    DependOn(sheetInit, masterInit, MasterOn)
    Settings.SetOnValueChangedCallback("HOWRARE_CHARACTERSHEET", function()
        if G.RefreshCharacterSheet then
            G.RefreshCharacterSheet()
        end
    end)

    local _, toastInit = AddCheckbox("toast", "Earned toast",
        "Replace Blizzard's achievement alert with a toast that adds the achievement's rarity. Turn off to restore Blizzard's own alert.")
    DependOn(toastInit, masterInit, MasterOn)
    -- Suppress / restore Blizzard's own achievement alert the moment this flips.
    Settings.SetOnValueChangedCallback("HOWRARE_TOAST", function()
        G.ApplyToastMode()
    end)

    -- Auto-screenshot as a mode, not a checkbox: "rare earns" is the middle setting
    -- that keeps the shots worth keeping without filling the folder — the tier is the
    -- addon's own judgment of "worth a screenshot". Conceptually under the toast (a
    -- screenshot needs a toast to catch), but dropdowns don't nest, so the tooltip
    -- says so instead.
    local shotSetting = Settings.RegisterAddOnSetting(
        category, "HOWRARE_SCREENSHOT", "screenshot", HowRareDB,
        Settings.VarType.String, "Screenshot earned achievements", DEFAULTS.screenshot)
    if Settings.CreateDropdown then
        Settings.CreateDropdown(category, shotSetting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("off", "Off", "Never screenshot automatically.")
            container:Add("rare", "Rare earns", "Screenshot earns of rare, epic, and legendary tier — the ones worth keeping.")
            container:Add("all", "All earns", "Screenshot every achievement earn.")
            return container:GetData()
        end, "Take a screenshot when you earn an achievement, capturing the toast over your screen — no UI hidden. Each toast in a multi-achievement earn is caught in turn. Needs the earned toast on.")
    end

    -- Tier-colouring of the panel-row titles (on by default). Nested under the
    -- master switch.
    local _, titleInit = AddCheckbox("titleColor", "Colour achievement titles by rarity",
        "Tint each achievement's title in the panel by its rarity tier — the same colours as the rarity %.")
    DependOn(titleInit, masterInit, MasterOn)
    -- Repaint the visible rows the moment it flips, so titles colour / restore without
    -- waiting for the list to re-fill (RepaintRows drives PaintRarity → PaintTitle).
    Settings.SetOnValueChangedCallback("HOWRARE_TITLECOLOR", function()
        if G.RepaintRows then
            G.RepaintRows()
        end
    end)

    -- A button (not a toggle): reposition where earned toasts appear. Opens the
    -- draggable mover, which closes this panel so the sample is visible. Guarded so
    -- a client without the button-initializer API still renders the panel.
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(
            "Earned toast position", "Move toast",
            function() G.ToastMoveMode() end,
            "Drag a sample toast to where you want earned toasts to appear, then Lock. Reset returns it to the default spot.",
            true)) -- addSearchTags: required (asserted non-nil); true makes it searchable
    end

    -- Click-to-preview: a modifier-click on an achievement pops its earned toast
    -- (the same card you get on earn), and screenshots it too if that option's on.
    -- A string dropdown like scope; the click intercept lives in AchievementUI. The
    -- hover line is gone, so this is also where the gesture is discoverable.
    local previewSetting = Settings.RegisterAddOnSetting(
        category, "HOWRARE_PREVIEWMODIFIER", "previewModifier", HowRareDB,
        Settings.VarType.String, "Preview toast on click", DEFAULTS.previewModifier)
    if Settings.CreateDropdown then
        Settings.CreateDropdown(category, previewSetting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("alt", "Alt-click", "Alt-click an achievement to preview its rarity toast.")
            container:Add("ctrl", "Ctrl-click", "Ctrl-click an achievement to preview its rarity toast.")
            container:Add("off", "Off", "Don't preview the toast on click.")
            return container:GetData()
        end, "Click an achievement with this modifier to pop its earned toast — the rarity celebration card. Works on achievement-panel rows and linked achievements in chat. Your other clicks are unchanged — plain clicks, and Blizzard's own modified-clicks (link / track), still work.")
    end

    -- Rarity scope: measure against your own region (default) or the whole tracked
    -- population. A string-valued dropdown; every surface and the public API read
    -- it through G.Scope(). Guarded so a client build without the dropdown API
    -- still renders the panel (the saved value, hence the default region, still
    -- applies). Realm scope is deliberately absent — rarity is only computed per
    -- region/global, never per realm.
    local scopeSetting = Settings.RegisterAddOnSetting(
        category, "HOWRARE_SCOPE", "scope", HowRareDB,
        Settings.VarType.String, "Rarity scope", DEFAULTS.scope)
    if Settings.CreateDropdown then
        Settings.CreateDropdown(category, scopeSetting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("region", "Your region", "Rarity among accounts in your own region (US or EU).")
            container:Add("global", "Global", "Rarity among all accounts tracked worldwide.")
            return container:GetData()
        end, "Whether rarity is measured against your own region or the whole tracked population. Applies everywhere — tooltips, panel rows, chat, and the toast.")
    end
    -- Repaint the visible panel rows (and the character-sheet verdict, whose cache
    -- is scope-keyed) the moment scope flips, without waiting for a re-fill.
    Settings.SetOnValueChangedCallback("HOWRARE_SCOPE", function()
        if G.RepaintRows then
            G.RepaintRows()
        end
        if G.RefreshCharacterSheet then
            G.RefreshCharacterSheet()
        end
    end)

    -- The small-club boundary (G.CountFormMax): below this many accounts, figures
    -- read as counts ("one of ~830", "first ~230") instead of percentages —
    -- everywhere a count form exists (tooltip parenthetical, rank phrase, toast).
    -- A dropdown of curated steps, not a slider: the boundary is a taste in orders
    -- of magnitude, and round numbers read as the "club sizes" they are. Default
    -- 2,500 — small enough that a count showing up means something.
    local countSetting = Settings.RegisterAddOnSetting(
        category, "HOWRARE_COUNTFORMMAX", "countFormMax", HowRareDB,
        Settings.VarType.Number, "Show counts for small clubs", DEFAULTS.countFormMax)
    if Settings.CreateDropdown then
        Settings.CreateDropdown(category, countSetting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add(0, "Off", "Always show percentages, never counts.")
            container:Add(500, "Under 500", "Counts only for the very rarest clubs.")
            container:Add(1000, "Under 1,000", "")
            container:Add(2500, "Under 2,500", "The default.")
            container:Add(5000, "Under 5,000", "")
            container:Add(10000, "Under 10,000", "Counts well into the rare tiers.")
            return container:GetData()
        end, "When an achievement's holder club — or the number of accounts that earned it before you — is smaller than this, show the count (\"one of ~830\", \"first ~230\") instead of a percentage.")
    end

    -- The methodology footnote: what the two numbers mean, as one two-sentence
    -- paragraph wrapped by the FontString itself (no hand-placed line breaks —
    -- natural wrapping fills each line to the template's real width). The
    -- denominator/date/credit strap lives at the page TOP (above). Our own element
    -- template (OptionsAbout.xml + HowRareAboutMixin below): stock section headers
    -- are 45px each and don't wrap, so line-per-header scrolled the panel. Guarded
    -- like the other optional Settings APIs; the fallback is a single credit
    -- header, not the full text.
    local about = "Rarity is the share of active accounts that hold an achievement. "
        .. "\"First N%\" is how early you earned it, shown when you were notably early."
    if Settings.CreateElementInitializer then
        layout:AddInitializer(Settings.CreateElementInitializer(
            "HowRareAboutTemplate", { text = about }))
    else
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
            "Data by |cffffd100wizzleworks|r"))
    end

    Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, loadedName)
    if event == "PLAYER_LOGIN" then
        -- Staleness nudge: freshness is the product promise, so an aging embedded
        -- snapshot is flagged rather than silently presented as current. 60 days ≈
        -- two refresh cadences missed.
        local age = G.SnapshotAgeDays()
        local stale = (age and age > 60)
            and string.format(" — snapshot ~%d months old; a newer release may have fresher data", math.floor(age / 30))
            or ""
        G.Print(string.format("loaded (as of %s%s) — /howrare for options", G.AsOfLong(), stale))
        return
    end
    if loadedName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")
    ApplyDefaults()
    RegisterSettings()
end)

-- The about block's element mixin (template: OptionsAbout.xml, instantiated by the
-- settings list when the page opens). Global — the XML template resolves the mixin
-- by name at instantiation. The settings scroll factory calls frame:Init(initializer)
-- (ScrollBoxFactoryInitializerMixin.InitFrame); the element's height comes from the
-- template, so this only fills the text.
HowRareAboutMixin = {}

function HowRareAboutMixin:Init(initializer)
    self.Text:SetText(initializer:GetData().text)
end

local function OpenOptions()
    Settings.OpenToCategory(G.settingsCategory:GetID())
end

local function PrintStatus()
    local meta = G.AR:GetMeta()
    local rarityCount = 0
    for _ in pairs(G.AR:GetData()) do
        rarityCount = rarityCount + 1
    end
    local opts = {}
    for key, value in pairs(HowRareDB) do
        if type(value) == "boolean" then
            opts[#opts + 1] = key .. "=" .. (value and "on" or "off")
        elseif type(value) == "string" then
            opts[#opts + 1] = key .. "=" .. value
        end
    end
    table.sort(opts)
    G.Print("status")
    print("  version " .. C_AddOns.GetAddOnMetadata(addonName, "Version")
        .. " · region " .. G.region .. " · data as of " .. meta.asOf)
    print("  rarity entries " .. rarityCount
        .. " · denominator " .. BreakUpLargeNumbers(meta.accounts[G.region]))
    print("  options: " .. table.concat(opts, " "))
    print("  achievement UI hooks: " .. (G.achievementUIHooked and "installed" or "waiting (panel not opened yet)"))
    print("  Lua errors are hidden unless: /console scriptErrors 1 (or install BugSack)")
end

-- /howrare top [n] — your rarest earned achievements, rarest first, as hoverable
-- links (each link shows the full tooltip, rank line included, so the list doubles
-- as a browser). Fine-formatted %s: a top list clamped to "<1%" would read as ties
-- exactly where it's most interesting. The scan is the shared G.EarnedRarities
-- (cold-path, sorted rarest-first).
local TOP_MAX = 25
local function PrintTop(rest)
    local n = math.min(tonumber(rest and rest:match("%d+")) or 10, TOP_MAX)
    local earned = G.EarnedRarities()
    if #earned == 0 then
        G.Print("no earned achievements in this data snapshot yet.")
        return
    end
    G.Print(string.format("your %d rarest (of %s earned in the snapshot):",
        math.min(n, #earned), BreakUpLargeNumbers(#earned)))
    for i = 1, math.min(n, #earned) do
        local e = earned[i]
        local rank = G.RankPhrase(e.id)
        print(string.format("  %d. %s |cff%s%s|r%s", i, GetAchievementLink(e.id) or "?",
            G.RarityHex(e.id), G.FormatPctFine(e.val),
            rank and (" |cffffffff· " .. rank .. "|r") or ""))
    end
end

-- /howrare why <achievement link or id> — the full story for one achievement: its
-- rarity, count, tier, your earn, your rank, and exactly which rule shows or hides
-- each line. The gates are deliberate but invisible, and an enthusiast testing their
-- proudest earn otherwise can't tell "suppressed" from "broken" — this makes every
-- suppression inspectable (and exercises the whole library surface, fitting the
-- reference-consumer job). Shift-click an achievement to insert its link.
local function ExplainWhy(rest)
    local id = tonumber((rest or ""):match("|Hachievement:(%d+)") or (rest or ""):match("^%s*(%d+)%s*$"))
    if not id then
        G.Print("usage: /howrare why <achievement link or id> — shift-click an achievement to insert its link.")
        return
    end
    local name = G.AchievementInfo(id)
    G.Print("why: " .. (name and GetAchievementLink(id) or ("achievement " .. id)))
    if not name then
        print("  this game client doesn't know that achievement id — nothing can be looked up.")
        return
    end
    local pct = G.RarityValue(id)
    if not pct then
        -- Two indistinguishable causes client-side (both are simply absent from the
        -- data): newer than the snapshot, or retired — delisted from Blizzard's
        -- achievement index and deliberately excluded (unobtainable; its rarity
        -- would measure attrition, not difficulty). Name both, claim neither.
        print("  not in this data — either newer than the snapshot's as-of date, or retired (delisted by Blizzard and deliberately excluded). No rarity, no rank.")
        return
    end
    local region = G.ScopeRegion()
    local meta = G.AR:GetMeta()
    -- GetCount takes the SAME saved scope as the % above it — an unscoped call
    -- would read the home-region column while the % and denominator use the
    -- saved scope, and the three numbers would contradict each other.
    print(string.format("  rarity: |cff%s%s|r — one of ~%s of %s active accounts (%s scope) · tier %s",
        G.RarityHex(id), G.FormatPctFine(pct), BreakUpLargeNumbers(G.AR:GetCount(id, G.Scope())),
        BreakUpLargeNumbers(meta.accounts[region]),
        region == "global" and "global" or region:upper(), G.RarityTier(id) or "?"))
    if not G.SelfCompleted(id) then
        print("  you haven't earned it — rank lines only ever describe your own earn.")
        return
    end
    local earnedShort = G.AchievementEarnedShort(id)
    local ago = G.EarnedAgo(id)
    print(string.format("  earned: %s%s", earnedShort or "date unknown",
        ago and (" (" .. ago .. ")") or ""))
    if not G.AchievementEarnedTime(id) then
        print("  the game records no usable earn date for it — rank suppressed.")
        return
    end
    -- Second return: the earner percentile on success, the library's suppression
    -- reason ("no-curve" / "date-floor"; "off-snapshot" was ruled out above) on nil.
    local rankAll, earnerPct = G.RankAtEarn(id)
    if not rankAll then
        if earnerPct == "date-floor" then
            print(string.format("  your recorded earn date is at or before WoW's launch (%s) — the game didn't exist to record it, so it can't be real. rank suppressed.",
                meta.rankFloor or "2004-11-23"))
        else
            print("  no rank curve for it in this scope — too few tracked earners for a stable percentile. rank suppressed.")
        end
        return
    end
    print(string.format("  rank: you were earlier than ~%d%% of its earners → in the first %s of all tracked accounts (~%s accounts earned it before you).",
        math.floor(earnerPct + 0.5), G.FormatPctFine(rankAll), BreakUpLargeNumbers(G.CountForPct(rankAll))))
    if earnerPct > G.RANK_EARLY_MAX then
        print(string.format("  display: suppressed — not notably early. The line shows when you're in the first %d%% of earners; later than that it would only restate the rarity.", G.RANK_EARLY_MAX))
    else
        local knob = G.CountFormMax()
        print("  display: shows on the tooltip, chat, and toast as \"you were in the " .. G.RankPhrase(id) .. " to earn this\""
            .. (knob > 0 and (" (under ~" .. BreakUpLargeNumbers(knob) .. " accounts before you it reads as the count, above as the share).")
                or " (count forms are off — shares only)."))
    end
end

-- /howrare me — the addon's title question, answered for the player: the whole-
-- collection standing. Prints the verdict + the numbers behind it, then pins the
-- shareable card (G.ShowStandingCard). The score alone still prints on a data file
-- without a standing distribution, with the explanation.
local function PrintMe()
    local score, tier, standing, r, g, b = G.CollectionVerdict()
    local scoreStr = BreakUpLargeNumbers(math.floor(score + 0.5))
    if not tier then
        G.Print(string.format("collection score ~%s — but this data snapshot ships no "
            .. "standing distribution to place it against; it arrives with the next data refresh.", scoreStr))
        return
    end
    -- Junk is never said to a player's face — the bottom tier leads with the
    -- honest number, no tier noun (the standing card's title does the same).
    local verdict = tier == "junk" and "your achievements are rarer than"
        or string.format("your achievements are |cff%s%s|r — rarer than",
            G.RGBHex(r, g, b), G.TierLabel(tier))
    G.Print(string.format("%s %s of %s (top %s).",
        verdict, G.FormatStandingPct(standing), G.ScopeNoun("accounts"),
        G.FormatPctFine(100 - standing)))
    print("  collection score ~" .. scoreStr .. " — " .. G.SCORE_NOTE)
    G.ShowStandingCard()
end

-- Keybinding label for the WoW Key Bindings screen. The action is declared in
-- Bindings.xml, which the client auto-loads from the addon root — it must NOT be
-- listed in the .toc (the general XML loader would otherwise mis-parse it and warn
-- on every <Binding> attribute). Ships unbound; the user assigns a key. No
-- category, so it lands under the default AddOns grouping.
BINDING_NAME_HOWRARE_SHARERAREST = "Share rarest achievement"

SLASH_HOWRARE1 = "/howrare"
SLASH_HOWRARE2 = "/hr"
SlashCmdList.HOWRARE = function(msg)
    local cmd, rest = (msg and strtrim(msg) or ""):match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()
    if cmd == "status" then
        PrintStatus()
    elseif cmd == "top" then
        PrintTop(rest)
    elseif cmd == "me" then
        PrintMe()
    elseif cmd == "why" then
        ExplainWhy(rest)
    elseif cmd == "toast" then
        G.DebugToast(rest)
    elseif cmd == "share" then
        G.ShareRarest()
    elseif cmd == "debug" then
        HowRareDB.debug = not HowRareDB.debug
        G.Print("debug " .. (HowRareDB.debug and "ON" or "off"))
    else
        -- Bare /howrare (or "options") opens the settings page — there's no window.
        OpenOptions()
    end
end

-- The addon-compartment entry (puzzle-piece drop-down at the minimap);
-- declared in the TOC via AddonCompartmentFunc. Opens the options page.
function HowRare_OnAddonCompartmentClick()
    OpenOptions()
end
