if GetLocale() ~= "koKR" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "플로팅"
L["PANEL_MODE_DOCKED"] = "도킹"
