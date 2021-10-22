#pragma semicolon 1

#include <sourcemod>
#include <builtinvotes>
#include <styxframe>

#define 	MAP_PATH			"configs/mapvote.txt"
#define 	MAP_CHANGE_DELAY	5.0

static Handle:	g_kvAddonMap;
static bool: bInfinaleScroll = false;
new String:	sMapvoteto[32];

new const String: OffiMapName[13][]={
	"",
	"c1m1_hotel",
	"c2m1_highway",
	"c3m1_plankcountry",
	"c4m1_milltown_a",
	"c5m1_waterfront",
	"c6m1_riverbank",
	"c7m1_docks",
	"c8m1_apartment",
	"c10m1_caves",
	"c10m1_caves",
	"c11m1_greenhouse",
	"c12m1_hilltop"
};

public Plugin myinfo =
{
	name = "[L4D2] Maps Manager",
	author = "AiMee",
};

public void OnPluginStart()
{
	decl String:sBuffer[128];
	g_kvAddonMap = CreateKeyValues("Map");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MAP_PATH);
	if (!FileToKeyValues(g_kvAddonMap, sBuffer))
		PrintToServer("Failed to read mapvote.txt");
	
	RegConsoleCmd("sm_vmap", 			MapRequest);
	RegConsoleCmd("sm_skip", 			SkipCmd);
	HookEvent("finale_win",  			Event_FinalWin,	EventHookMode_PostNoCopy);
	HookEvent("versus_match_finished", 	Event_FinalEnd,	EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	bInfinaleScroll = false;
}

public Action:SkipCmd(client, args)
{
	if(bInfinaleScroll)
	{
		if(!client || !IsClientInGame(client)) return Plugin_Handled;
		PrintToChatAll("\x01* \x04%N \x01选择了跳过!", client);
		CreateTimer(MAP_CHANGE_DELAY, Timer_NextMap, _, TIMER_FLAG_NO_MAPCHANGE);
		bInfinaleScroll = false;
	}
	return Plugin_Handled;
}

public Action:MapRequest(client, args)
{
	MapListMenu(client);
	return Plugin_Handled;
}

MapListMenu(client)
{
	new Handle:hMenu = CreateMenu(MapListMenuHandler);
	SetMenuTitle(hMenu, "Select a map:");
	new String:sBuffer[64];
	KvRewind(g_kvAddonMap);
	if (KvGotoFirstSubKey(g_kvAddonMap))
	{
		do
		{
			KvGetSectionName(g_kvAddonMap, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(g_kvAddonMap, false));
	}
	DisplayMenu(hMenu, client, 20);
}

public MapListMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_kvAddonMap);
		if (KvJumpToKey(g_kvAddonMap, sInfo) && KvGotoFirstSubKey(g_kvAddonMap))
		{
			new Handle:hMenu = CreateMenu(ChapterMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select Chapter:");
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_kvAddonMap, sInfo, sizeof(sInfo));
				KvGetString(g_kvAddonMap, "name", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(g_kvAddonMap));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			PrintToChat(param1, "No such map found");
			MapListMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public ChapterMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		if (StartMapVote(param1, sInfo))
		{
			strcopy(sMapvoteto, sizeof(sMapvoteto), sInfo);
			FakeClientCommand(param1, "Vote Yes");
		}
		else
		{
			MapListMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		MapListMenu(param1);
	}
}

bool:StartMapVote(client, const char[] map)
{
	if (IsNewBuiltinVoteAllowed())
	{
		new String:sBuffer[64];
		new Handle:bhMapvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Change map to '%s'?", map);
		SetBuiltinVoteArgument(bhMapvote, sBuffer);
		SetBuiltinVoteInitiator(bhMapvote, client);
		SetBuiltinVoteResultCallback(bhMapvote, MapVoteResultHandler);
		DisplayBuiltinVoteToAll(bhMapvote, 10);
		return true;
	}
	PrintToChat(client, "\x01[\x04!\x01]\x05Map vote \x01cannot be started now.");
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

#define 	_vmap_delay_ 	5.0
public MapVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "Get ready for new map.");
				CreateTimer(_vmap_delay_, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:Event_FinalWin(Event event, const char [] name, bool dontBroadcast)
{
	if(!Styx_IsVersus())
		CreateTimer(15.0, Timer_NextMap, _, TIMER_FLAG_NO_MAPCHANGE);
}

#define Finale_change_delay 60.0
public Action:Event_FinalEnd(Event event, const char [] name, bool dontBroadcast)
{
	CreateTimer(Finale_change_delay, Timer_NextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	bInfinaleScroll = true;
	PrintToChatAll("\x01说 \x04!skip \x01可以跳过!");
}

public Action:Timer_ChangeMap(Handle timer)
{
	ServerCommand("changelevel %s", sMapvoteto);
}

public Action:Timer_NextMap(Handle timer)
{
	decl String:sCurMap[32];
	decl String:sBuffer[8];
	GetCurrentMap(sCurMap, sizeof(sCurMap));
	for(new i =1; i < 13; i++)
	{
		Format(sBuffer,sizeof(sBuffer),"c%dm",i);
		if(StrContains(sCurMap, sBuffer, false) != -1)
		{
			i++;
			if(i > 12) i=1;
			ServerCommand("changelevel %s", OffiMapName[i]);
			return Plugin_Handled;
		}
	}
	ServerCommand("changelevel %s", OffiMapName[2]);
	return Plugin_Handled;
}