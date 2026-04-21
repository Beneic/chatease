local _, ns = ...

local ConfigPanel = {
    frame = nil,
    templateButtons = {},
    selectedTemplateId = nil,
    creatingNew = false,
    refreshing = false,
    readonlySelected = false,
    activeSection = "general",
}
ns.ConfigPanel = ConfigPanel

local READONLY_CHANNEL_PREFIX = "__channel_"
local DEFAULT_CHANNEL_ENTRIES = {
    { alias = "world", key = "BAR_WORLD", slash = "/1 " },
    { alias = "s", key = "BAR_SAY", slash = "/s " },
    { alias = "y", key = "BAR_YELL", slash = "/y " },
    { alias = "p", key = "BAR_PARTY", slash = "/p " },
    { alias = "g", key = "BAR_GUILD", slash = "/g " },
    { alias = "i", key = "BAR_OFFICER", slash = "/i " },
    { alias = "w", key = "BAR_WHISPER", slash = "/r " },
    { alias = "raid", key = "BAR_RAID", slash = "/raid " },
    { alias = "rw", key = "BAR_INSTANCE", slash = "/rw " },
}
local COMPACT_TEMPLATE_LABEL_KEYS = {
    pull = "BAR_TEMPLATE_PULL",
    ready = "BAR_TEMPLATE_READY",
    summon = "BAR_TEMPLATE_SUMMON",
    buff = "BAR_TEMPLATE_BUFF",
    roll = "BAR_TEMPLATE_ROLL",
}

local function BuildReadonlyChannelId(alias)
    return READONLY_CHANNEL_PREFIX .. tostring(alias or "")
end

local function ParseReadonlyChannelAlias(entryId)
    if type(entryId) ~= "string" then
        return nil
    end
    return string.match(entryId, "^" .. READONLY_CHANNEL_PREFIX .. "(.+)$")
end

local function IsReadonlyChannelEntry(entryId)
    return ParseReadonlyChannelAlias(entryId) ~= nil
end

local function FindDefaultChannelEntry(alias)
    for _, entry in ipairs(DEFAULT_CHANNEL_ENTRIES) do
        if entry.alias == alias then
            return entry
        end
    end
    return nil
end

local function BuildDefaultChannelAliasExample()
    local aliases = {}
    for _, entry in ipairs(DEFAULT_CHANNEL_ENTRIES) do
        aliases[#aliases + 1] = entry.alias
    end
    return table.concat(aliases, " / ")
end

local function ApplyBackdrop(frame, style)
    ns.Theme:ApplyBackdrop(frame, style)
end

local function GetListLabel(key, fallback)
    if ns.L and ns.L[key] then
        return ns.L[key]
    end
    return fallback
end

local function GetCompactTemplateListName(template)
    if not template then
        return ""
    end

    if template.displayName and ns.Compat.Trim(template.displayName) ~= "" then
        return template.displayName
    end

    local compactLabelKey = COMPACT_TEMPLATE_LABEL_KEYS[template.id or ""]
    if compactLabelKey and ns.L[compactLabelKey] then
        return ns.L[compactLabelKey]
    end

    return ns.TemplateStore:GetTemplateName(template)
end

local function Clamp01(value)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function EnsureReadableRgb(r, g, b, minLuma)
    local rr = Clamp01(tonumber(r) or 1)
    local gg = Clamp01(tonumber(g) or 1)
    local bb = Clamp01(tonumber(b) or 1)
    local target = tonumber(minLuma) or 0.82

    local luma = (0.2126 * rr) + (0.7152 * gg) + (0.0722 * bb)
    if luma >= target then
        return rr, gg, bb
    end

    local mix = (target - luma) / math.max(0.001, 1 - luma)
    rr = rr + (1 - rr) * mix
    gg = gg + (1 - gg) * mix
    bb = bb + (1 - bb) * mix

    return Clamp01(rr), Clamp01(gg), Clamp01(bb)
end

local function SetReadableText(fontString, r, g, b, a, minLuma)
    if not fontString then
        return
    end

    local rr, gg, bb = EnsureReadableRgb(r, g, b, minLuma)

    if not fontString._chatEaseOutlineApplied and fontString.GetFont and fontString.SetFont then
        local fontPath, fontSize = fontString:GetFont()
        if fontPath and fontSize then
            fontString:SetFont(fontPath, fontSize, "OUTLINE")
            fontString._chatEaseOutlineApplied = true
        end
    end
    fontString:SetTextColor(rr, gg, bb, a or 1)
    fontString:SetShadowColor(0, 0, 0, 0.95)
    fontString:SetShadowOffset(1, -1)
end

local function SetReadableThemeText(fontString, colorName, minLuma, alpha)
    local color = ns.Theme:GetColor(colorName) or { 1, 1, 1, 1 }
    SetReadableText(fontString, color[1], color[2], color[3], alpha or color[4] or 1, minLuma)
end

local function ApplyConfigButtonFrame(button, style, borderAlpha)
    if not button then
        return
    end

    ApplyBackdrop(button, style or "button")
    if type(button.SetBackdropBorderColor) == "function" then
        local accent = ns.Theme:GetColor("accent") or { 1, 1, 1, 1 }
        button:SetBackdropBorderColor(accent[1], accent[2], accent[3], borderAlpha or 0.92)
    end
end

local function GetConfigButtonFontString(button)
    if not button then
        return nil
    end

    if button.GetFontString then
        local region = button:GetFontString()
        if region then
            return region
        end
    end

    return button.Text
end

local function ApplyConfigButtonTextStyle(button, enabled)
    local fontString = GetConfigButtonFontString(button)
    if not fontString then
        return
    end

    SetReadableThemeText(fontString, enabled and "accent" or "textMuted", enabled and 0.9 or 0.75, enabled and 1 or 0.92)
end

local function RefreshConfigButtonVisual(button)
    if not button then
        return
    end

    if button._chatEaseSelected then
        ApplyConfigButtonFrame(button, "buttonPressed", 1)
        ApplyConfigButtonTextStyle(button, true)
        return
    end

    if button:IsEnabled() then
        if button:IsMouseOver() then
            ApplyConfigButtonFrame(button, "buttonHover", 1)
        else
            ApplyConfigButtonFrame(button, "button", 0.96)
        end
    else
        ApplyConfigButtonFrame(button, "button", 0.88)
        if type(button.SetBackdropBorderColor) == "function" then
            local borderSoft = ns.Theme:GetColor("borderSoft") or { 0.6, 0.6, 0.6, 1 }
            button:SetBackdropBorderColor(borderSoft[1], borderSoft[2], borderSoft[3], 0.95)
        end
    end

    ApplyConfigButtonTextStyle(button, button:IsEnabled())
end

local function SkinConfigButton(button)
    if not button then
        return
    end

    ns.Theme:SkinButton(button)
    RefreshConfigButtonVisual(button)

    if button._chatEaseConfigButtonHooked then
        return
    end

    button:HookScript("OnEnter", function(currentButton)
        if currentButton:IsEnabled() then
            ApplyConfigButtonFrame(currentButton, "buttonHover", 1)
        end
        ApplyConfigButtonTextStyle(currentButton, currentButton:IsEnabled())
    end)
    button:HookScript("OnLeave", function(currentButton)
        RefreshConfigButtonVisual(currentButton)
    end)
    button:HookScript("OnMouseDown", function(currentButton)
        if currentButton:IsEnabled() then
            ApplyConfigButtonFrame(currentButton, "buttonPressed", 1)
        end
        ApplyConfigButtonTextStyle(currentButton, currentButton:IsEnabled())
    end)
    button:HookScript("OnMouseUp", function(currentButton)
        RefreshConfigButtonVisual(currentButton)
    end)
    button:HookScript("OnEnable", function(currentButton)
        RefreshConfigButtonVisual(currentButton)
    end)
    button:HookScript("OnDisable", function(currentButton)
        RefreshConfigButtonVisual(currentButton)
    end)
    button:HookScript("OnShow", function(currentButton)
        RefreshConfigButtonVisual(currentButton)
    end)

    button._chatEaseConfigButtonHooked = true
end

local function SetCheckLabel(checkButton, text)
    if not checkButton._label then
        local labelParent = checkButton:GetParent() or checkButton
        local label = labelParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)
        checkButton._label = label
    end
    checkButton._label:SetText(text)
    SetReadableThemeText(checkButton._label, "class", 0.78, 1)
end

local function CreateCheckButton(parent)
    local checkButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkButton:SetSize(26, 26)
    ns.Theme:SkinCheckButton(checkButton)
    return checkButton
end

local function CreateLabel(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    label:SetText(text)
    SetReadableThemeText(label, "class", 0.78, 1)
    return label
end

local function CreateWrappedText(parent, fontObject, lineSpacing)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetWordWrap(true)
    if type(label.SetSpacing) == "function" then
        label:SetSpacing(lineSpacing or 0)
    end
    SetReadableThemeText(label, "class", 0.8, 1)
    return label
end

local function CreateEditBox(parent, width)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate,BackdropTemplate")
    editBox:SetSize(width, 22)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)
    ns.Theme:SkinEditBox(editBox)
    return editBox
end

local function UpdateEditBoxPlaceholder(editBox)
    if not editBox or not editBox._chatEasePlaceholder then
        return
    end

    local hasText = ns.Compat.Trim(editBox:GetText() or "") ~= ""
    local shouldShow = (not hasText) and (not editBox:HasFocus())

    if shouldShow then
        editBox._chatEasePlaceholder:Show()
    else
        editBox._chatEasePlaceholder:Hide()
    end
end

local function SetEditBoxPlaceholder(editBox, text)
    if not editBox then
        return
    end

    if not editBox._chatEasePlaceholder then
        local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        placeholder:SetPoint("LEFT", editBox, "LEFT", 8, 0)
        placeholder:SetPoint("RIGHT", editBox, "RIGHT", -8, 0)
        placeholder:SetJustifyH("LEFT")
        SetReadableThemeText(placeholder, "accent", 0.8, 0.86)
        editBox._chatEasePlaceholder = placeholder

        editBox:HookScript("OnTextChanged", function(currentBox)
            UpdateEditBoxPlaceholder(currentBox)
        end)
        editBox:HookScript("OnEditFocusGained", function(currentBox)
            UpdateEditBoxPlaceholder(currentBox)
        end)
        editBox:HookScript("OnEditFocusLost", function(currentBox)
            UpdateEditBoxPlaceholder(currentBox)
        end)
        editBox:HookScript("OnShow", function(currentBox)
            UpdateEditBoxPlaceholder(currentBox)
        end)
    end

    editBox._chatEasePlaceholder:SetText(text or "")
    UpdateEditBoxPlaceholder(editBox)
end

local function SetControlEnabled(control, enabled)
    if control.SetEnabled then
        control:SetEnabled(enabled)
    elseif enabled and control.Enable then
        control:Enable()
    elseif not enabled and control.Disable then
        control:Disable()
    end

    if control.EnableMouse then
        control:EnableMouse(enabled and true or false)
    end

    if control._label then
        control._label:SetAlpha(1)
    end
    if control.label then
        control.label:SetAlpha(1)
    end
end

local function EnsureListButton(self, index)
    if self.templateButtons[index] then
        return self.templateButtons[index]
    end

    local button = CreateFrame("Button", nil, self.frame.templateListContent, "BackdropTemplate")
    SkinConfigButton(button)
    button:SetHeight(22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.label:SetJustifyH("LEFT")
    SetReadableThemeText(button.label, "accent", 0.86, 1)

    button:SetScript("OnClick", function(currentButton)
        self.selectedTemplateId = currentButton.templateId
        self.creatingNew = false
        self:Refresh()
    end)
    function button:SetButtonText(text)
        self.label:SetText(text or "")
    end
    self.templateButtons[index] = button
    return button
end

local function SkinTitleBar(frame, closeHandler)
    frame.titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    frame.titleBar:SetHeight(22)
    ApplyBackdrop(frame.titleBar, "section")

    frame.TitleText = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.TitleText:SetPoint("CENTER", frame.titleBar, "CENTER", 0, 0)
    SetReadableThemeText(frame.TitleText, "accent", 0.88, 1)

    frame.closeButton = CreateFrame("Button", nil, frame.titleBar, "BackdropTemplate")
    frame.closeButton:SetSize(18, 18)
    frame.closeButton:SetPoint("RIGHT", frame.titleBar, "RIGHT", -2, 0)
    ns.Theme:SkinButton(frame.closeButton)

    frame.closeButton.text = frame.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.closeButton.text:SetPoint("CENTER", frame.closeButton, "CENTER", 0, 0)
    frame.closeButton.text:SetText("×")
    SetReadableText(frame.closeButton.text, 1, 0.35, 0.35, 1, 0.82)

    frame.closeButton:SetScript("OnEnter", function(button)
        ApplyBackdrop(button, "buttonHover")
        SetReadableText(button.text, 1, 0.62, 0.62, 1, 0.9)
    end)
    frame.closeButton:SetScript("OnLeave", function(button)
        ApplyBackdrop(button, "button")
        SetReadableText(button.text, 1, 0.45, 0.45, 1, 0.86)
    end)
    frame.closeButton:SetScript("OnClick", closeHandler)
end

local function GetEditorId(self)
    if self.selectedTemplateId and self.selectedTemplateId ~= "" then
        return self.selectedTemplateId
    end

    return ns.Compat.NormalizeToken(self.frame.idBox:GetText() or "")
end

function ConfigPanel:SetEditorReadonly(readonly)
    self.readonlySelected = readonly and true or false

    local editable = not self.readonlySelected
    SetControlEnabled(self.frame.idBox, editable)
    SetControlEnabled(self.frame.nameBox, editable)
    SetControlEnabled(self.frame.channelBox, editable)
    SetControlEnabled(self.frame.contentBox, editable)
    SetControlEnabled(self.frame.enabledCheck, editable)
    SetControlEnabled(self.frame.slashCommandCheck, editable)
    SetControlEnabled(self.frame.requireRWCheck, editable)
    SetControlEnabled(self.frame.charOverrideCheck, editable)
    SetControlEnabled(self.frame.charEnabledCheck, editable)
    SetControlEnabled(self.frame.charChannelBox, editable)
    SetControlEnabled(self.frame.charOrderBox, editable)
    SetControlEnabled(self.frame.saveButton, editable)
    SetControlEnabled(self.frame.deleteButton, editable)
    SetControlEnabled(self.frame.upButton, editable)
    SetControlEnabled(self.frame.downButton, editable)
end

function ConfigPanel:LoadReadonlyChannelIntoEditor(entryId)
    local alias = ParseReadonlyChannelAlias(entryId)
    local channel = FindDefaultChannelEntry(alias)
    if not channel then
        self:ClearEditor()
        return
    end

    local displayName = ns.L[channel.key] or string.upper(channel.alias)

    self:SetEditorReadonly(true)
    self.frame.idBox:SetText(channel.alias)
    self.frame.nameBox:SetText(displayName)
    self.frame.channelBox:SetText(channel.alias)
    self.frame.contentBox:SetText(channel.slash or "")
    self.frame.enabledCheck:SetChecked(true)
    self.frame.slashCommandCheck:SetChecked(true)
    self.frame.requireRWCheck:SetChecked(channel.alias == "rw")
    self.frame.charOverrideCheck:SetChecked(false)
    self.frame.charEnabledCheck:SetChecked(true)
    self.frame.charChannelBox:SetText("")
    self.frame.charOrderBox:SetText("")
end

function ConfigPanel:ClearEditor()
    self:SetEditorReadonly(false)
    SetControlEnabled(self.frame.idBox, true)
    self.frame.idBox:SetText("")
    self.frame.nameBox:SetText("")
    self.frame.channelBox:SetText("")
    self.frame.contentBox:SetText("")
    self.frame.enabledCheck:SetChecked(true)
    self.frame.slashCommandCheck:SetChecked(false)
    self.frame.requireRWCheck:SetChecked(false)
    self.frame.charOverrideCheck:SetChecked(false)
    self.frame.charEnabledCheck:SetChecked(true)
    self.frame.charChannelBox:SetText("")
    self.frame.charOrderBox:SetText("")
    self:UpdateTemplateKindControls()
    self:UpdateCharOverrideControls()
end

function ConfigPanel:LoadTemplateIntoEditor(templateId)
    local base = ns.TemplateStore:GetBaseTemplate(templateId)
    if not base then
        self:ClearEditor()
        return
    end

    local merged = ns.TemplateStore:GetTemplate(templateId)
    local override = ns.TemplateStore:GetCharOverride(templateId)

    self:SetEditorReadonly(false)
    SetControlEnabled(self.frame.idBox, false)
    self.frame.idBox:SetText(templateId)
    self.frame.nameBox:SetText(base.displayName or "")
    self.frame.channelBox:SetText(base.defaultChannel or "s")
    self.frame.contentBox:SetText(base.content or "")
    self.frame.enabledCheck:SetChecked(base.enabled ~= false)
    self.frame.slashCommandCheck:SetChecked(base.kind == "slash")
    self.frame.requireRWCheck:SetChecked(base.requirePermission == "rw")

    self.frame.charOverrideCheck:SetChecked(override ~= nil)
    if override and override.enabled ~= nil then
        self.frame.charEnabledCheck:SetChecked(override.enabled and true or false)
    else
        self.frame.charEnabledCheck:SetChecked(merged and merged.enabled ~= false)
    end
    self.frame.charChannelBox:SetText((override and override.defaultChannel) or "")
    self.frame.charOrderBox:SetText((override and override.order and tostring(override.order)) or "")

    self:UpdateTemplateKindControls()
    self:UpdateCharOverrideControls()
end

function ConfigPanel:UpdateTemplateKindControls()
    if self.readonlySelected then
        SetControlEnabled(self.frame.channelBox, false)
        SetControlEnabled(self.frame.requireRWCheck, false)
        return
    end

    local isSlash = self.frame.slashCommandCheck:GetChecked()
    SetControlEnabled(self.frame.channelBox, not isSlash)
    SetControlEnabled(self.frame.requireRWCheck, not isSlash)
    if isSlash then
        self.frame.requireRWCheck:SetChecked(false)
    end
end

function ConfigPanel:UpdateCharOverrideControls()
    if self.readonlySelected then
        SetControlEnabled(self.frame.charEnabledCheck, false)
        SetControlEnabled(self.frame.charChannelBox, false)
        SetControlEnabled(self.frame.charOrderBox, false)
        return
    end

    local enabled = self.frame.charOverrideCheck:GetChecked()
    SetControlEnabled(self.frame.charEnabledCheck, enabled)
    SetControlEnabled(self.frame.charChannelBox, enabled)
    SetControlEnabled(self.frame.charOrderBox, enabled)
end

function ConfigPanel:RefreshTemplateList()
    local needle = ns.Compat.NormalizeToken(self.frame.templateSearchBox:GetText() or "")
    local entries = {}

    for _, channel in ipairs(DEFAULT_CHANNEL_ENTRIES) do
        local channelName = ns.L[channel.key] or string.upper(channel.alias)
        local haystack = string.lower(channel.alias .. "\001" .. channelName .. "\001" .. (channel.slash or ""))
        if needle == "" or string.find(haystack, needle, 1, true) then
            table.insert(entries, {
                entryType = "channel",
                id = BuildReadonlyChannelId(channel.alias),
                alias = channel.alias,
                name = channelName,
            })
        end
    end

    local templates = ns.TemplateStore:GetTemplates({
        includeDisabled = true,
        search = "",
    })
    for _, template in ipairs(templates) do
        local templateName = GetCompactTemplateListName(template)
        local haystack = string.lower((template.id or "") .. "\001" .. (templateName or "") .. "\001" .. (template.content or ""))
        if needle == "" or string.find(haystack, needle, 1, true) then
            table.insert(entries, {
                entryType = "template",
                id = template.id,
                template = template,
            })
        end
    end

    local yOffset = 0
    local width = math.max(196, math.floor((self.frame.templateListScroll:GetWidth() or 220) - 4))
    for index, entry in ipairs(entries) do
        local button = EnsureListButton(self, index)
        button.templateId = entry.id
        if entry.entryType == "channel" then
            local readonlyLabel = GetListLabel("LABEL_LIST_READONLY", ns.L["LABEL_READONLY"] or "Read-only")
            local prefix = GetListLabel("LABEL_PRESET_CHANNEL", ns.L["LABEL_DEFAULT_CHANNEL"] or "Default Channel")
            button:SetButtonText(string.format("%s:%s [%s] (%s)", prefix, entry.name, entry.alias, readonlyLabel))
            SetReadableThemeText(button.label, "accent", 0.86, 1)
        else
            local template = entry.template
            local templateName = GetCompactTemplateListName(template)
            local suffix = ""
            if template.enabled == false then
                suffix = " (" .. GetListLabel("STATE_STOPPED", ns.L["STATE_DISABLED"] or "Disabled") .. ")"
            end
            local kindTag = (template.kind == "slash") and "/" or ""
            button:SetButtonText(string.format("%s [%s]%s%s", templateName, template.id, kindTag, suffix))
            SetReadableThemeText(button.label, "class", 0.82, 1)
        end

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.templateListContent, "TOPLEFT", 0, -yOffset)
        button:SetWidth(width)
        button:Show()
        yOffset = yOffset + 24
    end

    for index = #entries + 1, #self.templateButtons do
        self.templateButtons[index]:Hide()
    end

    self.frame.templateListContent:SetSize(width, math.max(20, yOffset))
end

function ConfigPanel:ApplySkin()
    if not self.frame then
        return
    end

    ns.Theme:SkinWindowFrame(self.frame)
    ApplyBackdrop(self.frame.body, "panel")
    ApplyBackdrop(self.frame.leftSection, "section")
    ApplyBackdrop(self.frame.middleSection, "section")
    ApplyBackdrop(self.frame.rightSection, "section")
    ApplyBackdrop(self.frame.aboutSection, "section")
    ApplyBackdrop(self.frame.templateListScrollBg, "input")
    ns.Theme:SkinScrollFrame(self.frame.templateListScroll)

    SkinConfigButton(self.frame.generalTabButton)
    SkinConfigButton(self.frame.aboutTabButton)
    SkinConfigButton(self.frame.newButton)
    SkinConfigButton(self.frame.upButton)
    SkinConfigButton(self.frame.downButton)
    SkinConfigButton(self.frame.saveButton)
    SkinConfigButton(self.frame.deleteButton)
    ns.Theme:SkinSlider(self.frame.scaleSlider)
    ns.Theme:SkinCheckButton(self.frame.permissionCheck)
    ns.Theme:SkinCheckButton(self.frame.lockPanelCheck)
    ns.Theme:SkinCheckButton(self.frame.barBackgroundCheck)
    ns.Theme:SkinCheckButton(self.frame.enabledCheck)
    ns.Theme:SkinCheckButton(self.frame.slashCommandCheck)
    ns.Theme:SkinCheckButton(self.frame.requireRWCheck)
    ns.Theme:SkinCheckButton(self.frame.charOverrideCheck)
    ns.Theme:SkinCheckButton(self.frame.charEnabledCheck)

    SetReadableThemeText(self.frame.generalLabel, "accent", 0.88, 1)
    SetReadableThemeText(self.frame.templatesLabel, "accent", 0.88, 1)
    SetReadableThemeText(self.frame.templateListLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.searchLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.idLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.nameLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.channelLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.contentLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.charChannelLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.charOrderLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.scaleLabel, "class", 0.82, 1)
    SetReadableThemeText(self.frame.scaleValue, "accent", 0.88, 1)
    SetReadableThemeText(self.frame.aboutTitle, "accent", 0.9, 1)
    SetReadableThemeText(self.frame.aboutMeta, "class", 0.82, 1)
    SetReadableThemeText(self.frame.aboutBody, "class", 0.8, 1)
    SetReadableThemeText(self.frame.aboutFooter, "accent", 0.82, 0.92)
end

function ConfigPanel:SaveCurrentTemplate()
    if IsReadonlyChannelEntry(self.selectedTemplateId) then
        ns.Compat.Print(ns.L["INFO_DEFAULT_CHANNEL_READONLY"])
        return
    end

    local id = GetEditorId(self)
    if id == "" then
        ns.Compat.Print(ns.L["ERROR_TEMPLATE_ID_REQUIRED"])
        return
    end

    local defaultChannel = ns.Compat.NormalizeToken(self.frame.channelBox:GetText() or "")
    if defaultChannel == "" then
        defaultChannel = "s"
    end

    local rawTemplate = {
        id = id,
        displayName = self.frame.nameBox:GetText() or "",
        defaultChannel = defaultChannel,
        content = self.frame.contentBox:GetText() or "",
        enabled = self.frame.enabledCheck:GetChecked() and true or false,
        kind = self.frame.slashCommandCheck:GetChecked() and "slash" or "chat",
        requirePermission = self.frame.requireRWCheck:GetChecked() and "rw" or nil,
    }

    local ok, errorKey = ns.TemplateStore:UpsertTemplate(rawTemplate)
    if not ok then
        ns.Compat.Print(ns.L[errorKey] or errorKey)
        return
    end

    if self.frame.charOverrideCheck:GetChecked() then
        local override = {
            enabled = self.frame.charEnabledCheck:GetChecked() and true or false,
        }

        local charChannel = ns.Compat.NormalizeToken(self.frame.charChannelBox:GetText() or "")
        if charChannel ~= "" then
            override.defaultChannel = charChannel
        end

        local orderText = ns.Compat.Trim(self.frame.charOrderBox:GetText() or "")
        if orderText ~= "" then
            local orderValue = tonumber(orderText)
            if orderValue then
                override.order = math.floor(orderValue)
            end
        end

        ns.TemplateStore:SetCharOverride(id, override)
    else
        ns.TemplateStore:ClearCharOverride(id)
    end

    self.selectedTemplateId = id
    self.creatingNew = false

    ns.Compat.Print(ns.L["INFO_TEMPLATE_SAVED"])
    if ns.ChatBar then
        ns.ChatBar:Refresh()
    end
    self:Refresh()
end

function ConfigPanel:DeleteCurrentTemplate()
    local id = self.selectedTemplateId
    if not id or id == "" then
        ns.Compat.Print(ns.L["ERROR_SELECT_TEMPLATE_FIRST"])
        return
    end
    if IsReadonlyChannelEntry(id) then
        ns.Compat.Print(ns.L["INFO_DEFAULT_CHANNEL_READONLY"])
        return
    end

    if ns.TemplateStore:DeleteTemplate(id) then
        self.selectedTemplateId = nil
        self.creatingNew = false
        self:ClearEditor()
        if ns.ChatBar then
            ns.ChatBar:Refresh()
        end
        self:Refresh()
        ns.Compat.Print(ns.L["INFO_TEMPLATE_DELETED"])
    end
end

function ConfigPanel:MoveTemplate(delta)
    if not self.selectedTemplateId then
        ns.Compat.Print(ns.L["ERROR_SELECT_TEMPLATE_FIRST"])
        return
    end
    if IsReadonlyChannelEntry(self.selectedTemplateId) then
        ns.Compat.Print(ns.L["INFO_DEFAULT_CHANNEL_READONLY"])
        return
    end

    if ns.TemplateStore:MoveTemplate(self.selectedTemplateId, delta) then
        if ns.ChatBar then
            ns.ChatBar:Refresh()
        end
        self:RefreshTemplateList()
    end
end

function ConfigPanel:SetActiveSection(section)
    if section ~= "about" then
        section = "general"
    end

    if self.activeSection == section then
        if self.frame then
            self:RefreshSectionVisibility()
        end
        return
    end

    self.activeSection = section
    if self.frame then
        self:Refresh()
    end
end

function ConfigPanel:RefreshSectionVisibility()
    if not self.frame then
        return
    end

    local isAbout = self.activeSection == "about"

    if self.frame.generalContent then
        self.frame.generalContent:SetShown(not isAbout)
    end
    if self.frame.middleSection then
        self.frame.middleSection:SetShown(not isAbout)
    end
    if self.frame.rightSection then
        self.frame.rightSection:SetShown(not isAbout)
    end
    if self.frame.aboutSection then
        self.frame.aboutSection:SetShown(isAbout)
    end

    if self.frame.generalTabButton then
        self.frame.generalTabButton._chatEaseSelected = not isAbout
        RefreshConfigButtonVisual(self.frame.generalTabButton)
    end
    if self.frame.aboutTabButton then
        self.frame.aboutTabButton._chatEaseSelected = isAbout
        RefreshConfigButtonVisual(self.frame.aboutTabButton)
    end
end

function ConfigPanel:StartNewTemplate()
    self.selectedTemplateId = nil
    self.creatingNew = true
    self:ClearEditor()
    self.frame.idBox:SetFocus()
end

function ConfigPanel:Refresh()
    if not self.frame then
        return
    end

    if self.refreshing then
        return
    end

    self.refreshing = true

    if self.frame.TitleText then
        local titleLabel = (self.activeSection == "about") and ns.L["LABEL_ABOUT"] or ns.L["LABEL_SETTINGS"]
        self.frame.TitleText:SetText(string.format("%s · %s", ns.L["ADDON_TITLE"], titleLabel))
        SetReadableThemeText(self.frame.TitleText, "accent", 0.88, 1)
    end

    self.frame.generalTabButton:SetText(ns.L["LABEL_GENERAL"])
    self.frame.aboutTabButton:SetText(ns.L["LABEL_ABOUT"])
    self.frame.generalLabel:SetText(ns.L["LABEL_GENERAL"])
    self.frame.templatesLabel:SetText(ns.L["LABEL_TEMPLATE_MANAGER"])
    self.frame.templateListLabel:SetText(ns.L["LABEL_TEMPLATE_LIST"])
    self.frame.searchLabel:SetText(ns.L["LABEL_SEARCH"])

    local addonVersion = "0.1.0"
    local addonNotes = ns.L["WARN_INTERFACE_VERSION"]
    local addonAuthor = "布兰卡德-太古龙"
    if type(GetAddOnMetadata) == "function" then
        local metadataVersion = GetAddOnMetadata("ChatEase", "Version")
        if metadataVersion and metadataVersion ~= "" then
            addonVersion = metadataVersion
        end

        local metadataNotes = GetAddOnMetadata("ChatEase", "Notes")
        if metadataNotes and metadataNotes ~= "" then
            addonNotes = metadataNotes
        end

        local metadataAuthor = GetAddOnMetadata("ChatEase", "Author")
        if metadataAuthor and metadataAuthor ~= "" then
            addonAuthor = metadataAuthor
        end
    end

    self.frame.aboutTitle:SetText(ns.L["ADDON_TITLE"])
    self.frame.aboutMeta:SetText(string.format(
        "%s: %s\n%s: %s\n%s: %s",
        ns.L["ABOUT_VERSION_LABEL"],
        addonVersion,
        ns.L["ABOUT_AUTHOR_LABEL"],
        addonAuthor,
        ns.L["ABOUT_NOTES_LABEL"],
        addonNotes
    ))
    self.frame.aboutBody:SetText(string.format(
        "%s\n\n%s\n%s\n\n%s\n%s",
        ns.L["ABOUT_INTRO"],
        ns.L["ABOUT_HIGHLIGHTS_TITLE"],
        ns.L["ABOUT_HIGHLIGHTS"],
        ns.L["ABOUT_USAGE_TITLE"],
        ns.L["ABOUT_USAGE"]
    ))
    self.frame.aboutFooter:SetText(ns.L["WARN_INTERFACE_VERSION"])

    SetCheckLabel(self.frame.permissionCheck, ns.L["LABEL_PERMISSION_ERRORS"])
    SetCheckLabel(self.frame.lockPanelCheck, ns.L["LABEL_LOCK_BAR"])
    SetCheckLabel(self.frame.barBackgroundCheck, ns.L["LABEL_BAR_BACKGROUND"])
    SetCheckLabel(self.frame.enabledCheck, ns.L["LABEL_TEMPLATE_ENABLED"])
    SetCheckLabel(self.frame.slashCommandCheck, ns.L["LABEL_TEMPLATE_SLASH_COMMAND"])
    SetCheckLabel(self.frame.requireRWCheck, ns.L["LABEL_TEMPLATE_REQUIRE_RW"])
    SetCheckLabel(self.frame.charOverrideCheck, ns.L["LABEL_CHAR_OVERRIDE"])
    SetCheckLabel(self.frame.charEnabledCheck, ns.L["LABEL_CHAR_ENABLED"])

    self.frame.permissionCheck:SetChecked(ns.db.showPermissionErrors ~= false)
    self.frame.lockPanelCheck:SetChecked(ns.db.chatBar and ns.db.chatBar.locked == true)
    self.frame.barBackgroundCheck:SetChecked(ns.db.chatBar and ns.db.chatBar.showBackground == true)
    self.frame.scaleLabel:SetText(ns.L["LABEL_BAR_SCALE"])
    self.frame.scaleValue:SetText(string.format("%.2f", (ns.db.chatBar and ns.db.chatBar.scale) or 1))
    self.frame.scaleSlider:SetValue((ns.db.chatBar and ns.db.chatBar.scale) or 1)

    self.frame.idLabel:SetText(ns.L["LABEL_TEMPLATE_ID"])
    self.frame.nameLabel:SetText(ns.L["LABEL_TEMPLATE_NAME"])
    self.frame.channelLabel:SetText(ns.L["LABEL_TEMPLATE_CHANNEL"])
    self.frame.contentLabel:SetText(ns.L["LABEL_TEMPLATE_CONTENT"])
    self.frame.charChannelLabel:SetText(ns.L["LABEL_CHAR_CHANNEL"])
    self.frame.charOrderLabel:SetText(ns.L["LABEL_CHAR_ORDER"])

    SetEditBoxPlaceholder(self.frame.idBox, ns.L["LABEL_TEMPLATE_ID"])
    SetEditBoxPlaceholder(self.frame.nameBox, ns.L["LABEL_TEMPLATE_NAME"])
    SetEditBoxPlaceholder(self.frame.channelBox, BuildDefaultChannelAliasExample())
    SetEditBoxPlaceholder(self.frame.contentBox, ns.L["LABEL_TEMPLATE_CONTENT"])
    SetEditBoxPlaceholder(self.frame.charChannelBox, ns.L["LABEL_CHAR_CHANNEL"])
    SetEditBoxPlaceholder(self.frame.charOrderBox, "1 - 999")
    SetEditBoxPlaceholder(self.frame.templateSearchBox, ns.L["LABEL_SEARCH"])

    self.frame.newButton:SetText(ns.L["LABEL_NEW"])
    self.frame.saveButton:SetText(ns.L["LABEL_SAVE"])
    self.frame.deleteButton:SetText(ns.L["LABEL_DELETE"])
    self.frame.upButton:SetText(ns.L["LABEL_MOVE_UP"])
    self.frame.downButton:SetText(ns.L["LABEL_MOVE_DOWN"])

    self:ApplySkin()
    self:RefreshSectionVisibility()
    self:RefreshTemplateList()

    if self.selectedTemplateId and IsReadonlyChannelEntry(self.selectedTemplateId) then
        self:LoadReadonlyChannelIntoEditor(self.selectedTemplateId)
    elseif self.selectedTemplateId and ns.TemplateStore:GetBaseTemplate(self.selectedTemplateId) then
        self:LoadTemplateIntoEditor(self.selectedTemplateId)
    elseif self.creatingNew then
        self:SetEditorReadonly(false)
        SetControlEnabled(self.frame.idBox, true)
    else
        self:ClearEditor()
    end

    self.refreshing = false
end

function ConfigPanel:Init()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ChatEaseConfigPanel", UIParent, "BackdropTemplate")
    frame:SetSize(860, 620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 40, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(currentFrame)
        currentFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(currentFrame)
        currentFrame:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow", function()
        self:Refresh()
    end)
    ns.Theme:SkinWindowFrame(frame)
    SkinTitleBar(frame, function()
        self:Hide()
    end)

    frame.body = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -36)
    frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    ApplyBackdrop(frame.body, "panel")

    frame.leftSection = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    frame.leftSection:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 10, -8)
    frame.leftSection:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 10, 10)
    frame.leftSection:SetWidth(258)
    ApplyBackdrop(frame.leftSection, "section")

    frame.middleSection = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    frame.middleSection:SetPoint("TOPLEFT", frame.leftSection, "TOPRIGHT", 8, 0)
    frame.middleSection:SetPoint("BOTTOMLEFT", frame.leftSection, "BOTTOMRIGHT", 8, 0)
    frame.middleSection:SetWidth(300)
    ApplyBackdrop(frame.middleSection, "section")

    frame.rightSection = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    frame.rightSection:SetPoint("TOPLEFT", frame.middleSection, "TOPRIGHT", 8, 0)
    frame.rightSection:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -10, 10)
    ApplyBackdrop(frame.rightSection, "section")

    frame.generalTabButton = CreateFrame("Button", nil, frame.leftSection, "UIPanelButtonTemplate")
    frame.generalTabButton:SetSize(238, 24)
    frame.generalTabButton:SetPoint("TOPLEFT", frame.leftSection, "TOPLEFT", 10, -10)
    frame.generalTabButton:SetScript("OnClick", function()
        self:SetActiveSection("general")
    end)

    frame.aboutTabButton = CreateFrame("Button", nil, frame.leftSection, "UIPanelButtonTemplate")
    frame.aboutTabButton:SetSize(238, 24)
    frame.aboutTabButton:SetPoint("TOPLEFT", frame.generalTabButton, "BOTTOMLEFT", 0, -6)
    frame.aboutTabButton:SetScript("OnClick", function()
        self:SetActiveSection("about")
    end)

    frame.generalContent = CreateFrame("Frame", nil, frame.leftSection)
    frame.generalContent:SetPoint("TOPLEFT", frame.aboutTabButton, "BOTTOMLEFT", 0, -12)
    frame.generalContent:SetPoint("TOPRIGHT", frame.leftSection, "TOPRIGHT", -10, 0)
    frame.generalContent:SetPoint("BOTTOMLEFT", frame.leftSection, "BOTTOMLEFT", 10, 10)

    frame.aboutSection = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    frame.aboutSection:SetPoint("TOPLEFT", frame.leftSection, "TOPRIGHT", 8, 0)
    frame.aboutSection:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -10, 10)
    ApplyBackdrop(frame.aboutSection, "section")
    frame.aboutSection:Hide()

    frame.aboutTitle = CreateLabel(frame.aboutSection, "", "GameFontNormalLarge")
    frame.aboutTitle:SetPoint("TOPLEFT", frame.aboutSection, "TOPLEFT", 22, -20)
    frame.aboutTitle:SetPoint("RIGHT", frame.aboutSection, "RIGHT", -22, 0)

    frame.aboutMeta = CreateWrappedText(frame.aboutSection, "GameFontNormal", 5)
    frame.aboutMeta:SetPoint("TOPLEFT", frame.aboutTitle, "BOTTOMLEFT", 0, -16)
    frame.aboutMeta:SetPoint("RIGHT", frame.aboutSection, "RIGHT", -22, 0)

    frame.aboutBody = CreateWrappedText(frame.aboutSection, "GameFontHighlight", 7)
    frame.aboutBody:SetPoint("TOPLEFT", frame.aboutMeta, "BOTTOMLEFT", 0, -24)
    frame.aboutBody:SetPoint("RIGHT", frame.aboutSection, "RIGHT", -22, 0)

    frame.aboutFooter = CreateWrappedText(frame.aboutSection, "GameFontDisable", 4)
    frame.aboutFooter:SetPoint("BOTTOMLEFT", frame.aboutSection, "BOTTOMLEFT", 22, 20)
    frame.aboutFooter:SetPoint("RIGHT", frame.aboutSection, "RIGHT", -22, 0)
    frame.aboutBody:SetPoint("BOTTOMLEFT", frame.aboutFooter, "TOPLEFT", 0, 26)
    frame.aboutBody:SetPoint("BOTTOMRIGHT", frame.aboutFooter, "TOPRIGHT", 0, 26)

    frame.generalLabel = CreateLabel(frame.generalContent, "", "GameFontNormalLarge")
    frame.generalLabel:SetPoint("TOPLEFT", frame.generalContent, "TOPLEFT", 0, 0)

    frame.permissionCheck = CreateCheckButton(frame.generalContent)
    frame.permissionCheck:SetPoint("TOPLEFT", frame.generalLabel, "BOTTOMLEFT", 0, -8)
    frame.permissionCheck:SetScript("OnClick", function(currentButton)
        ns.db.showPermissionErrors = currentButton:GetChecked() and true or false
    end)

    frame.lockPanelCheck = CreateCheckButton(frame.generalContent)
    frame.lockPanelCheck:SetPoint("TOPLEFT", frame.permissionCheck, "BOTTOMLEFT", 0, -2)
    frame.lockPanelCheck:SetScript("OnClick", function(currentButton)
        local locked = currentButton:GetChecked() and true or false
        if ns.ChatBar and ns.ChatBar.SetLocked then
            ns.ChatBar:SetLocked(locked, true)
        else
            if type(ns.db.chatBar) ~= "table" then
                ns.db.chatBar = {}
            end
            ns.db.chatBar.locked = locked
        end
    end)

    frame.barBackgroundCheck = CreateCheckButton(frame.generalContent)
    frame.barBackgroundCheck:SetPoint("TOPLEFT", frame.lockPanelCheck, "BOTTOMLEFT", 0, -2)
    frame.barBackgroundCheck:SetScript("OnClick", function(currentButton)
        if type(ns.db.chatBar) ~= "table" then
            ns.db.chatBar = {}
        end
        ns.db.chatBar.showBackground = currentButton:GetChecked() and true or false
        if ns.ChatBar then
            ns.ChatBar:Refresh()
        end
    end)

    frame.scaleLabel = CreateLabel(frame.generalContent, ns.L["LABEL_BAR_SCALE"], "GameFontNormal")
    frame.scaleLabel:SetPoint("TOPLEFT", frame.barBackgroundCheck, "BOTTOMLEFT", 4, -10)

    frame.scaleSlider = CreateFrame("Slider", nil, frame.generalContent, "OptionsSliderTemplate")
    frame.scaleSlider:SetPoint("TOPLEFT", frame.scaleLabel, "BOTTOMLEFT", 0, -6)
    frame.scaleSlider:SetPoint("RIGHT", frame.generalContent, "RIGHT", -42, 0)
    frame.scaleSlider:SetMinMaxValues(0.8, 1.4)
    frame.scaleSlider:SetValueStep(0.05)
    frame.scaleSlider:SetObeyStepOnDrag(true)
    frame.scaleSlider:SetScript("OnValueChanged", function(_, value)
        if self.refreshing then
            return
        end

        if type(ns.db.chatBar) ~= "table" then
            ns.db.chatBar = {}
        end
        ns.db.chatBar.scale = tonumber(string.format("%.2f", value))
        frame.scaleValue:SetText(string.format("%.2f", ns.db.chatBar.scale))
        if ns.ChatBar then
            ns.ChatBar:Refresh()
        end
    end)

    frame.scaleValue = CreateLabel(frame.generalContent, "1.00", "GameFontHighlight")
    frame.scaleValue:SetWidth(40)
    frame.scaleValue:SetJustifyH("RIGHT")
    frame.scaleValue:SetPoint("LEFT", frame.scaleSlider, "RIGHT", 8, 0)
    frame.scaleValue:SetPoint("RIGHT", frame.generalContent, "RIGHT", 0, 0)

    frame.templatesLabel = CreateLabel(frame.middleSection, "", "GameFontNormalLarge")
    frame.templatesLabel:SetPoint("TOPLEFT", frame.middleSection, "TOPLEFT", 10, -10)

    frame.templateListLabel = CreateLabel(frame.middleSection, "", "GameFontNormal")
    frame.templateListLabel:SetPoint("TOPLEFT", frame.templatesLabel, "BOTTOMLEFT", 0, -10)

    frame.searchLabel = CreateLabel(frame.middleSection, "", "GameFontNormal")
    frame.searchLabel:SetPoint("TOPLEFT", frame.templateListLabel, "BOTTOMLEFT", 0, -10)

    frame.templateSearchBox = CreateEditBox(frame.middleSection, 264)
    frame.templateSearchBox:SetPoint("TOPLEFT", frame.searchLabel, "BOTTOMLEFT", 0, -4)
    frame.templateSearchBox:SetScript("OnTextChanged", function()
        self:RefreshTemplateList()
    end)

    frame.templateListScrollBg = CreateFrame("Frame", nil, frame.middleSection, "BackdropTemplate")
    frame.templateListScrollBg:SetPoint("TOPLEFT", frame.templateSearchBox, "BOTTOMLEFT", -2, -4)
    frame.templateListScrollBg:SetSize(292, 392)
    ApplyBackdrop(frame.templateListScrollBg, "input")

    frame.templateListScroll = CreateFrame("ScrollFrame", nil, frame.templateListScrollBg, "UIPanelScrollFrameTemplate")
    frame.templateListScroll:SetPoint("TOPLEFT", frame.templateListScrollBg, "TOPLEFT", 2, -3)
    frame.templateListScroll:SetPoint("BOTTOMRIGHT", frame.templateListScrollBg, "BOTTOMRIGHT", -24, 3)

    frame.templateListContent = CreateFrame("Frame", nil, frame.templateListScroll)
    frame.templateListContent:SetSize(264, 1)
    frame.templateListScroll:SetScrollChild(frame.templateListContent)

    frame.newButton = CreateFrame("Button", nil, frame.middleSection, "UIPanelButtonTemplate")
    frame.newButton:SetSize(92, 22)
    frame.newButton:SetPoint("TOPLEFT", frame.templateListScroll, "BOTTOMLEFT", 0, -8)
    frame.newButton:SetScript("OnClick", function()
        self:StartNewTemplate()
    end)

    frame.upButton = CreateFrame("Button", nil, frame.middleSection, "UIPanelButtonTemplate")
    frame.upButton:SetSize(92, 22)
    frame.upButton:SetPoint("LEFT", frame.newButton, "RIGHT", 6, 0)
    frame.upButton:SetScript("OnClick", function()
        self:MoveTemplate(-1)
    end)

    frame.downButton = CreateFrame("Button", nil, frame.middleSection, "UIPanelButtonTemplate")
    frame.downButton:SetSize(92, 22)
    frame.downButton:SetPoint("LEFT", frame.upButton, "RIGHT", 6, 0)
    frame.downButton:SetScript("OnClick", function()
        self:MoveTemplate(1)
    end)

    frame.idLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.idLabel:SetPoint("TOPLEFT", frame.rightSection, "TOPLEFT", 10, -10)
    frame.idBox = CreateEditBox(frame.rightSection, 190)
    frame.idBox:SetPoint("TOPLEFT", frame.idLabel, "BOTTOMLEFT", 0, -4)
    frame.idBox:SetPoint("RIGHT", frame.rightSection, "RIGHT", -10, 0)

    frame.nameLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.nameLabel:SetPoint("TOPLEFT", frame.idBox, "BOTTOMLEFT", 0, -10)
    frame.nameBox = CreateEditBox(frame.rightSection, 190)
    frame.nameBox:SetPoint("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -4)
    frame.nameBox:SetPoint("RIGHT", frame.rightSection, "RIGHT", -10, 0)

    frame.channelLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.channelLabel:SetPoint("TOPLEFT", frame.nameBox, "BOTTOMLEFT", 0, -10)
    frame.channelBox = CreateEditBox(frame.rightSection, 120)
    frame.channelBox:SetPoint("TOPLEFT", frame.channelLabel, "BOTTOMLEFT", 0, -4)
    frame.channelBox:SetPoint("RIGHT", frame.rightSection, "RIGHT", -10, 0)

    frame.contentLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.contentLabel:SetPoint("TOPLEFT", frame.channelBox, "BOTTOMLEFT", 0, -10)
    frame.contentBox = CreateEditBox(frame.rightSection, 230)
    frame.contentBox:SetPoint("TOPLEFT", frame.contentLabel, "BOTTOMLEFT", 0, -4)
    frame.contentBox:SetPoint("RIGHT", frame.rightSection, "RIGHT", -10, 0)

    frame.enabledCheck = CreateCheckButton(frame.rightSection)
    frame.enabledCheck:SetPoint("TOPLEFT", frame.contentBox, "BOTTOMLEFT", 0, -14)

    frame.slashCommandCheck = CreateCheckButton(frame.rightSection)
    frame.slashCommandCheck:SetPoint("TOPLEFT", frame.enabledCheck, "BOTTOMLEFT", 0, -2)
    frame.slashCommandCheck:SetScript("OnClick", function()
        self:UpdateTemplateKindControls()
    end)

    frame.requireRWCheck = CreateCheckButton(frame.rightSection)
    frame.requireRWCheck:SetPoint("TOPLEFT", frame.slashCommandCheck, "BOTTOMLEFT", 0, -2)

    frame.charOverrideCheck = CreateCheckButton(frame.rightSection)
    frame.charOverrideCheck:SetPoint("TOPLEFT", frame.requireRWCheck, "BOTTOMLEFT", 0, -12)
    frame.charOverrideCheck:SetScript("OnClick", function()
        self:UpdateCharOverrideControls()
    end)

    frame.charEnabledCheck = CreateCheckButton(frame.rightSection)
    frame.charEnabledCheck:SetPoint("TOPLEFT", frame.charOverrideCheck, "BOTTOMLEFT", 18, -2)

    frame.charChannelLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.charChannelLabel:SetPoint("TOPLEFT", frame.charEnabledCheck, "BOTTOMLEFT", -18, -10)
    frame.charChannelBox = CreateEditBox(frame.rightSection, 80)
    frame.charChannelBox:SetPoint("LEFT", frame.charChannelLabel, "RIGHT", 8, 0)

    frame.charOrderLabel = CreateLabel(frame.rightSection, "", "GameFontNormal")
    frame.charOrderLabel:SetPoint("TOPLEFT", frame.charChannelLabel, "BOTTOMLEFT", 0, -10)
    frame.charOrderBox = CreateEditBox(frame.rightSection, 80)
    frame.charOrderBox:SetPoint("LEFT", frame.charOrderLabel, "RIGHT", 8, 0)

    frame.saveButton = CreateFrame("Button", nil, frame.rightSection, "UIPanelButtonTemplate")
    frame.saveButton:SetSize(90, 24)
    frame.saveButton:SetPoint("BOTTOMRIGHT", frame.rightSection, "BOTTOMRIGHT", -98, 8)
    frame.saveButton:SetScript("OnClick", function()
        self:SaveCurrentTemplate()
    end)

    frame.deleteButton = CreateFrame("Button", nil, frame.rightSection, "UIPanelButtonTemplate")
    frame.deleteButton:SetSize(90, 24)
    frame.deleteButton:SetPoint("LEFT", frame.saveButton, "RIGHT", 8, 0)
    frame.deleteButton:SetScript("OnClick", function()
        self:DeleteCurrentTemplate()
    end)

    self.frame = frame
    self:ApplySkin()
    self:Refresh()
end

function ConfigPanel:Show()
    if not self.frame then
        self:Init()
    end

    self.frame:Show()
    self.frame:Raise()
end

function ConfigPanel:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ConfigPanel:Toggle()
    if not self.frame or not self.frame:IsShown() then
        self:Show()
    else
        self:Hide()
    end
end
