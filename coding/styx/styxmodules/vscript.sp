#pragma semicolon 1

#if defined __vscript__
#endinput
#endif
#define __vscript__

#define 	SCRIPT_TYPE			"g_ModeScript"							//ModeScript;
#define		DOPS				"DirectorOptions"
#define		DIRECTOR			"Director"
#define		Run_Delay			0.6

static Handle: hCvarAutoInclude;
/*
public VS_OnAPL()
{
	CreateNative("IncludeVscript", Native_VsInclude);
	CreateNative("AutoIncludeOnce", Native_AutoIncludeOnce);
	CreateNative("RunDirectorScript", Native_RunDirectorScript);
}
*/

public VS_OnPluginStart()
{
	hCvarAutoInclude = CreateConVar("vscript_auto_include", "", "Auto run script", FCVAR_SPONLY);
}

public VS_OnRoundStart()
{
	CreateTimer(Run_Delay, Delay_Include, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Delay_Include(Handle:timer)
{
	decl String:sBuffer[32];
	GetConVarString(hCvarAutoInclude, sBuffer, sizeof(sBuffer));
	if(sBuffer[0] != '\0')
	{
		_VsInclude(sBuffer);
	}
	return Plugin_Handled;
}

/**
* Include a script(.nut) by its name.
*
* @param sName		the script name.
*/
stock void _VsInclude(const char[] sName)
{
	decl String:sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "g_ModeScript.IncludeScript(\"%s.nut\");", sName);
	L4D2_ExecVScriptCode(sBuffer);
	PrintToServer("[SM] Included Script:\x05%s", sName);
}