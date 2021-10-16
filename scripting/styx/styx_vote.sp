#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
// #include <styxframe>
#include <colors>

#include "styxvotes/vote_slots.sp"
#include "styxvotes/vote_kick.sp"
#include "styxvotes/vote_spec.sp"
#include "styxvotes/vote_health.sp"

public Plugin:myinfo = 
{
	name = "Styx VoteMenu.", 
	author = "Lind3ey", 
	description = "Vote menu", 
	version = "1.0", 
	url = ""
};

public OnPluginStart()
{	
	RegConsoleCmd("sm_votemenu",		Cmd_VoteMenu);
	RegConsoleCmd("sm_vote", 			Cmd_VoteMenu);
	RegHealthVote();
	RegSlotsVote();
}

public Action: Cmd_VoteMenu(client, args)
{
	ShowVoteMenu(client);
	return Plugin_Handled;
}

public ShowVoteMenu(client)
{
	new Handle:hMenu = CreateMenu(VoteMenuHandler);
	
	SetMenuTitle(hMenu, "Select a vote:");
	AddMenuItem(hMenu, 	"spec", "Move sb to Spec");
	AddMenuItem(hMenu, 	"kick", "Kick sb");
	AddMenuItem(hMenu, 	"slot", "Server slots(!slots)");
	if(IsVoteHealthAvailible())
	{
		AddMenuItem(hMenu,	"vhp",	"Restore Health(!vhp)");
	}
	AddMenuItem(hMenu, 	"vmap",	"Add-on Maps(!vmap)" );
	
	DisplayMenu(hMenu, client, 20);
}

VoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "spec"))	ShowSpecMenu(param1);
		if(StrEqual(sInfo, "kick"))	ShowKickMenu(param1);
		if(StrEqual(sInfo, "slot"))	FakeClientCommand(param1, "sm_slots");
		if(StrEqual(sInfo, "vmap"))	FakeClientCommand(param1, "sm_vmap");
		if(StrEqual(sInfo, "vhp"))	FakeClientCommand(param1, "sm_vhp");
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
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

stock bool:IsGenericAdmin(client)
{
	if(!client) return true;		// Console
	new flags = GetUserFlagBits(client);
	if ((flags & ADMFLAG_ROOT) || (flags & ADMFLAG_GENERIC))
	{
		return true;
	}
	return false;
}

stock LogPlayerAction(client, const char[] reason)
{
	decl String:sBuffer[128];
	GetClientAuthId(client,AuthId_Steam2, sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "%N(%s):%s", client, sBuffer, reason);
	LogToFile("addons/sourcemod/logs/styx.log", "===============================================");
	LogToFile("addons/sourcemod/logs/styx.log", sBuffer);
}
