#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <styxframe>
#include <styxutils>
#include <colors>
#include <left4dhooks>

#define COLOR_GOLD	{254, 225, 24, 255}

#define 	RAGE_TRACK_INTERVAL	0.33

// new Handle: cvar_tankSpeedvs;

new bool: 	g_bPlayerControlled 	= false;
new bool: 	g_bRagemeterRefilled 	= false;
static bool: bIsTankInPlay			= false;

new             bool:   g_bEnabled                  = true;
new             bool:   g_bAnnounceTankDamage       = false;            // Whether or not tank damage should be announced
new                     g_iOffset_Incapacitated     = 0;                // Used to check if tank is dying
new                     g_iTankClient               = 0;                // Which client is currently playing as tank
new                     g_iLastTankHealth           = 0;                // Used to award the killing blow the exact right amount of damage
new                     g_iSurvivorLimit            = 4;                // For survivor array in damage print
new                     g_iDamage[MAXPLAYERS + 1];
new             Float:  g_fMaxTankHealth            = 6750.0;
new             Handle: g_hCvarEnabled              = INVALID_HANDLE;
new             Handle: g_hCvarTankHealth           = INVALID_HANDLE;
new             Handle: g_hCvarSurvivorLimit        = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "Styx tank controll.", 
	author = "Lind3ey", 
	description = "Styx tank controll. speed, frustration, announce.", 
	version = "1.0", 
	url = ""
};

public OnPluginStart() 
{
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_Post);
	HookEvent("tank_spawn", 			Event_TankSpawn,	EventHookMode_Post);
	HookEvent("player_death",			EventHook:Event_Death,		EventHookMode_Post);
	     
	bIsTankInPlay = false;
	g_bAnnounceTankDamage = false;
	g_iTankClient = 0;
	ClearTankDamage();
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled", "1", "Announce damage done to tanks when enabled", FCVAR_SPONLY, true, 0.0, true, 1.0);
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_hCvarTankHealth = FindConVar("z_tank_health");
	
	HookConVarChange(g_hCvarEnabled, Cvar_Enabled);
	HookConVarChange(g_hCvarSurvivorLimit, Cvar_SurvivorLimit);
	HookConVarChange(g_hCvarTankHealth, Cvar_TankHealth);
	
	g_bEnabled = GetConVarBool(g_hCvarEnabled);
	CalculateTankHealth();
	
	g_iOffset_Incapacitated = FindSendPropInfo("Tank", "m_isIncapacitated");
}

public OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
	ClearTankDamage();
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay 			= false;
	g_bPlayerControlled 	= false;
	g_bRagemeterRefilled 	= false; 
	ClearTankDamage(); // Probably redundant
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!bIsTankInPlay) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim != g_iTankClient) return;
	
	// Award the killing blow's damage to the attacker; we don't award
	// damage from player_hurt after the tank has died/is dying
	// If we don't do it this way, we get wonky/inaccurate damage values
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker && IsClientInGame(attacker)) g_iDamage[attacker] += g_iLastTankHealth;
	
	// Damage announce could probably happen right here...
	CreateTimer(0.1, Timer_CheckTank, victim); // Use a delayed timer due to bugs where the tank passes to another player
	CreateTimer(0.1, CheckTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

#define TANK_SPAWN_DELAY 2.424

public Action:CheckTank(Handle timer)
{
	if(FindTankClient(false) == -1)
	{
		bIsTankInPlay 			= false;
		g_bPlayerControlled 	= false;
		g_bRagemeterRefilled 	= false;
	}
}

public Action: Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay = true;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientInGame(client) && GetClientTeam(client) && !IsFakeClient(client))
	{
		if(!Styx_IsVersus()) { CPrintToChatAllEx(client, "{green}☣ {teamcolor}%N {olive}has become the {green}Tank", client);}
		// SetConVarInt(cvar_tankSpeedvs,  GetConVarInt(cvar_tankSpeed_pz));
		g_bPlayerControlled = true;
		g_bRagemeterRefilled = false;
		if(Styx_IsVersus()) return Plugin_Handled;
		CreateTimer(RAGE_TRACK_INTERVAL, Rage_Tracker, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); //Forward in left4downtown can't be called when tank has no player teamates.
	}
	else
	{
		if(g_bPlayerControlled)
			g_bPlayerControlled = false;
		else {
			CPrintToChatAll("{green}☠ {red}Tank {olive}has spawned!");
			EmitSoundToAll("ui/pickup_secret01.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
		}
	}
    // New tank, damage has not been announced
	g_bAnnounceTankDamage = true;
	bIsTankInPlay = true;
    // Set health for damage print in case it doesn't get set by player_hurt (aka no one shoots the tank)
	g_iLastTankHealth = GetClientHealth(client);
	return Plugin_Handled;
}

stock Action: Rage_Tracker(Handle:timer, any:client) 
{
	if(!bIsTankInPlay) return Plugin_Stop;
	if(!g_bRagemeterRefilled && IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if(L4D2Direct_GetTankPassedCount() == 1 && GetTankFrustration(client) > 0 && GetTankFrustration(client) < 6)
		{
			CreateTimer(RAGE_TRACK_INTERVAL, Timer_Refill, client, TIMER_FLAG_NO_MAPCHANGE);
			g_bRagemeterRefilled = true;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	else if(!g_bRagemeterRefilled && FindTankClient(true) != -1)
	{	
		CreateTimer(RAGE_TRACK_INTERVAL, Rage_Tracker, FindTankClient(true), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		LogToFile("addons/sourcemod/logs/styx.log", "(Tank controll) Found tank controll swaped, rebuild tracker.");
	}
	return Plugin_Stop;
}

public Action:Timer_Refill(Handle timer, any:client)
{
	if( !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)) return Plugin_Handled;
	
	SetTankFrustration(client, 100);
	L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
	
	PrintHintText(client, "(Frustration->2nd) Rage Meter Refilled.");
	
	decl String: sMsg[256];
	Format(sMsg, sizeof(sMsg), "{default}[Tank({red}%N{default})]({olive}Frustration->2nd{default}) Rage Meter Refilled.", client);
	
	CPrintToChatTeam(TEAM_INFECTED, sMsg);
	LogToFile("addons/sourcemod/logs/styx.log", "(Tank controll)Tank player %N Rage Meter refilled.", client);
	return Plugin_Handled;
}

stock GetTankFrustration(iTankClient) {
    return (100 - GetEntProp(iTankClient, Prop_Send, "m_frustration"));
}

stock SetTankFrustration(iTankClient, iFrustration) {
    if (iFrustration < 0 || iFrustration > 100) {
        return;
    }
    
    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}

stock FindTankClient(bool: nobot = false) 
{
    for (new i = 1; i <= MaxClients; i++) 
    {
        if ( IsClientInGame(i)
        && GetClientTeam(i) == TEAM_INFECTED
        && GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_Tank) 
        {
			if(nobot && IsFakeClient(i)) continue;
			return i;
        }
    }
    return -1;
}

stock CPrintToChatTeam(team, char[] sMsg)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
		{
			CPrintToChat(i, sMsg);
		}
	}
}

public OnClientDisconnect_Post(client)
{
        if (!bIsTankInPlay || client != g_iTankClient) return;
        CreateTimer(0.1, Timer_CheckTank, client); // Use a delayed timer due to bugs where the tank passes to another player
}
     
public Cvar_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bEnabled = StringToInt(newValue) > 0 ? true:false;
}
     
public Cvar_SurvivorLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_iSurvivorLimit = StringToInt(newValue);
}
     
public Cvar_TankHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
    CalculateTankHealth();
}
     
CalculateTankHealth()
{
        g_fMaxTankHealth = GetConVarFloat(g_hCvarTankHealth) * 1.5;
        if (g_fMaxTankHealth <= 0.0) g_fMaxTankHealth = 1.0; // No dividing by 0!
}
     
public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bIsTankInPlay) return; // No tank in play; no damage to record
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim != GetTankClient() ||        // Victim isn't tank; no damage to record
			IsTankDying()                                   // Something buggy happens when tank is dying with regards to damage
									) return;
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	// We only care about damage dealt by survivors, though it can be funny to see
	// claw/self inflicted hittable damage, so maybe in the future we'll do that
	if (attacker == 0 ||                                                    // Damage from world?
			!IsClientInGame(attacker) ||                            // Not sure if this happens
			GetClientTeam(attacker) != TEAM_SURVIVORS
									) return;
	
	g_iDamage[attacker] += GetEventInt(event, "dmg_health");
	g_iLastTankHealth = GetEventInt(event, "health");
}

// When survivors wipe or juke tank, announce damage
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
        // But only if a tank that hasn't been killed exists
        if (g_bAnnounceTankDamage)
        {
                PrintRemainingHealth();
                PrintTankDamage();
        }
        // ClearTankDamage();
}
     
public Action:Timer_CheckTank(Handle:timer, any:oldtankclient)
{
        if (g_iTankClient != oldtankclient) return; // Tank passed
     
        new tankclient = FindTankClient();
        if (tankclient && tankclient != oldtankclient)
        {
                g_iTankClient = tankclient;
     
                return; // Found tank, done
        }
     
        if (g_bAnnounceTankDamage) PrintTankDamage();
        bIsTankInPlay = false; // No tank in play
}
     
bool:IsTankDying()
{
        new tankclient = GetTankClient();
        if (!tankclient) return false;
     
        return bool:GetEntData(tankclient, g_iOffset_Incapacitated);
}
     
PrintRemainingHealth()
{
        if (!g_bEnabled) return;
        new tankclient = GetTankClient();
        if (!tankclient) return;
     
        decl String:name[MAX_NAME_LENGTH];
        if (IsFakeClient(tankclient)) name = "Dummy";
        else GetClientName(tankclient, name, sizeof(name));
        PrintToChatAll("\x01[\x04✘\x01] Tank (\x05%s\x01) had \x04%d\x01 health remaining", name, g_iLastTankHealth);
}
     
PrintTankDamage()
{
	if (!g_bEnabled) return;
	if(IsFakeClient(g_iTankClient))
		PrintToChatAll("\x01[\x04✔\x01] \x05Damage \x01dealt to tank(\x05Dummy\x01):");
	else
		PrintToChatAll("\x01[\x04✔\x01] \x05Damage \x01dealt to tank(\x05%N\x01):",g_iTankClient);
	CreateTimer(0.1, Delay_PrintDmg, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Delay_PrintDmg(Handle timer)
{
        new client;
        new percent_total; // Accumulated total of calculated percents, for fudging out numbers at the end
        new damage_total; // Accumulated total damage dealt by survivors, to see if we need to fudge upwards to 100%
        new survivor_index = -1;
        new survivor_clients[g_iSurvivorLimit]; // Array to store survivor client indexes in, for the display iteration
        decl percent_damage, damage;
        for (client = 1; client <= MaxClients; client++)
        {
                if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVORS) continue;
                survivor_index++;
                survivor_clients[survivor_index] = client;
                damage = g_iDamage[client];
                damage_total += damage;
                percent_damage = GetDamageAsPercent(damage);
                percent_total += percent_damage;
        }
        SortCustom1D(survivor_clients, g_iSurvivorLimit, SortByDamageDesc);
     
        new percent_adjustment;
        // Percents add up to less than 100% AND > 99.5% damage was dealt to tank
        if ((percent_total < 100 &&
                float(damage_total) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0)))
                )
        {
                percent_adjustment = 100 - percent_total;
        }
     
        new last_percent = 100; // Used to store the last percent in iteration to make sure an adjusted percent doesn't exceed the previous percent
        decl adjusted_percent_damage;
        for (new i; i <= survivor_index; i++)
        {
                client = survivor_clients[i];
                damage = g_iDamage[client];
                percent_damage = GetDamageAsPercent(damage);
                // Attempt to adjust the top damager's percent, defer adjustment to next player if it's an exact percent
                // e.g. 3000 damage on 6k health tank shouldn't be adjusted
                if (percent_adjustment != 0 && // Is there percent to adjust
                        damage > 0 &&  // Is damage dealt > 0%
                        !IsExactPercent(damage) // Percent representation is not exact, e.g. 3000 damage on 6k tank = 50%
                        )
                {
                        adjusted_percent_damage = percent_damage + percent_adjustment;
                        if (adjusted_percent_damage <= last_percent) // Make sure adjusted percent is not higher than previous percent, order must be maintained
                        {
                                percent_damage = adjusted_percent_damage;
                                percent_adjustment = 0;
                        }
                }
                CPrintToChatAll("{default}[{blue}%2d{olive}％{default}] {olive}%4d: {blue}%N", percent_damage, damage, client);
        }
		
        ClearTankDamage();
}

ClearTankDamage()
{
        g_iLastTankHealth = 0;
        for (new i = 1; i <= MaxClients; i++) { g_iDamage[i] = 0; }
        g_bAnnounceTankDamage = false;
}
     
     
GetTankClient()
{
        if (!bIsTankInPlay) return 0;
     
        new tankclient = g_iTankClient;
     
        if (!IsClientInGame(tankclient)) // If tank somehow is no longer in the game (kicked, hence events didn't fire)
        {
                tankclient = FindTankClient(); // find the tank client
                if (!tankclient) return 0;
                g_iTankClient = tankclient;
        }
     
        return tankclient;
}
     
GetDamageAsPercent(damage)
{
        return RoundToFloor(float(damage)/g_fMaxTankHealth*100.0);
}
     
bool:IsExactPercent(damage)
{
        return (FloatAbs(float(GetDamageAsPercent(damage)) - float(damage)/g_fMaxTankHealth*100.0) < 0.001) ? true:false;
}
     
public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
        // By damage, then by client index, descending
        if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
        else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
        else if (elem1 > elem2) return -1;
        else if (elem2 > elem1) return 1;
        return 0;
}