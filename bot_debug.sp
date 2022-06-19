static int g_iLaserMaterial, g_iHaloMaterial;
float savePos[3];
bool drawLine;
public void RegisterDebugFunctions() 
{
    RegConsoleCmd("sm_savePos", smSavePos, "<player name> - save the position of the named player to place a player in");
    RegConsoleCmd("sm_setPos", smSetPos, "<x> <y> <z> - set a position to place a bot in");
    RegConsoleCmd("sm_getPos", smGetPos, "- get the current a position to place a bot in");
    RegConsoleCmd("sm_teleport", smTeleport, "<player name> - teleport the named player to the saved pos");
    RegConsoleCmd("sm_slayAllBut", smSlayAllBut, "<player name 0> ... - slay all but the listed players");
    RegConsoleCmd("sm_setArmor", smSetArmor, "<player name> <armor> - set a players armor value");
    RegConsoleCmd("sm_setHealth", smSetHealth, "<player name> <armor> - set a players health value");
    RegConsoleCmd("sm_rotate", smRotate, "<player name> <yaw> <pitch> - rotate the named player to yaw and pitch values");
    RegConsoleCmd("sm_giveItem", smGiveItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_setCurrentItem", smSetCurrentItem, "<player name> <item name> - give the item to the player");
    RegConsoleCmd("sm_line", smLine, "- draw line in direction player is trying to move");
    g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
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
        return Plugin_Handled;
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

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        TeleportEntity(target, savePos, zeroVec, zeroVec);
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
                SDKHooks_TakeDamage(target, client, client, 450.0);
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

    int targetId = GetClientIdByName(arg);
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

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        SetEntProp(targetId, Prop_Data, "m_iHealth", heatlhValue);
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
    GetCmdArg(2, yawArg, sizeof(yawArg));
    GetCmdArg(3, pitchArg, sizeof(pitchArg));
    float newAngles[3];
    newAngles[0] = StringToFloat(yawArg);
    newAngles[1] = StringToFloat(pitchArg);
    newAngles[2] = 0;

    int targetId = GetClientIdByName(arg);
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

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {
        GivePlayerItem(targetId, itemArg);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smGiveItem received player name that didnt match any valid clients");
    return Plugin_Handled;
}

public Action smSetCurrentItem(int client, int args)
{
    if (args != 2) {
        PrintToConsole(client, "smSetCurrentItem requires 2 args");
        return Plugin_Handled;
    }

    char nameArg[128], itemArg[128];
    // arg 0 is the command
    GetCmdArg(1, nameArg, sizeof(nameArg));
    GetCmdArg(2, itemArg, sizeof(itemArg));

    int targetId = GetClientIdByName(arg);
    if (targetId != -1) {

        // see grenade_status.sp for source of this code
        int entindex = CreateEntityByName();
        
        if (entindex == -1) {
            PrintToConsole(client, "smSetCurrentItem received invalid item name");
            return Plugin_Handled;
        }

        DispatchSpawn(entindex);
        int itemIndex = GetEntProp(entindex, Prop_Send, "m_iItemDefinitionIndex");
        AcceptEntityInput(entindex, "Kill");
        
        SetEntPropEnt(targetId, Prop_Send, "m_hActiveWeapon", itemIndex);
        return Plugin_Handled;
    }
        
    PrintToConsole(client, "smSetCurrentItem received player name that didnt match any valid clients");
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
