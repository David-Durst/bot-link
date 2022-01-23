#include <sourcemod>
#include <sdktools>
 
public Plugin myinfo =
{
    name = "Durst Game Time Logger Plugin",
    author = "David Durst",
    description = "Log the current server time in the info every frame",
    version = "1.0",
    url = "https://davidbdurst.com/"
};
public OnGameFrame()
{
    int cur_tick = GetGameTickCount();
    SetHudTextParams(0.2, 0.2, 0.05, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i))
    {
        ShowHudText(i, 1, "Tick: %i", cur_tick);
    }
    }
}

bool g_walls_status;
public OnMapStart() 
{
    g_walls_status = false;
    RegAdminCmd("sm_togglewalls", Command_ToggleWalls, ADMFLAG_GENERIC);
    CreateTimer(0.1, WallsTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:WallsTimer(Handle:timer) 
{
    SetHudTextParams(0.2, 0.6, 1.0, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i))
        {
            if(g_walls_status) 
        {
                ShowHudText(i, 2, "Please enable walls\nr_drawothermodels 2\nr_drawparticles 0");
        }
        else
        {
                ShowHudText(i, 2, "Please disable walls\nr_drawothermodels 1\nr_drawparticles 1");
        }
        }
    }
    return Plugin_Handled;
}

public Action Command_ToggleWalls(int client, int args)
{
    g_walls_status = !g_walls_status;
    return Plugin_Handled;
}

/*
new Handle:r_drawOtherModels;
public void OnPluginStart()
{
    RegAdminCmd("sm_enablewalls", Command_EnableWalls, ADMFLAG_GENERIC);
    RegAdminCmd("sm_disablewalls", Command_DisableWalls, ADMFLAG_GENERIC);
    r_drawOtherModels = CreateConVar("r_drawothermodels", "1", "you know it", FCVAR_REPLICATED | FCVAR_NOTIFY);
    LoadTranslations("common.phrases.txt"); // Required for FindTarget fail reply
}


public Action Command_EnableWalls(int client, int args)
{
    //SetConVarInt(r_drawOtherModels, 2, true, true);
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))

    {
        SendConVarValue(i, r_drawOtherModels, "2");
    }
    }
    return Plugin_Handled;
}

public Action Command_DisableWalls(int client, int args)
{
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i))
    {
            SetClientInfo(i, "r_drawOtherModels", "1");
    }
    }
    return Plugin_Handled;
}
*/

/*
public void OnPluginStart()
{
    RegConsoleCmd("sm_hudmessage", testmessage);
}

public Action testmessage(int client, int args)
{
    char arg1[64];
    char arg2[64];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));
    int ent = CreateEntityByName("game_text");
    DispatchKeyValue(ent, "channel", "2");
    DispatchKeyValue(ent, "color", "255 255 255");
    DispatchKeyValue(ent, "color2", "0 0 0");
    DispatchKeyValue(ent, "effect", "0");
    DispatchKeyValue(ent, "fadein", "1.5");
    DispatchKeyValue(ent, "fadeout", "0.5");
    DispatchKeyValue(ent, "fxtime", "0.25"); 		
    DispatchKeyValue(ent, "holdtime", "5.0");
    DispatchKeyValue(ent, "message", "this is a test message\nThis is a new line test");
    DispatchKeyValue(ent, "spawnflags", "0"); 	
    DispatchKeyValue(ent, "x", arg1);
    DispatchKeyValue(ent, "y", arg2); 		
    DispatchSpawn(ent);
    SetVariantString("!activator");
    AcceptEntityInput(ent,"display",client);
    return Plugin_Handled;
}

*/
/*
public OnGameFrame()
{
    PrintHintTextToAll("Tick: %i", GetGameTickCount());
}
*/

/*
public OnMapStart() 
{
    CreateTimer(0.1, HUDTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:HUDTimer(Handle:timer) 
{
    PrintHintTextToAll("Tick: %i", GetGameTickCount());
}
*/
/*
public OnGameFrame()
{
    static int last_tick = -1;
    int cur_tick = GetGameTickCount();
    SetHudTextParams(0.2, 0.2, 0.05, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
    {
        ShowHudText(i, 1, "Tick: %i", last_tick);
    }
    }

    SetHudTextParams(0.2, 0.2, 0.05, 0, 0, 0, 255, 0, 0.0, 0.0, 0.0);
    for(int i = 1; i < MaxClients; i++) 
    {
        if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
    {
        ShowHudText(i, 1, "Tick: %i", cur_tick);
    }
    }
    last_tick = cur_tick;
}
*/

/*
public void OnPluginStart()
{
    RegAdminCmd("sm_printtime", Command_PrintTime, ADMFLAG_GENERIC);
    LoadTranslations("common.phrases.txt"); // Required for FindTarget fail reply
}

public Action Command_PrintTime(int client, int args)
{
    int cur_tick = GetGameTickCount();

}
*/
