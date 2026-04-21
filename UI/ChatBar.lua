local _, ns = ...

local ChatBar = {
    frame = nil,
    buttons = {},
}
ns.ChatBar = ChatBar

local DEFAULT_CHANNELS = {
    { alias = "world", key = "BAR_WORLD", color = { 0.95, 0.45, 0.45 }, icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { alias = "s", key = "BAR_SAY", color = { 1.0, 1.0, 1.0 }, icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { alias = "y", key = "BAR_YELL", color = { 1.0, 0.2, 0.2 }, icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
    { alias = "p", key = "BAR_PARTY", color = { 0.66, 0.78, 1.0 }, icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
    { alias = "g", key = "BAR_GUILD", color = { 0.30, 0.95, 0.35 }, icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { alias = "i", key = "BAR_OFFICER", color = { 0.20, 0.92, 0.92 }, icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { alias = "w", key = "BAR_WHISPER", color = { 0.92, 0.35, 0.95 }, icon = "Interface\\Icons\\INV_Letter_15" },
    { alias = "raid", key = "BAR_RAID", color = { 1.0, 0.84, 0.2 }, icon = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider" },
    { alias = "rw", key = "BAR_INSTANCE", color = { 1.0, 0.36, 0.24 }, icon = "Interface\\Icons\\Ability_Warrior_CommandingShout" },
}

local ICON_SET_ORDER = { "color", "class", "mono" }
local CHANNEL_BUTTON_WIDTH = 34
local BUTTON_HEIGHT = 20
local BUTTON_GAP = 4
local BAR_SIDE_PADDING = 4

local function GetFirstUtf8Char(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local first = string.match(text, "^[%z\1-\127\194-\244][\128-\191]*")
    return first or ""
end

local function GetTemplateShortLabel(templateId)
    local normalizedId = ns.Compat.NormalizeToken(templateId or "")
    if normalizedId == "" then
        return nil
    end

    local key = "BAR_TEMPLATE_" .. string.upper(normalizedId)
    local localized = ns.L[key]
    if localized and localized ~= "" and localized ~= key then
        return localized
    end
    return nil
end

local function GetTemplateShortLabelFromNameKey(nameKey)
    if type(nameKey) ~= "string" then
        return nil
    end

    local suffix = string.match(nameKey, "^TEMPLATE_(.+)$")
    if not suffix or suffix == "" then
        return nil
    end

    local key = "BAR_TEMPLATE_" .. string.upper(suffix)
    local localized = ns.L[key]
    if localized and localized ~= "" and localized ~= key then
        return localized
    end
    return nil
end

local function GetFirstVisibleUtf8Char(text)
    local value = ns.Compat.Trim(text or "")
    if value == "" then
        return ""
    end

    local offset = 1
    while offset <= #value do
        local chunk = string.sub(value, offset)
        local char = string.match(chunk, "^[%z\1-\127\194-\244][\128-\191]*")
        if not char then
            break
        end

        local isWhitespace = string.match(char, "^%s$") ~= nil
        local isAsciiPunctuation = (#char == 1) and (string.match(char, "^[%p]$") ~= nil)
        if (not isWhitespace) and (not isAsciiPunctuation) then
            return char
        end

        offset = offset + #char
    end

    return GetFirstUtf8Char(value)
end

local function GetTemplateButtonText(template)
    local displayName = ns.Compat.Trim(template and template.displayName or "")
    if displayName ~= "" then
        local displayChar = GetFirstVisibleUtf8Char(displayName)
        if displayChar ~= "" then
            return displayChar
        end
    end

    local shortLabel = GetTemplateShortLabel(template and template.id)
    if shortLabel then
        return shortLabel
    end

    local fromNameKey = GetTemplateShortLabelFromNameKey(template and template.nameKey)
    if fromNameKey then
        return fromNameKey
    end

    local label = ns.TemplateStore:GetTemplateName(template)
    if ns.Compat.Trim(label) == "" then
        label = template.id or "?"
    end

    local firstChar = GetFirstVisibleUtf8Char(label)
    if firstChar ~= "" then
        return firstChar
    end

    return string.sub(tostring(label), 1, 1)
end

local function FindDefaultChannel(alias)
    local normalized = ns.Compat.NormalizeToken(alias or "")
    for _, channel in ipairs(DEFAULT_CHANNELS) do
        if channel.alias == normalized then
            return channel
        end
    end
    return nil
end

local function BuildEntries()
    local entries = {}

    for _, channel in ipairs(DEFAULT_CHANNELS) do
        entries[#entries + 1] = {
            entryType = "channel",
            alias = channel.alias,
            key = channel.key,
            color = channel.color,
            icon = channel.icon,
            width = CHANNEL_BUTTON_WIDTH,
        }
    end

    if ns.TemplateStore and ns.TemplateStore.GetTemplates then
        local templates = ns.TemplateStore:GetTemplates({
            includeDisabled = false,
            search = "",
        })

        for _, template in ipairs(templates) do
            local mappedChannel = FindDefaultChannel(template.defaultChannel)
            entries[#entries + 1] = {
                entryType = "template",
                templateId = template.id,
                label = GetTemplateButtonText(template),
                icon = (mappedChannel and mappedChannel.icon) or ((template.kind == "slash") and "Interface\\Icons\\INV_Misc_Note_03" or "Interface\\Icons\\INV_Scroll_03"),
                color = (mappedChannel and mappedChannel.color) or { 0.92, 0.94, 0.98 },
                width = CHANNEL_BUTTON_WIDTH,
            }
        end
    end

    return entries
end

local function GetBarWidth(entries)
    if not entries or #entries <= 0 then
        return 80
    end

    local width = BAR_SIDE_PADDING * 2
    for index, entry in ipairs(entries) do
        width = width + (entry.width or CHANNEL_BUTTON_WIDTH)
        if index < #entries then
            width = width + BUTTON_GAP
        end
    end
    return width
end

local function ApplyBackdrop(frame, style)
    ns.Theme:ApplyBackdrop(frame, style)
end

local function SetTransparentBackdrop(frame)
    if not frame or type(frame.SetBackdrop) ~= "function" then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
end

local function ApplyLabelShadow(fontString)
    if not fontString then
        return
    end
    fontString:SetShadowColor(0, 0, 0, 0.9)
    fontString:SetShadowOffset(1, -1)
end

function ChatBar:SaveAnchor()
    if not self.frame then
        return
    end

    local point, relativeFrame, relativePoint, x, y = self.frame:GetPoint(1)
    local anchor = ns.db.chatBar.anchor
    anchor.point = point or "TOPLEFT"
    anchor.relativePoint = relativePoint or "TOPLEFT"
    anchor.x = x or 0
    anchor.y = y or 0
    anchor.relativeToChatFrame = (relativeFrame == ChatFrame1)
end

function ChatBar:ApplyAnchor()
    if not self.frame then
        return
    end

    local anchor = ns.db.chatBar.anchor
    local relativeFrame = UIParent
    if anchor.relativeToChatFrame and ChatFrame1 then
        relativeFrame = ChatFrame1
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        anchor.point or "TOPLEFT",
        relativeFrame,
        anchor.relativePoint or "TOPLEFT",
        anchor.x or 0,
        anchor.y or 0
    )
end

function ChatBar:SetLocked(locked, silent)
    ns.db.chatBar.locked = locked and true or false
    if silent then
        return
    end

    if ns.db.chatBar.locked then
        ns.Compat.Print(ns.L["INFO_BAR_LOCKED"])
    else
        ns.Compat.Print(ns.L["INFO_BAR_UNLOCKED"])
    end
end

function ChatBar:ToggleLocked()
    self:SetLocked(not ns.db.chatBar.locked)
end

function ChatBar:SetEnabled(enabled, silent)
    ns.db.chatBar.enabled = enabled and true or false
    if self.frame then
        if ns.db.chatBar.enabled then
            self.frame:Show()
        else
            self.frame:Hide()
        end
    end

    if silent then
        return
    end
    if ns.db.chatBar.enabled then
        ns.Compat.Print(ns.L["INFO_BAR_SHOWN"])
    else
        ns.Compat.Print(ns.L["INFO_BAR_HIDDEN"])
    end
end

function ChatBar:SetStyle(style, silent)
    local normalized = ns.Compat.NormalizeToken(style or "")
    if normalized ~= "text" and normalized ~= "icon" then
        ns.Compat.Print(ns.L["ERROR_BAR_STYLE_USAGE"])
        return false
    end

    ns.db.chatBar.style = normalized
    if self.frame then
        self:Refresh()
    end

    if not silent then
        local label = (normalized == "icon") and ns.L["BAR_STYLE_ICON"] or ns.L["BAR_STYLE_TEXT"]
        ns.Compat.Print(string.format(ns.L["INFO_BAR_STYLE_NOW"], label))
    end
    return true
end

function ChatBar:ToggleStyle()
    local nextStyle = (ns.db.chatBar.style == "icon") and "text" or "icon"
    self:SetStyle(nextStyle)
end

function ChatBar:IsBackgroundEnabled()
    return ns.db.chatBar.showBackground == true
end

function ChatBar:SetBackgroundEnabled(enabled, silent)
    ns.db.chatBar.showBackground = enabled and true or false
    if self.frame then
        self:Refresh()
    end

    if silent then
        return
    end
    if self:IsBackgroundEnabled() then
        ns.Compat.Print(ns.L["INFO_BAR_BG_ON"])
    else
        ns.Compat.Print(ns.L["INFO_BAR_BG_OFF"])
    end
end

function ChatBar:ToggleBackground()
    self:SetBackgroundEnabled(not self:IsBackgroundEnabled())
end

function ChatBar:GetIconSetLabel(iconSet)
    if iconSet == "class" then
        return ns.L["BAR_ICONSET_CLASS"]
    end
    if iconSet == "mono" then
        return ns.L["BAR_ICONSET_MONO"]
    end
    return ns.L["BAR_ICONSET_COLOR"]
end

function ChatBar:SetIconSet(iconSet, silent)
    local normalized = ns.Compat.NormalizeToken(iconSet or "")
    if normalized ~= "color" and normalized ~= "class" and normalized ~= "mono" then
        ns.Compat.Print(ns.L["ERROR_BAR_ICONSET_USAGE"])
        return false
    end

    ns.db.chatBar.iconSet = normalized
    if self.frame then
        self:Refresh()
    end

    if not silent then
        ns.Compat.Print(string.format(ns.L["INFO_BAR_ICONSET_NOW"], self:GetIconSetLabel(normalized)))
    end
    return true
end

function ChatBar:ToggleIconSet()
    local current = ns.db.chatBar.iconSet or "color"
    local nextIndex = 1
    for index, value in ipairs(ICON_SET_ORDER) do
        if value == current then
            nextIndex = index + 1
            break
        end
    end
    if nextIndex > #ICON_SET_ORDER then
        nextIndex = 1
    end
    self:SetIconSet(ICON_SET_ORDER[nextIndex])
end

function ChatBar:HandleSlash(rest)
    local input = ns.Compat.Trim(rest or "")
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = ns.Compat.NormalizeToken(command or "")
    argument = ns.Compat.NormalizeToken(argument or "")

    if command == "" then
        self:SetEnabled(not ns.db.chatBar.enabled)
        return
    end

    if command == "lock" then
        self:SetLocked(true)
        return
    end
    if command == "unlock" then
        self:SetLocked(false)
        return
    end
    if command == "togglelock" then
        self:ToggleLocked()
        return
    end
    if command == "show" then
        self:SetEnabled(true)
        return
    end
    if command == "hide" then
        self:SetEnabled(false)
        return
    end
    if command == "style" then
        if argument == "" then
            local current = (ns.db.chatBar.style == "icon") and ns.L["BAR_STYLE_ICON"] or ns.L["BAR_STYLE_TEXT"]
            ns.Compat.Print(string.format(ns.L["INFO_BAR_STYLE_NOW"], current))
            return
        end
        self:SetStyle(argument)
        return
    end
    if command == "togglestyle" then
        self:ToggleStyle()
        return
    end
    if command == "iconset" then
        if argument == "" then
            local current = self:GetIconSetLabel(ns.db.chatBar.iconSet or "color")
            ns.Compat.Print(string.format(ns.L["INFO_BAR_ICONSET_NOW"], current))
            return
        end
        self:SetIconSet(argument)
        return
    end
    if command == "toggleiconset" then
        self:ToggleIconSet()
        return
    end
    if command == "bg" or command == "background" then
        if argument == "" then
            if self:IsBackgroundEnabled() then
                ns.Compat.Print(ns.L["INFO_BAR_BG_ON"])
            else
                ns.Compat.Print(ns.L["INFO_BAR_BG_OFF"])
            end
            return
        end

        if argument == "on" or argument == "enable" or argument == "enabled" or argument == "true" or argument == "1" then
            self:SetBackgroundEnabled(true)
            return
        end
        if argument == "off" or argument == "disable" or argument == "disabled" or argument == "false" or argument == "0" then
            self:SetBackgroundEnabled(false)
            return
        end
        if argument == "toggle" then
            self:ToggleBackground()
            return
        end

        ns.Compat.Print(ns.L["ERROR_BAR_BG_USAGE"])
        return
    end
    if command == "togglebg" then
        self:ToggleBackground()
        return
    end

    ns.Compat.Print(ns.L["ERROR_BAR_USAGE"])
end

function ChatBar:EnsureButton(index)
    if self.buttons[index] then
        return self.buttons[index]
    end

    local frame = self.frame
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetHeight(BUTTON_HEIGHT)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    ApplyLabelShadow(button.label)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetSize(14, 14)

    button:SetScript("OnMouseUp", function(currentButton, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end
        if frame._chatEaseMoving then
            return
        end
        if GetTime() < (frame._chatEaseSuppressClickUntil or 0) then
            return
        end

        local entry = currentButton.entry
        if not entry then
            return
        end

        if entry.entryType == "template" then
            ns.CommandRouter:ExecuteTemplate(entry.templateId)
        else
            ns.CommandRouter:PrimeChannel(entry.alias)
        end
    end)
    button:SetScript("OnDragStart", function()
        if ns.db.chatBar.locked then
            return
        end
        frame:StartMoving()
        frame._chatEaseMoving = true
    end)
    button:SetScript("OnDragStop", function()
        if frame._chatEaseMoving then
            frame._chatEaseMoving = nil
            frame:StopMovingOrSizing()
            self:SaveAnchor()
            frame._chatEaseSuppressClickUntil = GetTime() + 0.15
        end
    end)
    button:SetScript("OnEnter", function(currentButton)
        if self:IsBackgroundEnabled() then
            ApplyBackdrop(currentButton, "buttonHover")
        end
        currentButton.label:SetTextColor(1, 1, 1, 1)
        currentButton.icon:SetVertexColor(1, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function(currentButton)
        if self:IsBackgroundEnabled() then
            ApplyBackdrop(currentButton, "button")
        else
            SetTransparentBackdrop(currentButton)
        end
        local color = currentButton.baseColor or { 1, 1, 1 }
        currentButton.label:SetTextColor(color[1], color[2], color[3], 1)
        local setName = ns.db.chatBar.iconSet or "color"
        if setName == "class" then
            local classC = ns.Theme:GetColor("class")
            currentButton.icon:SetVertexColor(classC[1], classC[2], classC[3], 1)
        elseif setName == "mono" then
            currentButton.icon:SetVertexColor(0.9, 0.9, 0.9, 1)
        else
            currentButton.icon:SetVertexColor(color[1], color[2], color[3], 1)
        end
    end)

    self.buttons[index] = button
    return button
end

function ChatBar:Refresh()
    if not self.frame then
        return
    end

    local entries = BuildEntries()
    local width = GetBarWidth(entries)
    self.frame:SetWidth(width)

    local scale = tonumber(ns.db.chatBar.scale) or 1
    if scale < 0.5 then
        scale = 0.5
    elseif scale > 2 then
        scale = 2
    end
    self.frame:SetScale(scale)

    local isIconStyle = (ns.db.chatBar.style == "icon")
    local showBackground = self:IsBackgroundEnabled()
    local iconSet = ns.db.chatBar.iconSet or "color"
    local classColor = ns.Theme:GetColor("class")
    local accent = ns.Theme:GetColor("accent") or { 1, 0.85, 0.25, 1 }
    local xOffset = BAR_SIDE_PADDING

    if showBackground then
        ApplyBackdrop(self.frame, "section")
    else
        SetTransparentBackdrop(self.frame)
    end

    for index, entry in ipairs(entries) do
        local button = self:EnsureButton(index)
        button.entry = entry

        local baseColor = entry.color or { accent[1], accent[2], accent[3] }
        button.baseColor = baseColor

        button:SetSize(entry.width or CHANNEL_BUTTON_WIDTH, BUTTON_HEIGHT)
        button:ClearAllPoints()
        button:SetPoint("LEFT", self.frame, "LEFT", xOffset, 0)
        xOffset = xOffset + (entry.width or CHANNEL_BUTTON_WIDTH) + BUTTON_GAP

        if showBackground then
            ApplyBackdrop(button, "button")
        else
            SetTransparentBackdrop(button)
        end

        if entry.entryType == "template" then
            button.label:SetText(entry.label or entry.templateId or "?")
        else
            button.label:SetText(ns.L[entry.key] or "?")
        end
        button.label:SetTextColor(baseColor[1], baseColor[2], baseColor[3], 1)

        button.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if iconSet == "class" then
            button.icon:SetVertexColor(classColor[1], classColor[2], classColor[3], 1)
        elseif iconSet == "mono" then
            button.icon:SetVertexColor(0.9, 0.9, 0.9, 1)
        else
            button.icon:SetVertexColor(baseColor[1], baseColor[2], baseColor[3], 1)
        end

        if isIconStyle then
            button.icon:Show()
            button.label:Hide()
        else
            button.icon:Hide()
            button.label:Show()
        end

        button:Show()
    end

    for index = #entries + 1, #self.buttons do
        self.buttons[index]:Hide()
    end

    self:ApplyAnchor()

    if ns.db.chatBar.enabled then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function ChatBar:Init()
    if self.frame then
        self:Refresh()
        return
    end

    local frame = CreateFrame("Frame", "ChatEaseQuickBar", UIParent, "BackdropTemplate")
    frame:SetSize(GetBarWidth(BuildEntries()), 24)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    ApplyBackdrop(frame, "section")

    frame:SetScript("OnMouseDown", function(currentFrame, button)
        if button == "RightButton" then
            self:ToggleLocked()
            return
        end
    end)
    frame:SetScript("OnDragStart", function(currentFrame)
        if ns.db.chatBar.locked then
            return
        end
        currentFrame:StartMoving()
        currentFrame._chatEaseMoving = true
    end)
    frame:SetScript("OnDragStop", function(currentFrame)
        if currentFrame._chatEaseMoving then
            currentFrame._chatEaseMoving = nil
            currentFrame:StopMovingOrSizing()
            self:SaveAnchor()
            currentFrame._chatEaseSuppressClickUntil = GetTime() + 0.15
        end
    end)
    frame:SetScript("OnMouseUp", function(currentFrame)
        if currentFrame._chatEaseMoving then
            currentFrame._chatEaseMoving = nil
            currentFrame:StopMovingOrSizing()
            self:SaveAnchor()
            currentFrame._chatEaseSuppressClickUntil = GetTime() + 0.15
        end
    end)

    self.frame = frame
    self:Refresh()
end
