#include <profiler>
#define MAX_VIS_POINTS 72000
#define MAX_ROWS 20
float visPoints[MAX_VIS_POINTS][3];
bool visValid[MAX_ROWS][MAX_VIS_POINTS];

int visRangeStart, visRangeNum;
char visRangeBuffer[MAX_INPUT_LENGTH], visRangeExplodedBuffer[MAX_INPUT_FIELDS][MAX_INPUT_LENGTH];
int numVisPoints;
char visPointsBuffer[MAX_INPUT_LENGTH], visPointsExplodedBuffer[MAX_INPUT_FIELDS][MAX_INPUT_LENGTH];

static char visRangeFilePath[] = "addons/sourcemod/bot-link-data/vis_range.csv";
static char tmpVisRangeFilePath[] = "addons/sourcemod/bot-link-data/vis_range.csv.tmp.read";
File tmpVisRangeFile;
bool tmpVisRangeOpen = false;

static char visPointsFilePath[] = "addons/sourcemod/bot-link-data/vis_points.csv";
static char tmpVisPointsFilePath[] = "addons/sourcemod/bot-link-data/vis_points.csv.tmp.read";
File tmpVisPointsFile;
bool tmpVisPointsOpen = false;

static char visValidFilePath[] = "addons/sourcemod/bot-link-data/vis_valid.csv";
static char tmpVisValidFilePath[] = "addons/sourcemod/bot-link-data/vis_valid.csv.tmp.write";
File tmpVisValidFile;
bool tmpVisValidOpen = false;

stock void ReadVisRange() {
    if (tmpVisRangeOpen) {
        tmpVisRangeFile.Close();
        tmpVisRangeOpen = false;
    }
    // move file to tmp location so not overwritten, then read it and run each line in console
    if (FileExists(visRangeFilePath)) {
        RenameFile(tmpVisRangeFilePath, visRangeFilePath);

        tmpVisRangeFile = OpenFile(tmpVisRangeFilePath, "r", false, "");
        tmpVisRangeOpen = true;

        tmpVisRangeFile.ReadLine(visRangeBuffer, MAX_INPUT_LENGTH); 
        ExplodeString(visRangeBuffer, ",", visRangeExplodedBuffer, MAX_INPUT_FIELDS, MAX_INPUT_LENGTH);
        visRangeStart = StringToFloat(visRangeExplodedBuffer[0]);
        visRangeNum = StringToFloat(visRangeExplodedBuffer[1]);
        PrintToServer("Range start %i num %i", visRangeStart, visRangeNum);

        tmpVisRangeFile.Close();
        tmpVisRangeOpen = false;
    }
}

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
            if (visValid[i][j]) {
                tmpVisValidFile.WriteLine("%i,%i", i, j);
            }
        }
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

stock bool VisibilityTestWithPoint(const float sourcePosition[3], const float targetPosition[3], int flags, float hitPoint[3])
{
    Handle hTrace = TR_TraceRayFilterEx(sourcePosition, targetPosition, 
        flags, RayType_EndPoint, Base_TraceFilter, MaxClients);
    
    if (TR_DidHit(hTrace))
    {
        TR_GetEndPosition(hitPoint, hTrace);
        delete hTrace;
        return false;
    }
    
    delete hTrace;
    return true;
}

public Action smQueryRangeVisPointPairs(int client, int args)
{
    ReadVisRange();
    if (visRangeStart == 0) {
        ReadVisPoints();
    }

    int numValid = 0, numChecked = 0;
    for (int i = visRangeStart; i < visRangeStart + visRangeNum; i++) {
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
