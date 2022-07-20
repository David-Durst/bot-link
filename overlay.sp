#define MAX_OVERLAY_AREAS MAX_VIS_POINTS * 4 * 2 // two overlays (danger attention and diffusion) and four entries per overlay (where enemies can be)
float overlayMins[MAX_OVERLAY_AREAS][3], overlayMaxs[MAX_OVERLAY_AREAS][3];
char overlayColor[MAX_OVERLAY_AREAS];
int numOverlayAreas;
float overlayDuration;

static char overlayFilePath[] = "addons/sourcemod/bot-link-data/overlay_areas.csv";
static char overlayFilePath[] = "addons/sourcemod/bot-link-data/overlay_areas.csv.tmp.read";
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

        tmpOverlayFile.ReadLine(overlayBuffer, MAX_INPUT_LENGTH)
        overlayDuration = StringToFloat(overlayBuffer);

        for(int i = 0; tmpOverlayFile.ReadLine(overlayBuffer, MAX_INPUT_LENGTH); i++) {
            ServerCommand(overlayBuffer);
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
        PrintToServer("Read %i overlay areas", numOverlay);

        DrawOverlay();

        tmpOverlayFile.Close();
        tmpOverlayOpen = false;
    }
}

stock void DrawOverlay() {
  int color[4];
  for (int i = 0; i < numOverlayAreas; i++) {
    if (overlayColor[i] == 'b') {
      color = {0, 0, 0, 255};
    }
    else if (overlayColor[i] == 'u') {
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
    TE_SendBeam(overlayMins[i], overlayMaxs[i], color, overlayDuration)
  }
  return;
}
