#pragma semicolon 1

#include <sourcemod>
#include <styxutils>

#undef REQUIRE_PLUGIN
#include <readyup>

#define 	_check_interval_		0.33333

ConVar 	hCvarDiscardRange,
		hCvarTeleRangeMax,
		hCvarTeleRangeMin,
		hCvarGodTime,
		hCvarVisibletp;

bool	bIsRoundAlive = false,
		bVisibleTp 	= false;
float	fTeleGodTime,
		fMinRange,
		fMaxRange,
		fDiscardRange;

int 	iRoundWarpCount = 0,
		iRoundSolveCount = 0;

// int 	laserCache;

enum Distflag {
	INVALID_ = 0,
	TOO_CLOSE ,
	PROPER,
	TOO_FAR
}

float deathTime[MAXPLAYERS+1];
static Distflag distFlag[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Styx Dummy Teleporter.", 
	author = "Lind3ey", 
	description = "Tp dummys!", 
	version = "1.2", 
	url = ""
};

public OnPluginStart()
{
	hCvarDiscardRange  	= CreateConVar("ssitp_discard_range", 	"800.0",	"Discard range");
	hCvarTeleRangeMax 	= CreateConVar("ssitp_tp_range_max", 	"800.0", 	"teleport max range");
	hCvarTeleRangeMin 	= CreateConVar("ssitp_tp_range_min", 	"180.0", 	"teleport min range");
	hCvarGodTime		= CreateConVar("ssitp_god_time",		"0.6",	"SI free of damage for this seconds", FCVAR_SPONLY, true, 0.0);
	hCvarVisibletp		= CreateConVar("ssitp_visible", 		"0", 	"Teleport boomer to tank?", FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
	HookEvent("player_death",	Event_Death,		EventHookMode_Post);
	
	Cvar_Changed();
}

public void OnMapStart()
{
	// laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsRoundAlive = false;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bIsRoundAlive)
	{
		bIsRoundAlive = false;
		PrintToServer(">>> SSITP warped %d Special infected and solved %d Stuck.", iRoundWarpCount, iRoundSolveCount);
	}
}

public Cvar_Changed()
{
	fTeleGodTime		= GetConVarFloat(hCvarGodTime);
	fMinRange 			= GetConVarFloat(hCvarTeleRangeMin);
	fMaxRange 			= GetConVarFloat(hCvarTeleRangeMax);
	fDiscardRange		= GetConVarFloat(hCvarDiscardRange);
	bVisibleTp 			= GetConVarBool(hCvarVisibletp);
}

public OnLeftSafeArea()
{
	bIsRoundAlive 		= true;
	iRoundSolveCount = 0;
	iRoundWarpCount = 0;
	Cvar_Changed();
	CreateTimer(_check_interval_, REPEAT_CheckSpecials, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}	

public Action:REPEAT_CheckSpecials(Handle:timer)
{
	if(!bIsRoundAlive) return Plugin_Stop;
	TeleportSpecials();
	StuckSolver();
	
	return Plugin_Continue;
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{

	new victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(victim) && IsInfected(victim))
	{
		deathTime[victim] = GetGameTime();
	}
}

static void TeleportSpecials()
{
	CheckDistance();
	_allclients(i)
	{
		if(distFlag[i] == TOO_FAR && IsValidTeler(i))
		{
			int tgt = GetNextTPTarget();
			if(tgt < 1) break; 
			else 
			{
				//DrawBeam(i, tgt);
				TeleportEntTo(i, tgt, true);
				distFlag[tgt] = INVALID_;      // Reset flag to avoid repeatly tp to tgt.
				iRoundWarpCount++;
				AvoidDamageTime(i, fTeleGodTime);
			}
		}
	}
}

int GetNextTPTarget()
{
	static int index = 0;
	int i = MaxClients;
	while((--i) != 0)
	{
		if(++index > MaxClients) index = 1;
		if(distFlag[index] == PROPER && IsValidTarget(index, bVisibleTp)) return index;
	}
	return -1;
}

static Float: fLastPos[MAXPLAYERS+1][3];

#define 		_stuck_dist_		2.0
void StuckSolver()
{
	static float infPos[3], fVector[3];
	_allclients(i)
	{
		if(IsValidTeler(i))
		{
			GetClientAbsOrigin(i, infPos);
			MakeVectorFromPoints(infPos, fLastPos[i], fVector);
			if (distFlag[i] > TOO_CLOSE && GetVectorLength(fVector) < _stuck_dist_) 
			{
				if(GetEntityMoveType(i) != MOVETYPE_NONE && !(GetEntityFlags(i) & FL_ONGROUND))
				{
					PrintToServer("[sitp] %N stuck at %.1f, %.1f, %.1f", i, infPos[0], infPos[1], infPos[2]);
					if(!IsVisibleToSurvivors(i))
					{
						CheatCommand(i, "warp_to_start_area");
						iRoundSolveCount ++;
					}
				}
			}
			GetClientAbsOrigin(i, fLastPos[i]);
		}
	}
}

void CheckDistance()
{
	_allclients(i)
	{
		distFlag[i] = INVALID_;
		distFlag[i] = ComputeDistanceFormSurvivors(i, fMinRange, fMaxRange, fDiscardRange);
	}
}

Distflag ComputeDistanceFormSurvivors(int dummy, 
										float closerange, 
										float farange,
										float dscrange,
										bool countincaped = false)
{
	if(!IsInfected(dummy)) return INVALID_;
	if(!IsPlayerAlive(dummy)) return INVALID_;
	if(IsPinningASurvivor(dummy)) return INVALID_;
	if(0.00 < (GetGameTime() - deathTime[dummy]) < 3.33) return INVALID_;
	float dist, min_dist = 10000.0;
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			if(!countincaped && IsIncapacitated(i)) continue;
			dist = GetDistance(dummy, i);
			if(dist < min_dist) min_dist = dist;
		}
	}
	// if(min_dist == 10000.0) return INVALID_;
	if(min_dist < closerange) return TOO_CLOSE;
	else if(min_dist < farange) return PROPER;
	else if(min_dist > dscrange ) return TOO_FAR;
	else return INVALID_;
}


stock bool IsValidTeler(client)
{
	if (!IsClientInGame(client) || !IsFakeClient(client)) 	return false;
	if (!IsInfected(client) || !IsPlayerAlive(client)) 	return false;
	if (GetInfectedClass(client) == ZC_Tank) return false;
	if (GetVictim(client) > 0) return false;
	return true;
}

stock bool IsValidTarget(client, bool:visible)
{
	if(!IsClientInGame(client)) 	return false;
	if(!IsInfected(client) ) 		return false;
	// if(IsGhostInfected(client)) 	return false;
	if(!visible && IsVisibleToSurvivors(client)) 		return false;
	
	return true;
}

//==================== protected dummys ===============================
public Action:Timer_RemoveGod(Handle:timer, any:client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	ResetGlow(client);
}

void AvoidDamageTime(client, float time)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	AvoidDamageGlow(client);
	CreateTimer(time, Timer_RemoveGod, client, TIMER_FLAG_NO_MAPCHANGE);
}

void AvoidDamageGlow(client) 
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && IsInfected(client)) 
	{
		SetEntityRenderMode( client, RENDER_GLOW);
		SetEntityRenderColor (client, 0,0,0,223 );
	}
}

void ResetGlow(client) 
{
	if (IsClientInGame(client)) 
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}


// return if target is visible to client.
stock bool IsVisibleTo(client, target)
{
	static Handle:trace = INVALID_HANDLE;
	if(trace != INVALID_HANDLE)
	{
		CloseHandle(trace);
	}
	
	static float angles[3], self_pos[3];

	GetClientEyePosition(client, self_pos);
	ComputeAimAngles(client, target, angles);
	trace = TR_TraceRayFilterEx(self_pos, angles, MASK_OPAQUE, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) 
	{
		new hit = TR_GetEntityIndex(trace);
		if (hit == target) 
		{
			CloseHandle(trace);
			trace = INVALID_HANDLE;
			return true;
		}
	}
	CloseHandle(trace);
	trace = INVALID_HANDLE;
	return false;
}

// Aim type chest
stock ComputeAimAngles(client, target, Float:angles[3])
{
	static float target_pos[3], self_pos[3], lookat[3];

	GetClientEyePosition(client, self_pos);
	GetClientAbsOrigin(target, target_pos);
	target_pos[2] += 45.0; // このくらい
	// if(!IsPlayerAlive(target)) target_pos[2] += 30;
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}

bool IsVisibleToSurvivors(client)
{
	if(HasThreat(client)) return true;
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			if(GetDistance(i, client) < 42.0) return true;
			if(IsVisibleTo(i, client)) 	return true;
		}
	}
	return false;
}

bool traceFilter(entity, mask, any:self)
{
	return entity != self;
}

stock void DustEffect(ent1, ent2, float size = 300.0)
{
	float pos[3], dir[3];
	if(IsValidEntity(ent1) && IsValidEntity(ent2))
	{
		GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", dir);
		
		TE_SetupDust(dir, pos, size, 200.0);
		TE_SendToAll();	
	}
}

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3
#define PURPLE 4
stock void DrawBeam( ent1, ent2, spawnResult = PURPLE ) 
{
	float pos[3], dir[3];
	if(IsValidEntity(ent1) && IsValidEntity(ent2))
	{
		GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", dir);
		
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

stock bool:IsPlayerStuck( const Float:pos[3], client) {
	new bool:isStuck = true;
	if( IsValidClient(client) ) {
		new Float:mins[3];
		new Float:maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		
		// inflate the sizes just a little bit
		for( new i = 0; i < sizeof(mins); i++ ) {
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}
		
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}  

// filter out players, since we can't get stuck on them
public bool:TraceEntityFilterPlayer(entity, contentsMask) {
    return entity <= 0 || entity > MaxClients;
}  
