static char visibilityFilePath[] = "addons/sourcemod/bot-link-data/visibility.csv";
static char tmpVisibilityFilePath[] = "addons/sourcemod/bot-link-data/visibility.csv.tmp.write";
File tmpVisibilityFile;
bool tmpVisibilityOpen = false;

stock void WriteVisibility() {
    if (tmpVisibilityOpen) {
        tmpVisibilityFile.Close();
        tmpVisibilityOpen = false;
    }
    tmpVisibilityFile = OpenFile(tmpVisibilityFilePath, "w", false, "");
    tmpVisibilityOpen = true;
    if (tmpVisibilityFile == null) {
        PrintToServer("opening tmpVisibilityFile returned null");
        return;
    }

    tmpVisibilityFile.WriteLine("Source Player,Target Player");

    for (int source = 1; source < MaxClients; source++) {
        for (int target = source + 1; target < MaxClients; target++) {
            if (source != target && IsValidClient(source) && IsValidClient(target) && 
                    SourceCanSeeTarget(source, target)) {
                tmpVisibilityFile.WriteLine("%i,%i", source,target);
            }
        }
    }

    tmpVisibilityFile.Close();
    tmpVisibilityOpen = false;
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
            MASK_VISIBLE, RayType_EndPoint, Base_TraceFilter, target);
        
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
    // return true (can hit) if not any non-target player (aka target player or environment)
    return entity >= MaxClients || entity == data || !IsValidClient(entity);
}

static bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && 
        IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}
