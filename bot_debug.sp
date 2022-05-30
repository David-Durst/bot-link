float savePos[3];
public void RegisterDebugFunctions() 
{
    RegConsoleCmd("sm_savePos", smSavePos, "<player name> - save the position of the named player to place a player in");
    RegConsoleCmd("sm_setPos", smSetPos, "<x> <y> <z> - set a position to place a bot in");
    RegConsoleCmd("sm_getPos", smGetPos, "- get the current a position to place a bot in");
    RegConsoleCmd("sm_teleport", smTeleport, "<player name> - teleport the named player to the saved pos");
    RegConsoleCmd("sm_slayAllBut", smSlayAllBut, "<player name 0> ... - slay all but the listed players");
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

    float noVel[3];
    noVel[0] = 0.0;
    noVel[1] = 0.0;
    noVel[2] = 0.0;

    // https://wiki.alliedmods.net/Clients_(SourceMod_Scripting) - first client is 1, server is 0
    for (int target = 1; target <= MaxClients; target++) {
        if (IsValidClient(target)) {
            char targetName[128];
            GetClientName(target, targetName, 128);
            if (StrEqual(arg, targetName, false)) {
                TeleportEntity(client, savePos, NULL_VECTOR, noVel);
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
