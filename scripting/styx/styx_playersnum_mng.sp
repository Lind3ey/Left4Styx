/***************************************
** 1. COMMANDS vs ht to change configs.
** 2. Manage the numbers of survivors and infecteds.
** 3. Balance the CI numbers and Tank health.
** 4. Meanwhile changed the directoroptions.
**  ***********************/


#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <builtinvotes>
#include <styxutils>

#define 	DEBUG  		false

#define UPDATE_RUN_DELAY	1.7
#define	CMLMT 				32			// Max Common 
#define MMSIZE				60
#define MSIZE				16
// #define MODESCRIPT			"g_ModeScript.DirectorOptions"
// #define MAPSCRIPT			"g_MapScript.DirectorOptions"	
#define SUSAGE	"{green}# {olive}Vote cmds: {blue}!vs(!ht) <human> <zombie> {olive}e.g. !vs 2 4"
#define STRINGRESTART	"{green}%s$                       {blue}Restart in %.1f seconds!"

#define CHECK_DELAY		1.0
#define KICK_DELAY		0.5

char hostfile[16] = "xyts";
static const String: sZCName[ZC_Witch][]={
"Tank_health", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"
};

static const String: sDirectorVar[ZC_Witch][]={
"ZombieTankHealth", "SmokerLimit", "BoomerLimit", "HunterLimit", "SpitterLimit", "JockeyLimit", "ChargerLimit"
};

#define POOL_LENGTH 12
static const zcSpawnPools[4][POOL_LENGTH] ={ 
	{ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Boomer, ZC_Hunter, ZC_Jockey, ZC_Hunter, ZC_Charger, ZC_Hunter,ZC_Jockey, ZC_Charger, ZC_Jockey},
	{ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Hunter, ZC_Boomer, ZC_Charger, ZC_Jockey, ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Hunter, ZC_Smoker},
	{ZC_Hunter, ZC_Jockey, ZC_Charger, ZC_Hunter, ZC_Spitter, ZC_Boomer, ZC_Jockey, ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Hunter, ZC_Smoker},
	{ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Hunter,  ZC_Spitter, ZC_Boomer, ZC_Jockey, ZC_Hunter, ZC_Charger, ZC_Jockey, ZC_Hunter, ZC_Smoker}
	};


static int
//	ptSpawnPool = 0;
	temp_human = 4,	//For vote
	temp_ifted = 6,	//For vote
	nSurvivors = 4,
	nSpecials =  6,
//	nDynCIlimit = CMLMT,
	nVallinaSpawn = 2,
	z_charger_health_single	= 600,
	nSpecialLimits[ZC_Witch] = {4500, 1, 1, 2, 1, 1, 1};
	nVSLimits[ZC_Witch] = {4500, 0, 0, 2, 0, 2, 2};

static bool
	temp_bhunters = false,
	z_all_hunters_game = false;

// Game ConVars
static ConVar
	Cvar_VallinaSpawn,
	Cvar_ChargerHealth,
	Cvar_AllHunters,
	Survivor_Limit,
	Cvar_zmaxplayerzombies,
	Cvar_zcommonlimit,
	Cvar_megamobsize,
	Cvar_mobminsize,
	Cvar_mobmaxsize,
	Cvar_zsilimits[ZC_Witch][2];

// static Handle hTimeNode;
Handle
	hBuiltinvote;

public Plugin:myinfo =
{
	name = "L4D2 Survivor&SI Numbers",
	author = "Lind3ey",
	description = "",
	version = "210703",
	url = ""
};

public OnPluginStart()
{
	HookEvent("round_start",			EventRound,			EventHookMode_PostNoCopy);
	HookEvent("player_spawn",			OnSpawn,			EventHookMode_Post);

	RegConsoleCmd("sm_specials",		Cmd_Votevs);
	RegConsoleCmd("sm_vs",				Cmd_Votevs);
	RegConsoleCmd("sm_hunters",         Cmd_VoteHunters);
	RegConsoleCmd("sm_hunter",         	Cmd_VoteHunters);
	RegConsoleCmd("sm_ht",         		Cmd_VoteHunters);
	
	Cvar_AllHunters 	= CreateConVar("z_all_hunters_game",	"0"," 0 = not",	 	FCVAR_SPONLY, true, 0.0, true, 1.0);
	Cvar_ChargerHealth	= CreateConVar("z_charger_health_single", 	"560",	"", FCVAR_SPONLY, true, 0.0, true, 600.0);
	Cvar_VallinaSpawn 	= CreateConVar("z_vallina_spawn", 		"4",	"Director spawn or not", 	FCVAR_SPONLY, true, 0.0, true, 4.0);

	z_charger_health_single 	= GetConVarInt(Cvar_ChargerHealth);

	Survivor_Limit 			= FindConVar("survivor_limit");
	Cvar_zmaxplayerzombies 	= FindConVar("z_max_player_zombies");
	// Unlock more than 4 zombies.
	SetConVarBounds(Cvar_zmaxplayerzombies, ConVarBound_Upper, true, 12.0);
	Cvar_zcommonlimit 		= FindConVar("z_common_limit");
	Cvar_megamobsize 		= FindConVar("z_mega_mob_size");
	Cvar_mobminsize 		= FindConVar("z_mob_spawn_min_size");
	Cvar_mobmaxsize 		= FindConVar("z_mob_spawn_max_size");

	decl String:sNameBuf[64];
	Cvar_zsilimits[0][0] 	= FindConVar("z_tank_health");
	Cvar_zsilimits[0][1] 	= null;
	for(new i = 1; i < ZC_Witch; i++)
	{
		Format(sNameBuf, sizeof(sNameBuf), "z_%s_limit", sZCName[i]);
		Cvar_zsilimits[i][0] = FindConVar(sNameBuf);
		Format(sNameBuf, sizeof(sNameBuf), "z_versus_%s_limit", sZCName[i]);
		Cvar_zsilimits[i][1] = FindConVar(sNameBuf);
	}

	HookConVarChange(Cvar_AllHunters, 		Cvar_AllHuntersChange);
	HookConVarChange(Cvar_ChargerHealth,	Cvar_ChargerHealthChange);
	HookConVarChange(Cvar_VallinaSpawn, 	Cvar_VallinaSpawnChange);

	CreateTimer(UPDATE_RUN_DELAY, UpdateTimer, true, TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapStart()
{
	PrecacheSound("ui/critical_event_1.wav");
	GetConVarString(FindConVar("hostfile"), hostfile, sizeof(hostfile));
}

public Cvar_ChargerHealthChange(Handle:convar, const String:oldValue[], const String:newValue[]){ z_charger_health_single = StringToInt(newValue);}

public Cvar_AllHuntersChange(Handle:convar, const String:oldValue[], const String:newValue[]){ z_all_hunters_game = StringToInt(newValue) > 0 ? true:false;}

public Cvar_VallinaSpawnChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	nVallinaSpawn = StringToInt(newValue);
}

public Action:EventRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(UPDATE_RUN_DELAY, UpdateTimer, false, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(CHECK_DELAY, Delay_CheckSurvivorLimit, _, TIMER_FLAG_NO_MAPCHANGE);  	//Survivor Limit check
}

public Action:Delay_CheckSurvivorLimit(Handle:timer)
{
	if(IsVersusMode() && !InSecondHalfOfRound())
		return Plugin_Handled; // It seems in versus second half, the survivor limit is fixed.
	
	new limit = Survivor_Limit.IntValue;
	FixSurvivorLimit(limit);
	return Plugin_Handled;
}

public void FixSurvivorLimit(limit)
{
	new iHuman = 0;
	new bool: kick = false;

	_allclients(i)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			iHuman++;
			if(iHuman <= limit) continue;
			if(IsFakeClient(i)) KickClient(i, "");
			else
			{
				ForcePlayerSuicide(i);
				ChangeClientTeam(i, 3);
				kick = true;
			}
		}
	}
	if(iHuman < limit)
	{
		for(new j = 0; j < limit - iHuman; j++)
		{
			ServerCommand("sb_add");	// For coop .
		}
	}

	if(!kick) return;
	CreateTimer(KICK_DELAY, Delay_Kick, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Delay_Kick(Handle:timer)
{
	_allclients(i)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsFakeClient(i) && !IsPlayerAlive(i))
		{ 
			KickClient(i, "");
		}
	}
}

public Action:UpdateTimer(Handle:timer, bool: firstload)
{
	if(firstload)
	{	// Matching player nums when first load.
		new pnum = GetPlayerNum();
		pnum = MAX(MIN(4, pnum),1);
		nSurvivors 	= pnum;
		nSpecials 	= pnum + 1;
	}
	UpdateConVars();
}

public OnRoundIsLive()
{
	ShowConfig(true);
}

public Action:Cmd_Votevs(client, args)
{
	if (!client) 	return Plugin_Handled;
	if(args == 2)
	{
		if(client && IsClientInGame(client))
		{
			decl String: human[4];
			decl String: ifted[4];
			GetCmdArg(1, human, sizeof(human));
			GetCmdArg(2, ifted, sizeof(ifted));
		
			new ihuman = StringToInt(human);
			new iifted = StringToInt(ifted);
			PreVoteMatchSpecials(client, ihuman, iifted, false);
			return Plugin_Handled;
		}
	}
	// Show usage.
	ShowConfig(true);
	return Plugin_Handled;
}

public Action:Cmd_VoteHunters(client, args)
{
	if (!client) 	return Plugin_Handled;
	if(args == 2)
	{
		if(client && IsClientInGame(client))
		{
			decl String: human[4];
			decl String: ifted[4];
			GetCmdArg(1, human, sizeof(human));
			GetCmdArg(2, ifted, sizeof(ifted));
		
			new ihuman = StringToInt(human);
			new iifted = StringToInt(ifted);
			PreVoteMatchSpecials(client, ihuman, iifted, true);
			return Plugin_Handled;
		}
	}
	// Show usage.
	ShowConfig(true);
	return Plugin_Handled;
}

void PreVoteMatchSpecials(client, human, ifted, bool:hunter)
{
	if(human> 0 && human < 5 && ifted >= human && ifted < human * 2 + 3 )
	{
		if(IsGenericAdmin(client))
		{
			MatchSpecials(human, ifted, hunter);
			return;
		}
		if(VoteMatchSpecials(client, human, ifted, hunter))
		{
			temp_human = human;
			temp_ifted = ifted;
			temp_bhunters = hunter;
			FakeClientCommand(client, "Vote Yes");
		}
		return;
	}
	else
	{
		CPrintToChat(client, "{olive}Ilegal numbers."); // Content
		return;
    }   
}

bool:VoteMatchSpecials(client, human, ifted, bool:hunter) 
{
	if (IsNewBuiltinVoteAllowed())
	{
		new String:sBuffer[64];
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Load %d vs %d %s config?", human, ifted, hunter?"Hunters":"");
		SetBuiltinVoteArgument(hBuiltinvote, sBuffer);
		SetBuiltinVoteInitiator(hBuiltinvote, client);
		SetBuiltinVoteResultCallback(hBuiltinvote, SpecialsVoteHandler);
		DisplayBuiltinVoteToAllNonSpectators(hBuiltinvote, 10);
		return true;
	}
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public SpecialsVoteHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				MatchSpecials(temp_human, temp_ifted, temp_bhunters);
				DisplayBuiltinVotePass(vote, "Loading.");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void MatchSpecials(human, ifted, bool:hunter)
{
	// new bool: reluanch = false;
	if( nSurvivors == human && nSpecials == ifted && z_all_hunters_game == hunter)
	{
		UpdateConVars();
		EmitSoundToAll("ui/critical_event_1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		return;
	}

	if( nSurvivors != human || L4D_HasAnySurvivorLeftSafeArea())
	{
		RestartInSeconds(5.0);
	}
	
	nSurvivors = human;
	nSpecials = ifted;
	z_all_hunters_game = hunter;
	UpdateConVars();

	CPrintToChatAll("{green}%s$ {blue}Match {green}%d survivors {blue}versus {green}%d %ss", hostfile, nSurvivors, nSpecials, hunter?"hunter":"special");
	EmitSoundToAll("ui/critical_event_1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	return;
}

void RestartInSeconds(float seconds)
{
	CreateTimer(seconds, Delay_Restart, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateFakeEnd();
	FreezeAll();
	CPrintToChatAll(STRINGRESTART, hostfile, seconds);
}

void CreateFakeEnd()
{
	static Handle:event_end;
	event_end = INVALID_HANDLE;
	
	event_end = CreateEvent("round_end", true);
	SetEventInt(event_end, "winner", 0);
	SetEventInt(event_end, "reason", 5);
	SetEventString(event_end, "message", "voteconfig");
	FireEvent(event_end);
	event_end = INVALID_HANDLE;
	
	event_end = CreateEvent("mission_lost", true);
	FireEvent(event_end);
	event_end = INVALID_HANDLE;
	EmitSoundToAll("ui/critical_event_1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
}

public Action:Delay_Restart(Handle timer)
{
	// L4D2_FullRestart();
	SetConVarInt(FindConVar("mp_restartgame"), TEAM_INFECTED);
}

void UpdateConVars()
{
	SetConVarInt(Survivor_Limit, nSurvivors);	// survivor limit
	// Max specials
	SetConVarInt(Cvar_zmaxplayerzombies, nSpecials);
	RunDirectorScript("MaxSpecials<-%d", nSpecials);
	RunDirectorScript("cm_MaxSpecials<-%d", nSpecials);

	//Common limit
	static int nDynCIlimit;
	nDynCIlimit = (CMLMT>>2) * nSurvivors - 2;
	SetConVarInt(Cvar_zcommonlimit, nDynCIlimit);
	RunDirectorScript("CommonSpecialLimits <- %d", nDynCIlimit );
	RunDirectorScript("cm_CommonSpecialLimits <- %d", nDynCIlimit );

	// Mob
	SetConVarInt(Cvar_megamobsize, MMSIZE);
	RunDirectorScript("MegaMobSize <- %d", MMSIZE);

	SetConVarInt(Cvar_mobmaxsize, (MSIZE>>2) * nSurvivors);
	SetConVarInt(Cvar_mobminsize, (MSIZE>>2) * nSurvivors);
	RunDirectorScript("MobSpawnSize <- %d", (MSIZE>>2) * nSurvivors);

	SetConVarBool(Cvar_AllHunters, z_all_hunters_game);
	CaculateLimit(nSurvivors, nSpecials);

	// Tank Health;
	if(!IsVersusMode())
		nSpecialLimits[0] = nSpecialLimits[0] * 3 / 2;
	SetConVarInt(Cvar_zsilimits[0][0], nSpecialLimits[0] );
	RunDirectorScript("%s<-%d", sDirectorVar[0],nSpecialLimits[0]);

	// Specials Limit.
	for (new i = 1; i < ZC_Witch; i++)
	{
		SetConVarInt(Cvar_zsilimits[i][0], nSpecialLimits[i]);
		SetConVarInt(Cvar_zsilimits[i][1], nVSLimits[i]); // z_vs_xxx_limit 
		RunDirectorScript("%s<-%d", sDirectorVar[i],nSpecialLimits[i]);
	}
	PrintToServer("[Styx Player Management] Updated config %d vs %d!", nSurvivors, nSpecials);
}

void ShowConfig(bool:showUse = false)
{
	static String:sConfig[128];
	Format(sConfig, sizeof(sConfig), "{green}%s# {olive}Current config: {green}%s {blue}%d {default}<-> {green}%d", hostfile, z_all_hunters_game == true?"Hunters":"Normal", nSurvivors, nSpecials);
	CPrintToChatAll(sConfig);

	if(showUse)
		CPrintToChatAll(SUSAGE);
}

void CaculateLimit(nsvvs, nspcs)
{
	if(nsvvs == 1 )
	{ 
		nSpecialLimits = {1000, 0, 1, 2, 0, 1, 1}; 	// Sm 0 BM 1 HT 1 SP 0 JK 1 CG 1  sm+bm = 0.5 Ht = 1.5
	}
	else if(nsvvs == 2)
	{
		nSpecialLimits = {2000, 1, 1, 2, 1, 1, 1}; 	// SM + SP + BM = 1, Hunter 1.5 
	}
	else
	{ 
		nSpecialLimits[0] = 4500 * nsvvs /4;
		nSpecialLimits[ZC_Smoker] = (nspcs + 2) / 5;   		// 3    8 
		nSpecialLimits[ZC_Boomer] = nspcs / 8 + 1;				// 8
		nSpecialLimits[ZC_Hunter] = (nspcs - 2) / 3 + 1;		// 5	8
		nSpecialLimits[ZC_Spitter] = nspcs / 9 + 1;			// 9
		nSpecialLimits[ZC_Jockey] = nspcs / 7 + 1;				// 7
		nSpecialLimits[ZC_Charger] = nspcs / 7 + 1;			// 7
	}
}

public Action:L4D_OnSpawnSpecial(&zombieClass, const Float:vector[3], const Float:qangle[3])
{
	if( z_all_hunters_game && zombieClass != ZC_Tank)
	{
		zombieClass = ZC_Hunter;
		return Plugin_Changed;
	}
	else if(nSurvivors <= nVallinaSpawn)// if(nSurvivors < 3)
	{
		new nextspawn = GetNextSpawn();
		if(nextspawn > 0)
		{
			zombieClass = nextspawn;
			// PrintToServer("Convert to %s spawn.", sZCName[zombieClass]);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

// This function just changes charger health when single playing
public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(nSurvivors != 1) return Plugin_Handled;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientAndInGame(client) || GetClientTeam(client) != TEAM_INFECTED) return Plugin_Handled;
	
	new zombieClass = GetInfectedClass(client);

	if(zombieClass == ZC_Charger)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", z_charger_health_single);
	}
	return Plugin_Handled;
}

#define noCGorHT	AliveSpecialCount(ZC_Charger)+AliveSpecialCount(ZC_Hunter)<1
static int GetNextSpawn()
{
	static int nextspawn, pointer;
	nextspawn = -1;
	for(new times = POOL_LENGTH; times >0 ; times--)
	{
		pointer++;
		if(pointer > POOL_LENGTH - 1) pointer = 0;
		nextspawn = zcSpawnPools[nSurvivors-1][pointer];
		if(AliveSpecialCount(nextspawn) < nSpecialLimits[nextspawn])
		{	// Disable Spitter Spawn first.
			if(nextspawn == ZC_Spitter && noCGorHT)		continue;
			else 										return nextspawn;
		}
	}
	return nextspawn;
}
