#pragma semicolon 1


#define MIN(%0,%1) (((%0) > (%1)) ? (%1) : (%0))

static Handle: hCvarmaxSlots;
static Handle: hCvarCurSlots;

static Handle: hSlotVote;
static 		   islotsvote;

public RegSlotsVote()
{
	RegConsoleCmd("sm_slots",			Cmd_VoteSlots);
	
	hCvarmaxSlots 	= CreateConVar("sv_maxslots", "8", "Maximum amount of slots you wish players to be able to vote for.");
	hCvarCurSlots	= FindConVar("sv_maxplayers");
}

public Action: Cmd_VoteSlots(client, args)
{
	if (args == 0)
	{
		new pnum  = GetPlayerNum();
		new slots  = GetConVarInt(hCvarCurSlots);
		PrintToChat(client, "\x01[\x04Slots\x01] \x01Current slots\x01: \x04%d\x01/\x04%d", pnum, slots);
	}
	else if (args == 1)
	{
		char sTemp[16];
		GetCmdArg(1, sTemp, sizeof(sTemp));
		new slots 	= StringToInt(sTemp, 10);
		new mslots  = GetConVarInt(hCvarmaxSlots);
		
		if(IsGenericAdmin(client))
		{
			slots = MIN(slots, mslots);
			SetConVarInt(hCvarCurSlots, slots);
			if(!client)
			{
				CPrintToChatAll("{olive}* {olive}Admin {blue}Server {olive}has limited slots to {blue}%i", client, slots);
				PrintToServer("Server slots change to %d", slots);
				return Plugin_Handled;
			}
			CPrintToChatAllEx(client, "{teamcolor}* {olive}Admin {teamcolor}%N {olive}has limited slots to {teamcolor}%i", client, slots);
			PrintToServer("Server slots change to %d", slots);
			return Plugin_Handled;
		}
		
		if (!IsSlotsLegeal(slots))
		{ 
			PrintToChat(client, "\x01[\x04Slots\x01] Slots shouldn't lower than required number and above %d on this server", mslots);
			return Plugin_Handled;
		}
	
		if (StartSlotVote(client, slots)) { FakeClientCommand(client, "Vote Yes"); }
		return Plugin_Handled;
	}
	
	PrintToChat(client, "\x01[\x04Slots\x01] Usage: \x05!slots \x01<\x04number\x01> | Example: \x04!slots 5");
	return Plugin_Handled;
}


bool:StartSlotVote(client, slots)
{
	if (IsNewBuiltinVoteAllowed() && IsClientInGame(client))
	{
		islotsvote	= slots;
		new String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Change server slots to %d", slots);
		
		hSlotVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hSlotVote, sBuffer);
		SetBuiltinVoteInitiator(hSlotVote, client);
		SetBuiltinVoteResultCallback(hSlotVote, SlotVoteResultHandler);
		DisplayBuiltinVoteToAll(hSlotVote, 10);
		return true;
	}
	PrintToChat(client, "\x01[\x04!\x01]new \x05Vote \x01cannot be started now.");
	return false;
}

public SlotVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				SetConVarInt(hCvarCurSlots, islotsvote);
				PrintToServer("Server slots change to %d", islotsvote);
				DisplayBuiltinVotePass(vote, "Slots changed.");
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

bool:IsSlotsLegeal(slots)
{
	if(slots > GetConVarInt(hCvarmaxSlots)) return false;
	return slots >= FindConVar("survivor_limit").IntValue;
}
/**
*Return how many real players in the server.
*
*@return int
*/ 
stock GetPlayerNum(){
	new count = 0;
	for(new i= 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i)) count++;
	return count;
}
