local _, ns = ...

local Compat = {}
ns.Compat = Compat

local deferredActions = {}
local deferredFrame = CreateFrame("Frame")
deferredFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_ENABLED" then
        return
    end

    deferredFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    for key, callback in pairs(deferredActions) do
        deferredActions[key] = nil
        local ok, err = pcall(callback)
        if not ok then
            Compat.Print(string.format("Deferred action '%s' failed: %s", tostring(key), tostring(err)))
        end
    end
end)

function Compat.IsRetail1201OrNewer()
    local _, _, _, interfaceVersion = GetBuildInfo()
    return (interfaceVersion or 0) >= 120001
end

function Compat.Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Compat.NormalizeToken(value)
    return string.lower(Compat.Trim(value))
end

function Compat.Clone(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, innerValue in pairs(value) do
        copy[key] = Compat.Clone(innerValue)
    end
    return copy
end

function Compat.MergeDefaults(target, defaults)
    if type(defaults) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            Compat.MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function Compat.Print(message)
    local label = "ChatEase"
    if ns.L and ns.L["ADDON_TITLE"] then
        label = ns.L["ADDON_TITLE"]
    end

    local text = tostring(message or "")
    local prefix = string.format("|cff33ff99[%s]|r ", label)

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. text)
    else
        print(prefix .. text)
    end
end

function Compat.DeferUntilOutOfCombat(key, callback)
    if type(callback) ~= "function" then
        return false
    end

    if not InCombatLockdown() then
        local ok, err = pcall(callback)
        if not ok then
            Compat.Print(tostring(err))
            return false
        end
        return true
    end

    local safeKey = key or tostring(callback)
    deferredActions[safeKey] = callback
    if not deferredFrame:IsEventRegistered("PLAYER_REGEN_ENABLED") then
        deferredFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return false
end

function Compat.OpenChatEditBox(chatType, target, text)
    local preferredType = chatType or "SAY"
    local editBox = ChatEdit_ChooseBoxForSend(preferredType)
    if not editBox then
        return false
    end

    ChatEdit_ActivateChat(editBox)

    if preferredType == "WHISPER" and target and target ~= "" then
        ChatEdit_SetChatType(editBox, "WHISPER", nil, target)
    elseif preferredType and preferredType ~= "" then
        ChatEdit_SetChatType(editBox, preferredType)
    end

    editBox:SetText(text or "")
    editBox:SetCursorPosition(editBox:GetNumLetters())

    return true
end
