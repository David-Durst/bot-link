#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include "bot-link/weapon_status.sp"
#include "bot-link/grenade_status.sp"
#include "bot-link/visibility.sp"
#define MAX_INPUT_LENGTH 1000
#define MAX_INPUT_FIELDS 20
#define MAX_PATH_LENGTH 256
#define MAX_ONE_DIRECTION_SPEED 450.0
#define MAX_ONE_DIRECTION_ANGLE_VEL 15.0
#define DEBUG_INVALID_DIFF -20000.0

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
float clientFootPosOther[MAXPLAYERS+1][3];
float clientVelocity[MAXPLAYERS+1][3];
float mAimPunchAngle[MAXPLAYERS+1][3];
float mViewAdjustedAimPunchAngle[MAXPLAYERS+1][3];
float mViewPunchAngle[MAXPLAYERS+1][3];
int clientOtherState[MAXPLAYERS+1];

// recoil punch adjustment variables
ConVar weaponRecoilScale, viewRecoilTracking;
float lastRecoilAngleAdjustment[MAXPLAYERS+1][3];

// C4 values
float c4Position[3];

// files 
static char rootFolder[] = "addons/sourcemod/bot-link-data/";
static char generalFilePath[] = "addons/sourcemod/bot-link-data/general.csv";
static char tmpGeneralFilePath[] = "addons/sourcemod/bot-link-data/general.csv.tmp.write";
File tmpGeneralFile;
bool tmpGeneralOpen = false;
static char stateFilePath[] = "addons/sourcemod/bot-link-data/state.csv";
static char tmpStateFilePath[] = "addons/sourcemod/bot-link-data/state.csv.tmp.write";
File tmpStateFile;
bool tmpStateOpen = false;
static char c4FilePath[] = "addons/sourcemod/bot-link-data/c4.csv";
static char tmpC4FilePath[] = "addons/sourcemod/bot-link-data/c4.csv.tmp.write";
File tmpC4File;
bool tmpC4Open = false;
static char inputFilePath[] = "addons/sourcemod/bot-link-data/input.csv";
static char tmpInputFilePath[] = "addons/sourcemod/bot-link-data/input.csv.tmp.read";
File tmpInputFile;
bool tmpInputOpen = false;
int currentFrame;

// general variables
ConVar cvarBotStop, cvarBotChatter, cvarBotSnipers;
int roundNumber, mapNumber;

// debugging variables
ConVar cvarInfAmmo, cvarBombTime, cvarAutoKick, cvarRadarShowall, cvarForceCamera, cvarRoundRestartDelay;
bool debugStatus;
bool printStatus;
bool recordMaxs;
int clientToRecord;
float lastAngles[2], lastAngleVel[2], maxAngleVel[2], maxAngleAccel[2];

// placed down here so it has access to all variables defined above
#include "bot-link/bot_debug.sp"
 
public void OnPluginStart()
{
    RegConsoleCmd("sm_botDebug", smBotDebug, "- make bomb time 10 minutes and give infinite ammo");
    RegConsoleCmd("sm_draw", smDraw, "- immediately end the current round in a draw");
    RegConsoleCmd("sm_printLink", smPrintLink, "- print debugging values from bot-link");
    RegConsoleCmd("sm_recordMaxs", smRecordMaxs, "- record max angular values for debugging");
    RegisterDebugFunctions();
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);

    cvarBotStop = FindConVar("bot_stop");
    cvarBotChatter = FindConVar("bot_chatter");
    cvarBotSnipers = FindConVar("bot_allow_snipers");
    cvarInfAmmo = FindConVar("sv_infinite_ammo");
    cvarBombTime = FindConVar("mp_c4timer");
    cvarAutoKick = FindConVar("mp_autokick");
    cvarRadarShowall = FindConVar("mp_radar_showall");
    cvarForceCamera = FindConVar("mp_forcecamera");
    cvarRoundRestartDelay = FindConVar("mp_round_restart_delay");

    mapNumber = 0;
    roundNumber = 0;
    debugStatus = false;
    printStatus = false;
    recordMaxs = false;
    applyConVars();

    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");

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

public Action:smRecordMaxs(client, args) {
    lastAngles[0] = DEBUG_INVALID_DIFF; 
    lastAngles[1] = DEBUG_INVALID_DIFF; 
    lastAngleVel[0] = DEBUG_INVALID_DIFF; 
    lastAngleVel[1] = DEBUG_INVALID_DIFF; 
    maxAngleVel[0] = DEBUG_INVALID_DIFF;
    maxAngleVel[1] = DEBUG_INVALID_DIFF;
    maxAngleAccel[0] = DEBUG_INVALID_DIFF;
    maxAngleAccel[1] = DEBUG_INVALID_DIFF;
    recordMaxs = !recordMaxs;
    clientToRecord = client;
    return Plugin_Handled;
}

public Action:smBotDebug(client, args) {
    debugStatus = !debugStatus;
    applyConVars();
    return Plugin_Handled;
}

public Action:smDraw(client, args) {
    CS_TerminateRound(0.0, CSRoundEnd_Draw, false); 
    return Plugin_Handled;
}

public OnMapStart() {
    roundNumber = 0;
    mapNumber++;
    applyConVars();
    InitGrenadeOffsets();
}

public Action OnRoundStart(Event event, const char[] sName, bool bDontBroadcast) {
    roundNumber++;
    return Plugin_Continue;
}

stock void applyConVars() {
    SetConVarInt(cvarBotStop, 1, true, true);
    SetConVarString(cvarBotChatter, "off", true, true);
    SetConVarInt(cvarAutoKick, 0, true, true);
    SetConVarInt(cvarBotSnipers, 0, true, true);
    if (debugStatus) {
        SetConVarInt(cvarInfAmmo, 1, true, true);
        SetConVarInt(cvarBombTime, 600, true, true);
        SetConVarInt(cvarRadarShowall, 1, true, true);
        SetConVarInt(cvarForceCamera, 0, true, true);
        SetConVarInt(cvarRoundRestartDelay, 600, true, true);
    }
    else {
        SetConVarInt(cvarInfAmmo, 0, true, true);
        SetConVarInt(cvarBombTime, 40, true, true);
        SetConVarInt(cvarRadarShowall, 0, true, true);
        SetConVarInt(cvarForceCamera, 1, true, true);
        SetConVarInt(cvarRoundRestartDelay, 7, true, true);
    }
}


// write state and get new commands each frame
public OnGameFrame() {
    if (!DirExists(rootFolder)) {
        PrintToServer("please create %s", rootFolder);
        return;
    }

    WriteGeneral();
    WriteState();
    WriteC4();
    WriteVisibility();
    ReadInput();
    currentFrame++;
}


stock void WriteGeneral() {
    if (tmpGeneralOpen) {
        tmpGeneralFile.Close();
        tmpGeneralOpen = false;
    }
    tmpGeneralFile = OpenFile(tmpGeneralFilePath, "w", false, "");
    tmpGeneralOpen = true;
    if (tmpGeneralFile == null) {
        PrintToServer("opening tmpGeneralFile returned null");
        return;
    }
    tmpGeneralFile.WriteLine("Map Name,Round Number,Tick Rate,Map Number");

    char mapName[MAX_INPUT_LENGTH];
    GetCurrentMap(mapName, MAX_INPUT_LENGTH);

    tmpGeneralFile.WriteLine("%s,%i,%i,%f", mapName, roundNumber, mapNumber, GetTickInterval());

    tmpGeneralFile.Close();
    tmpGeneralOpen = false;
    RenameFile(generalFilePath, tmpGeneralFilePath);
}


stock void WriteState() {
    // write state - update temp file, then atomically overwrite last state
    if (tmpStateOpen) {
        tmpStateFile.Close();
        tmpStateOpen = false;
    }
    tmpStateFile = OpenFile(tmpStateFilePath, "w", false, "");
    tmpStateOpen = true;
    if (tmpStateFile == null) {
        PrintToServer("opening tmpStateFile returned null");
        return;
    }
    tmpStateFile.WriteLine("State Frame,Client Id,Name,Team,Active Weapon Id,"
        ... "Rifle Id,Rifle Clip Ammo,Rifle Reserve Ammo,"
        ... "Pistol Id,Pistol Clip Ammo,Pistol Reserve Ammo,"
        ... "Flashes,Molotovs,Smokes,HEs,Decoys,Incendiaries,Has C4,"
        ... "Eye Pos X,Eye Pos Y,Eye Pos Z,Foot Pos Z,"
        ... "Eye Angle Pitch,Eye Angle Yaw,Aimpunch Angle Pitch,Aimpunch Angle Yaw,"
        ... "Eye With Recoil Angle Pitch,Eye With Recoil Angle Yaw,Is Alive,Is Bot");

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client)) {
            char clientName[128];
            GetClientName(client, clientName, 128);
            int clientTeam = GetClientTeam(client);

            // this gets position result from getpos
            GetClientEyePosition(client, clientEyePos[client]);
            GetViewAngleWithRecoil(client);
            // this gets position result from getpos_exact
            GetClientAbsOrigin(client, clientFootPos[client]);
            GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientFootPosOther[client]); 
            // this gets velocity
            GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", clientVelocity[client]);

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

            int activeWeaponEntityId = GetActiveWeaponEntityId(client);
            int activeWeaponId = -1;
            if (activeWeaponEntityId != -1) {
                activeWeaponId = GetWeaponIdFromEntityId(activeWeaponEntityId);
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

            int hasC4 = GetC4EntityId(client) != -1 ? 1 : 0;

            tmpStateFile.WriteLine("%i,%i,%s,%i,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%i,%i,%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,"
                                    ... "%f,%f,"
                                    ... "%f,%f,%f,"
                                    ... "%f,%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%i,%i",
                currentFrame, client, clientName, clientTeam, activeWeaponId,
                rifleWeaponId, rifleClipAmmo, rifleReserveAmmo,
                pistolWeaponId, pistolClipAmmo, pistolReserveAmmo, hasC4,
                GetGrenade(client, Flash), GetGrenade(client, Molotov), 
                GetGrenade(client, Smoke), GetGrenade(client, HE), 
                GetGrenade(client, Decoy), GetGrenade(client, Incendiary), 
                clientEyePos[client][0], clientEyePos[client][1], 
                clientEyePos[client][2], clientFootPos[client][2], clientFootPosOther[client][2],
                clientVelocity[client][0], clientVelocity[client][1], clientVelocity[client][2],
                clientEyeAngle[client][0], clientEyeAngle[client][1],
                mAimPunchAngle[client][0], mAimPunchAngle[client][1],
                clientEyeAngleWithRecoil[client][0], clientEyeAngleWithRecoil[client][1],
                clientOtherState[client], clientFake);
        }
    }
    tmpStateFile.Close();
    tmpStateOpen = false;
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

stock void WriteC4() {
    if (tmpC4Open) {
        tmpC4File.Close();
        tmpC4Open = false;
    }
    tmpC4File = OpenFile(tmpC4FilePath, "w", false, "");
    tmpC4Open = true;
    if (tmpC4File == null) {
        PrintToServer("opening tmpC4File returned null");
        return;
    }
    tmpC4File.WriteLine("Is Planted,Is Dropped,"
        ... "Pos X,Pos Y,Pos Z");

    int c4Ent = -1;
    c4Ent = FindEntityByClassname(c4Ent, "planted_c4"); 
    int isPlanted = c4Ent == -1 ? 0 : 1;
    if (c4Ent == -1) {
        c4Ent = FindEntityByClassname(c4Ent, "weapon_c4"); 
    }

    if (c4Ent != -1) {
        float zeroVector[3] = {0.0, 0.0, 0.0};
        GetEntPropVector(c4Ent, Prop_Send, "m_vecOrigin", c4Position);
        int isDropped = !isPlanted && GetVectorDistance(zeroVector, c4Position) != 0.0 ? 1 : 0;
        tmpC4File.WriteLine("%i,%i,"
            ... "%f,%f,%f",
            isPlanted, isDropped, 
            c4Position[0], c4Position[1], c4Position[2]);
    }

    tmpC4File.Close();
    tmpC4Open = false;
    RenameFile(c4FilePath, tmpC4FilePath);
}


stock void ReadInput() {
    if (tmpInputOpen) {
        tmpInputFile.Close();
        tmpInputOpen = false;
    }
    // move file to tmp location so not overwritten, then read it
    // update to latest input if it exists
    // only use new inputs, give controller a chance to resopnd
    if (FileExists(inputFilePath)) {
        // on each new input file, recheck which inputs are valid
        // this prevents flipping back to bot control on in between frames where no input
        for (int client = 1; client <= MaxClients; client++) {
            inputSet[client] = false;
        }

        RenameFile(tmpInputFilePath, inputFilePath);

        tmpInputFile = OpenFile(tmpInputFilePath, "r", false, "");
        tmpInputOpen = true;
        tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);

        while(!tmpInputFile.EndOfFile()) {
            tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);
            ExplodeString(inputBuffer, ",", inputExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            int client = StringToInt(inputExplodedBuffer[0]);

            inputSet[client] = true;
            inputButtons[client] = StringToInt(inputExplodedBuffer[1]);
            inputMovement[client][Forward] = inputButtons[client] & IN_FORWARD > 0;
            inputMovement[client][Backward] = inputButtons[client] & IN_BACK > 0;
            inputMovement[client][Left] = inputButtons[client] & IN_MOVELEFT > 0;
            inputMovement[client][Right] = inputButtons[client] & IN_MOVERIGHT > 0;
            inputAngleDeltaPct[client][0] = StringToFloat(inputExplodedBuffer[2]);
            inputAngleDeltaPct[client][0] = fmax(-1.0, fmin(1.0, inputAngleDeltaPct[client][0]));
            inputAngleDeltaPct[client][1] = StringToFloat(inputExplodedBuffer[3]);
            inputAngleDeltaPct[client][1] = fmax(-1.0, fmin(1.0, inputAngleDeltaPct[client][1]));
        }

        tmpInputFile.Close();
        tmpInputOpen = false;
    }
}


// https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
    if (recordMaxs && client == clientToRecord) {
        printHumanAngleStats(fAngles, iButtons);
    }
    if (!inputSet[client]) {
        inputSetLastFrame[client] = false;
        return Plugin_Continue;
    }
    if (!IsFakeClient(client)) {
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

    newAngles[0] += inputAngleDeltaPct[client][0] * MAX_ONE_DIRECTION_ANGLE_VEL;
    newAngles[0] = fmax(-89.0, fmin(89.0, newAngles[0]));

    newAngles[1] += inputAngleDeltaPct[client][1] * MAX_ONE_DIRECTION_ANGLE_VEL;
    newAngles[1] = makeNeg180To180(newAngles[1]);

    TeleportEntity(client, NULL_VECTOR, newAngles, NULL_VECTOR);
    //fAngles = newAngles;
    //SetEntPropVector(client, Prop_Data, "m_angEyeAngles", newAngles);
    clientEyeAngle[client] = newAngles;

    if (printStatus) {
        char clientName[128];
        GetClientName(client, clientName, 128);
        PrintToServer("new inputs for %i: %s", client, clientName);
        PrintToServer("new fVel: (%f, %f, %f)",
            fVel[0], fVel[1], fVel[2]);
        PrintToServer("old Angles: (%f, %f, %f), new fAngles: (%f, %f, %f)",
            oldAngles[0], oldAngles[1], oldAngles[2],
            newAngles[0], newAngles[1], newAngles[2]);
        PrintToServer("delta pct Angles: (%f, %f)",
            inputAngleDeltaPct[client][0],
            inputAngleDeltaPct[client][1]);
        PrintToServer("delta Angles: (%f, %f, %f)",
            makeNeg180To180(newAngles[0] - oldAngles[0]),
            makeNeg180To180(newAngles[1] - oldAngles[1]),
            makeNeg180To180(newAngles[2] - oldAngles[2]));
    }

    // disable changing angles until next movement
    //inputAngleDeltaPct[client][0] = 0.0;
    //inputAngleDeltaPct[client][1] = 0.0;

    inputSetLastFrame[client] = true;

    return Plugin_Changed;
}

stock void printHumanAngleStats(float fAngles[3], int iButtons) {
    if (lastAngles[0] != DEBUG_INVALID_DIFF) {
        float curAngleVel[2];
        curAngleVel[0] = makeNeg180To180(fAngles[0] - lastAngles[0]);
        curAngleVel[1] = makeNeg180To180(fAngles[1] - lastAngles[1]);

        // assuming DEBUG_INVALID_DIFF is smaller than any possible angular velocity
        // set max angle velocity once have any velocity
        maxAngleVel[0] = fmax(maxAngleVel[0], curAngleVel[0]);
        maxAngleVel[1] = fmax(maxAngleVel[1], curAngleVel[1]);

        // set max angle accleration once have two velocities
        if (lastAngleVel[0] != DEBUG_INVALID_DIFF) {
            float curAngleAccel[2];
            curAngleAccel[0] = curAngleVel[0] - lastAngleVel[0];
            curAngleAccel[1] = curAngleVel[1] - lastAngleVel[1];
            maxAngleAccel[0] = fmax(maxAngleAccel[0], curAngleAccel[0]);
            maxAngleAccel[1] = fmax(maxAngleAccel[1], curAngleAccel[1]);

            // only print once all values are filled in
            PrintToServer("buttons: %i", iButtons);
            PrintToServer("curAngleVel: (%f, %f), curAngleAccel: (%f, %f)", 
                curAngleVel[0], curAngleVel[1],
                curAngleAccel[0], curAngleAccel[1]);
            PrintToServer("maxAngleVel: (%f, %f), maxAngleAccel: (%f, %f)", 
                maxAngleVel[0], maxAngleVel[1],
                maxAngleAccel[0], maxAngleAccel[1]);
        }

        lastAngleVel = curAngleVel;
    }
    lastAngles[0] = fAngles[0];
    lastAngles[1] = fAngles[1];
}

stock float makeNeg180To180(float angle) {
    angle = floatMod(angle, 360.0);
    if (angle > 180.0) {
        angle -= 360.0;
    }
    return angle;
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

// this always mods to positive
stock float floatMod(float num, float denom) {
    return num - denom * RoundToFloor(num / denom);
}
