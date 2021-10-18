#pragma semicolon 1

#define IsCoop()  !IsVersusMode()

enum Angle_Vector {
	Pitch = 0,
	Yaw,
	Roll
};

ConVar  CvarJockeyLeapRange, // vanilla cvar
		CvarLeapAgain,
		CvarJockeyStumbleRadius, // stumble radius of jockey ride
		CvarHopActivationProximity; // custom cvar

// Leaps
 
bool bCanLeap[MAXPLAYERS],
	 bJockeyBehavior[MAXPLAYERS],
	 bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
 // shoved jockeys will stop hopping


// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public Jockey_OnModuleStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	CvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	CvarLeapAgain 		= FindConVar("z_jockey_leap_again_timer");
	CvarJockeyLeapRange.SetInt(1000); 
	
	// proximity when plugin will start forcing jockeys to hop
	CvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
	
	// Jockey stumble
	HookEvent("jockey_ride", OnJockeyRide, EventHookMode_Pre); 
	CvarJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a jockey landing a ride");
}

public Jockey_OnModuleEnd() {
	ResetConVar(CvarJockeyLeapRange);
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action:Jockey_OnPlayerRunCmd(jockey, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, bool:hasBeenShoved) {
	new iSurvivorsProximity = GetSurvivorProximity(jockey);
	if ( HasThreat(jockey) && iSurvivorsProximity < CvarHopActivationProximity.IntValue) {
		// Force them to hop 
		new flags = GetEntityFlags(jockey);
		// Alternate normal jump and pounces if jockey has not been shoved
		if( (flags & FL_ONGROUND) && !hasBeenShoved ) {
			if(bJockeyBehavior[jockey])
			{
				if (bDoNormalJump[jockey]) {
					buttons |= IN_JUMP; // normal jump
					bDoNormalJump[jockey] = false;
				} else {
					if( bCanLeap[jockey] ) {
						buttons |= IN_ATTACK; // pounce leap
						bCanLeap[jockey] = false; // leap should be on cooldown
						float leapCooldown = CvarLeapAgain.FloatValue;
						CreateTimer(leapCooldown, Timer_LeapCooldown, any:jockey, TIMER_FLAG_NO_MAPCHANGE);
						bDoNormalJump[jockey] = true;
					}					
				}
			} else {
				buttons |= IN_FORWARD;
				if(bDoNormalJump[jockey])
				{
					buttons |= IN_JUMP; // normal jump
				}
				else
				{
					buttons |= IN_ATTACK; // pounce leap
					// buttons |= IN_JUMP;
				}			
				bDoNormalJump[jockey] = !bDoNormalJump[jockey];
			}
			
		} 
		
		else { // midair, release buttons
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
			if(hasBeenShoved) buttons &= ~IN_ATTACK2;
		}		
		return Plugin_Changed;
	} 

	return Plugin_Continue;
}

/*************************************************************************
					DEACTIVATING HOP DURING SHOVES
**************************************************************************/

// Enable hopping on spawned jockeys
public Action:Jockey_OnSpawn(botJockey) {
	bCanLeap[botJockey] = true;
	bJockeyBehavior[botJockey] =bool:GetRandomInt(0, 1);
	return Plugin_Handled;
}

// Disable hopping when shoved
public Jockey_OnShoved(botJockey) {
	bCanLeap[botJockey] = false;
	float leapCooldown = CvarLeapAgain.FloatValue;
	CreateTimer(leapCooldown, Timer_LeapCooldown, any:botJockey, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action:Timer_LeapCooldown(Handle:timer, any:jockey) {
	bCanLeap[jockey] = true;
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public OnJockeyRide(Handle:event, const String:name[], bool:dontBroadcast) {	
	if (IsCoop()) {
		new attacker = GetClientOfUserId(GetEventInt(event, "userid"));  
		new victim = GetClientOfUserId(GetEventInt(event, "victim"));  
		if(attacker > 0 && victim > 0) {
			StumbleBystanders(victim, attacker);
		} 
	}	
}

void StumbleBystanders( pinnedSurvivor, pinner ) {
	decl Float:pinnedSurvivorPos[3];
	decl Float:pos[3];
	decl Float:dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	float radius = CvarJockeyStumbleRadius.FloatValue;
	_allclients(i) {
		if( IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i) ) {
			if( i != pinnedSurvivor && i != pinner && !IsPinned(i) ) {
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if( GetVectorLength(dir) <= radius ) {
					NormalizeVector( dir, dir ); 
					L4D_StaggerPlayer( i, pinnedSurvivor, dir );
				}
			}
		} 
	}
}