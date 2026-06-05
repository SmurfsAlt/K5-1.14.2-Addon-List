-- scope stuff
gearquipper = gearquipper or {};
local c = gearquipper;

local quickBars;
local defaultSlotSize, defaultSlotMargin = 38, 8;
local defaultSlotSize_Ammo, defaultSlotMargin_Ammo = 26, 10;

local function GetSlotDimensions(slotId)
    if slotId == INVSLOT_AMMO then
        return defaultSlotSize_Ammo, defaultSlotMargin_Ammo;
    end
    return defaultSlotSize, defaultSlotMargin;
end

function c:CreateQuickBar(slotId)
    local parent = _G["Character" .. c:GetSlotInfo(slotId)];
    local frame = CreateFrame("Frame", "GQ_QuickBar_" .. slotId, parent);
    local slotSize, slotMargin = GetSlotDimensions(slotId);

    frame:SetFrameStrata("HIGH");
    frame:SetScript("OnHide", function()
        c:HighlightItemsInBags();
        ClearCursor();
    end);

    frame.parent = parent;

    frame.border = frame:CreateTexture("GQ_QuickBarBorderTex", "BORDER");
    frame.border:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot.blp");
    frame.border:SetPoint("TOPLEFT");

    if c:IsWeaponSlot(slotId) then
        frame:SetWidth(slotSize + slotMargin);
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", -(slotMargin / 3 * 2), -slotSize);
        frame.border:SetWidth(slotSize + slotMargin);
    else
        frame:SetHeight(slotSize + slotMargin);
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", slotSize, slotMargin / 2);
        frame.border:SetHeight(slotSize + slotMargin);
    end

    local S = c:GetElvUiSkinModule();
    if S then
        S:HandleFrame(frame);
    end

    return frame;
end

function c:CreateQuickSlot(slotId, index)
    local frame = CreateFrame("Button", "GQ_QuickSlot_" .. slotId .. "_" .. index, quickBars[slotId],
        "GqQuickSlotTemplate");
    local slotSize, slotMargin = GetSlotDimensions(slotId);

    frame:SetWidth(slotSize);
    frame:SetHeight(slotSize);
    frame:SetFrameStrata("HIGH");

    if c:IsWeaponSlot(slotId) then
        frame:SetPoint("TOPLEFT", quickBars[slotId], "TOPLEFT", slotMargin / 2,
            -(slotSize * (index - 1)) - (slotMargin * (index - 1)) - slotMargin);
    else
        frame:SetPoint("TOPLEFT", quickBars[slotId], "TOPLEFT",
            (slotSize * (index - 1)) + (slotMargin * (index - 1)) + slotMargin, -(slotMargin / 2));
    end

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
        GameTooltip:SetHyperlink(self.link);
        GameTooltip:Show();
    end);
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    frame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ClearCursor();

            local itemString = self:GetAttribute("item2");
            -- local itemLink = c:GetItemLink(itemString);
            if not c:FindItemInBags(itemString) and c:IsAtBank() then
                -- item not in bag -> check in bank
                local bagSpaceCache = c:GetBagSpace();
                if c:GetItemFromBank(itemString, bagSpaceCache) then
                    C_Timer.After(c:GetHomeLatency(100) / 1000, function()
                        EquipItemByName(itemString, slotId);
                    end);
                end
            elseif slotId == 0 then
                EquipItemByName(itemString); -- ammo workaround
            else
                EquipItemByName(itemString, slotId);
            end

            c:CloseQuickBar(slotId);
            GameTooltip:Hide();
        end
    end);

    return frame;
end

function c:AddQuickSlot(slotId, slotIndex, itemEntry)
    local quickBar = quickBars[slotId];
    quickBar.slots[slotIndex] = quickBar.slots[slotIndex] or c:CreateQuickSlot(slotId, slotIndex);
    local quickSlot = quickBar.slots[slotIndex];

    local link, quality, count, texture;
    if itemEntry[c.ITEM_BAG_ID] then
        texture, count, _, quality, _, _, link = c:GetContainerItemInfo(itemEntry[c.ITEM_BAG_ID],
            itemEntry[c.ITEM_SLOT_ID]);
    else
        _, link, quality, _, _, _, _, count, _, texture = GetItemInfo(itemEntry[c.ITEM_STRING]);
    end

    quickSlot.link = link;
    quickSlot.itemString = itemEntry[c.ITEM_STRING];
    quickSlot:SetAttribute("item2", itemEntry[c.ITEM_STRING]);
    quickSlot.icon:SetTexture(texture);
    if count > 1 then
        quickSlot.count:SetText(count);
        quickSlot.count:Show();
    else
        quickSlot.count:Hide();
    end

    if quality > 1 then
        local r, g, b, hex = GetItemQualityColor(quality);
        quickSlot.glow:SetVertexColor(r, g, b);
        quickSlot.glow:Show();
    else
        quickSlot.glow:Hide();
    end

    quickSlot:Show();
end

local function HasQuickSlot(quickBar, itemEntry)
    for slotIndex, quickSlot in pairs(quickBar.slots) do
        if quickSlot.itemString == itemEntry[c.ITEM_STRING] then
            return true;
        end
    end
end

function c:OpenQuickBar(slotId)
    if not c:IsInCombat() and not c:IsDead() and slotId then
        local matchingItems, noSlots = c:GetMatchingItems(slotId);
        if noSlots > 0 then
            local slotSize, slotMargin = GetSlotDimensions(slotId);

            quickBars = quickBars or {};
            quickBars[slotId] = quickBars[slotId] or c:CreateQuickBar(slotId);
            quickBars[slotId].slots = quickBars[slotId].slots or {};
            local itemStrings = {};

            local index = 0;
            for _, itemEntry in ipairs(matchingItems) do
                local itemString = itemEntry[c.ITEM_STRING];
                if not slotId == INVSLOT_AMMO or
                    (not c:IsItemEquipped(c:GetItemId(itemString)) and not HasQuickSlot(quickBars[slotId], itemEntry)) then
                    index = index + 1;
                    c:AddQuickSlot(slotId, index, itemEntry);
                    tinsert(itemStrings, itemString);
                end
            end

            if index > 0 then
                local S = c:GetElvUiSkinModule();

                if c:IsWeaponSlot(slotId) then
                    quickBars[slotId].border:SetHeight((slotSize * index) + (slotMargin * (index - 1)) +
                                                           (slotMargin * 2));
                    -- if S then
                    -- quickBars[slotId]:SetHeight((slotSize * index) + (slotMargin * (index - 1)));
                    -- else
                    quickBars[slotId]:SetHeight((slotSize * index) + (slotMargin * (index - 1)));
                    -- end
                else
                    quickBars[slotId].border:SetWidth((slotSize * index) + (slotMargin * (index - 1)) + (slotMargin * 2));
                    if S then
                        quickBars[slotId]:SetWidth((slotSize * index) + (slotMargin * (index - 1)) + 16);
                    else
                        quickBars[slotId]:SetWidth((slotSize * index) + (slotMargin * (index - 1)));
                    end
                end
                quickBars[slotId]:Show();

                c:HighlightItemsInBags(itemStrings);
                GameTooltip:Hide();

                return quickBars[slotId];
            end
        end
    end
end

function c:CloseQuickBars()
    if not c:IsInCombat() and not c:IsDead() and quickBars then
        for slotId, quickBar in pairs(quickBars) do
            c:CloseQuickBar(slotId);
        end
    end
end

function c:CloseQuickBar(slotId)
    if not c:IsInCombat() and not c:IsDead() and quickBars and quickBars[slotId] then
        quickBars[slotId]:Hide();
        for index, slot in pairs(quickBars[slotId].slots) do
            slot.itemString = nil;
            slot:Hide();
        end
        quickBars[slotId].parent.quickbar = nil;
    end
end
