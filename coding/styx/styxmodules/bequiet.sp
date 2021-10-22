#pragma semicolon 1

#include <sourcemod>

static Handle: hCvarCvarChange;
static Handle: hCvarNameChange;
static Handle: hCvarSpecNameChange;
static Handle: hCvarShowSpecsChat;

public BQ_OnPluginStart()
{
	AddCommandListener(Say_Callback, 	 "say");
	AddCommandListener(TeamSay_Callback, "say_team");

	//Server CVar
	HookEvent("server_cvar", 		Event_ServerDontNeedPrint, 	EventHookMode_Pre);
	HookEvent("player_changename", 	Event_NameDontNeedPrint, 	EventHookMode_Pre);
	
	hCvarCvarChange 	= CreateConVar("bq_cvar_change_suppress", "1", "Silence Server Cvars being changed.");
	hCvarNameChange 	= CreateConVar("bq_name_change_suppress", "1", "Silence Player name Changes.");
	hCvarSpecNameChange = CreateConVar("bq_name_change_spec_suppress", "1", "Silence Spectating Player name Changes.");
	hCvarShowSpecsChat 	= CreateConVar("bq_show_player_team_chat_spec", "1", "Show Spectators what Players are saying in team chat.");
}

public Action:Say_Callback(client, const String:command[], argc)
{
	decl String:sayWord[144];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	
	if(!client) // Console
	{
		StripQuotes(sayWord);
		CPrintToChatAll("{olive}%s {default}: {green}%s", hostfile, sayWord);
		return Plugin_Handled;
	}
	
	if(IsGenericAdmin(client))
	{
		StripQuotes(sayWord);
		CPrintToChatAllEx(client, "{teamcolor}%N {default}: {green}%s", client, sayWord);
		PrintToServer("(ADMIN)%N : %s", client, sayWord);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:TeamSay_Callback(client, const String:command[], argc)
{
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	if (GetConVarBool(hCvarShowSpecsChat) && !IsSpectator(client))
	{
		decl String:sChat[256];
		GetCmdArgString(sChat, sizeof(sChat));
		StripQuotes(sChat);
		for(new i = 1; i <= MaxClients; i++)
		{
			if (IsSpectator(i))
			{
				if (GetClientTeam(client) == TEAM_SURVIVORS)
				{
					CPrintToChat(i, "{default}(Survivor){blue}%N {default}: %s", client, sChat);
				}
				else{
					CPrintToChat(i, "{default}(Infected){red}%N {default}: %s", client, sChat);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_ServerDontNeedPrint(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarBool(hCvarCvarChange))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Event_NameDontNeedPrint(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetConVarBool(hCvarNameChange))
		return Plugin_Handled;
	if(IsSpectator(client) && GetConVarBool(hCvarSpecNameChange))
		return Plugin_Handled;
	return Plugin_Continue;
}