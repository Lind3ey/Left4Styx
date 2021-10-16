#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <weapons>

#pragma semicolon 1

#define PLUGIN_VERSION "1.1"

#define TEAM_SURVIVOR 2
#define PILL_INDEX 0
#define ADREN_INDEX 1

new BotStore[2];

public Plugin:myinfo = 
{
	name = "[L4D & L4D2] AI Fix",
	author = "sereky",
	description = "Survivor bots will not prefer pistols if they have sniper rifle.",
	version = PLUGIN_VERSION,
	url = "URL"
}

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("round_start",Event_RoundStart,EventHookMode_PostNoCopy);
	HookEvent("total_ammo_below_40", 	OnAlmostOut,		EventHookMode_Post);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public OnLeftSafeArea()
{
	for (new i = MaxClients; i > 0; i--)
	{
		if(IsClientInGame(i) 
			&& IsFakeClient(i) 
			&& GetClientTeam(i) == 2 
			&& IsPlayerAlive(i)
			&& GetPlayerWeaponSlot(i, 0) == -1)
		{
			new flags = GetCommandFlags("give");    
			SetCommandFlags("give", flags & ~FCVAR_CHEAT);
			FakeClientCommand(i, "give smg");
			SetCommandFlags("give", flags|FCVAR_CHEAT);
		}
	}
}

public Action:OnAlmostOut(Handle:event, const String:name[], bool:dontBroadcast)
{
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetClientTeam(player) == TEAM_SURVIVOR && IsFakeClient(player))
    {
        new flags = GetCommandFlags("give");    
        SetCommandFlags("give", flags & ~FCVAR_CHEAT);
        FakeClientCommand(player, "give ammo");
        SetCommandFlags("give", flags|FCVAR_CHEAT);
    }
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!victim
	|| !IsClientInGame(victim)
	|| GetClientTeam(victim) != 2)
	{
		return;
	}
	
	if(HasBotStore())
	{
		if(GetClientTotalHealth(victim) < 39 && GetPlayerWeaponSlot(victim, 4) == -1 && !IsPlayerIncap(victim))
		{
			RestoreItems(victim);
		}
	}
}

public bool:HasBotStore()
{
	return BotStore[0] || BotStore[1];
}

public Action:OnWeaponSwitch(client, weapon)
{
	if (IsClientConnected(client))
	{
		if (IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			if (!IsIncapacitated(client))
			{
				decl String:sClassname[32];
				GetEdictClassname(weapon, sClassname, sizeof(sClassname));
				new WeaponId:wep = WeaponNameToId(sClassname);
				if (wep == WEPID_PISTOL || wep == WEPID_MELEE)
				{
					new i_Weapon = GetPlayerWeaponSlot(client, 0);
					if (i_Weapon != -1)
					{
						FakeClientCommand(client, "+reload");
						FakeClientCommand(client, "-reload");
						return Plugin_Handled;
					}
				}
				if (wep == WEPID_PAIN_PILLS || wep == WEPID_ADRENALINE)
				{
					if (GetClientTotalHealth(client) < 39) return Plugin_Continue;
					/* end of L4D2 specific stuff */
					new target = GetNeedTarget(client);
					if(target > 0){
						AcceptEntityInput(GetPlayerWeaponSlot(client, 4), "Kill");
						new ent = CreateEntityByName(WeaponNames[wep]);
						DispatchSpawn(ent);
						EquipPlayerWeapon(target, ent);

						new Handle:hFakeEvent = CreateEvent("weapon_given");
						SetEventInt(hFakeEvent, "userid", GetClientUserId(target));
						SetEventInt(hFakeEvent, "giver", GetClientUserId(client));
						SetEventInt(hFakeEvent, "weapon", _:wep);
						SetEventInt(hFakeEvent, "weaponentid", ent);
						FireEvent(hFakeEvent);
						PrintHintText(client, "You get a bot stored item");
						return Plugin_Handled;
					}
					
					if (wep == WEPID_PAIN_PILLS)
					{
						BotStore[PILL_INDEX]++;
					}
					else if (wep == WEPID_ADRENALINE)
					{
						BotStore[ADREN_INDEX]++;
					}
					AcceptEntityInput(GetPlayerWeaponSlot(client, 4), "Kill");
					return Plugin_Handled;
								
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool:IsIncapacitated(client)
{
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0 )
		return true;
	return false;
}

stock GetClientTotalHealth(client)
{
	return GetSurvivorPermanentHealth(client) + GetSurvivorTemporaryHealth(client);
}

/**
 * Returns the amount of permanent health a survivor has. 
 *
 * @param client client ID
 * @return bool
 */
stock GetSurvivorPermanentHealth(client) {
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

/**
 * Returns the amount of temporary health a survivor has. 
 *
 * @param client client ID
 * @return bool
 */
stock GetSurvivorTemporaryHealth(client) {
    new Float:fDecayRate = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
    new Float:fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    new Float:fHealthBufferTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    new iTempHp = RoundToCeil(fHealthBuffer - ((GetGameTime() - fHealthBufferTime) * fDecayRate)) - 1;
    return iTempHp > 0 ? iTempHp : 0;
}

stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	BotStore[0] = 0; BotStore[1] = 0;
}

stock GetNeedTarget(client)
{
	for (new i = MaxClients; i > 0; i--)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			if(GetClientTotalHealth(i) < 40 && GetPlayerWeaponSlot(i, 4) == -1 && !IsPlayerIncap(i)) return i;
		}
	}
	return -1;
}

RestoreItems(client)
{
	// manually create entity and the equip it since GivePlayerItem() doesn't work in L4D2
	decl entity;
	decl Float:clientOrigin[3];
	new currentWeapon = GetPlayerWeaponSlot(client, 4);
	entity = CreateEntityByName(BotStore[PILL_INDEX] > 0 ? "weapon_pain_pills" : "weapon_adrenaline");
	GetClientAbsOrigin(client, clientOrigin);
	clientOrigin[2] += 10.0;
	TeleportEntity(entity, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	if (currentWeapon == -1)
	{
		EquipPlayerWeapon(client, entity);
		currentWeapon = entity;
	}
	BotStore[PILL_INDEX] > 0 ?BotStore[PILL_INDEX]--:BotStore[ADREN_INDEX]--;
	PrintHintText(client, "You get a bot stored item");
}
