#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <colors>

#define Z_JOCKEY 5
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar 
	z_leap_damage_interrupt,
	z_jockey_health,
	jockey_skeet_report;

float 
	jockeySkeetDmg,
	jockeyHealth,
	inflictedDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];

bool 
	reportJockeySkeets,
	lateLoad;

Handle
	g_hForwardSkeetJK,
	g_hForwardSkeetJKMelee;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateLoad = late;
	g_hForwardSkeetJK =      CreateGlobalForward("OnJockeySkeet", ET_Ignore, Param_Cell, Param_Cell );
	g_hForwardSkeetJKMelee =      CreateGlobalForward("OnJockeyMeleeSkeet", ET_Ignore, Param_Cell, Param_Cell );
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "L4D2 Jockey Skeet & Forward",
	author = "Visor, A1m`, Lind3ey",
	description = "A dream come true",
	version = "1.4",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	z_leap_damage_interrupt = CreateConVar("z_leap_damage_interrupt", "195.0", "Taking this much damage interrupts a leap attempt", _, true, 10.0, true, 325.0);
	jockey_skeet_report = CreateConVar("jockey_skeet_report", "0", "Report jockey skeets in chat?", _, true, 0.0, true, 1.0);
	z_jockey_health = FindConVar("z_jockey_health");

	if (lateLoad) {
		for (int i = MaxClients; i > 0 ; i--) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	jockeySkeetDmg = z_leap_damage_interrupt.FloatValue;
	reportJockeySkeets = jockey_skeet_report.BoolValue;
	jockeyHealth = z_jockey_health.FloatValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsJockey(victim) || !IsSurvivor(attacker) || IsFakeClient(attacker)) {
		return Plugin_Continue;
	}
	if (!HasJockeyTarget(victim) && IsAttachable(victim)) 
	{
		if (damagetype & DMG_SLASH || damagetype & DMG_CLUB )
		{
			if(damage >= jockeySkeetDmg && weapon != -1)
			{
				PushForwardMelee(attacker, victim);
				damage = jockeyHealth;
				return Plugin_Changed;
			}
		}
		else if(IsShotgun(weapon))
		{
			inflictedDamage[victim][attacker] += damage;
			if (inflictedDamage[victim][attacker] >= jockeySkeetDmg) {
				if (reportJockeySkeets) 
				{
					CPrintToChatAll("{green}★★{default} {olive}%N{default}'s Jockey was {blue}skeeted{default} by 	{olive}%N{default}.", victim, attacker);
				}
				PushForward(attacker, victim);
				damage = jockeyHealth;
				return Plugin_Changed;
			}
			CreateTimer(0.1, ResetDamageCounter, victim);
		}
	}
	return Plugin_Continue;	
}

public Action ResetDamageCounter(Handle hTimer, any jockey)
{
	for (int i=MaxClients;i>0;i--) {
		inflictedDamage[jockey][i] = 0.0;
	}
}

public void PushForward(int attacker, int jockey)
{
	Call_StartForward(g_hForwardSkeetJK);
	Call_PushCell(attacker);
	Call_PushCell(jockey);
	Call_Finish();
}

public void PushForwardMelee(int attacker, int jockey)
{
	Call_StartForward(g_hForwardSkeetJKMelee);
	Call_PushCell(attacker);
	Call_PushCell(jockey);
	Call_Finish();
}

bool IsSurvivor(int client)
{
	return (client > 0 
		&& client <= MaxClients 
		&& IsClientInGame(client) 
		&& GetClientTeam(client) == TEAM_SURVIVOR);
}

bool IsJockey(int client)
{
	return (client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == Z_JOCKEY
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1);
}

bool HasJockeyTarget(int infected)
{
	int client = GetEntPropEnt(infected, Prop_Send, "m_jockeyVictim");
	
	return (IsSurvivor(client) && IsPlayerAlive(client));
}

// A function conveniently named & implemented after the Jockey's ability of
// capping Survivors without actually using the ability itself.
bool IsAttachable(int jockey)
{
	return (!(GetEntityFlags(jockey) & FL_ONGROUND));
}

bool IsShotgun(int weapon)
{
	if (!IsValidEdict(weapon)) return false;
	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	return (StrEqual(classname, "weapon_pumpshotgun") || StrEqual(classname, "weapon_shotgun_chrome")
		/*|| StrEqual(classname, "weapon_autoshotgun") || StrEqual(classname, "weapon_shotgun_spas")*/); //visor code need?
}