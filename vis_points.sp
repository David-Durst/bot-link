#include <profiler>
#define MAX_VIS_POINTS 72000
#define MAX_ROWS 20
float visPoints[MAX_VIS_POINTS][3];
bool visValid[MAX_ROWS][MAX_VIS_POINTS];

int visRangeStart, visRangeNum;
float overallPctValid, overallRaysPerSecond;
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
        visRangeStart = StringToInt(visRangeExplodedBuffer[0]);
        visRangeNum = StringToInt(visRangeExplodedBuffer[1]);
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

    for(int i = 0; i < visRangeNum; i++) {
        for (int j = 0; j < numVisPoints; j++) {
            if (visValid[i][j]) {
                tmpVisValidFile.WriteLine("%i,%i", visRangeStart + i, j);
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
        overallPctValid = 1.0;
        overallRaysPerSecond = 1.0;
    }

    Profiler prof = CreateProfiler();
    int numValid = 0, numChecked = 0;
    StartProfiling(prof);
    for (int i = 0; i < visRangeNum; i++) {
        for (int j = visRangeStart + i + 1; j < numVisPoints; j++) {
            visValid[i][j] = VisibilityTest(visPoints[visRangeStart + i], visPoints[j]);
            if (visValid[i][j]) {
                numValid++;
            }
            numChecked++;
        }
    }

    WriteVisValid();
    StopProfiling(prof);
    float profTime = GetProfilerTime(prof);
    float curIterPctValid = (numValid * 1.0) / numChecked;
    float curIterRaysPerSecond = (numChecked * 1.0) / profTime;
    PrintToServer("cur iter: %i / %i (%f pct) vis pairs valid at %f rays / sec in %f seconds", 
        numValid, numChecked, curIterPctValid, curIterRaysPerSecond, profTime);
    overallPctValid = (overallPctValid * visRangeStart + curIterPctValid * visRangeNum) / 
        (visRangeStart + visRangeNum);
    overallRaysPerSecond = (overallRaysPerSecond * visRangeStart + curIterRaysPerSecond * visRangeNum) / 
        (visRangeStart + visRangeNum);
    PrintToServer("overall: %f pct vis pairs valid at %f rays / sec", 
        overallPctValid, overallRaysPerSecond);
    delete prof;
    return Plugin_Handled;
}
