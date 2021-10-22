#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#include "styxutils.inc"
#include "modules/dummyhunter.sp"
#include "modules/dummycharger.sp"
#include "modules/dummyjockey.sp"
#include "modules/dummytank.sp"

new bool:bHasBeenShoved[MAXPLAYERS]; // shoving resets SI movement

public Plugin:myinfo = 
{
	name = "Styx Dummys Main",
	author = "Breezy, Lind3ey",
	description = "Tank(Bhop & punch), Hunter, Charger(charge), Jockey and names",
	version = "3.0",
	url = "github.com/breezyplease"
};

static const String:sBotName[][] = 
{
	"吕奉先",
	"赵子龙",
	"关云长",
	"张翼德",
	"夏侯渊",
	"周公瑾",
	"锦马超",
	"黄汉升",
	"夏侯惇",
	"司马懿",
};


static	iNameIndex = 0;

public OnPluginStart() { 
	// Cvars
	// hCvarAssaultReminderInterval = CreateConVar( "ai_assault_reminder_interval", "2", "Frequency(sec) at which the 'nb_assault' command is fired to make SI attack" );
	// Event hooks
	HookEvent("player_spawn", InitialiseSpecialInfected, EventHookMode_Pre);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre); 
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Pre);
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Pre);
	
	// Load modules
	Hunter_OnModuleStart();
	Charger_OnModuleStart();
	Jockey_OnModuleStart();
	Tank_OnModuleStart();
}

public OnPluginEnd() {
	// Unload modules
	Hunter_OnModuleEnd();
	Jockey_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

																	KEEP SI AGGRESSIVE
																	
***********************************************************************************************************************************************************************************/
/*
public Action:L4D_OnFirstSurvivorLeftSafeArea(firstSurvivor) {
	// CreateTimer( float(GetConVarInt(hCvarAssaultReminderInterval)), Timer_ForceInfectedAssault, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public Action:Timer_ForceInfectedAssault( Handle:timer ) {
	CheatCommand("nb_assault");
}
*/
/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/

// Modify SI movement
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if( IsBotInfected(client) && IsPlayerAlive(client) ) { // bots continue to trigger this callback for a few seconds after death
		if(GetEntityMoveType(client) == MOVETYPE_LADDER) return Plugin_Continue;

		switch(GetInfectedClass(client)) {
			case ZC_Hunter: {
				if(!bHasBeenShoved[client]) 
					return Hunter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon );
			}		
			case ZC_Charger: return Charger_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon );
			case ZC_Jockey: return Jockey_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, bHasBeenShoved[client]);
			case ZC_Tank: 	return Tank_OnPlayerRunCmd( client, buttons, impulse, vel, angles, weapon );
			default: return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/

// Initialise relevant module flags for SI when they spawn
public Action:InitialiseSpecialInfected(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		bHasBeenShoved[client] = false;
		iNameIndex ++;
		if(iNameIndex > sizeof(sBotName)-1)
			iNameIndex = 0;

		SetClientName(client, sBotName[iNameIndex]);
		// Process for SI class
		switch(GetInfectedClass(client) ) {
		
			case (ZC_Hunter): {
				return Hunter_OnSpawn(client);
			}
			
			case (ZC_Charger): {
				return Charger_OnSpawn(client);
			}
			
			case (ZC_Jockey): {
				return Jockey_OnSpawn(client);
			}
			
			default: {
				return Plugin_Handled;	
			}				
		}
	}
	return Plugin_Handled;
}

// Modify hunter lunges and block smokers/spitters from fleeing after using their ability
public Action:OnAbilityUse(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		bHasBeenShoved[client] = false; // Reset shove status		
		// Process for different SI
		new String:abilityName[32];
		GetEventString(event, "ability", abilityName, sizeof(abilityName));
		if( StrEqual(abilityName, "ability_lunge") ) {
			return Hunter_OnPounce(client);
		} else if( StrEqual(abilityName, "ability_charge") ) {
			Charger_OnCharge(client);
		}
	}
	return Plugin_Handled;
}

// Pause behaviour modification when shoved
public Action:OnPlayerShoved(Handle:event, String:name[], bool:dontBroadcast) {
	new shovedPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(shovedPlayer) ) {
		bHasBeenShoved[shovedPlayer] = true;
		if(GetInfectedClass(shovedPlayer) == ZC_Jockey ) {
			Jockey_OnShoved(shovedPlayer);
		}
	}
	return Plugin_Continue;	
}

// Re-enable forced hopping when a shoved jockey leaps again naturally
public Action:OnPlayerJump(Handle:event, String:name[], bool:dontBroadcast) {
	new jumpingPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(jumpingPlayer) )  {
		bHasBeenShoved[jumpingPlayer] = false;
	}
} 

/***********************************************************************************************************************************************************************************

																	TRACKING SURVIVORS' AIM

***********************************************************************************************************************************************************************************/

/**
	Determines whether an attacking SI is being watched by the survivor
	@return: true if the survivor's crosshair is within the specified radius
	@param attacker: the client number of the attacking SI
	@param offsetThreshold: the radius(degrees) of the cone of detection around the straight line from the attacked survivor to the SI
**/
bool:IsTargetWatchingAttacker( attacker, offsetThreshold ) {
	new bool:isWatching = true;
	if( GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker) ) { // SI continue to hold on to their targets for a few seconds after death
		new target = GetClientAimTarget(attacker);
		if(target>0 && IsSurvivor(target) ) { 
			new aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if( aimOffset <= offsetThreshold ) {
				isWatching = true;
			} else {
				isWatching = false;
			}		
		} 
	}	
	return isWatching;
}

/**
	Calculates how much a player's aim is off another player
	@return: aim offset in degrees
	@attacker: considers this player's eye angles
	@target: considers this player's position
	Adapted from code written by Guren with help from Javalia
**/
Float:GetPlayerAimOffset( attacker, target ) {
	if( !IsClientConnected(attacker) || !IsClientInGame(attacker) || !IsPlayerAlive(attacker) )
		ThrowError("Client is not Alive."); 
	if(!IsClientConnected(target) || !IsClientInGame(target) || !IsPlayerAlive(target) )
		ThrowError("Target is not Alive.");
		
	decl Float:attackerPos[3], Float:targetPos[3];
	decl Float:aimVector[3], Float:directVector[3];
	decl Float:resultAngle;
	
	// Get the unit vector representing the attacker's aim
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0; // Restrict pitch and roll, consider yaw only (angles on horizontal plane)
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR); // extract the forward vector[3]
	NormalizeVector(aimVector, aimVector); // convert into unit vector
	
	// Get the unit vector representing the vector between target and attacker
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0; // Restrict to XY coordinates
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	// Calculate the angle between the two unit vectors
	resultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
	return resultAngle;
}