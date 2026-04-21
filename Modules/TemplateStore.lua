local _, ns = ...

local TemplateStore = {}
ns.TemplateStore = TemplateStore

local function ContainsId(order, id)
    for _, existingId in ipairs(order) do
        if existingId == id then
            return true
        end
    end
    return false
end

local function CleanOrder(db)
    local clean = {}
    local seen = {}

    if type(db.templateOrder) == "table" then
        for _, id in ipairs(db.templateOrder) do
            if type(id) == "string" and db.templates[id] and not seen[id] then
                table.insert(clean, id)
                seen[id] = true
            end
        end
    end

    for id in pairs(db.templates) do
        if not seen[id] then
            table.insert(clean, id)
            seen[id] = true
        end
    end

    db.templateOrder = clean
end

local function NormalizeTemplate(id, raw)
    local template = ns.Compat.Clone(raw or {})
    template.id = id
    template.defaultChannel = ns.Compat.NormalizeToken(template.defaultChannel or "s")
    if template.defaultChannel == "" then
        template.defaultChannel = "s"
    end

    if template.enabled == nil then
        template.enabled = true
    end

    if template.kind ~= "slash" then
        template.kind = "chat"
    end

    template.content = template.content or ""
    return template
end

local function NormalizeOverride(rawOverride)
    if type(rawOverride) ~= "table" then
        return nil
    end

    local normalized = {}

    if rawOverride.enabled ~= nil then
        normalized.enabled = rawOverride.enabled and true or false
    end

    if rawOverride.defaultChannel ~= nil then
        local alias = ns.Compat.NormalizeToken(rawOverride.defaultChannel)
        if alias ~= "" then
            normalized.defaultChannel = alias
        end
    end

    if rawOverride.order ~= nil then
        local numericOrder = tonumber(rawOverride.order)
        if numericOrder then
            normalized.order = math.floor(numericOrder)
        end
    end

    local hasAnyField = false
    for _ in pairs(normalized) do
        hasAnyField = true
        break
    end

    if not hasAnyField then
        return nil
    end

    return normalized
end

local function GetOverrideOrder(override)
    if type(override) ~= "table" then
        return nil
    end

    local numericOrder = tonumber(override.order)
    if not numericOrder then
        return nil
    end

    return math.floor(numericOrder)
end

function TemplateStore:Init(db, charDb)
    self.db = db
    self.charDb = charDb

    if type(self.db.templates) ~= "table" then
        self.db.templates = {}
    end

    if type(self.db.templateOrder) ~= "table" then
        self.db.templateOrder = {}
    end

    if type(self.charDb.templateOverrides) ~= "table" then
        self.charDb.templateOverrides = {}
    end

    CleanOrder(self.db)
end

function TemplateStore:GetBaseTemplate(id)
    return self.db.templates[id]
end

function TemplateStore:GetCharOverride(id)
    return self.charDb.templateOverrides[id]
end

function TemplateStore:GetTemplate(id)
    local base = self.db.templates[id]
    if not base then
        return nil
    end

    local template = NormalizeTemplate(id, base)
    local override = self.charDb.templateOverrides[id]
    if type(override) == "table" then
        if override.enabled ~= nil then
            template.enabled = override.enabled and true or false
        end
        if override.defaultChannel ~= nil then
            template.defaultChannel = ns.Compat.NormalizeToken(override.defaultChannel)
            if template.defaultChannel == "" then
                template.defaultChannel = "s"
            end
        end
    end

    return template
end

function TemplateStore:GetTemplateName(template)
    if not template then
        return ""
    end

    if template.displayName and ns.Compat.Trim(template.displayName) ~= "" then
        return template.displayName
    end

    if template.nameKey and ns.L[template.nameKey] then
        return ns.L[template.nameKey]
    end

    return template.id or ""
end

function TemplateStore:GetOrderedIds()
    local ids = {}
    local index = {}
    for orderIndex, id in ipairs(self.db.templateOrder) do
        if self.db.templates[id] then
            table.insert(ids, id)
            index[id] = orderIndex
        end
    end

    table.sort(ids, function(leftId, rightId)
        local leftOverride = self.charDb.templateOverrides[leftId]
        local rightOverride = self.charDb.templateOverrides[rightId]
        local leftOrder = GetOverrideOrder(leftOverride)
        local rightOrder = GetOverrideOrder(rightOverride)

        if leftOrder and rightOrder and leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        if leftOrder and not rightOrder then
            return true
        end
        if rightOrder and not leftOrder then
            return false
        end

        return (index[leftId] or 9999) < (index[rightId] or 9999)
    end)

    return ids
end

function TemplateStore:GetTemplates(options)
    options = options or {}

    local includeDisabled = options.includeDisabled == true
    local needle = ns.Compat.NormalizeToken(options.search or "")
    local templates = {}

    for _, id in ipairs(self:GetOrderedIds()) do
        local template = self:GetTemplate(id)
        if template and (includeDisabled or template.enabled ~= false) then
            if needle == "" then
                table.insert(templates, template)
            else
                local name = self:GetTemplateName(template)
                local haystack = string.lower((id or "") .. "\001" .. (name or "") .. "\001" .. (template.content or ""))
                if string.find(haystack, needle, 1, true) then
                    table.insert(templates, template)
                end
            end
        end
    end

    return templates
end

function TemplateStore:UpsertTemplate(rawTemplate)
    if type(rawTemplate) ~= "table" then
        return false, "ERROR_TEMPLATE_INVALID"
    end

    local id = ns.Compat.NormalizeToken(rawTemplate.id)
    if id == "" then
        return false, "ERROR_TEMPLATE_ID_REQUIRED"
    end

    local template = self.db.templates[id] or {}

    template.displayName = ns.Compat.Trim(rawTemplate.displayName or "")
    if template.displayName == "" then
        template.displayName = nil
    end

    if rawTemplate.nameKey ~= nil then
        template.nameKey = rawTemplate.nameKey
    end

    template.defaultChannel = ns.Compat.NormalizeToken(rawTemplate.defaultChannel or template.defaultChannel or "s")
    if template.defaultChannel == "" then
        template.defaultChannel = "s"
    end

    template.content = rawTemplate.content or template.content or ""
    template.enabled = rawTemplate.enabled ~= false
    template.kind = (rawTemplate.kind == "slash") and "slash" or "chat"
    template.category = rawTemplate.category or template.category or "general"
    template.requirePermission = rawTemplate.requirePermission

    if type(rawTemplate.tags) == "table" then
        template.tags = ns.Compat.Clone(rawTemplate.tags)
    elseif template.tags == nil then
        template.tags = {}
    end

    self.db.templates[id] = template

    if not ContainsId(self.db.templateOrder, id) then
        table.insert(self.db.templateOrder, id)
    end

    CleanOrder(self.db)
    return true, id
end

function TemplateStore:SetCharOverride(id, rawOverride)
    if not id or id == "" then
        return
    end

    local override = NormalizeOverride(rawOverride)
    if not override then
        self.charDb.templateOverrides[id] = nil
        return
    end

    self.charDb.templateOverrides[id] = override
end

function TemplateStore:ClearCharOverride(id)
    if not id or id == "" then
        return
    end

    self.charDb.templateOverrides[id] = nil
end

function TemplateStore:DeleteTemplate(id)
    if not id or id == "" then
        return false
    end

    if not self.db.templates[id] then
        return false
    end

    self.db.templates[id] = nil
    self.charDb.templateOverrides[id] = nil

    for index = #self.db.templateOrder, 1, -1 do
        if self.db.templateOrder[index] == id then
            table.remove(self.db.templateOrder, index)
        end
    end

    return true
end

function TemplateStore:MoveTemplate(id, delta)
    if not id or not delta or delta == 0 then
        return false
    end

    local orderedIds = self:GetOrderedIds()

    local sourceIndex
    for index, currentId in ipairs(orderedIds) do
        if currentId == id then
            sourceIndex = index
            break
        end
    end

    if not sourceIndex then
        return false
    end

    local destinationIndex = math.max(1, math.min(#orderedIds, sourceIndex + delta))
    if destinationIndex == sourceIndex then
        return false
    end

    local sourceOverride = GetOverrideOrder(self.charDb.templateOverrides[id])
    local destinationId = orderedIds[destinationIndex]
    local destinationOverride = GetOverrideOrder(self.charDb.templateOverrides[destinationId])

    table.remove(orderedIds, sourceIndex)
    table.insert(orderedIds, destinationIndex, id)

    if sourceOverride or destinationOverride then
        for orderIndex, currentId in ipairs(orderedIds) do
            local existingOverride = self.charDb.templateOverrides[currentId]
            local updatedOverride

            if type(existingOverride) == "table" then
                updatedOverride = ns.Compat.Clone(existingOverride)
            else
                updatedOverride = {}
            end

            updatedOverride.order = orderIndex
            self.charDb.templateOverrides[currentId] = updatedOverride
        end
        return true
    end

    self.db.templateOrder = orderedIds
    return true
end
