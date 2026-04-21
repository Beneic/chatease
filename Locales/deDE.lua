if GetLocale() ~= "deDE" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Schwebend"
L["PANEL_MODE_DOCKED"] = "Angedockt"
