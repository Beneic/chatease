if GetLocale() ~= "esES" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Flotante"
L["PANEL_MODE_DOCKED"] = "Acoplado"
