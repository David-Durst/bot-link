#define MAX_VIS_POINTS 2000
float visPoints[MAX_VIS_POINTS][3];
bool visValid[MAX_VIS_POINTS][MAX_VIS_POINTS];
char visValidBuf[MAX_VIS_POINTS + 1];

int numVisPoints;
char visPointsBuffer[MAX_INPUT_LENGTH], visPointsExplodedBuffer[MAX_INPUT_FIELDS][MAX_INPUT_LENGTH];

static char visPointsFilePath[] = "addons/sourcemod/bot-link-data/vis_points.csv";
static char tmpVisPointsFilePath[] = "addons/sourcemod/bot-link-data/vis_points.csv.tmp.read";
File tmpVisPointsFile;
bool tmpVisPointsOpen = false;

static char visValidFilePath[] = "addons/sourcemod/bot-link-data/vis_valid.csv";
static char tmpVisValidFilePath[] = "addons/sourcemod/bot-link-data/vis_valid.csv.tmp.write";
File tmpVisValidFile;
bool tmpVisValidOpen = false;


stock void ReadVisPoints() {
    if (tmpVisPointsOpen) {
        tmpVisPointsFile.Close();
        tmpVisPointsOpen = false;
    }
    // move file to tmp location so not overwritten, then read it and run each line in console
    if (FileExists(visPointsFilePath)) {
        RenameFile(tmpVisPointsFilePath, visPointsFilePath);

        tmpVisPointsFile = OpenFile(tmpVisPointsFilePath, "r", false, "");
        tmpVisPointsOpen = true;

        for(int i = 0; tmpVisPointsFile.ReadLine(visPointsBuffer, MAX_INPUT_LENGTH); i++) {
            ExplodeString(visPointsBuffer, ",", visPointsExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
            for (int j = 0; j < 3; j++) {
                visPoints[i][j] = StringToFloat(visPointsExplodedBuffer[j]);
            }
            numVisPoints = i + 1;
        }
        PrintToServer("Read %i vis points", numVisPoints);

        tmpVisPointsFile.Close();
        tmpVisPointsOpen = false;
    }
}

stock void WriteVisValid() {
    if (tmpVisValidOpen) {
        tmpVisValidFile.Close();
        tmpVisValidOpen = false;
    }

    tmpVisValidFile = OpenFile(tmpVisValidFilePath, "w", false, "");
    tmpVisValidOpen = true;
    if (tmpVisValidFile == null) {
        PrintToServer("opening tmpVisValidFile returned null");
        return;
    }

    for(int i = 0; i < numVisPoints; i++) {
        for (int j = 0; j < numVisPoints; j++) {
            visValidBuf[j] = visValid[i][j] ? 't' : 'f';
        }
        visValidBuf[numVisPoints] = '\0';
        tmpVisValidFile.WriteLine(visValidBuf);
    }

    tmpVisValidFile.Close();
    tmpVisValidOpen = false;
    RenameFile(visValidFilePath, tmpVisValidFilePath);
}

stock bool VisibilityTest(const float sourcePosition[3], const float targetPosition[3])
{
    Handle hTrace = TR_TraceRayFilterEx(sourcePosition, targetPosition, 
        MASK_VISIBLE, RayType_EndPoint, Base_TraceFilter, MaxClients);
    
    if (TR_DidHit(hTrace))
    {
        delete hTrace;
        return false;
    }
    
    delete hTrace;
    return true;
}


public Action smQueryAllVisPointPairs(int client, int args)
{
    ReadVisPoints();

    int numValid = 0, numChecked = 0;
    for (int i = 0; i < numVisPoints; i++) {
        for (int j = i + 1; j < numVisPoints; j++) {
            visValid[i][j] = VisibilityTest(visPoints[i], visPoints[j]);
            if (visValid[i][j]) {
                numValid++;
            }
            numChecked++;
        }
    }

    WriteVisValid();
    PrintToServer("%i / %i (%f pct) vis pairs valid", numValid, numChecked, (numValid * 1.0) / numChecked);
    return Plugin_Handled;
}
