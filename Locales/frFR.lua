if GetLocale() ~= "frFR" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Flottant"
L["PANEL_MODE_DOCKED"] = "Ancre"
