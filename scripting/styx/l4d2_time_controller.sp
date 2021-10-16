#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "[L4D2] Time Contoller",
	author = "McFlurry",
	description = "host_timescale functionality for Left 4 Dead 2.",
	version = PLUGIN_VERSION,
	url = "N/A j"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("TimeScale", Native_TimeScale);
	
	RegPluginLibrary("timescale");
	return APLRes_Success;
}

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}
	RegAdminCmd("sm_timescale", TimeScale, ADMFLAG_CHEATS ,"Change timescale of game");
}	
	
public Action:TimeScale(client, args)
{
	decl String:arg[12];
	if(args == 1)
	{
		GetCmdArg(1, arg, sizeof(arg));
		new Float:scale = StringToFloat(arg);
		if(scale == 0.0)
		{
			ReplyToCommand(client, "[SM] Invalid Float!");
			return;
		}	
		SetTimeScale(scale);
	}
	else
	{
		ReplyToCommand(client, "[SM] Usage: sm_timescale <float>");
	}	
}

stock void SetTimeScale(float scale, float duration = -0.0)
{
	if(scale <= 0.0 || scale > 16.0) return;
	char strts[8];
	FloatToString(scale, strts, sizeof(strts));
	
	static int i_Ent = INVALID_ENT_REFERENCE;
	if(IsValidEntity(i_Ent))
	{
		AcceptEntityInput(i_Ent, "Kill");
		i_Ent = INVALID_ENT_REFERENCE;
	}

	if(i_Ent == INVALID_ENT_REFERENCE || !IsValidEntity(i_Ent)){
		i_Ent = EntIndexToEntRef(CreateEntityByName("func_timescale"));
		if(i_Ent == INVALID_ENT_REFERENCE || !IsValidEntity(i_Ent)){
			LogError("Could not create 'func_timescale'");
			return;
		}
		DispatchSpawn(i_Ent);
	}

	DispatchKeyValue(i_Ent, "desiredTimescale", strts);
	DispatchKeyValue(i_Ent, "acceleration", "2.0");
	DispatchKeyValue(i_Ent, "minBlendRate", "1.0");
	DispatchKeyValue(i_Ent, "blendDeltaMultiplier", "2.0");
	AcceptEntityInput(i_Ent, "Start");

	if(duration > 0.0)
		CreateTimer(duration, ResetTimeScale, i_Ent, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:ResetTimeScale(Handle:Timer, int entity)
{
	if(IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Stop");
	}
	else
	{
		PrintToServer("[SM] i_Ent is not a valid edict!");
	}	
}	

/************************ Native ****************************/
public Native_TimeScale(Handle:plugin, numParams)
{
	float scale, time;
	scale = view_as<float>(GetNativeCell(1));
	time = view_as<float>(GetNativeCell(2));
	SetTimeScale(scale, time);
}
