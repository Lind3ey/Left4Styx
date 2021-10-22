
/**********************
** 1. Commands awaay spec join kill bot mark
** 2. Change versus gamemode for coop play. dont use this in versus config.
** 3. Vote replay after some times of trys.
************************/

#pragma semicolon 1

#define REQUIRE_PLUGIN
#include <sourcemod>
#include <sdkhooks>
#include <readyup>
#include <left4dhooks>
#include <colors>
#undef REQUIRE_PLUGIN

#include <styxutils>

bool 	bIsRoundAlived 		= false;
int 	iRoundCounter			= 0;
ConVar 	hCvarSkipRound,
		hCvarDirectorCheck;

public char hostfile[16] = "xyts";

/************** Modules ***************/
#include "styxvotes/vote_replay.sp"
#include "styxmodules/pz_mark.sp"

#define 		All_Commands			"!away/!join/!vs/!ht/!(r)match/!zed"
#define			Magician_Time			1.0

static bool bAllowInfectedPlayer	= false,
			bReadyFooterAdded		= false,
			bJustConnected[MAXPLAYERS] 		= false;

static ConVar 	hCvarAllowInfPlayer,
				hCvarMpgameMode;

public Plugin:myinfo = 
{
	name = "Styx Commands(Coop).", 
	author = "Lind3ey", 
	description = "Commands: away, join, kill...", 
	version = "2.9", 
	url = ""
};

public OnPluginStart()
{	
	hCvarAllowInfPlayer = CreateConVar("allow_player_zombie", 	"0", 	"allow player zombie?", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarSkipRound = CreateConVar("mp_round_to_skip",		"3",	"How many ?", 		FCVAR_NONE, true, 0.0, true, 999.0);
	hCvarDirectorCheck = FindConVar("director_no_death_check");

	HookConVarChange(hCvarAllowInfPlayer, Cvar_AllowInfPlayer);
	
	/*************** Clients commands **********************/
	RegConsoleCmd("sm_away", 	Cmd_Spectate,		"Turn player to spectate.");
	RegConsoleCmd("sm_spec", 	Cmd_Spectate,		"Turn player to spectate.");
	RegConsoleCmd("sm_join", 	Cmd_TurnToGame, 	"Turn player to game.");
	RegConsoleCmd("sm_kill", 	Cmd_Kill_Me,		"Force Player Suicide");
	RegConsoleCmd("sm_bot", 	Cmd_ComeBots,		"Call bots");
	
	// RegConsoleCmd("sm_rec", 	Cmd_RecordDemo,		"RecordDemo");
	// RegConsoleCmd("sm_record", 	Cmd_RecordDemo,		"RecordDemo");
	
	//Avoid player use "chooseteam" to join infected.
	AddCommandListener(	Cmd_JoinTeam, 		"jointeam");
	
	// Admin commands
	RegAdminCmd("sm_mark",		Cmd_MarkAsInfected, 	ADMFLAG_KICK, 	"Allow admin to handly mark." );
	RegAdminCmd("sm_take", 		CmdTakeBot, 			ADMFLAG_CHAT,  "Take the certain bot!");
	// RegAdminCmd("sm_styxrestart", Cmd_StyxRestartRound, ADMFLAG_GENERIC, "Restart Round.");
	
	// Even spam
	HookEvent("round_start", 			OnRoundStart, 		EventHookMode_Pre);
	HookEvent("round_end", 				OnRoundEnd, 		EventHookMode_Post);
	HookEvent("player_team",			OnPlayerTeam,		EventHookMode_Post);
	
	HookEvent("player_death",			PreCheck,			EventHookMode_Post);
	HookEvent("player_incapacitated",	PreCheck,			EventHookMode_Post);
	HookEvent("player_ledge_grab",		PreCheck,			EventHookMode_Post);
	
	CreateTimer(Magician_Time, Timer_TeamCheck, _, TIMER_REPEAT);
	
	hCvarMpgameMode = FindConVar("mp_gamemode");
}

/***********************************************************************
************************* Styx Cmds********************************
************************************************************************/
public Action:Cmd_Spectate(client, args)
{
	if(!client || !IsClientInGame(client)) return Plugin_Handled;
	if(GetClientTeam(client) == TEAM_SPECTATORS) return Plugin_Handled;
	//
	ChangeClientTeam(client, TEAM_SPECTATORS);
	// SendConVarValue(i, hCvarMpgameMode, "versus");
	CPrintToChatAllEx(client, "{default}※ {teamcolor}%N {default}has become a spectator.", client);
	UnMarkInfPlayer(client);
	return Plugin_Handled;
}

public Action:Cmd_JoinTeam(client, const String:command[], args)
{
	bJustConnected[client] = false;
	decl String: sArgs[16];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	if(StrContains(sArgs, "3", false) != -1 || StrContains(sArgs, "INFECTED", false) != -1)
	{
		if (!bAllowInfectedPlayer) return Plugin_Handled;
		if (GetClientTeam(client) != TEAM_SPECTATORS)
		{
			PrintHintText(client, "✘ Illegal team switch. ✘");
		}
		else if(!IsSurvivorTeamFull())
		{
			PrintHintText(client, "✘ Survivor team not full. ✘");
		}
		else
		{
			ChangeClientTeam(client, TEAM_INFECTED);
			MarkAsInfected(client);
			// SendConVarValue(client, hCvarMpgameMode, "versus");
			CPrintToChatAllEx(client, "{teamcolor}▶ {default}Player {teamcolor}%N {olive}joined infected.", client);
		}
		return Plugin_Handled;
	}
	// SendConVarValue(client, hCvarMpgameMode, "coop");
	return Plugin_Continue;
}

public Action:Cmd_TurnToGame(client, args)
{ 
	if(GetClientTeam(client) != TEAM_SPECTATORS) return Plugin_Handled;
	
	if(!IsSurvivorTeamFull() || !bAllowInfectedPlayer) 
	{
		ClientCommand(client, "jointeam SURVIVOR");
		// SendConVarValue(client, hCvarMpgameMode, "coop");
		UnMarkInfPlayer(client);
	}
	else
	{
		ChangeClientTeam(client, TEAM_INFECTED);
		MarkAsInfected(client);
		// SendConVarValue(client, hCvarMpgameMode, "versus");
		CPrintToChatAllEx(client, "{teamcolor}▶ {default}Player {teamcolor}%N {olive}joined infected.", client);
	}
	return Plugin_Handled;
}

public Action:Cmd_Kill_Me(client, args)
{
	if(!bIsRoundAlived || !IsClientInGame(client)) return Plugin_Handled;
	if(GetClientTeam(client) != TEAM_SURVIVORS || !IsPlayerAlive(client)) return Plugin_Handled;
	
	ForcePlayerSuicide(client);
	CPrintToChatAllEx(client, "{green}× {default}Player {teamcolor}%N {default}committed suicide.", client);
	
	return Plugin_Handled;
}

public Action:Cmd_ComeBots(client, args)
{
	if(GetClientTeam(client) == TEAM_SURVIVORS && IsPlayerAlive(client) && !IsHangingFromLedge(client))
		ComeBots(client);
	return Plugin_Handled;
}

public Action:Cmd_MarkAsInfected(client,args)
{
	if(bAllowInfectedPlayer)
	{
		MarkAsInfected(client);
		ChangeClientTeam(client, TEAM_INFECTED);
		// SendConVarValue(i, hCvarMpgameMode, "versus");
	}
	return Plugin_Handled;
}

public Action:CmdTakeBot(client, args)
{
	if(client && IsClientInGame(client))
	{
		if(args != 1)
		{
			PrintHintText(client, "What do you want to take?");
			return Plugin_Handled;
		}
		else
		{
			decl String: sbuffer[16];
			GetCmdArgString(sbuffer, sizeof(sbuffer));
			CheatCommand(client, "sb_takecontrol", sbuffer);
		}
	}
	return Plugin_Handled;
}

/************************************ Event Hook *******************************************/
public Cvar_AllowInfPlayer(Handle:convar, const String:oldValue[], const String:newValue[]){ bAllowInfectedPlayer = StringToInt(newValue) > 0 ? true:false;}

public OnMapStart()
{
	iRoundCounter = 0;
	PrecacheSound("music/undeath/death.wav");
	CreateTimer(1.0, DelaySetSlot, _, TIMER_FLAG_NO_MAPCHANGE);
	GetConVarString(FindConVar("hostfile"), hostfile, sizeof(hostfile));
}

public OnClientPostAdminCheck(client) 
{
	if(!IsFakeClient(client))
	{ 
		bJustConnected[client] = true;
		UnMarkInfPlayer(client);
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	DeActiveRound();
	// Force Second half of game.
	if(IsVersusMode() && !InSecondHalfOfRound())
	{
		CreateTimer(Magician_Time, ForceSecondHalf, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	
	bReadyFooterAdded = false;
	CreateTimer(3 * Magician_Time, Timer_Addfooter, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action:ForceSecondHalf(Handle:timer)
{
	if(InSecondHalfOfRound()) return Plugin_Stop;
	if(ConnectingPlayers()) return Plugin_Continue;
	else
	{
		SetConVarInt(FindConVar("mp_restartgame"), 1);
		return Plugin_Stop;
	}
}

public OnClientDisconnect(client)
{
	UnMarkInfPlayer(client);
	bJustConnected[client] = false;
}

public OnRoundIsLive()
{
	// CreateTimer(Magician_Time, RemindHumanPlayer);
	iRoundCounter ++ ; 
	// CPrintToChatAll("{default}<{green}Round: {blue}%d {default}>", iRoundCounter);
	PrintToServer("******** Roundcount: %d, InsecondHalf: %s *******", iRoundCounter, InSecondHalfOfRound()?"true":"false");
	if(bAllowInfectedPlayer){ ReportInfectedPlayer();}
}

public OnLeftSafeArea(){ ActiveRound();}

public Action: OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!bIsRoundAlived) 	return Plugin_Continue;		//	To avoid fake round end event.
	bIsRoundAlived 		= false;

	PrintToServer("******* Round(%d) end event report ******", iRoundCounter);
	L4D2_HideVersusScoreboard();
	return Plugin_Continue;
}

public Action:OnPlayerTeam(Handle:event, String:name[], bool:dontBroadcast)
{
	new iTeam = GetEventInt(event, "team");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Handled;
	
	if (iTeam != TEAM_SPECTATORS)
	{
		if (bJustConnected[client])
		{
			CreateTimer(0.1, Delay_Welcome, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		if(iTeam == TEAM_SURVIVORS)
		{
			SendConVarValue(client, hCvarMpgameMode, "coop");
		}
		else
		{
			SendConVarValue(client, hCvarMpgameMode, "versus");
		}
    }
	else
	{
		SendConVarValue(client, hCvarMpgameMode, "versus");
	}
	return Plugin_Handled;
}

/************************* Actions  ***************************/

public Action:Delay_Welcome(Handle:timer, any:client)
{
	bJustConnected[client] = false;
	CPrintToChat(client, "{green}# {olive}Commands{default}: {green}%s", All_Commands);
	if(bIsRoundAlived)
	{ 
		ChangeClientTeam(client, TEAM_SPECTATORS);
		// SendConVarValue(i, hCvarMpgameMode, "versus");
		CPrintToChat(client, "{green}%s# {red}Round already started, Please join game manually.", hostfile);
		// ClientCommand(client, "chooseteam");
	}
	return Plugin_Handled;
}

public Action:PreCheck(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client || client > MaxClients) return Plugin_Handled;
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVORS) return Plugin_Handled;  				// safeguard
	
	CreateTimer(Magician_Time, Timer_CheckFail, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action:ReportInfectedPlayer()
{
	new playerInf[4];
	new index = 0;
	for(new i = 1; i < MaxClients; i++)
	{
		if (IsPlayerZombie(i) && index < 4) 
		{
			playerInf[index++] = i;
			MarkAsInfected(i);		//Mark Inf player at the same time.
			SendConVarValue(i, hCvarMpgameMode, "versus");
		}
	}
		
	switch(index)
	{
		// case 0: 	CPrintToChatAll("{olive}Infected Player: {blue}None");
		case 1: CPrintToChatAll("{green}Infected Player: {red}%N", playerInf[0]);
		case 2: CPrintToChatAll("{green}Infected Player: {red}%N{default}, {red}%N", playerInf[0],playerInf[1]);
		case 3: CPrintToChatAll("{green}Infected Player: {red}%N{default}, {red}%N{default}, {red}%N", playerInf[0],playerInf[1],playerInf[2]);
		case 4: CPrintToChatAll("{green}Infected Player: {red}%N{default}, {red}%N{default}, {red}%N{default}, {red}%N",playerInf[0],playerInf[1],playerInf[2],playerInf[3]);
	}
	return Plugin_Handled;
}

public Action:RemindHumanPlayer(Handle timer)
{
	if(!IsSurvivorTeamFull()) CPrintToChatAll("{green}☛ {default}Use {blue}!bot {default}to {green}warp dummy Bots to you.");
	else if(bAllowInfectedPlayer) CPrintToChatAll("{green}☛ {default}Use {blue}!slots {default}to {green}vote extra slots for infected player.");
	return Plugin_Handled;
}

public void ActiveRound()
{
	bIsRoundAlived 		= true;
	FindConVar("god").SetBool(false);
	FindConVar("sv_infinite_ammo").SetBool(false);
	VR_ActiveRound();
	PrintToServer("********* Players left safe area, round alive. ********");
}

public void DeActiveRound()
{
	ResetMarkedPz();
	bIsRoundAlived 		= false;
	FindConVar("god").SetBool(true);
	FindConVar("sv_infinite_ammo").SetBool(true);
	VR_DeActiveRound();
}

public Action:Timer_Addfooter(Handle:timer, any:client) 
{ 
	if(bReadyFooterAdded) return Plugin_Handled;
	bReadyFooterAdded = true;
	decl String:readyString[65];
	Format(readyString,sizeof(readyString), "-> Join infected %s", (bAllowInfectedPlayer ? "enabled.":"disabled."));
	AddStringToReadyFooter(readyString);
	return Plugin_Handled;
}

public Action:Timer_TeamCheck(Handle: timer)
{
	if(bAllowInfectedPlayer) 	CheckPlayerTeam();
	else 						BlockPlayerZombie();
	return Plugin_Continue;
}

public Action:DelaySetSlot(Handle:timer) 
{ 
	if(L4D_IsFirstMapInScenario())
	{
		ConVar styxslot = FindConVar("mp_modeslots");
		if(styxslot != INVALID_HANDLE)
		{
			int slot = styxslot.IntValue;
			FindConVar("sv_maxplayers").SetInt(slot);
			FindConVar("sv_visiblemaxplayers").SetInt(-1);
			PrintToServer("<Slots> Server slots had been set to %d", slot);
		}
	}
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	ResetConVar(FindConVar("god"));
	ResetConVar(FindConVar("sv_infinite_ammo"));
	ResetConVar(hCvarDirectorCheck);
}

// @return Force blocking player from join infected.
void BlockPlayerZombie()
{
	_allclients(i)
	{
		if (IsPlayerZombie(i))
		{
			if (!IsSurvivorTeamFull()) 
				FakeClientCommand(i, "jointeam 2");
			else 
				ChangeClientTeam(i, TEAM_SPECTATORS);
			return;
		}
	}
}