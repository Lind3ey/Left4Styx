#pragma semicolon 1

#define DEBUG 0
#include <sourcemod>
#include <sdktools>
#include <adt_array>
#include <left4dhooks>
#include <styxutils>


public Plugin:myinfo = 
{
	name = "Styx dummys: Targeting",
	author = "Lind3ey",
	description = "Controls the survivor targeting behaviour of special infected",
	version = "8.11",
	url = ""
};

public OnPluginStart() {
	
	// Assigning targets to spawned infected
	HookEvent("player_spawn", 			OnPlayerSpawn, 			EventHookMode_Post);
	
	HookEvent("charger_carry_start",	OnStrongCap,			EventHookMode_Post);
	HookEvent("lunge_pounce",			OnStrongCap,			EventHookMode_Post);
	HookEvent("charger_pummel_start",	OnStrongCap,			EventHookMode_Post);
	
	HookEvent("tongue_pull_stopped",	OnTongueRes,			EventHookMode_Post);
	HookEvent("player_incapacitated",	OnIncap,			EventHookMode_Post);
	// CreateTimer(_refresh_tick_, Repeat_Refresh, _, TIMER_REPEAT);
}

/***********************************************************************************************************************************************************************************

																		UPDATING VALID SURVIVOR TARGETS

***********************************************************************************************************************************************************************************/

int GetAFreeSurvivor()
{
	int client = -1;
	bool drct =bool:GetRandomInt(0,1);
	_allclients(i)
	{
		client = drct?i:MaxClients-i+1;
		if(IsValidClient(client) && IsMobile(client))
		{
			return client;
		}
	}
	return -1;
}

int GetAFreeSurvivorEx(cexcept)
{
	int client = -1;
	bool drct =bool:GetRandomInt(0,1);
	_allclients(i)
	{
		client = drct?i:MaxClients-i+1;
		if(client != cexcept && IsValidClient(client) && IsMobile(client))
		{
			return client;
		}
	}
	return -1;
}

/***********************************************************************************************************************************************************************************

																	EXECUTING AI TARGET PREFERENCING

***********************************************************************************************************************************************************************************/

// Assign target to any cappers(smoker, hunter, jockey charger) that spawn
public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsBotInfected(client) && IsPlayerAlive(client))
	{
		new zombieclass = GetInfectedClass(client);
		if(zombieclass == ZC_Spitter)
		{
			if(!FindZombieByType(ZC_Hunter) && !FindZombieByType(ZC_Charger))
			{
				CmdBotRetreat(client);
				BlockAbility(client, 5.0);
			}
		}
		else if(zombieclass == ZC_Charger || zombieclass == ZC_Hunter)
		{
			new spitter = FindZombieByType(ZC_Spitter);
			if(spitter > 0 && IsFakeClient(spitter))
			{
				CmdBotReset(spitter);
			}
		}
		else if(zombieclass == ZC_Tank)
		{
			new spitter = FindZombieByType(ZC_Spitter);
			if(spitter > 0 && IsFakeClient(spitter))
			{
				new target = GetAFreeSurvivor();
				if(target > 0){
					CmdBotAttack(spitter, target);
					}
			}
		}
	}
}

void BlockAbility(bot, float time = 3.0) 
{
	new abEntity = GetEntPropEnt(bot, Prop_Send, "m_customAbility");
	if (abEntity > 0) 
	{
		SetEntPropFloat(abEntity, Prop_Send, "m_timestamp", GetGameTime() + time); 
	} 			
}

public Action:OnTongueRes(Handle:event, String:name[], bool:dontBroadcast) 
{
	new smoker = GetClientOfUserId(GetEventInt(event, "smoker"));
	if(IsClientAndInGame(smoker) && IsFakeClient(smoker) && IsPlayerAlive(smoker))
	{
		CmdBotRetreat(smoker);
	}
}

stock void RefreshTarget(client)
{
	new target = GetAFreeSurvivor();
	if(target > 0)
	{
		CmdBotAttack(client, target);
	}
}

void RefreshTargetEx(client, cexcept)
{
	new target = GetAFreeSurvivorEx(cexcept);
	if(target > 0)
	{
		CmdBotAttack(client, target);
	}
}

public Action:OnStrongCap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim	= GetClientOfUserId(GetEventInt(event, "victim"));
	new spitter = FindZombieByType(ZC_Spitter);
	
	if (spitter > 0)
	{
		if(GetAbilityTime(spitter) < 5.0)
		{
			BlockAbility(spitter, 0.0);
		}
		CmdBotAttack(spitter, victim);
	}
	
	_allclients(i)
	{
		if(i != attacker && IsClientInGame(i) && (IsBotCapper(i) || IsBotTank(i)))
		{
			RefreshTargetEx(i, victim);
		}
	}
}

public Action:OnIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker 	= GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim		= GetClientOfUserId(GetEventInt(event, "victim"));
	if(IsBotInfected(attacker)) {
		RefreshTargetEx(attacker, victim);
	}
}
