#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <readyup>
#include <left4dhooks>

new Handle: hCvarRoundLimit;
new Handle: hCvarWitchLimit;
new Handle: hCvarWitchRange; 
new Handle: hCvarFinale; 
new Handle: hCvarSpawnInterval;
new Handle: hCvarBrideChance;

static		WitchBrideChance	= 30;
static		iWitchCount			= 0;
new bool: 	bIsRoundActive 		= false;

public Plugin: myinfo = 
{
	name = "L4D2 Witch spawner",
	author = "Lind3ey",  
	description = "Many witches on map",
	version = "2.33"	
};

public OnPluginStart()
{	
	hCvarRoundLimit 		= CreateConVar("ws_witch_limit_round", 	"999", 		"Sets the limit for witches spawned. If 0, the plugin will not check count witches", FCVAR_NONE);
	hCvarWitchLimit 		= CreateConVar("ws_witch_limit_alive", 	"2", 		"Sets the limit alive witches. If 0, the plugin will not check count alive witches", FCVAR_NONE);
	hCvarWitchRange 		= CreateConVar("ws_witch_distance", 	"1500", 	"The range from survivors that witch should be removed.", FCVAR_NONE); 
	hCvarFinale 			= CreateConVar("ws_witch_after_finale", "1", 		"enable spawn witches after finale start.", FCVAR_NONE, true, 0.0, true, 1.0); 
	hCvarSpawnInterval		= CreateConVar("ws_witch_interval",		"60.0",		"wtf", FCVAR_SPONLY);
	hCvarBrideChance		= CreateConVar("ws_bride_chance",		"0.30",		"bride chance", FCVAR_SPONLY);
	
	HookConVarChange(hCvarBrideChance, Cvar_BrideChance);
	
	HookEvent("witch_spawn", 	Event_WitchSpawned, EventHookMode_PostNoCopy);	
	HookEvent("round_start", 	Event_RoundStart);
	HookEvent("round_end", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
	HookEvent("finale_start", 	Event_FinaleStart); 
	HookEvent("witch_killed",	EventHook:HealBot);
}

public OnMapStart()
{
	PrecacheModel("models/infected/witch.mdl");
	PrecacheModel("models/infected/witch_bride.mdl");
	StartTimer();
}
public Cvar_BrideChance(Handle:convar, const String:oldValue[], const String:newValue[])
{ 
	WitchBrideChance = RoundToFloor(StringToFloat(newValue) * 100);
}

public OnLeftSafeArea(){ bIsRoundActive = true; }

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{ 
	bIsRoundActive 	= false; 
	iWitchCount 	= 0;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) 
{ 
	bIsRoundActive 	= false; 
	iWitchCount 	= 0;
}

public Action:Event_FinaleStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(!GetConVarBool(hCvarFinale))
		bIsRoundActive = false; 
}

public Action:Event_WitchSpawned(Handle:event, const String:name[], bool:dontBroadcast) // version 1.3
{
	iWitchCount++; 
	new witch = GetEventInt(event, "witchid");
	if(GetURandomInt() % 100 < WitchBrideChance)
	{
		SetEntityModel(witch, "models/infected/witch_bride.mdl");
	}
}

// Noob BOT
#define TEAM_SURVIVORS 2
public HealBot()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
		{
			AddHealth(i, 3);
		}
	}
}

public StartTimer()
{	
	new Float: SpawnInterval = GetConVarFloat(hCvarSpawnInterval);
	new ispawnnum			= GetConVarInt(hCvarWitchLimit);
	CreateTimer(SpawnInterval, SpawnWitches, ispawnnum, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public GetCountAliveWitches() // version 1.1 & version 1.4
{	
	new countWitchAlive = 0;	
	new index = -1;
	new range = GetConVarInt(hCvarWitchRange);
	while ((index = FindEntityByClassname2(index, "witch")) != -1)
	{		
		if (FarFromSurvivors(index, range)) { AcceptEntityInput(index, "Kill"); iWitchCount--; }
		else countWitchAlive++;
	}	
	return countWitchAlive;
}

#define 	TICK_TIME			1.50
static		iSpawnCount			= 0;
public Action: SpawnWitches(Handle:timer, numbers)
{
	if (!bIsRoundActive) return Plugin_Continue;
	if (iWitchCount >= GetConVarInt(hCvarRoundLimit)){
		// PrintToServer("Witches Limit reach");
		return Plugin_Continue;
	}
	iSpawnCount = numbers;
	SetWitchLimit(numbers);
	CreateTimer(0.1, 		SpawnAWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(TICK_TIME, 	SpawnAWitch, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action:SpawnAWitch(Handle:timer)
{
	if (iWitchCount >= GetConVarInt(hCvarRoundLimit)) return Plugin_Stop;
	if(GetCountAliveWitches() >=  GetConVarInt(hCvarWitchLimit)) return Plugin_Stop;
	new client = GetAnyClient();
	if(client)
	{
		SpawnCommand(client, "z_spawn_old", "witch auto");
		iSpawnCount--;
	}
	if(iSpawnCount > 0)
		return Plugin_Continue;
	else
		return Plugin_Stop;
}

/**********
* Unlock witch limit by directoroptions.
**/
#define 	modeDOPS			"g_ModeScript.DirectorOptions"
#define		mapDOPS				"g_MapScript.LocalScript.DirectorOptions"
public Action:SetWitchLimit(limit)
{
	decl String:sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "%s.WitchLimit <- %d", modeDOPS, limit);
	L4D2_RunScript(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%s.WitchLimit <- %d", mapDOPS, limit);
	L4D2_RunScript(sBuffer);
	return Plugin_Handled;
}

#define TEAM_SURVIVORS	2
stock bool:FarFromSurvivors(entity, range)
{
	decl Float: entityPos[3], Float: PlayerPos[3], Float: distance;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			GetClientAbsOrigin(i, PlayerPos);
			distance = GetVectorDistance(entityPos, PlayerPos);
			if (distance < range) return false;											
		}
	}
	return true;
}

stock FindEntityByClassname2(startEnt, const String:classname[]) // version 1.4
{
	while (startEnt < GetMaxEntities() && !IsValidEntity(startEnt)) startEnt++;
	return FindEntityByClassname(startEnt, classname);
}

stock GetAnyClient()
{
	new i;
	for (i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i))) 
			return i;
	return 0;
}

/****************************************
* Run a spawn command*/
stock SpawnCommand(client, String:command[], String:arguments[] = "") // version 1.1
{
	if (client)
	{		
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, arguments);
		SetCommandFlags(command, flags);
	}
}
/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			PrintToServer("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

stock AddHealth(client, perm)
{
	new health = GetEntProp(client, Prop_Send, "m_iHealth") + perm;
	if(health > 100) health = 100;
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}