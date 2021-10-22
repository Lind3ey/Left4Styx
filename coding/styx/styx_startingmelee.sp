#pragma semicolon 1

#include <sourcemod>
#include <styxutils>

public Plugin:myinfo = 
{
	name = "Styx starting weapon", 
	author = "Lind3ey", 
	description = "Auto clear in single training", 
	version = "1.0", 
	url = ""
};


public OnRoundIsLive()
{
	StartingMelee();
}

void StartingMelee()
{	
	int index = 1, weapon;
	float vel[3] = {0.0, 0.0, -15.0};
	_forall(client)
	{
		if(IsSurvivor(client) && IsPlayerAlive(client))
		{
			switch(index)
			{
				case 1: { 	
					weapon = CreateEntityByName("weapon_melee_spawn");
					DispatchKeyValue(weapon, "melee_weapon", "any");
					}
				case 2: weapon = CreateEntityByName("weapon_pistol_magnum");
				case 3: weapon = CreateEntityByName("weapon_pistol");
			}

			float clientOrigin[3];
			float vecAngle[3] = {30.0,45.0,60.0};
			GetClientAbsOrigin(client, clientOrigin);
			clientOrigin[2]+=3.0;
			TeleportEntity(weapon, clientOrigin, vecAngle, NULL_VECTOR);
			DispatchSpawn(weapon);
			TeleportEntity(weapon, NULL_VECTOR, NULL_VECTOR, vel);
			ActivateEntity(weapon);
			index++;
		}
	}
}
