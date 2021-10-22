/**************************************************
************       StyxCoop   **************
*************************************************/
Msg("Active StyxCoop\n");

/***************************************************
** Hard Core base script key values ****************
**********************************************/
DirectorOptions <-
{
	AggressiveSpecials = true
	SpecialInfectedAssault = true
	ShouldAllowMobsWithTank = false
	ShouldAllowSpecialsWithTank = true
	PreferedSpecialDirection = SPAWN_SPECIALS_ANYWHERE
	SpecialInitialSpawnDelayMin = 1
	SpecialInitialSpawnDelayMax = 1
	SpecialRespawnInterval = 20
	TankLimit = 1
	WitchLimit = 1
	NumReservedWanderers = 5
	ActiveChallenge = 1
 	cm_BaseSpecialLimit = 2
 	cm_SpecialRespawnInterval = 15
 	cm_MaxSpecials = 8
 
 	DominatorLimit = 8

	weaponsToAvoid =
 	{
 		weapon_pumpshotgun = 0
 		weapon_shotgun_chrome = 0
 		weapon_hunting_rifle = 0
    	weapon_pain_pills = 0
    	weapon_first_aid_kit = 0
    	weapon_adrenaline = 0
 	}

   function ShouldAvoidItem( classname )
 	{
 		if (classname in weaponsToAvoid )
 		{
 			return true;
 		}
 		return false;
 	}
}