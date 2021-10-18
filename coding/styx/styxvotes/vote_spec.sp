#pragma semicolon 1

static Handle:hBuiltinvote;
static iObject;

public ShowSpecMenu(client)
{
	new Handle:menu = CreateMenu(SpecMenuHandler);
	new index = 0;
	decl String:title[100];
	new String:playername[128];
	new String:identifier[64];
	Format(title, sizeof(title), "%s", "Choose player:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	for (new i = 1; i < MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1)
		{
			index++;
			GetClientName(i, playername, sizeof(playername));
			Format(identifier, sizeof(identifier), "%i", i);
			AddMenuItem(menu, identifier, playername);
		}
	}
	if(index == 0){
		AddMenuItem(menu, "0", "No one to move");
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


SpecMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[12]; 
		
		if(GetMenuItem(menu, param2, info, sizeof(info)))
		{
			if(StartVoteSpec(StringToInt(info), param1)) { FakeClientCommand(param1, "Vote Yes");}
			LogMessage("|Vote|Player %N try to move %N to SPEC.", param1, StringToInt(info));
		}		
	}
	else if (action == MenuAction_End)
	{		
		CloseHandle(menu);
	}
}

bool:StartVoteSpec(cobject, csubject)
{
	if (IsNewBuiltinVoteAllowed() && IsClientInGame(cobject) && IsClientInGame(csubject))
	{
		iObject = cobject;
		new String: sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Move %N to spectator?", cobject);
		
		hBuiltinvote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hBuiltinvote, sBuffer);
		SetBuiltinVoteInitiator(hBuiltinvote, csubject);
		SetBuiltinVoteResultCallback(hBuiltinvote, SpecVoteResultHandler);
		DisplayBuiltinVoteToAll(hBuiltinvote, 5);
		return true;
	}
	PrintToChat(csubject, "\x01[\x04!\x01]new \x05Vote \x01cannot be started now.");
	return false;
}

public SpecVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				if(IsClientInGame(iObject)) 
				{
					ChangeClientTeam(iObject, 1);
					PrintToChatAll("\x01[\x05Vote\x01] Moved \x04%N \x01to spectator.", iObject);
					LogMessage("|Vote| Moved %N to spec.", iObject);
				}
				DisplayBuiltinVotePass(vote, "Moved the player to spectator.");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}