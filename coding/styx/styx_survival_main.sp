/*******************************************
** 1. Gamemode styxsurvival: need addons vpk file.
** 2. Six waves survival, 3 Tanks spawn total.
** 3. Auto Heal to decrease diffculty.
** 4. SI DROP LOOT, TANK DROP MEDKIT OF DEFB.
** 5. Need mutation addons name styxsurvival, need readyup_survival.smx.
***********/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#include <styxutils>
#include <timescale>

#pragma newdecls required

#define		Next_Wave_Delay		20.0
#define		Reward_Delay		3.0
#define		MaxWaves			6
#define		iNowSpawnTank		12

#define 	REWARDTIME			60.0
#define 	AUTOHEALMAXHEALTH	42
#define 	HEAL_INTERVAL		1.0
#define 	HEAL_PERINTER		1

#define		STAGE_START			0
#define 	STAGE_STOP			1
#define  	SLAY_COUNTDOWN		3

bool 		bAllowSpawnTank 	= false,
			bWaveAllowTank		= false,
			inRelaxing			= true;

int iWaveSpawnLeft 			= 0,
	iWaveInfectedLeft		= 0,
	iCurrentWaveIndex 		= 0,
	iTimeNextwave			= 20,
	// imobilisedChecking		= SLAY_COUNTDOWN,
	iTankWave[2];

static Handle hTimerHeal;
static Address pZombieManager = Address_Null;
static ConVar mp_gamemode;

char hostfile[16] = "xyts";
static const char MapList[17][] = {
	"c1m4_atrium",
	"c2m1_highway",
	"c2m4_barns",
	"c2m5_concert",
	"c3m1_plankcountry",
	"c3m4_plantation",
	"c4m1_milltown_a",
	"c4m2_sugarmill_a",
	"c5m2_park",
	"c5m5_bridge",
	"c6m1_riverbank",
	"c6m2_bedlam",
	"c6m3_port",
	"c7m1_docks",
	"c7m3_port",
	"c8m2_subway",
	"c8m5_rooftop"
};

static const char droplist[5][] = {
	"pain_pills",
	"adrenaline",
	"molotov",
	"pipe_bomb",
	"vomitjar"
};

public Plugin myinfo = 
{
    name = "Styx Survival Concept",
    author = "Lind3ey",
    description = "Survival Hardcore",
    version = "8.12",
}

public void OnPluginStart()
{
	Handle gamedata = LoadGameConfigFile("left4dhooks.l4d2");
	if (!gamedata)
	{
		PrintToServer("Left4DHooks gamedata missing or corrupt");
	}
	else
	{
		pZombieManager = GameConfGetAddress(gamedata, "ZombieManager");
		if (!pZombieManager)
		{
			PrintToServer("Couldn't find the 'ZombieManager' address");
		}
	}

	HookEvent("player_death", 			OnDeath,			EventHookMode_Post);
	HookEvent("round_start", 			RoundStart,			EventHookMode_Post);
	HookEvent("survival_round_start", 	OnStart,			EventHookMode_Post);
	HookEvent("round_end", 				OnRoundEnd,			EventHookMode_Post);
	HookEvent("total_ammo_below_40", 	OnAlmostOut,		EventHookMode_Post);
	HookEvent("tank_spawn", 			OnTank_Spawn,		EventHookMode_Post);
	HookEvent("player_spawn",			OnSpawn,			EventHookMode_Post);
	HookEvent("weapon_reload",			OnReload,			EventHookMode_Post);
	HookEvent("player_team",			OnPlayerTeam,		EventHookMode_Post);
	
	//Sound Hook
	AddNormalSoundHook(view_as<NormalSHook>(SoundHook));
	RegConsoleCmd("sm_tank", 		TankCmd);
	RegConsoleCmd("sm_cur", 		CurCmd);
	RegAdminCmd("sm_mark",          Cmd_MarkAsInfected, 	ADMFLAG_GENERIC);
	// RegAdminCmd("sm_glow", GlowCmd, ADMFLAG_ROOT);

	mp_gamemode = FindConVar("mp_gamemode");
}

public void OnMapStart()
{
	inRelaxing		 	= true;
	bAllowSpawnTank 	= false;
	bWaveAllowTank 		= false;
	iWaveSpawnLeft 		= 0;
	iWaveInfectedLeft	= 0;
	iCurrentWaveIndex 	= 0;
	// imobilisedChecking = SLAY_COUNTDOWN;
	
	// Event sound 
	PrecacheSound("ui/pickup_secret01.wav");					// Tank spawn
	PrecacheSound("music/safe/themonsterswithout_s.wav");		// Mission success
	PrecacheSound("ui/bigreward.wav");							// Wave Success

	GetConVarString(FindConVar("hostfile"), hostfile, sizeof(hostfile));
}

public void OnClientPutInServer(int client)
{
    CreateTimer(2.0, WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TankCmd(int client, int args)
{
	CPrintToChatAll("{default}<{olive}Spawn{default}> {red}Tank {default}waves: {red}%d %d %d", iTankWave[0], iTankWave[1], MaxWaves);
}

public Action CurCmd(int client, int args)
{
	if(iWaveInfectedLeft > 0)
	{
		CPrintToChat(client, "{default}<{olive}Wave{default}> @ {olive}%d/%d, {green}%d {red}SI {olive}remaining.",iCurrentWaveIndex, MaxWaves, iWaveInfectedLeft);
		if(bWaveAllowTank && iWaveInfectedLeft > iNowSpawnTank)
		{
			CPrintToChat(client, "{default}[{green}!{default}] {red}Tank{olive} will spawn in this wave!");
		}
	}
	else
	{
		if(inRelaxing && iCurrentWaveIndex < MaxWaves && iCurrentWaveIndex > 0)
		{
			CPrintToChat(client, "{default}<{olive}Wave{default}> next wave @ {olive}%d/%d. {green}%d {red}SIs {olive}on total.",iCurrentWaveIndex + 1, MaxWaves, GetWaveTotal(iCurrentWaveIndex + 1));
		}
	}
}

public Action Cmd_MarkAsInfected(int client,int args)
{
	ChangeClientTeam(client, TEAM_INFECTED);
	return Plugin_Handled;
}


public Action OnPlayerTeam(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Handled;

	if(mp_gamemode != INVALID_HANDLE)
		SendConVarValue(client, mp_gamemode, "coop");
	return Plugin_Handled;
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	inRelaxing 			= true;
	bAllowSpawnTank 	= false;
	bWaveAllowTank		= false;
	iCurrentWaveIndex 	= 0;
	// imobilisedChecking = SLAY_COUNTDOWN;
	iTankWave[0] 		= GetRandomInt(2, 3);
	iTankWave[1] 		= GetRandomInt(4, 5);

	if(hTimerHeal != INVALID_HANDLE)
		CloseHandle(hTimerHeal);
}

public Action OnStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Initiating......
	inRelaxing 			= false;
	bAllowSpawnTank 	= false;
	bWaveAllowTank		= false;
	iCurrentWaveIndex 	= 1;
	iWaveSpawnLeft 		= GetWaveTotal(iCurrentWaveIndex);
	iWaveInfectedLeft	= iWaveSpawnLeft;

	DirectorStage(STAGE_START);
	CPrintToChatAll("{green}# {blue}Survive all waves!");
	CPrintToChatAll("{green}# {olive}Wave: {blue}%d/%d. {olive}Incoming!", iCurrentWaveIndex, MaxWaves);
	CPrintToChatAll("{green}# {blue}Tank {olive}waves: {blue}%d %d %d", iTankWave[0], iTankWave[1], MaxWaves);

	// hTimerHeal 		= CreateTimer(HEAL_INTERVAL, Timer_CheckHeal, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	ServerCommand("sm_stormstart");
}

// Auto fill bots' ammo
public Action OnAlmostOut(Handle event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(player) && IsFakeClient(player))
        CheatGivePlayer(player, "ammo");
}

public Action OnReload(Handle event, const char[] name, bool dontBroadcast)
{
	if(iWaveSpawnLeft <= 0 && !inRelaxing)
		CheckWaveEnd();
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	bAllowSpawnTank 	= false;
	bWaveAllowTank		= false;
	iWaveSpawnLeft 		= 0;
	iWaveInfectedLeft	= 0;
	iCurrentWaveIndex 	= 0;
	inRelaxing 			= true;
}

public Action SoundHook(int[] clients, int &numClients, char[] sample,int &entity)
{
	if (iWaveSpawnLeft <= 0 && StrContains(sample, "mega_mob_incoming", false) != -1)
		return Plugin_Stop;
	return Plugin_Continue;
}

public Action Timer_NextMap(Handle timer)
{
	int nextMap = GetNextMapIndex();
	L4D_RestartScenarioFromVote(MapList[nextMap]);
	return Plugin_Stop;
}

public Action WelcomePlayer(Handle timer, any client)
{
	if(!client || !IsClientInGame(client)) return Plugin_Handled;
	CPrintToChat(client, "{default}[{blue}Commands{default}] {olive}!spec/!join/!match/!rmatch/!vote/!bot"); 
	return Plugin_Handled;
}

public Action ForceRoundEnd()
{
	inRelaxing = true;
	SetConVarInt(FindConVar("god"), 1);
	DirectorStage(STAGE_STOP);
	
	Nb_DeleteAll();
	TimeScale(0.4, 0.8);
	CPrintToChatAll("{blue}* Survival Mission success! {olive}Get Ready for next Map.");
	EmitSoundToAll("music/safe/themonsterswithout_s.wav");
	
	CreateTimer(8.0, Timer_NextMap, _, TIMER_FLAG_NO_MAPCHANGE);

	Handle event = CreateEvent("round_end");
	FireEvent(event);

	ServerCommand("sm_stormstop");
}

public void CheckWaveEnd()
{
	if(iWaveSpawnLeft <= 0 && !HasAliveSpecials())
	{
		if(iCurrentWaveIndex == MaxWaves)
		{
			ForceRoundEnd();
			return;
		}
		
		inRelaxing 	= true;
		DirectorStage(STAGE_STOP);
		Nb_DeleteAll();
		TimeScale(0.4, 0.8);
		iTimeNextwave = RoundToNearest(Next_Wave_Delay);
		CreateTimer(1.0, Timer_NextWave, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		PrintHintTextToAll("Round %d Clear!", iCurrentWaveIndex);
		PrintToChatAll("\x01[\x04!\x01]\x05 wave \x04%d \x05cleared. 20 seconds \x01before next wave.", iCurrentWaveIndex);
		ServerCommand("sm_stormstop");
	}
	else if(iWaveSpawnLeft <= 0 && GetSpecialCount() < 3)
	{
		// Glow the rest infected.
		_forall(client)
		{
			if (IsClientInGame(client) 
				&& IsInfected(client)
				&& IsPlayerAlive(client)
				&& GetInfectedClass(client) != ZC_Tank){
				SetEntProp(client, Prop_Send, "m_iGlowType", 3);
				SetEntProp(client, Prop_Send, "m_glowColorOverride", 0x0000FF);
			}
		}
	}
}

//    ---------------------------- MOB------------------------------------------------------
public Action L4D_OnSpawnMob(int &amount)
{
	if(iWaveSpawnLeft > 0 && !IsTankAlive())
	{
		PrintToServer("Spawn mob amount @ %d!.....", amount);
		//amount = 60;
		return Plugin_Continue;
	}
	PrintToServer("Try to spawn mob @ %d!, handled.....", amount);
	amount = 0;
	SetPendingMobCount(0);
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if ( IsTankAlive() && StrEqual(classname, "infected", false) && !ArePlayersBiled())
	{
		CreateTimer(0.1, CommonSlayer, entity);
	}
}

public Action CommonSlayer(Handle timer, any entity)
{
	if (IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

bool ArePlayersBiled()
{
	_forall(client)
	{
		if (IsClientInGame(client) && IsSurvivor(client))
		{
			if(IsPlayerBiled(client)) return true;
		}
	}
	return false;
}

void SetPendingMobCount(int count)
{
	if(!pZombieManager)
		StoreToAddress(pZombieManager + view_as<Address>(528), count, NumberType_Int32);
}

#pragma newdecls optional
//------------------------------------------SI CONTROLL----------------------------------------
public Action:L4D_OnSpawnSpecial(&zombieClass, const Float:vector[3], const Float:qangle[3])
{
	if(iWaveSpawnLeft > 0)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action:L4D_OnGetScriptValueInt(const String:key[], &retVal)
{
	if(inRelaxing)
	{
		if(StrContains(key, "Limit") != -1)
		{
			retVal = 0;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0 || !IsClientInGame(client)) return;
	
	if(GetClientTeam(client) != TEAM_INFECTED) return;
	
	iWaveSpawnLeft--;
	
	if(iWaveSpawnLeft <= 0)
	{
		DirectorStage(STAGE_STOP);
	}
}

//#define z_drop_probility 0.05
public Action:OnDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim 	= GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientAndInGame(victim) || !IsInfected(victim)) return;    	// safeguard
	SetEntProp(victim, Prop_Send, "m_iGlowType", 0);

	iWaveInfectedLeft --;
	if(iWaveInfectedLeft > 0)
	{
		if(bWaveAllowTank)
		{
			if(iWaveInfectedLeft == iNowSpawnTank + 4)
			{
				CPrintToChatAll("{default}[{green}!{default}] {red}TANK {olive}is approaching!!!");
			}
			if(iWaveInfectedLeft == iNowSpawnTank && !bAllowSpawnTank){
				bAllowSpawnTank = true;
			}
		}
		else if(iWaveInfectedLeft == iNowSpawnTank)
			CreateTimer(0.4, SpawnAWitch, _, TIMER_FLAG_NO_MAPCHANGE);
		if(iWaveInfectedLeft % 10 == 0)
			CPrintToChatAll("{default}<{green}!{default}> {green}%d {red}Special Infecteds {olive}remaining...", iWaveInfectedLeft);
	}
	if(!inRelaxing)
	{
		CheckWaveEnd();
		new idx = GetRandomInt(0, 49);
		if(GetInfectedClass(victim) == ZC_Tank){
			GivePlayerItem(victim, "first_aid_kit");
			if(GetRandomInt(0, 1) < 1)
				GivePlayerItem(victim, "first_aid_kit");
			else
				GivePlayerItem(victim, "defibrillator");
		} else if(idx < 5)
			GivePlayerItem(victim, droplist[idx]);
	}
}
			// CreateTimer( 0.1, Timer_CheckTankDeath, client );
/*
public Action: Timer_CheckTankDeath ( Handle:hTimer, any:client_oldTank )
{
    if ( !FindTankClient())
    {
        // tank died
		Give(client, "first_aid_kit");
		Give(client, "first_aid_kit");
    }
}
*/

public Action:Timer_NextWave(Handle:timer)
{
	if(iCurrentWaveIndex == 0) return Plugin_Stop;
	if(iTimeNextwave > 0)
	{
		PrintHintTextToAll("Get ready, %d seconds before next waves.", iTimeNextwave);
		iTimeNextwave--;
		return Plugin_Continue;
	}

	inRelaxing = false;
	iCurrentWaveIndex ++;
	iWaveSpawnLeft = GetWaveTotal(iCurrentWaveIndex);
	iWaveInfectedLeft = iWaveSpawnLeft;
	bWaveAllowTank = (iCurrentWaveIndex == iTankWave[0] || iCurrentWaveIndex == iTankWave[1]);
	
	if(iCurrentWaveIndex == MaxWaves)
	{
		bWaveAllowTank = true;
		CPrintToChatAll("{olive}<{green}Waves{olive}>: {blue}Hold out, {olive}finale wave!");
	}
	else
		CPrintToChatAll("{olive}<{green}Waves{olive}>: {blue}%d/%d. {olive}Incoming!", iCurrentWaveIndex, MaxWaves);
		
	DirectorStage(STAGE_START);	
	ServerCommand("sm_stormstart");
	L4D_ResetMobTimer();
	PrintHintTextToAll("THEY ARE COMMING%s", bWaveAllowTank?", TANK READY!":"!");
	return Plugin_Stop;
}

//----------------------------------------------Tank Control-----------------------------
public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if(!bAllowSpawnTank || IsTankAlive()) return Plugin_Handled;
	if(iWaveSpawnLeft <= 0) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action: OnTank_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	bAllowSpawnTank = false;
	CPrintToChatAll("{default}[{green}!{default}] {red}Tank {green}has spawned!");
	// director_no_mobs.SetBool(true);
	SetPendingMobCount(0);
	EmitSoundToAll("ui/pickup_secret01.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
}

// -------------------------------------------------stock-------------------------------------
int GetNextMapIndex()
{
	new String:sCurMap[64];
	GetCurrentMap(sCurMap, sizeof(sCurMap));
	for(new i = 0; i < 16; i++)
	{
		if(StrEqual(sCurMap, MapList[i])) return i + 1;
	}
	return 0;
}

int GetWaveTotal(iWaves, iDiff = 3)
{
	return ((iWaves - 1) * iDiff + 20);
}

stock void Nb_DeleteAll()
{
	new entcount = GetEntityCount();
	decl String:sBuffer[32];
	for( new entity = entcount; entity > 0; entity--)
	{
		if(IsValidEntity(entity) && IsValidEdict(entity))
		{
			GetEdictClassname(entity, sBuffer, 32);
			if (StrEqual(sBuffer, "infected", false)) {
				IgniteEntity(entity, 10.0);
			}
		}
	}
}

/*
stock void Give(Client, String:itemId[], bool:sim = false)
{
	if (!sim)
	{
		CheatCommand(Client, "give", itemId);
		LogMessage("[SurvivalAM] Spawned %s.", itemId);
	}
	else
		PrintToServer("[SurvivalAM SIM] Spawned %s.", itemId);
	
}
public Action:Timer_CheckHeal(Handle:timer)
{
	if(!L4D_HasAnySurvivorLeftSafeArea()) 
	{
		PrintToServer("!L4D_HasAnySurvivorLeftSafeArea, stopped.");
		return Plugin_Stop;
	}
	
	CheckImmosed();

	_forall(client)
	{
		if(IsClientInGame(client) && IsMobile(client) && GetClientHealth(client) < AUTOHEALMAXHEALTH)
		{
			new health = GetClientHealth(client);
			if(health < AUTOHEALMAXHEALTH)
				AddHealth(client, HEAL_PERINTER);
		}
	}
	return Plugin_Continue;
}
void CheckImmosed()
{
	if(IsTeamImmobilised() && !IsTeamWiped())
	{
		PrintToChatAll("\x03%s # [\x0400:%02d:00\x01]", hostfile, imobilisedChecking);
		if(--imobilisedChecking < 0)
		{
			SlaySpecialInfected();
			imobilisedChecking = SLAY_COUNTDOWN;
		}
	}
	else
		imobilisedChecking = SLAY_COUNTDOWN;
	return;
}

void SlaySpecialInfected() 
{	// Make damage before slay infected;
	_allclients(i)
	{
		if(!IsClientInGame(i)) continue;
		if(IsSurvivor(i) && IsPinned(i))
		{
			SurvivorHurt(i, i, Float:20);
		}
	}
	_allclients(i) 
	{
		if(!IsClientInGame(i)) continue;
		if(IsBotInfected(i) && IsPlayerAlive(i)) 
		{
			if(IsPinningASurvivor(i)) 
			{
				IgniteEntity(i, 4.2);
				ForcePlayerSuicide(i);
				ClearZombieAround(i,500);
			} 
		}
	}
	CPrintToChatAll("{green}root{default}@%s # {blue}sudo rm -rf {olive}~/infected/", hostfile);
}

void ClearZombieAround(client,int range)
{
	int entcount = GetEntityCount();
	decl String:sBuffer[32];
	for( int entity = entcount; entity > 0; entity--)
	{	
		if(IsValidEntity(entity) && IsValidEdict(entity))
		{
			GetEdictClassname(entity, sBuffer, sizeof(sBuffer));
			if (StrEqual(sBuffer, "infected", false))
			{
				if(GetDistance(client, entity) < range)
				{
					IgniteEntity(entity, 4.2, true, 4.2);
				}
			}
		}
	}
}

void AddHealth(client, perm = 1)
{
	new health = GetEntProp(client, Prop_Send, "m_iHealth") + perm;
	if(health > 100) health = 100;
	SetEntProp(client, Prop_Send, "m_iHealth", health);
	return;
}


void SurvivorHurt(client, attacker, Float:damage)
{
	SDKHooks_TakeDamage(client, attacker, attacker, damage, DMG_SHOCK);
	EmitGameSoundToClient(client, "HunterZombie.Pounce.Hit", SOUND_FROM_PLAYER, SND_NOFLAGS);
}
*/

public Action:SpawnAWitch(Handle:timer)
{
	new client = GetAnyClient();
	if(client)
	{
		CheatCommand(client, "z_spawn_old", "witch auto");
	}
	return Plugin_Stop;
}

public void DirectorStage(int stage)
{
	switch(stage)
	{
		case STAGE_START: ServerCheatCommand("director_start");
		case STAGE_STOP: ServerCheatCommand("director_stop");
	}
}