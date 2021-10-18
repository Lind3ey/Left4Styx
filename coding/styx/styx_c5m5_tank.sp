#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

public Plugin:myinfo = 
{
	name = "Styx Bridge Tank.", 
	author = "Lind3ey", 
	description = "just for coop...", 
	version = "2.0", 
	url = ""
};

static bool:isBridge = false;
static bool:isFirst	= true;

public OnPluginStart()
{
	HookEvent("player_spawn", 			OnPlayerSpawn, 			EventHookMode_Post);
	
	HookEvent("round_start",			EventRound,			EventHookMode_PostNoCopy);
}

public OnMapStart()
{
    decl String:mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    if(StrEqual(mapname, "c5m5_bridge"))
    {
        isBridge = true;
    }
    else
    {
        isBridge = false;
    }
}

public Action:EventRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	isFirst = true;
}

public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) 
{
	if(!isBridge) return Plugin_Handled;
	if(!isFirst) return Plugin_Handled;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsFakeClient(client) && IsPlayerAlive(client))
	{
		isFirst = false;
		new Float:vector[3] = {-9965.6, 6256.6, 482.0};
		L4D2_SpawnTank(vector, Float:{0.0, 0.0, 0.0});
		PrintToServer("Spawned BRIDGE TANK.");
	}
	return Plugin_Handled;
}