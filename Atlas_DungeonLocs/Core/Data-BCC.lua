-- $Id: Data-BCC.lua 83 2022-03-25 17:37:45Z arithmandar $
--[[

	Atlas, a World of Warcraft instance map browser
	Copyright 2005 ~ 2010 - Dan Gilbert <dan.b.gilbertat gmail dot com>
	Copyright 2010 - Lothaer <lothayerat gmail dot com>, Atlas Team
	Copyright 2011 ~ 2022 - Arith Hsu, Atlas Team <atlas.addon at gmail dot com>

	This file is part of Atlas.

	Atlas is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	Atlas is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Atlas; if not, write to the Free Software
	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

--]]
local _G = getfenv(0)

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub

local BZ = Atlas_GetLocaleLibBabble("LibBabble-SubZone-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)
local ALC = LibStub("AceLocale-3.0"):GetLocale("Atlas")

local data = {}
local alliance = {}
local horde = {}
private.data = data
private.alliance = alliance
private.horde = horde

local BLUE = "|cff6666ff"
local GREN = "|cff66cc33"
local LBLU = "|cff33cccc"
local _RED = "|cffcc3333"
local ORNG = "|cffcc9933"
local PINK = "|ccfcc33cc"
local PURP = "|cff9900ff"
local WHIT = "|cffffffff"
local GREY = "|cff999999"
local YLOW = "|cffcccc33"
local ALAN = "|cff7babe0" -- Alliance
local HRDE = "|cffda6955" -- Horde
local INDENT = "      "

alliance.maps = {}
alliance.coords = {}
horde.maps = {}
horde.coords = {}

data.maps = {
	DLEast_BCC = {
		ZoneName = { BZ["Eastern Kingdoms"] },
		{ BLUE.." A) "..BZ["Alterac Valley"]..ALC["Comma"].._RED..BZ["Hillsbrad Foothills"], 10001 },
		{ BLUE.." B) "..BZ["Arathi Basin"]..ALC["Comma"].._RED..BZ["Arathi Highlands"], 10002 },
		{ WHIT.." 1) "..BZ["Magisters' Terrace"]..ALC["Comma"].._RED..BZ["Isle of Quel'Danas"], 10003 },
		{ WHIT..INDENT..BZ["Sunwell Plateau"]..ALC["Comma"].._RED..BZ["Isle of Quel'Danas"], 10004 },
		{ WHIT.." 2) "..BZ["Zul'Aman"]..ALC["Comma"].._RED..BZ["Ghostlands"], 10005 },
		{ WHIT.." 3) "..BZ["Scarlet Monastery"]..ALC["Comma"].._RED..BZ["Tirisfal Glades"], 10006 },
		{ WHIT.." 4) "..BZ["Stratholme"]..ALC["Comma"].._RED..BZ["Eastern Plaguelands"], 10007 },
		{ WHIT..INDENT..BZ["Naxxramas"]..ALC["Comma"].._RED..BZ["Stratholme"], 10008 },
		{ WHIT.." 5) "..BZ["Scholomance"]..ALC["Comma"].._RED..BZ["Western Plaguelands"], 10009 },
		{ WHIT.." 6) "..BZ["Shadowfang Keep"]..ALC["Comma"].._RED..BZ["Silverpine Forest"], 10010 },
		{ WHIT.." 7) "..BZ["Gnomeregan"]..ALC["Comma"].._RED..BZ["Dun Morogh"], 10011 },
		{ WHIT.." 8) "..BZ["Uldaman"]..ALC["Comma"].._RED..BZ["Badlands"], 10012 },
		{ WHIT.." 7) "..BZ["Blackrock Mountain"]..ALC["Comma"].._RED..BZ["Searing Gorge"]..ALC["Slash"]..BZ["Burning Steppes"], 10013 },
		{ WHIT..INDENT..BZ["Blackrock Depths"], 10014 },
		{ WHIT..INDENT..BZ["Blackrock Spire"], 10015 },
		{ WHIT..INDENT..BZ["The Molten Core"], 10016 },
		{ WHIT..INDENT..BZ["Blackwing Lair"], 10017 },
		{ WHIT.."10) "..BZ["The Stockade"]..ALC["Comma"].._RED..BZ["Stormwind City"], 10018 },
		{ WHIT.."11) "..BZ["The Deadmines"]..ALC["Comma"].._RED..BZ["Westfall"], 10019 },
		{ WHIT.."12) "..BZ["Zul'Gurub"]..ALC["Comma"].._RED..BZ["Northern Stranglethorn"], 10020 },
		{ WHIT.."13) "..BZ["Sunken Temple"]..ALC["Comma"].._RED..BZ["Swamp of Sorrows"], 10021 },
		{ WHIT.."14) "..BZ["Karazhan"]..ALC["Comma"].._RED..BZ["Deadwind Pass"], 10022 },
		{ "" },
		{ BLUE..L["Blue"]..ALC["Colon"]..ORNG..BATTLEGROUNDS },
		{ WHIT..L["White"]..ALC["Colon"]..ORNG..L["Instances"] },
	},
	DLWest_BCC = {
		ZoneName = { BZ["Kalimdor"] },
		{ BLUE.." A) "..BZ["Warsong Gulch"]..ALC["Comma"].._RED..BZ["Ashenvale"], 10000 },
		{ WHIT.." 1) "..BZ["Blackfathom Deeps"]..ALC["Comma"].._RED..BZ["Ashenvale"], 10001 },
		{ WHIT.." 2) "..BZ["Ragefire Chasm"]..ALC["Comma"].._RED..BZ["Orgrimmar"], 10002 },
		{ WHIT.." 3) "..BZ["Wailing Caverns"]..ALC["Comma"].._RED..BZ["Northern Barrens"], 10003 },
		{ WHIT.." 4) "..BZ["Maraudon"]..ALC["Comma"].._RED..BZ["Desolace"], 10004 },
		{ WHIT.." 5) "..BZ["Dire Maul"]..ALC["Comma"].._RED..BZ["Feralas"], 10005 },
		{ WHIT.." 6) "..BZ["Razorfen Kraul"]..ALC["Comma"].._RED..BZ["Southern Barrens"], 10006 },
		{ WHIT.." 7) "..BZ["Razorfen Downs"]..ALC["Comma"].._RED..BZ["Thousand Needles"], 10007 },
		{ WHIT.." 8) "..BZ["Onyxia's Lair"]..ALC["Comma"].._RED..BZ["Dustwallow Marsh"], 10008 },
		{ WHIT.." 9) "..BZ["Zul'Farrak"]..ALC["Comma"].._RED..BZ["Tanaris"], 10009 },
		{ WHIT.."10) "..BZ["Temple of Ahn'Qiraj"]..ALC["Comma"].._RED..BZ["Silithus"], 10010 },
		{ WHIT.."11) "..BZ["Ruins of Ahn'Qiraj"]..ALC["Comma"].._RED..BZ["Silithus"], 10011 },
		{ WHIT.."10) "..BZ["Caverns of Time"]..", ".._RED..BZ["Tanaris"], 10012 };
		{ WHIT..INDENT..BZ["Old Hillsbrad Foothills"], 10013 };
		{ WHIT..INDENT..BZ["The Black Morass"], 10014 };
		{ WHIT..INDENT..BZ["Hyjal Summit"], 10015 };
		{ "" },
		{ BLUE..L["Blue"]..ALC["Colon"]..ORNG..BATTLEGROUNDS },
		{ WHIT..L["White"]..ALC["Colon"]..ORNG..L["Instances"] },
	},
	DLOutland_BCC = {
		ZoneName = { BZ["Outland"] },
		{ WHIT.." 1) "..BZ["Gruul's Lair"]..ALC["Comma"].._RED..BZ["Blade's Edge Mountains"], 10001 },
		{ WHIT.." 2) "..BZ["Tempest Keep"]..ALC["Comma"].._RED..BZ["Netherstorm"], 10002 },
		{ WHIT..INDENT..BZ["The Mechanar"] },
		{ WHIT..INDENT..BZ["The Botanica"] },
		{ WHIT..INDENT..BZ["The Arcatraz"] },
		{ WHIT..INDENT..BZ["Tempest Keep"] },
		{ WHIT.." 3) "..BZ["Coilfang Reservoir"]..ALC["Comma"].._RED..BZ["Zangarmarsh"], 10003 },
		{ WHIT..INDENT..BZ["The Slave Pens"] },
		{ WHIT..INDENT..BZ["The Underbog"] },
		{ WHIT..INDENT..BZ["The Steamvault"] },
		{ WHIT..INDENT..BZ["Serpentshrine Cavern"] },
		{ WHIT.." 4) "..BZ["Hellfire Citadel"]..ALC["Comma"].._RED..BZ["Hellfire Peninsula"], 10004 },
		{ WHIT..INDENT..BZ["Hellfire Ramparts"] },
		{ WHIT..INDENT..BZ["The Blood Furnace"] },
		{ WHIT..INDENT..BZ["The Shattered Halls"] },
		{ WHIT..INDENT..BZ["Magtheridon's Lair"] },
		{ WHIT.." 5) "..BZ["Auchindoun"]..ALC["Comma"].._RED..BZ["Terokkar Forest"], 10005 },
		{ WHIT..INDENT..BZ["Mana-Tombs"] },
		{ WHIT..INDENT..BZ["Auchenai Crypts"] },
		{ WHIT..INDENT..BZ["Sethekk Halls"] },
		{ WHIT..INDENT..BZ["Shadow Labyrinth"] },
		{ WHIT.." 6) "..BZ["Black Temple"]..ALC["Comma"].._RED..BZ["Shadowmoon Valley"], 10006 },
	}
}

data.coords = {
}
