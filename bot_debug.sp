int g_iLaserMaterial, g_iHaloMaterial, g_iWhiteMaterial;
float savePos[3], saveAngle[3];
bool drawLine;
public void RegisterDebugFunctions() 
{
    RegConsoleCmd("sm_savePos", smSavePos, "<player name> - save the position of the named player to place a player in");
    RegConsoleCmd("sm_setPos", smSetPos, "<x> <y> <z> <pitch> <yaw> - set a position to place a bot in (pitch/yaw optional)");
    RegConsoleCmd("sm_getPos", smGetPos, "- get the current a position to place a bot in");
    RegConsoleCmd("sm_teleport", smTeleport, "<player name> - teleport the named player to the saved pos");
    RegConsoleCmd("sm_teleportPlantedC4", smTeleportPlantedC4, " - teleport the planted C4 to the saved pos");
    RegConsoleCmd("sm_slayAllBut", smSlayAllBut, "<player name 0> ... - slay all but the listed players");
    RegConsoleCmd("sm_setArmor", smSetArmor, "<player name> <armor> - set a players armor value");
    RegConsoleCmd("sm_setHelmet", smSetHelmet, "<player name> <1/0> - set a players helmet status");
    RegConsoleCmd("sm_setHealth", smSetHealth, "<player name> <health> - set a players health value");
    RegConsoleCmd("sm_damageActive", smDamageActive, "<attacker player name> <victim player name> - damage victim with attacker using their current weapon");
    RegConsoleCmd("sm_rotate", smRotate, "<player name> <pitch> <yaw> - rotate the named player to pitch yaw values");
    RegConsoleCmd("sm_giveItem", smGiveItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_removeGuns", smRemoveGuns, "<player name> - remove a players guns");
    RegConsoleCmd("sm_setCurrentItem", smSetCurrentItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_specPlayerToTarget", smSpecPlayerToTarget, "<player name> <target name> <thirdPerson=f> - make player spectate a target (thirdPerson default false, any value is true)");
    RegConsoleCmd("sm_specGoto", smSpecGoto, "<player name> <orig x> <orig y> <orig z> <pitch> <yaw> - spectate camera in absolute position");
    RegConsoleCmd("sm_allHumansSpec", smAllHumansSpec, "<num non-spectators=0> - force all humans after first n to spectator team");
    RegConsoleCmd("sm_fakeCmd", smFakeCmd, "<player name> <fake cmd> - do fake client cmd for player");
    RegConsoleCmd("sm_line", smLine, "- draw line in direction player is trying to move");
    RegConsoleCmd("sm_drawAABBRadius", smDrawAABBRadius, "<duration_seconds> <x> <y> <z> <radius> <z radius>  - draw AABB with fixed radius");
    RegConsoleCmd("sm_drawAABB", smDrawAABB, "<duration_seconds> <x0> <y0> <z0> <x1> <y1> <z1> - draw AABB");
    RegConsoleCmd("sm_drawCollisionAABBs", smDrawCollisionAABBs, "<player name> - draw AABBs for player collision areas");
    RegConsoleCmd("sm_refresh", smRefresh, "- reload the plugin");
    RegConsoleCmd("sm_setMaxRounds", smSetMaxRounds, "<max_rounds> - set max rounds");
    RegConsoleCmd("sm_setBotStop", smSetBotStop, "<bot_stop> - set bot stop");
    RegConsoleCmd("sm_endGame", smEndGame, "- end the game immediately");
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
    if (args != 0 && args != 1) {
        PrintToConsole(client, "smSavePos requires 0 or 1 arg");
        return Plugin_Handled;
    }

    int targetId;
    if (args == 1) {
        char arg[128];
        // arg 0 is the command
        GetCmdArg(1, arg, sizeof(arg));

        targetId = GetClientIdByName(arg);
    }
    else {
        targetId = client;
    }

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

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        teleportInternal(targetId);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smTeleport received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smTeleportPlantedC4(int client, int args)
{
    if (args != 0) {
        PrintToConsole(client, "smTeleportC4 requires 0 arg");
        return Plugin_Handled;
    }

    int c4Ent = -1;
    c4Ent = FindEntityByClassname(c4Ent, "planted_c4"); 
    bool isPlanted = c4Ent != -1;

    if (isPlanted) {
        teleportInternal(c4Ent);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smTeleportPlantedC4 didnt find planted c4");
    return Plugin_Handled;
}

void teleportInternal(int targetId)
{
    if (targetId <= MAXPLAYERS) {
        PrintToServer("teleport");
        clientLastTeleportId[targetId]++;
        clientEyeAngle[targetId] = saveAngle;
    }
    TeleportEntity(targetId, savePos, saveAngle, NULL_VECTOR);
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

public Action smSetHelmet(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smSetHelmet requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], helmetArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, helmetArg, sizeof(helmetArg));
    int helmetValue = StringToInt(helmetArg);

    int targetId = GetClientIdByName(nameArg);
    if (targetId != -1) {
        SetEntProp(targetId, Prop_Send, "m_bHasHelmet", helmetValue);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSetHelmet received player name that didnt match any valid clients");
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

public Action smDamageActive(int client, int args) 
{
    if (args != 2) {
        PrintToConsole(client, "smDamage requires 2 args");
        return Plugin_Handled;
    }

    char attackerNameArg[128], victimNameArg[128];
    // arg 0 is the command
    GetCmdArg(1, attackerNameArg, sizeof(attackerNameArg));
    GetCmdArg(2, victimNameArg, sizeof(victimNameArg));

    int attackerId = GetClientIdByName(attackerNameArg);
    int victimId = GetClientIdByName(victimNameArg);
    if (attackerId != -1 && victimId != -1) {
        int activeWeaponEntityId = GetActiveWeaponEntityId(attackerId);
        int activeWeaponId = -1;
        if (activeWeaponEntityId != -1) {
            activeWeaponId = GetWeaponIdFromEntityId(activeWeaponEntityId);
        }
        SDKHooks_TakeDamage(victimId, activeWeaponEntityId, attackerId, 1.0, DMG_BULLET, activeWeaponId);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smDamageActive received attacker or victim player name that didnt match any valid clients");
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

public Action smAllHumansSpec(int client, int args)
{
    if (args != 0 && args != 1) {
        PrintToConsole(client, "smAllHumansSpec requires 0 or 1 args");
        return Plugin_Handled;
    }

    int numNonSpectators = 0;
    if (args == 1) {
        char arg[128];
        // arg 0 is the command
        GetCmdArg(1, arg, sizeof(arg));
        numNonSpectators = StringToInt(arg);
    }

    int numHumans = 0;
    for (int clientInner = 1; clientInner <= MaxClients; clientInner++) {
        if (IsValidClient(clientInner) && !IsFakeClient(clientInner)) {
            if (numHumans >= numNonSpectators) {
                ChangeClientTeam(clientInner, CS_TEAM_SPECTATOR);
                ForcePlayerSuicide(clientInner);
            }
            else {
                ChangeClientTeam(clientInner, CS_TEAM_T);
                ForcePlayerSuicide(clientInner);
            }
            numHumans++;
        }
    }
        
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

stock void Vec3Assign(float dstVec[3], float x, float y, float z) {
    dstVec[0] = x;
    dstVec[1] = y;
    dstVec[2] = z;
}

public Action smDrawAABBRadius(int client, int args) {
    if (args != 0 && args != 1 && args != 5 && args != 6) {
        PrintToConsole(client, "smDrawAABBRadius requires 0 or 1 or 5 or 6 args");
        return Plugin_Handled;
    }
    char floatArg[128];
    float duration, radius, zRadius;
    // first is mins, second is maxs, will sort after loading
    float vals[2][3];
    if (args > 1) {
        // arg 0 is the command
        GetCmdArg(1, floatArg, sizeof(floatArg));
        duration = StringToFloat(floatArg);
        for (int i = 0; i < 3; i++) {
            GetCmdArg(2 + i, floatArg, sizeof(floatArg));
            vals[0][i] = StringToFloat(floatArg);
            vals[1][i] = StringToFloat(floatArg);
        }
        GetCmdArg(5, floatArg, sizeof(floatArg));
        radius = StringToFloat(floatArg);
        if (args == 5) {
            zRadius = radius;
        }
        else {
            GetCmdArg(6, floatArg, sizeof(floatArg));
            zRadius = StringToFloat(floatArg);
        }
    }
    else {
        duration = 5.0;
        if (args != 1) {
            radius = 32.0;
            zRadius = 32.0;
        }
        else {
            GetCmdArg(1, floatArg, sizeof(floatArg));
            radius = StringToFloat(floatArg);
            zRadius = radius;
        }
        vals[0] = savePos;
        vals[1] = savePos;
    }
    vals[0][0] -= radius;
    vals[0][1] -= radius;
    vals[0][2] -= zRadius;
    vals[1][0] += radius;
    vals[1][1] += radius;
    vals[1][2] += zRadius;
    drawAABBsThroughWalls(client, duration, vals);
    return Plugin_Handled;
}

public Action smDrawAABB(int client, int args) {
    if (args != 7) {
        PrintToConsole(client, "smDrawAABB requires 7 args");
        return Plugin_Handled;
    }

    char floatArg[128];
    float duration;
    // first is mins, second is maxs, will sort after loading
    float vals[2][3];
    // arg 0 is the command
    GetCmdArg(1, floatArg, sizeof(floatArg));
    duration = StringToFloat(floatArg);
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 3; j++) {
            GetCmdArg(2 + i*3 + j, floatArg, sizeof(floatArg));
            vals[i][j] = StringToFloat(floatArg);
        }
    }
    drawAABBsThroughWalls(client, duration, vals);
    return Plugin_Handled;
}

bool checkInsideUsingEachDimension(float mins[3], float maxs[3]) {
    float valid[3];
    if (!TR_PointOutsideWorld(mins)) {
        valid = mins;
    }
    else if (!TR_PointOutsideWorld(maxs)) {
        valid = maxs;
    }
    else {
        for (int i = 0; i < 3; i++) {
            valid[i] = (mins[i] + maxs[i]) / 2.0;
        }
        if (TR_PointOutsideWorld(valid)) {
            return false;
        }
    }
    for (int i = 0; i < 3; i++) {
        float minOneDimOnly[3], maxOneDimOnly[3];
        minOneDimOnly = valid;
        minOneDimOnly[i] = mins[i];
        maxOneDimOnly = valid;
        maxOneDimOnly[i] = maxs[i];
        makeInsideWorld(valid, minOneDimOnly);
        mins[i] = minOneDimOnly[i];
        makeInsideWorld(valid, maxOneDimOnly);
        maxs[i] = maxOneDimOnly[i];
    }
    return true;
}

void makeInsideWorld(float valid[3], float point[3]) {
    // make sure dont infinite loop if valid check goes wrong
    bool equalDims[3] = {false, false, false};
    while (TR_PointOutsideWorld(point) && !(equalDims[0] && equalDims[1] && equalDims[2])) {
        PrintToServer("Point (%f, %f, %f)", point[0], point[1], point[2]);
        // if out of bounds, shrink in all dimensions towards valid
        for (int i = 0; i < 3; i++) {
            if (FloatAbs(valid[i] - point[i]) > 1.0) {
                if (valid[i] > point[i]) {
                    point[i] += 0.5;
                }
                else {
                    point[i] -= 0.5;
                }
            }
            else {
                equalDims[i] = true;
            }
        }
    }
    
}

void drawAABBsThroughWalls(int client, float duration, float vals[2][3]) {
    for (int i = 0; i < 3; i++) {
        float tmpMin = fmin(vals[0][i], vals[1][i]);
        vals[1][i] = fmax(vals[0][i], vals[1][i]);
        vals[0][i] = tmpMin;
    }

    float mins[3], maxs[3];
    mins = vals[0];
    maxs = vals[1];
    int color[4] = {255, 0, 0, 255};

    float tmpMins[3], tmpMaxs[3];
    tmpMins = mins;
    tmpMaxs = maxs;
    if (!checkInsideUsingEachDimension(tmpMins, tmpMaxs)) {
        PrintToConsole(client, "min, max, and center not valid, so not drawing an AABB");
        return;
    }
    //PrintToConsole(client, "drawing (%f, %f, %f) to (%f, %f, %f)", tmpMaxs[0], tmpMaxs[1], tmpMaxs[2], tmpMins[0], tmpMins[1], tmpMins[2]);
    drawAABBInternal(tmpMins, tmpMaxs, color, duration);
}

void drawAABBInternal(float mins[3], float maxs[3], int color[4], float duration) {
    // from min point
    float tmpSrc[3], tmpDst[3];
    Vec3Assign(tmpSrc,  mins[0], mins[1], mins[2]);
    Vec3Assign(tmpDst, maxs[0], mins[1], mins[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, mins[0], mins[1], mins[2]);
    Vec3Assign(tmpDst, mins[0], maxs[1], mins[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, mins[0], mins[1], mins[2]);
    Vec3Assign(tmpDst, mins[0], mins[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);

    // reverse from max point
    Vec3Assign(tmpSrc, maxs[0], maxs[1], maxs[2]);
    Vec3Assign(tmpDst, mins[0], maxs[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, maxs[0], maxs[1], maxs[2]);
    Vec3Assign(tmpDst, maxs[0], mins[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, maxs[0], maxs[1], maxs[2]);
    Vec3Assign(tmpDst, maxs[0], maxs[1], mins[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);

    // from corners above/below min/max point
    Vec3Assign(tmpSrc, mins[0], mins[1], maxs[2]);
    Vec3Assign(tmpDst, mins[0], maxs[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, mins[0], mins[1], maxs[2]);
    Vec3Assign(tmpDst, maxs[0], mins[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, maxs[0], maxs[1], mins[2]);
    Vec3Assign(tmpDst, maxs[0], mins[1], mins[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, maxs[0], maxs[1], mins[2]);
    Vec3Assign(tmpDst, mins[0], maxs[1], mins[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);

    // vertical bars not connected to max or min points
    Vec3Assign(tmpSrc, maxs[0], mins[1], mins[2]);
    Vec3Assign(tmpDst, maxs[0], mins[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
    Vec3Assign(tmpSrc, mins[0], maxs[1], mins[2]);
    Vec3Assign(tmpDst, mins[0], maxs[1], maxs[2]);
    TE_SendBeam(tmpSrc, tmpDst, color, duration);
}

stock void toStringPropFieldType(char typeString[100], PropFieldType type) {
    switch(type)
    {
        case PropField_Unsupported:
        {  
            typeString = "unsupported";
        }
        case PropField_Integer:
        {  
            typeString = "integer";
        }
        case PropField_Float:
        {  
            typeString = "float";
        }
        case PropField_Entity:
        {  
            typeString = "entity";
        }
        case PropField_Vector:
        {  
            typeString = "vector";
        }
        case PropField_String:
        {  
            typeString = "string";
        }
        case PropField_String_T:
        {  
            typeString = "string_t";
        }
        case PropField_Variant:
        {  
            typeString = "variant";
        }
        default:
        {  
            typeString = "no_match";
        }
    }
}

public Action smDrawCollisionAABBs(int client, int args)
{
    if (args != 0 && args != 1) {
        PrintToConsole(client, "smDrawCollisionAABBs requires 0 or 1 arg");
        return Plugin_Handled;
    }

    int targetId;
    if (args == 1) {
        char arg[128];
        // arg 0 is the command
        GetCmdArg(1, arg, sizeof(arg));

        targetId = GetClientIdByName(arg);
    }
    else {
        targetId = client;
    }

    if (targetId != -1) {
        char className[128];
        bool res = GetEntityNetClass(targetId, className, 128);
        if (res) {
            PrintToConsole(client, "classname: %s", className);
        }
        else {
            PrintToConsole(client, "no classname");
        }
        res = HasEntProp(targetId, Prop_Send, "m_Collision");
        if (res) {
            PrintToConsole(client, "has collision");
        }
        else {
            PrintToConsole(client, "no collision");
        }
        int resi = GetEntPropArraySize(targetId, Prop_Send, "m_Collision");
        PrintToConsole(client, "collision size: %i", resi);
        //res = HasEntProp(targetId, Prop_Send, "m_Collision[0]");
        PropFieldType type;
        int num_bits;
        int local_offset;
        int array_size;

        int global_offset;
        global_offset = FindSendPropInfo(className, "m_Collision", type, num_bits, local_offset, array_size);
        if (global_offset >= 0) {
            char typeString[100];
            toStringPropFieldType(typeString, type);
            PrintToConsole(client, "has collision global offset %i type %s num_bits %i local_offset %i array_size %i", global_offset, typeString, num_bits, local_offset, array_size);
        }
        else {
            PrintToConsole(client, "no collision");
        }

        global_offset = FindSendPropInfo(className, "m_vecMins", type, num_bits, local_offset, array_size);
        if (global_offset >= 0) {
            char typeString[100];
            toStringPropFieldType(typeString, type);
            PrintToConsole(client, "has vecMins global offset %i type %s num_bits %i local_offset %i array_size %i", global_offset, typeString, num_bits, local_offset, array_size);
            float vecMins[3];
            GetEntPropVector(client, Prop_Send, "m_vecMins", vecMins);
            PrintToConsole(client, "vecMins (%f, %f, %f)", vecMins[0], vecMins[1], vecMins[2]);
        }
        else {
            PrintToConsole(client, "no vecMins");
        }

        global_offset = FindSendPropInfo(className, "m_vecMaxs", type, num_bits, local_offset, array_size);
        if (global_offset >= 0) {
            char typeString[100];
            toStringPropFieldType(typeString, type);
            PrintToConsole(client, "has vecMaxs global offset %i type %s num_bits %i local_offset %i array_size %i", global_offset, typeString, num_bits, local_offset, array_size);
            float vecMaxs[3];
            GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMaxs);
            PrintToConsole(client, "vecMaxs (%f, %f, %f)", vecMaxs[0], vecMaxs[1], vecMaxs[2]);
        }
        else {
            PrintToConsole(client, "no vecMaxs");
        }
            
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smDrawCollisionAABBs received player name that didnt match any valid clients");
    return Plugin_Handled;
}

void TE_SendBeam(float src[3], float dst[3], int color[4], float flDur = 0.1)
{
	TE_SetupBeamPoints(src, dst, g_iLaserMaterial, g_iHaloMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToAll();
}

public Action smRefresh(int client, int args) {
    ServerCommand("sm plugins unload link; sm plugins load link");
    return Plugin_Handled;
}

File maxRoundsFile;
static char maxRoundsFilePath[] = "addons/sourcemod/bot-link-data/max_rounds_config_file.txt";
bool maxRoundsOpen = false;
stock void WriteMaxRounds() {
    if (maxRoundsOpen) {
        maxRoundsFile.Close();
        maxRoundsOpen = false;
    }
    maxRoundsFile = OpenFile(maxRoundsFilePath, "w", false, "");
    maxRoundsOpen = true;
    if (maxRoundsFile == null) {
        PrintToServer("opening maxRoundsFile returned null");
        return;
    }

    maxRoundsFile.WriteLine("%i", internalMaxRounds);

    maxRoundsFile.Close();
    maxRoundsOpen = false;
}

char debugInputBuffer[MAX_INPUT_LENGTH];

stock void ReadMaxRounds() {
    if (maxRoundsOpen) {
        maxRoundsFile.Close();
        maxRoundsOpen = false;
    }

    if (FileExists(maxRoundsFilePath)) {
        maxRoundsFile = OpenFile(maxRoundsFilePath, "r", false, "");
        maxRoundsOpen = true;
        maxRoundsFile.ReadLine(debugInputBuffer, MAX_INPUT_LENGTH);
        TrimString(debugInputBuffer);
        internalMaxRounds = StringToInt(debugInputBuffer);
        maxRoundsFile.Close();
        maxRoundsOpen = false;
    }
}

public Action smSetMaxRounds(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSetMaxRounds requires 1 args");
        return Plugin_Handled;
    }

    char arg[128];
    // arg 0 is the command
    GetCmdArg(1, arg, sizeof(arg));
    internalMaxRounds = StringToInt(arg);
    WriteMaxRounds();
    SetConVarInt(cvarMaxRounds, internalMaxRounds, true, true);

    return Plugin_Handled;
}


File botStopFile;
static char botStopFilePath[] = "addons/sourcemod/bot-link-data/bot_stop_config_file.txt";
bool botStopOpen = false;
stock void WriteBotStop() {
    if (botStopOpen) {
        botStopFile.Close();
        botStopOpen = false;
    }
    botStopFile = OpenFile(botStopFilePath, "w", false, "");
    botStopOpen = true;
    if (botStopFile == null) {
        PrintToServer("opening botStopFile returned null");
        return;
    }

    botStopFile.WriteLine("%s", internalBotStop);

    botStopFile.Close();
    botStopOpen = false;
}

stock void ReadBotStop() {
    if (botStopOpen) {
        botStopFile.Close();
        botStopOpen = false;
    }

    if (FileExists(botStopFilePath)) {
        botStopFile = OpenFile(botStopFilePath, "r", false, "");
        botStopOpen = true;
        botStopFile.ReadLine(internalBotStop, MAX_BOT_STOP_LENGTH);
        TrimString(internalBotStop);
        if (StrEqual(internalBotStop, "1")) {
           stopT = true; 
           stopCT = true;
        }
        else if (StrEqual(internalBotStop, "t")) {
           stopT = true; 
           stopCT = false;
        }
        else if (StrEqual(internalBotStop, "ct")) {
           stopT = false; 
           stopCT = true;
        }
        else if (StrEqual(internalBotStop, "0")) {
           stopT = false; 
           stopCT = false;
        }
        else {
            PrintToServer("no match on bot stop %s", internalBotStop);
        }
        botStopFile.Close();
        botStopOpen = false;
    }
}

public Action smSetBotStop(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSetBotStop requires 1 args");
        return Plugin_Handled;
    }

    // arg 0 is the command
    GetCmdArg(1, internalBotStop, sizeof(internalBotStop));
    WriteBotStop();
    ReadBotStop();
    SetConVarString(cvarBotStop, internalBotStop, true, true);

    return Plugin_Handled;
}

// https://forums.alliedmods.net/showthread.php?t=82726
public Action smEndGame(int client, int args)
{
    //Routine by Tsunami to end the map
    new iGameEnd  = FindEntityByClassname(-1, "game_end");
    if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1) 
    {     
        LogError("Unable to create entity \"game_end\"!");
    } 
    else 
    {     
        AcceptEntityInput(iGameEnd, "EndGame");
    }
    return Plugin_Handled;
}
