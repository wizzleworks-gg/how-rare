-- Options.lua — SavedVariables defaults + the Settings panel (one checkbox per
-- feature) + /howrare slash. HowRareDB holds the feature toggles and the
-- saved toast position.
local addonName, G = ...

local DEFAULTS = {
    enabled = true, -- master switch: off silences every automatic surface (G.IsEnabled)
    toast = true, -- companion toast on ACHIEVEMENT_EARNED (replaces Blizzard's alert)
    screenshot = false, -- auto-screenshot the toast on earn (off: it fills the folder)
    titleColor = true, -- tier-colour panel-row titles by rarity
    scope = "region", -- rarity scope: "region" (your own) or "global" (everyone tracked)
    previewModifier = "alt", -- click-to-preview modifier: "alt" / "ctrl" / "off"
}
-- Rarity on tooltips, chat lines, and panel rows, plus the toast's glow/sweep
-- flourish, have no toggle of their own — they're the addon's baseline behaviour,
-- governed by the master switch above.

local function ApplyDefaults()
    HowRareDB = HowRareDB or {}
    for key, value in pairs(DEFAULTS) do
        if HowRareDB[key] == nil then
            HowRareDB[key] = value
        end
    end
end

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("How Rare?")
    G.settingsCategory = category

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
    -- restore Blizzard's alert. Tooltip / chat / panel rarity read the master at
    -- use-time, so need no callback.
    Settings.SetOnValueChangedCallback("HOWRARE_ENABLED", function()
        G.ApplyToastMode()
    end)

    local toast, toastInit = AddCheckbox("toast", "Earned toast",
        "Replace Blizzard's achievement alert with a toast that adds the achievement's rarity. Turn off to restore Blizzard's own alert.")
    DependOn(toastInit, masterInit, MasterOn)
    -- Suppress / restore Blizzard's own achievement alert the moment this flips.
    Settings.SetOnValueChangedCallback("HOWRARE_TOAST", function()
        G.ApplyToastMode()
    end)

    -- Nested under the toast (and the master): a screenshot needs a toast to catch.
    local _, shotInit = AddCheckbox("screenshot", "Screenshot earned achievements",
        "Take a screenshot when you earn an achievement, capturing the toast over your screen — no UI hidden. Each toast in a multi-achievement earn is caught in turn. Needs the earned toast on.")
    DependOn(shotInit, toastInit, function()
        return MasterOn() and toast:GetValue()
    end)

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
    -- Repaint the visible panel rows the moment scope flips, so their %/colours
    -- update without waiting for the list to re-fill.
    Settings.SetOnValueChangedCallback("HOWRARE_SCOPE", function()
        if G.RepaintRows then
            G.RepaintRows()
        end
    end)

    -- The rarity "about" section: what the number means, the live denominator + scope,
    -- the snapshot date (a release IS a data refresh), and the data attribution. The
    -- user opted into this page, so it's the home for the fuller "by the Wizzleworks"
    -- credit. The explanation names the account count, not the brand. A "How the
    -- numbers work" link is deferred until the funnel/hub lands (it'll ride the rarity-
    -- library split) — see HANDOVER.
    local accounts = G.AR:GetMeta().accounts
    local scope
    if G.region == "global" then
        scope = string.format("%s active accounts worldwide",
            BreakUpLargeNumbers(accounts.global))
    else
        scope = string.format("%s active %s accounts",
            BreakUpLargeNumbers(accounts[G.region]), G.region:upper())
    end
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        "Rarity is the share of active accounts that have earned an achievement"))
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        string.format("Measured across %s", scope)))
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        string.format("Data snapshot: %s", G.AsOfLong())))
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        "Data generated by the Wizzleworks"))

    Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, loadedName)
    if event == "PLAYER_LOGIN" then
        G.Print(string.format("loaded (as of %s) — /howrare for options", G.AsOfLong()))
        return
    end
    if loadedName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")
    ApplyDefaults()
    RegisterSettings()
end)

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
