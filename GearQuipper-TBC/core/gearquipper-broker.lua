-- scope stuff
gearquipper = gearquipper or {};
local c = gearquipper;
local LDB;

local eventListeners = {};

GQ_EVENT_ACTIONSLOT_SAVED = "GQ_EVENT_ACTIONSLOT_SAVED";
GQ_EVENT_ACTIONSLOT_SET_SAVED = "GQ_EVENT_ACTIONSLOT_SET_SAVED";
GQ_EVENT_EVENT_BINDING_REMOVED = "GQ_EVENT_EVENT_BINDING_REMOVED";
GQ_EVENT_EVENT_BINDING_SAVED = "GQ_EVENT_EVENT_BINDING_SAVED";
GQ_EVENT_SET_REMOVED = "GQ_EVENT_SET_REMOVED";
GQ_EVENT_SET_SAVED = "GQ_EVENT_SET_SAVED";
GQ_EVENT_SLOT_SAVED = "GQ_EVENT_SLOT_SAVED";
GQ_EVENT_SLOT_STATE_SAVED = "GQ_EVENT_SLOT_STATE_SAVED";

function c:InitBroker()
    if LibStub and not LDB then
        LDB = LibStub('LibDataBroker-1.1'):NewDataObject('GearQuipper', {
            label = 'GearQuipper',
            type = 'data source',
            icon = "Interface\\Icons\\Ability_warrior_defensivestance",
            OnTooltipShow = function(self)
                if GQ_OPTIONS[c.OPT_SHOWBROKERTOOLTIP] then
                    self:AddLine("|cFFFFFFFFGearQuipper|r");
                    self:AddLine(" ");

                    local currentSet = c:LoadCurrentSetName() or UNKNOWN;
                    self:AddLine(c:GetText("%s: %s", c:GetText("Current set"),
                        c:FormatTextWithColor(currentSet, "FFFFFF")));

                    self:AddLine(" ");
                    if c:IsEventsEnabled() then
                        local eventBindings = c:LoadEventBindings();
                        if eventBindings and c:GetTableSize(eventBindings) > 0 then
                            self:AddLine(c:GetText("Active event bindings:"));
                            for index, binding in pairs(eventBindings) do
                                local type = binding[c.FIELD_TYPE];
                                local environment;
                                if binding[c.FIELD_PVE] then
                                    environment = "( " .. c:FormatTextWithColor("PvE", "00FF00");
                                end
                                if binding[c.FIELD_PVP] then
                                    if environment then
                                        environment = environment .. " / " .. c:FormatTextWithColor("PvP", "FF0000") ..
                                                          " )";
                                    else
                                        environment = "( " .. c:FormatTextWithColor("PvP", "FF0000") .. " )";
                                    end
                                elseif environment then
                                    environment = environment .. " )";
                                end
                                local setName = binding[c.FIELD_NAME];
                                if setName == c.KEYWORD_PREVIOUS then
                                    setName = c:GetText("[Previous equipment]");
                                end
                                self:AddLine(c:GetText("%s will switch to %s %s", c:FormatTextWithColor(
                                    c:GetEvents()[binding[c.FIELD_TYPE]], "FFFFFF"),
                                    c:FormatTextWithColor(setName, "FFFFFF"), environment));
                            end
                        else
                            self:AddLine(c:GetText("Active event bindings:") .. " " ..
                                             c:FormatTextWithColor(NONE_KEY, "FFFFFF"));
                        end

                    else
                        self:AddLine(c:GetText("Event bindings disabled."));
                    end
                end
            end,
            OnClick = function(self, button)
                if button == "RightButton" then
                    CloseDropDownMenus();
                    ToggleDropDownMenu(1, nil, LDB.dropDownMenu, _G[self:GetName()], -4, -4);
                end
            end,
            OnDoubleClick = function(self, button)
                if button == "LeftButton" then
                    c:QueueSwitch({
                        [c.SWITCHARG_SETNAME] = c.KEYWORD_PREVIOUS
                    });
                end
            end
        });

        if not LDB then
            c:Println(c:GetText("Error while initializing data broker!"));
            return;
        end

        LDB.dropDownMenu = CreateFrame("Frame", "GearQuipper_Broker_DropDownMenu", UIParent,
            BackdropTemplateMixin and "BackdropTemplate");
        -- LDB.dropDownMenu:SetBackdropColor(0, 0, 0);
        LDB.dropDownMenu:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4
            }
        });
        UIDropDownMenu_Initialize(LDB.dropDownMenu, function(frame, level, menuList)
            local currentSet = c:LoadCurrentSetName();
            local info = UIDropDownMenu_CreateInfo();

            if c:IsSwitching() then
                info.text = c:GetText("- Currently Switching -");
                info.isTitle = true;
                info.notCheckable = true;
                UIDropDownMenu_AddButton(info);
            else
                info.text = c:GetText("Switch to set:");
                info.isTitle = true;
                info.notCheckable = true;
                UIDropDownMenu_AddButton(info);
                info.isTitle = false;
                info.notClickable = false;

                for index, setName in ipairs(c:LoadSetNames(false)) do
                    local info = UIDropDownMenu_CreateInfo();
                    info.checked = (setName == currentSet);
                    info.func = function()
                        if setName ~= currentSet then
                            c:SwitchToSet({
                                [c.SWITCHARG_SETNAME] = setName
                            });
                        end
                    end
                    info.text = setName;
                    UIDropDownMenu_AddButton(info);
                end
            end
            LDB.dropDownMenu:SetAllPoints();
        end);
        LDB.dropDownMenu:Hide();

        c:UpdateBroker();
        c:Println(c:GetText("Data broker initialized."));
    end
end

function c:UpdateBroker()
    if LDB then
        local currentSet = c:LoadCurrentSetName() or UNKNOWN;
        LDB.text = currentSet;
    end
end

--- Returns a list of valid GearQuipper events.
function c:GetEventListenerEvents()
    return {GQ_EVENT_ACTIONSLOT_SAVED, GQ_EVENT_ACTIONSLOT_SET_SAVED, GQ_EVENT_EVENT_BINDING_REMOVED,
            GQ_EVENT_EVENT_BINDING_SAVED, GQ_EVENT_SET_REMOVED, GQ_EVENT_SET_SAVED, GQ_EVENT_SLOT_SAVED,
            GQ_EVENT_SLOT_STATE_SAVED};
end

--- Registers event listener for given event. See gearquipper:GetEventListenerEvents() for list of valid events.
---@param event string event
---@param func function function which will be called upon event
---@param o any (optional) custom existing object which will get :OnEvent(event, ...) and :GetGqEventListenerId() methods attached
---@return any listener object with :OnEvent(event, ...) and :GetGqEventListenerId() methods
function c:RegisterEventListener(event, func, o)
    if event and func then
        local listener = o or {};

        listener.gqEventListenerId = c:uuid();
        listener.GetGqEventListenerId = function(self)
            return self.gqEventListenerId;
        end;

        listener.gqEventListenerEvents = listener.gqEventListenerEvents or {};
        listener.gqEventListenerEvents[event] = func;
        listener.OnEvent = function(self, event, ...)
            self.gqEventListenerEvents[event](self, ...);
        end;

        eventListeners[event] = eventListeners[event] or {};
        eventListeners[event][listener:GetGqEventListenerId()] = listener;
        return listener;
    end
end

--- Removes registered event listener.
---@param listener any listener object with :OnEvent(event, ...) and :GetGqEventListenerId() methods
---@param event string (optional) event. if omitted, the listener will be removed from all events
function c:RemoveEventListener(listener, event)
    if listener and listener:GetGqEventListenerId() then
        if event then
            eventListeners[event][listener:GetGqEventListenerId()] = nil;
            listener.gqEventListenerEvents[event] = nil;
        else
            for event, _ in pairs(listener.gqEventListenerEvents) do
                eventListeners[event][listener:GetGqEventListenerId()] = nil;
            end
            listener.gqEventListenerEvents = {};
        end
        eventListeners[listener:GetGqEventListenerId()] = nil;
    end
    return listener;
end

--- Notifies registered event listeners about the given event.
---@param event string
function c:NotifyEventListeners(event, ...)
    if event and eventListeners[event] then
        for _, listener in pairs(eventListeners[event]) do
            listener:OnEvent(event, ...);
        end
    end
end
