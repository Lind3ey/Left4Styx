#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include "styxutils"

public Plugin:myinfo = 
{
	name = "Styx Skill Report ++",
	author = "Lind3ey",
	description = "Display Skeets/Etc to Chat to clients",
	version = "1.0",
	url = "<- URL ->"
}
new				g_iLastHealth[MAXPLAYERS + 1];

// Player temp stats
new				g_iDamageDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker
new				g_iShotsDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker, count # of shots (not pellets)

new		bool:	g_bShotCounted[MAXPLAYERS + 1][MAXPLAYERS +1];		// Victim - Attacker, used by playerhurt and weaponfired

new     Handle:         g_hForwardAirshoot                                     = INVALID_HANDLE;
new     Handle:         g_hForwardStopCharge                                 = INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    g_hForwardAirshoot =         CreateGlobalForward("OnAirShoot", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardStopCharge =       CreateGlobalForward("OnStopCharge", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    return APLRes_Success;
}


public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("weapon_fire", Event_WeaponFire);
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	_allclients(i)
	{
		// [Victim][Attacker]
		g_bShotCounted[i][client] = false;
	}
}

public Action:Event_AbilityUse(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsInfected(client) ) {
		_allclients(i)
		{
			g_iShotsDealt[client][i]=0;
			g_iShotsDealt[client][i]=0;
		}
	}
	return Plugin_Handled;
}

public OnMapStart()
{
	ClearMapStats();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	_allclients(i)
	{
		ClearDamage(i);
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	_allclients(i)
	{
		ClearDamage(i);
	}
}

#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 
#define DMG_STOP  	300
public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (!IsValidClient(attacker) || !IsValidClient(victim)) return;
	
	new damage = GetEventInt(event, "dmg_health");
	new damagetype = GetEventInt(event, "type");
	if ( damage < 1 ) { return; }

	if (IsSurvivor(attacker) && IsInfected(victim))
	{
		new zombieclass = GetInfectedClass(victim);
		if(zombieclass != ZC_Charger && zombieclass != ZC_Hunter) return;
		new remaining_health = GetEventInt(event, "health");
		
		if (zombieclass == ZC_Charger)
		{  
			if(IsCharging(victim))
			{
				if (!g_bShotCounted[victim][attacker])
				{
					g_iShotsDealt[victim][attacker]++;
					g_bShotCounted[victim][attacker] = true;
				}
				g_iDamageDealt[victim][attacker] += damage;
				//PrintToServer("charging +%ddamage, %dremainder", damage, remaining_health);
				// Let player_death handle remainder damage (avoid overkill damage)
				if (remaining_health <= 0) {
					new _damage = g_iDamageDealt[victim][attacker];
					new shots = g_iShotsDealt[victim][attacker];

					// PrintToServer("==> Stop charger: damage %d", _damage);
					if(!(damagetype&DMG_SLASH) && !(damagetype&DMG_CLUB) && _damage > DMG_STOP)
					{
						Call_StartForward(g_hForwardStopCharge);
						Call_PushCell(attacker);
						Call_PushCell(victim);
						Call_Finish();
						CPrintToChatAll("{green}★ {olive}%N {blue}stopped {green}%N{default}'s charging.({blue}%d {default}dmg, {blue}%d {default}shots)", attacker, victim, _damage, shots);
					}
					return;
				}
			}
		} else if(IsPouncing(victim)){ // zombieclass == ZC_Huner
			if (!g_bShotCounted[victim][attacker])
			{
				g_iShotsDealt[victim][attacker]++;
				g_bShotCounted[victim][attacker] = true;
			}
			g_iDamageDealt[victim][attacker] += damage;
			
			// PrintToServer("pouncing +%ddamage, %dremainder", damage, remaining_health);
			if (remaining_health <= 0) 
			{
				new _damage = g_iDamageDealt[victim][attacker];
				new shots = g_iShotsDealt[victim][attacker];

				if(damagetype&DMG_BULLET && !(damagetype&DMG_BUCKSHOT) && _damage > 149)
				{    
					Call_StartForward(g_hForwardAirshoot);
					Call_PushCell(attacker);
					Call_PushCell(victim);
					Call_Finish();
					CPrintToChatAll("{green}★★ {olive}%N {default}({blue}smg{default}){blue}airshotted {green}%N{default}({blue}%d {default}dmg, {blue}%d {default}shots)",attacker, victim, _damage, shots);
				}
				return;
			}
		}
		g_iLastHealth[victim] = remaining_health;
	}
	return;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim == 0 || !IsClientInGame(victim)) return;
	
	if (attacker == 0) return;
	
	if (!IsClientInGame(attacker))
	{
		if (IsInfected(victim)) ClearDamage(victim);
		return;
	}
	
	if (IsSurvivor(attacker) && IsInfected(victim))
	{
		new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_Tank) return; // We don't care about tank damage
		
		new lasthealth = g_iLastHealth[victim];
		g_iDamageDealt[victim][attacker] += lasthealth;
		
		if(!IsFakeClient(victim))
		{
			PrintHintText(victim, "You are killed by %N.", attacker);
		}
		
		if (zombieclass == ZC_Hunter && IsPouncing(victim))
		{ 
			new String:weapon[64];
			GetClientWeapon(attacker, weapon, sizeof(weapon));
			if (GetEventBool(event, "headshot") && (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_pistol_magnum")))
			{
				Call_StartForward(g_hForwardAirshoot);
				Call_PushCell(attacker);
				Call_PushCell(victim);
				Call_Finish();
				CPrintToChatAll("{green}★★★ {olive}%N {blue}headshot{default}-{blue}skeeted {green}%N{default}.", attacker, victim);
			}
		}
	}
	if (IsInfected(victim)) ClearDamage(victim);
}

public Action:OnSkeet(survivor, hunter)
{
	if(survivor == -2 && IsClientInGame(hunter))
	{
		CPrintToChatAllEx(hunter, "{teamcolor}★ {green}%N {default}was {teamcolor}teamskeeted.", hunter);
	}
	else if(IsClientInGame(survivor) && IsClientInGame(hunter))
	{
		CPrintToChatAll("{green}★ {olive}%N {blue}skeeted {green}%N{default}.", survivor, hunter);
	}
}

public Action:OnJockeySkeet(attacker, victim)
{
	CPrintToChatAll("{green}★★ {olive}%N {blue}skeeted {green}%N{default}'s Jockey.", attacker, victim);
}

public Action:OnJockeyMeleeSkeet(attacker, victim)
{
	CPrintToChatAll("{green}★★ {olive}%N {blue}melee-skeeted {green}%N{default}'s Jockey.", attacker, victim);
}

public OnSkeetMelee( survivor, hunter )
{
	CPrintToChatAll("{green}★★ {olive}%N {blue}melee{olive}-{blue}skeeted {green}%N{default}.", survivor, hunter);
}

public OnSkeetMeleeHurt( survivor, hunter, damage, isOverkill )
{
	CPrintToChatAll("{green}★★ {olive}%N {blue}melee{olive}-{blue}skeeted {green}%N{default}.", survivor, hunter);
}

public OnBoomerPop( survivor, boomer, shoveCount, Float:timeAlive )
{
	if(timeAlive < 1.9)
		CPrintToChatAll("{green}★ {olive}%N {blue}popped {green}%N{default} in {blue}%.1f{default}s.", survivor, boomer, timeAlive);
}

public OnSpecialClear( clearer, pinner, pinvictim, zombieClass, Float:timeA, Float:timeB, bool:withShove )
{
	new Float: fClearTime = timeA;
	if ( zombieClass == ZC_Charger || zombieClass == ZC_Smoker) { fClearTime = timeB; }
	if (clearer == 0 || clearer == pinvictim) return;											// self clear
	if (!IsSurvivor(clearer)) return;
	if (fClearTime > 0.00 && fClearTime <= 0.42)
	{
		CPrintToChatAllEx(clearer, "{green}★ {olive}%N{teamcolor} insta-cleared {olive}%N{teamcolor} from {green}%N{teamcolor}(%.2fs).", clearer, pinvictim, pinner, fClearTime);
	}
}

public OnChargerLevel( survivor, charger )
{
	CPrintToChatAllEx(survivor, "{green}★★ {olive}%N{teamcolor} leveled {green}%N{teamcolor}.", survivor, charger );
}

public OnChargerLevelHurt( survivor, charger, damage )
{
	CPrintToChatAllEx(survivor, "{green}★★ {olive}%N{teamcolor} chip-leveled {green}%N{teamcolor}.", survivor, charger );
}

public OnTongueCut( survivor, smoker )
{
	CPrintToChatAllEx(survivor, "{green}★★ {olive}%N{teamcolor} cut {green}%N{default}'s tongue.", survivor, smoker );
}

public OnSmokerSelfClear( survivor, smoker, withShove )
{
	CPrintToChatAllEx(survivor, "{green}★ {olive}%N{teamcolor} self-cleared from {green}%N{default}'s tongue{teamcolor}%s.", survivor, smoker, (withShove) ? " by shoving" : "" );
}

public OnTankRockSkeeted( survivor, tank )
{
	CPrintToChatAllEx(survivor, "{green}★ {olive}%N{teamcolor} skeeted {default}a {green}tank rock{default}.", survivor );
}

public OnHunterHighPounce( hunter, victim, actualDamage, Float:calculatedDamage, Float:height, bool:bReportedHigh, bool:bPlayerIncapped )
{
	if(actualDamage < 15 && height < 200.0) return;
	CPrintToChatAllEx(hunter, "{teamcolor}★★ {green}%N {teamcolor}high-pounced {olive}%N{default}(dmg: {teamcolor}%d{default}, height:{teamcolor}%.1f{default})", hunter, victim, actualDamage, height);
}

public OnDeathCharge( charger, victim, Float: height, Float: distance, wasCarried )
{
	CPrintToChatAllEx(charger, "{teamcolor}★★★ {green}%N {teamcolor}death-charged {olive}%N{default}.", charger, victim);
}

public OnBunnyHopStreak( survivor, streak, Float:maxVelocity )
{
	if(streak > 2)
		CPrintToChatAllEx(survivor, "{green}★ {olive}%N{default} got {teamcolor}%i{green} bunnyhop%s {default}in a row ({green}top speed{default}: {teamcolor}%.1f{default}).", survivor, streak, ( streak > 1 ) ? "s" : "", maxVelocity );
}

public OnCarAlarmTriggered( survivor, infected, reason )
{
	if(survivor > 0 && survivor <= MaxClients && IsClientInGame(survivor))
		CPrintToChatAllEx(survivor, "{green}✘ {olive}%N {teamcolor}triggered {default}an {green}Alarmed Car{default}.", survivor);
}

public Action:OnHunterDeadstop( survivor, hunter )
{
	CPrintToChatAllEx(survivor, "{green}★ {olive}%N {teamcolor}deadstopped {green}%N{default}.", survivor, hunter);
}

public OnWitchCrown(survivor, damage)
{
	CPrintToChatAllEx(survivor,"{green}★ {olive}%N {teamcolor}crowned {default}a {green}Witch{default}.", survivor);
}

public OnWitchDrawCrown(attacker, damage, chipdamage)
{
	CPrintToChatAllEx(attacker, "{green}★ {olive}%N {teamcolor}draw-crowned {default}a {green}Witch{default}({teamcolor}%d {default}dmg, {teamcolor}%d {default}chip)", attacker, damage, chipdamage );
}

void ClearMapStats()
{
	_allclients(i)
	{
		ClearDamage(i);
	}
}

void ClearDamage(client)
{
	g_iLastHealth[client] = 0;
	_allclients(i)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}

public ClientValue2DSortDesc(x[], y[], const array[][], Handle:data)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}