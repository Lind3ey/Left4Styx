#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define		FF_LOG		10
#define 	ANC_MINFF	5

#define 	allclient(i)  for(new i=MAXPLAYERS;i>0;i--)

new Handle: AnnounceEnable;
new Handle: AnnounceType;
new Handle:	FFTimer[MAXPLAYERS+1]; 
new bool:	FFActive[MAXPLAYERS+1]; 

new DamageCache[MAXPLAYERS+1][MAXPLAYERS+1]; 

public Plugin:myinfo = 
{
	name = "L4D2 FF Announce",
	author = "Lind3ey",
	description = "Friendly Fire Announcements",
	version = "3.2",
	url = "",
}

public OnPluginStart()
{
	AnnounceEnable 	= CreateConVar("l4d_ff_announce_enable", 	"1", "Enable Announcing Friendly Fire", FCVAR_SPONLY);
	AnnounceType 	= CreateConVar("l4d_ff_announce_type", 		"0", "Changes how to displays FF damage (0:In private 1, HINT 2,public)", FCVAR_SPONLY);
	
	HookEvent("player_hurt_concise", Event_HurtConcise, EventHookMode_Post);
}

public Action:Event_HurtConcise(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarInt(AnnounceEnable)) return;
	
	new attacker 	= GetEventInt(event, "attackerentid");
	new victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (attacker > MaxClients || attacker < 1) return;
	if (!IsClientConnected(attacker) || !IsClientInGame(attacker) || IsFakeClient(attacker) || GetClientTeam(attacker) != 2 ) return;
	if (!IsClientConnected(victim)   || !IsClientInGame(victim)   || GetClientTeam(victim) != 2) return; 
	
	new damage = GetEventInt(event, "dmg_health");
	if (FFActive[attacker])  
	{
		DamageCache[attacker][victim] += damage;
		KillTimer(FFTimer[attacker]);
		FFTimer[attacker] = CreateTimer(1.5, AnnounceFF, attacker);
	}
	else 
	{
		DamageCache[attacker][victim] = damage;
		FFActive[attacker] = true;
		FFTimer[attacker] = CreateTimer(1.0, AnnounceFF, attacker);
		
		allclient(i)
		{
			if (i != attacker && i != victim)
			{
				DamageCache[attacker][i] = 0;
			}
		}
	}
}

public Action:AnnounceFF(Handle:timer, any:attacker) 
{
	FFActive[attacker] = false;
	
	if (!attacker || !IsClientInGame(attacker) || IsFakeClient(attacker)) return Plugin_Handled;
		
	allclient(i)
	{
		if (DamageCache[attacker][i] != 0 && attacker != i)
		{
			if (DamageCache[attacker][i] >= ANC_MINFF && IsClientInGame(i))
			{
				switch(GetConVarInt(AnnounceType))
				{
					case 0:
					{
						PrintToChat(attacker, "\x01× \x03FriendlyFire\x01(\x04you \x01-> \x04%N\x01, \x03damage \x01= \x03%d\x01).", i, DamageCache[attacker][i]);
						if (!IsFakeClient(i))
							PrintToChat(i, "\x01▷ \x03FriendlyFire\x01(\x04you \x01<- \x04%N\x01, \x03damage \x01= \x03%d\x01).", attacker,DamageCache[attacker][i]);
					}
					case 1:
					{
						PrintHintText(attacker, "You did %d FF to %N", DamageCache[attacker][i],i);
						if (!IsFakeClient(i))
							PrintHintText(i, "%N did %d friendly fire to you", attacker,DamageCache[attacker][i]);
					}
					case 2:
					{
						PrintToChatAll("\x04%N \x01did \x03%d \x01friendly fire damage to \x04%N", attacker, DamageCache[attacker][i],i);
					}
				}
			}
			if(DamageCache[attacker][i] > FF_LOG && IsClientInGame(i) && IsClientInGame(attacker))
			{
				LogToFile("addons/sourcemod/logs/abnormalff.log", "!!! %N did %d friendly fire to %N.", attacker, DamageCache[attacker][i], i);
			}
			DamageCache[attacker][i] = 0;
		}
	}
	return Plugin_Handled;
}