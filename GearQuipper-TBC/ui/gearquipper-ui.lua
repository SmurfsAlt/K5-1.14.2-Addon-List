-- scope stuff
gearquipper = gearquipper or {};
local c = gearquipper;

local gqTooltips = {};
local slotStateBoxes;
local secureActionButtons = {};

local blizzardFrameNames = {"CraftFrame", "TradeSkillFrame", "BankFrame", "SpellBookFrame", "PlayerTalentFrame",
                            "MailFrame"};

local ECS_FrameName = "ECS_StatsFrame";
local DCS_FrameName = "DejaClassicStatsFrame";
local ElvUI_WACS_FrameName = "WrathArmory_StatsPane";
local csFrameNames = {ECS_FrameName, DCS_FrameName, ElvUI_WACS_FrameName};

c.MACROACTION_NEW = "MACROACTION_NEW";
c.MACROACTION_EDIT = "MACROACTION_EDIT";
c.MACROACTION_DELETE = "MACROACTION_DELETE";

----- general ui stuff -----

function c:InitUI(paperDollFrame)
    if paperDollFrame then
        c.paperDollFrame = paperDollFrame;
        c.paperDollFrame.paperDollButton = c.paperDollFrame.paperDollButton or c:CreatePaperDollButton();
        c.paperDollFrame.paperDollLabel = c.paperDollFrame.paperDollLabel or c:CreatePaperDollLabel();

        c.paperDollFrame:HookScript("OnShow", function()
            if GQ_OPTIONS[c.OPT_MENUOPEN] then
                c:ToggleUI(true);
            end
            c:SetSlotInfo();
            c:SetPaperDollLabelText();
            c:SetGqUiFramePosition();

            if c:IsSwitching() or c:IsInCombat() or c:IsDead() then
                c:LockUI();
            else
                c:UnlockUI();
            end

            if c:IsWotlkClassic() then
                _G["GearManagerToggleButton"]:ClearAllPoints();
                if ElvUI then
                    _G["GearManagerToggleButton"]:SetPoint("TOPLEFT", c.paperDollFrame, "TOPLEFT", 18, -33);
                else
                    _G["GearManagerToggleButton"]:SetPoint("TOPLEFT", c.paperDollFrame, "TOPLEFT", 75, -39);
                end
            end
        end);
        c.paperDollFrame:HookScript("OnHide", function()
            GQ_OPTIONS[c.OPT_MENUOPEN] = GqUiFrame.isOpen;
            c:CloseQuickBars();
        end);
        InterfaceOptionsFrameOkay:HookScript("OnClick", function(self)
            c:SaveCloakAndHelmet();
        end);

        GameMenuButtonMacros:HookScript("OnClick", function()
            if not MacroFrame.gearQuipperHooked then
                MacroNewButton:HookScript("OnClick", function()
                    c.macroAction = {
                        [c.FIELD_NAME] = c.MACROACTION_NEW,
                        [c.FIELD_TYPE] = MacroFrame.selectedTab
                    };
                end);
                MacroEditButton:HookScript("OnClick", function()
                    c.macroAction = {
                        [c.FIELD_NAME] = c.MACROACTION_EDIT,
                        [c.FIELD_TYPE] = MacroFrame.selectedTab,
                        [c.FIELD_ID] = MacroFrame.selectedMacro
                    };
                end);
                MacroDeleteButton:HookScript("OnClick", function()
                    c.macroAction = {
                        [c.FIELD_NAME] = c.MACROACTION_DELETE,
                        [c.FIELD_TYPE] = MacroFrame.selectedTab,
                        [c.FIELD_ID] = MacroFrame.selectedMacro
                    };
                end);
                MacroFrame.gearQuipperHooked = true;
            end
        end);

        local function ShowExtendedItemTooltip(self)
            -- extend default tooltip
            if GQ_OPTIONS[c.OPT_SHOWITEMTOOLTIP] and self and self:GetOwner() then
                local ownerName = self:GetOwner():GetName();
                if ownerName then
                    local slotId = c:GetSlotId(ownerName:gsub("Character", ""));
                    if slotId then
                        -- inventory slot item tooltip
                        local setName = c:LoadCurrentSetName();
                        local itemString = c:LoadSlot(slotId, setName);
                        if setName and not (c:LoadPartialOption(setName) or c:LoadSlotState(slotId, setName)) and
                            not c:IsSetItemOnSlot(slotId, itemString) then
                            self:AddLine(" ");
                            self:AddDoubleLine(c:FormatTextWithColor(c:GetText("Expected Item:"), "ff0000"),
                                c:GetItemLink(itemString));
                        end
                    else
                        -- bag/bank slot item tooltip
                        local name, itemLink = self:GetItem();
                        local itemString = c:GetItemString(itemLink);
                        if itemString then
                            local sets, spacing = c:GetItemSets(itemString);
                            if sets and getn(sets) > 0 then
                                self:AddLine(" ");
                                self:AddDoubleLine(c:GetText("GearQuipper set(s):"), table.concat(sets, ", "));
                                spacing = true;
                            end
                            if GQ_OPTIONS[c.OPT_SET_ITEM_COMPARISON_SHOW_HINT] then
                                if getn(c:GetItemSlots(itemString)) > 0 then
                                    if not spacing then
                                        self:AddLine(" ");
                                    end
                                    self:AddLine(c:GetText("Press L-Alt to cycle through sets."));
                                end
                            end
                        end
                    end
                end
            end

            -- load custom tooltips
            if GQ_OPTIONS[c.OPT_SET_ITEM_COMPARISON] then
                local itemName, itemLink = self:GetItem();
                if itemLink then
                    local comparisonSetName = c:LoadComparisonSetName();
                    if comparisonSetName then
                        c:ShowSetItemComparison(itemLink, comparisonSetName);
                    else
                        c:HideGqTooltips();
                    end
                end
            end
        end

        local function IsEmptyInventorySlotTooltip(...)
            for i = 1, select("#", ...) do
                local region = select(i, ...)
                if region and region:GetObjectType() == "FontString" then
                    local text = region:GetText() -- string or nil
                    if text then
                        return c:TableContains(c:GetAllInventoryTypes(), text);
                    end
                end
            end
        end

        GameTooltip:HookScript("OnShow", function(self)
            -- TODO: get slotId (beware: trinkets, rings) and pass it to the tooltip function
            self.gqEmptyInventorySlot = IsEmptyInventorySlotTooltip(self:GetRegions());
        end);

        GameTooltip:HookScript("OnTooltipSetItem", function(self)
            ShowExtendedItemTooltip(self);
        end);

        GameTooltip:HookScript("OnHide", function()
            c:HideGqTooltips();
        end);

        -- hook character slots for quickslots on empty slot
        for slotId, slotName in pairs(c:GetSlotInfo()) do
            local frame = _G["Character" .. slotName];
            if frame then
                frame:HookScript("OnClick", function(self, button)
                    if button == "LeftButton" then
                        if self.quickbar then
                            self.quickbar:Hide();
                            self.quickbar = nil;
                        elseif slotId == INVSLOT_AMMO or c:GetItemString(slotId) == c.VALUE_NONE then
                            c:CloseQuickBars();
                            self.quickbar = c:OpenQuickBar(slotId);
                        end
                    end
                end)
            end
        end

        c:HookBlizzardFrameScripts();
        c:HookCharacterStatsFrameScripts();
        c:InitUiFrame();

        c:CreateSecureActionButtons();

        C_Timer.After(2, function()
            c:ToggleWatermark(GQ_OPTIONS[c.OPT_SHOW_WATERMARK]);
        end);
    end
end

function c:ToggleWatermark(value)
    if not c.watermark then
        local cmb = _G["CharacterMicroButton"];
        if not cmb then
            return;
        end

        c.watermark = CreateFrame("CheckButton", "GQ_Watermark", cmb);
        c.watermark:SetPropagateKeyboardInput(true);
        c.watermark:SetPoint("CENTER", 2, -2);
        c.watermark:SetFrameStrata("MEDIUM");
        c.watermark:EnableMouse(false);
        c.watermark:SetSize(14, 10);
        c.watermark:SetAllPoints();

        c.watermark.fontString = c.watermark:CreateFontString("GQ_Watermark_FontString", "ARTWORK");
        c.watermark.fontString:SetFont("Fonts\\FRIZQT__.TTF", 7, "MONOCHROME")
        c.watermark.fontString:SetAllPoints();
        c.watermark.fontString:SetText("GQ");
    end

    if value == true or not value then
        c.watermark:Show();
    else
        c.watermark:Hide();
    end
end

function c:HookBlizzardFrameScripts()
    local newFrameHasBeenHooked;
    for _, frameName in ipairs(blizzardFrameNames) do
        local frame = _G[frameName];
        if frame and not c.isFrameHooked[frameName] then
            frame:HookScript("OnShow", function()
                c:SetFramePositions();
            end);
            frame:HookScript("OnHide", function()
                c:SetFramePositions();
            end);
            c.isFrameHooked[frameName] = true;
            newFrameHasBeenHooked = true;
        end
    end
    if newFrameHasBeenHooked then
        c:SetFramePositions();
    end
end

function c:SetFramePositions(norepeat)
    local xOffset = 0;

    -- mail
    local mailFrame = _G["MailFrame"];
    if mailFrame and mailFrame:IsVisible() then
        xOffset = xOffset + mailFrame:GetWidth();
    end

    -- spellbook
    local spellbookFrame = _G["SpellBookFrame"];
    if spellbookFrame and spellbookFrame:IsVisible() then
        xOffset = xOffset + spellbookFrame:GetWidth();
    end

    -- character
    local characterFrame = _G["CharacterFrame"];
    if characterFrame and characterFrame:IsVisible() then
        xOffset = xOffset + characterFrame:GetWidth() - 15;
    end

    -- GQ
    if GqUiFrame:IsVisible() then
        xOffset = xOffset + GqUiFrame:GetWidth() - 20;
    end

    -- extended character stats (addon)
    local ecsFrame = _G[c:GetCharacterStatsFrameNames()[1]];
    if ecsFrame and ecsFrame:IsVisible() then
        xOffset = xOffset + ecsFrame:GetWidth();
    end

    -- elvui wrath armory (addon)
    local elvUiWaFrame = _G[c:GetCharacterStatsFrameNames()[3]];
    if elvUiWaFrame and elvUiWaFrame:IsVisible() then
        xOffset = xOffset + elvUiWaFrame:GetWidth();
    end

    -- crafting
    local craftFrame, tradeSkillFrame = _G["CraftFrame"], _G["TradeSkillFrame"];
    if craftFrame and craftFrame:IsVisible() then
        craftFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, -104);
        xOffset = xOffset + craftFrame:GetWidth() - 20;
    elseif tradeSkillFrame and tradeSkillFrame:IsVisible() and tradeSkillFrame:GetLeft() > characterFrame:GetLeft() then
        tradeSkillFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, -104);
        xOffset = xOffset + tradeSkillFrame:GetWidth() - 20;
    end

    -- bank
    local bankFrame = _G["BankFrame"];
    if bankFrame and bankFrame:IsVisible() then
        bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, -104);
    end

    -- talents
    local talentFrame = _G["PlayerTalentFrame"];
    if talentFrame and talentFrame:IsVisible() then
        talentFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, -104);
    end

    -- tradeskillframe and craftingframe seem to do some async server requests which cause repositioning to fail at first try
    if not norepeat then
        C_Timer.After(0.001, function()
            c:SetFramePositions(true);
        end);
    end
end

function c:GetCharacterStatsFrameNames()
    return csFrameNames;
end

function c:HookCharacterStatsFrameScripts()
    -- hook character stats frame scripts
    for _, csFrameName in ipairs(csFrameNames) do
        local csFrame = _G[csFrameName];
        if csFrame and not c.isFrameHooked[csFrameName] then
            csFrame:HookScript("OnShow", function()
                c:SetGqUiFramePosition();
            end);
            csFrame:HookScript("OnHide", function()
                c:SetGqUiFramePosition();
            end);
            c.isFrameHooked[csFrameName] = true;
        end
    end
end

function c:CreatePaperDollButton()
    local button = CreateFrame("Button", "GQ_PaperDollButton", c.paperDollFrame);
    button:SetPoint("TOPRIGHT", c.paperDollFrame, "TOPRIGHT", -40, -45);
    button:SetWidth(50);
    button:SetHeight(20);
    button:SetText("GQ");
    button:SetNormalFontObject("GameFontNormal");
    button:RegisterForClicks("LeftButtonUp");
    button:SetScript("OnClick", function()
        c:ToggleUI();
    end);

    local ntex = button:CreateTexture("GQ_PaperDollButtonIconTexture");
    ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up");
    ntex:SetTexCoord(0, 0.625, 0, 0.6875);
    ntex:SetAllPoints();
    button:SetNormalTexture(ntex);

    local htex = button:CreateTexture();
    htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight");
    htex:SetTexCoord(0, 0.625, 0, 0.6875);
    htex:SetAllPoints();
    button:SetHighlightTexture(htex);

    local ptex = button:CreateTexture();
    ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down");
    ptex:SetTexCoord(0, 0.625, 0, 0.6875);
    ptex:SetAllPoints();
    button:SetPushedTexture(ptex);

    local dtex = button:CreateTexture();
    dtex:SetTexture("Interface/Buttons/UI-Panel-Button-Disabled");
    dtex:SetTexCoord(0, 0.625, 0, 0.6875);
    dtex:SetAllPoints();
    button:SetDisabledTexture(dtex);

    local S = c:GetElvUiSkinModule();
    if S then
        S:HandleButton(button);
    end

    return button;
end

function c:DisablePaperDollButton()
    c.paperDollFrame.paperDollButton:Disable();
end

function c:EnablePaperDollButton()
    c.paperDollFrame.paperDollButton:Enable();
end

function c:CreatePaperDollLabel()
    local label = CreateFrame("Frame", "GQ_PaperDollLabel", c.paperDollFrame);
    label:SetPoint("CENTER", c.paperDollFrame, "CENTER", 0, -5);
    label:SetFrameStrata("HIGH");
    label:SetWidth(200);
    label:SetHeight(20);
    label:EnableMouse();
    label:SetScript("OnEnter", function(self)
        self:SetAlpha(0);
    end);
    label:SetScript("OnLeave", function(self)
        self:SetAlpha(1);
    end);

    label.text = label:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
    label.text:SetPoint("CENTER", 0, 0);

    return label;
end

function c:SetPaperDollLabelText(setName)
    if GQ_OPTIONS[c.OPT_SHOWCURRENTSET] then
        setName = setName or c:LoadCurrentSetName();
        if not setName then
            c.paperDollFrame.paperDollLabel.text:SetFormattedText("%s%s: %s", "|cffff0000", c:GetText("Current set"),
                UNKNOWN);
        elseif c:GetTableSize(c:GetIgnoredItems()) > 0 then
            c.paperDollFrame.paperDollLabel.text:SetFormattedText("%s%s: \"%s\"", "|cff6977f0",
                c:GetText("Current set"), setName);
        elseif c:IsSetComplete() then
            c.paperDollFrame.paperDollLabel.text:SetFormattedText("%s%s: \"%s\"", "|cffffcc00",
                c:GetText("Current set"), setName);
        else
            c.paperDollFrame.paperDollLabel.text:SetFormattedText("%s%s: \"%s\"", "|cffff0000",
                c:GetText("Current set"), setName);
        end
        c.paperDollFrame.paperDollLabel:Show();
    else
        c.paperDollFrame.paperDollLabel:Hide();
    end
end

function c:HideGqTooltips()
    for _, tt in ipairs(gqTooltips) do
        tt:Hide();
    end
end

function c:GetGqTooltip(index)
    index = index or 1;
    if not gqTooltips[index] then
        gqTooltips[index] = CreateFrame("GameTooltip", "GQ_Tooltip_" .. index, UIParent, "GameTooltipTemplate");
        gqTooltips[index]:SetToplevel(true);
    end
    return gqTooltips[index];
end

function c:ShowSetItemComparison(itemLink, setName, gameTooltipOwner)
    local itemSlots = c:GetItemSlots(itemLink);
    if itemSlots then
        for i, slotId in ipairs(itemSlots) do
            local setItemLink = c:LoadSlot(slotId, setName);
            if gameTooltipOwner then
                GameTooltip:SetOwner(gameTooltipOwner, 'ANCHOR_RIGHT');
                GameTooltip:SetHyperlink(itemLink);
                GameTooltip:Show();
            end

            local tt = c:GetGqTooltip(i);
            if i == 1 then
                tt:SetOwner(GameTooltip);
            else
                tt:SetOwner(c:GetGqTooltip(i - 1));
            end

            if not c:IsEmpty(setItemLink) then
                if c:IsNumeric(setItemLink) then
                    -- ammo workaround
                    setItemLink = c:GetItemLink(setItemLink);
                end

                if not c:IsEmpty(setItemLink) then
                    if not pcall(function()
                        tt:SetHyperlink(setItemLink);
                    end) then
                        if not c.itemComparisonErrorShown then
                            c:Println(c:GetText(
                                "Error while displaying item comparison tooltip for %s. Tooltip was resetted. This message will only be shown once per session.",
                                itemLink));
                            c.itemComparisonErrorShown = true;
                        end
                        c:SaveComparisonSetName(); -- reset set item comparison on error
                    end
                end
            else
                tt:AddLine(c:GetText("Empty slot"));
            end

            tt:AddLine(" ");
            tt:AddLine(c:GetText("%s slot item in \"%s\"", c:GetDisplaySlotName(slotId), setName));
            tt:Show();

            tt:ClearAllPoints();
            if GameTooltip:GetLeft() and GameTooltip:GetLeft() < 250 then
                if i == 1 then
                    tt:SetPoint("TOPLEFT", tt:GetOwner(), "TOPRIGHT");
                else
                    tt:SetPoint("TOPLEFT", tt:GetOwner(), "BOTTOMLEFT");
                end
            else
                if i == 1 then
                    tt:SetPoint("TOPRIGHT", tt:GetOwner(), "TOPLEFT");
                else
                    tt:SetPoint("TOPRIGHT", tt:GetOwner(), "BOTTOMRIGHT");
                end
            end
        end
        return true;
    end
end

function c:ShowAddSetDialog()
    StaticPopupDialogs["GQ_DIALOG_ADDSET"] = StaticPopupDialogs["GQ_DIALOG_ADDSET"] or {
        text = c:GetText("Enter a name for this set:"),
        button1 = APPLY,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 30,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent();
            local setName = c:Trim(self:GetText());
            if c:IsValidSetName(setName) then
                c:SaveSet(setName, false);
                c:UpdateBroker();
            else
                c:Println(c:GetText(
                    "Invalid set name: \"%s\". Set names must [1] not be empty, [2] be unique (case insensitive) and [3] not contain \"$\" (reserved).",
                    setName));
            end
            parent:Hide();
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide();
        end,
        OnAccept = function(self, data, data2)
            local setName = c:Trim(self.editBox:GetText());
            if c:IsValidSetName(setName) then
                c:SaveSet(setName, false);
                c:UpdateBroker();
            else
                c:Println(c:GetText(
                    "Invalid set name: \"%s\". Set names must [1] not be empty, [2] be unique (case insensitive) and [3] not contain \"$\" (reserved).",
                    setName));
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    };

    StaticPopup_Show("GQ_DIALOG_ADDSET");
end

function c:ShowRemoveSetDialog(setName)
    if setName then
        StaticPopupDialogs["GQ_DIALOG_REMOVESET"] = StaticPopupDialogs["GQ_DIALOG_REMOVESET"] or {
            text = c:GetText("Do you really want to remove \"%s\"?", "%s"),
            button1 = c:GetText(YES),
            button2 = c:GetText(NO),
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide();
            end,
            OnAccept = function(self, data)
                if data and tContains(c:LoadSetNames(), data) then
                    c:RemoveSet(data);
                    GqUiFrame_BtnSaveSet:Hide();
                    GqUiFrame_BtnRemoveSet:Hide();
                    c:UpdateBroker();
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        };

        local dialog = StaticPopup_Show("GQ_DIALOG_REMOVESET", setName);
        if dialog then
            dialog.data = setName;
        end
    end
end

function c:ShowResetDialog()
    StaticPopupDialogs["GQ_DIALOG_RESET"] = StaticPopupDialogs["GQ_DIALOG_RESET"] or {
        text = c:GetText("This will reset GearQuipper to defaults. All your sets will be lost.\n\nAre you sure?"),
        button1 = c:GetText("Reset"),
        button2 = c:GetText("Cancel"),
        OnEscapePressed = function()
            self:Hide();
        end,
        OnAccept = function()
            GQ_OPTIONS = {};
            GQ_DATA = {};
            GQ_AUX = {};
            c:ToggleUI(false);
            c:Init();
            c:CreateDefaultSet();
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    };

    StaticPopup_Show("GQ_DIALOG_RESET");
end

function c:ShowLoadSaveActionSlotsDialog(data)
    StaticPopupDialogs["GQ_DIALOG_LOADSAVEACTIONSLOTS"] = StaticPopupDialogs["GQ_DIALOG_LOADSAVEACTIONSLOTS"] or {
        text = c:GetText(
            "Your current action configuration differs from \"%s\".\n\nClick \"Save\" to replace the action slots saved in \"%s\" with your current ones\n\nor\n\nClick \"Load\" to replace your current action slots by the actions saved in \"%s\".",
            c:LoadCurrentSetName(), c:LoadCurrentSetName(), c:LoadCurrentSetName()),
        button1 = SAVE,
        button2 = CANCEL,
        button3 = c:GetText("Load"),
        OnAccept = function(self, data, data2)
            c:SaveActionConfiguration(c:LoadCurrentSetName());
        end,
        OnCancel = function(self, data, data2)
            if data then
                data:SetChecked(false);
            end
        end,
        OnAlt = function(self, data, data2)
            c:LoadActionConfiguration(c:LoadCurrentSetName());
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    };

    local dialog = StaticPopup_Show("GQ_DIALOG_LOADSAVEACTIONSLOTS");
    dialog.data = data;
end

function c:ShowDeleteScriptDialog(script)
    if script then
        StaticPopupDialogs["GQ_DIALOG_DELETESCRIPT"] = StaticPopupDialogs["GQ_DIALOG_DELETESCRIPT"] or {
            text = c:GetText("Do you really want to delete \"%s\"?", "%s"),
            button1 = c:GetText(YES),
            button2 = c:GetText(NO),
            OnAccept = function(self, data)
                if data then
                    c:DeleteScript(data);
                    c:ClearScriptEditorFields();
                    c:RefreshScripts();
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        };

        local dialog = StaticPopup_Show("GQ_DIALOG_DELETESCRIPT", script[c.FIELD_NAME]);
        if dialog then
            dialog.data = script;
        end
    end
end

-- gearquipper:ShowAcceptGqActionSlotManagementDialog()
function c:ShowAcceptGqActionSlotManagementDialog(acceptFunc, cancelFunc)
    StaticPopupDialogs["GQ_DIALOG_ACCEPTGQACTIONSLOTMANAGEMENT"] =
        StaticPopupDialogs["GQ_DIALOG_ACCEPTGQACTIONSLOTMANAGEMENT"] or {
            text = c:GetText(
                "You changed your talents.\n\nDo you want your action bars to be managed by GearQuipper or Blizzard (default)?\n\nIf you choose GearQuipper, your action bars will be saved with your equipment sets, not with your talents.\n\nIf you choose Blizzard, GearQuipper action slot management will be disabled.\n\nYou will not be asked again, but you can change this behaviour later in the GQ interface options."),
            button1 = c:GetText("GearQuipper"),
            button2 = c:GetText("Blizzard (default)"),
            OnAccept = function()
                acceptFunc();
            end,
            OnCancel = function()
                cancelFunc();
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 1
        };
    StaticPopup_Show("GQ_DIALOG_ACCEPTGQACTIONSLOTMANAGEMENT");
end

function c:ShowSaveScriptAfterClosingDialog(script, unsavedScriptText)
    if script then
        StaticPopupDialogs["GQ_DIALOG_SAVESCRIPTAFTERCLOSING"] =
            StaticPopupDialogs["GQ_DIALOG_SAVESCRIPTAFTERCLOSING"] or {
                text = c:GetText(
                    "Warning! You did not save your script.\n\nWe could not prevent Blizzard from closing the window, but we can still save your script for you.\n\nDo you want to save your script \"%s\" now?",
                    "%s"),
                button1 = c:GetText(YES),
                button2 = c:GetText(NO),
                OnAccept = function(self, data)
                    if data then
                        c:SaveScript(script, unsavedScriptText);
                    end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3
            };

        local dialog = StaticPopup_Show("GQ_DIALOG_SAVESCRIPTAFTERCLOSING", script[c.FIELD_NAME]);
        if dialog then
            dialog.data = script;
        end
    end
end

function c:SetSlotInfo(slotId, color)
    if not slotId then
        for slotId, _ in pairs(c:GetSlotInfo()) do
            c:SetSlotInfo(slotId);
        end
        return;
    else
        local slot = _G["Character" .. c:GetSlotInfo()[slotId]];
        if not slot.gqTex then
            slot.slotId = slotId;
            slot.gqTex = slot:CreateTexture(slot:GetName() .. "IconTexture", "OVERLAY");
            slot.gqTex:SetAllPoints();
        end

        if GQ_OPTIONS[c.OPT_SHOWSLOTBACKDROPS] and not color then
            local setName = c:LoadCurrentSetName();

            if c:LoadPartialOption(setName) and not c:LoadSlotState(slotId, setName) then
                color = "white";
            elseif c:IsIgnoredItem(slotId) then
                color = "blue";
            elseif c:IsSetItemOnSlot(slotId, c:LoadSlot(slotId, setName)) then
                color = "green";
            else
                color = "red";
            end
        end

        if color == "red" then
            slot.gqTex:SetColorTexture(1, 0, 0, 0.2);
            slot.gqInfo = c:GetText("|cffff0000%s|r %s", c:GetText("Expected Item:"), c:GetItemLink(c:LoadSlot(slotId)));
        else
            slot.gqInfo = nil;
            if color == "white" then
                slot.gqTex:SetColorTexture(1, 1, 1, 0.2);
            elseif color == "blue" then
                slot.gqTex:SetColorTexture(0, 0, 1, 0.2);
            else
                -- "green" (actually empty)
                slot.gqTex:SetColorTexture(0, 0, 0, 0);
            end
        end
    end
end

function c:GetSlotStateBoxes()
    if not slotStateBoxes then
        slotStateBoxes = {};
        for slotId, slotName in pairs(c:GetSlotInfo()) do
            slotStateBoxes[slotId] = c:CreateSlotStateBox(slotName, _G["Character" .. slotName]);
        end
    end
    return slotStateBoxes;
end

function c:ShowSlotStateBoxes()
    if GqUiFrame:IsVisible() and c:LoadPartialOption() then
        for slotId, checkBox in pairs(c:GetSlotStateBoxes()) do
            c:SetSlotState(slotId, c:LoadSlotState(slotId));
            checkBox:Show();
        end
    end
end

function c:HideSlotStateBoxes()
    for _, checkBox in pairs(c:GetSlotStateBoxes()) do
        checkBox:Hide();
    end
end

function c:CreateSlotStateBox(slotName, parent)
    local checkbutton = CreateFrame("CheckButton", slotName .. "StateBox", parent, "UICheckButtonTemplate");
    checkbutton:SetWidth(24);
    checkbutton:SetHeight(24);
    checkbutton:SetPoint("BOTTOMLEFT", -3, -3);
    checkbutton:RegisterForClicks("LeftButtonUp");
    checkbutton:SetScript("OnClick", function(self)
        local slotId = c:GetSlotId(slotName);
        c:SaveSlotState(slotId, self:GetChecked());
        if GqUiFrame:IsVisible() then
            c:RefreshSetList();
        end

        if not self:GetChecked() then
            c:SetSlotInfo(slotId, "white");
            return;
        elseif not c:IsSetItemOnSlot(slotId, c:LoadSlot(slotId)) then
            c:SaveSlot(slotId);
        end
        c:SetSlotInfo(slotId, "green");
    end);

    local S = c:GetElvUiSkinModule();
    if S then
        S:HandleCheckBox(checkbutton);
    end

    return checkbutton;
end

function c:SetSlotState(slotId, value)
    c:GetSlotStateBoxes()[slotId]:SetChecked(value);
end

function c:GetSlotState(slotId)
    return c:GetSlotStateBoxes()[slotId]:GetChecked();
end

local function GetContainersForItems(itemStrings)
    local result = {};
    if itemStrings then
        if c:IsAddonEnabled("AdiBags") then
            for slotId = 0, 255 do
                local frame = _G["AdiBagsItemButton" .. slotId];
                if frame and frame.bag and frame.slot then
                    local itemString = c:GetItemString(GetContainerItemLink(frame.bag, frame.slot));
                    if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                        tinsert(result, frame);
                    end
                end

                if c:IsAtBank() then
                    local frame = _G["AdiBagsBankItemButton" .. slotId];
                    if frame and frame.bag and frame.slot then
                        local itemString = c:GetItemString(GetContainerItemLink(frame.bag, frame.slot));
                        if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                            tinsert(result, frame);
                        end
                    end
                end
            end
        elseif c:IsAddonEnabled("ArkInventory") then
            -- I'm just guessing here...
            for invId = 0, 5 do
                for bagId = 0, 8 do
                    for slotId = 1, MAX_CONTAINER_ITEMS do
                        local frameName = "ARKINV_Frame" .. invId .. "ScrollContainerBag" .. bagId .. "Item" .. slotId;
                        local arkFrame = _G[frameName];
                        if arkFrame then
                            local arkData = arkFrame.ARK_Data;
                            if arkData then
                                local itemString = c:GetItemString(
                                    GetContainerItemLink(arkData.blizzard_id, arkData.slot_id));
                                if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                                    tinsert(result, arkFrame);
                                end
                            end
                        end
                    end
                end
            end
        elseif c:IsAddonEnabled("TBag") and TInvItm and TInvItm[TInvFrame.playerid] then
            -- I'm just guessing here...
            for bagId = 1, 13 do
                for slotId = 1, MAX_CONTAINER_ITEMS do
                    local match = false;
                    local tbagFrame = _G["TInvainerFrame" .. bagId .. "Item" .. slotId];
                    if tbagFrame then
                        if TInvItm[TInvFrame.playerid][bagId] and TInvItm[TInvFrame.playerid][bagId][slotId] and
                            TInvItm[TInvFrame.playerid][bagId][slotId]["il"] then
                            local itemString = TInvItm[TInvFrame.playerid][bagId][slotId]["il"]; -- .. ":" .. UnitLevel("player") .. ":::::::::"; -- messy workaround
                            local itemName = TInvItm[TInvFrame.playerid][bagId][slotId]["in"];
                            if not itemName then
                                break
                            end
                            for _, is in ipairs(itemStrings) do
                                if not match and c:GetItemName(is) == itemName then
                                    match = true;
                                    break
                                end
                            end
                        end

                        if not match then
                            tinsert(result, tbagFrame);
                        end
                    end
                end
            end
        elseif ElvUI then
            -- I'm just guessing here...
            for bagId = -8, 8 do
                for slotId = 1, MAX_CONTAINER_ITEMS do
                    local frameName = "ElvUI_ContainerFrameBag" .. bagId .. "Slot" .. slotId;
                    if _G[frameName] and _G[frameName].itemLink then
                        local itemString = c:GetItemString(_G[frameName].itemLink);
                        if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                            tinsert(result, _G[frameName]);
                        end
                    end
                end
            end
        else
            -- default player bags / bagnon containers
            for bagId = 0, NUM_BAG_SLOTS do
                local bagSize = GetContainerNumSlots(bagId);

                for slotId = 1, MAX_CONTAINER_ITEMS do
                    if c:IsAddonEnabled("Bagnon") then
                        local frameName = "ContainerFrame" .. bagId .. "Item" .. slotId;
                        if _G[frameName] and _G[frameName].info then
                            local itemString = c:GetItemString(_G[frameName].info.link);
                            if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                                tinsert(result, _G[frameName]);
                            end
                        end
                    else
                        local frameName = "ContainerFrame" .. (bagId + 1) .. "Item" .. (bagSize - slotId + 1);
                        if _G[frameName] then
                            local itemString = c:GetItemString(GetContainerItemLink(bagId, slotId));
                            if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                                tinsert(result, _G[frameName]);
                            end
                        end
                    end
                end
            end

            if c:IsAtBank() then
                -- default bank container
                for bankSlotId = 1, 28 do
                    local frameName = "BankFrameItem" .. bankSlotId;
                    if _G[frameName] then
                        local itemString = c:GetItemString(GetContainerItemLink(BANK_CONTAINER, bankSlotId));
                        if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                            tinsert(result, _G[frameName]);
                        end
                    end
                end

                -- default bank bags
                for bagId = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
                    local bagSize = GetContainerNumSlots(bagId);
                    for slotId = 1, bagSize do
                        if _G["BankFrame"] and _G["BankFrame"]:IsVisible() then
                            local frameName = "ContainerFrame" .. (bagId + 1) .. "Item" .. (bagSize - slotId + 1);
                            if _G[frameName] then
                                local itemString = c:GetItemString(GetContainerItemLink(bagId, slotId));
                                if c:IsEmpty(itemString) or not c:TableContains(itemStrings, itemString) then
                                    tinsert(result, _G[frameName]);
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return result;
end

local function ResetFrameAlpha(frameName)
    if _G[frameName] then
        _G[frameName]:SetAlpha(1);
    end
end

function c:HighlightItemsEquipped(itemStrings, setName)
    if not itemStrings then
        -- reset
        for id, name in pairs(c:GetSlotInfo()) do
            ResetFrameAlpha("Character" .. name);
        end
    else
        -- set
        for id, name in pairs(c:GetSlotInfo()) do
            _G["Character" .. name]:SetAlpha(0.35);
        end
        for _, itemString in pairs(itemStrings) do
            local list = c:IsItemEquipped(itemString);
            if list then
                for _, slotId in ipairs(list) do
                    if not c:LoadPartialOption(setName) or c:LoadSlotState(slotId, setName) then
                        ResetFrameAlpha("Character" .. c:GetSlotInfo()[slotId]);
                    end
                end
            end
        end
    end
end

function c:HighlightItemsInBags(itemStrings)
    if c:IsAddonEnabled("AdiBags") then
        -- reset alpha
        -- I'm just guessing here...
        for slotId = 0, 255 do
            ResetFrameAlpha("AdiBagsItemButton" .. slotId);
        end
        if c:IsAtBank() then
            for slotId = 0, 255 do
                ResetFrameAlpha("AdiBagsBankItemButton" .. slotId);
            end
        end
    elseif c:IsAddonEnabled("ArkInventory") then
        -- reset alpha
        -- I'm just guessing here...
        for invId = 0, 5 do
            for bagId = 0, 8 do
                for slotId = 1, MAX_CONTAINER_ITEMS do
                    ResetFrameAlpha("ARKINV_Frame" .. invId .. "ScrollContainerBag" .. bagId .. "Item" .. slotId);
                end
            end
        end
    elseif c:IsAddonEnabled("TBag") then
        -- reset alpha
        -- I'm just guessing here...
        for bagId = 1, 13 do
            for slotId = 1, MAX_CONTAINER_ITEMS do
                ResetFrameAlpha("TInvainerFrame" .. bagId .. "Item" .. slotId);
            end
        end
    elseif ElvUI then
        -- reset alpha
        -- I'm just guessing here...
        for bagId = -8, 8 do
            for slotId = 1, MAX_CONTAINER_ITEMS do
                ResetFrameAlpha("ElvUI_ContainerFrameBag" .. bagId .. "Slot" .. slotId);
            end
        end
    else
        -- default / bagnon frames
        -- reset alpha
        for bagId = 0, 24 do
            for slotId = 1, MAX_CONTAINER_ITEMS do
                ResetFrameAlpha("ContainerFrame" .. bagId .. "Item" .. slotId);
            end
        end

        if c:IsAtBank() then
            for frameId = 1, 28 do
                ResetFrameAlpha("BankFrameItem" .. frameId);
            end
        end
    end

    -- set alpha
    for _, frame in ipairs(GetContainersForItems(itemStrings)) do
        frame:SetAlpha(0.35);
    end
end

----- experimental -----

function c:CreateSecureActionButtons()
    for _, setName in ipairs(c:LoadSetNames()) do
        local macrotext;

        local mainHandItem = c:LoadSlot(INVSLOT_MAINHAND, setName);
        if c:IsEmpty(mainHandItem) then
            macrotext = string.format("/unequipslot %s", INVSLOT_MAINHAND);
        else
            macrotext = string.format("/equipslot %s %s", INVSLOT_MAINHAND, c:GetItemName(mainHandItem));
        end

        local offHandItem = c:LoadSlot(INVSLOT_OFFHAND, setName);
        if c:IsEmpty(offHandItem) then
            macrotext = string.format("/unequipslot %s", INVSLOT_OFFHAND);
        else
            macrotext = string.format("/equipslot %s %s", INVSLOT_OFFHAND, c:GetItemName(offHandItem));
        end

        local rangedItem = c:LoadSlot(INVSLOT_RANGED, setName);
        if c:IsEmpty(rangedItem) then
            macrotext = string.format("/unequipslot %s", INVSLOT_RANGED);
        else
            macrotext = string.format("/equipslot %s %s", INVSLOT_RANGED, c:GetItemName(rangedItem));
        end

        c:SetSecureAction(setName, macrotext);
    end
end

function c:CreateSecureActionButton(setName)
    if setName then
        if not secureActionButtons[setName] then
            local button = CreateFrame("Button", "GQ_SecureActionButton_" .. setName, UIParent,
                "SecureActionButtonTemplate");
            button:RegisterForClicks("AnyUp");
            button:SetAttribute("type", "macro");
            secureActionButtons[setName] = button;
        end
        return secureActionButtons[setName];
    end
end

function c:SetSecureAction(setName, macrotext)
    if setName and macrotext then
        local button = c:CreateSecureActionButton(setName);
        button:SetAttribute("macrotext", macrotext);
    end
end

function c:CallSecureAction(setName)
    if secureActionButtons[setName] then
        -- experimental
        -- C_Timer.After(0.1, function()
        --	secureActionButtons[setName]:Click();
        -- end);
    end
end
