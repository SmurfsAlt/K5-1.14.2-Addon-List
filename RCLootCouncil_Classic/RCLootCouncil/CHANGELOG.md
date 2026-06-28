# RCLootCouncil

## [2.19.3-75-gfdae092](https://github.com/evil-morfar/RCLootCouncil2/tree/fdae092cc74b6a448c89ea5ccd1f10b467889b48) (2023-11-14)
[Full Changelog](https://github.com/evil-morfar/RCLootCouncil2/compare/2.19.3...fdae092cc74b6a448c89ea5ccd1f10b467889b48) [Previous Releases](https://github.com/evil-morfar/RCLootCouncil2/releases)

- Merge branch 'HEAD' into v2.x  
- Added checks for missing candidate data  
- Merge branch 'HEAD' into v2.x  
- Observe mode udpdate.  
    Observe + hide votes will no longer hide votes for non-council members.  
- Prevent nil errors from breaking errorhandler  
- Updated Ace3  
- VF: Update current session only  
    Updating everything every time we receive data could lead to rows jumping around. Now we only update visuals if there's updates to the session we're looking at.  
- VF Session buttons checkmark update.  
    Selecting an awarded item now shows a yellow checkmark instead of nothing.  
- Updated token data  
- Updated random roll system  
- Fixed history issue when awarding multiple copies.  
    History would record "Awarded" when a awarding an item multiple times to the same player  
- Updated Ace3  
- Created "GlobalUpdates" file.  
    For handling certain functions that isn't interchanceable between WoW versions.  
    Currently only "C\_Container" is used which isn't available in classic era  
- Fixed issue in ML:ItemsInBagsLowTradeTimeRemainingReminder  
- Added button groups for mounts and bags.  
- Added `start` command  
- Added export of items in session  
- Added equipcLocation to more info awarded items  
- Fixed issue with changing history response and GetResponse without mldb  
- Fixed keep/trade pop-up  
- Shrunk header of session frame removing empty space  
- Removed TradeUI ST header to make title clickable  
- Fixed deleteDate selection not showing up  
- Fix wrong usage of GetContainerItemInfo  
- Removed deprecated use of "Container" functions  
- Fix award later error on error  
- Removed old interface hack  
- TradeUI: Hiding frame would disable comms.  
- Fix potential nil error (Classic#46)  
- TradeUI: Grab recipient from Blizzard UI  
- Retail: Update test version logic  
- TradeUI: Updates from retail.  
    Added delete column.  
- ItemStorage: Updated with latest retail changes.  
    Includes major overhaul of time keeping and persistance of ItemStorage  
- Checkmarks on awarded session buttons  
- Esc to close frames  
- Fix issue with Items not being removed when no longer in bags  
- Disable "OnMouseWheel" when frame minimzied.  
    Frames would intercept scroll wheel otherwise.  
- Update ItemStorage with latest changes  
- Updated TradeUI/ItemStorage logic.  
    Should be more reliable  
- Fixed button sort issue  
- Add all tradeables from bags to session  
- Added itemName to JSON export  
- Only attempt to remove trade items from storage if we're supposed to trade it  
- Removed v3.0 warning  
- Copied lootTable logic from retail.  
    Tokens weren't always parsed properly.  
    lt\_additions required retail upgrade  
- Added responseText to award fail/succes event  
- Persist boss name on award later items  
- Added `id` to json export  
- options for /rc  
- Added itemLink to award fail/success events  
- Fix CurseClassic#169  
    With observe enabled, receiving mldb after council would not do CallModule:VF, leading to it not being enabled later when receiving LT.  
- Merge branch 'HEAD' into v2.x  
- Updated logic for restored ItemStorage items  
- TradeUI should now handle reawards  
- Added blacklist override  
- Fixed issue with `/rc remove`  
- TradeUI should now handle duplicates  
- Fixed spelling  
- fix ST obstructing sessionFrame title  
- Fixed frame z-level fighting  
- Added missing LSM files  
- Updated a few more libs  
- Merge pull request #209 from corylation/v2.x  
    Updates for TBC Classic  
- Update CreateFrame calls to add BackdropMixin  
- Update libdialog  
- Update lib-st  
- Add Backdrop Mixin to CreateFrame  
- Update MSA-DropDownMenu to v1.0.12  
- Update Ace3 Libs  
- Don't clear ml.lootTable from session frame on a running session  
- Fixed desaturated item icon in votingframe  
- Merge pull request #193 from snowlove/BugFix-colorInfo  
    Fix colorInfo error  
- Fix colorInfo error  
    Removed LootSlot() API call because it should not be called when MasterLooting, it will cause a chain of errors through Blizzards LootFrame.lua, specifically the MasterLooterFrame\_Show() Function, since the Slot[index] was never "Selected" by OnClick, when the MasterLooterFrame pops up. This can also be resolved by _G["LootButton"..i]:Click("RightButton") which fires off the approriate events to "Select" Slot[Index]  
- GuildRoster call in options now uses Utils.GuildRoster  
- Finalized function editing for full classic support  
