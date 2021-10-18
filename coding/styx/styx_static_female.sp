#include <sourcemod>
#include <sdktools>
#include <styxutils>

public Plugin:myinfo = 
{
	name = "Styx Static Female Character",
	author = "Lind3ey",
	description = "Static Characters model",
	version = "210704",
	url = "?"
}

#define INDEX_ROCHELLE 		1
#define INDEX_ZOEY 			5

#define SET_CHARACTER_ZOEY 			SetEntProp(i, Prop_Send, "m_survivorCharacter", 1);
#define SET_CHARACTER_ROCHELLE 		SetEntProp(i, Prop_Send, "m_survivorCharacter", 1);

ConVar 
	Cvar_survivorlimit;

static const String:fFmModel[2][] = {
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_teenangst.mdl"
}

static const String:L4D2cModel[4][] ={
	"gambler",
	"producer",
	"coach",
	"mechanic"
}

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);	
	Cvar_survivorlimit = FindConVar("survivor_limit");
}

public OnMapStart()
{
	if(!IsModelPrecached(fFmModel[0])) PrecacheModel(fFmModel[0]);
	if(!IsModelPrecached(fFmModel[1])) PrecacheModel(fFmModel[1]);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new nSurvivor = Cvar_survivorlimit.IntValue;
	if(nSurvivor < 4)
	{
		CreateTimer(0.5, ForceOneFemale, nSurvivor, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ForceOneFemale(Handle:timer, nSurvivor)
{
	if(SurvivorHasIndex(1) > 0) return Plugin_Stop;
	if(IsL4DChar() && ForceOneZoey()) return Plugin_Stop;
	else if(ForceOneRochelle()) return Plugin_Stop;
	return Plugin_Continue;
}

bool ForceOneZoey()
{
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Send, "m_survivorCharacter", 1);
			SetEntityModel(i, fFmModel[1]);
			PrintToServer("[Styx] Force %N to be ZOEY.", i);
			if(!IsFakeClient(i)) PrintToConsole(i,"\x03[Styx]\x04 your charactor is forced to be ZOEY.");
			return true;
		}
	}
	return false;
}

bool ForceOneRochelle()
{
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Send, "m_survivorCharacter", 1);
			SetEntityModel(i, fFmModel[0]);
			PrintToServer("[Styx] Force %N to be Rochelle.", i);
			if(!IsFakeClient(i)) PrintToConsole(i,"\x03[Styx]\x04 your charactor is forced to be Ro.");
			return true;
		}
	}
	return false;
}

stock int SurvivorHasIndex(int index)
{
	new offset = FindSendPropInfo("CTerrorPlayer", "m_survivorCharacter");
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			if(GetEntData(i, offset, 1) == index) return i;
		}
	}
	return -1;
}

stock bool IsL4DChar()
{
	decl String:sBuffer[64];
	_allclients(i)
	{
		if(IsClientInGame(i) && IsSurvivor(i) && IsPlayerAlive(i))
		{
			GetClientModel(i, sBuffer, sizeof(sBuffer));
			for(new j = 0; j < 4; j++)
			{
				if(StrContains(sBuffer, L4D2cModel[j], false) != -1) return false;
			}
		}
	}
	return true;
}