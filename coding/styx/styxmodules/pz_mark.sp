#pragma semicolon 1

static bool:	bMarkedInfPlayer[MAXPLAYERS] 	= false;

//======================== Infected player Mark System ===============================

public MarkAsInfected(client)
{
	bMarkedInfPlayer[client] = true;
	PrintHintText(client, "Marked as infected.");
}

public Action:ResetMarkedPz()
{
	for(new i = 0; i < MAXPLAYERS; i++)
	{
		bMarkedInfPlayer[i] = false;
	}
	return Plugin_Handled;
}

public bool:IsMarkedInfPlayer(client)
{
	return bMarkedInfPlayer[client];
}

public UnMarkInfPlayer(client)
{
	bMarkedInfPlayer[client] = false;
}

public Action:CheckPlayerTeam()
{
	if (!IsSurvivorTeamFull())
	{
		_forall(client)
		{
			if (IsPlayerZombie(client)
				&& !IsMarkedInfPlayer(client)){
				FakeClientCommand(client, "jointeam SURVIVOR");
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}