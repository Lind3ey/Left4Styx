#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "styxutils.inc"

public Plugin:myinfo = 
{
	name = "Styx Dummy SI ++",
	author = "Lind3ey",
	description = "Smoker, Boommer, Spitter, Charger",
	version = "0.4",
	url = ""
}

#define MAXPLAYERS1     (MAXPLAYERS+1)
#define justSpawntime 	0.6

#define VEL_MAX          450.0
#define MOVESPEED_TICK     1.0
#define EYEANGLE_TICK      0.2
#define TEST_TICK          2.0
#define MOVESPEED_MAX     1000

#define BHOP_MAX_PROX 	 450.0
#define BHOP_MIN_PROX	 180.0
#define BHOP_START_SPEED 180.0
#define ONEHANDOVERHEAD  49
#define UNDERHIP		 50
#define TWOHANDOVERHEAD	 51

#define _climbing(%0)	(GetEntityMoveType(%0)==MOVETYPE_LADDER)

ConVar 	CvarJumpRockChance,
		CvarSecondJumpProx,
		CvarSecondHeight,
		CvarVomitRange,
		CvarTongueRange;

static bool BhopChg[MAXPLAYERS1];

int 	rocktype, laserCache;
// 特殊がメイン攻撃した時間
float g_si_attack_time;
#define getSIAttackTime() 		g_si_attack_time
#define updateSIAttackTime()  	g_si_attack_time=GetGameTime()

float g_delay[MAXPLAYERS1][4];

#define delayStart(%0,%1) g_delay[%0][%1]=GetGameTime()

#define delayExpired(%0,%1,%2)	GetGameTime()-g_delay[%0][%1]>%2
#define inDelay(%0,%1,%2)	GetGameTime()-g_delay[%0][%1]<%2

enum AimTarget
{
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

public OnPluginStart()
{
	HookEvent("round_start", OnRoundStart);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("ability_use", OnUseAbility);
	HookEvent("player_incapacitated", OnIncap);
	HookEvent("player_hurt", OnPunchHurt);
	CvarJumpRockChance = CreateConVar("z_tank_jumprock_chance", "1.0", "Tank JUMP ROCK CHANCE", FCVAR_SPONLY, true, 0.0, true, 1.0);
	CvarSecondJumpProx = CreateConVar("z_secondjump_prox", "0", "second jump prox", FCVAR_CHEAT);
	CvarSecondHeight = CreateConVar("tank_secondjump_height", "512", "second jump height", FCVAR_CHEAT);
// 	PropVelocity  = FindSendPropInfo("CBasePlayer",   "m_vecVelocity[0]");
}

public void OnMapStart()
{
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public Action:OnRoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	initStatus();
	CvarVomitRange = FindConVar("z_vomit_range");
	CvarTongueRange = FindConVar("tongue_range");
}

#define 	JUMP_POWER 		60.0
#define		JUMP_DIST		200.0
#define 	JUMP2_DELAY 	1.56		//Timing for tank to perform second jump
#define 	JUMP2_AIM		2.32		//Timing to adjust aim for tank 
public Action:OnUseAbility(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client)) return Plugin_Continue;
	if(!IsInfected(client) || !IsFakeClient(client)) return Plugin_Continue;
	if(GetInfectedClass(client) == ZC_Boomer && NearestSurvivorDistance(client) > JUMP_DIST)
	{
		Client_Jump(client, JUMP_POWER);
		CreateTimer(0.15, Boomer_Aim, client, TIMER_FLAG_NO_MAPCHANGE);
	}else if(GetInfectedClass(client) == ZC_Tank){
		g_delay[client][1] = 0.0
		if(Math_GetRandomInt(0, 99) < CvarJumpRockChance.FloatValue * 100)
			Client_Jump(client, JUMP_POWER/2);
		CreateTimer(JUMP2_DELAY, delaySecondJump, client, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(JUMP2_AIM, delayJumpAim, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

Action delaySecondJump(Handle timer, int client)
{
	if(!IsBotTank(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	float prox;
	int target = NearestRangeTarget(client, prox);
	if(target > 0){
		if(GetEntityFlags(client)&FL_ONGROUND && prox>CvarSecondJumpProx.FloatValue)
			Client_Jump(client, JUMP_POWER*3, CvarSecondHeight.FloatValue);
	}
	return Plugin_Handled;
}

Action delayJumpAim(Handle timer, int client)
{
	if(!IsBotTank(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	if(rocktype != ONEHANDOVERHEAD) return Plugin_Handled;
	TankAdjustAim(client);
	return Plugin_Handled;
}

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3
#define PURPLE 4
stock void DrawBeam( ent1, ent2, spawnResult = PURPLE ) 
{
	float pos[3], dir[3];
	if(IsValidClient(ent1) && IsValidEntity(ent2))
	{
		GetClientEyePosition(ent1, pos);
		GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", dir);
		dir[2]+=45.0;
		//laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
		static int Color[5][4]; 
		Color[VALID_MESH] = {0, 255, 0, 75}; // green
		Color[INVALID_MESH] = {255, 0, 0, 75}; // red
		Color[SPAWN_FAIL] = {255, 140, 0, 75}; // orange
		Color[WHITE] = {255, 255, 255, 75}; // white
		Color[PURPLE] = {128, 0, 128, 75}; // purple
		float beamDuration = 1.42;
		TE_SetupBeamPoints(pos, dir, laserCache, 0, 1, 1, beamDuration, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
		TE_SendToAll();
	}
}

public Action:Boomer_Aim(Handle:timer, client)
{
	float min_dist;
	int target = NearestRangeTarget(client, min_dist);
	if(target > 0)
	{
		float aim_angles[3];
		ComputeAimAngles(client, target, aim_angles, 0.0, AimTarget_Eye);
		aim_angles[2] += 15.0;
		TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
		if(IsVisibleTo(target, client) && min_dist < 320.0)
			L4D_CTerrorPlayer_OnVomitedUpon(target, client);
	}
}

public Action:OnPlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotInfected(client)) {
		if(GetInfectedClass(client) == ZC_Boomer)
			delayStart(client, 1);
		if(GetInfectedClass(client) == ZC_Charger) {
			BhopChg[client] = GetRandomInt(0, 99) > 68;
		}
	}
}

public Action:OnIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsBotTank(attacker)) {
		delayStart(attacker, 0);
		PrintToServer("debug incapacitate , delay start");
	}
}

public Action OnPunchHurt(Handle:event, const String:name[], bool:dontBroadcast){
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (!IsBotTank(attacker) || !IsSurvivor(victim)) return;
	
	new damage = GetEventInt(event, "dmg_health");
	if ( damage < 1 )  return; 
	
	if(GetClientHealth(victim) < 2) {
		delayStart(attacker, 0);
	}
	if(IsIncapacitated(victim)) {
		delayStart(attacker, 0);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsBotInfected(client)) {
			int zombie_class = GetInfectedClass(client);
			Action ret = Plugin_Continue;
			if(_climbing(client)) return ret;

			switch (zombie_class) {
				case ZC_Smoker:  { ret = OnSmokerRunCmd(client, buttons, vel, angles); }
				case ZC_Boomer:  { ret = OnBoomerRunCmd(client, buttons, vel, angles); }
				case ZC_Spitter: { ret = OnSpitterRunCmd(client, buttons, vel, angles); }
				case ZC_Charger: { ret = OnChargerRunCmd(client, buttons, vel, angles); }
				case ZC_Tank: 	 { ret = OnTankRunCmd(client, buttons, vel, angles); }
			}
			if (buttons & IN_ATTACK) 
				updateSIAttackTime();
			return ret;
	}
	return Plugin_Continue;
}

#define TANK_ROCK_AIM_TIME    	4.0
#define TANK_ROCK_AIM_DELAY   	0.25
#define TANK_ROCK_TOO_FAR 		600.0
#define Punch_Check_Delay		1.25
public Action:OnTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (inDelay(client, 1, Punch_Check_Delay)){
		buttons |= IN_ATTACK2;	//This delay should manually expire OnSelectRock
	}
	if (buttons&IN_ATTACK2) {
		if(FarAway(client, TANK_ROCK_TOO_FAR)){
			buttons &= ~IN_ATTACK2;
		} else {
			delayStart(client, 2);
			delayStart(client, 3);
		}
	}else if(buttons&IN_ATTACK) {
		new target = NearestSurvivor(client);
		if(target > 0)
		{
			float aim_angles[3];
			ComputeAimAngles(client, target, aim_angles);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
		}
	}

	if (delayExpired(client, 3, TANK_ROCK_AIM_DELAY) && inDelay(client, 2, TANK_ROCK_AIM_TIME)) {
		delayStart(client, 3);  //Fix angle evey 0.25 second
		TankAdjustAim(client);
	}
	return Plugin_Continue;
}

void TankAdjustAim(int client)
{
	int target = GetClientAimTarget(client, true);
	if (target > 0 && !IsIncapacitated(client) && IsVisibleTo(client, target)) {
		// do nothing
	} else {		
		float min_dist;
		target = NearestRangeTarget(client, min_dist);
		if (target > 0) 
		{
			float aim_angles[3];
			ComputeAimAngles(client, target, aim_angles, min_dist, AimTarget_Chest);
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
		}
	}
	CmdBotAttack(client, target);
}

#define SMOKER_ATTACK_SCAN_DELAY     0.5 
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE           300.0
public Action:OnSmokerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	Action ret = Plugin_Continue;
	if (buttons & IN_ATTACK) {
		// no thing
	} else if (delayExpired(client, 0, SMOKER_ATTACK_SCAN_DELAY))
	{
		delayStart(client, 0);
		int target = GetClientAimTarget(client, true);
		if (IsValidClient(target) && IsSurvivor(target) && IsVisibleTo(client, target)) {
			float dist = GetDistance(client, target);
			if (dist < SMOKER_MELEE_RANGE) 
			{
				buttons |= IN_ATTACK|IN_ATTACK2; 
				ret = Plugin_Changed;
			} else if (dist < CvarTongueRange.FloatValue) {
				if (GetGameTime() - getSIAttackTime() < SMOKER_ATTACK_TOGETHER_LIMIT) {
					buttons |= IN_ATTACK;
					ret = Plugin_Changed;
				} else {
					new target_aim = GetClientAimTarget(target, true);
					if (target_aim == client) {
						buttons |= IN_ATTACK;
						ret = Plugin_Changed;
					}
				}
			}
		}
	}
	
	return ret;
}


#define BOMMER_SCAN_DELAY 0.5
#define Boomer_forward 80.0
public Action:OnBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if(inDelay(client, 1, justSpawntime) && !HasThreat(client)){
		SetClientSpeed(client, 2.2);
		return Plugin_Continue;
	}

	SetClientSpeed(client, 1.0);

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if (delayExpired(client, 0, BOMMER_SCAN_DELAY))
		{
			delayStart(client, 0);
			float prox = NearestSurvivorDistance(client);
			if (HasThreat(client)) {
				if (prox < CvarVomitRange.FloatValue) {
					buttons |= IN_ATTACK;
					buttons |= IN_JUMP;
					buttons |= IN_ATTACK2;
				}
				else if(prox < BHOP_MAX_PROX && GetPlayerVelocity(client) > 120.0)
				{
					BlockVomit(client);
					buttons |= IN_DUCK;
					buttons |= IN_JUMP;
				}
			}
			if(buttons & IN_JUMP)
				Infected_Bhop(client, buttons, Boomer_forward);
			return Plugin_Changed;
		}
	}else{
		buttons &= ~IN_DUCK;
		buttons &= ~IN_JUMP;
	}
	return Plugin_Continue;	
}

// Avoid boomer from using ablilty
void BlockVomit(boomer) 
{
	int e_abilty = GetEntPropEnt(boomer, Prop_Send, "m_customAbility");
	if (e_abilty > 0 && IsValidEntity(e_abilty)) {
		SetEntPropFloat(e_abilty, Prop_Send, "m_timestamp", GetGameTime() + 0.1); 
	} 			
}

#define CHARGER_MELEE_DELAY     0.4
#define CHARGER_CLOSE 	300.0
#define Charger_forward 		60.0
#define CHARGER_RUN				180.0
public Action:OnChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	// Speed controll
	if( !HasThreat(client) ) {
		SetClientSpeed(client, 1.25);
		return Plugin_Continue;
	} 

	SetClientSpeed(client, 1.0);

	float prox = NearestSurvivorDistance(client);
	int flags = GetEntityFlags(client);

	// Close range melee attack
	if (!(buttons & IN_ATTACK)
		&& flags & FL_ONGROUND
		&& HasThreat(client)
		&& delayExpired(client, 0, CHARGER_MELEE_DELAY)
		&& prox < 120.0)
	{
		delayStart(client, 0);
		if(GetClientAimTarget(client) > 0 && IsFreeSurvivor(client)){
			buttons |= GetRandomInt(0,1)?IN_ATTACK:IN_ATTACK2;
		}
		return Plugin_Changed;
	}

	// Bhop.
	if (BhopChg[client] && delayExpired(client, 1, CHARGER_MELEE_DELAY)){
		if(HasThreat(client)
		   && (BHOP_MIN_PROX < prox < BHOP_MAX_PROX)
		   && GetPlayerVelocity(client) > CHARGER_RUN)
		{
			if( flags & FL_ONGROUND){
				delayStart(client, 1)
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				Infected_Bhop(client, buttons, Charger_forward);
			}else{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;	
}

#define SPITTER_RUN 180.0
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.4
#define SPITTER_forward 70.0
public Action:OnSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if ((GetEntityFlags(client) & FL_ONGROUND))
	{
		if( HasThreat(client)
			&& delayExpired(client, 0, SPITTER_JUMP_DELAY)
			&& GetPlayerVelocity(client) > SPITTER_RUN)
		{
			delayStart(client, 0);
			buttons |= IN_JUMP;
			Infected_Bhop(client, buttons, SPITTER_forward);
			return Plugin_Changed;
		}
	
		if (buttons & IN_ATTACK ) {
			if (delayExpired(client, 1, SPITTER_SPIT_DELAY)) {
				delayStart(client, 1);
				buttons |= IN_JUMP;
				return Plugin_Changed;
			}
		}
	}else{
		buttons &= ~IN_JUMP;
		buttons &= ~IN_DUCK;
	}
	return Plugin_Continue;
}

bool FarAway(client, float iMaxRange)
{
	_allclients(i)
	{
		if(IsFreeSurvivor(i))
		{
			if (GetDistance(client, i) < iMaxRange) return false;
		}
	}
	return true;
}

bool traceFilter(entity, mask, any:self){ return entity != self; }
bool IsVisibleTo(client, target)
{
	bool ret = false;
	float angles[3], self_pos[3];
	GetClientEyePosition(client, self_pos);
	ComputeAimAngles(client, target, angles, 0.0, AimTarget_Eye);
	Handle trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if(TR_DidHit(trace)) {
        new hit = TR_GetEntityIndex(trace);
        if (hit == target) {
             ret = true;
            }
        }
	CloseHandle(trace);
	return ret;
}

int NearestSurvivor(client, float min_dist = 100.0)
{
	int min_i = -1;
	_allclients(i) {
		if (IsFreeSurvivor(i))
		{
			float dist = GetDistance(client, i);
			if (dist < min_dist) {
				min_dist = dist;
				min_i = i;
			}
		}
	}
	return min_i;
}

void ComputeAimAngles(client, target, Float:angles[3], Float:dist = 0.0, AimTarget:type = AimTarget_Chest)
{
	float target_pos[3], self_pos[3], lookat[3];
	GetClientEyePosition(client, self_pos);
	switch (type) {
		case AimTarget_Eye:	GetClientEyePosition(target, target_pos);
		case AimTarget_Body: GetClientAbsOrigin(target, target_pos);
		case AimTarget_Chest: {
			GetClientAbsOrigin(target, target_pos);
			target_pos[2] += 45.0; // このくらい
			if(dist > 400)
				target_pos[2] += 15.0;
			if(dist > 600)
				target_pos[2] += 15.0;
    	}
    }
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}

// Smart AI rock, no underhand rock
public Action L4D2_OnSelectTankAttack(int client,int &sequence) {
	if (IsFakeClient(client) && sequence == UNDERHIP) {
		sequence = GetRandomInt(0, 5)?ONEHANDOVERHEAD:TWOHANDOVERHEAD;
		rocktype = sequence;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// @return Nearest Survivor distance
float NearestSurvivorDistance(client)
{
	float min_dist = 100000.0;
	_allclients(i) 
	{
		if (IsFreeSurvivor(i)) 
		{
			float dist = GetDistance(client, i);
			if (dist < min_dist)  min_dist = dist; 
		}
	}
	return min_dist;
}

// @return maybe the best vomit/rock target.
int NearestRangeTarget(tank, float& min_dist)
{
	min_dist = 100000.0;
	int min_i = -1;
	_forall(client) {
		if (IsFreeSurvivor(client) && IsVisibleTo(tank, client))
		{
			float dist = GetDistance(tank, client);
			if (dist < min_dist) 
			{
				min_dist = dist;
				min_i = client;
			}
		}
	}
	return min_i;
}

// clientから見える範囲で一番近い生存者を取得
stock int NearestVisibleSurvivor(client)
{
	float min_dist = 100000.0;
	int min_i = -1;
	_allclients(i) {
		if (IsClientInGame(i)
			&& IsSurvivor(i)
			&& IsPlayerAlive(i)
			&& IsVisibleTo(client, i))
		{
			float dist = GetDistance(client, i);
			if (dist < min_dist) {
				min_dist = dist;
				min_i = i;
			}
		}
	}
	return min_i;
}

void initStatus()
{
	float time = GetGameTime();
	g_si_attack_time = 0.0;
	_allclients(i) {
		for (new j = 0; j < 4; ++j) {
			g_delay[i][j] = time;
		}
	}
}

void Client_Jump(int client, float power, float zplus = 300.0)
{
	static Handle event_jump;
	event_jump = INVALID_HANDLE;
	
	float clientEyeAngle[3], forwardVector[3], velocity[3];
	GetClientEyeAngles(client, clientEyeAngle);
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	GetAbsVelocity(client, velocity);
	velocity[0] += forwardVector[0];	/* x coord */
	velocity[1] += forwardVector[1];	/* y coord */
	velocity[2] += zplus;					/* z coord */
	// velocity[2] += forwardVector[2];
	SetAbsVelocity(client, velocity);
	event_jump = CreateEvent("player_jump", true);
	SetEventInt(event_jump, "userid", GetClientUserId(client));
	FireEvent(event_jump);
	event_jump = INVALID_HANDLE;
}
