#pragma semicolon 1

#include <builtinvotes>

static Handle: 	hBuiltinvote 			= INVALID_HANDLE;
static bool:   	bTeamFailedChecked		= false;
static 			mp_round_to_skip		= 3;
float			versus_restarttimer 	= 5.0;

#define STRINGSKIP		"{green}%s$                       {blue}Skip current chapter!"
#define STRINGRESTART	"{green}%s$                       {blue}Restart in %.1f seconds!"

bool StartVoteRestart()
{
	if(IsNewBuiltinVoteAllowed())
	{
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		decl String:sMsgs[128];
		Format(sMsgs, sizeof(sMsgs), "Try it again? (Yes/No)\n(or JUMP to next chapter)");
		SetBuiltinVoteArgument(hBuiltinvote, sMsgs);
		SetBuiltinVoteInitiator(hBuiltinvote, BUILTINVOTES_SERVER_INDEX);
		SetBuiltinVoteResultCallback(hBuiltinvote, RestartResultHandler);
		DisplayBuiltinVoteToAllNonSpectators(hBuiltinvote, 5);
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
			hBuiltinvote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			/*********************** RESTART Vote failed **************************/
			DirectorFailCheckOn();
			CPrintToChatAll(STRINGSKIP, hostfile);
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public RestartResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				RestartInSeconds(versus_restarttimer);
				DisplayBuiltinVotePass(vote, "☑CHAPTER RESTARTING...");
				return;
			}
		}
	}
	
	/*********************** RESTART Vote failed **************************/
	DirectorFailCheckOn();
	CPrintToChatAll(STRINGSKIP, hostfile);
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public void RestartInSeconds(float seconds)
{
	CreateTimer(seconds, Delay_Restart, _, TIMER_FLAG_NO_MAPCHANGE);
	CPrintToChatAll(STRINGRESTART, hostfile, seconds);
}

public Action:Delay_Restart(Handle timer)
{
	SetConVarInt(FindConVar("mp_restartgame"), 42); 	//this value make no sense, just nonzero.
}

public Action:Timer_CheckFail(Handle:timer)
{
	if(bTeamFailedChecked) return Plugin_Continue;	//Get Checked!
	if(bIsRoundAlived && InSecondHalfOfRound())
	{
		if(IsSurvivorTeamFailed())
		{
			bTeamFailedChecked 	 = true;
			CreateFakeEnd();
			L4D2_HideVersusScoreboard();
			if(iRoundCounter < mp_round_to_skip || L4D_IsMissionFinalMap() || !HasNonSpectators())
			{
				RestartInSeconds(versus_restarttimer);
			}
			else if(!StartVoteRestart())
			{
				DirectorFailCheckOn();
				L4D2_HideVersusScoreboard();
				CPrintToChatAll(STRINGSKIP, hostfile);
			}
		}
	}
	return Plugin_Handled;
}

stock void CreateFakeEnd()
{
	static Handle:event_end;
	event_end = INVALID_HANDLE;
	
	event_end = CreateEvent("round_end", true);
	SetEventInt(event_end, "winner", 0);
	SetEventInt(event_end, "reason", 5);
	SetEventString(event_end, "message", "styxend");
	FireEvent(event_end);
	event_end = INVALID_HANDLE;
	
	event_end = CreateEvent("mission_lost", true);
	FireEvent(event_end);
	event_end = INVALID_HANDLE;
	EmitSoundToAll("music/undeath/death.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
}

void DirectorFailCheckOff()
{
	hCvarDirectorCheck.SetBool(true);
}

void DirectorFailCheckOn()
{
	hCvarDirectorCheck.SetBool(false);
	L4D2_HideVersusScoreboard();
}

public void VR_ActiveRound()
{
	bTeamFailedChecked	= false;
	if(InSecondHalfOfRound()) 
	{ 
		DirectorFailCheckOff(); 
	}
}

public void VR_DeActiveRound()
{
	bTeamFailedChecked	= false;
	DirectorFailCheckOn();
	versus_restarttimer = FindConVar("versus_round_restarttimer").FloatValue;
	mp_round_to_skip = hCvarSkipRound.IntValue;
}

public bool:HasNonSpectators()
{
	_forall(client)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != TEAM_SPECTATORS)
		{
			return true;
		}
	}
	return false;
}