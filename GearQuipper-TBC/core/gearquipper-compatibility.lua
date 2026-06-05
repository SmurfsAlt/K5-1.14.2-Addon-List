gearquipper = gearquipper or {};
local c = gearquipper;

-- WOTLK new API patch
if C_Container then
    ContainerIDToInventoryID = ContainerIDToInventoryID or C_Container.ContainerIDToInventoryID;
    GetContainerItemCooldown = GetContainerItemCooldown or C_Container.GetContainerItemCooldown;
    GetContainerItemLink = GetContainerItemLink or C_Container.GetContainerItemLink;
    GetContainerNumFreeSlots = GetContainerNumFreeSlots or C_Container.GetContainerNumFreeSlots;
    GetContainerNumSlots = GetContainerNumSlots or C_Container.GetContainerNumSlots;
    GetItemCooldown = GetItemCooldown or C_Container.GetItemCooldown;
    PickupContainerItem = PickupContainerItem or C_Container.PickupContainerItem;
end

function c:ClearPushedTexture(frame)
    if frame.ClearPushedTexture then
        frame:ClearPushedTexture();
    else
        frame:SetPushedTexture(nil);
    end
end

function c:GetContainerItemInfo(bagId, slotId)
    if C_Container then
        local info = C_Container.GetContainerItemInfo(bagId, slotId);
        return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot,
            info.hyperlink, info.isFiltered, info.hasNoValue, info.itemID, info.isBound;
    end
    return _G.GetContainerItemInfo(bagId, slotId)
end
