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

//int g_iBotTargetSpotOffset, g_iBotProfileOffset, g_iSkillOffset, g_iBotEnemyOffset, g_iEnemyVisibleOffset;

//ConVar cl_forwardspeed;
float lastEyeAngles[MAXPLAYERS+1][3];
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];
float maxDiff[2];
ConVar weaponRecoilScale, viewRecoilTracking, weaponRecoilPunchExtra;
 
public void OnPluginStart()
{
    //cl_forwardspeed = FindConVar("cl_forwardspeed");
    new ConVar:cvarBotStop = FindConVar("bot_stop");
    SetConVarInt(cvarBotStop, 1, true, true);
    new ConVar:cvarNoSpread = FindConVar("weapon_accuracy_nospread");
    SetConVarInt(cvarNoSpread, 0, true, true);
    new ConVar:cvarInfAmmo = FindConVar("sv_infinite_ammo");
    SetConVarInt(cvarInfAmmo, 1, true, true);
    new ConVar:cvarBombTime = FindConVar("mp_c4timer");
    SetConVarInt(cvarBombTime, 600, true, true);
    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");
    weaponRecoilPunchExtra = FindConVar("weapon_recoil_view_punch_extra");
    PrintToServer("loaded bot_export 1.0 - no armor print fangles");
    maxDiff[0] = 0.0;
    maxDiff[1] = 0.0;
    for (int i = 0; i < MAXPLAYERS+1; i++) {
        lastEyeAngles[i][0] = 0.0;
        lastEyeAngles[i][1] = 0.0;
        lastEyeAngles[i][2] = 0.0;
        lastRecoilAngleAdjustment[i][0] = 0.0;
        lastRecoilAngleAdjustment[i][1] = 0.0;
        lastRecoilAngleAdjustment[i][2] = 0.0;
    }
}

public void vec3_sub(float v1[3], float v2[3], float result[3]) {
    result[0] = v1[0] - v2[0];
    result[1] = v1[1] - v2[1];
    result[2] = v2[2] - v2[2];
}



// https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
    SetEntProp( client, Prop_Data, "m_ArmorValue", 0, 1 );  
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


