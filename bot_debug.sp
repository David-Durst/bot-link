static int g_iLaserMaterial, g_iHaloMaterial;
float savePos[3];
public void RegisterDebugFunctions() 
{
    RegConsoleCmd("sm_savePos", smSavePos, "<player name> - save the position of the named player to place a player in");
    RegConsoleCmd("sm_setPos", smSetPos, "<x> <y> <z> - set a position to place a bot in");
    RegConsoleCmd("sm_getPos", smGetPos, "- get the current a position to place a bot in");
    RegConsoleCmd("sm_teleport", smTeleport, "<player name> - teleport the named player to the saved pos");
    RegConsoleCmd("sm_slayAllBut", smSlayAllBut, "<player name 0> ... - slay all but the listed players");
    RegConsoleCmd("sm_line", smLine, "- test draw line");
    g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
}

public Action smSavePos(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSavePos requires 1 arg");
        return Plugin_Handled;
    }

    char arg[128];
    // arg 0 is the command
    GetCmdArg(1, arg, sizeof(arg));

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            char targetName[128];
            GetClientName(target, targetName, 128);
            if (StrEqual(arg, targetName, false)) {
                GetClientAbsOrigin(target, savePos);
                return Plugin_Handled;
            }
        }
    }
        
    PrintToConsole(client, "smSavePos received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSetPos(int client, int args)
{
    if (args != 3) {
        PrintToConsole(client, "smSetPos requires 3 args");
        return Plugin_Handled;
    }

    char arg[128];
    for (int i = 1; i <= args; i++) {
        GetCmdArg(i, arg, sizeof(arg));
        savePos[i-1] = StringToFloat(arg);
    }
    return Plugin_Handled;
}

public Action smGetPos(int client, int args)
{
    PrintToConsole(client, "savedPos (%f, %f, %f)", savePos[0], savePos[1], savePos[2]);
    return Plugin_Handled;
}

public Action smTeleport(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smTeleport requires 1 arg");
        return Plugin_Handled;
    }

    char arg[128];
    // arg 0 is the command
    GetCmdArg(1, arg, sizeof(arg));

    float zeroVec[3] = {0.0, 0.0, 0.0};

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            char targetName[128];
            GetClientName(target, targetName, 128);
            if (StrEqual(arg, targetName, false)) {
                TeleportEntity(target, savePos, zeroVec, zeroVec);
                return Plugin_Handled;
            }
        }
    }
        
    PrintToConsole(client, "smTeleport received player name that didnt match any valid clients");
    return Plugin_Handled;
}

char savedPlayers[MAXPLAYERS][128];
public Action smSlayAllBut(int client, int args)
{
    int numSavedPlayers = args;
    for (int i = 1; i <= args; i++) {
        GetCmdArg(i, savedPlayers[i-1], 128);
    }

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            char targetName[128];
            GetClientName(target, targetName, 128);
            bool savePlayer = false;
            for (int saveIndex = 0; saveIndex < numSavedPlayers; saveIndex++) {
                if (StrEqual(savedPlayers[saveIndex], targetName, false)) {
                    savePlayer = true;
                    break;
                }
            }
            if (!savePlayer) {
                SDKHooks_TakeDamage(target, client, client, 450.0);
            }
        }
    }
    return Plugin_Handled;
}

public Action smLine(int client, int args) {
    CreateTimer(0.1, DrawAllClients);
    return Plugin_Handled;
}

// this function is only safe to access global variables because code is single threaded
public Action DrawAllClients(Handle timer) {
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            bool moveForward = inputMovement[target][Forward] && !inputMovement[target][Backward];
            bool moveBackward = !inputMovement[target][Forward] && inputMovement[target][Backward];
            bool moveLeft = inputMovement[target][Left] && !inputMovement[target][Right];
            bool moveRight = !inputMovement[target][Left] && inputMovement[target][Right];

            // skip if not moving
            if (!moveForward && !moveBackward && !moveLeft && !moveRight) {
                continue;
            }


            float offsetMoveAngle;
            if (moveForward) {
                offsetMoveAngle = 0.0;
                if (moveLeft) {
                    offsetMoveAngle -= 45.0;
                }
                else if (moveRight) {
                    offsetMoveAngle += 45.0;
                }
            }
            else if (moveBackward) {
                offsetMoveAngle = 180.0;
                if (moveLeft) {
                    offsetMoveAngle += 45.0;
                }
                else if (moveRight) {
                    offsetMoveAngle -= 45.0;
                }
            }
            else {
                if (moveLeft) {
                    offsetMoveAngle = -90.0;
                }
                else if (moveRight) {
                    offsetMoveAngle = 90.0;
                }
            }

            float origin[3], dest[3];
            origin = clientEyePos[target];
            dest = clientEyePos[target];
            float offset = 50.0;
            float yawRad = DegToRad(clientEyeAngle[target][1] + offsetMoveAngle);
            //PrintToConsoleAll("target %d offsetAngle %f yawRad %f", target, offsetMoveAngle, yawRad);
            dest[0] += offset*Cosine(yawRad);
            dest[1] += offset*Sine(yawRad);
                        
            TE_SendBeam(origin, dest, {255, 0, 0, 255});
            
        }
    }
    CreateTimer(0.1, DrawAllClients);
}

void TE_SendBeam(float m_vecMins[3], float m_vecMaxs[3], int color[4], float flDur = 0.1)
{
	TE_SetupBeamPoints(m_vecMins, m_vecMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToAll();
}
