#pragma semicolon 1

#if defined __servernamer__
#endinput
#endif
#define __servernamer__

#define		HOST_NAME_PATH		"configs/hostname.txt"

static		iMainnames		=	0;
static String:Mainnames[8][32];

public SN_OnPluginStart()
{
	iMainnames = LoadNames();
	RegServerCmd("sm_styx_hostname",		Cmd_SetName);	
}

public Action:Cmd_SetName(args)
{
	static iNameIndex = 0;

	SetConVarString(FindConVar("hostfile"), hostfile);
	
	if(iMainnames > 0 && iNameIndex == 0)
		iNameIndex = GetRandomInt(1, iMainnames);
		
	decl String:sBuffer[64];
	if(IsConfoglAvailable() && LGO_IsMatchModeLoaded())
	{
		GetReadyCfgName(sBuffer);
		Format(sBuffer, sizeof(sBuffer),"%s|%s",Mainnames[iNameIndex], sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer),"%s",Mainnames[iNameIndex]);
	}
	
	SetConVarString(FindConVar("hostname"),sBuffer,false,false);
	PrintToServer("[StyxFrame] Hostname has bee set to [%s]", sBuffer);
	
	if(iMainnames > 0)
	{
		iNameIndex++;
		if(iNameIndex > iMainnames)
			iNameIndex = 1;
	}
}

public LoadNames()
{
	Format(Mainnames[0], 64, "Whatever");
	
	decl String:sBuffer[64];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), HOST_NAME_PATH);
	Handle hNameFile = OpenFile(sBuffer, "r", false);
	if (hNameFile)
	{	
		new index = 1;
		if(ReadFileLine(hNameFile, hostfile, sizeof(hostfile)))
			CutStringAfter(hostfile, '\n');

		while(index < 8 && ReadFileLine(hNameFile, Mainnames[index], 32))
			CutStringAfter(Mainnames[index++], '\n');

		return index - 1;
	}
	return 0;
}
