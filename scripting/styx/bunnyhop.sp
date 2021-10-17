#include <sourcemod>
#include <sdktools>

new bool: bUseAutoHops[MAXPLAYERS+1] = false;

public Plugin:myinfo=
{
	name="Auto Bunnyhop",
	author="Lindsey",
	description="admin only, for test.",
	version="2.2.2",
	url=""
}

public OnPluginStart()
{
	RegAdminCmd("sm_bhop", AutobhopCmd, ADMFLAG_KICK);
}

public OnClientPostAdminCheck(client)
{
	bUseAutoHops[client] = false;
}

public OnClientDisconnect(client)
{
	bUseAutoHops[client] = false;
}

public Action:AutobhopCmd(client, args)
{
	if(args != 0)
	{
		decl String:sBuffer[32], String:sName[32];
		GetCmdArg(1, sBuffer, sizeof(sBuffer));
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				GetClientName(i, sName, sizeof(sName));
				if(StrContains(sName, sBuffer, false) != -1)
				{
					bUseAutoHops[i] = !bUseAutoHops[i];
					PrintToChatAll("\x01[\x5SM\x01] \x05Admin \x04%N \x01toggled \x05%N's \x04Autobhop \x01state \x05%s", client, i, (bUseAutoHops[i]?"On":"Off"));
					return Plugin_Handled;
				}
			}
		}
		PrintHintText(client, "Player Not find.");
		return Plugin_Handled;
	}
	
	bUseAutoHops[client]=!bUseAutoHops[client];
	PrintHintText(client, "Autobhop state is now %s", (bUseAutoHops[client]?"On":"Off"));
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(bUseAutoHops[client])
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND))
		{
			buttons &= ~IN_JUMP;
		}
	}
	return Plugin_Continue;
}