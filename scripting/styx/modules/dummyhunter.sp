#pragma semicolon 1

#include <sdktools>
#define DEBUG_HUNTER_AIM 0
#define DEBUG_HUNTER_RNG 0
#define DEBUG_HUNTER_ANGLE 0

#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2

#define _e_ 	2.71828

// Vanilla Cvars
ConVar CvarHunterCommittedAttackRange,
	CvarHunterPounceReadyRange,
	CvarHunterLeapAwayGiveUpRange, 
	CvarHunterPounceMaxLoftAngle, 
//	CvarLungeInterval, 
// Gaussian random number generator for pounce angles
	CvarPounceAngleMean,
	CvarPounceAngleStd, // standard deviation
// Pounce vertical angle
	CvarPounceVerticalAngle,
// Distance at which hunter begins pouncing fast
	CvarFastPounceProximity, 
// Distance at which hunter considers pouncing straight
	CvarStraightPounceProximity,
// Aim offset(degrees) sensitivity
	CvarAimOffsetSensitivityHunter;
// Wall detection
//	CvarWallDetectionDistance

bool 	bHasQueuedLunge[MAXPLAYERS],
		bCanLunge[MAXPLAYERS];

public Hunter_OnModuleStart() {
	// Set aggressive hunter cvars
	// range at which hunter is committed to attack
	CvarHunterCommittedAttackRange = FindConVar("hunter_committed_attack_range"); 	
	// range at which hunter prepares pounce	
	CvarHunterPounceReadyRange = FindConVar("hunter_pounce_ready_range"); 
	// range at which shooting a non-committed hunter will cause it to leap away	
	CvarHunterLeapAwayGiveUpRange = FindConVar("hunter_leap_away_give_up_range"); 
	// cooldown on lunges
	// CvarLungeInterval = FindConVar("z_lunge_interval"); 
	// maximum vertical angle hunters can pounce
	CvarHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle"); 

	SetConVarInt(CvarHunterCommittedAttackRange, 10000);
	SetConVarInt(CvarHunterPounceReadyRange, 300);
	SetConVarInt(CvarHunterLeapAwayGiveUpRange, 0); 
	SetConVarInt(CvarHunterPounceMaxLoftAngle, 15);
	
	// proximity to nearest survivor when plugin starts to force hunters to lunge ASAP
	CvarFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000", "At what distance to start pouncing fast");
	
	// Verticality
	CvarPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "7", "Vertical angle to which AI hunter pounces will be restricted");
	
	// Pounce angle
	CvarPounceAngleMean = CreateConVar( "ai_pounce_angle_mean", "10", "Mean angle produced by Gaussian RNG" );
	CvarPounceAngleStd = CreateConVar( "ai_pounce_angle_std", "20", "One standard deviation from mean as produced by Gaussian RNG" );
	CvarStraightPounceProximity = CreateConVar( "ai_straight_pounce_proximity", "200", "Distance to nearest survivor at which hunter will consider pouncing straight");
	
	// Aim offset sensitivity
	CvarAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter",
									"30",
									"If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0 );
	// How far in front of hunter to check for a wall
	// CvarWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");
}

public Hunter_OnModuleEnd() {
	// Reset aggressive hunter cvars
	ResetConVar(CvarHunterCommittedAttackRange);
	ResetConVar(CvarHunterPounceReadyRange);
	ResetConVar(CvarHunterLeapAwayGiveUpRange);
	ResetConVar(CvarHunterPounceMaxLoftAngle);
}

public Action:Hunter_OnSpawn(botHunter) {
	bHasQueuedLunge[botHunter] = false;
	bCanLunge[botHunter] = true;
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/

public Action:Hunter_OnPlayerRunCmd(hunter, &buttons, &impulse, Float:vel[3], Float:eyeAngles[3], &weapon) {	
	// botHunter can pounce instantly
	if(buttons & IN_DUCK)
	{
		new lunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
		float ftime = GetGameTime();
		if (lunge > 0 && GetEntPropFloat(lunge, Prop_Send, "m_timestamp")-ftime>0.0482) 
			SetEntPropFloat(lunge, Prop_Send, "m_timestamp", ftime+0.048); 
	}
	int flags = GetEntityFlags(hunter);

	//Hunter is about to jump.
	if (flags&FL_ONGROUND) {
		if (buttons&IN_JUMP && HasThreat(hunter)) {
			buttons &= ~IN_JUMP;

			new lunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
			if (lunge > 0) 
				SetEntPropFloat(lunge, Prop_Send, "m_timestamp", GetGameTime()); 
			buttons |= IN_DUCK;
			buttons |= IN_ATTACK;
			return Plugin_Changed;
		}

	//Proceed if the hunter is in a position to pounce
		if( flags & FL_DUCKING) 
		{				
			int iSurvivorsProximity = GetSurvivorProximity(hunter);
			bool bHasLOS = HasThreat(hunter) || HunterAtHighPos(hunter); 
			// Line of sight to survivors		
			// Start fast pouncing if close enough to survivors
			if( bHasLOS ) {
				if( iSurvivorsProximity < CvarFastPounceProximity.IntValue ) {
					buttons &= ~IN_ATTACK; // release attack button; precautionary					
					// Queue a pounce/lunge
					if (!bHasQueuedLunge[hunter]) 
					{ // check lunge interval timer has not already been initiated
						bCanLunge[hunter] = false;
						bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
						CreateTimer(0.1, Timer_LungeInterval, hunter, TIMER_FLAG_NO_MAPCHANGE);
					} 
					else if (bCanLunge[hunter]) 
					{ // end of lunge interval; lunge!
						buttons |= IN_ATTACK;
						bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
					} // else lunge queue is being processed
				}
			}	
		} 
	}
	return Plugin_Changed;
}

bool HunterAtHighPos(hunter)
{
	decl Float:hunterPos[3];
	GetClientAbsOrigin(hunter, hunterPos);
	decl Float:sPos[3];
	for( new i = MaxClients; i > 0; i--)
	{
		if(IsSurvivor(i) && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, sPos);
			if(hunterPos[2] < sPos[2] + 200.0) return false;
		}
	}
	return true;
}

/***********************************************************************************************************************************************************************************

																	POUNCING AT AN ANGLE TO SURVIVORS

***********************************************************************************************************************************************************************************/

public Action:Hunter_OnPounce(botHunter) 
{	
	new entLunge = GetEntPropEnt(botHunter, Prop_Send, "m_customAbility"); // get the hunter's lunge entity				
	new Float:lungeVector[3]; 
	GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector); // get the vector from the lunge entity

	if( IsTargetWatchingAttacker(botHunter, CvarAimOffsetSensitivityHunter.IntValue) 
		&& GetSurvivorProximity(botHunter) > CvarStraightPounceProximity.IntValue ) 
	{			
		float pounceAngle = GaussianRNG( CvarPounceAngleMean.FloatValue, CvarPounceAngleStd.FloatValue);
		AngleLunge( entLunge, pounceAngle );
		if(GetRandomInt(0, 1))
			LimitLungeVerticality( entLunge );

		#if DEBUG_HUNTER_AIM
			new target = GetClientAimTarget(botHunter);
			if( IsSurvivor(target) ) {
				new String:targetName[32];
				GetClientName(target, targetName, sizeof(targetName));
				PrintToChatAll("The aim of hunter's target(%s) is %f degrees off", targetName, GetPlayerAimOffset(target, botHunter));
				PrintToChatAll("Angling pounce to throw off survivor");
			} 	
		#endif
		return Plugin_Changed;	
	}
	return Plugin_Continue;
}

// Credits to High Cookie and Standalone for working out the math behind hunter lunges
void AngleLunge( lungeEntity, Float:turnAngle ) {	
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
    
    // Create a new vector of the desired angle from the original
	turnAngle = DegToRad(turnAngle); // convert angle to radian form
	new Float:forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);	
}

// Stop pounces being too high
bool LimitLungeVerticality( lungeEntity ) {
	// Get vertical angle restriction
	float vertAngle = CvarPounceVerticalAngle.FloatValue;
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
	
	vertAngle = DegToRad(vertAngle);	
	new Float:flatLunge[3];
	// First rotation
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	// Second rotation
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
Float:GaussianRNG( Float:mean, Float:std ) {	 	
	// Randomising positive/negative
	int signBit = GetRandomInt(0, 1);
	
	float x1, x2, w;
	// Box-Muller algorithm
	do {
	    // Generate random number
	    x1 = 2.0*GetRandomFloat( 0.0, 1.0 ) - 1.0;
	    x2 = 2.0*GetRandomFloat( 0.0, 1.0 ) - 1.0;
	    w = x1*x1 + x2* x2;
	 
	} while( w >= 1.0 );	
	w = SquareRoot(  -2.0*  Logarithm(w, _e_)/ w ); 

	if (signBit == NEGATIVE)
		return x1 * w * std - mean;
	else
		return x1 * w * std + mean;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action:Timer_LungeInterval(Handle:timer, any:client) {
	bCanLunge[client] = true;
}