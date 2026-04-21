local _, ns = ...

local MainPanel = {
    frame = nil,
    templateButtons = {},
    channelButtons = {},
}
ns.MainPanel = MainPanel

local CHANNEL_ALIASES = { "s", "p", "i", "raid", "rw", "w" }

local CHANNEL_LABEL_KEYS = {
    s = "CHANNEL_S",
    p = "CHANNEL_P",
    i = "CHANNEL_I",
    raid = "CHANNEL_RAID",
    rw = "CHANNEL_RW",
    w = "CHANNEL_W",
}

local function ApplyBackdrop(frame, style)
    ns.Theme:ApplyBackdrop(frame, style)
end

local function CreateSectionLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ns.Theme:ColorizeText(label, "accent")
    label:SetText(text or "")
    return label
end

local function CreateStyledButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    ns.Theme:SkinButton(button)
    button:SetHeight(24)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetTextColor(1, 1, 1, 1)

    function button:SetButtonText(text)
        self.label:SetText(text or "")
    end

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
    ns.Theme:ColorizeText(frame.TitleText, "accent")

    frame.closeButton = CreateFrame("Button", nil, frame.titleBar, "BackdropTemplate")
    frame.closeButton:SetSize(18, 18)
    frame.closeButton:SetPoint("RIGHT", frame.titleBar, "RIGHT", -2, 0)
    ns.Theme:SkinButton(frame.closeButton)

    frame.closeButton.text = frame.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.closeButton.text:SetPoint("CENTER", frame.closeButton, "CENTER", 0, 0)
    frame.closeButton.text:SetText("×")
    frame.closeButton.text:SetTextColor(1, 0.35, 0.35, 1)

    frame.closeButton:SetScript("OnEnter", function(button)
        ApplyBackdrop(button, "buttonHover")
        button.text:SetTextColor(1, 0.55, 0.55, 1)
    end)
    frame.closeButton:SetScript("OnLeave", function(button)
        ApplyBackdrop(button, "button")
        button.text:SetTextColor(1, 0.35, 0.35, 1)
    end)
    frame.closeButton:SetScript("OnClick", closeHandler)
end

local function EnsureTemplateButton(self, index)
    if self.templateButtons[index] then
        return self.templateButtons[index]
    end

    local button = CreateFrame("Button", nil, self.frame.templateContent, "BackdropTemplate")
    ns.Theme:SkinButton(button)
    button:SetHeight(28)
    button:SetScript("OnClick", function(currentButton)
        ns.CommandRouter:ExecuteTemplate(currentButton.templateId)
    end)

    button.nameText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.nameText:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.nameText:SetJustifyH("LEFT")

    button.channelText = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    button.channelText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    local muted = ns.Theme:GetColor("textMuted")
    button.channelText:SetTextColor(muted[1], muted[2], muted[3], muted[4])

    button:SetScript("OnEnter", function(currentButton)
        local template = currentButton.template
        if not template then
            return
        end

        local templateName = ns.TemplateStore:GetTemplateName(template)
        GameTooltip:SetOwner(currentButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(templateName)
        if template.kind == "slash" then
            GameTooltip:AddLine(ns.L["TOOLTIP_TEMPLATE_SLASH"], 0.8, 0.95, 1)
        else
            GameTooltip:AddLine(string.format(ns.L["TOOLTIP_TEMPLATE_CHANNEL"], template.defaultChannel), 0.8, 0.8, 0.8)
            if template.requirePermission == "rw" then
                GameTooltip:AddLine(ns.L["TOOLTIP_TEMPLATE_PERMISSION"], 1, 0.82, 0)
            end
        end
        GameTooltip:AddLine(template.content or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(_)
        GameTooltip:Hide()
    end)

    self.templateButtons[index] = button
    return button
end

function MainPanel:UpdateResponsiveLayout()
    if not self.frame then
        return
    end

    local channelGap = 4
    local channelWidth = self.frame.channelBox:GetWidth()
    local channelButtonWidth = math.max(44, math.floor((channelWidth - channelGap * 2) / 3))
    local channelButtonHeight = 24

    for index, button in ipairs(self.channelButtons) do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:ClearAllPoints()
        button:SetSize(channelButtonWidth, channelButtonHeight)
        button:SetPoint("TOPLEFT", self.frame.channelBox, "TOPLEFT", column * (channelButtonWidth + channelGap), -row * (channelButtonHeight + channelGap))
    end

    local actionGap = 6
    local actionWidth = self.frame.actionBar:GetWidth()
    local singleActionWidth = math.max(96, math.floor((actionWidth - actionGap) / 2))

    self.frame.panelModeButton:ClearAllPoints()
    self.frame.settingsButton:ClearAllPoints()

    self.frame.panelModeButton:SetSize(singleActionWidth, 24)
    self.frame.settingsButton:SetSize(singleActionWidth, 24)

    self.frame.panelModeButton:SetPoint("LEFT", self.frame.actionBar, "LEFT", 0, 0)
    self.frame.settingsButton:SetPoint("LEFT", self.frame.panelModeButton, "RIGHT", actionGap, 0)
end

function MainPanel:Init()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ChatEaseMainPanel", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    ns.Theme:SkinWindowFrame(frame)
    SkinTitleBar(frame, function()
        self:Hide()
    end)

    frame:SetScript("OnDragStart", function(currentFrame)
        if ns.db.ui.locked then
            return
        end
        currentFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(currentFrame)
        currentFrame:StopMovingOrSizing()
        self:SaveAnchor()
    end)
    frame:SetScript("OnShow", function()
        self:Refresh()
    end)
    frame:SetScript("OnSizeChanged", function()
        self:UpdateResponsiveLayout()
        self:RefreshTemplateButtons()
    end)

    frame.TitleText:SetText(ns.L["ADDON_TITLE"])
    ns.Theme:ColorizeText(frame.TitleText, "accent")

    frame.body = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -36)
    frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 44)
    ApplyBackdrop(frame.body, "panel")

    frame.channelLabel = CreateSectionLabel(frame.body, ns.L["LABEL_CHANNEL_BUTTONS"])
    frame.channelLabel:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 12, -10)

    frame.channelBox = CreateFrame("Frame", nil, frame.body)
    frame.channelBox:SetPoint("TOPLEFT", frame.channelLabel, "BOTTOMLEFT", 0, -6)
    frame.channelBox:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -12, -30)
    frame.channelBox:SetHeight(52)

    for index, alias in ipairs(CHANNEL_ALIASES) do
        local channelButton = CreateStyledButton(frame.channelBox)
        channelButton.alias = alias
        channelButton:SetScript("OnClick", function(currentButton)
            ns.CommandRouter:PrimeChannel(currentButton.alias)
        end)
        self.channelButtons[index] = channelButton
    end

    frame.templateLabel = CreateSectionLabel(frame.body, ns.L["LABEL_TEMPLATE_LIST"])
    frame.templateLabel:SetPoint("TOPLEFT", frame.channelBox, "BOTTOMLEFT", 0, -12)

    frame.searchLabel = frame.body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.searchLabel:SetPoint("TOPLEFT", frame.templateLabel, "BOTTOMLEFT", 0, -8)
    local muted = ns.Theme:GetColor("textMuted")
    frame.searchLabel:SetTextColor(muted[1], muted[2], muted[3], muted[4])
    frame.searchLabel:SetText(ns.L["LABEL_SEARCH"])

    frame.searchBox = CreateFrame("EditBox", nil, frame.body, "InputBoxTemplate")
    frame.searchBox:SetHeight(20)
    frame.searchBox:SetPoint("LEFT", frame.searchLabel, "RIGHT", 8, 0)
    frame.searchBox:SetPoint("RIGHT", frame.body, "RIGHT", -14, 0)
    frame.searchBox:SetAutoFocus(false)
    ns.Theme:SkinEditBox(frame.searchBox)
    frame.searchBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)
    frame.searchBox:SetScript("OnTextChanged", function()
        self:RefreshTemplateButtons()
    end)

    frame.templateScrollBg = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    frame.templateScrollBg:SetPoint("TOPLEFT", frame.searchLabel, "BOTTOMLEFT", 0, -8)
    frame.templateScrollBg:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -12, 42)
    ApplyBackdrop(frame.templateScrollBg, "section")

    frame.templateScroll = CreateFrame("ScrollFrame", nil, frame.templateScrollBg, "UIPanelScrollFrameTemplate")
    frame.templateScroll:SetPoint("TOPLEFT", frame.templateScrollBg, "TOPLEFT", 4, -4)
    frame.templateScroll:SetPoint("BOTTOMRIGHT", frame.templateScrollBg, "BOTTOMRIGHT", -26, 4)
    ns.Theme:SkinScrollFrame(frame.templateScroll)

    frame.templateContent = CreateFrame("Frame", nil, frame.templateScroll)
    frame.templateContent:SetSize(1, 1)
    frame.templateScroll:SetScrollChild(frame.templateContent)

    frame.actionBar = CreateFrame("Frame", nil, frame.body)
    frame.actionBar:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 12, 10)
    frame.actionBar:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -12, 10)
    frame.actionBar:SetHeight(24)

    frame.panelModeButton = CreateStyledButton(frame.actionBar)
    frame.panelModeButton:SetScript("OnClick", function()
        local nextMode = (ns.db.ui.mode == "docked") and "floating" or "docked"
        ns.db.ui.mode = nextMode
        self:ApplyLayout()
        self:Refresh()
        if ns.ConfigPanel then
            ns.ConfigPanel:Refresh()
        end
        ns.Compat.Print(string.format(ns.L["INFO_PANELMODE_NOW"], ns.CommandRouter:GetPanelModeLabel(nextMode)))
    end)

    frame.settingsButton = CreateStyledButton(frame.actionBar)
    frame.settingsButton:SetScript("OnClick", function()
        ns.ConfigPanel:Toggle()
    end)

    self.frame = frame
    self:ApplyLayout()
    self:Refresh()
end

function MainPanel:SaveAnchor()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local mode = ns.db.ui.mode or "floating"
    local anchorTable

    if mode == "docked" then
        anchorTable = ns.db.ui.dockedAnchor
    else
        anchorTable = ns.db.ui.floatingAnchor
    end

    anchorTable.point = point or "CENTER"
    anchorTable.relativePoint = relativePoint or "CENTER"
    anchorTable.x = x or 0
    anchorTable.y = y or 0
end

function MainPanel:ApplyLayout()
    if not self.frame then
        return
    end

    local function ApplyNow()
        local mode = ns.db.ui.mode or "floating"
        local ui = ns.db.ui
        local size = (mode == "docked") and ui.dockedSize or ui.floatingSize
        local anchor = (mode == "docked") and ui.dockedAnchor or ui.floatingAnchor

        self.frame:SetScale(ui.scale or 1)
        self.frame:SetSize(size.width or 420, size.height or 500)

        self.frame:ClearAllPoints()
        local relativeFrame = UIParent
        if mode == "docked" and ChatFrame1 then
            relativeFrame = ChatFrame1
        end
        self.frame:SetPoint(
            anchor.point or "CENTER",
            relativeFrame,
            anchor.relativePoint or "CENTER",
            anchor.x or 0,
            anchor.y or 0
        )

        self:UpdateResponsiveLayout()
        self:RefreshTemplateButtons()
    end

    ns.Compat.DeferUntilOutOfCombat("apply_main_panel_layout", ApplyNow)
end

function MainPanel:RefreshTemplateButtons()
    if not self.frame then
        return
    end

    local search = self.frame.searchBox:GetText() or ""
    local templates = ns.TemplateStore:GetTemplates({
        includeDisabled = false,
        search = search,
    })

    local yOffset = 0
    local rowGap = 4
    local rowHeight = 28
    local width = math.max(180, (self.frame.templateScroll:GetWidth() or 0) - 10)

    for index, template in ipairs(templates) do
        local button = EnsureTemplateButton(self, index)
        button.templateId = template.id
        button.template = template
        button:SetWidth(width)
        button.nameText:SetText(ns.TemplateStore:GetTemplateName(template))
        button.channelText:SetText(string.upper(template.defaultChannel or "s"))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.templateContent, "TOPLEFT", 0, -yOffset)
        button:Show()
        yOffset = yOffset + rowHeight + rowGap
    end

    for index = #templates + 1, #self.templateButtons do
        self.templateButtons[index]:Hide()
    end

    if #templates == 0 then
        if not self.frame.emptyMessage then
            self.frame.emptyMessage = self.frame.templateContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            self.frame.emptyMessage:SetPoint("TOPLEFT", self.frame.templateContent, "TOPLEFT", 4, -4)
        end
        self.frame.emptyMessage:SetText(ns.L["LABEL_NO_TEMPLATES"])
        self.frame.emptyMessage:Show()
        yOffset = 20
    elseif self.frame.emptyMessage then
        self.frame.emptyMessage:Hide()
    end

    self.frame.templateContent:SetSize(width, math.max(20, yOffset))
end

function MainPanel:Refresh()
    if not self.frame then
        return
    end

    self.frame.channelLabel:SetText(ns.L["LABEL_CHANNEL_BUTTONS"])
    self.frame.templateLabel:SetText(ns.L["LABEL_TEMPLATE_LIST"])
    self.frame.searchLabel:SetText(ns.L["LABEL_SEARCH"])

    if self.frame.TitleText then
        self.frame.TitleText:SetText(ns.L["ADDON_TITLE"])
        ns.Theme:ColorizeText(self.frame.TitleText, "accent")
    end

    self.frame.panelModeButton:SetButtonText(string.format("%s: %s", ns.L["LABEL_PANELMODE_SHORT"], ns.CommandRouter:GetPanelModeLabel(ns.db.ui.mode)))
    self.frame.settingsButton:SetButtonText(ns.L["LABEL_SETTINGS"])

    for _, button in ipairs(self.channelButtons) do
        local key = CHANNEL_LABEL_KEYS[button.alias]
        button:SetButtonText(ns.L[key] or string.upper(button.alias))
    end

    self:UpdateResponsiveLayout()
    self:RefreshTemplateButtons()
end

function MainPanel:Show()
    if not self.frame then
        self:Init()
    end

    self.frame:Show()
    self.frame:SetFrameStrata("MEDIUM")
    self.frame:Raise()
end

function MainPanel:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MainPanel:Toggle()
    if not self.frame or not self.frame:IsShown() then
        self:Show()
    else
        self:Hide()
    end
end
