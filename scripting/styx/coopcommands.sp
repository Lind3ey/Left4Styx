#pragma semicolon 1
#include <colors>
#include <left4dhooks>
#include <styxutils>

#undef REQUIRE_PLUGIN
#include <readyup>

new bool:readyUpIsAvailable;

public Plugin:myinfo = 
{
	name = "Styx Coop Commands.", 
	author = "Lind3ey", 
	description = "Pimpernel base commands: away...", 
	version = "1.0", 
	url = ""
};

public OnPluginStart()
{	
	// Common commands
	RegConsoleCmd("sm_away", 	Cmd_TurnToSpectate,	"Turn player to spectate.");
	RegConsoleCmd("sm_spec", 	Cmd_TurnToSpectate,	"Turn player to spectate.");
	RegConsoleCmd("sm_bot", 	Cmd_ComeBots,		"Call bots");
	RegConsoleCmd("sm_join", 	Cmd_TurnToGame, 	"Turn player to game.");
	//RegConsoleCmd("sm_styxrestart", Cmd_Restart,	"Restart");
	
	// Even spam
	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
}

public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

#define 	rstart_Delay		3.0
public Action:Cmd_Restart(client,args)
{
	CreateTimer(rstart_Delay, Timer_RestartRound, _, TIMER_FLAG_NO_MAPCHANGE);
	CPrintToChatAll("{green}✔ {red}Chapter will restart in 5 seconds.");
}

public Action:Timer_RestartRound(Handle:timer)
{
	decl String:sBuffer[32];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	PrintToServer("============= Restart current map: %s ================", sBuffer);
	L4D_RestartScenarioFromVote(sBuffer);
	// CreateTimer(_round_check_delay_, Timer_CheckFirstRound, _, TIMER_FLAG_NO_MAPCHANGE); //Map Restart in 2 seconds
	return Plugin_Stop;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}

public OnMapStart()
{
	if(L4D_IsFirstMapInScenario())
	{ 
		SetSlots(FindConVar("survivor_limit").IntValue); 
	}
}

public Action: Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){ DeActiveRound();}
public Action: L4D_OnFirstSurvivorLeftSafeArea(client) {if(!readyUpIsAvailable){ ActiveRound();} }
public OnLeftSafeArea(){ ActiveRound(); }

/***********************************************************************
************************* Cmd ********************************
************************************************************************/

public Action:Cmd_TurnToSpectate(client, args)
{
	if(!client || !IsClientInGame(client)) return Plugin_Handled;
	if(GetClientTeam(client) == TEAM_SPECTATORS) return Plugin_Handled;
	
	ChangeClientTeam(client, TEAM_SPECTATORS);
	PrintToChatAll("\x01%N has become a spectator.", client);
	return Plugin_Handled;
}

public Action:Cmd_TurnToGame(client, args)
{ 
	if(GetClientTeam(client) != TEAM_SPECTATORS) return Plugin_Handled;
	ClientCommand(client, "jointeam 2");
	return Plugin_Handled;
}

public Action:Cmd_ComeBots(client, args)
{
	if(GetClientTeam(client) == TEAM_SURVIVORS && IsPlayerAlive(client) && !IsHangingFromLedge(client))
		ComeBots(client);
	return Plugin_Handled;
}

public Action:ActiveRound()
{
	SetConVarInt(FindConVar("god"),0);
	SetConVarInt(FindConVar("sv_infinite_ammo"),0);
	PrintToServer("================ Player left safe area, round alive. =======================");
	return Plugin_Handled;
}

public Action:DeActiveRound()
{
	SetConVarInt(FindConVar("god"),1);
	SetConVarInt(FindConVar("sv_infinite_ammo"),1);
	return Plugin_Handled;
}

public OnPluginEnd()
{
	// Reset fucked cvars.
	ResetConVar(FindConVar("god"));
	ResetConVar(FindConVar("sv_infinite_ammo"));
}