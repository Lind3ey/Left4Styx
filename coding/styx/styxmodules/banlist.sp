#pragma semicolon 1

#include <sourcemod>

#define		 _BAN_LOAD_DELAY_	5.0
#define	 	 CONSOLE			0
#define		 BAN_TIME			0
#define		 BAN_REASON			"Styx_Auto"

#define		 BANLIST_FILE		"cfgs/banlist.cfg"

static iBanCount = 0;

public BL_OnPluginStart()
{
	RegServerCmd("styx_addban", StyxBan);
	CreateTimer(_BAN_LOAD_DELAY_, Delay_LoadBan);
}

public Action: Delay_LoadBan(Handle:timer)
{
	ServerCommand("exec %s", BANLIST_FILE);
	PrintToServer(">>>> Styx Auto BANED %d SteamID", iBanCount);
}

public Action:StyxBan(args)
{
	if(args == 1)
	{
		decl String:sBuffer[32];
		GetCmdArg(1, sBuffer, sizeof(sBuffer));
		BanIdentity(sBuffer, BAN_TIME, BANFLAG_AUTHID, BAN_REASON, "sm_addban", CONSOLE);
		iBanCount ++;
	}
	return Plugin_Handled;
}