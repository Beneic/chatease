local _, ns = ...

local Permission = {}
ns.Permission = Permission

local function IsInAnyGroup()
    return IsInRaid() or IsInGroup() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end

local function IsLeaderOrAssistant()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function Permission:HasPermission(permissionKey)
    if not permissionKey or permissionKey == "" then
        return true
    end

    if permissionKey == "rw" then
        if not IsInAnyGroup() then
            return false, "ERROR_PERMISSION_RW_NO_GROUP"
        end
        if not IsLeaderOrAssistant() then
            return false, "ERROR_PERMISSION_RW"
        end
    end

    return true
end

function Permission:Check(permissionKey)
    local ok, errorKey = self:HasPermission(permissionKey)
    if ok then
        return true
    end

    if ns.db and ns.db.showPermissionErrors ~= false then
        local message = ns.L[errorKey] or ns.L["ERROR_PERMISSION_GENERIC"] or "Permission denied."
        ns.Compat.Print(message)
    end

    return false
end
