#pragma semicolon 1

#define BoostForward 	60.0 // Bhop
#define Tank_boost		1.10

int iTankPunched[MAXPLAYERS+1],
	iTankBoostHealth 	= 3000;

bool bTankAllowBhop[MAXPLAYERS+1];

ConVar hCvarTankPunch;

public Tank_OnModuleStart() 
{
	HookEvent("tank_spawn", 			Event_TankSpawn,	EventHookMode_Post);
	HookEvent("player_bot_replace", 	OnTankBotReplace,		EventHookMode_Post);
	HookEvent("player_hurt", 			Event_Hurt, 		EventHookMode_Post);

	hCvarTankPunch = CreateConVar("l4d2_tankpunch_bhop", 	"1", 	"N punch close bhop.");
}

public Tank_OnModuleEnd() {

}

// Tank bhop and blocking rock throw
public Action:Tank_OnPlayerRunCmd( tank, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) 
{
	if(bTankAllowBhop[tank]) {
		if(GetClientHealth(tank) < iTankBoostHealth) {
			bTankAllowBhop[tank] = false;
			return Plugin_Continue;	
		}
		int iSurvivorsProximity = GetSurvivorProximity(tank);

		// Near survivors
		if( HasThreat(tank) && (420 > iSurvivorsProximity > 120) && GetPlayerVelocity(tank) > 190.0 ) {
			if (GetEntityFlags(tank) & FL_ONGROUND) {
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				Infected_Bhop(tank, buttons, BoostForward);
			} else{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
	}
	return Plugin_Continue;	
}

public Action:OnTankBotReplace(Handle:event, const String: name[], bool:dontBroadcast)
{	
	new formerTank = GetClientOfUserId(GetEventInt(event, "player"));
	new newTank = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if (formerTank != 0 && IsTank(newTank))
	{
		bTankAllowBhop[newTank] = false;
	}
}

public Action Event_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker 	= GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientAndInGame(attacker) || !IsClientAndInGame(victim)) return Plugin_Handled;
	if(IsSurvivor(victim) && !IsIncapacitated(victim) && IsBotTank(attacker))
	{
		// Tank Punched (not incaped survivor);
		iTankPunched[attacker] ++;
		if(bTankAllowBhop[attacker]){
			bTankAllowBhop[attacker] = (iTankPunched[attacker] >= GetConVarInt(hCvarTankPunch));
		}
	}
	return Plugin_Handled;
}

public Action: Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientInGame(client) && IsFakeClient(client))
	{
		iTankPunched[client] = 0;
		iTankBoostHealth = GetClientHealth(client) / 2;
		if(GetConVarInt(hCvarTankPunch) > 0) bTankAllowBhop[client] = true;
		else bTankAllowBhop[client] = false;
	}
}