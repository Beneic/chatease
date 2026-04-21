local _, ns = ...

local Router = {}
ns.CommandRouter = Router

local CHANNEL_MAP = {
    world = { chatType = "CHANNEL", channelTarget = 1, customSlash = "/1 " },
    ["1"] = { chatType = "CHANNEL", channelTarget = 1, customSlash = "/1 " },
    s = { chatType = "SAY", customSlash = "/s " },
    say = { chatType = "SAY", customSlash = "/s " },
    p = { chatType = "PARTY", customSlash = "/p " },
    party = { chatType = "PARTY", customSlash = "/p " },
    i = { chatType = "INSTANCE_CHAT", customSlash = "/i " },
    instance = { chatType = "INSTANCE_CHAT", customSlash = "/i " },
    raid = { chatType = "RAID", customSlash = "/raid " },
    r = { chatType = "RAID", customSlash = "/raid " },
    rw = { chatType = "RAID_WARNING", permission = "rw", customSlash = "/rw " },
    g = { chatType = "GUILD", customSlash = "/g " },
    guild = { chatType = "GUILD", customSlash = "/g " },
    o = { chatType = "OFFICER", customSlash = "/o " },
    officer = { chatType = "OFFICER", customSlash = "/o " },
    y = { chatType = "YELL", customSlash = "/y " },
    yell = { chatType = "YELL", customSlash = "/y " },
    e = { chatType = "EMOTE", customSlash = "/e " },
    emote = { chatType = "EMOTE", customSlash = "/e " },
    w = { customSlash = "/r ", reply = true },
    whisper = { chatType = "WHISPER", needsTarget = true },
}

local function SplitFirst(text)
    if not text or text == "" then
        return nil, ""
    end

    local head, tail = text:match("^(%S+)%s*(.-)$")
    return head, tail or ""
end

local function FormatLocalized(template, value)
    return string.format(template, value)
end

local function OpenSlashPrefill(text)
    local commandText = text or ""
    if type(ChatFrame_OpenChat) == "function" then
        local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1 or SELECTED_DOCK_FRAME
        local ok = pcall(ChatFrame_OpenChat, commandText, chatFrame)
        if ok then
            return true
        end
    end

    return ns.Compat.OpenChatEditBox(nil, nil, commandText)
end

local function SetEditBoxSlash(editBox, slashText)
    if not editBox then
        return
    end
    editBox:SetText(slashText or "")
    editBox:SetCursorPosition(editBox:GetNumLetters())
end

local function HookPreferredEditBox(editBox)
    if not editBox or editBox._chatEasePreferredHooked then
        return
    end
    editBox._chatEasePreferredHooked = true
    editBox:HookScript("OnShow", function(currentBox)
        Router:ApplyPreferredChannelToEditBox(currentBox)
    end)
end

function Router:Init()
    local boxes = {}
    if type(NUM_CHAT_WINDOWS) == "number" then
        for i = 1, NUM_CHAT_WINDOWS do
            local box = _G["ChatFrame" .. i .. "EditBox"]
            if box then
                boxes[#boxes + 1] = box
            end
        end
    end

    local fallback = _G.ChatFrame1EditBox
    if fallback then
        boxes[#boxes + 1] = fallback
    end

    for _, box in ipairs(boxes) do
        HookPreferredEditBox(box)
    end
end

function Router:GetPanelModeLabel(mode)
    if mode == "docked" then
        return ns.L["PANEL_MODE_DOCKED"]
    end
    return ns.L["PANEL_MODE_FLOATING"]
end

function Router:ResolveChannel(alias)
    local normalized = ns.Compat.NormalizeToken(alias)
    if normalized == "" then
        return nil
    end
    return CHANNEL_MAP[normalized], normalized
end

function Router:SetPreferredAlias(alias)
    local route, normalizedAlias = self:ResolveChannel(alias)
    if not route or not normalizedAlias then
        return false
    end

    if type(ns.db.chatBar) ~= "table" then
        ns.db.chatBar = {}
    end
    ns.db.chatBar.preferredAlias = normalizedAlias
    return true
end

function Router:GetPreferredAlias()
    if type(ns.db.chatBar) ~= "table" then
        return "s"
    end

    local stored = ns.Compat.NormalizeToken(ns.db.chatBar.preferredAlias or "")
    if stored == "" then
        return "s"
    end

    if self:ResolveChannel(stored) then
        return stored
    end
    return "s"
end

function Router:ApplyPreferredChannelToEditBox(editBox)
    if not editBox or not editBox:IsShown() then
        return
    end

    local currentText = ns.Compat.Trim(editBox:GetText() or "")
    if currentText ~= "" then
        return
    end

    local alias = self:GetPreferredAlias()
    local route = self:ResolveChannel(alias)
    if not route then
        return
    end

    if route.customSlash and route.customSlash ~= "" then
        SetEditBoxSlash(editBox, route.customSlash)
        return
    end

    if route.reply then
        SetEditBoxSlash(editBox, "/r ")
        return
    end

    if route.needsTarget then
        SetEditBoxSlash(editBox, "/w ")
        return
    end

    if route.chatType and route.chatType ~= "" then
        ChatEdit_SetChatType(editBox, route.chatType, nil, route.channelTarget)
    end
end

function Router:PrimeChannel(alias)
    local route = self:ResolveChannel(alias)
    if not route then
        ns.Compat.Print(FormatLocalized(ns.L["ERROR_UNKNOWN_ALIAS"], tostring(alias)))
        return false
    end

    self:SetPreferredAlias(alias)

    if route.customSlash then
        local ok = OpenSlashPrefill(route.customSlash)
        if not ok then
            ns.Compat.Print(ns.L["ERROR_EDITBOX_OPEN_FAILED"])
        end
        return ok
    end

    if route.reply then
        local ok = OpenSlashPrefill("/r ")
        if not ok then
            ns.Compat.Print(ns.L["ERROR_EDITBOX_OPEN_FAILED"])
        end
        return ok
    end

    if route.needsTarget then
        local ok = OpenSlashPrefill("/w ")
        if not ok then
            ns.Compat.Print(ns.L["ERROR_EDITBOX_OPEN_FAILED"])
        end
        return ok
    end

    local ok = ns.Compat.OpenChatEditBox(route.chatType, nil, "")
    if not ok then
        ns.Compat.Print(ns.L["ERROR_EDITBOX_OPEN_FAILED"])
    end
    return ok
end

function Router:SendToAlias(alias, rawMessage, explicitTarget, explicitPermission)
    local route = self:ResolveChannel(alias)
    if not route then
        ns.Compat.Print(FormatLocalized(ns.L["ERROR_UNKNOWN_ALIAS"], tostring(alias)))
        return false
    end

    local message = ns.Compat.Trim(rawMessage)
    local whisperTarget = explicitTarget and ns.Compat.Trim(explicitTarget) or nil

    if route.reply then
        if message == "" then
            ns.Compat.Print(ns.L["ERROR_MISSING_MESSAGE"])
            return false
        end
        return self:ExecuteSlashCommand("/r " .. message)
    end

    if route.needsTarget then
        if not whisperTarget or whisperTarget == "" then
            local target, tail = SplitFirst(message)
            whisperTarget = ns.Compat.Trim(target or "")
            message = ns.Compat.Trim(tail or "")
        end

        if whisperTarget == "" or message == "" then
            ns.Compat.Print(ns.L["ERROR_WHISPER_FORMAT"])
            return false
        end
    else
        if message == "" then
            ns.Compat.Print(ns.L["ERROR_MISSING_MESSAGE"])
            return false
        end
    end

    local requiredPermission = explicitPermission or route.permission
    if requiredPermission and not ns.Permission:Check(requiredPermission) then
        return false
    end

    local channelTarget = whisperTarget or route.channelTarget
    local ok, err = pcall(SendChatMessage, message, route.chatType, nil, channelTarget)
    if not ok then
        ns.Compat.Print(string.format("%s: %s", ns.L["ERROR_SEND_FAILED"], tostring(err)))
        return false
    end

    return true
end

function Router:ExecuteTemplate(templateId)
    local id = ns.Compat.NormalizeToken(templateId)
    if id == "" then
        ns.Compat.Print(ns.L["ERROR_MISSING_TEMPLATE_ID"])
        return false
    end

    local template = ns.TemplateStore:GetTemplate(id)
    if not template then
        ns.Compat.Print(FormatLocalized(ns.L["ERROR_TEMPLATE_NOT_FOUND"], id))
        return false
    end

    if template.enabled == false then
        ns.Compat.Print(ns.L["ERROR_TEMPLATE_DISABLED"])
        return false
    end

    if template.kind == "slash" then
        return self:ExecuteSlashCommand(template.content)
    end

    return self:SendToAlias(
        template.defaultChannel,
        template.content,
        template.whisperTarget,
        template.requirePermission
    )
end

function Router:ExecuteSlashCommand(rawCommand)
    local commandText = ns.Compat.Trim(rawCommand or "")
    if commandText == "" then
        ns.Compat.Print(ns.L["ERROR_EMPTY_SLASH_COMMAND"])
        return false
    end

    if string.sub(commandText, 1, 1) ~= "/" then
        commandText = "/" .. commandText
    end

    local editBox = ChatEdit_ChooseBoxForSend("SAY")
    if not editBox then
        ns.Compat.Print(ns.L["ERROR_EDITBOX_OPEN_FAILED"])
        return false
    end

    ChatEdit_ActivateChat(editBox)
    editBox:SetText(commandText)
    editBox:SetCursorPosition(editBox:GetNumLetters())

    if ChatEdit_SendText then
        local ok = pcall(ChatEdit_SendText, editBox, 0)
        if ok then
            return true
        end
    end

    ns.Compat.Print(ns.L["INFO_SLASH_PREFILLED"])
    return true
end

function Router:PrintHelp()
    ns.Compat.Print(ns.L["CMD_HELP_HEADER"])
    ns.Compat.Print(ns.L["CMD_HELP_OPEN"])
    ns.Compat.Print(ns.L["CMD_HELP_CONFIG"])
    ns.Compat.Print(ns.L["CMD_HELP_SEND"])
    ns.Compat.Print(ns.L["CMD_HELP_CHANNEL"])
    ns.Compat.Print(ns.L["CMD_HELP_BAR"])
end

function Router:HandleSlash(message)
    local input = ns.Compat.Trim(message or "")
    if input == "" then
        if ns.ConfigPanel then
            ns.ConfigPanel:Toggle()
        end
        return
    end

    local command, rest = SplitFirst(input)
    command = ns.Compat.NormalizeToken(command)

    if command == "config" or command == "options" then
        if ns.ConfigPanel then
            ns.ConfigPanel:Toggle()
        end
        return
    end

    if command == "send" then
        local templateId = ns.Compat.Trim(rest or "")
        if templateId == "" then
            ns.Compat.Print(ns.L["ERROR_MISSING_TEMPLATE_ID"])
            return
        end
        self:ExecuteTemplate(templateId)
        return
    end

    if command == "channel" then
        local alias, tail = SplitFirst(rest or "")
        if not alias then
            ns.Compat.Print(ns.L["ERROR_CHANNEL_USAGE"])
            return
        end

        local normalizedAlias = ns.Compat.NormalizeToken(alias)
        if normalizedAlias == "w" then
            self:SendToAlias(normalizedAlias, tail)
            return
        end

        if normalizedAlias == "whisper" then
            local target, body = SplitFirst(tail or "")
            if not target or not body or ns.Compat.Trim(body) == "" then
                ns.Compat.Print(ns.L["ERROR_WHISPER_FORMAT"])
                return
            end
            self:SendToAlias(normalizedAlias, body, target)
            return
        end

        self:SendToAlias(normalizedAlias, tail)
        return
    end

    if command == "panel" then
        if ns.ConfigPanel then
            ns.ConfigPanel:Toggle()
        end
        return
    end

    if command == "bar" then
        if ns.ChatBar then
            ns.ChatBar:HandleSlash(rest)
        end
        return
    end

    if command == "help" then
        self:PrintHelp()
        return
    end

    ns.Compat.Print(string.format("%s: %s", ns.L["ERROR_UNKNOWN_COMMAND"], tostring(command)))
    self:PrintHelp()
end
