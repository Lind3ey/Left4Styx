#pragma semicolon 1

static Handle:	hKickVote;
static			iKick;

public ShowKickMenu(client)
{
	new Handle:menu = CreateMenu(KickMenuHandler);
	new index = 0;
	decl String:title[100];
	new String:playername[128];
	new String:identifier[64];
	Format(title, sizeof(title), "%s", "Choose player:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	for (new i = 1; i < MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && !IsFakeClient(i))
		{
			index++;
			GetClientName(i, playername, sizeof(playername));
			Format(identifier, sizeof(identifier), "%i", i);
			AddMenuItem(menu, identifier, playername);
		}
	}
	if(index == 0){
		AddMenuItem(menu, "0", "No one to kick");
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

KickMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[12]; 
		
		if(GetMenuItem(menu, param2, info, sizeof(info)))
		{
			if(StartVoteKick(StringToInt(info), param1))
			{
				FakeClientCommand(param1, "Vote Yes");
				FakeClientCommand(StringToInt(info), "Vote No");
			}
		}		
	}
	else if (action == MenuAction_End)
	{		
		CloseHandle(menu);
	}
}

bool:StartVoteKick(cobject, csubject)
{
	if (IsNewBuiltinVoteAllowed() && IsClientInGame(cobject) && IsClientInGame(csubject))
	{
		iKick = cobject;
		new String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Kick Player %N?", cobject);
		
		hKickVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hKickVote, sBuffer);
		SetBuiltinVoteInitiator(hKickVote, csubject);
		SetBuiltinVoteResultCallback(hKickVote, KickVoteResultHandler);
		DisplayBuiltinVoteToAll(hKickVote, 10);
		return true;
	}
	PrintToChat(csubject, "\x01[\x04!\x01]new \x05Vote \x01cannot be started now.");
	return false;
}

public KickVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				if(IsClientInGame(iKick)) 
				{ 
					KickClient(iKick, "Vote Kicked.");
				}
				DisplayBuiltinVotePass(vote, "Kicked the player.");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}