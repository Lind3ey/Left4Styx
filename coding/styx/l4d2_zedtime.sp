#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include "styxutils"
// #include <colors>

static bool: bZedTimeOn	= false;

public Plugin:myinfo = 
{
    name = "L4D2 Zed Time",
    author = "Lind3ey",
    description = "Some skillful kills trigger zed time.",
    version = "1.5",
}

public OnPluginStart()
{
	bZedTimeOn	= true;
	RegConsoleCmd("sm_zed", Cmd_Toggle, "Toggle zed time");
}
/*
#define HFMIN	30.0

public OnRoundIsLive()
{
	CreateTimer(HFMIN, Timer_SayUse);
}

public Action:Timer_SayUse(Handle:timer)
{
	PrintToChatAll("\x03->\x01You can use \x04!zed \x01to toggle \x04Zed Time.");
}
*/

#define 	TEAM_SPECTATORS 	1
public Action:Cmd_Toggle(client, args)
{
	if(!client) 
	{
		bZedTimeOn = !bZedTimeOn;
		return Plugin_Handled;
	}
	if(GetClientTeam(client) == TEAM_SPECTATORS) return Plugin_Handled;
	bZedTimeOn = !bZedTimeOn;
	PrintToChatAll("\x03-> \x04%N \x01toggled \x04Zed time \x03%s.", client, (bZedTimeOn?"On":"Off"));
	return Plugin_Handled;
}

public OnSkeet( survivor, hunter )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}

public OnSkeetMelee( survivor, hunter )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}

public OnSkeetMeleeHurt( survivor, hunter, damage, isOverkill )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}

public OnSkeetSniper( survivor, hunter )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}
// Jockey_skeet.smx
public OnJockeySkeet(attacker, victim)
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.6, attacker);
}

public OnJockeyMeleeSkeet(attacker, victim)
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.6, attacker);
}
/*
public OnHunterDeadstop( survivor, hunter )
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.5);
}
*/

public OnChargerLevel( survivor, charger )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}

public OnChargerLevelHurt(attacker)
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.6, attacker);
}

public OnWitchDrawCrown(attacker, damage, chipdamage)
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.6, attacker);
}
/*
public OnWitchCrown( survivor, damage )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.5);
}

public OnTongueCut( survivor, smoker )
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.5);
}

public OnSmokerSelfClear( survivor, smoker, withShove )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.5);
}

public OnTankRockSkeeted( survivor, tank )
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.5);
}
*/
// stats_styx.smx
public OnAirShoot(survivor, victim)
{
	if(bZedTimeOn)
		SetTimeScale(0.2, 0.6, survivor);
}
//stats_styx.smx
public OnStopCharge(survivor, victim)
{
	if(bZedTimeOn)
		SetTimeScale(0.3, 0.6, survivor);
}

stock void SetTimeScale(float scale, float duration = -0.0, int client = -1)
{
	if(scale <= 0.0 || scale > 16.0) return;
	char strts[8];
	FloatToString(scale, strts, sizeof(strts));
	
	static int i_Ent = INVALID_ENT_REFERENCE;
	if(IsValidEntity(i_Ent))
	{
		AcceptEntityInput(i_Ent, "Kill");
		i_Ent = INVALID_ENT_REFERENCE;
	}

	if(i_Ent == INVALID_ENT_REFERENCE || !IsValidEntity(i_Ent)){
		i_Ent = EntIndexToEntRef(CreateEntityByName("func_timescale"));
		if(i_Ent == INVALID_ENT_REFERENCE || !IsValidEntity(i_Ent)){
			LogError("Could not create 'func_timescale'");
			return;
		}
		DispatchSpawn(i_Ent);
	}

	DispatchKeyValue(i_Ent, "desiredTimescale", strts);
	DispatchKeyValue(i_Ent, "acceleration", "2.0");
	DispatchKeyValue(i_Ent, "minBlendRate", "1.0");
	DispatchKeyValue(i_Ent, "blendDeltaMultiplier", "2.0");
	AcceptEntityInput(i_Ent, "Start");

	if(duration > 0.0){
		CreateTimer(duration, ResetTimeScale, i_Ent, TIMER_FLAG_NO_MAPCHANGE);

		if (client > 0 && IsValidPlayer(client)) {
			Handle pack = CreateDataPack();
			WritePackCell( pack, client );
			WritePackFloat( pack, 1.00/scale);
			CreateTimer(0.024, delaySetClientSpeed, pack, TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(duration, resetClientSpeed, client, TIMER_FLAG_NO_MAPCHANGE );
		}
	}
}

Action delaySetClientSpeed(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	float value = ReadPackFloat(pack);
	SetClientSpeed(client, value);	
}

Action ResetTimeScale(Handle Timer, int entity)
{
	if(IsValidEdict(entity))
		AcceptEntityInput(entity, "Stop");
	else
		PrintToServer("[SM] i_Ent is not a valid edict!");
}

Action resetClientSpeed(Handle timer, int client){
	SetClientSpeed(client, 1.000);
}