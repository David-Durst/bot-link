#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
//#include <dhooks>

public Plugin myinfo =
{
    name = "Durst Bot Exporter",
    author = "David Durst",
    description = "Export bot state so another program can make decisions",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

// input commands
int inButtons[MAXPLAYERS+1];
int inMovement[MAXPLAYERS+1];
float inAngleDeltas[MAXPLAYERS+1][3];

// GetClientEyePosition - this will store where looking
// check GetClientAbsOrigin vs  GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos); 
// output state
float outEyePos[MAXPLAYERS+1][3];
float outEyeAngle[MAXPLAYERS+1][3];
float outFootPos[MAXPLAYERS+1][3];
int crouchingAndDead[MAXPLAYERS+1];

// output file and file state
File outputFile;
int maxFramesBeforeRotation;
int currentFrame;

// recoil punch adjustment variables
ConVar weaponRecoilScale, viewRecoilTracking, weaponRecoilPunchExtra;
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];

// how fast you can move in any direction
float maxSpeed;

static char folder[] = "/home/steam/bot_exporter/";
static char clientFile[] = "/home/steam/bot_exporter/clients";
static char logFile[] = "/home/steam/bot_exporter/output_log";
static char logFileOld[] = "/home/steam/bot_exporter/old_output_log";

// debugging variables
ConVar cvarInfAmmo, cvarBombTime;
bool debugStatus;
float maxDiff[2];
 
public void OnPluginStart()
{
	maxSpeed = 450.0;	
	RegConsoleCmd("sm_botDebug", smBotDebug, "- make bomb time 10 minutes and give infinite ammo");

	new ConVar:cvarBotStop = FindConVar("bot_stop");
	SetConVarInt(cvarBotStop, 1, true, true);
	cvarInfAmmo = FindConVar("sv_infinite_ammo");
	cvarBombTime = FindConVar("mp_c4timer");

	debugStatus = false;

	weaponRecoilScale = FindConVar("weapon_recoil_scale");
	viewRecoilTracking = FindConVar("view_recoil_tracking");
	weaponRecoilPunchExtra = FindConVar("weapon_recoil_view_punch_extra");


	maxDiff[0] = 0.0;
	maxDiff[1] = 0.0;

	for (int i = 0; i < MAXPLAYERS+1; i++) {
		lastRecoilAngleAdjustment[i][0] = 0.0;
		lastRecoilAngleAdjustment[i][1] = 0.0;
		lastRecoilAngleAdjustment[i][2] = 0.0;
	}

	maxFramesBeforeRotation = 1000;
	currentFrame = 1000;

	CreateDirectory("/home/steam/bot_exporter", 777);

	PrintToServer("loaded bot_export 1.1 - actually handling files");
}


public Action:smBotDebug() {
	if (!debugStatus) {
		debugStatus = true;
		SetConVarInt(cvarInfAmmo, 1, true, true);
		SetConVarInt(cvarBombTime, 600, true, true);
	}
	else {
		debugStatus = false;
		SetConVarInt(cvarInfAmmo, 0, true, true);
		SetConVarInt(cvarBombTime, 40, true, true);
	}
	return Plugin_Handled;
}

// update client list when a new client connects
public void OnClientConnected(int client) {
	File clientsFile = OpenFile("/home/steam/bot_exporter/clients.csv", "w", false, "");
	// https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
	for (int i = 1; i < MaxClients; i++) {
		if (isClientConnected(i)) {
			char playerName[128];
			GetClientName(client, playerName, 128);
			WriteFileLine(clientsFile, "%i, %s", i, playerName);
		}
	}
	CloseHandle(clientsFile);
}


// write state and get new commands each frame
public Action OnGameFrame() {
	// write state
	if (currentFrame >= maxFramesBeforeRotation) {
		
	}

	// acquire lock
	File writeLock = OpenFile("/home/steam/bot_exporter/clients.csv", "w", false, "");
	WriteFileLine(writeLock, "writer");
float outEyePos[MAXPLAYERS+1][3];
float outEyeAngle[MAXPLAYERS+1][3];
float outFootPos[MAXPLAYERS+1][3];
int crouchingAndDead[MAXPLAYERS+1];
	
	// update commands
	return Plugin_Continue;
}


public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
	if (debugStatus) {
		SetEntProp( client, Prop_Data, "m_ArmorValue", 0, 1 );  
	}

	char playerName[128];
	GetClientName(client, playerName, 128);
	/*
	if (GetVectorDistance(fAngles, lastEyeAngles[client]) < 4) {
		fAngles = lastEyeAngles[client];
	}
	else {
		PrintToServer("%s fAngle changed from (%f, %f, %f) to (%f, %f, %f)", 
			playerName, fAngles[0], fAngles[1], fAngles[2], 
			lastEyeAngles[client][0], lastEyeAngles[client][1], lastEyeAngles[client][2]);
		lastEyeAngles[client] = fAngles;
	}
	*/
	float fViewAngles[3];
	float zeroVector[3] = {0.0, 0.0, 0.0};
	float mAimPunchAngle[3], mAimPunchAngleVel[3], mViewPunchAngle[3];
	GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", mAimPunchAngle);
	GetEntPropVector(client, Prop_Send, "m_aimPunchAngleVel", mAimPunchAngleVel);
	GetEntPropVector(client, Prop_Send, "m_viewPunchAngle", mViewPunchAngle);
	GetClientEyeAngles(client, fViewAngles);

	if (GetVectorDistance(mAimPunchAngle, zeroVector) > 0.2 || 
		GetVectorDistance(mAimPunchAngleVel, zeroVector) > 0.2 ||
		GetVectorDistance(mViewPunchAngle, zeroVector) > 0.2) {
		PrintToServer("%s m_aimPunchAngle (%f, %f, %f)", playerName,
			mAimPunchAngle[0], mAimPunchAngle[1], mAimPunchAngle[2]);
		PrintToServer("%s m_aimPunchAngleVel (%f, %f, %f)", playerName,
			mAimPunchAngleVel[0], mAimPunchAngleVel[1], mAimPunchAngleVel[2]);
		PrintToServer("%s m_viewPunchAngle (%f, %f, %f)", playerName,
			mViewPunchAngle[0], mViewPunchAngle[1], mViewPunchAngle[2]);
	}
	if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
	{
		//PrintToServer("ignoring %s", playerName);

		if ((iTickcount / 100) % 2 == 0) {
			fVel[0] = 0.0;//450.0;//cl_forwardspeed.FloatValue;
		}
		else {
			fVel[0] = 0.0;
		}
		///fVel[0] = 0.0;
		fVel[1] = 0.0;
		fVel[2] = 0.0;

		iButtons = 0;

		//iButtons |= IN_FORWARD;
		//DisablePunch(client);

	}
	else 
	{
		if (fVel[0] > 0 || fVel[1] > 0 || fVel[2] > 0) {
			//PrintToServer("%s fVel: (%f,%f,%f)", playerName, fVel[0], fVel[1], fVel[2]);
		}
		float diffView[3];
		SubtractVectors(fViewAngles, fAngles, diffView);
		if (FloatAbs(diffView[0]) > maxDiff[0]) {
			maxDiff[0] = FloatAbs(diffView[0]);
		}
		if (FloatAbs(diffView[1]) > maxDiff[1] && FloatAbs(diffView[1]) < 300.0) {
			maxDiff[1] = FloatAbs(diffView[1]);
		}
		if (GetVectorDistance(mAimPunchAngle, zeroVector) > 0) {
			PrintToServer("%s m_aimPunchAngle (%f, %f, %f)", playerName,
				mAimPunchAngle[0], mAimPunchAngle[1], mAimPunchAngle[2]);
			float scaledPunch[3];
			scaledPunch = mAimPunchAngle;
			ScaleVector(scaledPunch, GetConVarFloat(weaponRecoilScale));
			PrintToServer("%s scaledPunch (%f, %f, %f)", playerName,
				scaledPunch[0], scaledPunch[1], scaledPunch[2]);
			PrintToServer("%s m_viewPunchAngle (%f, %f, %f)", playerName,
				mViewPunchAngle[0], mViewPunchAngle[1], mViewPunchAngle[2]);
		}
			/*
		if (GetVectorDistance(diffView, zeroVector) > 0) {
			PrintToServer("%s m_aimPunchAngle (%f, %f, %f)", playerName,
				mAimPunchAngle[0], mAimPunchAngle[1], mAimPunchAngle[2]);
			PrintToServer("%s m_aimPunchAngleVel (%f, %f, %f)", playerName,
				mAimPunchAngleVel[0], mAimPunchAngleVel[1], mAimPunchAngleVel[2]);
			PrintToServer("%s m_viewPunchAngle (%f, %f, %f)", playerName,
				mViewPunchAngle[0], mViewPunchAngle[1], mViewPunchAngle[2]);
			PrintToServer("iMouse (%i, %i)", 
				iMouse[0], iMouse[1]);
			PrintToServer("fAngles (%f, %f, %f)", 
				fAngles[0], fAngles[1], fAngles[2]);
			PrintToServer("fViewAngles (%f, %f, %f)", 
				fViewAngles[0], fViewAngles[1], fViewAngles[2]);
			PrintToServer("diffView (%f, %f, %f)", 
				diffView[0], diffView[1], diffView[2]);
			PrintToServer("maxDiff (%f, %f)", 
				maxDiff[0], maxDiff[1]);
		}
		*/
		//iMouse[0] = 10;
		//float finalView[3];
		//float mouse3[3]; 
		//mouse3[0] = iMouse[0] * 1.0;
		//mouse3[1] = iMouse[1] * 1.0;
		//mouse3[2] = 0.0;
		//AddVectors(mouse3, fAngles, finalView);
		//TeleportEntity(client, NULL_VECTOR, finalView ,NULL_VECTOR);
		float recoilAngleAdjustment[3], finalView[3];
		// this prevents looking around
		finalView = fViewAngles;
		//finalView = fAngles;
		/*
		finalView[1] += 1;
		if (finalView[1] > 180.0) {
			finalView[1] = finalView[1] - 360.0;
		}
		*/
		//SubtractVectors(finalView, mViewPunchAngle, finalView);
		if (iButtons & IN_SPEED) {
			/*
			ScaleVector(mAimPunchAngle, GetConVarFloat(weaponRecoilScale));
			ScaleVector(mAimPunchAngle, GetConVarFloat(viewRecoilTracking));
			ScaleVector(mViewPunchAngle, GetConVarFloat(weaponRecoilPunchExtra));
			AddVectors(mViewPunchAngle, mAimPunchAngle, recoilAngleAdjustment);
			SubtractVectors(finalView, recoilAngleAdjustment, finalView);
			AddVectors(finalView, lastRecoilAngleAdjustment[client], finalView);
			lastRecoilAngleAdjustment[client] = recoilAngleAdjustment;
			TeleportEntity(client, NULL_VECTOR, finalView,NULL_VECTOR);
			PrintToServer("walking");
			*/
			DisablePunch(client);
		}
		
		if (iButtons & IN_ATTACK) {

		}

/*
		if (GetVectorDistance(fAngles, lastEyeAngles[client]) > 0) {
			lastEyeAngles[client] = fAngles;
			PrintToServer("%s fAngle changed from (%f, %f, %f) to (%f, %f, %f)", 
				playerName, fAngles[0], fAngles[1], fAngles[2], 
				lastEyeAngles[client][0], lastEyeAngles[client][1], lastEyeAngles[client][2]);
			PrintToServer("iMouse (%f, %f)", 
				iMouse[0], iMouse[1]);
		}
		*/
	}
	
	return Plugin_Changed;
	//return Plugin_Continue;
}

stock void DisablePunch(int client) {
	// get punch angles
	float mAimPunchAngle[3], mAimPunchAngleVel[3], mViewPunchAngle[3];
	GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", mAimPunchAngle);
	GetEntPropVector(client, Prop_Send, "m_aimPunchAngleVel", mAimPunchAngleVel);
	GetEntPropVector(client, Prop_Send, "m_viewPunchAngle", mViewPunchAngle);

	// get original angles
	float finalView[3];
	GetClientEyeAngles(client, finalView);

	float recoilAngleAdjustment[3];
	ScaleVector(mAimPunchAngle, GetConVarFloat(weaponRecoilScale));
	ScaleVector(mAimPunchAngle, GetConVarFloat(viewRecoilTracking));
	//ScaleVector(mViewPunchAngle, GetConVarFloat(weaponRecoilPunchExtra));
	AddVectors(mViewPunchAngle, mAimPunchAngle, recoilAngleAdjustment);
	SubtractVectors(finalView, recoilAngleAdjustment, finalView);
	AddVectors(finalView, lastRecoilAngleAdjustment[client], finalView);
	lastRecoilAngleAdjustment[client] = recoilAngleAdjustment;
	TeleportEntity(client, NULL_VECTOR, finalView,NULL_VECTOR);
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}


