local _, ns = ...

local Theme = {}
ns.Theme = Theme

local WINDOW_NINESLICE_PIECES = {
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "Center",
}

local BUTTON_TEX_KEYS = {
    "Left", "Middle", "Right",
    "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
}

local function Clamp(value)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function Mix(fromValue, toValue, ratio)
    return fromValue + (toValue - fromValue) * ratio
end

local function GetClassColor()
    local _, classTag = UnitClass("player")
    local classColor

    if RAID_CLASS_COLORS and classTag then
        classColor = RAID_CLASS_COLORS[classTag]
    end

    if not classColor and C_ClassColor and C_ClassColor.GetClassColor and classTag then
        classColor = C_ClassColor.GetClassColor(classTag)
    end

    if classColor then
        return Clamp(classColor.r), Clamp(classColor.g), Clamp(classColor.b)
    end

    return 0.85, 0.72, 0.32
end

function Theme:Refresh()
    local cr, cg, cb = GetClassColor()

    self.colors = {
        class = { cr, cg, cb, 1 },
        accent = {
            Mix(cr, 1, 0.06),
            Mix(cg, 1, 0.06),
            Mix(cb, 1, 0.06),
            1,
        },
        border = {
            Mix(0.02, cr, 0.72),
            Mix(0.02, cg, 0.72),
            Mix(0.03, cb, 0.72),
            0.94,
        },
        borderSoft = {
            Mix(0.01, cr, 0.56),
            Mix(0.01, cg, 0.56),
            Mix(0.02, cb, 0.56),
            0.80,
        },
        panelBg = {
            Mix(0.00, cr, 0.08),
            Mix(0.00, cg, 0.08),
            Mix(0.01, cb, 0.08),
            0.74,
        },
        sectionBg = {
            Mix(0.00, cr, 0.06),
            Mix(0.00, cg, 0.06),
            Mix(0.01, cb, 0.06),
            0.68,
        },
        buttonBg = {
            Mix(0.01, cr, 0.11),
            Mix(0.01, cg, 0.11),
            Mix(0.02, cb, 0.11),
            0.88,
        },
        buttonHover = {
            Mix(0.07, cr, 0.22),
            Mix(0.07, cg, 0.22),
            Mix(0.09, cb, 0.22),
            0.98,
        },
        buttonPressed = {
            Mix(0.12, cr, 0.30),
            Mix(0.12, cg, 0.30),
            Mix(0.14, cb, 0.30),
            1,
        },
        inputBg = {
            Mix(0.00, cr, 0.05),
            Mix(0.00, cg, 0.05),
            Mix(0.01, cb, 0.05),
            0.88,
        },
        inputFieldBg = {
            Mix(0.01, cr, 0.12),
            Mix(0.01, cg, 0.12),
            Mix(0.02, cb, 0.12),
            0.98,
        },
        inputFieldHover = {
            Mix(0.03, cr, 0.18),
            Mix(0.03, cg, 0.18),
            Mix(0.04, cb, 0.18),
            0.99,
        },
        inputFieldFocus = {
            Mix(0.05, cr, 0.24),
            Mix(0.05, cg, 0.24),
            Mix(0.06, cb, 0.24),
            1,
        },
        inputFieldBorder = {
            Mix(0.20, cr, 0.78),
            Mix(0.20, cg, 0.78),
            Mix(0.24, cb, 0.78),
            1,
        },
        scrollTrack = {
            Mix(0.00, cr, 0.04),
            Mix(0.00, cg, 0.04),
            Mix(0.01, cb, 0.04),
            0.74,
        },
        textMuted = { 0.74, 0.77, 0.81, 1 },
    }
end

function Theme:GetColor(name)
    if not self.colors then
        self:Refresh()
    end
    return self.colors[name]
end

function Theme:ApplyBackdrop(frame, style)
    if not frame then
        return
    end

    if type(frame.SetBackdrop) ~= "function"
        or type(frame.SetBackdropColor) ~= "function"
        or type(frame.SetBackdropBorderColor) ~= "function" then
        return
    end

    local bg
    local border

    if style == "panel" then
        bg = self:GetColor("panelBg")
        border = self:GetColor("border")
    elseif style == "section" then
        bg = self:GetColor("sectionBg")
        border = self:GetColor("borderSoft")
    elseif style == "input" then
        bg = self:GetColor("inputBg")
        border = self:GetColor("borderSoft")
    elseif style == "inputField" then
        bg = self:GetColor("inputFieldBg")
        border = self:GetColor("inputFieldBorder")
    elseif style == "inputFieldHover" then
        bg = self:GetColor("inputFieldHover")
        border = self:GetColor("inputFieldBorder")
    elseif style == "inputFieldFocus" then
        bg = self:GetColor("inputFieldFocus")
        border = self:GetColor("accent")
    elseif style == "buttonHover" then
        bg = self:GetColor("buttonHover")
        border = self:GetColor("border")
    elseif style == "buttonPressed" then
        bg = self:GetColor("buttonPressed")
        border = self:GetColor("border")
    elseif style == "scrollTrack" then
        bg = self:GetColor("scrollTrack")
        border = self:GetColor("borderSoft")
    else
        bg = self:GetColor("buttonBg")
        border = self:GetColor("borderSoft")
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function Theme:ColorizeText(fontString, colorName)
    if not fontString then
        return
    end
    local c = self:GetColor(colorName or "accent")
    fontString:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function Theme:StripTextureRegions(frame)
    if not frame then
        return
    end

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetTexture then
                    region:SetTexture(nil)
                end
                if region.SetAtlas then
                    region:SetAtlas(nil)
                end
                if region.SetAlpha then
                    region:SetAlpha(0)
                end
                if region.Hide then
                    region:Hide()
                end
            end
        end
    end

    for _, key in ipairs(BUTTON_TEX_KEYS) do
        local tex = frame[key]
        if tex and tex.GetObjectType and tex:GetObjectType() == "Texture" then
            if tex.SetTexture then
                tex:SetTexture(nil)
            end
            if tex.SetAtlas then
                tex:SetAtlas(nil)
            end
            if tex.SetAlpha then
                tex:SetAlpha(0)
            end
            if tex.Hide then
                tex:Hide()
            end
        end
    end
end

function Theme:SkinButton(button)
    if not button then
        return
    end

    self:StripTextureRegions(button)

    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture("")
    end

    self:ApplyBackdrop(button, "button")

    local fontString = button.GetFontString and button:GetFontString() or nil
    if fontString then
        fontString:SetTextColor(0.96, 0.97, 1, 1)
    end

    if button._chatEaseButtonHooked then
        return
    end

    button:HookScript("OnEnter", function(currentButton)
        Theme:ApplyBackdrop(currentButton, "buttonHover")
    end)
    button:HookScript("OnLeave", function(currentButton)
        Theme:ApplyBackdrop(currentButton, "button")
    end)
    button:HookScript("OnMouseDown", function(currentButton)
        Theme:ApplyBackdrop(currentButton, "buttonPressed")
    end)
    button:HookScript("OnMouseUp", function(currentButton)
        if currentButton:IsMouseOver() then
            Theme:ApplyBackdrop(currentButton, "buttonHover")
        else
            Theme:ApplyBackdrop(currentButton, "button")
        end
    end)

    button._chatEaseButtonHooked = true
end

function Theme:SkinEditBox(editBox)
    if not editBox then
        return
    end

    local skinTarget = editBox
    if type(editBox.SetBackdrop) ~= "function"
        or type(editBox.SetBackdropColor) ~= "function"
        or type(editBox.SetBackdropBorderColor) ~= "function" then
        if not editBox._chatEaseBackdropFrame then
            local backdrop = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
            backdrop:SetPoint("TOPLEFT", editBox, "TOPLEFT", -1, 1)
            backdrop:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 1, -1)
            local level = editBox:GetFrameLevel() - 1
            if level < 0 then
                level = 0
            end
            backdrop:SetFrameLevel(level)
            backdrop:EnableMouse(false)
            editBox._chatEaseBackdropFrame = backdrop
        end
        skinTarget = editBox._chatEaseBackdropFrame
    end
    editBox._chatEaseSkinTarget = skinTarget

    local function SetBoxVisual(currentBox, styleName, borderColorName, borderAlpha)
        local target = currentBox._chatEaseSkinTarget or skinTarget
        Theme:ApplyBackdrop(target, styleName)
        local borderColor = Theme:GetColor(borderColorName)
        if target.SetBackdropBorderColor and borderColor then
            target:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha or borderColor[4] or 1)
        end
    end

    if editBox.Left then
        editBox.Left:SetAlpha(0)
    end
    if editBox.Middle then
        editBox.Middle:SetAlpha(0)
    end
    if editBox.Right then
        editBox.Right:SetAlpha(0)
    end

    SetBoxVisual(editBox, "inputField", "inputFieldBorder", 1)

    if editBox.SetTextInsets then
        editBox:SetTextInsets(8, 8, 2, 2)
    end

    if editBox.SetTextColor then
        editBox:SetTextColor(0.96, 0.97, 1, 1)
    end
    if editBox.SetFontObject then
        editBox:SetFontObject("GameFontHighlight")
    end

    if editBox._chatEaseEditHooked then
        return
    end

    editBox:HookScript("OnEnter", function(currentBox)
        if currentBox:HasFocus() then
            return
        end
        SetBoxVisual(currentBox, "inputFieldHover", "inputFieldBorder", 1)
    end)
    editBox:HookScript("OnLeave", function(currentBox)
        if currentBox:HasFocus() then
            return
        end
        SetBoxVisual(currentBox, "inputField", "inputFieldBorder", 1)
    end)
    editBox:HookScript("OnEditFocusGained", function(currentBox)
        SetBoxVisual(currentBox, "inputFieldFocus", "accent", 1)
    end)
    editBox:HookScript("OnEditFocusLost", function(currentBox)
        if currentBox:IsMouseOver() then
            SetBoxVisual(currentBox, "inputFieldHover", "inputFieldBorder", 1)
        else
            SetBoxVisual(currentBox, "inputField", "inputFieldBorder", 1)
        end
    end)
    editBox:HookScript("OnEnable", function(currentBox)
        if currentBox:HasFocus() then
            SetBoxVisual(currentBox, "inputFieldFocus", "accent", 1)
        elseif currentBox:IsMouseOver() then
            SetBoxVisual(currentBox, "inputFieldHover", "inputFieldBorder", 1)
        else
            SetBoxVisual(currentBox, "inputField", "inputFieldBorder", 1)
        end
        if currentBox.SetTextColor then
            currentBox:SetTextColor(0.96, 0.97, 1, 1)
        end
    end)
    editBox:HookScript("OnDisable", function(currentBox)
        SetBoxVisual(currentBox, "input", "borderSoft", 0.72)
        if currentBox.SetTextColor then
            currentBox:SetTextColor(0.72, 0.74, 0.78, 0.95)
        end
    end)

    editBox._chatEaseEditHooked = true
end

function Theme:SkinCheckButton(checkButton)
    if not checkButton then
        return
    end

    if not checkButton._chatEaseBox then
        local box = CreateFrame("Frame", nil, checkButton, "BackdropTemplate")
        box:SetPoint("LEFT", checkButton, "LEFT", 2, 0)
        box:SetSize(20, 20)
        box:EnableMouse(false)
        checkButton._chatEaseBox = box

        local fill = box:CreateTexture(nil, "ARTWORK")
        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
        checkButton._chatEaseFill = fill

        local mark = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        mark:SetPoint("CENTER", box, "CENTER", 0, 0)
        mark:SetText("✓")
        mark:SetShadowColor(0, 0, 0, 0.9)
        mark:SetShadowOffset(1, -1)
        checkButton._chatEaseMark = mark
    end

    local checkedTexture = checkButton.GetCheckedTexture and checkButton:GetCheckedTexture() or nil
    if checkedTexture then
        checkedTexture:SetAlpha(0)
    end

    local normalTexture = checkButton.GetNormalTexture and checkButton:GetNormalTexture() or nil
    if normalTexture then
        normalTexture:SetAlpha(0)
    end
    local pushedTexture = checkButton.GetPushedTexture and checkButton:GetPushedTexture() or nil
    if pushedTexture then
        pushedTexture:SetAlpha(0)
    end
    local highlightTexture = checkButton.GetHighlightTexture and checkButton:GetHighlightTexture() or nil
    if highlightTexture then
        highlightTexture:SetAlpha(0)
    end
    local disabledCheckedTexture = checkButton.GetDisabledCheckedTexture and checkButton:GetDisabledCheckedTexture() or nil
    if disabledCheckedTexture then
        disabledCheckedTexture:SetAlpha(0)
    end

    if not checkButton._chatEaseRefreshVisual then
        checkButton._chatEaseRefreshVisual = function(currentButton, hovered)
            local box = currentButton._chatEaseBox
            if not box then
                return
            end

            if hovered then
                Theme:ApplyBackdrop(box, "buttonHover")
            else
                Theme:ApplyBackdrop(box, "input")
            end

            local border = Theme:GetColor(hovered and "border" or "borderSoft")
            box:SetBackdropBorderColor(border[1], border[2], border[3], 1)

            local fill = currentButton._chatEaseFill
            local mark = currentButton._chatEaseMark
            local checked = currentButton:GetChecked() and true or false
            local enabled = currentButton:IsEnabled()
            local accent = Theme:GetColor("accent")

            if checked then
                fill:SetVertexColor(accent[1], accent[2], accent[3], enabled and 0.9 or 0.45)
                fill:Show()
                mark:SetTextColor(1, 1, 1, enabled and 1 or 0.55)
                mark:Show()
            else
                fill:Hide()
                mark:Hide()
            end

            box:SetAlpha(enabled and 1 or 0.65)
        end
    end

    local refreshVisual = checkButton._chatEaseRefreshVisual
    refreshVisual(checkButton, checkButton:IsMouseOver())

    if checkButton._chatEaseCheckHooked then
        return
    end

    checkButton:HookScript("OnEnter", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, true)
    end)
    checkButton:HookScript("OnLeave", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, false)
    end)
    checkButton:HookScript("OnClick", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, currentButton:IsMouseOver())
    end)
    checkButton:HookScript("OnShow", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, currentButton:IsMouseOver())
    end)
    checkButton:HookScript("OnEnable", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, currentButton:IsMouseOver())
    end)
    checkButton:HookScript("OnDisable", function(currentButton)
        currentButton._chatEaseRefreshVisual(currentButton, currentButton:IsMouseOver())
    end)

    checkButton._chatEaseCheckHooked = true
end

function Theme:SkinScrollFrame(scrollFrame)
    if not scrollFrame then
        return
    end

    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar and scrollFrame.GetName then
        scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    end
    if not scrollBar then
        return
    end

    for _, key in ipairs({ "Top", "Middle", "Bottom", "TrackBG", "BG", "Background" }) do
        local region = scrollBar[key]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    if not scrollBar._chatEaseTrack then
        local track = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
        track:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", 0, -16)
        track:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", 0, 16)
        track:SetFrameLevel(math.max(1, scrollBar:GetFrameLevel() - 1))
        track:EnableMouse(false)
        scrollBar._chatEaseTrack = track
    end
    self:ApplyBackdrop(scrollBar._chatEaseTrack, "scrollTrack")

    local function SkinArrowButton(button, arrowText)
        if not button then
            return
        end

        Theme:StripTextureRegions(button)

        if button.SetNormalTexture then
            button:SetNormalTexture("")
        end
        if button.SetHighlightTexture then
            button:SetHighlightTexture("")
        end
        if button.SetPushedTexture then
            button:SetPushedTexture("")
        end
        if button.SetDisabledTexture then
            button:SetDisabledTexture("")
        end

        if not button._chatEaseLayer then
            local layer = CreateFrame("Frame", nil, button, "BackdropTemplate")
            layer:SetAllPoints(button)
            layer:EnableMouse(false)

            local text = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER", layer, "CENTER", 0, 0)
            text:SetText(arrowText)

            button._chatEaseLayer = layer
            button._chatEaseLayerText = text
        end

        self:ApplyBackdrop(button._chatEaseLayer, "button")
        button._chatEaseLayerText:SetTextColor(0.92, 0.94, 0.98, 0.9)

        if not button._chatEaseScrollHooked then
            button:HookScript("OnEnter", function(currentButton)
                Theme:ApplyBackdrop(currentButton._chatEaseLayer, "buttonHover")
            end)
            button:HookScript("OnLeave", function(currentButton)
                Theme:ApplyBackdrop(currentButton._chatEaseLayer, "button")
            end)
            button:HookScript("OnMouseDown", function(currentButton)
                Theme:ApplyBackdrop(currentButton._chatEaseLayer, "buttonPressed")
            end)
            button:HookScript("OnMouseUp", function(currentButton)
                if currentButton:IsMouseOver() then
                    Theme:ApplyBackdrop(currentButton._chatEaseLayer, "buttonHover")
                else
                    Theme:ApplyBackdrop(currentButton._chatEaseLayer, "button")
                end
            end)
            button._chatEaseScrollHooked = true
        end
    end

    SkinArrowButton(scrollBar.ScrollUpButton or scrollBar.UpButton, "▲")
    SkinArrowButton(scrollBar.ScrollDownButton or scrollBar.DownButton, "▼")

    local thumb = scrollBar.ThumbTexture
        or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture())
        or scrollBar.thumbTexture
    if thumb then
        local accent = self:GetColor("accent")
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(accent[1], accent[2], accent[3], 0.85)
    end
end

function Theme:SkinSlider(slider)
    if not slider then
        return
    end

    self:StripTextureRegions(slider)

    for _, key in ipairs({ "BG", "Border", "Low", "High", "Text" }) do
        local region = slider[key]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    if not slider._chatEaseTrack then
        local track = CreateFrame("Frame", nil, slider, "BackdropTemplate")
        track:SetPoint("LEFT", slider, "LEFT", 0, 0)
        track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
        track:SetHeight(4)
        track:SetFrameLevel(math.max(1, slider:GetFrameLevel() - 1))
        track:EnableMouse(false)
        slider._chatEaseTrack = track
    end
    self:ApplyBackdrop(slider._chatEaseTrack, "input")

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider.GetThumbTexture and slider:GetThumbTexture() or nil
    if thumb then
        local accent = self:GetColor("accent")
        thumb:SetSize(10, 14)
        thumb:SetVertexColor(accent[1], accent[2], accent[3], 0.95)
    end
end

function Theme:SkinWindowFrame(frame)
    if not frame then
        return
    end

    local function HideRegion(region)
        if not region then
            return
        end
        if region.SetAlpha then
            region:SetAlpha(0)
        end
        if region.Hide then
            region:Hide()
        end
    end

    HideRegion(frame.Bg)
    HideRegion(frame.TopTileStreaks)
    HideRegion(frame.Inset)
    HideRegion(frame.InsetBg)
    HideRegion(frame.LeftInset)
    HideRegion(frame.RightInset)
    HideRegion(frame.BottomInset)

    if frame.NineSlice then
        for _, pieceName in ipairs(WINDOW_NINESLICE_PIECES) do
            HideRegion(frame.NineSlice[pieceName])
        end
    end

    if not frame._chatEaseGlass then
        local glass = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glass:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        glass:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        glass:SetFrameLevel(math.max(1, frame:GetFrameLevel() - 1))
        glass:EnableMouse(false)

        local titleBar = CreateFrame("Frame", nil, glass, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT", glass, "TOPLEFT", 8, -8)
        titleBar:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -8, -8)
        titleBar:SetHeight(26)
        titleBar:EnableMouse(false)

        local divider = titleBar:CreateTexture(nil, "BORDER")
        divider:SetTexture("Interface\\Buttons\\WHITE8X8")
        divider:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
        divider:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        divider:SetHeight(1)

        frame._chatEaseGlass = glass
        frame._chatEaseTitleBar = titleBar
        frame._chatEaseTitleDivider = divider
    end

    self:ApplyBackdrop(frame._chatEaseGlass, "panel")
    self:ApplyBackdrop(frame._chatEaseTitleBar, "section")

    if frame._chatEaseTitleDivider then
        local accent = self:GetColor("accent")
        frame._chatEaseTitleDivider:SetVertexColor(accent[1], accent[2], accent[3], 0.40)
    end

    if frame.TitleText then
        self:ColorizeText(frame.TitleText, "accent")
    end
end
