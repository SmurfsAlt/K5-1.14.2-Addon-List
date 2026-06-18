local blueColor = { r = 0.00, g = 0.44, b = 0.87, colorStr = "ff0070dd" }

-- 1. Standard Global Overrides (for Chat, Tooltips, and Unitframes)
if _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS["SHAMAN"] then
    _G.RAID_CLASS_COLORS["SHAMAN"] = blueColor
end
if _G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS["SHAMAN"] then
    _G.CUSTOM_CLASS_COLORS["SHAMAN"] = blueColor
end

-- 2. Direct ElvUI Internal Injection
local function InjectElvUIColor()
    if not _G.ElvUI then return end
    local E = unpack(_G.ElvUI)
    if not E then return end

    -- Force ElvUI's engine-level class color reference
    if E.ClassColors then
        E.ClassColors["SHAMAN"] = blueColor
    end

    -- Force ElvUI's media/palette framework colors
    if E.media then
        if not E.media.classcolors then E.media.classcolors = {} end
        E.media.classcolors["SHAMAN"] = blueColor
    end

    -- Intercept the Nameplate Module specifically
    local NP = E:GetModule('NamePlates', true)
    if NP then
        -- Force the nameplate styling configuration to see the new color
        if NP.db and NP.db.colors and NP.db.colors.class then
            NP.db.colors.class["SHAMAN"] = blueColor
        end
        
        -- If oUF is active, force its internal element colors to update
        if E.oUF and E.oUF.colors then
            E.oUF.colors.class["SHAMAN"] = { 0.00, 0.44, 0.87 }
        end

        -- Trigger a hard redraw of every active nameplate on screen
        if NP.UpdateAllPlates then
            NP:UpdateAllPlates()
        end
    end
end

-- Execute the injection as soon as ElvUI finishes initializing its database
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    InjectElvUIColor()
    
    -- Secondary fallback: ensuring a redraw when entering the world
    if event == "PLAYER_ENTERING_WORLD" then
        local E = unpack(_G.ElvUI)
        if E then
            local NP = E:GetModule('NamePlates', true)
            if NP and NP.UpdateAllPlates then
                NP:UpdateAllPlates()
            end
        end
        self:UnregisterAllEvents()
    end
end)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")