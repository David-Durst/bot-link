#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
//#include <dhooks>

public Plugin myinfo =
{
    name = "Durst Bot Training",
    author = "David Durst",
    description = "Setup training for bots.",
    version = "1.0",
    url = "https://davidbdurst.com/"
};

int roundNumber;
float roundTimeSeconds = 20.0;
ConVar cvarBotStop, cvarBotChatter, cvarInfAmmo;
 
public void OnPluginStart() {
    roundNumber = 0;

    cvarBotStop = FindConVar("bot_stop");
    cvarBotChatter = FindConVar("bot_chatter");
    cvarInfAmmo = FindConVar("sv_infinite_ammo");

    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);

    PrintToServer("loaded bot training 1.0");
}

public OnMapStart() {
    roundNumber = 0;
    SetConVarInt(cvarBotStop, 1, true, true);
    SetConVarString(cvarBotChatter, "off", true, true);
    SetConVarInt(cvarInfAmmo, 1, true, true);
}

public Action OnRoundStart(Event event, const char[] sName, bool bDontBroadcast) {
    roundNumber++;
    CreateTimer(roundTimeSeconds, Timer_EndRound, roundNumber);
    return Plugin_Continue;
}

public Action Timer_EndRound(Handle timer, int fireRoundNumber)
{
    if (roundNumber == fireRoundNumber) {
        CS_TerminateRound(0.0, CSRoundEnd_Draw, false);
    }
}

