// #include <builtinvotes>
#include <colors>

#pragma semicolon 1
// #pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define MAX_FOOTERS 		10
#define MAX_FOOTER_LEN 		65
#define READY_DELAY 		2
#define AUTO_READY_DELAY 	2.5
#define READY_MAX_PLAYER 	10

#define COOL_DOWN_SOUND		"ui/beep07.wav"
#define LIVE_SOUND			"ui/bigreward.wav"

public Plugin:myinfo =
{
	name = "Lind3ey's Ready-Up",
	author = "Lind3ey",
	description = "New and improved ready-up plugin.",
	version = "9.2",
	url = ""
};

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

// Plugin Cvars
new Handle:		cvar_CfgName;
new Handle:		cvar_MaxPlayers;
new Handle:		cvar_HostName;
new Handle:		cvar_SvvLimit;
new Handle:		cvar_InfLimit;
new Handle:		cvar_Readymode;
new Handle:		cvar_NeedAllPlayers;
ConVar
	l4d_ready_delay;

new Handle:		liveForward;
new Handle:		leftForward;
new Handle:		menuPanel;
new Handle:		timerCooldown;
new String:		readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
new String:		sCmd[32];

new bool:		isPlayerReady[MAXPLAYERS + 1];
new bool:		hiddenPanel[MAXPLAYERS + 1];
new bool:		inLiveCountdown = false;
new bool:		inReadyUp		= false;

new bIsRoundAlived	= false;
new readyDealy		= READY_DELAY;
new ftCount 		= 0;
new iCmd 			= 0;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("AddStringToReadyFooter", Native_AddStringToReadyFooter);
	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("GetReadyCfgName", Native_GetReadyCfgName);
	liveForward = CreateGlobalForward("OnRoundIsLive", ET_Event);
	leftForward = CreateGlobalForward("OnLeftSafeArea", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public OnPluginStart()
{
	cvar_Readymode		= CreateConVar("l4d_ready_mode", 		"0", 		"0=handly , 1=auto", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_CfgName 		= CreateConVar("l4d_ready_cfg_name", 	"NoMatch",	"");
	cvar_NeedAllPlayers	= CreateConVar("l4d_ready_need_all",	"0",		"",	FCVAR_NONE, true, 0.0, true, 1.0);
	l4d_ready_delay 	= CreateConVar("l4d_ready_delay", "3", "233");
	cvar_HostName		= FindConVar("hostname");
	cvar_MaxPlayers		= FindConVar("sv_maxplayers");
	cvar_SvvLimit 		= FindConVar("survivor_limit");
	cvar_InfLimit 		= FindConVar("z_max_player_zombies");

	HookEvent("round_start", RoundStart_Event);
	HookEvent("player_team", PlayerTeam_Event);
	
	AddCommandListener(Vote_Callback, "Vote");
	
	RegAdminCmd("sm_forcestart", 	ForceStart_Cmd, ADMFLAG_KICK, 	"Forces the round to start regardless of player ready status.");
	RegAdminCmd("sm_fs", 			ForceStart_Cmd, ADMFLAG_KICK, 	"Players can unready to stop a force");
	RegConsoleCmd("sm_return", 		Return_Cmd, 					"Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_hide",	 	Hide_Cmd, 						"Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", 		Show_Cmd, 						"Shows a hidden ready-up panel");
	RegConsoleCmd("sm_ready", 		Ready_Cmd, 						"Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_toggleready", ToggleReady_Cmd, 				"Toggle your ready status");
	RegConsoleCmd("sm_unready", 	Unready_Cmd, 					"Mark yourself as not ready if you have set yourself as ready");
}

public OnClientPostAdminCheck(client) 
{
	if(!IsFakeClient(client))
	{
		//Auto Readyup
		if(inReadyUp && GetConVarBool(cvar_Readymode))
		{
			CreateTimer(AUTO_READY_DELAY, Timer_AutoReady, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnPluginEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public OnMapStart()
{
	/* OnMapEnd needs this to work */
	PrecacheSound(COOL_DOWN_SOUND);
	PrecacheSound(LIVE_SOUND);
	timerCooldown = INVALID_HANDLE;
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public OnMapEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public OnClientDisconnect(client)
{
	isPlayerReady[client] = false;
}

public Native_AddStringToReadyFooter(Handle:plugin, numParams)
{
	decl String:footer[MAX_FOOTER_LEN];
	GetNativeString(1, footer, sizeof(footer));
	if (ftCount < MAX_FOOTERS)
	{
		if (strlen(footer) < MAX_FOOTER_LEN)
		{
			strcopy(readyFooter[ftCount], MAX_FOOTER_LEN, footer);
			ftCount++;
			return _:true;
		}
	}
	return _:false;
}

public Native_GetReadyCfgName(Handle:plugin, numParams)
{
	decl String:sBuffer[32];
	GetConVarString(cvar_CfgName, sBuffer, sizeof(sBuffer));
	return true;
}

public Native_IsInReady(Handle:plugin, numParams)
{
	return _:inReadyUp;
}

public Action:ForceStart_Cmd(client, args)
{
	if (inReadyUp)
	{
		InitiateLiveCountdown();
	}
	return Plugin_Handled;
}

public Action:Vote_Callback(client, const String:command[], args)
{
	if(inReadyUp && IsPlayer(client))
	{
		decl String: sArgs[MAX_NAME_LENGTH];
		GetCmdArg(1, sArgs, sizeof(sArgs));
		if(StrContains(sArgs, "Yes", false) != -1)
		{
			isPlayerReady[client] = true;
			if(CheckFullReady())
				InitiateLiveCountdown();
		}else{
			isPlayerReady[client] = false;
			CancelFullReady();
		}
	}
	return Plugin_Continue;
}

public Action:Ready_Cmd(client, args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = true;
		if (CheckFullReady())
			InitiateLiveCountdown();
	}

	return Plugin_Handled;
}

public Action:Unready_Cmd(client, args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = false;
		CancelFullReady();
	}

	return Plugin_Handled;
}

public Action:ToggleReady_Cmd(client, args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = !isPlayerReady[client];
		if (isPlayerReady[client] && CheckFullReady())
		{
			InitiateLiveCountdown();
		}
		else
		{
			CancelFullReady();
		}
	}

	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!bIsRoundAlived)
	{
		if (GetEntityFlags(client) & FL_INWATER){ ReturnPlayerToSaferoom(client, false);}
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (inReadyUp || IsFakeClient(client))
	{
		ReturnPlayerToSaferoom(client, false);
		return Plugin_Handled;
	}
	Call_StartForward(leftForward);
	Call_Finish();
	bIsRoundAlived = true;
	return Plugin_Continue;
}

public Action:Return_Cmd(client, args)
{
	if (client > 0
			&& inReadyUp
			&& L4D2Team:GetClientTeam(client) == L4D2Team_Survivor)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

public Action:Hide_Cmd(client, args)
{
	hiddenPanel[client] = true;
	return Plugin_Handled;
}

public Action:Show_Cmd(client, args)
{
	hiddenPanel[client] = false;
	return Plugin_Handled;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{	
	bIsRoundAlived = false;
	InitiateReadyUp();
}

public PlayerTeam_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientAndInGame(client)) return;
	if( IsFakeClient(client) || !inReadyUp)return;
	
	new L4D2Team:oldteam 	= L4D2Team:GetEventInt(event, "oldteam");
	new L4D2Team:team 		= L4D2Team:GetEventInt(event, "team");
	if (oldteam == L4D2Team_Survivor || oldteam == L4D2Team_Infected || team == L4D2Team_Survivor || team == L4D2Team_Infected)
	{
		CancelFullReady();
		if(GetConVarBool(cvar_Readymode) && team != L4D2Team_Spectator )
		{ 
			CreateTimer(AUTO_READY_DELAY, Timer_AutoReady, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_AutoReady(Handle timer, client)
{
	if(IsClientAndInGame(client) && !IsFakeClient(client) && L4D2Team:GetClientTeam(client) != L4D2Team_Spectator)
	{
		isPlayerReady[client] = true;
		if (CheckFullReady())
			InitiateLiveCountdown();
	}
}

public Action:MenuRefresh_Timer(Handle:timer)
{
	if (inReadyUp)
	{
		iCmd++;
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

UpdatePanel()
{
	if (menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
		menuPanel = INVALID_HANDLE;
	}
	
	PrintCmd();
	new String:svvBuffer[800] 	= "";
	new String:infBuffer[800] 	= "";
	new String:specBuffer[800] 	= "";
	new playerCount 			= 0;
	new specCount 				= 0;
	new slots 					= GetConVarInt(cvar_MaxPlayers);
	new pnum 					= GetPlayerNum();
	menuPanel 					= CreatePanel();

	decl String:nameBuf[MAX_NAME_LENGTH*2];
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientName(client, nameBuf, sizeof(nameBuf));
			if (IsPlayer(client))
			{
				if (isPlayerReady[client])
				{
					if (!inLiveCountdown) PrintHintText(client, "You are ready.\nPress F2 or say !unready to unready.");
					Format(nameBuf, sizeof(nameBuf), "☑ %s\n", nameBuf);
				}
				else
				{
					if (!inLiveCountdown) PrintHintText(client, "You are not ready.\nPress F1 or say !ready to ready up.");
					Format(nameBuf, sizeof(nameBuf), "☐ %s\n", nameBuf);
				}
				if(GetClientTeam(client) == 2) StrCat(svvBuffer, sizeof(svvBuffer), nameBuf);
				else StrCat(infBuffer, sizeof(infBuffer), nameBuf);
			}
			else
			{
				++specCount;
				if (playerCount <= READY_MAX_PLAYER)
				{
					Format(nameBuf, sizeof(nameBuf), "%d. %s\n", specCount, nameBuf);
					StrCat(specBuffer, sizeof(specBuffer), nameBuf);
				}
			}
		}
	}

	decl String:svBuf[128];
	decl String:cfgBuf[128];
	GetConVarString(cvar_HostName, svBuf, sizeof(svBuf));
	CutStringAfter(svBuf, '|');
	GetConVarString(cvar_CfgName, cfgBuf, sizeof(cfgBuf));
	Format(svBuf,sizeof(svBuf),"▸ Server: %s \n▸ Slots: %d/%d | Tickrate: %d \n▸ Config: %s", svBuf, pnum, slots, RoundToNearest(1.0 / GetTickInterval()), cfgBuf);
	DrawPanelText(menuPanel, svBuf);
	DrawPanelText(menuPanel, "▸ Commands:");
	DrawPanelText(menuPanel, sCmd);
	DrawPanelText(menuPanel, "  "); //Blank Line
	
	new bufLen = strlen(svvBuffer);
	if (bufLen != 0)
	{
		svvBuffer[bufLen] = '\0';
		ReplaceString(svvBuffer, sizeof(svvBuffer), "#buy", "<- TROLL");
		ReplaceString(svvBuffer, sizeof(svvBuffer), "#", "_");
		DrawPanelText(menuPanel, "->1. Survivors:");
		DrawPanelText(menuPanel, svvBuffer);
	}

	bufLen = strlen(infBuffer);
	if (bufLen != 0)
	{
		infBuffer[bufLen] = '\0';
		ReplaceString(infBuffer, sizeof(infBuffer), "#buy", "<- TROLL");
		ReplaceString(infBuffer, sizeof(infBuffer), "#", "_");
		DrawPanelText(menuPanel, "->2. Infected:");
		DrawPanelText(menuPanel, infBuffer);
	}

	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		DrawPanelText(menuPanel, "->3. Spectators:");
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > READY_MAX_PLAYER)
		FormatEx(specBuffer, sizeof(specBuffer), "->1. Many (%d)", specCount);
		DrawPanelText(menuPanel, specBuffer);
	}

	DrawPanelText(menuPanel, " ");
	for (new i = 0; i < MAX_FOOTERS; i++)
	{
		DrawPanelText(menuPanel, readyFooter[i]);
	}

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
		{
			SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

public DummyHandler(Handle:menu, MenuAction:action, param1, param2) { }

PrintCmd()
{
	if (iCmd > 5) iCmd = 1;
	switch (iCmd)
	{
		case 1: 	Format(sCmd, 32, "->1. !away/!join");
		case 2: 	Format(sCmd, 32, "->2. !slots #");
		case 3: 	Format(sCmd, 32, "->3. !match/!rmatch");
		case 4: 	Format(sCmd, 32, "->4. !vote");
		case 5: 	Format(sCmd, 32, "->5. !bot");
	}
}

InitiateReadyUp()
{
	for (new i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
	}

	UpdatePanel();
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	inReadyUp = true;
	inLiveCountdown = false;
	timerCooldown = INVALID_HANDLE;

	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
	SetConVarInt(FindConVar("sb_stop"),1);
}

InitiateLive(bool:real = true)
{
	inReadyUp = false;
	inLiveCountdown = false;
	SetConVarInt(FindConVar("sb_stop"),0);
	SetTeamFrozen(L4D2Team_Survivor, false);
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.0);

	for (new i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}

	for (new i = 0; i < MAX_FOOTERS; i++)
	{
		readyFooter[i] = "";
	}

	ftCount = 0;
	if (real)
	{
		Call_StartForward(liveForward);
		Call_Finish();
	}
}

ReturnPlayerToSaferoom(client, bool:flagsSet = true)
{
	new warp_flags;
	new give_flags;
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

ReturnTeamToSaferoom(L4D2Team:team)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

bool:CheckFullReady()
{
	if(ConnectingPlayers()) return false;
	new playerCount = 0;
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (!IsFakeClient(client) && IsPlayer(client))
			{
				if(!isPlayerReady[client])return false;
				playerCount++;
			}
		}
	}
	
	if(IsVersus())
		return playerCount >= GetConVarInt(cvar_SvvLimit) + GetConVarInt(cvar_InfLimit);
	else
		return playerCount > 0;
}

InitiateLiveCountdown()
{
	if (timerCooldown == INVALID_HANDLE)
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, true);
		PrintHintTextToAll("Going live!\nPress F2 to cancel");
		inLiveCountdown = true;
		readyDealy = READY_DELAY;
		timerCooldown = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ReadyCountdownDelay_Timer(Handle:timer)
{
	if (readyDealy == 0)
	{
		PrintHintTextToAll("Round is live!");
		InitiateLive();
		timerCooldown = INVALID_HANDLE;
		EmitSoundToAll(LIVE_SOUND, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Live in: %d\nPress F2 to cancel", readyDealy);
		EmitSoundToAll(COOL_DOWN_SOUND, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		readyDealy--;
	}
	return Plugin_Continue;
}

CancelFullReady()
{
	if (timerCooldown != INVALID_HANDLE)
	{
		inLiveCountdown = false;
		CloseHandle(timerCooldown);
		timerCooldown = INVALID_HANDLE;
		PrintHintTextToAll("Countdown Cancelled!");
	}
}

SetTeamFrozen(L4D2Team:team, bool:freezeStatus)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == team)
		{
			SetClientFrozen(client, freezeStatus);
		}
	}
}

stock SetClientFrozen(client, freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

stock IsPlayer(client)
{
	if (!client || !IsClientInGame(client)) return false;
	new L4D2Team:team = L4D2Team:GetClientTeam(client);
	return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

/**
*Return how many real players in the server.
*
*@return int
*/ 
stock GetPlayerNum(){
	new count = 0;
	for(new i= 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsFakeClient(i)) count++;
	return count;
}

bool:IsVersus()
{
	return GetConVarBool(cvar_NeedAllPlayers);
}

stock bool:IsClientAndInGame(index) { return (index > 0 && index <= MaxClients && IsClientInGame(index));}

stock bool:ConnectingPlayers()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) && IsClientConnected(i))return true;
	}
	return false;
}

stock CutStringAfter(char[] str, char search)
{
	new len = strlen(str);
	for (new i = 0; i < len; i++) {
			if (str[i] == search)
				str[i] = '\0';
		}
}
