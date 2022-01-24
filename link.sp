#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#define MAX_INPUT_LENGTH 1000
#define MAX_INPUT_FIELDS 20
#define MAX_PATH_LENGTH 256
#define MAX_ONE_DIRECTION_SPEED 450.0

public Plugin myinfo =
{
    name = "Durst Bot Exporter",
    author = "David Durst",
    description = "Export bot state so another program can make decisions",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

// input commands to read
char inputBuffer[MAX_INPUT_LENGTH];
char inputExplodedBuffer[MAX_INPUT_FIELDS][MAX_INPUT_LENGTH];
int inputButtons[MAXPLAYERS+1];
enum MovementInputs: {
    Forward,
    Backward,
    Left,
    Right,
    NUM_MOVEMENT_INPUTS
};
bool inputMovement[MAXPLAYERS+1][NUM_MOVEMENT_INPUTS];
float inputAngleDeltas[MAXPLAYERS+1][3];

// GetClientEyePosition - this will store where looking
// check GetClientAbsOrigin vs  GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos); 
// states to outpuot
float clientEyePos[MAXPLAYERS+1][3];
float clientEyeAngle[MAXPLAYERS+1][3];
float clientFootPos[MAXPLAYERS+1][3];
int clientOtherState[MAXPLAYERS+1];

// recoil punch adjustment variables
ConVar weaponRecoilScale, viewRecoilTracking;
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];

// files 
static char rootFolder[] = "addons/sourcemod/bot-link-data/";
static char clientFilePath[] = "addons/sourcemod/bot-link-data/clients.csv";
static char tmpClientFilePath[] = "addons/sourcemod/bot-link-data/clients.csv.tmp.write";
static char stateFilePath[] = "addons/sourcemod/bot-link-data/state.csv";
static char tmpStateFilePath[] = "addons/sourcemod/bot-link-data/state.csv.tmp.write";
File tmpStateFile;
static char inputFilePath[] = "addons/sourcemod/bot-link-data/input.csv";
static char tmpInputFilePath[] = "addons/sourcemod/bot-link-data/input.csv.tmp.read";
File tmpInputFile;
int currentFrame;

// debugging variables
ConVar cvarInfAmmo, cvarBombTime;
bool debugStatus;
float maxDiff[2];

 
public void OnPluginStart()
{
    RegConsoleCmd("sm_botDebug", smBotDebug, "- make bomb time 10 minutes and give infinite ammo");

    new ConVar:cvarBotStop = FindConVar("bot_stop");
    SetConVarInt(cvarBotStop, 1, true, true);
    cvarInfAmmo = FindConVar("sv_infinite_ammo");
    cvarBombTime = FindConVar("mp_c4timer");

    debugStatus = false;

    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");


    maxDiff[0] = 0.0;
    maxDiff[1] = 0.0;

    for (int i = 0; i < MAXPLAYERS+1; i++) {
        lastRecoilAngleAdjustment[i][0] = 0.0;
        lastRecoilAngleAdjustment[i][1] = 0.0;
        lastRecoilAngleAdjustment[i][2] = 0.0;
    }

    if (!DirExists(rootFolder)) {
        PrintCantFindFolder();
        return;
    }
    else {
        PrintToServer("Can access %s", rootFolder);
    }

    PrintToServer("loaded bot-link 1.0");
}


public Action:smBotDebug(client, args) {
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
public void OnClientPutInServer(int client) {
    if (!DirExists(rootFolder)) {
        PrintCantFindFolder();
        return;
    }

    // rewrite the entire file every time a player connects to get fresh state
    File tmpClientsFile = OpenFile(tmpClientFilePath, "w", false, "");
    if (tmpClientsFile == null) {
        PrintToServer("opening tmpClientsFile returned null");
        return;
    }

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int i = 1; i < MaxClients; i++) {
        if (IsValidClient(i)) {
            char playerName[128];
            GetClientName(i, playerName, 128);
            tmpClientsFile.WriteLine("%i, %s", i, playerName);
        }
    }

    tmpClientsFile.Close();
    RenameFile(clientFilePath, tmpClientFilePath);
}

// write state and get new commands each frame
public OnGameFrame() {
    if (!DirExists(rootFolder)) {
        PrintToServer("please create %s", rootFolder);
        return;
    }

    // write state - update temp file, then atomically overwrite last state
    tmpStateFile = OpenFile(tmpStateFilePath, "w", false, "");
    if (tmpStateFile == null) {
        PrintToServer("opening tmpStateFile returned null");
        return;
    }
    tmpStateFile.WriteLine("State Frame,Player Index,Bot,Eye Pos X,Eye Pos Y,Eye Pos Z,"
        ... "Eye Angle X,Eye Angle Y,Foot Pos X,Foot Pos Y,Foot Pos Z,Is Alive");

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int client = 1; client < MaxClients; client++) {
        if (IsValidClient(client)) {
            GetClientEyePosition(client, clientEyePos[client]);
            GetClientAbsAngles(client, clientEyeAngle[client]);
            GetClientAbsOrigin(client, clientFootPos[client]);
            if (IsPlayerAlive(client)) {
                clientOtherState[client] |= 1;
            }
            else {
                clientOtherState[client] &= ~1;
            }
            int clientFake = 0;
            if (IsFakeClient(client)) {
                clientFake = 1;
            }
            tmpStateFile.WriteLine("%i, %i, %i, %f, %f, %f, %f, %f, %f, %f, %f, %i,", 
                currentFrame, client, clientFake,
                clientEyePos[client][0], clientEyePos[client][1], clientEyePos[client][2],
                clientEyeAngle[client][0], clientEyeAngle[client][1],
                clientFootPos[client][0], clientFootPos[client][1], clientFootPos[client][2],
                clientOtherState[client]);
        }
    }
    tmpStateFile.Close();
    RenameFile(stateFilePath, tmpStateFilePath);

    // read state - move file to tmp location so not overwritten, then read it
    // update to latest input if it exists
    if (FileExists(inputFilePath)) {
        RenameFile(tmpInputFilePath, inputFilePath);
    }

    // once at least one input, keep using it until a new one is provided
    if (FileExists(tmpInputFilePath)) {
        tmpInputFile = OpenFile(tmpInputFilePath, "r", false, "");
        tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);

        while(!tmpInputFile.EndOfFile()) {
            tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);
            ExplodeString(inputBuffer, ",", inputExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            int client = StringToInt(inputExplodedBuffer[0]);

            inputButtons[client] = StringToInt(inputExplodedBuffer[1]);
            inputMovement[client][Forward] = inputButtons[client] & IN_FORWARD > 0;
            inputMovement[client][Backward] = inputButtons[client] & IN_BACK > 0;
            inputMovement[client][Left] = inputButtons[client] & IN_LEFT > 0;
            inputMovement[client][Right] = inputButtons[client] & IN_RIGHT > 0;
            inputAngleDeltas[client][0] = StringToFloat(inputExplodedBuffer[2]);
            inputAngleDeltas[client][1] = StringToFloat(inputExplodedBuffer[3]);
        }

        tmpInputFile.Close();
    }
    currentFrame++;
}


public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
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
        //float recoilAngleAdjustment[3];
        float finalView[3];
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
            DisablePunch(client);
        }
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
    return client > 0 && client <= MaxClients && 
        IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}

stock bool PrintCantFindFolder() {
    PrintToServer("Cant access root folder %s, please create it with permissions 777", rootFolder);
}
