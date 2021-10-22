#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#if defined __styxfunctions__
#endinput
#endif
#define __styxfunctions__

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS	2
#define TEAM_INFECTED	3

static iScriptLogic = INVALID_ENT_REFERENCE;

stock bool:IsOfficialMap()
{
	decl String:sBuffer[32];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	if(sBuffer[0] != 'c' )return false;
	if(sBuffer[1] > '9' || sBuffer[1] < '0')return false;
	return true;
}

stock ReturnPlayerToSaferoom(client, bool:flagsSet = true)
{
	new warp_flags;
	new give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

stock LogPlayerAction(client, const char[] reason)
{
	decl String:sBuffer[128];
	GetClientAuthId(client,AuthId_Steam2, sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "%N(%s):%s", client, sBuffer, reason);
	LogToFile("addons/sourcemod/logs/styx.log", "===============================================");
	LogToFile("addons/sourcemod/logs/styx.log", sBuffer);
}

stock ConnectingPlayers()
{
	new Clients = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) && IsClientConnected(i))Clients++;
	}
	return Clients;
}

stock bool:IsHumansOnServer()
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))return true;
	}
	return false;
}

stock CutStringAfter(char[] str, char search)
{
	new len = strlen(str);
	for (new i = 0; i < len; i++) {
			if (str[i] == search){
				str[i] = '\0';
				return;
			}
		}
}

stock ReplaceCharIn(char[] str, char search, char sub)
{
	new len = strlen(str);
	for (new i = 0; i < len; i++) {
			if (str[i] == search)
				str[i] = sub;
		}
}

//***********************stock************************
stock GetHumanCount()
{
	new humans = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			humans++;
		}
	}
	return humans;
}

/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
void L4D2_RunScript(const String:sCode[], any:...)
{
	// static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
		{
			LogError("Could not create 'logic_script'");
			return;
		}
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[1<<9];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	// PrintToServer(sBuffer);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
stock void _RunScript(const String:sCode[])
{
	// static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
		{
			LogError("Could not create 'logic_script'");
			return;
		}
		DispatchSpawn(iScriptLogic);
	}
	
	// static String:sBuffer[1<<9];
	// VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	//PrintToServer(sCode);
	SetVariantString(sCode);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

/**
* Include a script(.nut) by its name.
*
* @param sName		the script name.
*/
stock _VsInclude(const char[] sName)
{
	decl String:sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "g_ModeScript.IncludeScript(\"%s.nut\");", sName);
	L4D2_RunScript(sBuffer);
	PrintToServer("[SM] Included Script:\x05%s", sName);
}

/**
* Make sure client is a connected hunman player.
*
* @client client
*/
stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

stock bool:IsSpectator(client)
{
	if(IsValidClient(client) && GetClientTeam(client) == TEAM_SPECTATORS)
		return true;
	return false;
}

stock bool:IsGenericAdmin(client)
{
	new flags = GetUserFlagBits(client);
	if ((flags & ADMFLAG_ROOT) || (flags & ADMFLAG_GENERIC))
	{
		return true;
	}
	return false;
}