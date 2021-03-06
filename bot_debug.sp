int g_iLaserMaterial, g_iHaloMaterial, g_iWhiteMaterial;
float savePos[3], saveAngle[3];
bool drawLine;
public void RegisterDebugFunctions() 
{
    for (int i = 0; i <= MAXPLAYERS; i++) {
        clientTeleportedSinceLastInput[i] = false;
    }

    RegConsoleCmd("sm_savePos", smSavePos, "<player name> - save the position of the named player to place a player in");
    RegConsoleCmd("sm_setPos", smSetPos, "<x> <y> <z> <pitch> <yaw> - set a position to place a bot in (pitch/yaw optional)");
    RegConsoleCmd("sm_getPos", smGetPos, "- get the current a position to place a bot in");
    RegConsoleCmd("sm_teleport", smTeleport, "<player name> - teleport the named player to the saved pos");
    RegConsoleCmd("sm_slayAllBut", smSlayAllBut, "<player name 0> ... - slay all but the listed players");
    RegConsoleCmd("sm_setArmor", smSetArmor, "<player name> <armor> - set a players armor value");
    RegConsoleCmd("sm_setHealth", smSetHealth, "<player name> <armor> - set a players health value");
    RegConsoleCmd("sm_rotate", smRotate, "<player name> <pitch> <yaw> - rotate the named player to pitch yaw values");
    RegConsoleCmd("sm_giveItem", smGiveItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_removeGuns", smRemoveGuns, "<player name> - remove a players guns");
    RegConsoleCmd("sm_setCurrentItem", smSetCurrentItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_specPlayerToTarget", smSpecPlayerToTarget, "<player name> <target name> <thirdPerson=f> - make player spectate a target (thirdPerson default false, any value is true)");
    RegConsoleCmd("sm_specGoto", smSpecGoto, "<player name> <orig x> <orig y> <orig z> <pitch> <yaw> - spectate camera in absolute position");
    RegConsoleCmd("sm_fakeCmd", smFakeCmd, "<player name> <fake cmd> - do fake client cmd for player");
    RegConsoleCmd("sm_line", smLine, "- draw line in direction player is trying to move");
    RegConsoleCmd("sm_refresh", smRefresh, "- draw line in direction player is trying to move");
    g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iWhiteMaterial = PrecacheModel("materials/sprites/white.vmt");
    g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
    drawLine = false;
    CreateTimer(0.1, DrawAllClients, _, TIMER_REPEAT);
}

stock int GetClientIdByName(const char[] name) {
    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            char targetName[128];
            GetClientName(target, targetName, 128);
            if (StrEqual(name, targetName, false)) {
                return target;
            }
        }
    }
    return -1;
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

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        GetClientAbsOrigin(targetId, savePos);
        GetClientEyeAngles(client, saveAngle);
        //saveAngle = clientEyeAngle[targetId];
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSavePos received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSetPos(int client, int args)
{
    if (args != 3 && args != 5) {
        PrintToConsole(client, "smSetPos requires 3 or 5 args");
        return Plugin_Handled;
    }

    char arg[128];
    for (int i = 1; i <= args; i++) {
        GetCmdArg(i, arg, sizeof(arg));
        if (i <= 3) {
            savePos[i-1] = StringToFloat(arg);
         }
         else {
            saveAngle[i-4] = StringToFloat(arg);
         }
    }

    // default angle values
    if (args != 5) {
        saveAngle[0] = 0.0;
        saveAngle[1] = 0.0;
    }
    return Plugin_Handled;
}

public Action smGetPos(int client, int args)
{
    PrintToConsole(client, "savedPos (%f, %f, %f) (%f, %f)", savePos[0], savePos[1], savePos[2], saveAngle[0], saveAngle[1]);
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

    //float zeroVec[3] = {0.0, 0.0, 0.0};

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        clientTeleportedSinceLastInput[targetId] = true;
        clientEyeAngle[targetId] = saveAngle;
        TeleportEntity(targetId, savePos, saveAngle, NULL_VECTOR);
        return Plugin_Handled;
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
                SDKHooks_TakeDamage(target, 0, 0, 450.0);
            }
        }
    }
    return Plugin_Handled;
}

public Action smSetArmor(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smSetArmor requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], armorArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, armorArg, sizeof(armorArg));
    int armorValue = StringToInt(armorArg);

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        SetEntProp(targetId, Prop_Data, "m_ArmorValue", armorValue);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSetArmor received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSetHealth(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smSetHealth requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], healthArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, healthArg, sizeof(healthArg));
    int healthValue = StringToInt(healthArg);

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        SetEntProp(targetId, Prop_Data, "m_iHealth", healthValue);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSetHealth received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smRotate(int client, int args)
{
    if (args != 3) {
        PrintToConsole(client, "smRotate requires 3 args");
        return Plugin_Handled;
    }

    char nameArg[128], yawArg[128], pitchArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, pitchArg, sizeof(pitchArg));
    GetCmdArg(3, yawArg, sizeof(yawArg));
    float newAngles[3];
    newAngles[0] = StringToFloat(pitchArg);
    newAngles[1] = StringToFloat(yawArg);
    newAngles[2] = 0.0;

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        TeleportEntity(targetId, NULL_VECTOR, newAngles, NULL_VECTOR);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smRotate received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smGiveItem(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smGiveItem requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], itemArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, itemArg, sizeof(itemArg));

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        GivePlayerItem(targetId, itemArg);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smGiveItem received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smRemoveGuns(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smRemoveGuns requires 1 arg");
        return Plugin_Handled;
    }

    char nameArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        int rifleId = GetRifleEntityId(targetId);
        if (rifleId != -1) {
            RemovePlayerItem(targetId, rifleId);
        }
        int pistolId = GetPistolEntityId(targetId);
        if (pistolId != -1) {
            RemovePlayerItem(targetId, pistolId);
        }
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smRemoveGuns received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSetCurrentItem(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smSetCurrentItem requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], itemArg[128], consoleCmd[150];
    consoleCmd = "use ";
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, itemArg, sizeof(itemArg));
    StrCat(consoleCmd, sizeof(consoleCmd), itemArg);

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        FakeClientCommand(targetId, consoleCmd);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSetCurrentItem received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSpecPlayerToTarget(int client, int args)
{
    if (args != 2 && args != 3) {
        PrintToConsole(client, "smSpecPlayerToTarget requires 2 or 3 args");
        return Plugin_Handled;
    }

    char playerArg[128], targetArg[128], consoleCmd[150];
    bool thirdPerson = args == 3;
    consoleCmd = "spec_player ";
    // arg 0 is the command
    GetCmdArg(1, playerArg, sizeof(playerArg));
    GetCmdArg(2, targetArg, sizeof(targetArg));
    StrCat(consoleCmd, sizeof(consoleCmd), targetArg);

    int playerId = GetClientIdByName(playerArg);
    if (playerId != -1) {
        ChangeClientTeam(playerId, CS_TEAM_SPECTATOR);
        ForcePlayerSuicide(playerId);
        FakeClientCommand(playerId, "spec_goto 0 0 0 0 0");
        FakeClientCommand(playerId, consoleCmd);
        if (thirdPerson) {
            FakeClientCommand(playerId, "spec_mode");
        }
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSpecPlayerToTarget received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSpecGoto(int client, int args)
{
    if (args != 6) {
        PrintToConsole(client, "smSpecGoto requires 6 args");
        return Plugin_Handled;
    }

    char playerArg[128], origX[128], origY[128], origZ[128], pitch[128], yaw[128];
    // arg 0 is the command
    GetCmdArg(1, playerArg, sizeof(playerArg));
    GetCmdArg(2, origX, sizeof(origX));
    GetCmdArg(3, origY, sizeof(origY));
    GetCmdArg(4, origZ, sizeof(origZ));
    GetCmdArg(5, pitch, sizeof(pitch));
    GetCmdArg(6, yaw, sizeof(yaw));

    int playerId = GetClientIdByName(playerArg);
    if (playerId != -1) {
        ChangeClientTeam(playerId, CS_TEAM_SPECTATOR);
        ForcePlayerSuicide(playerId);
        FakeClientCommand(playerId, "spec_goto %s %s %s %s %s", origX, origY, origZ, pitch, yaw);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSpecGoto received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smFakeCmd(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smFakeCmd requires 2 args");
        return Plugin_Handled;
    }

    char arg[128], cmd[128];
    // arg 0 is the command
    GetCmdArg(1, arg, sizeof(arg));
    GetCmdArg(2, cmd, sizeof(cmd));

    //float zeroVec[3] = {0.0, 0.0, 0.0};

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        FakeClientCommand(targetId, cmd);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smFakeCmd received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smLine(int client, int args) {
    drawLine = !drawLine;
    return Plugin_Handled;
}

// this function is only safe to access global variables because code is single threaded
public Action DrawAllClients(Handle timer) {
    if (drawLine) {
        for (int target = 1; target <= MaxClients; target++) {
            if (IsValidClient(target) && IsPlayerAlive(target)) {
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
    }
    return Plugin_Handled;
}

void TE_SendBeam(float m_vecMins[3], float m_vecMaxs[3], int color[4], float flDur = 0.1)
{
	TE_SetupBeamPoints(m_vecMins, m_vecMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToAll();
}

public Action smRefresh(int client, int args) {
    ServerCommand("sm plugins unload link; sm plugins load link");
    return Plugin_Handled;
}
