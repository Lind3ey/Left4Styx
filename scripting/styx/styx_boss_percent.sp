#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#define REQUIRE_PLUGIN
#include <readyup>

#define MIN(%0,%1) (((%0) > (%1)) ? (%1) : (%0))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin myinfo =
{
	name = "Styx Boss Percent",
	author = "Spoon, Forgetest, Lind3ey",
	version = "1.6.1._styx",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

int iWitchPercent = 0,
	iTankPercent = 0;

Handle g_hVsBossBuffer;
ConVar 	hCvarPrintToEveryone,
		hCvarTankPercent,
		hCvarWitchPercent;
bool 	readyUpIsAvailable,
		readyFooterAdded;

public APLRes AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	MarkNativeAsOptional("AddStringToReadyFooter");
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	
	hCvarPrintToEveryone = CreateConVar("l4d_global_percent", "1", "Display boss percentages to entire team when using commands", FCVAR_SPONLY);
	hCvarTankPercent = CreateConVar("l4d_tank_percent", "1", "Display Tank flow percentage in chat", FCVAR_SPONLY);
	hCvarWitchPercent = CreateConVar("l4d_witch_percent", "0", "Display Witch flow percentage in chat", FCVAR_SPONLY);

	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_cur", CurrentCmd);
	
	AddCommandListener(Cmd_SetBoss, 		"sm_settank");
	AddCommandListener(Cmd_SetBoss, 		"sm_setwitch");

	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
}

public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}

public Action:Cmd_SetBoss(client, const String:command[], args)
{
	CreateTimer(0.5, SaveBossFlows);
	return Plugin_Continue;
}

public OnRoundIsLive()
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client))
			PrintBossPercents(client);
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	readyFooterAdded = false;
	CreateTimer(5.0, SaveBossFlows);
	CreateTimer(6.0, AddReadyFooter); // workaround for boss equalizer
}

public Native_UpdateBossPercents(Handle:plugin, numParams)
{
	CreateTimer(0.1, SaveBossFlows);
	CreateTimer(0.2, AddReadyFooter);
	return true;
}

public Action:SaveBossFlows(Handle:timer)
{
	iWitchPercent = 0;
	iTankPercent = 0;
	if (L4D2Direct_GetVSWitchToSpawnThisRound(1))
	{
		iWitchPercent = RoundToNearest(GetWitchFlow(0)*100.0);
	}
	if (L4D2Direct_GetVSTankToSpawnThisRound(1))
	{
		iTankPercent = RoundToNearest(GetTankFlow(0)*100.0);
	}
}

public Action:AddReadyFooter(Handle:timer)
{
	if (readyFooterAdded) return;
	if (readyUpIsAvailable)
	{
		decl String:readyString[65];
		if (GetConVarBool(hCvarTankPercent) && GetConVarBool(hCvarWitchPercent) && iWitchPercent && iTankPercent)
			Format(readyString, sizeof(readyString), "->Round: %s, Tank: %d%%, Witch: %d%%",(InSecondHalfOfRound()?"2nd":"1st"), iTankPercent, iWitchPercent);
		else if (GetConVarBool(hCvarTankPercent) && iTankPercent)
			Format(readyString, sizeof(readyString), "->Round: %s, Tank Spawn: %d%%",(InSecondHalfOfRound()?"2nd":"1st"), iTankPercent);
		else if (GetConVarBool(hCvarWitchPercent) && iWitchPercent)
			Format(readyString, sizeof(readyString), "->Round: %s, Tank: --, Witch: %d%%",(InSecondHalfOfRound()?"2nd":"1st"), iWitchPercent);
		else
		{
			readyFooterAdded = true;
			return;	
		}
		readyFooterAdded = true;
		AddStringToReadyFooter(readyString);
	}
}

stock PrintBossPercents(client)
{
	if(GetConVarBool(hCvarTankPercent))
	{
		if (iTankPercent)
			CPrintToChat(client, "{green}# {default}${green}Tank.Spawn {default}= {red}%2d{default}%%", iTankPercent);
		else
			CPrintToChat(client, "{green}# {default}${green}Tank.Spawn {default} = {red}UNKNOWN");
	}

	if(GetConVarBool(hCvarWitchPercent))
	{
		if (iWitchPercent)
			PrintToChat(client, "{green}# {default}${green}Witch Spawn {default}= {red}%2d{default}%%", iWitchPercent);
		else
			PrintToChat(client, "{default}<{olive}Witch: {red}--{olive}%%{default}>");
	}
}

public Action:BossCmd(client, args)
{
	if ( GetClientTeam(client) == 1)
	{
		PrintBossPercents(client);
		PrintCurPercents(client);
		return Plugin_Handled;
	}

	if (GetConVarBool(hCvarPrintToEveryone))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				PrintBossPercents(i);
				PrintCurPercents(i);
			}
		}
	}
	else
	{
		PrintBossPercents(client);
		PrintCurPercents(client);
	}

	return Plugin_Handled;
}

stock PrintCurPercents(client)
{
	new boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	CPrintToChat(client, "{default}< {blue}Current {default}@ {green}%2d{default}%% >", boss_proximity);
}


public Action:CurrentCmd(client, args)
{
	if (GetClientTeam(client) == 1)
	{
		PrintCurPercents(client);
		return Plugin_Handled;
	}
	
	if (GetConVarBool(hCvarPrintToEveryone))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				PrintCurPercents(i);
			}
		}
	}
	else
	{
		PrintCurPercents(client);
	}

	return Plugin_Handled;
}

stock Float:GetBossProximity()
{
	new Float:proximity = GetMaxSurvivorCompletion() + (GetConVarFloat(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	return MIN(proximity, 1.0);
}

stock Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			flow = MAX(flow, L4D2Direct_GetFlowDistance(i));
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client client ID
 * @return bool
 */
stock bool:IsSurvivor(client) {
    if (!IsClientInGame(client) || GetClientTeam(client) != 2) {
        return false;
    }
    return true;
}
/**
 * Returns true if it's the second half of round.
 *
 * @param client client ID
 * @return bool
 */
stock bool:InSecondHalfOfRound(){
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}
