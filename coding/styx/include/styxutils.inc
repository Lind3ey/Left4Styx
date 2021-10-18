/***********************************************************************
************************* Styx Utils ********************************
************************************************************************/
#if defined _styxutils_included_
	#endinput
#endif
#define _styxutils_included_

#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define 	TEAM_SPECTATORS 	1
#define 	TEAM_SURVIVORS  	2
#define 	TEAM_INFECTED   	3

#define 	_forall(client)		for(int client=MaxClients;client>0;client--)
#define 	_allclients(i)		for(int i=MaxClients;i>0;i--)
#define		_team(%1)			GetClientTeam(%1)


#define 	MAX(%0,%1) 				%0>%1?%0:%1
#define 	MIN(%0,%1) 				%0<%1?%0:%1

enum{
	ZC_Smoker = 1,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Spitter,
	ZC_Jockey,
	ZC_Charger,
	ZC_Witch,
	ZC_Tank
};

#define IsSpectator(%0) (IsValidClient(%0) && GetClientTeam(%0) == TEAM_SPECTATORS)
#define IsSurvivor(%0) (IsValidClient(%0) && GetClientTeam(%0) == TEAM_SURVIVORS)
#define IsInfected(%0) (IsValidClient(%0) && GetClientTeam(%0) == TEAM_INFECTED)

// @return if the index is a client current in game.
#define IsClientAndInGame(%0)  IsValidClient(%0)
#define IsClient(%0)	(%0>0&&%0<=MaxClients)

stock bool IsValidClient(int client)
{
	return (IsClient(client) && IsClientInGame(client));
}

/**
 * Returns true if the survivor is hanging onto a ledge (or falling from one to their doom).
 *
 * @param client client ID
 * @return bool
 */

#define IsHangingFromLedge(%0) 	view_as<bool>(GetEntProp(%0, Prop_Send, "m_isHangingFromLedge") || GetEntProp(%0, Prop_Send, "m_isFallingFromLedge"))

/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
#define IsIncapacitated(%0)  view_as<bool>(GetEntProp(%0, Prop_Send, "m_isIncapacitated"))

/**
 * Returns true if it's the second half of round.
 *
 * @param client client ID
 * @return bool
 */
#define InSecondHalfOfRound() view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"))

/**
 * Returns the ID of the client's infected class. Use GetInfectedClassName()
 * to convert it to a string.
 *
 * @param client client ID
 * @return class ID
 */
#define _zclass(%0)  				GetEntProp(%0, Prop_Send, "m_zombieClass")
#define GetInfectedClass(%0)  		GetEntProp(%0, Prop_Send, "m_zombieClass")

#define HasThreat(%0) 	view_as<bool>(GetEntProp(%0, Prop_Send, "m_hasVisibleThreats"))

/**
*Return how many real players in the server.
*
*@return int
*/ 
stock int GetPlayerNum()
{
	int count = 0;
	_allclients(i)
		if (IsValidPlayer(i)) count++;
	return count;
}

/**
* Swarp all survivor bot to client's location.
*
* @client, swarp to who.
*/
stock void ComeBots(int client)
{
	float fOwnerOrigin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fOwnerOrigin);
	_allclients(i){
		if(i != client
		  && IsBotSurvivor(i)
		  && IsPlayerAlive(i))
			TeleportEntity(i, fOwnerOrigin, NULL_VECTOR, NULL_VECTOR);
	}
}
// @todo Set server slot.
stock void SetSlots(int slot)
{
	SetConVarInt(FindConVar("sv_maxplayers"), slot);
	SetConVarInt(FindConVar("sv_visiblemaxplayers"), -1);
	PrintToServer("[Styx] Server slots had been set to %d", slot);
}

// @return true if client is neither caped or dead.
stock bool IsFreeSurvivor(int client)
{
	if (IsSurvivor(client)
	&& IsPlayerAlive(client) 
	&& !IsIncapacitated(client) 
	&& !IsHangingFromLedge(client))
		return true;
	return false;
}

// @ return True if client is infected bot not bot.
stock bool IsPlayerZombie(int client)
{
	if (IsInfected(client) 
	&& !IsFakeClient(client))
		return true;
	return false;
}

// @ return If there is no alive survivor bot.
stock bool IsSurvivorTeamFull() 
{
	_allclients(i)
	{
		if (IsSurvivor(i)
		&& IsPlayerAlive(i) 
		&& IsFakeClient(i))
			return false;
	}
	return true;
}

// @return If there is no chance for survivor.
stock bool IsSurvivorTeamFailed()
{
	_allclients(i)
		if (IsFreeSurvivor(i)) return false;
	return true;
}

// @return if client is a human player currently in game.
stock bool IsValidPlayer(int client)
{
    if (!IsValidClient(client)) return false;
    if (IsFakeClient(client)) return false;
    return true;
}

// @return int counts of players currently connecting.
stock int ConnectingPlayers()
{
	int Clients = 0;
	_allclients(i)
	{
		if (!IsClientInGame(i) && IsClientConnected(i)) Clients++;
	}
	return Clients;
}

#define CheatGivePlayer(%0,%1)		CheatCommand(%0,"give",%1) 

/**
* @todo: Recover all survivors' health.
*/
stock void RestoreAllSurvivors()
{
	_allclients(i)
	{
        if (IsClientInGame(i) 
			&& GetClientTeam(i) == TEAM_SURVIVORS 
			&& IsPlayerAlive(i))
		{
			// RecoverHealth(i);
			CheatGivePlayer(i, "health");
        }
    }
}

stock void RestorePlayer(int client)
{
	CheatGivePlayer(client, "health");
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
}

// @return if the client is a generic admin.
stock bool IsGenericAdmin(int client)
{
	int flags = GetUserFlagBits(client);
	return ((flags & ADMFLAG_ROOT) || (flags & ADMFLAG_GENERIC));
}

/**
 * Force client to idle.
 *
 * @param client     Param description
 * @return           Return description
 */
stock void IDLEPlayer(int client)
{
	if(!IsSurvivor(client)) return;
	if(!IsPlayerAlive(client)) return;
	ChangeClientTeam(client, TEAM_SPECTATORS);
	int clientID = GetClientUserId(client);
	SetEntProp(bot, Prop_Send, "m_humanSpectatorUserID", clientID);
}

// @return int index of a client in game and is not a bot.
stock int GetAnyClient(bool onlyhuman = true)
{
	_forall(client)
		if (IsClientConnected(client) && IsClientInGame(client)){
			if(onlyhuman && IsFakeClient(client)) continue;
			return client;
		}
	return -1;
}


/****************************************
* Run a spawn command*/
stock void ServerCheatCommand(const char[] command, char[] arguments = "") // version 1.1
{	
	int scflags = GetCommandFlags(command);
	SetCommandFlags(command, scflags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", command, arguments);
	SetCommandFlags(command, scflags);
}

// run a cheat command
stock void CheatCommand(int client, const char[] command, char[] arguments = "") // version 1.1
{
	if (client && IsClientInGame(client))
	{		
		int flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, arguments);
		SetCommandFlags(command, flags);
	}
}


/**
 * @return: true if client is a special infected bot
 */
stock bool IsBotInfected(int client) {
    if (IsInfected(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}
/**
 * @return: true if client is a special survivor bot
 */
stock bool IsBotSurvivor(int client)
{
    // Check if player is a bot on the survivor team
    if (IsSurvivor(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}

stock bool IsPinningASurvivor(int client) {
	if( IsInfected(client) && IsPlayerAlive(client) ) {
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) return true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) return true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) return true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) return true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) return true; // jockey
	}
	return false;
}

stock bool IsPinned(int client) {
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) return true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) return true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) return true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) return true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) return true; // jockey
	}		
	return false;
}

/**
 * Returns survivor victim of infected attacker.
 *
 * Note: Survivor victim means the survivor player that is currently pinned
 * down by an attacker. Such as hunter, smoker, charger and jockey.
 *
 * @param client        Infected client index.
 * @return              Survivor victim index, -1 if not found.
 * @error               Invalid client index.
 */
stock int GetVictim(int client)
{
    int victim;

    /* Charger */
    victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
    if (victim > 0) return victim;

    victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
    if (victim > 0) return victim;

    /* Hunter */
    victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
    if (victim > 0) return victim;

    /* Smoker */
    victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
    if (victim > 0) return victim;

    /* Jockey */
    victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
    if (victim > 0) return victim;

    return -1;
}

/**
 * @return: true if all survivors are either incapacitated or pinned
**/
stock bool IsTeamImmobilised() {
	_forall(client) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsPinned(client) && !IsIncapacitated(client)) {		
				return false;
			} 
		} 
	}
	return true;
}

stock bool IsTeamWiped() {
	_forall(client) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsIncapacitated(client) ) {		
				return false;
			} 
		} 
	}
	return true;
}

/**
 * Returns player temporarily health.
 *
 * @param client		Client index.
 * @return				Player's temporarily health.
 * @error				Invalid client index or unable to find
 * 						pain_pills_decay_rate cvar.
 */
stock int GetPlayerTempHealth(int client)
{
	static Handle painPillsDecayCvar = INVALID_HANDLE;
	if (painPillsDecayCvar == INVALID_HANDLE)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == INVALID_HANDLE)
		{
			LogError("Unable to find pain pills decay rate cvar.");
			return 0;
			// SetFailState("Unable to find pain pills decay rate cvar.");
		}
	}

	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}

/**
 * Set players temporarily health.
 *
 * @param client		Client index.
 * @param tempHealth	Temporarily health.
 * @noreturn
 * @error				Invalid client index.
 */
stock void SetPlayerTempHealth(int client, int tempHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(tempHealth));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

/**
 * Return true if the infected is in ghost (spawn) mode.
 *
 * @param client client ID
 * @return bool
 */
#define IsGhost(%0) view_as<bool>(GetEntProp(%0, Prop_Send, "m_isGhost"))

//  return is client a ghost.
stock bool IsGhostInfected(int client)
{
	return IsInfected(client) && IsGhost(client);
}

stock bool IsTankAlive()
{
	_forall(client)
	{
		if (!IsInfected(client) ||
			!IsPlayerAlive(client) ||
			_zclass(client) != ZC_Tank)
			continue;
		return true;
	}
	return false;
}

stock bool HasAliveSpecials()
{
	_forall(client)
	{
		if (IsInfected(client)
			&& IsPlayerAlive(client)
			&& !IsGhost(client))
			return true;
	}
	return false;
}

stock int GetSpecialCount()
{
	int count = 0;
	_forall(client)
	{
		if (IsClientInGame(client) 
			&& IsInfected(client)
			&& IsPlayerAlive(client))
			count++;
	}
	return count;
}

// @Todo: Freeze or unfreeze the client.
#define FreezeClient(%1,%0)		SetEntityMoveType(%1,%0?MOVETYPE_NONE:MOVETYPE_WALK)
#define UnfreezeClient(%0)		SetEntityMoveType(%0,MOVETYPE_WALK)
// @todo Freeze of unfreeze all players.
stock void FreezeAll(bool freezeStatus = true)
{
	_forall(client)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			FreezeClient(client, freezeStatus);
		}
	}
}

// @Todo: Freeze of unfreeze the team.
stock void FreezeTeam(int team, bool freezeStatus)
{
	_forall(client)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			FreezeClient(client, freezeStatus);
		}
	}
}

// @return True if the client is biled.
stock bool IsPlayerBiled(int client)
{
	float fVomitFade = GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart");
	if (fVomitFade != 0.0 && fVomitFade + 8.0 > GetGameTime())
		return true;
	return false;
}

// @return True if the mp_gamemode == versus/community6(confogl)
stock bool IsVersusMode()
{
	char smode[16];
	GetConVarString(FindConVar("mp_gamemode"), smode, sizeof(smode));
	if(StrEqual(smode, "versus", false) 
	   || StrEqual(smode, "community6", false) 
	   || StrEqual(smode, "scavenge", false))
		return true;
	return false;
}

// @return  ALIVE counts of zombieClass
stock int AliveSpecialCount(int zombieClass)
{
	int count = 0;
	_forall(client)
	{
		if(IsAliveInfected(client) && GetInfectedClass(client) == zombieClass)
			count ++;
	}
	return count;
}

// @return first client find as a zombieClass.
stock int FindZombieByType(int zombieClass)
{
	_forall(client)
	{
		if (IsAliveInfected(client) && GetInfectedClass(client) == zombieClass)
			return client;
	}
	return -1;
}

// @return True if client is an alive infected.
stock bool IsAliveInfected(int client)
{
	if(IsInfected(client) && IsPlayerAlive(client) && !IsGhost(client))
	{
		return true;
	}
	return false;
}

// @return  counts of all common infected in the map.
stock int CommonInfectedCount()
{
	int count;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE)
	{
		count++;
	}
	return count;
}

#define GetClientSpeed(%0) GetEntPropFloat(%0,Prop_Send,"m_flLaggedMovementValue")
#define SetClientSpeed(%0,%1) SetEntPropFloat(%0,Prop_Send,"m_flLaggedMovementValue",%1)


/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
#define SIZE_OF_INT         2147483647 // without 0
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

/**
 *@return: true if client is a tank
 */
#define IsTank(%1)	(IsInfected(%1)&&GetInfectedClass(%1)==ZC_Tank)

// @return Return true if client is a bot tank.
stock bool IsBotTank(int client) {
	return IsTank(client)&&IsFakeClient(client);
}

// @return: true if client is a survivor that is not dead/incapacitated nor pinned by an SI
stock bool IsMobile(int client) {
	if (IsSurvivor(client)) {
		if (IsPinned(client) || IsIncap(client)) {
			return false;
		}
	} 
	return true;
}

// @return: true if player is a dead/incapacitated survivor
stock bool IsIncap(int client) {
	if ( IsSurvivor(client) ) {
		if (IsIncapacitated(client)) return true;
		if (!IsPlayerAlive(client)) return true;
	}
	return false;
}

/**
 * Description
 *
 * @param client     Param description
 * @return           Return true if client is a bot dominator.
 */
stock bool IsBotCapper(int client) {
	if (IsBotInfected(client)) {
		int zombieClass = GetInfectedClass(client);
		if ( zombieClass == ZC_Charger || zombieClass == ZC_Hunter || zombieClass == ZC_Jockey || zombieClass == ZC_Smoker ) {
			return true;
		}
	}
	return false;
}

/**
 * Description
 *
 * @param charger     Param description
 * @return            Return true if the charger is charging.
 */
stock bool IsCharging(int charger) {
 	// Is this AI charger charging?
	int abilityEnt = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0)
		return true;
	return false;
}

stock bool IsPouncing(int hunter){
	//
	if(view_as<bool>(GetEntProp(hunter, Prop_Send, "m_isAttemptingToPounce")))
		return true;
	else if(!IsPlayerAlive(hunter) && !(GetEntityFlags(hunter)&FL_ONGROUND))
		return true;
	return false;
}

/**
 * Sets the Absolute velocity of an entity.
 * The absolute velocity is the sum of the local
 * and base velocities. It's the actual value used to move.
 *
 * @param entity		Entity index.
 * @param vel			An 3 dim array
 * @noreturn
 */
#define SetAbsVelocity(%0,%1) TeleportEntity(%0,NULL_VECTOR,NULL_VECTOR,%1)

/**
 * Gets the Absolute velocity of an entity.
 * The absolute velocity is the sum of the local
 * and base velocities. It's the actual value used to move.
 *
 * @param entity		Entity index.
 * @param vel			An 3 dim array
 * @noreturn
 */
#define GetAbsVelocity(%0,%1) GetEntPropVector(%0,Prop_Data,"m_vecAbsVelocity",%1)

stock float GetAbilityTime(int bot)
{
	int abEntity = GetEntPropEnt(bot, Prop_Send, "m_customAbility");
	if (abEntity > 0) 
	{
		return GetEntPropFloat(abEntity, Prop_Send, "m_timestamp") - GetGameTime(); 
	}
	else return 0.0;
}
/**
 * Description
 *
 * @param ent1     Param description
 * @param ent2     Param description
 * @return         Return float distance between ent1 and ent2.
 */
stock float GetDistance(int ent1, int ent2)
{
	float vec1[3], vec2[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", vec1);
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", vec2);
	return GetVectorDistance(vec1, vec2);
}

/**
 * Teleport ent to tgt(target)
 *
 * @param ent       who to teleport
 * @param tgt       where to teleport to
 * @param cpvelocity     copy vel?
 * @return          Return false if invalid entitys.
 */
stock bool TeleportEntTo(int ent, int tgt, bool cpvelocity = false)
{
	static float fOrigin[3], fVelocity[3];
	if(!IsValidEntity(ent) || !IsValidEntity(tgt)) return false;
	GetEntPropVector(tgt, Prop_Data, "m_vecVelocity", fVelocity);
	GetEntPropVector(tgt, Prop_Data, "m_vecOrigin", fOrigin);
	if(cpvelocity)
		TeleportEntity(ent, fOrigin, NULL_VECTOR, fVelocity);
	else
		TeleportEntity(ent, fOrigin, NULL_VECTOR, NULL_VECTOR);
	return false;
}

stock void Infected_Bhop(int client,int buttons, float power)
{
	float clientEyeAngles[3];
	GetClientEyeAngles(client,clientEyeAngles);
	if(buttons & IN_BACK) { clientEyeAngles[1] += 180.0;}
	else if(buttons & IN_MOVELEFT) { clientEyeAngles[1] += 60.0; }
	else if(buttons & IN_MOVERIGHT) { clientEyeAngles[1] += -60.0; }
	Client_Push(client, clientEyeAngles, power);
}

// Velocity
enum VelocityOverride {
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

// Reserved funtion.
stock void Client_Push(int client, float clientEyeAngle[3], float power, VelocityOverride override[3]=VelocityOvr_None) 
{
	float forwardVector[3], newVel[3];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	//PrintToChatAll("Tank velocity: %.2f", forwardVector[1]);
	
	GetAbsVelocity(client,newVel);
	
	for( int i = 0; i < 3; i++ ) {
		switch( override[i] ) {
			case VelocityOvr_Velocity: {
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] *= -1.0;
				}
			}
		}
		
		newVel[i] += forwardVector[i];
	}
	
	SetAbsVelocity(client,newVel);
}

stock void Infected_Push(int client, float clientEyeAngle[3], float power) 
{
	float forwardVector[3], newVel[3];
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newVel);
	float vel = GetVectorLength(newVel);
	power += vel/2.0;
//	GetClientEyeAngles(client,clientEyeAngles);
	ScaleVector(forwardVector, power);
	newVel[0] /= 1.4;
	newVel[1] /= 1.4;
	newVel[2] /= 1.4;
	newVel[0] += forwardVector[0];
	newVel[1] += forwardVector[1];
	newVel[2] += forwardVector[2];
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
}

stock float GetPlayerVelocity(int client)
{
	// Get the player velocity:
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	return  SquareRoot(fVelocity[0]*fVelocity[0]+fVelocity[1]*fVelocity[1]);	
}

stock int GetSurvivorProximity(int client, int specified = -1)
{
	float min_dist = 100000.0;
	if(specified > 0 && IsSurvivor(specified))
	{
		return RoundToNearest(GetDistance(client, specified));
	}
	_allclients(i) 
	{
		if (IsFreeSurvivor(i)) 
		{
			float dist = GetDistance(client, i);
			if (dist < min_dist)  min_dist = dist; 
		}
	}
	return RoundToNearest(min_dist);
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock int GetClosestSurvivor(int client, int excludeSurvivor = -1 ) 
{
	int min_i = -1;
	float min_dist = 10000.0;
	_allclients(i) {
		if (IsFreeSurvivor(i) && i != excludeSurvivor)
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


stock float modulus(float a, float b) {
	while(a > b)
		a -= b;
	return a;
}

#define ammotype_smg 5
#define ammotype_shotgun	7
#define ammotype_rifle 3
#define ammotype_autosg		8

stock void RefillPrimaryClip(int client)
{
	if (!IsClientAndInGame(client))
		return;
	int weapon = GetPlayerWeaponSlot(client, 0);
	if ( !IsValidEntity(weapon) )
		return;
	int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");

	int clipSize;
	switch ( ammoType )
	{
		case ammotype_shotgun: clipSize = 8;
		case ammotype_autosg: clipSize = 8;
		case ammotype_smg: clipSize = 50;
		case ammotype_rifle: clipSize = 40;
		default: clipSize = 15;
	}

	SetEntProp(weapon, Prop_Send, "m_iClip1", clipSize);
}

stock bool Weapon_IsSmg(int weapon)
{
	return GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType") == ammotype_smg;
}

stock bool Weapon_IsShotGun(int weapon)
{
	return GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType") == ammotype_shotgun;
}

// left4dhooks should be include to use this function.
stock void RunDirectorScript(const char[] scode, any:...)
{
	static char sbuffer[(1<<8)];
	VFormat(sbuffer, 1<<8, scode, 2);
	L4D2_ExecVScriptCode(sbuffer);
}

/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
stock void L4D2_RunScript(const char[] sCode, any:...)
{
	/*static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
		{
			LogMessage("Could not create 'logic_script'");
			return;
		}
		DispatchSpawn(iScriptLogic);
	}*/
	static char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	L4D2_ExecVScriptCode(sBuffer);
	/*SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");*/
}

// not a total correct one, but usable.
stock bool IsOfficialMap()
{
	char sBuffer[32];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	if(sBuffer[0] != 'c' ) return false;
	if(sBuffer[1] > '9' || sBuffer[1] < '0') return false;
	return true;
}

stock void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags, give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

stock void LogPlayerAction(int client, const char[] reason)
{
	char sBuffer[128];
	GetClientAuthId(client, AuthId_Steam2, sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "%N(%s):%s", client, sBuffer, reason);
	LogToFile("addons/sourcemod/logs/styx.log", "===============================================");
	LogToFile("addons/sourcemod/logs/styx.log", sBuffer);
}

stock bool IsHumansOnServer()
{
	_allclients(i)
	{
		if(IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}

//***********************stock************************
stock int GetHumanCount()
{
	int humans = 0;
	_allclients(i)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			humans++;
		}
	}
	return humans;
}

stock void CutStringAfter(char[] str, char search)
{
	int len = strlen(str);
	for (int i = 0; i < len; i++) {
			if (str[i] == search){
				str[i] = '\0';
				return;
			}
		}
}

stock void ReplaceCharIn(char[] str, char search, char sub)
{
	int len = strlen(str);
	for (int i = 0; i < len; i++) {
			if (str[i] == search)
				str[i] = sub;
		}
}

#define CMD_ATTACK 		0
#define CMD_MOVE 		1
#define CMD_RETREAT 	2
#define CMD_RESET 		3
stock void CmdBotAttack(int bot, int client)
{
	if (IsBotInfected(bot) && IsSurvivor(client))
	{
		int botID = GetClientUserId(bot);
		int targetID = GetClientUserId(client);		
		L4D2_RunScript("CommandABot({cmd = %i,bot = GetPlayerFromUserID(%i),target = GetPlayerFromUserID(%i)})", CMD_ATTACK, botID, targetID); // attack
	}
}

stock void CmdBotRetreat(int bot)
{
	if (IsBotInfected(bot))
	{
		int botID = GetClientUserId(bot);
		int target = GetAFreeSurvivor(); 
		if(target < 1) return;
		int targetID = GetClientUserId(target);		
		L4D2_RunScript("CommandABot({cmd = %i,bot = GetPlayerFromUserID(%i),target = GetPlayerFromUserID(%i)})", CMD_RETREAT, botID, targetID); // attack
	}
}

stock void CmdBotMoveTo(int bot, const float pos[3])
{
	if (IsBotInfected(bot))
	{
		int botID = GetClientUserId(bot);
		L4D2_RunScript("CommandABot({cmd = %i,bot = GetPlayerFromUserID(%i)}, pos = Vector(%.1f, %.1f, %.1f))", CMD_MOVE, botID, pos[0], pos[1], pos[2]); // Move
	}
}

stock void CmdBotReset(int bot)
{
	if (IsBotInfected(bot))
	{
		int botID = GetClientUserId(bot);
		L4D2_RunScript("CommandABot({cmd = %i,bot = GetPlayerFromUserID(%i)})", CMD_RESET, botID); // attack
	}
}

#pragma newdecls optional