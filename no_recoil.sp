#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
//#include <dhooks>

public Plugin myinfo =
{
    name = "Durst Recoil Disabler",
    author = "David Durst",
    description = "Disable either visual or actual recoil by setting the cursor on the server. Remeber to set cl_predict 0.",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

float lastEyeAngles[MAXPLAYERS+1][3];
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];

// feature variables
ConVar weaponRecoilScale, viewRecoilTracking, cvarNoSpread;
bool noSpread;

// general variables
ConVar cvarBotStop, cvarBotChatter;

// debugging variables
ConVar cvarInfAmmo, cvarBombTime, cvarAutoKick, cvarRadarShowall;
bool printStatus, disableVisualRecoil;
 
public void OnPluginStart() {
    RegConsoleCmd("sm_printRecoil", smPrintRecoil, "- print debugging values from recoil disabler");
    RegConsoleCmd("sm_recoilType", smToggleRecoilType, "- toggle disabling visual or actual recoil");
    RegConsoleCmd("sm_toggleSpread", smToggleSpread, "- toggle spread on or off");

    cvarBotStop = FindConVar("bot_stop");
    cvarBotChatter = FindConVar("bot_chatter");
    cvarNoSpread = FindConVar("weapon_accuracy_nospread");
    cvarInfAmmo = FindConVar("sv_infinite_ammo");
    cvarBombTime = FindConVar("mp_c4timer");
    cvarAutoKick = FindConVar("mp_autokick");
    cvarRadarShowall = FindConVar("mp_radar_showall");

    noSpread = false;
    printStatus = false;
    disableVisualRecoil = true;

    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");

    for (int i = 0; i < MAXPLAYERS+1; i++) {
        lastEyeAngles[i][0] = 0.0;
        lastEyeAngles[i][1] = 0.0;
        lastEyeAngles[i][2] = 0.0;
        lastRecoilAngleAdjustment[i][0] = 0.0;
        lastRecoilAngleAdjustment[i][1] = 0.0;
        lastRecoilAngleAdjustment[i][2] = 0.0;
    }

    PrintToServer("loaded recoil disabler 1.0");
}

public Action:smToggleSpread(client, args) {
    if (noSpread) {
        noSpread = false;
        SetConVarInt(cvarNoSpread, 0, true, true);
    }
    else {
        noSpread = true;
        SetConVarInt(cvarNoSpread, 1, true, true);
    }
    return Plugin_Handled;
}

public Action:smPrintRecoil(client, args) {
    printStatus = !printStatus;
    return Plugin_Handled;
}

public Action:smToggleRecoilType(client, args) {
    disableVisualRecoil = !disableVisualRecoil;
    return Plugin_Handled;
}

public OnMapStart() {
    SetConVarInt(cvarBotStop, 1, true, true);
    SetConVarString(cvarBotChatter, "off", true, true);
    SetConVarInt(cvarInfAmmo, 1, true, true);
    SetConVarInt(cvarBombTime, 600, true, true);
    SetConVarInt(cvarAutoKick, 0, true, true);
    SetConVarInt(cvarRadarShowall, 1, true, true);
}

// https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
    if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client)) {
        return Plugin_Continue;
    }

    SetEntProp( client, Prop_Data, "m_ArmorValue", 0, 1 );  
    char playerName[128];
    GetClientName(client, playerName, 128);

    float fViewAngles[3];
    float zeroVector[3] = {0.0, 0.0, 0.0};
    float mAimPunchAngle[3], mAimPunchAngleVel[3], mViewPunchAngle[3];
    GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", mAimPunchAngle);
    GetEntPropVector(client, Prop_Send, "m_aimPunchAngleVel", mAimPunchAngleVel);
    GetEntPropVector(client, Prop_Send, "m_viewPunchAngle", mViewPunchAngle);
    GetClientEyeAngles(client, fViewAngles);

    float scaledPunch[3];
    scaledPunch = mAimPunchAngle;
    ScaleVector(scaledPunch, GetConVarFloat(weaponRecoilScale));

    if (printStatus && (
        GetVectorDistance(mAimPunchAngle, zeroVector) > 0 || 
        GetVectorDistance(mAimPunchAngleVel, zeroVector) > 0 ||
        GetVectorDistance(mViewPunchAngle, zeroVector) > 0)) {
        PrintToServer("%s m_aimPunchAngle (%f, %f, %f)", playerName,
            mAimPunchAngle[0], mAimPunchAngle[1], mAimPunchAngle[2]);
        PrintToServer("%s m_aimPunchAngleVel (%f, %f, %f)", playerName,
            mAimPunchAngleVel[0], mAimPunchAngleVel[1], mAimPunchAngleVel[2]);
        PrintToServer("%s m_viewPunchAngle (%f, %f, %f)", playerName,
            mViewPunchAngle[0], mViewPunchAngle[1], mViewPunchAngle[2]);
        PrintToServer("%s scaledPunch (%f, %f, %f)", playerName,
            scaledPunch[0], scaledPunch[1], scaledPunch[2]);
    }

    if (iButtons & IN_SPEED) {
        DisablePunch(client);
    }
        
    return Plugin_Changed;
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
    if (disableVisualRecoil) {
        ScaleVector(mAimPunchAngle, GetConVarFloat(weaponRecoilScale));
        ScaleVector(mAimPunchAngle, GetConVarFloat(viewRecoilTracking));
        AddVectors(mViewPunchAngle, mAimPunchAngle, recoilAngleAdjustment);
    }
    else {
        ScaleVector(mAimPunchAngle, GetConVarFloat(weaponRecoilScale));
        recoilAngleAdjustment = mAimPunchAngle;
    }
    SubtractVectors(finalView, recoilAngleAdjustment, finalView);
    AddVectors(finalView, lastRecoilAngleAdjustment[client], finalView);
    lastRecoilAngleAdjustment[client] = recoilAngleAdjustment;
    TeleportEntity(client, NULL_VECTOR, finalView,NULL_VECTOR);
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}


