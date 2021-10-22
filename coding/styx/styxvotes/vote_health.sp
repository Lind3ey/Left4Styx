#pragma semicolon 1

static Handle:hBuiltinvote;

static Handle:hCvarAllowVoteHealth;

public RegHealthVote()
{
	RegConsoleCmd("sm_vhp",				Cmd_VoteHealth);
	hCvarAllowVoteHealth = CreateConVar("sv_allow_votehealth", "0", "", FCVAR_CHEAT);
}

public Action:Cmd_VoteHealth(client, args)
{
	if(IsGenericAdmin(client))
	{
		GiveAllSurvivorsHealth();
		CPrintToChatAllEx(client, "{teamcolor}* {olive}Admin {teamcolor}%N {olive}restored survivors health.", client);
		LogPlayerAction(client, "Use vote restore health.");
		return Plugin_Handled;
	}
	if(!GetConVarBool(hCvarAllowVoteHealth)) return Plugin_Handled;
	if(IsClientInGame(client) && GetClientTeam(client) != 1)
	{
		if(StartVoteHp(client)) 
		{ 
			FakeClientCommand(client, "Vote Yes");
			LogPlayerAction(client, "Use vote restore health.");
		}
	}
	return Plugin_Handled;
}

bool:StartVoteHp(client) 
{
	if (IsNewBuiltinVoteAllowed())
	{
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hBuiltinvote, "Restore survivors' Health value?");
		SetBuiltinVoteInitiator(hBuiltinvote, client);
		SetBuiltinVoteResultCallback(hBuiltinvote, HPVoteResultHandler);
		DisplayBuiltinVoteToAllNonSpectators(hBuiltinvote, 5);
		return true;
	}
	return false;
}

public HPVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				GiveAllSurvivorsHealth();
				DisplayBuiltinVotePass(vote, "Restored.");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

/**
* Recover all survivors' health.
*/
stock GiveAllSurvivorsHealth()
{
	for (new i = 1; i <= MaxClients; i++)
	{
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			new userflags = GetUserFlagBits(i);
			SetUserFlagBits(i, ADMFLAG_ROOT);
			new iflags=GetCommandFlags("give");
			SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
			FakeClientCommand(i,"give health");
			SetCommandFlags("give", iflags);
			SetUserFlagBits(i, userflags);
			SetEntPropFloat(i, Prop_Send, "m_healthBuffer", 0.0);
			SetEntProp(i, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 0);
        }
    }
}

public bool:IsVoteHealthAvailible()
{
	return GetConVarBool(hCvarAllowVoteHealth);
}
