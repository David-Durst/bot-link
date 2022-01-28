#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include "bot-link/weapon_status.sp"
#include "bot-link/grenade_status.sp"
#define MAX_INPUT_LENGTH 1000
#define MAX_INPUT_FIELDS 20
#define MAX_PATH_LENGTH 256
#define MAX_ONE_DIRECTION_SPEED 450.0
#define MAX_ONE_DIRECTION_ANGLE_DELTA 30.0

public Plugin myinfo =
{
    name = "Durst Bot Link",
    author = "David Durst",
    description = "Link the CSGO server to another program running bot AI",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

// input commands to read
bool inputSet[MAXPLAYERS+1];
bool inputSetLastFrame[MAXPLAYERS+1];
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
float inputAngleDeltaPct[MAXPLAYERS+1][3];

// GetClientEyePosition - this will store where looking
// check GetClientAbsOrigin vs  GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos); 
// states to outpuot
float clientEyePos[MAXPLAYERS+1][3];
float clientEyeAngle[MAXPLAYERS+1][3];
float clientEyeAngleWithRecoil[MAXPLAYERS+1][3];
float clientFootPos[MAXPLAYERS+1][3];
float mAimPunchAngle[MAXPLAYERS+1][3];
float mViewAdjustedAimPunchAngle[MAXPLAYERS+1][3];
float mViewPunchAngle[MAXPLAYERS+1][3];
int clientOtherState[MAXPLAYERS+1];

// recoil punch adjustment variables
ConVar weaponRecoilScale, viewRecoilTracking;
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];

// files 
static char rootFolder[] = "addons/sourcemod/bot-link-data/";
static char stateFilePath[] = "addons/sourcemod/bot-link-data/state.csv";
static char tmpStateFilePath[] = "addons/sourcemod/bot-link-data/state.csv.tmp.write";
File tmpStateFile;
static char inputFilePath[] = "addons/sourcemod/bot-link-data/input.csv";
static char tmpInputFilePath[] = "addons/sourcemod/bot-link-data/input.csv.tmp.read";
File tmpInputFile;
int currentFrame;

// general variables
ConVar cvarBotStop, cvarBotChatter;

// debugging variables
ConVar cvarInfAmmo, cvarBombTime, cvarAutoKick, cvarRadarShowall;
bool debugStatus;
bool printStatus;
float maxDiff[2];

 
public void OnPluginStart()
{
    RegConsoleCmd("sm_botDebug", smBotDebug, "- make bomb time 10 minutes and give infinite ammo");
    RegConsoleCmd("sm_printLink", smPrintLink, "- print debugging values from bot-link");

    cvarBotStop = FindConVar("bot_stop");
    cvarBotChatter = FindConVar("bot_chatter");
    cvarInfAmmo = FindConVar("sv_infinite_ammo");
    cvarBombTime = FindConVar("mp_c4timer");
    cvarAutoKick = FindConVar("mp_autokick");
    cvarRadarShowall = FindConVar("mp_radar_showall");

    debugStatus = false;
    printStatus = false;
    applyConVars();

    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");

    maxDiff[0] = 0.0;
    maxDiff[1] = 0.0;

    for (int i = 0; i < MAXPLAYERS+1; i++) {
        lastRecoilAngleAdjustment[i][0] = 0.0;
        lastRecoilAngleAdjustment[i][1] = 0.0;
        lastRecoilAngleAdjustment[i][2] = 0.0;
        inputSetLastFrame[i] = false;
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

public Action:smPrintLink(client, args) {
    printStatus = !printStatus;
    return Plugin_Handled;
}

public Action:smBotDebug(client, args) {
    debugStatus = !debugStatus;
    applyConVars();
    return Plugin_Handled;
}

public OnMapStart() {
    applyConVars();
    InitGrenadeOffsets();
}

stock void applyConVars() {
    SetConVarInt(cvarBotStop, 1, true, true);
    SetConVarString(cvarBotChatter, "off", true, true);
    if (debugStatus) {
        SetConVarInt(cvarInfAmmo, 1, true, true);
        SetConVarInt(cvarBombTime, 600, true, true);
        SetConVarInt(cvarAutoKick, 0, true, true);
        SetConVarInt(cvarRadarShowall, 1, true, true);
    }
    else {
        SetConVarInt(cvarInfAmmo, 0, true, true);
        SetConVarInt(cvarBombTime, 40, true, true);
        SetConVarInt(cvarAutoKick, 1, true, true);
        SetConVarInt(cvarRadarShowall, 0, true, true);
    }
}


// write state and get new commands each frame
public OnGameFrame() {
    if (!DirExists(rootFolder)) {
        PrintToServer("please create %s", rootFolder);
        return;
    }

    WriteState();
    ReadInput();
    currentFrame++;
}


stock void WriteState() {
    // write state - update temp file, then atomically overwrite last state

    tmpStateFile = OpenFile(tmpStateFilePath, "w", false, "");
    if (tmpStateFile == null) {
        PrintToServer("opening tmpStateFile returned null");
        return;
    }
    tmpStateFile.WriteLine("State Frame,Client Id,Name,Team,"
        ... "Rifle Id,Rifle Clip Ammo,Rifle Reserve Ammo,"
        ... "Pistol Id,Pistol Clip Ammo,Pistol Reserve Ammo,"
        ... "Flashes,Molotovs,Smokes,HEs,Decoys,Incendiaries,"
        ... "Eye Pos X,Eye Pos Y,Eye Pos Z,Foot Pos Z,"
        ... "Eye Angle Pitch,Eye Angle Yaw,Aimpunch Angle Pitch,Aimpunch Angle Yaw,"
        ... "Eye With Recoil Angle Pitch,Eye With Recoil Angle Yaw,Is Alive,Is Bot");

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int client = 1; client < MaxClients; client++) {
        if (IsValidClient(client)) {
            char clientName[128];
            GetClientName(client, clientName, 128);
            int clientTeam = GetClientTeam(client);

            // this gets position result from getpos
            GetClientEyePosition(client, clientEyePos[client]);
            GetViewAngleWithRecoil(client);
            // this gets position result from getpos_exact
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

            int rifleId = GetRifleEntityId(client), rifleWeaponId = -1;
            int rifleClipAmmo = -1, rifleReserveAmmo = -1;
            if (rifleId != -1) {
                rifleWeaponId = GetWeaponIdFromEntityId(rifleId);
                rifleClipAmmo = GetWeaponClipAmmo(rifleId);
                rifleReserveAmmo = GetWeaponReserveAmmo(rifleId);
            }

            int pistolId = GetPistolEntityId(client), pistolWeaponId = -1;
            int pistolClipAmmo = -1, pistolReserveAmmo = -1;
            if (pistolId != -1) {
                pistolWeaponId = GetWeaponIdFromEntityId(pistolId);
                pistolClipAmmo = GetWeaponClipAmmo(pistolId);
                pistolReserveAmmo = GetWeaponReserveAmmo(pistolId);
            }

            tmpStateFile.WriteLine("%i,%i,%s,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%i,%i",
                currentFrame, client, clientName, clientTeam,
                rifleWeaponId, rifleClipAmmo, rifleReserveAmmo,
                pistolWeaponId, pistolClipAmmo, pistolReserveAmmo,
                GetGrenade(client, Flash), GetGrenade(client, Molotov), 
                GetGrenade(client, Smoke), GetGrenade(client, HE), 
                GetGrenade(client, Decoy), GetGrenade(client, Incendiary), 
                clientEyePos[client][0], clientEyePos[client][1], 
                clientEyePos[client][2], clientFootPos[client][2],
                clientEyeAngle[client][0], clientEyeAngle[client][1],
                mAimPunchAngle[client][0], mAimPunchAngle[client][1],
                clientEyeAngleWithRecoil[client][0], clientEyeAngleWithRecoil[client][1],
                clientOtherState[client], clientFake);
        }
    }
    tmpStateFile.Close();
    RenameFile(stateFilePath, tmpStateFilePath);
}


stock void GetViewAngleWithRecoil(int client) {
    // this gets angle from getpos, getpos_exact seems to be this in range of 0-360 for pitch,
    // which is weird as legal pitch range is -90-90 yaw
    // tried GetClientAbsAngles and those werent as useful, might be with abs value for getpos_exact
    // confirmed that both GetClientAbsAngles and GetClientEyeAngles dont adjust for recoil

    // since bots drift, if under my control, dont actually update EyeAngles
    if (!inputSet[client]) {
        GetClientEyeAngles(client, clientEyeAngle[client]);
    }

    // get recoil state from engine, m_aimPunchAngleVel not important
    GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", mAimPunchAngle[client]);
    GetEntPropVector(client, Prop_Send, "m_viewPunchAngle", mViewPunchAngle[client]);

    // adjust by per game coefficients, weapon_recoil_punch_extra not needed as already included in viewPunch
    ScaleVector(mAimPunchAngle[client], GetConVarFloat(weaponRecoilScale));
    mViewAdjustedAimPunchAngle[client] = mAimPunchAngle[client];
    ScaleVector(mViewAdjustedAimPunchAngle[client], GetConVarFloat(viewRecoilTracking));
    AddVectors(mViewAdjustedAimPunchAngle[client], clientEyeAngle[client], clientEyeAngleWithRecoil[client]);
    AddVectors(mViewPunchAngle[client], clientEyeAngleWithRecoil[client], clientEyeAngleWithRecoil[client]);
}


stock void ReadInput() {
    // disable inputSet for each client, will make true if actually appears in file
    for (int client = 1; client < MaxClients; client++) {
        inputSet[client] = false;
    }

    //  move file to tmp location so not overwritten, then read it
    // update to latest input if it exists
    // only use new inputs, give controller a chance to resopnd
    if (FileExists(inputFilePath)) {
        RenameFile(tmpInputFilePath, inputFilePath);

        tmpInputFile = OpenFile(tmpInputFilePath, "r", false, "");
        tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);

        while(!tmpInputFile.EndOfFile()) {
            tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);
            ExplodeString(inputBuffer, ",", inputExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            int client = StringToInt(inputExplodedBuffer[0]);

            inputSet[client] = true;
            inputButtons[client] = StringToInt(inputExplodedBuffer[1]);
            inputMovement[client][Forward] = inputButtons[client] & IN_FORWARD > 0;
            inputMovement[client][Backward] = inputButtons[client] & IN_BACK > 0;
            inputMovement[client][Left] = inputButtons[client] & IN_LEFT > 0;
            inputMovement[client][Right] = inputButtons[client] & IN_RIGHT > 0;
            inputAngleDeltaPct[client][0] = StringToFloat(inputExplodedBuffer[2]);
            inputAngleDeltaPct[client][0] = fmax(-1.0, fmin(1.0, inputAngleDeltaPct[client][0]));
            inputAngleDeltaPct[client][1] = StringToFloat(inputExplodedBuffer[3]);
            inputAngleDeltaPct[client][1] = fmax(-1.0, fmin(1.0, inputAngleDeltaPct[client][1]));
        }

        tmpInputFile.Close();
    }
}


// https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
    if (!inputSet[client]) {
        inputSetLastFrame[client] = false;
        return Plugin_Continue;
    }

    iButtons = inputButtons[client];

    fVel[0] = 0.0;
    fVel[1] = 0.0;
    fVel[2] = 0.0;
    // crouching/walking/jump doesnt change fVel
    // dont know what changes fVel[2]
    if (inputMovement[client][Forward]) {
        fVel[0] += MAX_ONE_DIRECTION_SPEED;
    }
    if (inputMovement[client][Backward]) {
        fVel[0] -= MAX_ONE_DIRECTION_SPEED;
    }
    if (inputMovement[client][Right]) {
        fVel[1] += MAX_ONE_DIRECTION_SPEED;
    }
    if (inputMovement[client][Left]) {
        fVel[1] -= MAX_ONE_DIRECTION_SPEED;
    }

    float newAngles[3];
    float oldAngles[3];
    if (inputSetLastFrame[client]) {
        newAngles = clientEyeAngle[client];
    }
    else {
        newAngles = fAngles;
    }
    oldAngles = newAngles;

    newAngles[0] += inputAngleDeltaPct[client][0] * MAX_ONE_DIRECTION_ANGLE_DELTA;
    newAngles[0] = fmax(-89.0, fmin(89.0, newAngles[0]));

    newAngles[1] += inputAngleDeltaPct[client][1] * MAX_ONE_DIRECTION_ANGLE_DELTA;
    if (newAngles[1] > 180.0) {
        newAngles[1] = -360.0 + newAngles[1];
    }
    else if (newAngles[1] < -180.0) {
        newAngles[1] = 360.0 + newAngles[1];
    }

    TeleportEntity(client, NULL_VECTOR, newAngles, NULL_VECTOR);
    clientEyeAngle[client] = newAngles;

    if (printStatus) {
        char clientName[128];
        GetClientName(client, clientName, 128);
        PrintToServer("new inputs for %i: %s", client, clientName);
        PrintToServer("old Angles: (%f, %f, %f), new fAngles: (%f, %f, %f)",
            oldAngles[0], oldAngles[1], oldAngles[2],
            newAngles[0], newAngles[1], newAngles[2]);
        PrintToServer("delta pct Angles: (%f, %f)",
            inputAngleDeltaPct[client][0],
            inputAngleDeltaPct[client][1]);
        PrintToServer("delta Angles: (%f, %f, %f)",
            compareAnglesMod360(newAngles[0], oldAngles[0]),
            compareAnglesMod360(newAngles[1], oldAngles[1]),
            compareAnglesMod360(newAngles[2], oldAngles[2]));
    }

    inputSetLastFrame[client] = true;

    return Plugin_Changed;
}

stock float compareAnglesMod360(float angle0, float angle1) {
    return fabs(floatMod((angle0 + 180.0 - (angle1 + 180.0)), 360.0));
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && 
        IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}


stock bool PrintCantFindFolder() {
    PrintToServer("Cant access root folder %s, please create it with permissions 777", rootFolder);
}

stock int min(int a, int b) {
    return a < b ? a : b;
}

stock float fmin(float a, float b) {
    return a < b ? a : b;
}

stock int max(int a, int b) {
    return a > b ? a : b;
}

stock float fmax(float a, float b) {
    return a > b ? a : b;
}

stock float fabs(float a) {
    return fmax(a, -1.0*a);
}

stock float floatMod(float num, float denom) {
    return num - denom * RoundToFloor(num / denom);
}
