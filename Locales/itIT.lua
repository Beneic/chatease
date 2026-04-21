if GetLocale() ~= "itIT" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Flottante"
L["PANEL_MODE_DOCKED"] = "Ancorato"
