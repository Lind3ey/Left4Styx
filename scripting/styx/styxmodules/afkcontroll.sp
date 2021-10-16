#pragma semicolon 1

#include <sourcemod>

#define		CoolTime		1.5

static InCoolDownTime[MAXPLAYERS+1] = false;
static Handle: hCvarNoIDLE;

public NAG_OnPluginStart()
{
	AddCommandListener(JoinTeam, "jointeam");
	AddCommandListener(CmdIDLE, "go_away_from_keyboard");
	
	hCvarNoIDLE = CreateConVar("sm_no_idle", "1", "No idle", FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	HookEvent("player_bot_replace", OnPlayerBotReplace);
}

public NAG_OnClientPostAdminCheck(client)
{
	InCoolDownTime[client] = false;
}

//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action:OnPlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"));
	InCoolDownTime[client] = true;
	CreateTimer(CoolTime, Timer_CanJoin, client);
}

public NAG_OnRoundStart()
{	// Reset.
	for(new i = MAXPLAYERS; i >= 0; i--)
	{
		InCoolDownTime[i] = false;
	}
}

public Action:JoinTeam(client, const String:command[], argc)
{
	if(InCoolDownTime[client])
	{
		PrintHintText(client, "Wait a moment before next join team.");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:CmdIDLE(client, const String:command[], args)
{
	if(GetConVarBool(hCvarNoIDLE))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Timer_CanJoin(Handle:timer, client)
{
	InCoolDownTime[client] = false;
}