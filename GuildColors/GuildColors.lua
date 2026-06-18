-- 1. Безопасное получение цвета класса (Только английский язык, регистронезависимый)
function FriendColor_ClassColor(class)
	if not class or class == "" then return { r = 1, g = 1, b = 1 } end
	
	-- Переводим в верхний регистр, так как игра может возвращать "Mage", "MAGE" или "SHAMAN"
	local localClass = tostring(class):upper()
	
	-- Принудительно задаем правильный синий цвет для Шамана
	if localClass == "SHAMAN" then
		return { r = 0.00, g = 0.44, b = 0.87 }
	end

	-- Исправляем возможные несовпадения имен для таблицы RAID_CLASS_COLORS
	if localClass == "DRUID" then localClass = "DRUID"
	elseif localClass == "HUNTER" then localClass = "HUNTER"
	elseif localClass == "MAGE" then localClass = "MAGE"
	elseif localClass == "PALADIN" then localClass = "PALADIN"
	elseif localClass == "PRIEST" then localClass = "PRIEST"
	elseif localClass == "ROGUE" then localClass = "ROGUE"
	elseif localClass == "WARLOCK" then localClass = "WARLOCK"
	elseif localClass == "WARRIOR" then localClass = "WARRIOR"
	end
	
	local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local classColor = colorTable and colorTable[localClass]
	
	-- Защита от nil: если класс не определен, возвращаем белый цвет
	return classColor or { r = 1, g = 1, b = 1 }
end

-- 2. Раскраска друзей Battle.net
function FriendColor_BNetFriend(i, friendOffset, numOnline)
	local bnetIDAccount, accountName, battleTag, isBattleTagPresence, characterName, bnetIDGameAccount, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText, isRIDFriend, messageTime, canSoR, isReferAFriend, canSummonFriend = BNGetFriendInfo(i);
	if isOnline == false or client ~= BNET_CLIENT_WOW then return end
	
	local hasFocus, characterName, client, realmName, realmID, faction, race, class, guild, zoneName, level, gameText, broadcastText, broadcastTime, canSoR, toonID, bnetIDAccount, isGameAFK, isGameBusy = BNGetGameAccountInfo(bnetIDGameAccount);
	local classc = FriendColor_ClassColor(class);
	
	local index = i - friendOffset + numOnline;
	local nameString = _G["FriendsFrameFriendsScrollFrameButton"..(index).."Name"];
	if nameString then
		nameString:SetText(accountName.." ("..characterName..", L"..level..")");
		nameString:SetTextColor(classc.r, classc.g, classc.b);
	end
	
	if CanCooperateWithGameAccount(toonID) ~= true then
		local infoString = _G["FriendsFrameFriendsScrollFrameButton"..(index).."Info"];
		if infoString then
			infoString:SetText(zoneName.." ("..realmName..")");
		end
	end
end

-- 3. Раскраска обычных друзей
function FriendColor_Friend(i, friendOffset)
	local friendInfo = C_FriendList.GetFriendInfoByIndex(i);
	if not friendInfo or friendInfo.connected == false then return end
	
	local classc = FriendColor_ClassColor(friendInfo.className);
	local index = i - friendOffset;
	
	local nameString = _G["FriendsFrameFriendsScrollFrameButton"..(index).."Name"];
	if nameString and friendInfo.name then
		nameString:SetText(friendInfo.name..", L"..friendInfo.level);
		nameString:SetTextColor(classc.r, classc.g, classc.b);
	end
end

-- 4. Раскраска списка Гильдии
function GuildColor_Class()
	if not GUILDMEMBERS_TO_DISPLAY or not GetGuildRosterInfo then return end
	local playerzone = GetRealZoneText()
	local off = FauxScrollFrame_GetOffset(GuildListScrollFrame) or 0
	
	for i = 1, GUILDMEMBERS_TO_DISPLAY, 1 do
		local name, _, _, level, class, zone, _, _, online = GetGuildRosterInfo(off + i)
		if name and class then
			local classc = FriendColor_ClassColor(class);
			if online then
				if _G['GuildFrameGuildStatusButton'..i..'Name'] then
					_G['GuildFrameGuildStatusButton'..i..'Name']:SetTextColor(classc.r, classc.g, classc.b);
				end
				local onlineString = _G['GuildFrameGuildStatusButton'..i..'Online'];
				if onlineString then
					if onlineString:GetText() == 'Online' then onlineString:SetTextColor(.5, 1, 1, 1) end
					if onlineString:GetText() == '<AFK>' then onlineString:SetTextColor(1, 1, .4) end
				end
				
				local nameString = _G["GuildFrameButton"..(i).."Name"];
				if nameString then nameString:SetTextColor(classc.r, classc.g, classc.b) end
				
				local classString = _G["GuildFrameButton"..(i).."Class"];
				if classString then classString:SetTextColor(classc.r, classc.g, classc.b) end
			else
				if _G['GuildFrameGuildStatusButton'..i..'Name'] then
					_G['GuildFrameGuildStatusButton'..i..'Name']:SetTextColor(classc.r, classc.g, classc.b, .5);
				end
				local nameString = _G["GuildFrameButton"..(i).."Name"];
				if nameString then nameString:SetTextColor(classc.r, classc.g, classc.b, .5) end
				
				local classString = _G["GuildFrameButton"..(i).."Class"];
				if classString then classString:SetTextColor(classc.r, classc.g, classc.b, .5) end
			end

			if zone and zone == playerzone then
				local zoneString = _G["GuildFrameButton"..i.."Zone"]
				if zoneString then
					if online then zoneString:SetTextColor(.5, 1, 1, 1) else zoneString:SetTextColor(.5, 1, 1, .5) end
				end
			end
		end
	end
end

-- 5. Вспомогательная функция получения смещения
function FriendColor_GetFriendOffset()
	local friendOffset = HybridScrollFrame_GetOffset(FriendsFrameFriendsScrollFrame);
	if not friendOffset or friendOffset < 0 then friendOffset = 0 end
	return friendOffset;
end

-- 6. Раскраска окна Поиска (/who)
function WhoColor_Class()
	if not _G.WHOS_TO_DISPLAY or not C_FriendList.GetWhoInfo then return end
	
	for i = 1, _G.WHOS_TO_DISPLAY do
		if _G["WhoFrameButton"..i.."Variable"] then
			_G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
		end
	end
	
	local whoOffset = FauxScrollFrame_GetOffset(WhoListScrollFrame) or 0
	
	for i = 1, _G.WHOS_TO_DISPLAY do
		local whoIndex = whoOffset + i
		local info = C_FriendList.GetWhoInfo(whoIndex)
		if info then
			local guild = info.fullGuildName
			local name = info.fullName
			local class = info.classStr or info.className
			local zone = info.area
			local race = info.raceStr
			local classc = FriendColor_ClassColor(class);

			local nameString = _G['WhoFrameButton'..i..'Name']
			if nameString then
				nameString:SetTextColor(classc.r, classc.g, classc.b);
			end
			
			local selectedID = WhoFrameDropDown and UIDropDownMenu_GetSelectedID(WhoFrameDropDown)
			local variableText = _G["WhoFrameButton"..i.."Variable"]
			if variableText then
				if selectedID == 1 then
					local playerzone = GetRealZoneText()
					if zone and zone == playerzone then variableText:SetTextColor(.5, 1, 1, 1) end
				elseif selectedID == 2 then
					local playerGuild = GetGuildInfo("player")
					if guild and guild == playerGuild then variableText:SetTextColor(.5, 1, 1, 1) end
				elseif selectedID == 3 then
					local playerRace = UnitRace("player")					
					if race and race == playerRace then variableText:SetTextColor(.5, 1, 1, 1) end
				end
			end		
		end
	end
end

-- 7. Объединенный безопасный обработчик обновлений (Хук)
function FriendColor_Hook_FriendsList_Update()
	local friendOffset = FriendColor_GetFriendOffset();
	local numBNetTotal, numBNetOnline = BNGetNumFriends();
	local numFriends = C_FriendList.GetNumFriends() or 0;
	local numOnline = C_FriendList.GetNumOnlineFriends() or 0;
	
	-- Раскрашиваем обычных онлайн друзей
	if numOnline > 0 then
		for i = 1, numFriends do
			FriendColor_Friend(i, friendOffset);
		end
	end
		
	-- Раскрашиваем онлайн Battlenet друзей
	if numBNetOnline and numBNetOnline > 0 then
		for i = 1, numBNetTotal do
			FriendColor_BNetFriend(i, friendOffset, numOnline);
		end
	end
	
	-- Запуск раскраски гильдии (вызывается один раз, а не в цикле)
	GuildColor_Class()
	
	-- Запуск раскраски окна поиска (вызывается один раз)
	local numWhos, totalNumWhos = C_FriendList.GetNumWhoResults();
	if numWhos and numWhos > 0 then
		WhoColor_Class()
	end
end

-- 8. СОВРЕМЕННЫЕ ХУКИ (Исправлено для WoW Classic Era 1.14+)
if FriendsListFrame_Update then
	hooksecurefunc("FriendsListFrame_Update", FriendColor_Hook_FriendsList_Update);
else
	hooksecurefunc("FriendsList_Update", FriendColor_Hook_FriendsList_Update);
end

if WhoList_Update then
	hooksecurefunc("WhoList_Update", WhoColor_Class);
else
	hooksecurefunc("WhoList_Update", FriendColor_Hook_FriendsList_Update);
end

if GuildRoster_Update then
	hooksecurefunc("GuildRoster_Update", GuildColor_Class);
else
	hooksecurefunc("GuildStatus_Update", FriendColor_Hook_FriendsList_Update);
end

hooksecurefunc("HybridScrollFrame_Update", FriendColor_Hook_FriendsList_Update);
