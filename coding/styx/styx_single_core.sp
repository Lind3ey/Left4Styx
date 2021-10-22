/************************************
** 1. For single player(survivor) game: auto revive, starting melee, cancel getup.
** 2. For multiplayer, auto healing, auto revive when team pinned.
** 3. Heal after crowning witch.
**************************/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>

#include "styxutils"

#pragma newdecls required
#define 	HEAL_PERKILL			2
#define		CUT_DAMAGE				250.0		// z_gas_health
#define		Z_HUNTER_DMG			20.0
#define		Z_CHARGER_DMG			25.0
#define		Z_JOCKEY_DMG			20.0
#define		Z_SMOKER_DMG			16.0

#define 	Report_Interval			90

#define		Pinned_Check_Delay		0.25
#define 	Smoker_Delay			1.20
#define 	Delay_Blind_Time 		0.40

#define 	AUTOHEALMAXHEALTH	42		//Survivor health lower than this gets heal
#define 	HEAL_INTERVAL		1.0
#define 	SLAY_COUNTDOWN		3
#define		LOG_FILE			"addons/sourcemod/logs/styx.log"

//Timer
static Handle TimerChecking = INVALID_HANDLE;

// Game ConVars
ConVar
	CvarHealLmt,
	CvarSurvivorLimit,
	CvarAutoHealRate,
	CvarWitchCrownHeal;

static bool 
	btimerstarted				= false,
	bStatsCleared				= false;

static int
	survivor_limit      		= 4,
	survivor_autoheal_limit		= 2,
	// Flags
	imobilisedChecking			= SLAY_COUNTDOWN,
	iPlayerStats[4][2],
	sum_checking_ticks			= 0,
	total_heal					= 0;
	
static float survivor_autoheal_rate	= 0.54;

char hostfile[16] = "Styx";

#define RESETFLAGS	imobilisedChecking = SLAY_COUNTDOWN; sum_checking_ticks	= 0; total_heal = 0;

// Internal array of strings for timer ability timer entity classnames
static const char InfectedClassName[9][] = {
	"Infected",
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Witch",
	"Tank"
};

public Plugin myinfo = 
{
	name = "Styx Single Core", 
	author = "Lind3ey", 
	description = "cap and health manager", 
	version = "21.8.11", 
	url = ""
};

public void OnPluginStart()
{	
	HookEvent("round_start", 			Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end", 				Event_RoundEnd,		EventHookMode_PostNoCopy);
	
	HookEvent("jockey_ride",			OnRide,				EventHookMode_Post);
	HookEvent("tongue_grab", 			OnGrab, 			EventHookMode_Post);
	HookEvent("lunge_pounce",			OnPounce,			EventHookMode_Post);
	HookEvent("charger_carry_start",	OnCharge,			EventHookMode_Post);
	HookEvent("charger_pummel_start",	OnPummel,			EventHookMode_Post);
	HookEvent("total_ammo_below_40",	OnAmmoUsed,			EventHookMode_Post);
	
	HookEvent("player_death", 			OnDeath, 			EventHookMode_Post);
	
	// Cvarnbblind 		= FindConVar("nb_blind");
	CvarSurvivorLimit 	= FindConVar("survivor_limit");

	CvarHealLmt 		= CreateConVar("survivor_autoheal_limit",	"4",	"equal or less, survivors auto heal.", 	FCVAR_SPONLY, true, 0.0, true, 4.0);
	CvarAutoHealRate	= CreateConVar("survivor_autoheal_rate",	"0.667",	"Auto heal per second.", 	FCVAR_SPONLY, true, 0.0, true, 100.0);
	CvarWitchCrownHeal	= CreateConVar("st_witchcrown_heal", 		"15", "How much healing survivor when crown a witch.");

	survivor_limit				= CvarSurvivorLimit.IntValue;
	survivor_autoheal_limit 	= CvarHealLmt.IntValue;
	survivor_autoheal_rate		= CvarAutoHealRate.FloatValue;

	HookConVarChange(CvarSurvivorLimit, Cvar_SurvivorLimit);
	HookConVarChange(CvarHealLmt, 		Cvar_AutoHealLmt);
	HookConVarChange(CvarAutoHealRate, 	Cvar_AutoHealRate);
}

public void Cvar_SurvivorLimit(Handle convar, const char[] oldValue, const char[] newValue){ survivor_limit = StringToInt(newValue);}

public void Cvar_AutoHealLmt(Handle convar, const char[] oldValue, const char[] newValue){ survivor_autoheal_limit = StringToInt(newValue);}

public void Cvar_AutoHealRate(Handle convar, const char[] oldValue, const char[] newValue){ survivor_autoheal_rate = StringToFloat(newValue);}

public void OnMapStart()
{
	btimerstarted = false;
	GetConVarString(FindConVar("hostfile"), hostfile, sizeof(hostfile));
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Cvarnbblind.SetBool(false);
	ClearKDstats();
	bStatsCleared = true;
	RESETFLAGS

	if(btimerstarted && TimerChecking != INVALID_HANDLE)
	{
		btimerstarted = false;
		CloseHandle(TimerChecking);
		TimerChecking 	= INVALID_HANDLE;
	}
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{	
	if(sum_checking_ticks > (1<<6))
		PrintToServer("[Styx] total heal valume this round: %d", total_heal);
	RESETFLAGS
	if(survivor_limit != 1 || bStatsCleared) 
		return Plugin_Handled;
	// SinglePlayerGame
	CreateTimer(0.1, Timer_ReportStats, true, TIMER_FLAG_NO_MAPCHANGE);
	bStatsCleared = true;
	return Plugin_Handled;
}

public void OnLeftSafeArea()
{	
	ClearKDstats();
	bStatsCleared = true;
	RESETFLAGS
	TimerChecking = CreateTimer(HEAL_INTERVAL, Timer_CheckHeal, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	btimerstarted = true;
}

public Action OnDeath(Handle event, const char[] name, bool dontBroadcast)
{

	int victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker 	= GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!IsClientAndInGame(victim) || !IsClientAndInGame(attacker)) return Plugin_Handled;    	// safeguard
	if (!IsInfected(victim) || !IsSurvivor(attacker)) return Plugin_Handled;     				// safeguard

	if(survivor_limit <= survivor_autoheal_limit)
		HealSurvivor(attacker);
	
	if(survivor_limit != 1) return Plugin_Handled;
	// Single game
	int zombieClass = GetInfectedClass(victim);
	StatsHandle(zombieClass, true);
	return Plugin_Handled;
}

public Action OnPounce(Handle event, const char[] name, bool dontBroadcast)
{	
	if(survivor_limit != 1) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));	
	int victim	= GetClientOfUserId(GetEventInt(event, "victim"));
	
	FreezeInfected(Delay_Blind_Time);
	HandleCap(attacker, victim, ZC_Hunter);
	CancelGetup(victim);
	return Plugin_Handled;
}

public Action OnPummel(Handle event, const char[] name, bool dontBroadcast)
{
	if(survivor_limit != 1) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	int victim	= GetClientOfUserId(GetEventInt(event, "victim"));
	
	FreezeInfected(Delay_Blind_Time);
	HandleCap(attacker, victim, ZC_Charger);
	CancelGetup(victim);
	return Plugin_Handled;
}

public Action OnCharge(Handle event, const char[] name, bool dontBroadcast)
{
	if(survivor_limit != 1) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(Pinned_Check_Delay, Delay_CheckCap, attacker, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action OnGrab(Handle event, const char[] name, bool dontBroadcast)
{
	if(survivor_limit != 1) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(Smoker_Delay, Delay_CheckCap, attacker, TIMER_FLAG_NO_MAPCHANGE);
	FreezeInfected(Smoker_Delay);
	return Plugin_Handled;
}

public Action OnRide(Handle event, const char[] name, bool dontBroadcast)
{
	if(survivor_limit != 1) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(Pinned_Check_Delay, Delay_CheckCap, attacker, TIMER_FLAG_NO_MAPCHANGE);
	FreezeInfected(Delay_Blind_Time);
	return Plugin_Handled;
}

public Action OnAmmoUsed(Handle event, const char[] name, bool dontBroadcast)
{
	if(survivor_limit > 1) return Plugin_Handled;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	CheatGivePlayer(client, "ammo");
	// PrintHintText(client, "Ammo auto Refilled.");
	return Plugin_Handled;
}

public void OnTongueCut(int survivor, int smoker)
{
	if(survivor_limit != 1) return;

	InfectedHurt(smoker, survivor, CUT_DAMAGE);
	CreateTimer(0.1, timerUnfreezeInfected, _, TIMER_FLAG_NO_MAPCHANGE);
	return;
}

Action Delay_CheckCap(Handle timer, int attacker)
{
	if(IsPlayerAlive(attacker))
	{
		int victim = GetVictim(attacker);
		if(victim > 0)
		{
			int zombieClass = GetInfectedClass(attacker);
			HandleCap(attacker, victim, zombieClass);
		}
	}
}

void HandleCap(int attacker, int victim, int zc)
{
	float damage = Z_HUNTER_DMG;
	switch(zc)
	{
		case ZC_Charger: damage = Z_CHARGER_DMG;
		case ZC_Jockey:  damage = Z_JOCKEY_DMG;
		case ZC_Smoker: damage = Z_SMOKER_DMG;
	}
	// Damage survivors as the infected.
	SurvivorHurt(victim, attacker, damage);
	SlayAndReportInfected(attacker);
	StatsHandle(zc, false);
	RefillPrimaryClip(victim);
}

#define 	Cancel_Delay			0.142
void CancelGetup(int client)
{
	CreateTimer(Cancel_Delay, DelayCancelGetup, client, TIMER_FLAG_NO_MAPCHANGE);
}

// Gets players out of pending animations, i.e. sets their current frame in the animation to 1000.
public Action DelayCancelGetup(Handle timer, any client) 
{
	if (!IsSurvivor(client)) return Plugin_Stop;

	SetEntPropFloat(client, Prop_Send, "m_flCycle", 1.0);
	return Plugin_Stop;
}

public Action FreezeInfected(float time)
{
	CreateTimer(time, timerUnfreezeInfected, _, TIMER_FLAG_NO_MAPCHANGE);
	// Hard si made sis continue move even if blind.
	_allclients(i)
	{
		if(IsBotInfected(i) && IsPlayerAlive(i))
		{
			SetEntityMoveType(i, MOVETYPE_NONE);
		}
	}
}

public Action timerUnfreezeInfected(Handle timer)
{
	_allclients(i)
	{
		if(IsBotInfected(i) && IsPlayerAlive(i))
		{
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}
}

void StatsHandle(int zc, bool killed)
{
	int index = 1;
	int zcindex = 2;
	
	if(killed) index = 0;
	switch (zc)
	{
		case ZC_Hunter: zcindex = 0;
		case ZC_Jockey: zcindex = 1;
		default:					 zcindex = 2;
	}
	
	iPlayerStats[zcindex][index]++;
}

public Action Timer_CheckHeal(Handle timer)
{
	sum_checking_ticks++; 
	if(!L4D_HasAnySurvivorLeftSafeArea()) 
	{
		btimerstarted = false;
		sum_checking_ticks = 0;
		PrintToServer("!L4D_HasAnySurvivorLeftSafeArea, stopped.");
		return Plugin_Stop;
	}
	if(survivor_limit == 1 && sum_checking_ticks % Report_Interval == 0)
	{
		ReportStats();
	} else if(survivor_limit > 1)
	{	// PrintToServer("Checking Immosed."); // Auto slayer.
		CheckImmosed();
	}

	if(survivor_limit > survivor_autoheal_limit)
	{
		return Plugin_Continue;
	}

	// Auto Healing
	int	healvalume 	= RoundToFloor(sum_checking_ticks * survivor_autoheal_rate) 
					- RoundToFloor((sum_checking_ticks - 1) * survivor_autoheal_rate);
	if (healvalume < 1 || imobilisedChecking != SLAY_COUNTDOWN) 
		return Plugin_Continue;
	
	_forall(client)
	{
		if(IsClientInGame(client) && IsMobile(client) && GetClientHealth(client) < AUTOHEALMAXHEALTH)
		{
			HealSurvivor(client, healvalume);
			total_heal+=healvalume;
		}
	}
	return Plugin_Continue;
}

Action ReportStats(bool Save = false)
{
	AddupKDStats();
	
	if(iPlayerStats[3][0] == 0 && iPlayerStats[3][1] == 0) return Plugin_Stop;
	
	int player = FindSurvivorPlayer();
	if(!IsClientAndInGame(player)) return Plugin_Continue;
	
	float KC = float(iPlayerStats[3][0]) / float(MAX(iPlayerStats[3][1], 1));
	
	char data[256];
	Format(data, sizeof(data), "{blue}%d{default}/%d    {blue}%d{default}/%d    {blue}%d{default}/%d    {blue}%d{default}/%d",
		iPlayerStats[0][0],iPlayerStats[0][1],
		iPlayerStats[1][0],iPlayerStats[1][1],
		iPlayerStats[2][0],iPlayerStats[2][1],
		iPlayerStats[3][0],iPlayerStats[3][1]);
	
	CPrintToChatAllEx(player, "{green}%s{default} Player {teamcolor}%N{default}'s stats[{green}%.2f{default}]:",(KC>=3? "★★★":(KC>=2?"★★":"★")), player, KC);
	CPrintToChatAll( "{green}∯ {blue}Specials: {green}Hunter   Jockey    Others   All" );
	CPrintToChatAll("{green}∯ {blue}Kill{green}/Capped: %s", data);
	
	if(Save)
	{	
		LogStats(player);
		ClearKDstats();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

Action Timer_ReportStats(Handle timer, bool Save)
{
	return ReportStats(Save);
}

void ClearKDstats()
{
	for(int i=0; i<4; i++)
	{
		iPlayerStats[i][0] = 0;
		iPlayerStats[i][1] = 0;
	}
}

void AddupKDStats()
{
	iPlayerStats[3][0]=0;iPlayerStats[3][1]=0;
	
	for(int i=0; i<3; i++)
	{
		iPlayerStats[3][0] += iPlayerStats[i][0];
		iPlayerStats[3][1] += iPlayerStats[i][1];
	}
}

void LogStats(int player)
{	
	AddupKDStats();
	if(!IsFakeClient(player) && iPlayerStats[3][0] > 30)
	{
		char sBuffer[32], sCurmap[32];
		GetClientAuthId(player,AuthId_Steam2, sBuffer, sizeof(sBuffer));
		GetCurrentMap(sCurmap, sizeof(sCurmap));
		LogToFile(LOG_FILE, "===============================================");
		LogToFile(LOG_FILE, "Player: %N <%s> ", player, sBuffer);
		LogToFile(LOG_FILE, "Map: %s ", sCurmap);
		LogToFile(LOG_FILE, "Round stats: %d / %d", iPlayerStats[3][0], iPlayerStats[3][1]);
	}
}

#define seconds 5.0
void SlayAndReportInfected(int client)
{
	int health = GetClientHealth(client);
	int zc = GetInfectedClass(client);
	CPrintToChatAll("{green}∰ {red}%N{default}({olive}%s{default}) has {green}%d {default}health remaining.", client, InfectedClassName[zc], health);
	IgniteEntity(client, seconds);
	ForcePlayerSuicide(client);
	ClearZombieAround(client);
}

public void OnWitchDrawCrown(int attacker,int damage, int chipdamage)
{
	OnWitchCrown(attacker, damage);
}

public void OnWitchCrown(int attacker, int damage)
{
	int st_witchcrown_heal = GetConVarInt(CvarWitchCrownHeal);
	if(st_witchcrown_heal > 0)
		HealSurvivor(attacker, st_witchcrown_heal);
}

#define 	MAX_HEALTH	100
void HealSurvivor(int client, int heals = HEAL_PERKILL)
{
	if(!client || !IsClientInGame(client) || !IsSurvivor(client))
		return;
	int health =GetEntProp(client, Prop_Send, "m_iHealth") + heals;
	SetEntProp(client, Prop_Send, "m_iHealth", MIN(health, MAX_HEALTH));
}

int FindSurvivorPlayer()
{
	_allclients(i)
	{
		if(IsSurvivor(i))
			return i;
	}
	return -1;
}

void SurvivorHurt(int client, int attacker, float damage)
{
	SDKHooks_TakeDamage(client, attacker, attacker, damage, DMG_SHOCK);
	EmitGameSoundToClient(client, "HunterZombie.Pounce.Hit", SOUND_FROM_PLAYER, SND_NOFLAGS);
}

void InfectedHurt(int client, int attacker, float damage)
{
	SDKHooks_TakeDamage(client, attacker, attacker, damage, DMG_SLASH);
}

stock Action Timer_ClearZombieAround(Handle timer, int client)
{
	if(IsSurvivor(client))
		ClearZombieAround(client);
}

static void ClearZombieAround(int client, float range = 420.0)
{
	int entcount = GetEntityCount();
	char sBuffer[32];
	for( int entity = entcount; entity > 0; entity--)
	{	
		if(IsValidClient(entity) && IsValidEntity(entity))
		{
			if(GetDistance(client, entity) < range - 42.0)
			{
				IgniteEntity(entity, seconds);
				continue;
			}
		}
		if(IsValidEntity(entity) && IsValidEdict(entity))
		{
			GetEdictClassname(entity, sBuffer, sizeof(sBuffer));
			if (StrEqual(sBuffer, "infected", false))
			{
				if(GetDistance(client, entity) < range)
				{
					IgniteEntity(entity, seconds);
				}
			}
		}
	}
}

void CheckImmosed()
{
	if(IsTeamImmobilised() && !IsTeamWiped())
	{
		PrintToChatAll("\x04%s #                        \x01[\x0400:%02d:00\x01]", hostfile, imobilisedChecking);
		if(--imobilisedChecking < 0)
		{
			SlaySpecialInfected();
			imobilisedChecking = SLAY_COUNTDOWN;
		}
	}
	else
		imobilisedChecking = SLAY_COUNTDOWN;
	return;
}

void SlaySpecialInfected() 
{	// Make damage before slay infected;
	_allclients(i)
	{
		if(!IsClientInGame(i)) continue;
		if(IsSurvivor(i) && IsPinned(i))
		{
			SurvivorHurt(i, i, Z_HUNTER_DMG);
		}
	}
	_allclients(i) 
	{
		if(!IsClientInGame(i)) continue;
		if(IsBotInfected(i) && IsPlayerAlive(i)) 
		{
			if(GetInfectedClass(i) != ZC_Tank) 
			{
				IgniteEntity(i, seconds);
				ForcePlayerSuicide(i);
				ClearZombieAround(i);
			} 
		}
	}
	CPrintToChatAll("{green}%s:                        {green}業 火", hostfile);
}