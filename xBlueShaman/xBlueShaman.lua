-- xBlueShaman (Modified for ElvUI Initialization)
-- Author: xHaplo

local NEW_R, NEW_G, NEW_B = 0.0, 0.44, 0.87
local NEW_COLOR_STR = string.format("ff%02x%02x%02x",
    math.floor(NEW_R * 255 + 0.5),
    math.floor(NEW_G * 255 + 0.5),
    math.floor(NEW_B * 255 + 0.5))

-- 1. Create CUSTOM_CLASS_COLORS immediately so ElvUI's API finds it on startup
if not _G.CUSTOM_CLASS_COLORS then
    _G.CUSTOM_CLASS_COLORS = _G.CopyTable(_G.RAID_CLASS_COLORS)
end

-- 2. Apply the dark blue color to both global tables instantly
if _G.RAID_CLASS_COLORS["SHAMAN"] then
    _G.RAID_CLASS_COLORS["SHAMAN"].r = NEW_R
    _G.RAID_CLASS_COLORS["SHAMAN"].g = NEW_G
    _G.RAID_CLASS_COLORS["SHAMAN"].b = NEW_B
    _G.RAID_CLASS_COLORS["SHAMAN"].colorStr = NEW_COLOR_STR
end

if _G.CUSTOM_CLASS_COLORS["SHAMAN"] then
    _G.CUSTOM_CLASS_COLORS["SHAMAN"].r = NEW_R
    _G.CUSTOM_CLASS_COLORS["SHAMAN"].g = NEW_G
    _G.CUSTOM_CLASS_COLORS["SHAMAN"].b = NEW_B
    _G.CUSTOM_CLASS_COLORS["SHAMAN"].colorStr = NEW_COLOR_STR
end