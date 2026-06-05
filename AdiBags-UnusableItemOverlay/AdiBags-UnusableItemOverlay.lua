local _, ns = ...

local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = setmetatable({}, {__index = addon.L})

local mod = addon:NewModule("UnusableItemOverlay", 'ABEvent-1.0')
mod.uiName = L['Unusable item overlay']
mod.uiDesc = L["Adds a red overlay to items that are unusable for you (by searching for red text in the tooltip)"]

local enabled = false

function mod:OnInitialize()
end

function mod:OnEnable()
    enabled = true
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	self:SendMessage('AdiBags_UpdateAllButtons')
end

function mod:OnDisable()
    enabled = false
	self:SendMessage('AdiBags_UpdateAllButtons')
end

function mod:GetOptions()
end

function mod:UpdateButton(event, button)
    local vertexColor = button.UnusableInidicatorVertexColorModified

    if enabled and mod:ScanTooltipOfBagItemForRedText(button.bag, button.slot) then
        if not vertexColor then
            button.UnusableInidicatorVertexColor = true
            button.icon:SetVertexColor(1, 0.1, 0.1)
        end
    else
        if vertexColor then
            button.UnusableInidicatorVertexColor = false
            button.icon:SetVertexColor(1, 1, 1)
        end
    end
end

local function roundRGB(r, g, b)
    return floor(r * 100 + 0.5) / 100, floor(g * 100 + 0.5) / 100, floor(b * 100 + 0.5) / 100
end

local function isTextColorRed(textTable)
    if not textTable then
        return false
    end

    local text = textTable:GetText()
    if not text or text == "" then
        return false
    end

    local r, g, b = roundRGB(textTable:GetTextColor())
    return r == 1 and g == 0.13 and b == 0.13
end

function mod:ScanTooltipOfBagItemForRedText(bag, slot)
    local tooltipName = "AdibagsUnusableItemOverlayScanningTooltip"
    local tooltip = _G[tooltipName]
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)
    for i=1, tooltip:NumLines() do
        if isTextColorRed(_G[tooltipName .. "TextLeft" .. i]) or isTextColorRed(_G[tooltipName .. "TextRight" .. i]) then
            return true
        end
    end

    return false
end
