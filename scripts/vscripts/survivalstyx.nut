/**************************************************
************       StyxCoop   **************
*************************************************/
Msg("Active Styx Survival \n");

/***************************************************
** Hard Core base script key values ****************
**********************************************/
DirectorOptions <-
 {
   ActiveChallenge = true
   AggressiveSpecials = true
   SpecialInfectedAssault = true
   ShouldAllowMobsWithTank = false
   ShouldAllowSpecialsWithTank = true
   PreferedSpecialDirection = SPAWN_LARGE_VOLUME
   PreferredMobDirection = SPAWN_LARGE_VOLUME
   ZombieSpawnInFog = true
   SpecialInitialSpawnDelayMin = 1
   SpecialInitialSpawnDelayMax = 6
   TankLimit = 1
   WitchLimit = 3

   // Total Limit
   MaxSpecials = 6
   cm_MaxSpecials = 6
   cm_BaseSpecialLimit = 3
   DominatorLimit = 5

   // Specials
   HunterLimit = 2
   ChargerLimit = 2
   JockeyLimit = 2
   SmokerLimit = 0
   SpitterLimit = 1
   BoomerLimit = 1

   cm_SpecialRespawnInterval = 10
   NumReservedWanderers = 1
    
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

  DefaultItems =
 	[
 		"pistol_magnum",
    "pain_pills",
		//Using two "weapon_pistol" makes you spawn holding two pistols.
 	]

 	function GetDefaultItem( idx )
 	{
 		if ( idx < DefaultItems.len() )
 		{
 			return DefaultItems[idx];
 		}
 		return 0;
 	}
}