bool clientPush5s[MAXPLAYERS+1];
bool clientPush10s[MAXPLAYERS+1];
bool clientPush20s[MAXPLAYERS+1];
bool pushRound, enableAggressionControl;
float temperature;

public void RegisterAggressionFunctions() 
{
    RegConsoleCmd("sm_setBotPush", smSetBotPush, "<player name> <1/0 push 5s> <1/0 push 10s> <1/0 push 20s> - set aggression for one player (or * for all players)");
    RegConsoleCmd("sm_setBotPushRound", smSetBotPushRound, "<1/0 push round> - set push round for all bots")
    RegConsoleCmd("sm_setAggressionControl", smSetAggressionControl, "<1/0 enable aggression control> - enable/disable entire aggression control");
    RegConsoleCmd("sm_setTemperature", smSetTemperature, "<0. to 1.> - set softmax temperature");
    RegConsoleCmd("sm_printAggressionControl", smPrintAggressionControl, " - print aggression status");

    for (int i = 0; i < MAXPLAYERS+1; i++) {
        clientPush5s[i] = true;
        clientPush10s[i] = true;
        clientPush20s[i] = true;
    }
    pushRound = true;
    enableAggressionControl = true;
    temperature = 0.7;
}

File botAggressionFile;
static char botAggressionFilePath[] = "addons/sourcemod/bot-link-data/bot_aggression_config_file.txt";
bool botAggressionOpen = false;
stock void WriteBotAggression() {
    if (botAggressionOpen) {
        botAggressionFile.Close();
        botAggressionOpen = false;
    }
    botAggressionFile = OpenFile(botAggressionFilePath, "w", false, "");
    botAggressionOpen = true;
    if (botAggressionFile == null) {
        PrintToServer("opening botAggressionFile returned null");
        return;
    }

    botAggressionFile.WriteLine("%i,%i,%f", pushRound, enableAggressionControl, temperature);
    for (int i = 0; i < MAXPLAYERS+1; i++) {
        botAggressionFile.WriteLine("%i,%i,%i,%i", i, clientPush5s[i], clientPush10s[i], clientPush20s[i]);
    }


    botAggressionFile.Close();
    botAggressionOpen = false;
}

stock void ReadBotAggression() {
    if (botAggressionOpen) {
        botAggressionFile.Close();
        botAggressionOpen = false;
    }

    if (FileExists(botAggressionFilePath)) {
        botAggressionFile = OpenFile(botAggressionFilePath, "r", false, "");
        botAggressionOpen = true;
        botAggressionFile.ReadLine(internalBotAggression, MAX_BOT_AGGRESSION_LENGTH);
        TrimString(internalBotAggression);
        ExplodeString(internalBotAggression, ",", botAggressionExploded, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
        pushRound = StringToInt(botAggressionExploded[0]) == 1;
        enableAggressionControl = StringToInt(botAggressionExploded[1]) == 1;
        temperature = StringToFloat(botAggressionExploded[2]);


        for (int client = 0; client < MAXPLAYERS+1; client++) {
            botAggressionFile.ReadLine(internalBotAggression, MAX_BOT_AGGRESSION_LENGTH);
            //PrintToServer("line %i / %i: %s", client, MAXPLAYERS+1, internalBotAggression);
            TrimString(internalBotAggression);
            ExplodeString(internalBotAggression, ",", botAggressionExploded, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            clientPush5s[client] = StringToInt(botAggressionExploded[1]) == 1;
            clientPush10s[client] = StringToInt(botAggressionExploded[2]) == 1;
            clientPush20s[client] = StringToInt(botAggressionExploded[3]) == 1;
        }

        botAggressionFile.Close();
        botAggressionOpen = false;
    }
}

stock void internalSetBotPush(int targetId, bool push5s, bool push10s, bool push20s) 
{
    clientPush5s[targetId] = push5s;
    clientPush10s[targetId] = push10s;
    clientPush20s[targetId] = push20s;
}

public Action smSetBotPush(int client, int args)
{
    if (args != 4) {
        PrintToConsole(client, "smSetBothPush requires 4 args");
        return Plugin_Handled;
    }

    char playerArg[128], otherArg[128];
    // arg 0 is the command
    GetCmdArg(1, playerArg, sizeof(playerArg));

    GetCmdArg(2, otherArg, sizeof(otherArg));
    bool push5s = StringToInt(otherArg) == 1;
    GetCmdArg(3, otherArg, sizeof(otherArg));
    bool push10s = StringToInt(otherArg) == 1;
    GetCmdArg(4, otherArg, sizeof(otherArg));
    bool push20s = StringToInt(otherArg) == 1;

    if (StrEqual(playerArg, "*")) {
        for (int targetId = 1; targetId <= MaxClients; targetId++) {
            if (IsValidClient(targetId) && IsPlayerAlive(targetId)) {
                internalSetBotPush(targetId, push5s, push10s, push20s);
            }
        }
        WriteBotAggression();
        return Plugin_Handled;
    }
    else {
        int targetId = GetClientIdByName(playerArg);
        if (targetId != -1) {
            internalSetBotPush(targetId, push5s, push10s, push20s);
            WriteBotAggression();
            return Plugin_Handled;
        }
            
        PrintToConsole(client, "smSetBotPush received player name that didnt match any valid clients");
        return Plugin_Handled;
    }
}

public Action smSetBotPushRound(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSetBothPushRound requires 1 arg");
        return Plugin_Handled;
    }

    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    pushRound = StringToInt(arg) == 1;
    WriteBotAggression();
    return Plugin_Handled;
}

public Action smSetAggressionControl(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSetAggressionControl requires 1 arg");
        return Plugin_Handled;
    }

    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    enableAggressionControl = StringToInt(arg) == 1;
    WriteBotAggression();
    return Plugin_Handled;
}

public Action smSetTemperature(int client, int args)
{
    if (args != 1) {
        PrintToConsole(client, "smSetTemperature requires 1 arg");
        return Plugin_Handled;
    }

    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    temperature = StringToFloat(arg);
    WriteBotAggression();
    return Plugin_Handled;
}

public Action smPrintAggressionControl(int client, int args)
{
    if (args != 0) {
        PrintToConsole(client, "smPrintAggressionControl requires 0 arg");
        return Plugin_Handled;
    }

    PrintToConsole(client, "PushRound: %d, EnableAggressionControl %d, Temperature %f", pushRound, enableAggressionControl, temperature);
    for (int targetId = 1; targetId <= MaxClients; targetId++) {
        if (IsValidClient(targetId) && IsPlayerAlive(targetId)) {
            char targetName[128];
            GetClientName(targetId, targetName, 128);
            PrintToConsole(client, "%s push5s: %d, push10s: %d, push20s: %d", 
                targetName, clientPush5s[targetId], clientPush10s[targetId], clientPush20s[targetId]);
        }
    }

    return Plugin_Handled;
}
