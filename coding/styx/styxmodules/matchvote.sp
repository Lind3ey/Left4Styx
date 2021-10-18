#pragma semicolon 1

#if defined __matchvote__
#endinput
#endif
#define __matchvote__

#define		NOMATCH_SLOTS		4
#define	 	MATCHMODES_PATH		"configs/matchstyx.txt"

static Handle:		hBuiltinvote;
static Handle:		hKvMatchModes;
static String:		temp_sConfig[32];
static String:		temp_sCfgName[32];
static bool:		bIsMatchModeFailed	= false;

public MV_OnPluginStart()
{
	if(InitiateMatchModes())
	{
		RegConsoleCmd("sm_matchstyx", 			MatchRequest);
		RegConsoleCmd("sm_styx", 				MatchRequest);
		RegConsoleCmd("sm_rmatch", 				MatchReset);
	}
	else
	{
		bIsMatchModeFailed = true;
	}
	
	SetConVarInt(FindConVar("sv_maxplayers"), NOMATCH_SLOTS);
	
	// Tell dummy what to do. Called only when !rmatch passed.
	if(!LGO_IsMatchModeLoaded())
		CPrintToChatAll("{blue}Config has unloaded, say {green}!match {blue}to match mode");
}

public bool:InitiateMatchModes()
{
	decl String:sBuffer[128];
	hKvMatchModes = CreateKeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);
	if (!FileToKeyValues(hKvMatchModes, sBuffer))
	{
		PrintToServer("Couldn't load matchmodes.txt!");
		return false;
	}
	return true;
}

public MV_OnPluginEnd()
{
	if(FindConVar("sv_maxplayers") != INVALID_HANDLE)
		SetConVarInt(FindConVar("sv_maxplayers"), NOMATCH_SLOTS);
}

public MV_OnClientPostAdminCheck(client) 
{
	CreateTimer(5.0, Timer_Welcome, client);
}

public Action:Timer_Welcome(Handle:timer, any:client) 
{
	if(bIsMatchModeFailed) return Plugin_Handled;
	if(!IsClientInGame(client)) return Plugin_Handled;
	if(IsConfoglAvailable() && LGO_IsMatchModeLoaded())
	{
		
		// decl String:sCfgname[64];
		// GetReadyCfgName(sCfgname);
		// CPrintToChat(client, "{green}# {olive}$Config: {blue}%s", sCfgname);
		// CPrintToChat(client, "{green}* {blue}use {green}!rmatch {blue}to resetmatch.");
	}
	else
	{
		CPrintToChat(client, "{green}%s$                {blue}Hello, {green}%N {blue}!", hostfile, client);
		CPrintToChat(client, "{green}%s$                {blue}Say {green}!match {blue}to choose game config.", hostfile);
		// MatchModeMenu(client);
	}
	return Plugin_Handled;
}

public Action:MatchRequest(client, args)
{
	if ((!client) || (!IsConfoglAvailable())) return Plugin_Handled;
	
	if (args > 0)
	{
		//config specified
		new String:sCfg[64], String:sName[64];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		if (FindConfigName(sCfg, sName, sizeof(sName)))
		{
			CutStringAfter(sName, '(');
			if (StartMatchVote(client, sName))
			{
				strcopy(temp_sConfig, sizeof(temp_sConfig), sCfg);
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}
	//show main menu
	MatchModeMenu(client);
	return Plugin_Handled;
}

bool:FindConfigName(const String:cfg[], String:name[], maxlength)
{
	KvRewind(hKvMatchModes);
	if (KvGotoFirstSubKey(hKvMatchModes))
	{
		do
		{
			if (KvJumpToKey(hKvMatchModes, cfg))
			{
				KvGetString(hKvMatchModes, "name", name, maxlength);
				return true;
			}
		} while (KvGotoNextKey(hKvMatchModes, false));
	}
	return false;
}

MatchModeMenu(client)
{
	new Handle:hMenu = CreateMenu(MatchModeMenuHandler);
	SetMenuTitle(hMenu, "Select match mode:");
	new String:sBuffer[64];
	KvRewind(hKvMatchModes);
	if (KvGotoFirstSubKey(hKvMatchModes))
	{
		do
		{
			KvGetSectionName(hKvMatchModes, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(hKvMatchModes, false));
	}
	DisplayMenu(hMenu, client, 30);
}

public MatchModeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(hKvMatchModes);
		if (KvJumpToKey(hKvMatchModes, sInfo) && KvGotoFirstSubKey(hKvMatchModes))
		{
			new Handle:hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select %s config:", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(hKvMatchModes, sInfo, sizeof(sInfo));
				KvGetString(hKvMatchModes, "name", sBuffer, sizeof(sBuffer));
				if(sBuffer[0] == '*')
					AddMenuItem(hMenu, sInfo, sBuffer, ITEMDRAW_DISABLED);
				else
					AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(hKvMatchModes));
			// AddMenuItem(hMenu, "back", "<-Back");
			SetMenuExitButton(hMenu, true);
			SetMenuExitBackButton(hMenu, true);
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			PrintHintText(param1, "No configs for such mode were found.");
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public ConfigsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		if(StrEqual(sInfo, "back", false))
		{
			MatchModeMenu(param1);
			return;
		}
		CutStringAfter(sBuffer, '(');
		PreStartVote(param1, sInfo, sBuffer);
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		MatchModeMenu(param1);
	}
}

bool:PreStartVote(client, const String:cfg[], const String:cfgname[])
{
	// static min, max, cur;
	// static Handle wpanel = INVALID_HANDLE;
	strcopy(temp_sConfig, sizeof(temp_sConfig), cfg);
	strcopy(temp_sCfgName, sizeof(temp_sCfgName), cfgname);
	if (GetClientTeam(client) == TEAM_SPECTATORS)
	{
		PrintHintText(client, "Match voting isn't allowed for spectators.");
		return false;
	}
	if (LGO_IsMatchModeLoaded())
	{
		PrintHintText(client, "Match vote cannot be started. \nMatch is already running.");
		PrintToChat(client, "\x01Say \x04!rmatch \x01to vote turning off current match.");
		return false;
	}
	if(StartMatchVote(client, cfgname))
	{
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	PrintHintText(client, "Sorry, find error.");
	return false;
}

bool:StartMatchVote(client, const String:cfgname[])
{
	if (!IsBuiltinVoteInProgress())
	{
		new String:sBuffer[64];
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Load: '%s'?", cfgname);
		SetBuiltinVoteArgument(hBuiltinvote, sBuffer);
		SetBuiltinVoteInitiator(hBuiltinvote, client);
		SetBuiltinVoteResultCallback(hBuiltinvote, MatchVoteResultHandler);
		DisplayBuiltinVoteToAllNonSpectators(hBuiltinvote, 20);
		LogPlayerAction(client, sBuffer);
		return true;
	}
	PrintHintText(client, "Match vote cannot be started now.");
	return false;
}

public void MatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "Get ready for Combat");
				ReplaceCharIn(temp_sConfig, '-', '/');
				ServerCommand("sm_fm %s", temp_sConfig);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:MatchReset(client, args)
{
	if ((!client) || (!IsConfoglAvailable())) return Plugin_Handled;
	//voting for resetmatch
	StartResetMatchVote(client);
	return Plugin_Handled;
}

StartResetMatchVote(client)
{
	if (GetClientTeam(client) == TEAM_SPECTATORS)
	{
		PrintHintText(client, "Resetmatch voting isn't allowed for spectators.");
		return;
	}
	if (!LGO_IsMatchModeLoaded())
	{
		PrintHintText(client, "Resetmatch vote cannot be started.\n No match is running.");
		return;
	}
	if (!IsBuiltinVoteInProgress())
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == TEAM_SPECTATORS))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		if (ConnectingPlayers() > 0)
		{
			PrintHintText(client, "Resetmatch vote cannot be started.\n Players are connecting");
			return;
		}
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hBuiltinvote, "Turn off LGOFNOC?");
		SetBuiltinVoteInitiator(hBuiltinvote, client);
		SetBuiltinVoteResultCallback(hBuiltinvote, ResetMatchVoteResultHandler);
		DisplayBuiltinVote(hBuiltinvote, iPlayers, iNumPlayers, 20);
		FakeClientCommand(client, "Vote Yes");
		return;
	}
	PrintHintText(client, "Resetmatch vote cannot be started now.");
}

public void ResetMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "LGOFNOC is unloading...");
				ServerCommand("sm_resetmatch");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			hBuiltinvote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}
