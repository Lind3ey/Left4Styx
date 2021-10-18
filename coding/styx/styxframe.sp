/******************************************************
** 1. Match vote. @configs/matchmodes.txt
** 2. servername @configs/hostname.txt
** 3. cvar vscript auto include.
** 4. bequiet. cvars and command: sm_silent_cvar
** 5. afk Controll, no spam.
** 6. Auto resetmatch when nobody in server.
** 7. Auto config the convars about tickrates.
** *. Need confoglcompmod.smx to run.
********************************/

#pragma semicolon 1

#include <sourcemod>
#include <builtinvotes>
#include <left4dhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#define TEAM_SPECTATORS		1
#define	UNRESERVE_HUMANS	4
#define	CHECK_TIMES			6
#define	CHECK_INTERVAL		30.0
#define	NB_FREQ				0.017		//Sir said no lower than this value.

String:hostfile[16] = "Styx";

#include "styxutils.inc"
#include "styxmodules/matchvote.sp"
#include "styxmodules/servernamer.sp"
#include "styxmodules/vscript.sp"
#include "styxmodules/bequiet.sp"
#include "styxmodules/afkcontroll.sp"

static Handle: hCvarFactMode;
static Handle: hCvarModeSlots;
static Handle: hCvarCfgName;
static Handle: hCvarNoMatchNoPlay;
static Handle: hCvarAutoRmatch;

static bool: bIsConfoglAvailable 	= false;

enum Mode_flag
{
	MDFLAG_COOP = 0,
	MDFLAG_VERSUS,
	MDFLAG_VSCOOP,
	MDFLAG_SURVIVAL
};

public Plugin:myinfo = 
{
	name = "Styx FrameWork.", 
	author = "Lind3ey", 
	description = "reconcept", 
	version = "1.2", 
	url = ""
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Styx_IsVersus", Native_IsVersus);
	CreateNative("GetModeSlots", Native_GetModeSlots);
	
	RegPluginLibrary("styxframe");
	return APLRes_Success;
}

public OnPluginStart()
{
	bIsConfoglAvailable = LibraryExists("confogl");
	
	hCvarFactMode 		= CreateConVar("mp_factmode", 				"0",		"0=COOP, 1=VERSUS, 2=VSCOOP, 3=OTHERS", FCVAR_SPONLY);
	hCvarModeSlots  	= CreateConVar("mp_modeslots", 				"4", 		"", FCVAR_SPONLY, true, 0.0, true, 10.0);
	hCvarNoMatchNoPlay	= CreateConVar("sm_no_match_no_play", 		"1", 		"", FCVAR_SPONLY,true, 0.0, true, 1.0);
	hCvarAutoRmatch		= CreateConVar("sm_auto_resetmatch", 			"1", 		"", FCVAR_SPONLY,true, 0.0, true, 1.0);
	hCvarCfgName 		= CreateConVar("l4d_ready_cfg_name", 		"Empty",	"", FCVAR_SPONLY);

	RegServerCmd("sm_match_tickrate", 		Cmd_TickrateSet, 				"set tickrate");
	
	RegAdminCmd("sm_killlobbyres", 			Cmd_Unreserve, ADMFLAG_BAN, 	"manually force removes the lobby reservation");
	RegAdminCmd("sm_silent_cvar",			Cmd_SilentSet, ADMFLAG_CONFIG,	"silently change cvar.");
	
	HookEvent("round_start",			EventRoundStart);
	CreateTimer(CHECK_INTERVAL, 		Check_Server, _, TIMER_REPEAT);
	
	MV_OnPluginStart();
	SN_OnPluginStart();
	VS_OnPluginStart();
	BQ_OnPluginStart();
	NAG_OnPluginStart();
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "confogl")) bIsConfoglAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "confogl")) bIsConfoglAvailable = true;
}

public OnPluginEnd()
{
	MV_OnPluginEnd();
}

public OnClientPostAdminCheck(client) 
{
	if(IsFakeClient(client)) return;
	
	MV_OnClientPostAdminCheck(client);
	NAG_OnClientPostAdminCheck(client);
	if(GetHumanCount() >= UNRESERVE_HUMANS){ L4D_LobbyUnreserve(); }
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (!LGO_IsMatchModeLoaded() && GetConVarBool(hCvarNoMatchNoPlay))
	{
		ReturnPlayerToSaferoom(client, false);
		if(!IsFakeClient(client))
		{
			ClientCommand(client, "motd");
			SetConVarString(FindConVar("mp_gamemode"), "coop");
			LogPlayerAction(client, "Ilegal Went out.");
		}
		// ClientCommand(client, "sm_match");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	VS_OnRoundStart();
	NAG_OnRoundStart();
}

public Action:Check_Server(Handle:timer)
{
	static iNohumanTimes = 0;
	if(!GetConVarBool(hCvarAutoRmatch)) return Plugin_Continue;
	if(!IsHumansOnServer() && LGO_IsMatchModeLoaded())
	{ 
		iNohumanTimes++;
		PrintToServer("[confogl] %d times find server no human but matched.", iNohumanTimes);
		if(iNohumanTimes > CHECK_TIMES)
		{ 
			iNohumanTimes = 0;
			PrintToServer("[confogl] Reset Match....");
			ServerCommand("sm_resetmatch");
		}
		return Plugin_Continue;
	}
	iNohumanTimes = 0;
	return Plugin_Continue;
}

public Action:Cmd_Unreserve(client, args)
{
	L4D_LobbyUnreserve();
	if(client && IsClientInGame(client))
		PrintToChat(client, "\x01[\x05SM\x01] \x05Lobby reservation \x01has been removed.");
	
	return Plugin_Handled;
}

public Action:Cmd_SilentSet(client, args)
{
	if(args == 2)
	{
		decl String: Dvars[32], String:Newval[16];
		GetCmdArg(1, Dvars, sizeof(Dvars));
		GetCmdArg(2, Newval, sizeof(Newval));
		if(FindConVar(Dvars) != INVALID_HANDLE)
			SetConVarString(FindConVar(Dvars), Newval);
		else
			LogError("Silent Set: False. invlaid cvar \"%s\".", Dvars);
		return Plugin_Handled;
	}
	LogError("Silent Set: not a correct options.");
	return Plugin_Handled;
}

public Action:Cmd_TickrateSet(args)
{
	new tick = RoundToNearest(1.0 / GetTickInterval());
	
	// Config the rate.
	SetConVarInt(FindConVar("sv_minrate"), 					tick * 1000);
	SetConVarInt(FindConVar("sv_maxrate"), 					tick * 1000);
	SetConVarInt(FindConVar("sv_mincmdrate"), 				tick);
	SetConVarInt(FindConVar("sv_maxcmdrate"), 				tick + 1);
	SetConVarInt(FindConVar("sv_minupdaterate"), 			tick);
	SetConVarInt(FindConVar("sv_maxupdaterate"), 			tick + 1);
	SetConVarInt(FindConVar("sv_client_min_interp_ratio"), 	0);
	SetConVarInt(FindConVar("sv_client_max_interp_ratio"), 	0);
	SetConVarFloat(FindConVar("nb_update_frequency"), 		NB_FREQ);
	
	// These ConVars not certainly exist.
	if(FindConVar("fps_max") != INVALID_HANDLE)
		SetConVarInt(FindConVar("fps_max"), 					tick + 15);
	if(FindConVar("net_splitpacket_maxrate") != INVALID_HANDLE)
		SetConVarInt(FindConVar("net_splitpacket_maxrate"), 	tick * 1000);
	if(FindConVar("tick_door_speed") != INVALID_HANDLE)
		SetConVarFloat(FindConVar("tick_door_speed"), 			float(tick) / 100.0 * 2.0);
	
	PrintToServer("[Tickrate] Convars matched to tickrate %d", tick);
	return Plugin_Handled;
}

public GetReadyCfgName(char[] sBuffer)
{
	GetConVarString(hCvarCfgName, sBuffer, 32);
}

public IsConfoglAvailable() { return bIsConfoglAvailable; }

//***********************Natives******************************
public Native_GetModeSlots(Handle:plugin, numParams)
{
	return GetConVarInt(hCvarModeSlots);
}

public Native_IsVersus(Handle:plugin, numParams)
{
	return bool:(Mode_flag: GetConVarInt(hCvarFactMode) == MDFLAG_VERSUS);
}
