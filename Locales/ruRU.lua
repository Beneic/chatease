if GetLocale() ~= "ruRU" then
    return
end

local L = select(2, ...).L

L["PANEL_MODE_FLOATING"] = "Плавающая"
L["PANEL_MODE_DOCKED"] = "Закрепленная"
