#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include "bot-link/weapon_status.sp"
#include "bot-link/grenade_status.sp"
#include "bot-link/visibility.sp"
#include "bot-link/events.sp"
#define MAX_INPUT_LENGTH 1000
#define MAX_INPUT_FIELDS 20
#define MAX_PATH_LENGTH 256
#define MAX_ONE_DIRECTION_SPEED 450.0
#define MAX_ONE_DIRECTION_ANGLE_VEL 15.0
#define DEBUG_INVALID_DIFF -20000.0
#define MAX_BOT_STOP_LENGTH 5
#define MAX_BOT_AGGRESSION_LENGTH 100
#include "bot-link/script_interface.sp"
#include "bot-link/vis_points.sp"

public Plugin myinfo =
{
    name = "Durst Bot Link",
    author = "David Durst",
    description = "Link the CSGO server to another program running bot AI",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

// input commands to read
int frameForLastInput;
bool newInput;
static int missedInputFramesThreshold = 5;
int missedInputFrames[MAXPLAYERS+1];
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
float inputAngle[MAXPLAYERS+1][3];
bool inputAngleAbsolute[MAXPLAYERS+1];
bool forceInput[MAXPLAYERS+1];
bool enableAbsPos[MAXPLAYERS+1];
float absPos[MAXPLAYERS+1][3];
float absView[MAXPLAYERS+1][3];

// GetClientEyePosition - this will store where looking

// check GetClientAbsOrigin vs  GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos); 
// 8-21-22 - abs origin gets the position fo the player model in absolute space
// m_vecOrigin gets it relevant to parent, which is 0 for all players since not attached.
// m_vecAbsOrigin is in prop_data, which should always be same as GetClientAbsOrigin, but not in demo so dont
// care about it for now

// states to outpuot
float clientEyePos[MAXPLAYERS+1][3];
float clientEyeAngle[MAXPLAYERS+1][3];
float clientEyeAngleWithRecoil[MAXPLAYERS+1][3];
float clientFootPos[MAXPLAYERS+1][3];
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

// player flag values
#define PF_ONGROUND 1
#define PF_DUCKING 2
#define PF_ANIMDUCKING 4

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
static char debugIndicatorDirPath[] = "addons/sourcemod/bot-link-data/debug_indicator";

// general variables
ConVar cvarBotStop, cvarBotChatter, cvarBotSnipers, cvarWarmupTime, cvarMaxRounds, cvarMatchCanClinch, cvarRoundRestartDelay, cvarFreezeTime, cvarMatchRestartDelay,
    cvarCompetitiveOfficial5v5, cvarMatchEndChangeLevel, cvarSMNextMap, cvarBotDifficulty;
int internalMaxRounds = 100;
char internalBotStop[MAX_BOT_STOP_LENGTH] = "1";
char internalBotAggression[MAX_BOT_AGGRESSION_LENGTH] = "1";
char botAggressionExploded[MAX_INPUT_FIELDS][MAX_BOT_AGGRESSION_LENGTH];
bool stopCT = true, stopT = true;

int roundNumber, mapNumber, lastBombDefusalRoundNumber;

// debugging variables
ConVar cvarInfAmmo, cvarBombTime, cvarAutoKick, cvarRadarShowall, cvarForceCamera, cvarIgnoreRoundWinConditions;
bool debugStatus;
bool printStatus;
bool recordMaxs;
int clientToRecord;
float lastAngles[2], lastAngleVel[2], maxAngleVel[2], maxAngleAccel[2];
// hold client until we receive a matching confirmation
int clientLastTeleportId[MAXPLAYERS+1];
int clientLastTeleportConfirmationId[MAXPLAYERS+1];

// placed down here so it has access to all variables defined above
#include "bot-link/bot_debug.sp"
#include "bot-link/bot_aggression.sp"
#include "bot-link/overlay.sp"
 
public void OnPluginStart()
{
    RegConsoleCmd("sm_botDebug", smBotDebug, "(t/f) - make bomb time 10 minutes and give infinite ammo (toggle option)");
    RegConsoleCmd("sm_applyConVars", smBotDebug, "- reapply convars");
    RegConsoleCmd("sm_drawX", smDrawX, "<minX> <minY> <minZ> <maxX> <maxY> <maxZ> <colors sum of 1,2,4,8> <duration> - draw x");
    RegConsoleCmd("sm_draw", smDraw, "- immediately end the current round in a draw");
    RegConsoleCmd("sm_skipFirstRound", smSkipFirstRound, "- force team to win a round (in way that server recognizes)");
    RegConsoleCmd("sm_printLink", smPrintLink, "- print debugging values from bot-link");
    RegConsoleCmd("sm_recordMaxs", smRecordMaxs, "- record max angular values for debugging");
    RegConsoleCmd("sm_queryRangeVisPointPairs", smQueryRangeVisPointPairs, "- query all vis point pairs to determine basic PVS");
    RegisterDebugFunctions();
    RegisterAggressionFunctions();
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("bomb_defused", OnBombDefused, EventHookMode_PostNoCopy);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("weapon_fire", Event_WeaponFire);

    cvarBotStop = FindConVar("bot_stop");
    cvarBotChatter = FindConVar("bot_chatter");
    cvarBotSnipers = FindConVar("bot_allow_snipers");
    cvarWarmupTime = FindConVar("mp_warmuptime");
    cvarMaxRounds = FindConVar("mp_maxrounds");
    cvarMatchCanClinch = FindConVar("mp_match_can_clinch");
    cvarRoundRestartDelay = FindConVar("mp_round_restart_delay");
    cvarFreezeTime = FindConVar("mp_freezetime");
    cvarMatchRestartDelay = FindConVar("mp_match_restart_delay");
    cvarCompetitiveOfficial5v5 = FindConVar("sv_competitive_official_5v5");
    cvarMatchEndChangeLevel = FindConVar("mp_match_end_changelevel");
    cvarSMNextMap = FindConVar("sm_nextmap");
    cvarBotDifficulty = FindConVar("bot_difficulty");
    cvarInfAmmo = FindConVar("sv_infinite_ammo");
    cvarBombTime = FindConVar("mp_c4timer");
    cvarAutoKick = FindConVar("mp_autokick");
    cvarRadarShowall = FindConVar("mp_radar_showall");
    cvarForceCamera = FindConVar("mp_forcecamera");
    cvarIgnoreRoundWinConditions = FindConVar("mp_ignore_round_win_conditions");

    mapNumber = 0;
    roundNumber = 0;
    lastBombDefusalRoundNumber = -1;
    if (DirExists(debugIndicatorDirPath)) {
        debugStatus = true;
    }
    else {
        debugStatus = false;
    }
    ReadMaxRounds();
    ReadBotStop();
    ReadBotAggression();
    printStatus = false;
    recordMaxs = false;
    applyConVars();

    weaponRecoilScale = FindConVar("weapon_recoil_scale");
    viewRecoilTracking = FindConVar("view_recoil_tracking");

    PrintToServer("reset teleport");
    for (int i = 0; i < MAXPLAYERS+1; i++) {
        lastRecoilAngleAdjustment[i][0] = 0.0;
        lastRecoilAngleAdjustment[i][1] = 0.0;
        lastRecoilAngleAdjustment[i][2] = 0.0;
        missedInputFrames[i] = 0;
        inputSetLastFrame[i] = false;
        clientLastTeleportId[i] = 0;
        clientLastTeleportConfirmationId[i] = 0;
        forceInput[i] = false;
        enableAbsPos[i] = false;
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
    PrintToConsole(client, "running smPrintLink");
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
    if (args != 0 && args != 1) {
        PrintToConsole(client, "smBotDebug requires 0 or 1 ar1");
        return Plugin_Handled;
    }

    if (args == 0) {
        debugStatus = !debugStatus;
    }
    else {
        char arg[128];
        GetCmdArg(1, arg, sizeof(arg));
        if (arg[0] == 't') {
            debugStatus = true;
        }
        else {
            debugStatus = false;
        }
    }

    if (debugStatus && !DirExists(debugIndicatorDirPath)) {
        CreateDirectory(debugIndicatorDirPath, 509);
    }
    else if (!debugStatus && DirExists(debugIndicatorDirPath)) {
        RemoveDir(debugIndicatorDirPath);
    }

    applyConVars();
    return Plugin_Handled;
}

public Action:smDraw(client, args) {
    CS_TerminateRound(0.0, CSRoundEnd_Draw, false); 
    return Plugin_Handled;
}

public Action:smSkipFirstRound(client, args) {
    int tScore = CS_GetTeamScore(CS_TEAM_T),
        ctScore = CS_GetTeamScore(CS_TEAM_CT);
    if (tScore == 0 && ctScore == 0) {
        //CS_SetTeamScore(CS_TEAM_CT, 1);
        //SetTeamScore(CS_TEAM_CT, 1);
        //CS_TerminateRound(0.0, CSRoundEnd_CTWin, false); 
        smSlayAllBut(client, 0);
    }
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
    lastBombDefusalRoundNumber = -1;
    SetConVarString(cvarSMNextMap, "de_dust2", true, true);
    SetLastRoundStartFrame(currentFrame);
    return Plugin_Continue;
}

public Action OnBombDefused(Event event, const char[] sName, bool bDontBroadcast) {
    lastBombDefusalRoundNumber = roundNumber;
    return Plugin_Continue;
}

stock void applyConVars() {
    SetConVarString(cvarBotStop, internalBotStop, true, true);
    SetConVarString(cvarBotChatter, "off", true, true);
    SetConVarInt(cvarAutoKick, 0, true, true);
    SetConVarInt(cvarBotSnipers, 0, true, true);
    SetConVarInt(cvarWarmupTime, 0, true, true);
    SetConVarInt(cvarMaxRounds, internalMaxRounds, true, true);
    SetConVarInt(cvarMatchCanClinch, 0, true, true);
    SetConVarFloat(cvarRoundRestartDelay, 0.1, true, true);
    SetConVarFloat(cvarFreezeTime, 0.1, true, true);
    SetConVarInt(cvarMatchRestartDelay, 10, true, true);
    SetConVarInt(cvarMatchEndChangeLevel, 1, true, true);
    SetConVarInt(cvarBotDifficulty, 3, true, true);
    SetConVarInt(cvarCompetitiveOfficial5v5, 1, true, true);
    if (debugStatus) {
        SetConVarInt(cvarInfAmmo, 1, true, true);
        SetConVarInt(cvarBombTime, 600, true, true);
        SetConVarInt(cvarRadarShowall, 1, true, true);
        SetConVarInt(cvarForceCamera, 0, true, true);
        SetConVarInt(cvarIgnoreRoundWinConditions, 1, true, true);
    }
    else {
        SetConVarInt(cvarInfAmmo, 0, true, true);
        SetConVarInt(cvarBombTime, 40, true, true);
        SetConVarInt(cvarRadarShowall, 0, true, true);
        SetConVarInt(cvarForceCamera, 1, true, true);
        SetConVarInt(cvarIgnoreRoundWinConditions, 0, true, true);
    }
}


// write state and get new commands each frame
public OnGameFrame() {
    if (!DirExists(rootFolder)) {
        PrintToServer("please create %s", rootFolder);
        return;
    }

    //PrintToServer("start onGameFrame %i", currentFrame);
    EnsureAllAK();
    ReadInput();
    ReadExecuteScript();
    WriteGeneral();
    WriteState();
    WriteC4();
    WriteVisibility();
    WriteWeaponFire();
    WritePlayerHurt();
    WriteRoundStart();
    WriteSay();
    currentFrame++;
    if (currentFrame < 0) {
        currentFrame = 0;
    }
    //PrintToServer("end onGameFrame %i", currentFrame);
}

stock void EnsureAllAK() {
    for (int client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && IsPlayerAlive(client)) {
            int clientTeam = GetClientTeam(client);
            bool uncontrolledBot = (!stopT && clientTeam == CS_TEAM_T) || 
                (!stopCT && clientTeam == CS_TEAM_CT);

            int activeWeaponEntityId = GetActiveWeaponEntityId(client);
            int activeWeaponId = -1;
            if (activeWeaponEntityId != -1) {
                activeWeaponId = GetWeaponIdFromEntityId(activeWeaponEntityId);
            }

            int rifleId = GetRifleEntityId(client), rifleWeaponId = -1;
            if (rifleId != -1) {
                rifleWeaponId = GetWeaponIdFromEntityId(rifleId);
            }

            int pistolId = GetPistolEntityId(client), pistolWeaponId = -1;
            if (pistolWeaponId != -1) {
                pistolWeaponId = GetWeaponIdFromEntityId(pistolId);
            }

            if (rifleWeaponId != -1 && rifleWeaponId != 7) {
                RemovePlayerItem(client, rifleId);
            } 
            else if (pistolWeaponId != -1) {
                RemovePlayerItem(client, pistolId);
            }
            else if (rifleWeaponId == -1) {
                GivePlayerItem(client, "weapon_ak47");
            }
            else if (!uncontrolledBot && IsFakeClient(client) && activeWeaponId != rifleWeaponId) {
                FakeClientCommand(client, "use weapon_ak47");
            }
        }
    }
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
    tmpGeneralFile.WriteLine("Map Name,Round Number,T Score,CT Score,Map Number,Tick Rate,Game Time,Push Round,Enable Aggression Control,Temperature");

    char mapName[MAX_INPUT_LENGTH];
    GetCurrentMap(mapName, MAX_INPUT_LENGTH);

    int tScore = CS_GetTeamScore(CS_TEAM_T),
        ctScore = CS_GetTeamScore(CS_TEAM_CT);

    tmpGeneralFile.WriteLine("%s,%i,%i,%i,%i,%f,%f,%i,%i,%f", 
        mapName, roundNumber, tScore, ctScore, mapNumber, GetTickInterval(), GetGameTime(), pushRound, enableAggressionControl, temperature);

    tmpGeneralFile.Close();
    tmpGeneralOpen = false;
    RenameFile(generalFilePath, tmpGeneralFilePath);
}


int prevFrame = 0;
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
    tmpStateFile.WriteLine("State Frame,Client Id,Teleported Id,Name,Team,"
        ... "Health,Armor,Has Helmet,"
        ... "Active Weapon Id,Next Primary Attack,Next Secondary Attack,Time Weapon Idle,Recoil Index,Reload Visually Complete,"
        ... "Rifle Id,Rifle Clip Ammo,Rifle Reserve Ammo,"
        ... "Pistol Id,Pistol Clip Ammo,Pistol Reserve Ammo,Has C4,"
        ... "Flashes,Molotovs,Smokes,HEs,Decoys,Incendiaries,Zeus,"
        ... "Eye Pos X,Eye Pos Y,Eye Pos Z,Foot Pos Z,"
        ... "Vel X, Vel Y, Vel Z,"
        ... "Eye Angle Pitch,Eye Angle Yaw,Aimpunch Angle Pitch,Aimpunch Angle Yaw,Viewpunch Angle Pitch,Viewpunch Angle Yaw,"
        ... "Eye With Recoil Angle Pitch,Eye With Recoil Angle Yaw,Is Alive,Is Bot,Is Airborne,Is Scoped,Duck Amount,"
        ... "Duck Key Pressed,Is Reloading,Is Walking,Flash Duration,Has Defuser,Money,Ping,Game Time,Input Set,"
        ... "Push 5s, Push 10s, Push 20s");

    if (false && newInput) {
        if (frameForLastInput + 1 != currentFrame) {
            PrintToServer("frame for last input %i, current frame: %i", frameForLastInput, currentFrame);
        }
        newInput = false;
    }
    //PrintToServer("game time: %f, game frame time: %f, previous frame %i, current frame %i", GetGameTime(), GetGameFrameTime(), prevFrame, currentFrame);
    if (false && prevFrame != 0 && prevFrame != currentFrame - 1) {
        PrintToServer("Skipped frame: previous frame %i, current frame %i", prevFrame, currentFrame);
    }
    prevFrame = currentFrame;

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
            float nextPrimaryAttack = -1.0;
            float nextSecondaryAttack = -1.0;
            float timeWeaponIdle = -1.0;
            float recoilIndex = -1.0;
            int reloadVisuallyComplete = -1;
            // this should be something, but its always 0
            // int nextThinkTick = -1;
            bool isReloading = false;
            if (activeWeaponEntityId != -1) {
                activeWeaponId = GetWeaponIdFromEntityId(activeWeaponEntityId);
                nextPrimaryAttack = GetEntPropFloat(activeWeaponEntityId, Prop_Send, "m_flNextPrimaryAttack");
                nextSecondaryAttack = GetEntPropFloat(activeWeaponEntityId, Prop_Send, "m_flNextSecondaryAttack");
                timeWeaponIdle = GetEntPropFloat(activeWeaponEntityId, Prop_Send, "m_flTimeWeaponIdle");
                recoilIndex = GetEntPropFloat(activeWeaponEntityId, Prop_Send, "m_flRecoilIndex");
                isReloading = IsWeaponReloading(activeWeaponEntityId);
                reloadVisuallyComplete = GetEntProp(activeWeaponEntityId, Prop_Send, "m_bReloadVisuallyComplete");
                //nextThinkTick = GetEntProp(activeWeaponEntityId, Prop_Send, "m_nNextThinkTick");
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

            int isAirborne = !(GetEntityFlags(client) & FL_ONGROUND) ? 1 : 0;
            int isScoped = GetEntProp(client, Prop_Send, "m_bIsScoped") ? 1 : 0;
            float duckAmount = GetEntPropFloat(client, Prop_Send, "m_flDuckAmount");
            // this doesnt tell me anything beyond m_flNextPrimaryAttack, so ignoring it
            //float nextAttack = GetEntPropFloat(client, Prop_Send, "m_flNextAttack");

            int health = GetClientHealth(client);
            int armor = GetClientArmor(client);
            bool hasHelmet = GetEntProp(client, Prop_Send, "m_bHasHelmet") != 0;
            bool duckKeyPressed = (GetEntProp(client, Prop_Send, "m_fFlags") & PF_ANIMDUCKING) != 0;
            bool isWalking = GetEntProp(client, Prop_Send, "m_bIsWalking") != 0;
            float flashDuration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
            // this doesnt matter, its always 255 once flashed
            //float flashMaxAlpha = GetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha");
            bool hasDefuser = GetEntProp(client, Prop_Send, "m_bHasDefuser") != 0;
            int money = GetEntProp(client, Prop_Send, "m_iAccount");
            float gameTime = GetTickInterval() * GetEntProp(client, Prop_Send, "m_nTickBase");
            int ping = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, client);

            /*
            if (clientEyeAngle[client][1] > -179 && clientEyeAngle[client][1] < -177) {
                PrintToServer("%i in range, input was %f, clientLastTeleportId %i, clientLastTeleportConfirmationId %i", 
                    client, inputAngle[client][1], clientLastTeleportId[client], clientLastTeleportConfirmationId[client]);
            }
            */


            tmpStateFile.WriteLine("%i,%i,%i,%s,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%i,%f,%f,%f,%f,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%i,%i,%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,"
                                    ... "%i,%i,%i,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%f,%f,"
                                    ... "%i,%i,%i,%i,%f,"
                                    ... "%i,%i,%i,%f,%i,%i,%i,%f,%i,"
                                    ... "%i,%i,%i",
                currentFrame, client, clientLastTeleportId[client], clientName, clientTeam, 
                health, armor, hasHelmet, 
                activeWeaponId, nextPrimaryAttack, nextSecondaryAttack, timeWeaponIdle, recoilIndex, reloadVisuallyComplete,
                rifleWeaponId, rifleClipAmmo, rifleReserveAmmo,
                pistolWeaponId, pistolClipAmmo, pistolReserveAmmo, hasC4,
                GetGrenade(client, Flash), GetGrenade(client, Molotov), 
                GetGrenade(client, Smoke), GetGrenade(client, HE), 
                GetGrenade(client, Decoy), GetGrenade(client, Incendiary), HaveZeus(client),
                clientEyePos[client][0], clientEyePos[client][1], 
                // 8-21-22 - investigated using separate eye and foot poses for all three dimensions
                // didnt make a different as eye pos is camera pos and thats directly above origin
                clientEyePos[client][2], clientFootPos[client][2], 
                clientVelocity[client][0], clientVelocity[client][1], clientVelocity[client][2],
                clientEyeAngle[client][0], clientEyeAngle[client][1],
                mAimPunchAngle[client][0], mAimPunchAngle[client][1],
                mViewPunchAngle[client][0], mViewPunchAngle[client][1],
                clientEyeAngleWithRecoil[client][0], clientEyeAngleWithRecoil[client][1],
                clientOtherState[client], clientFake, isAirborne, isScoped, duckAmount,
                duckKeyPressed, isReloading, isWalking, flashDuration, hasDefuser, money, ping, gameTime, inputSet[client],
                clientPush5s[client], clientPush10s[client], clientPush20s[client]);

            /*
            int sz = GetEntPropArraySize(client, Prop_Send, "m_flPoseParameter");
            float poseParams[24];
            for (int j = 0; j < sz; j++) {
                poseParams[j] = GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", j);
            }
            tmpStateFile.WriteLine("%f,%f,%f,%f,%f,%f,"
                                    ... "%f,%f,%f,%f,%f,%f,"
                                    ... "%f,%f,%f,%f,%f,%f,"
                                    ... "%f,%f,%f,%f,%f,%f,",
                                    poseParams[0], poseParams[1], poseParams[2], poseParams[3], poseParams[4], poseParams[5],
                                    poseParams[6], poseParams[7], poseParams[8], poseParams[9], poseParams[10], poseParams[11],
                                    poseParams[12], poseParams[13], poseParams[14], poseParams[15], poseParams[16], poseParams[17],
                                    poseParams[18], poseParams[19], poseParams[20], poseParams[21], poseParams[22], poseParams[23]);
            */


        }
    }
    tmpStateFile.Close();
    tmpStateOpen = false;
    RenameFile(stateFilePath, tmpStateFilePath);

    ReadUpdateOverlay();
}


stock void GetViewAngleWithRecoil(int client) {
    // this gets angle from getpos, getpos_exact seems to be this in range of 0-360 for pitch,
    // which is weird as legal pitch range is -90-90 yaw
    // tried GetClientAbsAngles and those werent as useful, might be with abs value for getpos_exact
    // 8-20-22 - confirmed that abs angles are for body, not camera (so pitch never 0), getpos_exact is similarly for body and not camera
    // confirmed that both GetClientAbsAngles and GetClientEyeAngles dont adjust for recoil

    // since bots drift, if under my control, dont actually update EyeAngles
    // if miss frame on a teleport, this would allow game to move eye. need to hold on teleport
    if (!inputSet[client] && clientLastTeleportId[client] == clientLastTeleportConfirmationId[client]) {
        //PrintToServer("read for client %i", client);
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
    tmpC4File.WriteLine("Is Planted,Is Dropped,Is Defused,"
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
        tmpC4File.WriteLine("%i,%i,%i,"
            ... "%f,%f,%f",
            isPlanted, isDropped, lastBombDefusalRoundNumber == roundNumber,
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

    for (int client = 1; client <= MaxClients; client++) {
        if (missedInputFrames[client] > missedInputFramesThreshold) {
            inputSet[client] = false;
        }
        else {
            /*
            if (missedInputFrames[client] > 0) {
                PrintToServer("decay for frame %i", currentFrame);
            }
            */
            missedInputFrames[client]++;
        }
    }

    // move file to tmp location so not overwritten, then read it
    // update to latest input if it exists
    // only use new inputs, give controller a chance to resopnd
    if (FileExists(inputFilePath)) {

        RenameFile(tmpInputFilePath, inputFilePath);

        tmpInputFile = OpenFile(tmpInputFilePath, "r", false, "");
        tmpInputOpen = true;
        tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);

        while(!tmpInputFile.EndOfFile()) {
            tmpInputFile.ReadLine(inputBuffer, MAX_INPUT_LENGTH);
            ExplodeString(inputBuffer, ",", inputExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            int client = StringToInt(inputExplodedBuffer[0]);
            frameForLastInput = StringToInt(inputExplodedBuffer[1]);
            clientLastTeleportConfirmationId[client] = StringToInt(inputExplodedBuffer[2]);
            newInput = true;

            inputSet[client] = true;
            missedInputFrames[client] = 0;
            inputButtons[client] = StringToInt(inputExplodedBuffer[3]);
            inputMovement[client][Forward] = inputButtons[client] & IN_FORWARD > 0;
            inputMovement[client][Backward] = inputButtons[client] & IN_BACK > 0;
            inputMovement[client][Left] = inputButtons[client] & IN_MOVELEFT > 0;
            inputMovement[client][Right] = inputButtons[client] & IN_MOVERIGHT > 0;
            inputAngle[client][0] = StringToFloat(inputExplodedBuffer[4]);
            inputAngle[client][1] = StringToFloat(inputExplodedBuffer[5]);
            inputAngleAbsolute[client] = StringToInt(inputExplodedBuffer[6]) != 0;
            forceInput[client] = StringToInt(inputExplodedBuffer[7]) != 0;
            enableAbsPos[client] = StringToInt(inputExplodedBuffer[8]) != 0;
            absPos[client][0] = StringToFloat(inputExplodedBuffer[9]);
            absPos[client][1] = StringToFloat(inputExplodedBuffer[10]);
            absPos[client][2] = StringToFloat(inputExplodedBuffer[11]);
            absView[client][0] = StringToFloat(inputExplodedBuffer[12]);
            absView[client][1] = StringToFloat(inputExplodedBuffer[13]);
            absView[client][2] = 0.0;
        }

        tmpInputFile.Close();
        tmpInputOpen = false;
    }
}


// https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVel[3], float fAngles[3], int & iWeapon, int & iSubtype, int & iCmdNum, int & iTickcount, int & iSeed, int iMouse[2])
{
    //PrintToServer("run cmd player %i game frame %i", client, currentFrame);
    if (recordMaxs && client == clientToRecord) {
        printHumanAngleStats(fAngles, iButtons);
    }
    if (!inputSet[client]) {
        // DO NOT SET TELEPORT HERE
        // game will continue to reset to pre-teleport angles
        // so just dont change bot angles if not driving them every frame
        // this wont trigger if if bot sending wrong input due to not catching up to teleport
        inputSetLastFrame[client] = false;
        return Plugin_Continue;
    }
    if (!IsFakeClient(client) && !forceInput[client]) {
        return Plugin_Continue;
    }
    else if (!IsFakeClient(client)) {
        //PrintToServer("Forcing %i", client);
    }
    int clientTeam = GetClientTeam(client);
    if (!stopT && clientTeam == CS_TEAM_T) {
        return Plugin_Continue;
    }
    if (!stopCT && clientTeam == CS_TEAM_CT) {
        return Plugin_Continue;
    }

    iButtons = inputButtons[client];
    /*
    if (iButtons & IN_ATTACK > 0) {
        char shooterName[128];
        GetClientName(client, shooterName, 128);
        PrintToServer("%s shot on frame %i", shooterName, currentFrame);        
    }
    */

    if (enableAbsPos[client]) {
        float zeroVector[3] = {0.0, 0.0, 0.0};
        TeleportEntity(client, absPos[client], absView[client], zeroVector);
    }
    else {
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
        //float oldAngles[3];
        if (inputSetLastFrame[client]) {
            newAngles = clientEyeAngle[client];
        }
        else {
            newAngles = fAngles;
        }
        //oldAngles = newAngles;
        
        if (clientLastTeleportId[client] == clientLastTeleportConfirmationId[client]) {
            if (inputAngleAbsolute[client]) {
                TeleportEntity(client, NULL_VECTOR, inputAngle[client], NULL_VECTOR);
                clientEyeAngle[client] = inputAngle[client];
            }
            else {
                newAngles[0] += inputAngle[client][0] * MAX_ONE_DIRECTION_ANGLE_VEL;
                newAngles[0] = fmax(-89.0, fmin(89.0, newAngles[0]));

                newAngles[1] += inputAngle[client][1] * MAX_ONE_DIRECTION_ANGLE_VEL;
                newAngles[1] = makeNeg180To180(newAngles[1]);
                TeleportEntity(client, NULL_VECTOR, newAngles, NULL_VECTOR);
                clientEyeAngle[client] = newAngles;
            }
        }
        else {
            TeleportEntity(client, NULL_VECTOR, clientEyeAngle[client], NULL_VECTOR);
        }

        //fAngles = newAngles;
        //SetEntPropVector(client, Prop_Data, "m_angEyeAngles", newAngles);

        /*
        if (printStatus && IsPlayerAlive(client)) {
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
        */

        // disable changing angles until next movement
        //inputAngleDeltaPct[client][0] = 0.0;
        //inputAngleDeltaPct[client][1] = 0.0;

        if (clientLastTeleportId[client] != clientLastTeleportConfirmationId[client]) {
            fVel[0] = 0.0;
            fVel[1] = 0.0;
            fVel[2] = 0.0;
        }
    }

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


stock void PrintCantFindFolder() {
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
