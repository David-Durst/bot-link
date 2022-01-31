static char visibilityFilePath[] = "addons/sourcemod/bot-link-data/visibility.csv";
static char tmpVisibilityFilePath[] = "addons/sourcemod/bot-link-data/visibility.csv.tmp.write";
File tmpVisibilityFile;

stock void WriteVisibility() {
    tmpVisibilityFile = OpenFile(tmpVisibilityFilePath, "w", false, "");
    if (tmpVisibilityFile == null) {
        PrintToServer("opening tmpVisibilityFile returned null");
        return;
    }

    tmpVisibilityFile.WriteLine("Source Player,Target Player,Visible");

    for (int source = 1; source < MaxClients; source++) {
        for (int target = 1; target < MaxClients; target++) {
            if (IsValidClient(source) && IsValidClient(target)) {
                int result = 0;
                if (SourceCanSeeTarget(source, target)) {
                    result = 1;
                }
                tmpVisibilityFile.WriteLine("%i,%i,%i", source, target,result);
            }
        }
    }

    tmpVisibilityFile.Close();
    RenameFile(visibilityFilePath, tmpVisibilityFilePath);
}

stock bool SourceCanSeeTarget(int source, int target, float maxDistance = 0.0)
{
    float sourcePosition[3], targetPosition[3];

    GetClientEyePosition(source, sourcePosition);
    GetClientEyePosition(target, targetPosition);
    
    if (maxDistance == 0.0 || GetVectorDistance(sourcePosition, targetPosition, false) < maxDistance)
    {
        Handle hTrace = TR_TraceRayFilterEx(sourcePosition, targetPosition, 
            MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter, source);
        
        if (TR_DidHit(hTrace) && TR_GetEntityIndex(hTrace) != target)
        {
            delete hTrace;
            return false;
        }
        
        delete hTrace;
        return true;
    }
    
    return false;
}

public bool Base_TraceFilter(int entity, int contentsMask, int data)
{
    return entity != data;
}
