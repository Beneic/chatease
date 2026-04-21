if GetLocale() ~= "ptBR" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Flutuante"
L["PANEL_MODE_DOCKED"] = "Acoplado"
