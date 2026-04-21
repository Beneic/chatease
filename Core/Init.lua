local ADDON_NAME, ns = ...

local eventFrame = CreateFrame("Frame")

local function ApplyMigrations()
    local db = ns.db
    local currentVersion = tonumber(db.schemaVersion) or 0
    local targetVersion = tonumber(ns.DB_DEFAULTS.schemaVersion) or 0

    if currentVersion < 2 then
        if type(db.ui) == "table" then
            local floating = db.ui.floatingSize
            if type(floating) ~= "table" then
                db.ui.floatingSize = { width = 430, height = 520 }
            elseif floating.width == 380 and floating.height == 460 then
                floating.width = 430
                floating.height = 520
            end

            local docked = db.ui.dockedSize
            if type(docked) ~= "table" then
                db.ui.dockedSize = { width = 340, height = 430 }
            elseif docked.width == 300 and docked.height == 360 then
                docked.width = 340
                docked.height = 430
            end
        end
        currentVersion = 2
    end

    if currentVersion < 3 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {
                enabled = true,
                locked = false,
                anchor = {
                    point = "TOPLEFT",
                    relativePoint = "TOPLEFT",
                    x = 0,
                    y = 8,
                    relativeToChatFrame = true,
                },
            }
        else
            if db.chatBar.enabled == nil then
                db.chatBar.enabled = true
            end
            if db.chatBar.locked == nil then
                db.chatBar.locked = false
            end
            if type(db.chatBar.anchor) ~= "table" then
                db.chatBar.anchor = {
                    point = "TOPLEFT",
                    relativePoint = "TOPLEFT",
                    x = 0,
                    y = 8,
                    relativeToChatFrame = true,
                }
            end
        end
        currentVersion = 3
    end

    if currentVersion < 4 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        if db.chatBar.style ~= "text" and db.chatBar.style ~= "icon" then
            db.chatBar.style = "icon"
        end
        currentVersion = 4
    end

    if currentVersion < 5 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        if db.chatBar.iconSet ~= "color" and db.chatBar.iconSet ~= "class" and db.chatBar.iconSet ~= "mono" then
            db.chatBar.iconSet = "color"
        end
        currentVersion = 5
    end

    if currentVersion < 6 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        db.chatBar.style = "text"
        currentVersion = 6
    end

    if currentVersion < 7 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        if db.chatBar.showBackground == nil then
            db.chatBar.showBackground = false
        end
        currentVersion = 7
    end

    if currentVersion < 8 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        if type(db.chatBar.scale) ~= "number" then
            db.chatBar.scale = 1
        end
        currentVersion = 8
    end

    if currentVersion < 9 then
        if type(db.chatBar) ~= "table" then
            db.chatBar = {}
        end
        if type(db.chatBar.preferredAlias) ~= "string" or db.chatBar.preferredAlias == "" then
            db.chatBar.preferredAlias = "s"
        end
        currentVersion = 9
    end

    if currentVersion < 10 then
        if type(db.templates) == "table" then
            local pullTemplate = db.templates.pull
            if type(pullTemplate) == "table" then
                pullTemplate.kind = "slash"
                pullTemplate.content = "/pull"
            end

            local readyTemplate = db.templates.ready
            if type(readyTemplate) == "table" then
                readyTemplate.kind = "slash"
                readyTemplate.content = "/ready"
            end

            local rollTemplate = db.templates.roll
            if type(rollTemplate) == "table" then
                rollTemplate.kind = "slash"
                rollTemplate.content = "/roll"
            end
        end
        currentVersion = 10
    end

    if currentVersion < targetVersion then
        currentVersion = targetVersion
    end

    db.schemaVersion = currentVersion
end

local function InitializeDatabases()
    ChatEaseDB = ChatEaseDB or {}
    ChatEaseCharDB = ChatEaseCharDB or {}

    ns.db = ChatEaseDB
    ns.charDb = ChatEaseCharDB

    ns.Compat.MergeDefaults(ns.db, ns.DB_DEFAULTS)
    ns.Compat.MergeDefaults(ns.charDb, ns.CHAR_DEFAULTS)
    ApplyMigrations()
end

local function RegisterSlashCommands()
    SLASH_CHATEASE1 = "/ce"
    SLASH_CHATEASE2 = "/chatease"
    SlashCmdList.CHATEASE = function(message)
        ns.CommandRouter:HandleSlash(message or "")
    end
end

local function SafeInitBlock(label, callback)
    local ok, err = pcall(callback)
    if not ok then
        ns.Compat.Print(string.format("Init failed (%s): %s", tostring(label), tostring(err)))
        return false
    end
    return true
end

local function InitializeAddon()
    InitializeDatabases()
    RegisterSlashCommands()

    ns.Theme:Refresh()

    ns.TemplateStore:Init(ns.db, ns.charDb)
    ns.CommandRouter:Init()

    SafeInitBlock("ConfigPanel", function()
        ns.ConfigPanel:Init()
    end)
    SafeInitBlock("ChatBar", function()
        ns.ChatBar:Init()
    end)

    if not ns.Compat.IsRetail1201OrNewer() then
        ns.Compat.Print(ns.L["WARN_INTERFACE_VERSION"])
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        InitializeAddon()
    end
end)
