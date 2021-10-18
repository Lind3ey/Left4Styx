#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <styxutils>

#define Normal_Speed	1.0

ConVar 	hCvarAIladderboost,
		hCvarPzladderboost,
		hCvarBoostMultiper;

bool 	bAiSiLadderbooster,
	 	bPzSiLadderbooster;

float 	fBoostMultiper;

public Plugin myinfo = 
{
	name = "Styx Dummys LADDER BOOSTER",
	author = "Lind3ey",
	description = "",
	version = "2.3.3",
	url = "233"
};

public void OnPluginStart()
{
	hCvarAIladderboost = CreateConVar("l4d2_ai_ladder_boost", "1", "", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarPzladderboost = CreateConVar("l4d2_pz_ladder_boost", "0", "", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarBoostMultiper = CreateConVar("l4d2_boost_multi", "3.2", "", FCVAR_SPONLY, true, 0.0, true, 10.0);
	
	// RegConsoleCmd("sm_mtype", CMD_MTYPE);
	HookConVarChange(hCvarAIladderboost, Cvar_OneChanged);
	HookConVarChange(hCvarPzladderboost, Cvar_OneChanged);
	HookConVarChange(hCvarBoostMultiper, Cvar_OneChanged);
	
	Cvar_Changed();
}

public Cvar_OneChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{ 
	Cvar_Changed();
}

public Action:CMD_MTYPE(cmd, args)
{
	new tank = FindZombieByType(ZC_Tank);
	if(tank > 0)
	{
		MoveType wtype = GetEntityMoveType(tank);
		PrintToServer(" TANK MOVE TYPE %d", wtype);
	}
}

public Cvar_Changed()
{
	bAiSiLadderbooster = GetConVarBool(hCvarAIladderboost);
	bPzSiLadderbooster = GetConVarBool(hCvarPzladderboost);
	fBoostMultiper	   = GetConVarFloat(hCvarBoostMultiper);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsValidClient(client) && IsInfected(client) && IsPlayerAlive(client))
	{
		if(GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			// To make sure the SI is boosted only by this plugin.
			if(IsBotTank(client) && GetEntityMoveType(client) == MOVETYPE_CUSTOM && !IsIncapacitated(client))
			{
				// Tank climb boost
				if(0.133 < GetEntPropFloat(client, Prop_Send, "m_flCycle") < 0.399 )
					SetEntPropFloat(client, Prop_Send, "m_flCycle", 0.40);
				else if(0.633 < GetEntPropFloat(client, Prop_Send, "m_flCycle") < 0.899 )
					SetEntPropFloat(client, Prop_Send, "m_flCycle", 0.90);
			}
			else if(GetClientSpeed(client) == fBoostMultiper){ SetClientSpeed(client, Normal_Speed); }
			return Plugin_Continue;
		}
		
		if(bAiSiLadderbooster && IsFakeClient(client))
		{		
			SetClientSpeed(client, fBoostMultiper);
			return Plugin_Continue;
		}
		
		if(bPzSiLadderbooster && !IsFakeClient(client) && !IsGhost(client))
		{
			SetClientSpeed(client, fBoostMultiper);
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}