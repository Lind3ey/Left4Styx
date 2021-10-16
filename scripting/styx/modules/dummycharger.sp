#pragma semicolon 1

// custom convar
ConVar  CvarChargeProximity,
		CvarAimOffsetSensitivityCharger,
		CvarHealthThresholdCharger;

bool bShouldCharge[MAXPLAYERS]; // manual tracking of charge cooldown

public Charger_OnModuleStart() {
	// Charge proximity
	CvarChargeProximity = CreateConVar("ai_charge_proximity", "300", "How close a charger will approach before charging");	
	// Aim offset sensitivity
	CvarAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger",
									"20",
									"If the charger has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0);
	// Health threshold
	CvarHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "400", "Charger will charge if its health drops to this level");	
}
/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/

// Initialise spawned chargers
public Action:Charger_OnSpawn(botCharger) {
	bShouldCharge[botCharger] = false;
	return Plugin_Handled;
}

public Action:Charger_OnPlayerRunCmd(charger, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// prevent charge until survivors are within the defined proximity
	float chargerPos[3];
	GetClientAbsOrigin(charger, chargerPos);
	int target = GetClientAimTarget(charger);	
	int iSurvivorProximity = GetSurvivorProximity(charger, target); 

	new chargerHealth = GetEntProp(charger, Prop_Send, "m_iHealth");
	if( chargerHealth > CvarHealthThresholdCharger.IntValue 
		&& iSurvivorProximity > CvarChargeProximity.IntValue ) {	
		if( !bShouldCharge[charger] ) { 				
			BlockCharge(charger);
			return Plugin_Continue;
		} 			
	} else {
		bShouldCharge[charger] = true;
	}
	return Plugin_Continue;	
}

void BlockCharge(charger) {
	new chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (chargeEntity > 0) {  // charger entity persists for a short while after death; check ability entity is valid
		SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1); // keep extending end of cooldown period
	} 			
}

void Charger_OnCharge(charger) {
	// Assign charger a new survivor target if they are not specifically targetting anybody with their charge or their target is watching
	new aimTarget = GetClientAimTarget(charger);
	if(	!IsSurvivor(aimTarget) 
		|| IsTargetWatchingAttacker(charger, CvarAimOffsetSensitivityCharger.IntValue)) {

		int newTarget = GetClosestSurvivor(charger, aimTarget);	// try and find another closeby survivor
		if( newTarget != -1 && GetSurvivorProximity(charger, newTarget) <= CvarChargeProximity.IntValue ) {
			aimTarget = newTarget; // might be the same survivor if there were no other survivors within configured charge proximity
		}
		ChargePrediction(charger, aimTarget);
	}
}

void ChargePrediction(charger, survivor) {
	if( !IsBotInfected(charger) || GetInfectedClass(charger) != ZC_Charger || !IsSurvivor(survivor) ) {
		return;
	}
	new Float:survivorPos[3];
	new Float:chargerPos[3];
	new Float:attackDirection[3];
	new Float:attackAngle[3];
	// Add some fancy schmancy trignometric prediction here; as a placeholder charger will face survivor directly
	GetClientAbsOrigin(charger, chargerPos);
	GetClientAbsOrigin(survivor, survivorPos);
	MakeVectorFromPoints( chargerPos, survivorPos, attackDirection );
	GetVectorAngles(attackDirection, attackAngle);	
	TeleportEntity(charger, NULL_VECTOR, attackAngle, NULL_VECTOR); 
}