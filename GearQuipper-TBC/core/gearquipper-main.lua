-- scope stuff
gearquipper = gearquipper or {};
local c = gearquipper;

local switchId, switchQueue, switching, bankAction = 0, {};
local inCombat, changingTalents, notifyInventoryError;

local lastMountState, lastStealthState, lastPvPState, lastAfkState, lastPartyState, lastRaidState, lastSubmergedState;
local lastDruidForm, druidShapeshiftPending;
local lastPaladinAura, paladinAuraPending;
local lastRaidRoster, lastMapId;
local lastGearAndBagsCache;

local timeoutHighlightButtons = 1;

local BLIZZARD_UI_ADDONS = {"Blizzard_AchievementUI", "Blizzard_TalentUI", "Blizzard_TradeSkillUI"};

local QUEUE_CAUSE_COMBAT = "combat";
local QUEUE_CAUSE_ACTION = "action";
local QUEUE_CAUSE_INVENTORY = "inventory";

c.SWITCHARG_FIRST = "SWITCHARG_FIRST";
c.SWITCHARG_ID = "SWITCHARG_ID";
c.SWITCHARG_NOTIFY = "SWITCHARG_NOTIFY";
c.SWITCHARG_ONFINISHED = "SWITCHARG_ONFINISHED";
c.SWITCHARG_SETNAME = "SWITCHARG_SETNAME";
c.SWITCHARG_QUEUE_CAUSE = "SWITCHARG_QUEUE_CAUSE";

function c:GetCharName()
    return UnitName("player");
end

function c:GetRealmName()
    return GetRealmName();
end

local function GetNextSwitchId()
    switchId = switchId + 1;
    return switchId;
end

function c:NotifyInChat(msg)
    if GQ_OPTIONS[c.OPT_NOTIFYCHANGES] then
        c:Println(msg);
    end
end

local function HighlightButton(button)
    if button then
        ActionButton_ShowOverlayGlow(button);
        C_Timer.After(timeoutHighlightButtons, function()
            ActionButton_HideOverlayGlow(button);
        end);
    end
end

function c:HighlightInventorySlot(slotId)
    if GQ_OPTIONS[c.OPT_HIGHLIGHTCHANGES] then
        if c:GetSlotInfo()[slotId] then
            HighlightButton(_G["Character" .. c:GetSlotInfo()[slotId]]);
        end
    end
end

function c:HighlightActionSlot(slotId)
    if GQ_OPTIONS[c.OPT_HIGHLIGHTCHANGES] then
        HighlightButton(c:GetActionButton(slotId));
    end
end

function c:IsSwitching()
    return switching;
end

function c:SetSwitching(value)
    switching = value;
    if value then
        c:DebugPrint("Switching: true");
    else
        c:DebugPrint("Switching: false");
    end
end

function c:IsChangingTalents()
    return changingTalents;
end

function c:GetNextSetName(seedName)
    local setNames = c:LoadSetNames();
    if setNames then
        if not seedName then
            return setNames[1];
        end

        for i, setName in ipairs(setNames) do
            if setName == seedName then
                local result;
                if i == table.getn(setNames) then
                    result = nil;
                else
                    result = setNames[i + 1];
                end
                if result == c:LoadCurrentSetName() then
                    return c:GetNextSetName(result);
                end
                return result;
            end
        end
    end
end

-- command handling
SLASH_GEARQUIPPER1 = "/gq";
local CMD_DEBUG = "debug";
local CMD_RESET = "reset";
local CMD_SAVE = "save";
local CMD_SWITCH = "switch";
local CMD_SWITCHWAIT = "switchwait";
local CMD_TOGGLEEVENTS = "toggleevents";

local CMD_AFFECTSHELMET = "affectshelmet";
local CMD_AFFECTSCLOAK = "affectscloak";

SlashCmdList["GEARQUIPPER"] = function(msg)
    if msg then
        if c.initFinished then
            msg = c:Trim(msg);

            if msg == CMD_DEBUG then
                c.debugMode = not c.debugMode;
                if c.debugMode then
                    c:Println("Debug mode enabled. Type '/gq debug' or relog/reload to disable.");
                else
                    c:Println("Debug mode disabled.");
                end
                return;
            elseif msg == CMD_RESET then
                c:ShowResetDialog();
                return;
            elseif c:StartsWith(msg, CMD_SWITCHWAIT, true) then
                msg = c:Trim(msg:gsub(CMD_SWITCHWAIT, ""));

                if msg ~= "" then
                    local args = c:ExtractArguments(msg);

                    if args and table.getn(args) == 2 then
                        local setName, onFinished = args[1], args[2];

                        local existingSetName = c:TableContains(c:LoadSetNames(), setName, true);
                        if existingSetName then
                            c:QueueSwitch({
                                [c.SWITCHARG_SETNAME] = existingSetName,
                                [c.SWITCHARG_ONFINISHED] = onFinished
                            });
                            return;
                        else
                            c:Println(c:GetText("Macro warning: There is no set named \"%s\".", setName));
                        end
                    end
                end
            elseif c:StartsWith(msg, CMD_SWITCH, true) then
                msg = c:Trim(msg:gsub(CMD_SWITCH, ""));
                local existingSets, setNames = c:LoadSetNames(), {};

                if msg ~= "" then
                    for _, v in ipairs(c:ExtractArguments(msg)) do
                        if string.upper(v) == c.KEYWORD_PREVIOUS then
                            table.insert(setNames, c.KEYWORD_PREVIOUS);
                        elseif string.upper(v) == c.KEYWORD_PREVIOUSEQUIPMENT then
                            table.insert(setNames, c.KEYWORD_PREVIOUSEQUIPMENT);
                        else
                            local existingSetName = c:TableContains(existingSets, v, true);
                            if existingSetName then
                                table.insert(setNames, existingSetName);
                            else
                                c:Println(c:GetText("Macro warning: There is no set named \"%s\".", v));
                            end
                        end
                    end
                else
                    setNames = c:Deepcopy(existingSets);
                end

                local noSets = table.getn(setNames);
                if noSets == 1 then
                    c:QueueSwitch({
                        [c.SWITCHARG_SETNAME] = setNames[1]
                    });
                elseif noSets > 1 then
                    local currentSet = c:LoadCurrentSetName();
                    for k, v in ipairs(setNames) do
                        if v == currentSet then
                            local index = k + 1;
                            if index > noSets then
                                index = 1;
                            end
                            c:QueueSwitch({
                                [c.SWITCHARG_SETNAME] = setNames[index]
                            });
                            return;
                        end
                    end

                    c:ResetIgnoredSlots();
                    c:QueueSwitch({
                        [c.SWITCHARG_SETNAME] = setNames[1]
                    });
                end
                return;
            elseif c:StartsWith(msg, CMD_SAVE, true) then
                msg = c:Trim(msg:gsub(CMD_SAVE, ""));

                if msg ~= "" then
                    local existingSetName = c:TableContains(c:LoadSetNames(), msg, true);
                    if existingSetName then
                        c:SaveSet(existingSetName);
                    else
                        c:Println(c:GetText("Macro warning: There is no set named \"%s\".", msg));
                    end
                else
                    local currentSetName = c:LoadCurrentSetName();
                    if currentSetName then
                        c:SaveSet(currentSetName);
                    end
                end
                return;
            elseif msg == CMD_TOGGLEEVENTS then
                local newVal = not c:IsEventsEnabled();
                c:SetEventsEnabled(newVal);
                c:ToggleEvents(newVal);
                c:Println(c:GetText("Event bindings %s.",
                    c:BoolToText(newVal, c:GetText("enabled"), c:GetText("disabled"))));
                return;
            elseif msg == CMD_AFFECTSHELMET then
                local setName = c:LoadCurrentSetName();
                c:SetAffectsHelmet(not c:GetAffectsHelmet(setName), setName);
                return;
            elseif msg == CMD_AFFECTSCLOAK then
                local setName = c:LoadCurrentSetName();
                c:SetAffectsCloak(not c:GetAffectsCloak(setName), setName);
                return;
            end

            c:Println(c:GetText("Unknown command. Possible parameters are: /gq ..."));
            c:Println(c:GetText("affectscloak -> Toggles whether your current set affects cloak visibility or not."));
            c:Println(c:GetText("affectshelmet -> Toggles whether your current set affects helmet visibility or not."));
            c:Println(c:GetText("reset -> Resets the GearQuipper addon (e.g. in case of errors)."));
            c:Println(c:GetText("save [setname] -> Saves the specified set or the current set if omitted."));
            c:Println(c:GetText("switch [setname1] [setname2] ... -> Switches between specified sets. For macro use."));
            c:Println(c:GetText("toggleevents -> Toggles event bindings enabled or disabled."));
        else
            c:Println(c:GetText("The AddOn has not been initialized due to an error. Please relog and try again."));
        end
    end
end

-- event handling
c.eventFrame = c.eventFrame or CreateFrame("Frame");
c.eventFrame:EnableKeyboard();
c.eventFrame:SetPropagateKeyboardInput(true);
c.eventFrame:RegisterEvent("ADDON_LOADED");
c.eventFrame:RegisterEvent("PLAYER_LOGIN");
c.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
c.eventFrame:RegisterEvent("CRAFT_SHOW");
c.eventFrame:RegisterEvent("TRADE_SKILL_SHOW");
c.eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED");

-- event bindings
c.eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED");
c.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
c.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
c.eventFrame:RegisterEvent("SPELL_UPDATE_USABLE");
c.eventFrame:RegisterEvent("MIRROR_TIMER_START");
c.eventFrame:RegisterEvent("MIRROR_TIMER_STOP");
c.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
c.eventFrame:RegisterEvent("ZONE_CHANGED");
c.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS");
c.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
c.eventFrame:RegisterEvent("UNIT_AURA");
c.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE");
c.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE");

-- core features
c.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED");
c.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
c.eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
c.eventFrame:RegisterEvent("ITEM_LOCK_CHANGED");
c.eventFrame:RegisterEvent("ITEM_LOCKED");
c.eventFrame:RegisterEvent("ITEM_UNLOCKED");
c.eventFrame:RegisterEvent("BANKFRAME_OPENED");
c.eventFrame:RegisterEvent("BANKFRAME_CLOSED");

-- additional core features
c.eventFrame:RegisterEvent("PLAYER_LEVEL_UP");
c.eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB");
c.eventFrame:RegisterEvent("UPDATE_MACROS");

if not c:IsClassic() then
    -- socketing (new in tbc classic)
    c.eventFrame:RegisterEvent("SOCKET_INFO_SUCCESS");
    c.eventFrame:RegisterEvent("SOCKET_INFO_CLOSE");

    -- dual spec (new in wotlk classic)
    c.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
end

-- c.eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT");
-- c.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");

c.eventFrame:HookScript("OnEvent", function(self, event, arg1, arg2, arg3, ...)
    if event then

        -- if c.initFinished then
        --     if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        --         c:DebugPrint(event, arg1, arg2, arg3, ...);
        --     end
        -- end

        if event == "ADDON_LOADED" then
            if arg1 == "GearQuipper-TBC" and not c.initFinished then
                c:Init();
            elseif c:TableContains(BLIZZARD_UI_ADDONS, arg1) then
                c:HookBlizzardFrameScripts();
            end
        elseif event == "PLAYER_LOGIN" then
            if GwCharacterWindow then
                -- GW2_UI support
                c:InitUI(GwCharacterWindow);
            end
            c.playerLogin = true;
        elseif event == "PLAYER_ENTERING_WORLD" then
            local currentRealmName, currentCharName = GetRealmName(), c:GetCharName();
            if not c.currentSession or c.currentSession["realmName"] ~= currentRealmName or c.currentSession["charName"] ~=
                currentCharName then
                c:CreateDefaultSet();
                c:CreatePreviousEquipmentSet();

                -- set initial states
                lastMountState = IsMounted() and not UnitOnTaxi("player");
                lastStealthState = IsStealthed();
                lastPartyState = IsInGroup();
                lastRaidState = IsInRaid();
                lastPvPState = UnitIsPVP("player");
                lastAfkState = UnitIsAFK("player");
                lastSubmergedState = IsSwimming();
                lastMapId = C_Map.GetBestMapForUnit("player");

                lastDruidForm = c:GetCurrentDruidForm();
                druidShapeshiftPending = false;

                lastPaladinAura = c:GetCurrentPaladinAura();
                paladinAuraPending = false;

                c:GetMacros();
                c:LoadCloakAndHelmet();
                c.currentSession = {
                    ["realmName"] = currentRealmName,
                    ["charName"] = currentCharName
                };

                -- C_Timer.After(timeoutCreateSpellbookCache, function()
                --     c:GetSpellCache(); -- init spell id cache
                --     c:GetLearnedSpellNameAndRank(); -- init learned spells cache
                --     --c:Println(c:GetText("Spell database updated."));
                -- end);
            else
                local currentMountState = IsMounted() and not UnitOnTaxi("player");
                if currentMountState ~= lastMountState then
                    if currentMountState then
                        c:Mounting();
                    else
                        c:Dismounting();
                    end
                    lastMountState = currentMountState;
                end

                c:NewZone();
            end
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            -- pvp state change
            local currentPvPState = UnitIsPVP("player");
            if lastPvPState ~= currentPvPState then
                if currentPvPState then
                    c:HandleEvent(c.EVENT_PVP_ENABLE);
                else
                    c:HandleEvent(c.EVENT_PVP_DISABLE);
                end
                lastPvPState = currentPvPState;
            end

            local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
                destFlags, destRaidFlags, spellId, spellName, spellSchool = CombatLogGetCurrentEventInfo();
            -- c:DebugPrint(event, subevent, spellName, spellId);

            -- if sourceName == UnitName("player") then
            local playerName = sourceName == UnitName("player");
            if subevent == "SPELL_CAST_START" then
                c:SpellCastStart(spellId);
            elseif subevent == "SPELL_CAST_SUCCESS" then
                c:SpellCastSuccess(spellId);
            elseif subevent == "SPELL_CAST_FAILED" or subevent == "SPELL_INTERRUPT" then
                c:SpellCastEnd();
            elseif subevent == "SPELL_AURA_APPLIED" and sourceName == playerName then
                c:SpellAuraApplied(spellId);
            elseif subevent == "SPELL_AURA_REMOVED" and sourceName == playerName then
                c:SpellAuraRemoved(spellId);
            elseif subevent == "ENCHANT_APPLIED" then
                C_Timer.After(c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                    c:CheckForNewEnchantment();
                end);
            end
            -- end
        elseif event == "MODIFIER_STATE_CHANGED" then
            if c.initFinished and arg1 == "LALT" and GQ_OPTIONS[c.OPT_SET_ITEM_COMPARISON] and not c:IsSwitching() then
                if GameTooltip:IsVisible() and arg2 == 1 then
                    local itemName, itemLink = GameTooltip:GetItem();
                    if itemLink then
                        local comparisonSetName = c:LoadComparisonSetName();
                        if not comparisonSetName or c:GetGqTooltip():IsVisible() then
                            comparisonSetName = c:GetNextSetName(comparisonSetName);
                        end
                        if comparisonSetName then
                            if c:ShowSetItemComparison(itemLink, comparisonSetName) then
                                c:SaveComparisonSetName(comparisonSetName);
                            end
                        else
                            c:HideGqTooltips();
                            if c:GetItemSlots(itemLink) then
                                c:SaveComparisonSetName(comparisonSetName);
                            end
                        end
                    end
                end
            end
        elseif event == "SOCKET_INFO_UPDATE" then
            if c.socketingAction then
                -- needs timeout
                C_Timer.After(c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                    -- updated sockets -> save item if it is in set(s)
                    local newItemString;
                    if c:GetSlotInfo(c.socketingAction.bagOrCharacterSlotId) and not c.socketingAction.bagSlotId then
                        -- currently equipped item
                        newItemString = c:GetItemString(GetInventoryItemLink("player",
                            c.socketingAction.bagOrCharacterSlotId));
                    elseif c.socketingAction.bagSlotId then
                        -- item in bag
                        newItemString = c:GetItemString(GetContainerItemLink(c.socketingAction.bagOrCharacterSlotId,
                            c.socketingAction.bagSlotId));
                    end

                    if newItemString then
                        c:ReplaceItemStringInAllSets(c.socketingAction.itemString, newItemString, true);
                    end
                end);
                c.eventFrame:UnregisterEvent("SOCKET_INFO_UPDATE");
            end
        elseif event == "SOCKET_INFO_SUCCESS" then
            c.eventFrame:RegisterEvent("SOCKET_INFO_UPDATE");
        elseif event == "SOCKET_INFO_CLOSE" then
            c.eventFrame:UnregisterEvent("SOCKET_INFO_UPDATE");
            c.socketingAction = nil;
        elseif event == "UNIT_INVENTORY_CHANGED" then
            if arg1 == "player" then
                -- ammo slot workaround
                c:EquipmentChanged(INVSLOT_AMMO);
            end
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            if arg1 ~= INVSLOT_AMMO then
                c:EquipmentChanged(arg1);
            end
        elseif event == "ACTIONBAR_SLOT_CHANGED" then
            if not c:IsSwitching() and not c:IsChangingTalents() and c:LoadActionSlotsConditionsMet() and arg1 and arg1 >
                0 and arg1 < 121 and c:SaveConditionsMet(c.OPT_SAVECHANGES_ACTIONSLOTS) and
                (not totemic or not totemic:IsSwitching()) then
                c:SaveActionSlot(arg1);
            end
        elseif event == "PLAYER_LEVEL_UP" then
            c:LevelUp(arg1);
        elseif event == "LEARNED_SPELL_IN_TAB" then
            if not c:IsSwitching() and arg1 then
                local spellId = arg1;
                local spellName, spellRank = c:GetSpellName(spellId), c:GetSpellSubText(spellId);
                c:DebugPrint("Learned:", spellName, spellRank);
                -- C_Timer.After(c:GetHomeLatency(GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                --     c:UprankSpellOnActionSlots(spellId);
                -- end);
                c:QueueAction(function()
                    c:UprankSpellOnActionSlots(spellId);
                end, c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]));
            end
        elseif event == "UPDATE_MACROS" then
            if c.initFinished then
                c:ProcessMacroUpdate();
            end
        elseif event == "ITEM_LOCK_CHANGED" then
            if not c:IsInCombat() and not c:IsDead() and not c:IsSwitching() then
                lastGearAndBagsCache = c:CacheCurrentGearAndBags();
            end
        elseif event == "ITEM_LOCKED" then
            if not c:IsSwitching() and not bankAction then
                local bagOrCharacterSlotId, bagSlotId = tonumber(arg1), tonumber(arg2);
                if IsShiftKeyDown() and bagOrCharacterSlotId then
                    -- opened socketing frame
                    local itemString;
                    if c:GetSlotInfo(bagOrCharacterSlotId) and not bagSlotId then
                        -- currently equipped item
                        itemString = c:LoadSlot(bagOrCharacterSlotId);
                    elseif bagSlotId then
                        -- item in bag
                        itemString = c:GetItemString(GetContainerItemLink(bagOrCharacterSlotId, bagSlotId));
                    end

                    if itemString then
                        c.socketingAction = {
                            bagOrCharacterSlotId = bagOrCharacterSlotId,
                            bagSlotId = bagSlotId,
                            itemString = itemString
                        };
                    end
                elseif not bagSlotId and c:GetSlotInfo(bagOrCharacterSlotId) then
                    c:OpenQuickBar(bagOrCharacterSlotId);
                end
            end
        elseif event == "ITEM_UNLOCKED" then
            c:CloseQuickBars();
            if GqUiFrame:IsVisible() and not c:IsSwitching() then
                c:RefreshSetList();
            end
        elseif event == "UNIT_AURA" then
            C_Timer.After(c:GetHomeLatency(GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                local currentMountState, currentStealthState = IsMounted() and not UnitOnTaxi("player"), IsStealthed();
                if currentMountState ~= lastMountState then
                    if currentMountState then
                        c:Mounting();
                    else
                        c:Dismounting();
                    end
                    lastMountState = currentMountState;
                end
                if currentStealthState ~= lastStealthState then
                    if currentStealthState then
                        c:HandleEvent(c.EVENT_STEALTH);
                    else
                        c:HandleEvent(c.EVENT_UNSTEALTH);
                    end
                    lastStealthState = currentStealthState;
                end
                c:SpellAuraApplied();
            end);
        elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
            if GqUiFrame:IsVisible() then
                -- timeout neccessary for closing event
                C_Timer.After(c:GetLatency(GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                    c:RefreshSetList(true);
                end);
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            c:LeaveCombat();
        elseif event == "PLAYER_REGEN_DISABLED" then
            c:EnterCombat();
        elseif event == "PLAYER_FLAGS_CHANGED" then
            local currentAfkState = UnitIsAFK("player");
            if lastAfkState ~= currentAfkState then
                if currentAfkState then
                    c:HandleEvent(c.EVENT_AFK_ENABLE);
                else
                    c:HandleEvent(c.EVENT_AFK_DISABLE);
                end
                lastAfkState = currentAfkState;
            end
        elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
            if c.initFinished and c.playerLogin then

                changingTalents = true;
                local func = function()
                    -- dual spec changed
                    local newTalentSet, oldTalentSet = arg1, arg2;
                    -- timeout needed for waiting until blizzard default action slot feature completed
                    C_Timer.After(c:GetHomeLatency(1000 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                        if not c:HandleEvent(c.EVENT_TALENTS_CHANGED, newTalentSet) then
                            -- reload current action slots if no event was triggered
                            local currentSetName = c:LoadCurrentSetName();
                            if c:LoadActionSlotsConditionsMet(currentSetName) then
                                c:LoadActionConfiguration(currentSetName);
                            end
                        end
                        changingTalents = false;
                    end);
                end;
                -- /run GQ_OPTIONS["OPT_ACTIONBARS_SHOW_CONFIRMATION_ON_FIRST_TALENT_CHANGE"] = false;
                if not GQ_OPTIONS[c.OPT_ACTIONBARS_SHOW_CONFIRMATION_ON_FIRST_TALENT_CHANGE] then
                    c:ShowAcceptGqActionSlotManagementDialog(func, function()
                        GQ_OPTIONS[c.OPT_SAVECHANGES_ACTIONSLOTS] = c.OPTVALUE_DISABLE;
                        c:InitOptions();
                        changingTalents = false;
                    end);
                    GQ_OPTIONS[c.OPT_ACTIONBARS_SHOW_CONFIRMATION_ON_FIRST_TALENT_CHANGE] = true;
                else
                    func();
                end
            end
        elseif event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" then
            c:HookBlizzardFrameScripts();
            c:HookCharacterStatsFrameScripts();
            c:SetFramePositions();
        elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
            local currentPartyState, currentRaidState = IsInGroup(), IsInRaid();
            if lastPartyState ~= currentPartyState then
                if currentPartyState then
                    c:HandleEvent(c.EVENT_PARTY_JOIN);
                else
                    c:HandleEvent(c.EVENT_PARTY_LEAVE);
                end
                lastPartyState = currentPartyState;
            end

            if lastRaidState ~= currentRaidState then
                if currentRaidState then
                    c:HandleEvent(c.EVENT_RAID_JOIN);
                else
                    c:HandleEvent(c.EVENT_RAID_LEAVE);
                end
                lastRaidState = currentRaidState;
            end
        elseif event == "SPELL_UPDATE_USABLE" or event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP" then
            local currentSubmergedState = IsSwimming();
            if lastSubmergedState ~= currentSubmergedState then
                if currentSubmergedState then
                    c:HandleEvent(c.EVENT_SUBMERGE);
                else
                    c:HandleEvent(c.EVENT_EMERGE);
                end
                lastSubmergedState = currentSubmergedState;
            end
        elseif c:StartsWith(event, "ZONE_CHANGED") then
            if c.firstZoneEntered then
                c:NewZone();
            else
                c.firstZoneEntered = true;
            end
        end
    end
end);

function c:EquipmentChanged(slotId)
    if not c:IsSwitching() then
        if slotId and c:GetSlotInfo()[slotId] and not c:IsSwitching() and not bankAction then
            local currentSetName = c:LoadCurrentSetName();
            if currentSetName then
                if c:SaveConditionsMet() and (not c:LoadPartialOption() or c:LoadSlotState(slotId)) and
                    (slotId == INVSLOT_AMMO or not c:IsSetItemOnSlot(slotId, c:LoadSlot(slotId, currentSetName))) then
                    c:SaveSlot(slotId, currentSetName);
                elseif GQ_OPTIONS[c.OPT_IGNOREMANUALITEMS] then
                    c:AddIgnoredSlot(slotId);
                end

                c:SetSlotInfo(slotId);
            end
        end

        if slotId == INVSLOT_AMMO or not c:IsSetItemOnSlot(slotId, c:LoadSlot(slotId, c.KEYWORD_PREVIOUSEQUIPMENT)) then
            c:SaveSlot(slotId, c.KEYWORD_PREVIOUSEQUIPMENT, false);
        end
    end
end

function c:HandleEvent(eventType, eventSubType)
    if eventType == c.EVENT_MOUNT then
        lastMountState = true;
    elseif eventType == c.EVENT_DISMOUNT then
        lastMountState = false;
    elseif eventType == c.EVENT_STEALTH then
        lastStealthState = true;
    elseif eventType == c.EVENT_UNSTEALTH then
        lastStealthState = false;
    end

    if c:IsEventsEnabled() then
        local filter = {
            [c.FIELD_TYPE] = eventType
        };
        if eventType == c.EVENT_ZONE_ENTER or eventType == c.EVENT_ZONE_LEAVE then
            filter[c.FIELD_SUBTYPE] = c:GetZoneInfo(eventSubType);
        elseif eventType == c.EVENT_SHAPESHIFT_IN or eventType == c.EVENT_SHAPESHIFT_OUT then
            -- druid shapes
            filter[c.FIELD_SUBTYPE] = {
                name = c:GetDruidForms()[eventSubType],
                spellId = eventSubType
            };
        elseif eventType == c.EVENT_AURA_CHANGED then
            -- paladin auras
            filter[c.FIELD_SUBTYPE] = {
                name = c:GetPaladinAuras()[eventSubType],
                spellId = eventSubType
            };
        elseif eventType == c.EVENT_STANCE_CHANGED then
            -- warrior stances
            filter[c.FIELD_SUBTYPE] = {
                name = c:GetWarriorStances()[eventSubType],
                spellId = eventSubType
            };
        elseif eventType == c.EVENT_PRESENCE_CHANGED then
            -- deathknight presences
            filter[c.FIELD_SUBTYPE] = {
                name = c:GetDeathKnightPresences()[eventSubType],
                spellId = eventSubType
            };
        elseif eventType == c.EVENT_TALENTS_CHANGED then
            -- talent changed (dual spec)
            filter[c.FIELD_SUBTYPE] = {
                name = c:GetTalentSpecializations()[eventSubType],
                spellId = eventSubType
            };
        end

        local setBindings = c:LoadEventBindings(filter);
        if setBindings then
            local currentPvPState = UnitIsPVP("player");
            for index, binding in pairs(setBindings) do
                if (binding[c.FIELD_ENABLED] == nil or binding[c.FIELD_ENABLED]) and
                    (binding[c.FIELD_PVE] and not currentPvPState) or (binding[c.FIELD_PVP] and currentPvPState) then
                    c:QueueSwitch({
                        [c.SWITCHARG_SETNAME] = binding[c.FIELD_NAME]
                    });
                    return true;
                end
            end
        end
    end
end

function c:Mounting()
    c:HandleEvent(c.EVENT_MOUNT);
end

function c:Dismounting()
    c:HandleEvent(c.EVENT_DISMOUNT);
end

function c:NewZone()
    local currentMapId = C_Map.GetBestMapForUnit("player");
    if currentMapId ~= lastMapId then
        if lastMapId then
            -- leave bg
            if c:IsZoneBattleground(lastMapId) then
                c:HandleEvent(c.EVENT_BG_LEAVE);
            end

            -- leave zone
            local lastParentMapId = c:GetZoneInfo(lastMapId)["parentMapId"];
            if lastParentMapId and lastParentMapId ~= 947 then
                -- leave parent zone
                c:HandleEvent(c.EVENT_ZONE_LEAVE, lastParentMapId);
            end
            c:HandleEvent(c.EVENT_ZONE_LEAVE, lastMapId);
        end
        lastMapId = currentMapId;

        if currentMapId then
            -- enter bg
            if c:IsZoneBattleground(currentMapId) then
                c:HandleEvent(c.EVENT_BG_ENTER);
            end

            -- enter zone
            local currentParentMapId = c:GetZoneInfo(currentMapId)["parentMapId"];
            if currentParentMapId and currentParentMapId ~= 947 then
                -- enter parent zone
                c:HandleEvent(c.EVENT_ZONE_ENTER, currentParentMapId);
            end
            c:HandleEvent(c.EVENT_ZONE_ENTER, currentMapId);
        end
    end
end

function c:GetCurrentDruidForm()
    local druidForms = c:GetDruidForms();
    for _, spellId in pairs(c:GetCurrentBuffs()) do
        if druidForms[spellId] then
            return spellId;
        end
    end
    return c.VALUE_NONE;
end

function c:GetCurrentPaladinAura()
    local paladinAuras = c:GetPaladinAuras();
    for _, spellId in pairs(c:GetCurrentBuffs()) do
        if paladinAuras[spellId] then
            return spellId;
        end
    end
    return c.VALUE_NONE;
end

function c:EnterCombat()
    inCombat = true;
    c:HandleEvent(c.EVENT_COMBAT_ENTER);
    c:LockUI();
end

function c:LeaveCombat()
    inCombat = false;
    lastGearAndBagsCache = nil;
    c:HandleEvent(c.EVENT_COMBAT_LEAVE);

    if getn(switchQueue) > 0 then
        c:RequeueFirst();
    elseif not c:IsSwitching() then
        c:UnlockUI();
    end
end

function c:IsInCombat()
    return InCombatLockdown() or inCombat;
end

function c:IsDead()
    return UnitIsDeadOrGhost("player");
end

function c:IsOnBattleground()
    local bgPosition = UnitInBattleground("player");
    if not bgPosition then
        return false;
    end
    return bgPosition;
end

function c:IsCastingSpell()
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, spellId = CastingInfo();
    return name;
end

function c:SpellCastStart(spellId)
    if not c:IsInCombat() and not c:IsDead() then
        lastGearAndBagsCache = c:CacheCurrentGearAndBags();
    end
end

function c:SpellCastSuccess(spellId)
    -- check for enchanted items
    if not c:IsInCombat() and not c:IsDead() then
        C_Timer.After(c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
            c:CheckForNewEnchantment();
        end);
    end

    -- check for paladin aura event
    if c:GetPaladinAuras()[spellId] then
        c:HandleEvent(c.EVENT_AURA_CHANGED, spellId);
    end

    -- check for warrior stance event
    if c:GetWarriorStances()[spellId] then
        c:HandleEvent(c.EVENT_STANCE_CHANGED, spellId);
    end

    -- check for deathknight presence event
    if c:GetDeathKnightPresences()[spellId] then
        c:HandleEvent(c.EVENT_PRESENCE_CHANGED, spellId);
    end

    c:SpellCastEnd();
end

function c:SpellAuraApplied()
    c:CheckDruidFormChanged(c.EVENT_SHAPESHIFT_IN);
    c:CheckPaladinAuraChanged(c.EVENT_AURA_CHANGED);
end

function c:SpellAuraRemoved(spellId)
    if c:GetPaladinAuras()[spellId] then
        -- workaround for "no paladin aura"
        c:HandleEvent(c.EVENT_AURA_CHANGED, c.VALUE_NONE);
    elseif c:GetDruidForms()[spellId] then
        -- druid shapeshift
        c:CheckDruidFormChanged(c.EVENT_SHAPESHIFT_OUT);
    end
end

function c:SpellCastEnd()
    if not c:IsInCombat() and not c:IsDead() then
        C_Timer.After(c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
            if not c:IsSwitching() and not c:IsInCombat() and not c:IsCastingSpell() then
                if getn(switchQueue) > 0 then
                    c:RequeueFirst();
                else -- if not c:IsSwitching() then
                    c:UnlockUI();
                end
            end
        end);
    end
end

function c:CheckDruidFormChanged(eventType)
    c:DebugPrint("CheckDruidFormChanged", eventType);

    if not druidShapeshiftPending then
        druidShapeshiftPending = true;

        C_Timer.After(c:GetHomeLatency(GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
            local currentFormSpellId = c:GetCurrentDruidForm();
            if currentFormSpellId ~= lastDruidForm then
                c:DebugPrint("lastform, currentform: ", lastDruidForm, currentFormSpellId);
                c:HandleEvent(c.EVENT_SHAPESHIFT_OUT, lastDruidForm);
                c:HandleEvent(c.EVENT_SHAPESHIFT_IN, currentFormSpellId);
                lastDruidForm = currentFormSpellId;
            end
            druidShapeshiftPending = false;
        end);
    end
end

function c:CheckPaladinAuraChanged(eventType)
    c:DebugPrint("CheckPaladinAuraChanged", eventType);

    if not paladinAuraPending then
        paladinAuraPending = true;

        C_Timer.After(c:GetHomeLatency(GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
            local currentAuraSpellId = c:GetCurrentPaladinAura();
            if currentAuraSpellId ~= lastPaladinAura then
                c:DebugPrint("lastaura, currentaura: ", lastPaladinAura, currentAuraSpellId);
                c:HandleEvent(c.EVENT_AURA_CHANGED, currentAuraSpellId);
                lastPaladinAura = currentAuraSpellId;
            end
            paladinAuraPending = false;
        end);
    end
end

function c:CheckForNewEnchantment()
    if not c:IsInCombat() and not c:IsDead() and lastGearAndBagsCache then
        local cacheType, bagId, slotId, oldItemString, newItemString = c:GetFirstChangedItem(lastGearAndBagsCache);
        c:DebugPrint("CheckForNewEnchantment", cacheType, bagId, slotId, oldItemString, newItemString);

        -- check for equal item names in case player moved items while another player casted the enchantment - just to be sure
        if oldItemString and newItemString then
            c:ReplaceItemStringInAllSets(oldItemString, newItemString, true);
        end
    end
end

function c:FinishSwitch(switchArgs)
    if getn(switchQueue) > 0 then
        local nextSet = tremove(switchQueue, 1);
        c:SwitchToSet(nextSet);
    else
        C_Timer.After(c:GetHomeLatency(500 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
            if notifyInventoryError or switchArgs[c.SWITCHARG_QUEUE_CAUSE] == QUEUE_CAUSE_INVENTORY then
                c:Println(c:GetText("Action could not be finished. Switch to set \"%s\" incomplete.",
                    switchArgs[c.SWITCHARG_SETNAME]));
                notifyInventoryError = false;
            elseif c:IsSetComplete(switchArgs[c.SWITCHARG_SETNAME]) and GQ_OPTIONS[c.OPT_NOTIFYQUEUES] then
                if switchArgs[c.SWITCHARG_QUEUE_CAUSE] == QUEUE_CAUSE_COMBAT then
                    c:Println(c:GetText("Combat ended. Switch to set \"%s\" complete.", switchArgs[c.SWITCHARG_SETNAME]));
                elseif switchArgs[c.SWITCHARG_QUEUE_CAUSE] == QUEUE_CAUSE_ACTION then
                    c:Println(c:GetText("Action finished. Switch to set \"%s\" complete.",
                        switchArgs[c.SWITCHARG_SETNAME]));
                end
            end

            c:ResetIgnoredSlots();
            c:LoadCloakAndHelmet(switchArgs[c.SWITCHARG_SETNAME]);
            c:UpdateBroker();
            c:UnlockUI();
            if c.paperDollFrame:IsVisible() then
                c:SetPaperDollLabelText();
                c:SetSlotInfo();
                c:ShowSlotStateBoxes();
                c:RefreshSetList(switchArgs[c.SWITCHARG_SETNAME]);

                -- if switchArgs[c.SWITCHARG_ONFINISHED] and strlen(switchArgs[c.SWITCHARG_ONFINISHED]) > 0 then
                --     RunMacroText(switchArgs[c.SWITCHARG_ONFINISHED]);
                -- end
            end

            CloseDropDownMenus();
            PlaySound(1264);

            c:SetSwitching();
        end);
    end
end

function c:QueueSwitch(switchArgs)
    -- for simple set name string call
    if (type(switchArgs) == "string") then
        switchArgs = {
            [c.SWITCHARG_SETNAME] = switchArgs
        };
    end
    c:DebugPrint("Switch request for: " .. switchArgs[c.SWITCHARG_SETNAME]);

    -- complex call
    if switchArgs then
        switchArgs[c.SWITCHARG_ID] = switchArgs[c.SWITCHARG_ID] or GetNextSwitchId();
        if not c:IsSwitching() and not c:IsCastingSpell() and not c:IsDead() and
            (c:AffectsOnlyWeapons(switchArgs[c.SWITCHARG_SETNAME]) or not c:IsInCombat()) then
            -- switch immediately
            c:SwitchToSet(switchArgs);
            c:DebugPrint("Switch request applied immediately.");
            return;
        end

        if not switchArgs[c.SWITCHARG_QUEUE_CAUSE] then
            if c:IsInCombat() then
                switchArgs[c.SWITCHARG_QUEUE_CAUSE] = QUEUE_CAUSE_COMBAT;
            elseif c:IsCastingSpell() then
                switchArgs[c.SWITCHARG_QUEUE_CAUSE] = QUEUE_CAUSE_ACTION;
            end
        end

        -- queue switch
        if switchArgs[c.SWITCHARG_FIRST] then
            if not switchQueue[1] or switchQueue[1][c.SWITCHARG_SETNAME] ~= switchArgs[c.SWITCHARG_SETNAME] then
                -- as first (priority) switch
                local tmp = c:Deepcopy(switchQueue);
                switchQueue = {switchArgs};
                for _, set in ipairs(tmp) do
                    tinsert(switchQueue, set);
                end
                c:DebugPrint("Switch request queued first.");
            else
                c:DebugPrint("Switch request already queued first. Nothing to do.");
            end
        elseif not c:IsSetLastQueued(switchArgs[c.SWITCHARG_SETNAME]) then
            -- normal queue
            tinsert(switchQueue, switchArgs);
            c:DebugPrint("Switch request queued.");
        else
            -- dont queue if already queued last
            c:DebugPrint("Switch request not queued.");
            return;
        end

        if switchArgs[c.SWITCHARG_NOTIFY] == nil or switchArgs[c.SWITCHARG_NOTIFY] then
            if switchArgs[c.SWITCHARG_SETNAME] == c.KEYWORD_PREVIOUS then
                switchArgs[c.SWITCHARG_SETNAME] = c:LoadPreviousSetName();
            end

            if GQ_OPTIONS[c.OPT_NOTIFYQUEUES] then
                c:Println(c:GetText("Switch to \"%s\" queued.", switchArgs[c.SWITCHARG_SETNAME]));
            end
        end
    end
end

function c:RequeueFirst()
    -- when combat ends etc.
    -- essentially equals "start working on queue again"
    local nextSet = c:Dequeue(switchQueue);
    nextSet[c.SWITCHARG_FIRST] = true;
    nextSet[c.SWITCHARG_NOTIFY] = false;
    c:QueueSwitch(nextSet);
end

function c:IsSetQueued(setName)
    if setName then
        for _, switchArgs in ipairs(switchQueue) do
            if switchArgs[c.SWITCHARG_SETNAME] == setName then
                return true;
            end
        end
    end
end

function c:IsSetLastQueued(setName)
    if setName then
        local queuedSets = table.getn(switchQueue);
        if queuedSets > 0 then
            local lastQueuedSet = switchQueue[queuedSets];
            if lastQueuedSet and lastQueuedSet[c.SWITCHARG_SETNAME] == setName then
                return true;
            end
        end
    end
end

function c:SwitchToSet(switchArgs)
    if switchArgs then
        local setName = switchArgs[c.SWITCHARG_SETNAME];
        if setName == c.KEYWORD_PREVIOUS then
            setName = c:LoadPreviousSetName();
        end

        setName = c:TableContains(c:LoadSetNames(true), setName, true); -- case insensitive
        if setName then
            local desiredSet = c:LoadSet(setName);
            local uniqueGems = c:GetAllUniqueGems(setName);
            -- c:SaveSet(c.KEYWORD_PREVIOUSEQUIPMENT, false); -- unneccessary?

            local freeSpace, neededSpace, bagSpaceCache = c:CheckNeccessaryBagSpace(setName);
            if neededSpace > freeSpace then
                c:Println(c:GetText("Not enough bag space. Current space: %s, needed: %s", freeSpace, neededSpace));
                c:RefreshSetList();
            else
                c:SetSwitching(setName);
                CloseMerchant();
                c:LockUI(setName);
                PlaySound(1264);

                local slotSwitchOrder = c:GetSlotSwitchOrder(setName);
                local interrupted = false;

                while (getn(slotSwitchOrder) > 0) do
                    local slotId = c:Dequeue(slotSwitchOrder, 0);
                    local desiredItemString = desiredSet[slotId];

                    if not interrupted and not c:IsSetItemOnSlot(slotId, desiredItemString) and
                        (not c:LoadPartialOption(setName) or c:LoadSlotState(slotId, setName)) and
                        (not GQ_OPTIONS[c.OPT_IGNOREMANUALITEMS] or not c:IsIgnoredItem(slotId)) then

                        if slotId ~= INVSLOT_MAINHAND and slotId ~= INVSLOT_OFFHAND and slotId ~= INVSLOT_RANGED and
                            c:IsInCombat() then

                            -- breaks loop if combat starts
                            if GQ_OPTIONS[c.OPT_NOTIFYQUEUES] then
                                c:Println(c:GetText(
                                    "Switching interrupted by combat. It will be re-attempted once combat is over."));
                            end
                            c:QueueSwitch({
                                [c.SWITCHARG_SETNAME] = setName,
                                [c.SWITCHARG_FIRST] = true,
                                [c.SWITCHARG_QUEUE_CAUSE] = QUEUE_CAUSE_COMBAT
                            });
                            interrupted = true;
                            return;
                        end

                        if c:IsCastingSpell() then
                            -- breaks loop if spell cast starts
                            if GQ_OPTIONS[c.OPT_NOTIFYQUEUES] then
                                c:Println(c:GetText(
                                    "Switching interrupted by action. It will be re-attempted once the action is finished."));
                            end
                            c:QueueSwitch({
                                [c.SWITCHARG_SETNAME] = setName,
                                [c.SWITCHARG_FIRST] = true,
                                [c.SWITCHARG_QUEUE_CAUSE] = QUEUE_CAUSE_ACTION
                            });
                            interrupted = true;
                            return;
                        end

                        if c:IsEmpty(desiredItemString) then
                            if not c:UnequipItem(slotId, bagSpaceCache, c:GetItemString(slotId)) then
                                interrupted = true;
                                notifyInventoryError = true;
                            end
                        else
                            -- prevents mh/oh swapping issues (no longer needed??)
                            -- if (slotId == INVSLOT_MAINHAND and c:GetItemString(INVSLOT_OFFHAND) == desiredItemString) then
                            --     if not c:UnequipItem(slotId, bagSpaceCache, c:GetItemString(INVSLOT_MAINHAND)) then
                            --         return;
                            --     end
                            -- end

                            -- equip item
                            local itemLink = c:GetItemLink(desiredItemString);
                            if itemLink then
                                if not c:FindItemInBags(desiredItemString) and c:IsAtBank() then
                                    -- item not in bag -> check in bank
                                    if not c:GetItemFromBank(c:GetItemString(itemLink), bagSpaceCache) then
                                        interrupted = true;
                                        notifyInventoryError = true;
                                    end

                                    C_Timer.After(c:GetHomeLatency(100 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000,
                                        function()
                                            c:TryEquipItem(slotId, itemLink, bagSpaceCache, uniqueGems, slotSwitchOrder,
                                                desiredSet[INVSLOT_MAINHAND], desiredSet[INVSLOT_OFFHAND]);
                                        end);
                                elseif not c:TryEquipItem(slotId, itemLink, bagSpaceCache, uniqueGems, slotSwitchOrder,
                                    desiredSet[INVSLOT_MAINHAND], desiredSet[INVSLOT_OFFHAND]) then
                                    interrupted = true;
                                    notifyInventoryError = true;
                                end
                            end
                        end

                        if GQ_OPTIONS[c.OPT_HIGHLIGHTCHANGES] then
                            c:HighlightInventorySlot(slotId);
                        end
                    end
                end

                if not switchArgs[c.SWITCHARG_QUEUE_CAUSE] then
                    if setName ~= c.KEYWORD_PREVIOUSEQUIPMENT then
                        if c:LoadActionSlotsConditionsMet(setName) then
                            c:LoadActionConfiguration(setName);
                        end
                        c:SaveCurrentSetName(setName);
                    else
                        if c:LoadActionSlotsConditionsMet(c:LoadPreviousSetName()) then
                            c:LoadActionConfiguration(c:LoadPreviousSetName());
                        end
                        c:SaveCurrentSetName(c:LoadPreviousSetName());
                    end
                end

                -- c:SetKeyBindings(c:LoadKeyBindings(setName));
                c:FinishSwitch(switchArgs);
            end
        end
    end
end

function c:TryEquipItem(slotId, itemLink, bagSpaceCache, targetSetUniqueGems, slotSwitchOrder, mainHandItemLink,
    offHandItemLink)
    if not targetSetUniqueGems[slotId] then
        return c:EquipItem(slotId, itemLink, bagSpaceCache, mainHandItemLink, offHandItemLink);
    else
        -- potential unique gem conflict -> unequip conflicting items first
        for _, gemItemString in ipairs(targetSetUniqueGems[slotId]) do
            local itemSlotId = c:IsGemSocketed(gemItemString);
            if itemSlotId and c:TableContains(slotSwitchOrder, itemSlotId) then
                if not c:UnequipItem(itemSlotId, bagSpaceCache, c:GetItemString(itemLink)) then
                    return false;
                end
            end
        end
        return c:EquipItem(slotId, itemLink, bagSpaceCache, mainHandItemLink, offHandItemLink);
    end
end

function c:EquipItem(slotId, itemLink, bagSpaceCache, mainHandItemLink, offHandItemLink)
    local itemString = c:GetItemString(itemLink);
    local list = c:FindItemInBags(itemString);

    if list then
        local bagId, bagSlotId = list[1].bagId, list[1].slotId;
        c:SaveLastBagLocation(itemString, bagId, bagSlotId);
        if c:IsEmpty(slotId) then
            bagSpaceCache[bagId] = bagSpaceCache[bagId] + 1;
        end
    end

    if slotId == INVSLOT_AMMO then
        -- ammo workaround
        EquipItemByName(itemLink);
        return true;
    elseif c:Equals(mainHandItemLink, offHandItemLink) and (slotId == INVSLOT_MAINHAND or slotId == INVSLOT_OFFHAND) then
        -- identical weapons workaround
        local equippedList = c:IsItemEquipped(itemString);
        if not equippedList then
            PickupContainerItem(list[1].bagId, list[1].slotId);
            if CursorHasItem() then
                EquipCursorItem(slotId);
                ClearCursor();
            end
            if getn(list) > 1 then
                PickupContainerItem(list[2].bagId, list[2].slotId);
                if CursorHasItem() then
                    EquipCursorItem(INVSLOT_OFFHAND);
                    ClearCursor();
                end
            end
        elseif getn(equippedList) < 2 then
            PickupContainerItem(list[1].bagId, list[1].slotId);
            if CursorHasItem() then
                EquipCursorItem(slotId);
                ClearCursor();
            end
        end
        return true;
    end

    -- default
    EquipItemByName(itemLink, slotId);
    return true;
end

function c:UnequipItem(slotId, bagSpaceCache, itemString)
    ClearCursor();
    PickupInventoryItem(slotId);
    if not c:PutInBag(bagSpaceCache, itemString) then
        c:Println(c:GetText("Not enough bag space. Switching aborted."));
        return false;
    end
    ClearCursor();
    return true;
end

function c:LoadActionConfiguration(setName)
    local actionSlots = c:LoadActionSlots(setName);
    for slotId, entry in pairs(actionSlots) do
        if slotId > 0 and slotId < 121 and entry and not c:IsSameAction(slotId, entry) then
            if c:IsInCombat() then
                -- breaks loop if combat starts
                if GQ_OPTIONS[c.OPT_NOTIFYQUEUES] then
                    c:Println(c:GetText("Switching interrupted by combat. It will be re-attempted once combat is over."));
                end
                c:QueueSwitch({
                    [c.SWITCHARG_SETNAME] = setName,
                    [c.SWITCHARG_FIRST] = true,
                    [c.SWITCHARG_QUEUE_CAUSE] = QUEUE_CAUSE_COMBAT
                });
                return;
            end

            ClearCursor();
            PickupAction(slotId);
            ClearCursor();

            if not c:IsEmpty(entry) then
                if entry[c.FIELD_TYPE] == "spell" or entry[c.FIELD_TYPE] == "companion" then
                    PickupSpell(entry[c.FIELD_ID]);
                elseif entry[c.FIELD_TYPE] == "item" then
                    PickupItem(entry[c.FIELD_ID]);
                elseif entry[c.FIELD_TYPE] == "macro" then
                    PickupMacro(GetMacroIndexByName(entry[c.FIELD_ID]));
                end

                PlaceAction(slotId);
                ClearCursor();
            end

            c:HighlightActionSlot(slotId);
        end
    end

    return true;
end

function c:PutInBag(bagSpaceCache, itemString)
    if itemString then
        local lastBagId, lastSlotId = c:LoadLastBagLocation(itemString);
        if lastBagId and bagSpaceCache[lastBagId] and bagSpaceCache[lastBagId] > 0 and
            c:PutInBackpack(bagSpaceCache, lastBagId, lastSlotId) then
            return true;
        end
    end

    local bagIdsSorted = {};
    for bagId, freeSlots in pairs(bagSpaceCache) do
        tinsert(bagIdsSorted, bagId);
    end
    table.sort(bagIdsSorted);

    for _, bagId in ipairs(bagIdsSorted) do
        if bagSpaceCache[bagId] > 0 then
            return c:PutInBackpack(bagSpaceCache, bagId);
        end
    end
end

function c:PutInBackpack(bagSpaceCache, bagId, slotId)
    if CursorHasItem() then
        if bagId == 0 then
            PutItemInBackpack();
        else
            PutItemInBag(ContainerIDToInventoryID(bagId));
        end

        if not CursorHasItem() then
            bagSpaceCache[bagId] = bagSpaceCache[bagId] - 1;
            return true;
        end
    end
end

function c:PutInBank(bankSpaceCache, itemString)
    if itemString then
        local lastBagId, lastSlotId = c:LoadLastBankLocation(itemString);
        if lastBagId then
            if not lastSlotId and bankSpaceCache[lastBagId] > 0 then
                PutItemInBag(lastBagId);
                bankSpaceCache[lastBagId] = bankSpaceCache[lastBagId] - 1;
                return;
            else
                local invId = ContainerIDToInventoryID(lastBagId);
                if bankSpaceCache[invId] > 0 then
                    PutItemInBag(invId);
                    bankSpaceCache[invId] = bankSpaceCache[invId] - 1;
                    return;
                end
            end
        end
    end

    local invIdsSorted = {};
    for invId, freeSlots in pairs(bankSpaceCache) do
        tinsert(invIdsSorted, invId);
    end
    table.sort(invIdsSorted);

    for _, invId in ipairs(invIdsSorted) do
        if bankSpaceCache[invId] > 0 then
            PutItemInBag(invId);
            bankSpaceCache[invId] = bankSpaceCache[invId] - 1;
            return;
        end
    end
end

function c:PushSetToBank(setName)
    if setName and not bankAction then
        local error = false;
        local freeSpace, items, bankSpaceCache = c:CheckNeccessaryPushSpace(setName);
        if freeSpace >= c:GetTableSize(items) then
            CloseMerchant();
            bankAction = "push";
            for slotId, itemString in pairs(items) do
                if not c:IsEmpty(itemString) and (not c:LoadPartialOption(setName) or c:LoadSlotState(slotId, setName)) and
                    not c:IsSetCurrentSetItem(itemString) then

                    ClearCursor();
                    if c:IsSetItemOnSlot(slotId, itemString) then
                        PickupInventoryItem(slotId);
                    else
                        local list = c:FindItemInBags(itemString);
                        if list then
                            PickupContainerItem(list[1].bagId, list[1].slotId);
                        end
                    end

                    if CursorHasItem() then
                        c:PutInBank(bankSpaceCache, itemString);
                    else
                        c:Println(c:GetText("%s could not be found or pushed to bank.", c:GetItemLink(itemString)));
                        error = true;
                    end
                end
            end

            C_Timer.After(c:GetLatency(1000 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                c:SetSlotInfo();
                bankAction = nil;
            end);

            if error then
                c:Println(c:GetText("Set \"%s\" was incompletely pushed to bank.", setName));
            end

            ClearCursor();
            return not error;
        else
            c:Println(c:GetText("Not enough bank space to push \"%s\" to bank. Free: %s, needed: %s.", setName,
                freeSpace, c:GetTableSize(items)));
        end
    end
end

function c:PullSetFromBank(setName)
    if setName and not bankAction then
        local error = false;
        local freeSpace, items, bagSpaceCache = c:CheckNeccessaryPullSpace(setName);
        if freeSpace >= c:GetTableSize(items) then
            CloseMerchant();
            bankAction = "pull";
            for slotId, itemString in pairs(items) do
                if not c:IsEmpty(itemString) and (not c:LoadPartialOption(setName) or c:LoadSlotState(slotId, setName)) then

                    if not c:GetItemFromBank(itemString, bagSpaceCache) then
                        c:Println(c:GetText("%s could not be found or pulled from bank.", c:GetItemLink(itemString)));
                        error = true;
                    end
                end
            end

            C_Timer.After(c:GetLatency(1000 + GQ_OPTIONS[c.OPT_SWITCHDELAY]) / 1000, function()
                c:SetSlotInfo();
                bankAction = nil;
            end);

            if error then
                c:Println(c:GetText("Set \"%s\" was incompletely pulled from bank.", setName));
            end

            ClearCursor();
            return not error;
        else
            c:Println(c:GetText("Not enough bag space to pull \"%s\" from bank. Free: %s, needed: %s.", setName,
                freeSpace, c:GetTableSize(items)));
        end
    end
end

function c:GetItemFromBank(itemString, bagSpaceCache)
    ClearCursor();

    local containerId, containerSlotId = c:FindItemInBank(itemString);
    if containerId then
        c:SaveLastBankLocation(itemString, containerId, containerSlotId);
        if not containerSlotId then
            PickupContainerItem(BANK_CONTAINER, containerId);
        else
            PickupContainerItem(containerId, containerSlotId);
        end
    end

    if CursorHasItem() then
        return c:PutInBag(bagSpaceCache, itemString);
    end
end

function c:GetCurrentKeyBindings()
    local bindings = {};
    -- LoadBindings(GetCurrentBindingSet());
    for i = 1, GetNumBindings() do
        local b = {GetBinding(i)};

        local command = b[1];
        bindings[command] = bindings[command] or {};

        local size = c:GetTableSize(b);
        if size > 1 then
            for i = 2, size do
                tinsert(bindings[command], b[i]);
            end
        end
    end
    return bindings;
end

function c:SetKeyBindings(bindings)
    if bindings then
        for command, keys in pairs(bindings) do
            keys = keys or {};

            for _, key in ipairs(keys) do
                if SetBinding(key, command) == 1 then
                    c:Println("changed " .. key .. " " .. command);
                end
            end
            -- SaveBindings(GetCurrentBindingSet());
        end
    end
end
