#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <styxutils>

Handle	MaxSpecialsDuringTank,
		NoSpitterDuringTank,
		NoSpitterSpawnFirst,
		SpecialsLimit;

static	special_limit, 
		z_max_specials_during_tank;
static bool z_no_spitter_during_tank,
 			z_no_spitter_spawn_first,
 			bIsTankInPlay = false;

public Plugin:myinfo =
{
	name = "Styx Director During Tank",
	author = "Lind3ey",
	description = "to set max specials during tank, and no spitter spawn first btw",
	version = "2.1",
	url = ""
};

public OnPluginStart()
{
	MaxSpecialsDuringTank 	= CreateConVar("z_max_specials_during_tank", 	"-2", "minus limit if it leq 0", 	FCVAR_SPONLY);
	NoSpitterDuringTank 	= CreateConVar("z_no_spitter_during_tank", 		"1", "",	FCVAR_SPONLY, true, 0.0, true, 1.0);
	NoSpitterSpawnFirst		= CreateConVar("z_no_spitter_spawn_first", 		"1", "",	FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	SpecialsLimit = FindConVar("z_max_player_zombies");
	special_limit = GetConVarInt(SpecialsLimit);
	
	HookEvent("round_start",			EventRound,			EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",				EventTankSpawn, 	EventHookMode_PostNoCopy);
	HookEvent("player_death",			EventDeath,			EventHookMode_PostNoCopy);	
	
	UpdateConVars();
}

public Action:EventRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay = false;
	z_max_specials_during_tank = GetConVarInt(MaxSpecialsDuringTank);
	z_no_spitter_during_tank = GetConVarBool(NoSpitterDuringTank);
	z_no_spitter_spawn_first = GetConVarBool(NoSpitterSpawnFirst);
}

public Action:EventTankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!bIsTankInPlay)
	{
		bIsTankInPlay = true;
		UpdateConVars();
		PrintToServer("root# Tank has spawned, adjusted director's key values.");
	}
}

public UpdateConVars()
{
	z_max_specials_during_tank 	= GetConVarInt(MaxSpecialsDuringTank);
	z_no_spitter_during_tank 	= GetConVarBool(NoSpitterDuringTank);
	z_no_spitter_spawn_first 	= GetConVarBool(NoSpitterSpawnFirst);
	special_limit = GetConVarInt(SpecialsLimit);
}

public Action:EventDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bIsTankInPlay)
	{
        CreateTimer(0.1, Timer_CheckTank, _, TIMER_FLAG_NO_MAPCHANGE); // Use a delayed timer due to bugs where the tank passes to another player
	}
}

public Action:Timer_CheckTank(Handle:timer)
{
	if(!IsTankAlive())
	{
		bIsTankInPlay = false;
		PrintToServer("root# Tank has dead, restored director's key values.");
	}
}

public Action:L4D_OnGetScriptValueInt(const String:key[], &retVal)
{
	if(bIsTankInPlay && (StrEqual(key,"MaxSpecials") || StrEqual(key, "cm_MaxSpecials")))
	{
		retVal = z_max_specials_during_tank>0?z_max_specials_during_tank:z_max_specials_during_tank+special_limit;
		return Plugin_Handled;
	}
	if(StrEqual(key, "SpitterLimit"))
	{
		if(		(z_no_spitter_spawn_first && !FindChargerHunter())
			||	(z_no_spitter_during_tank && bIsTankInPlay))
			{
				retVal = 0;
				return Plugin_Handled;
			}
	}
	else if(StrEqual(key, "GasCansOnBacks") || StrEqual(key, "EscapeSpawnTanks"))
	{
		retVal = 0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:L4D_OnSpawnSpecial(&zombieClass, const Float:vector[3], const Float:qangle[3])
{
	if(zombieClass == ZC_Spitter)
	{
		if(bIsTankInPlay)
		{	
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

bool FindChargerHunter()
{
	for (new client = MaxClients; client > 0 ; client--)
	{
		if (!IsClientInGame(client) 
			|| !IsInfected(client)
			|| !IsPlayerAlive(client))
			continue;
		if(GetInfectedClass(client) == ZC_Charger || GetInfectedClass(client) == ZC_Hunter)
			return true;
	}
	return false;
}

