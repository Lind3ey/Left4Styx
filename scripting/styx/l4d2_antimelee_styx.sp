#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

new Handle:hCvarMeleeNerfPercentage;
new bool:lateLoad;
new Handle:hCvarSurvivorLimit;

public Plugin:myinfo =
{
	name = "L4D2 AntiMelee",
	description = "Nerfes melee damage against tanks by a set amount of %,  and balance 1 - 3 players tank dmg.",
	author = "Visor",
	version = "1.1",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax)
{
	lateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	hCvarMeleeNerfPercentage = CreateConVar("l4d2_melee_tank_nerf", "0", "Percentage of melee damage nerf against tank", FCVAR_CHEAT|FCVAR_NOTIFY, true, 0.0, true, 100.0);
	hCvarSurvivorLimit = FindConVar("survivor_limit");
	if (lateLoad)
	{
		for(new i=MaxClients;i>0;i--) 
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!IsSurvivor(attacker) || !IsTank(victim) || !IsMelee(weapon))
	{
		return Plugin_Continue;
	}
	damage = damage / GetConVarInt(hCvarSurvivorLimit) * 4.0;
	damage = damage / 100.0 * (100.0 - GetConVarFloat(hCvarMeleeNerfPercentage));
	return Plugin_Changed;
}

bool:IsMelee(entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		decl String:strClassName[64];
		GetEdictClassname(entity, strClassName, 64);
		return StrContains(strClassName, "melee", false) != -1;
	}
	return false;
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsTank(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass", 4, 0) == 8;
}

