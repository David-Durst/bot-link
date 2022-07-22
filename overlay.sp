#define MAX_OVERLAY_AREAS MAX_VIS_POINTS * 4 * 2 // two overlays (danger attention and diffusion) and four entries per overlay (where enemies can be)
float overlayMins[MAX_OVERLAY_AREAS][3], overlayMaxs[MAX_OVERLAY_AREAS][3];
char overlayColor[MAX_OVERLAY_AREAS];
int numOverlayAreas;
float overlayDuration;
char overlayBuffer[MAX_INPUT_LENGTH], overlayExplodedBuffer[MAX_INPUT_FIELDS][MAX_INPUT_LENGTH];

static char overlayFilePath[] = "addons/sourcemod/bot-link-data/overlay.csv";
static char tmpOverlayFilePath[] = "addons/sourcemod/bot-link-data/overlay.csv.tmp.read";
File tmpOverlayFile;
bool tmpOverlayOpen = false;


stock void ReadUpdateOverlay() {
    if (tmpOverlayOpen) {
        tmpOverlayFile.Close();
        tmpOverlayOpen = false;
    }
    // move file to tmp location so not overwritten, then read it and run each line in console
    if (FileExists(overlayFilePath)) {
        RenameFile(tmpOverlayFilePath, overlayFilePath);

        tmpOverlayFile = OpenFile(tmpOverlayFilePath, "r", false, "");
        tmpOverlayOpen = true;

        numOverlayAreas = 0;

        tmpOverlayFile.ReadLine(overlayBuffer, MAX_INPUT_LENGTH);
        overlayDuration = StringToFloat(overlayBuffer);

        for(int i = 0; tmpOverlayFile.ReadLine(overlayBuffer, MAX_INPUT_LENGTH); i++) {
            ExplodeString(overlayBuffer, ",", overlayExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            for (int j = 0; j < 3; j++) {
              overlayMins[i][j] = StringToFloat(overlayExplodedBuffer[j]);
            }
            for (int j = 0; j < 3; j++) {
              overlayMaxs[i][j] = StringToFloat(overlayExplodedBuffer[3+j]);
            }
            overlayColor[i] = overlayExplodedBuffer[6][0];
            numOverlayAreas = i + 1;
        }
        //PrintToConsoleAll("Read %i overlay areas with duration %f", numOverlayAreas, overlayDuration);

        DrawOverlay();

        tmpOverlayFile.Close();
        tmpOverlayOpen = false;
    }
}

// works in b site on d2 sm_drawAABB -1643.615479 2133.535400 112.794823 -1700.615479 2433.535400 112.794823 g 10.0 
public Action smDrawX(int client, int args)
{
    if (args != 8) {
        PrintToConsole(client, "smSavePos requires 8 args");
        return Plugin_Handled;
    }

    char arg[128];

    for (int i = 1; i <= 6; i++) {
        GetCmdArg(i, arg, sizeof(arg));
        if (i < 4) {
            overlayMins[0][i - 1] = StringToFloat(arg);
        }
        else {
            overlayMaxs[0][i - 4] = StringToFloat(arg);
        }
    }

    GetCmdArg(7, arg, sizeof(arg));
    overlayColor[0] = arg[0];

    GetCmdArg(8, arg, sizeof(arg));
    overlayDuration = StringToFloat(arg);

    numOverlayAreas = 1;

    DrawOverlay();
    return Plugin_Handled;
}

stock void DrawOverlay() {
    int color[4];
    for (int i = 0; i < numOverlayAreas; i++) {
        if (overlayColor[i] == 'b') {
            color = {0, 0, 255, 255};
        }
        else if (overlayColor[i] == 'r') {
            color = {255, 0, 0, 255};
        }
        else if (overlayColor[i] == 'g') {
            color = {0, 255, 0, 255};
        }
        else if (overlayColor[i] == 'w') {
            color = {255, 255, 255, 255};
        }
        else if (overlayColor[i] == 'y') {
            color = {255, 255, 0, 255};
        }
        else if (overlayColor[i] == 'p') {
            color = {255, 0, 255, 255};
        }
        else if (overlayColor[i] == 'c') {
            color = {0, 255, 255, 255};
        }
        else if (overlayColor[i] == 'e') {
            color = {255, 128, 128, 255};
        }
        /*
        PrintToConsoleAll("drawing overlay aabb (%f, %f, %f) (%f, %f, %f) (%d, %d, %d) %c", 
            overlayMins[i][0], overlayMins[i][1], overlayMins[i][2], overlayMaxs[i][0], overlayMaxs[i][1], overlayMaxs[i][2],
            color[0], color[1], color[2], overlayColor[i]);
        */
        TE_SendX(overlayMins[i], overlayMaxs[i], color, overlayDuration);
    }
    return;
}

void TE_SendX(float m_vecMins[3], float m_vecMaxs[3], int color[4], float flDur = 0.1)
{
    float m_vecBaseMins[3], m_vecBaseMaxs[3];
    float m_vecBaseMins2[3], m_vecBaseMaxs2[3];
    m_vecBaseMins[0] = m_vecMins[0];
    m_vecBaseMins[1] = m_vecMins[1];
    m_vecBaseMins[2] = m_vecMins[2];
    m_vecBaseMaxs[0] = m_vecMaxs[0];
    m_vecBaseMaxs[1] = m_vecMaxs[1];
    m_vecBaseMaxs[2] = m_vecMaxs[2];
    TE_SetupBeamPoints(m_vecBaseMins, m_vecBaseMaxs, g_iWhiteMaterial, g_iWhiteMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
    TE_SendToAll();
    m_vecBaseMins2[0] = m_vecMaxs[0];
    m_vecBaseMins2[1] = m_vecMins[1];
    m_vecBaseMins2[2] = m_vecMins[2];
    m_vecBaseMaxs2[0] = m_vecMins[0];
    m_vecBaseMaxs2[1] = m_vecMaxs[1];
    m_vecBaseMaxs2[2] = m_vecMaxs[2];
    TE_SetupBeamPoints(m_vecBaseMins2, m_vecBaseMaxs2, g_iWhiteMaterial, g_iWhiteMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
    TE_SendToAll();
}
