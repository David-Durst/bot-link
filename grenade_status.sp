// https://forums.alliedmods.net/showthread.php?t=263982
char g_saGrenadeWeaponNames[][] = {
    "weapon_flashbang",
    "weapon_molotov",
    "weapon_smokegrenade",
    "weapon_hegrenade",
    "weapon_decoy",
    "weapon_incgrenade",
    "weapon_taser"
};

enum grenades: {
    Flash,
    Molotov,
    Smoke,
    HE,
    Decoy,
    Incendiary,
    Zeus,
    NUM_GRENADES
};

#define FLASHBANG_WEAPON_ID 43
#define HE_WEAPON_ID 44
#define SMOKE_WEAPON_ID 45
#define MOLOTOV_WEAPON_ID 46
#define DECOY_WEAPON_ID 47
#define INCENDIARY_WEAPON_ID 48

int g_iaGrenadeOffsets[sizeof(g_saGrenadeWeaponNames)];

stock void InitGrenadeOffsets() {
    if (!g_iaGrenadeOffsets[0]) {
        for (int i=0; i<sizeof(g_saGrenadeWeaponNames); i++) {
            int entindex = CreateEntityByName(g_saGrenadeWeaponNames[i]);
            DispatchSpawn(entindex);
            g_iaGrenadeOffsets[i] = GetEntProp(entindex, Prop_Send, "m_iPrimaryAmmoType");
            AcceptEntityInput(entindex, "Kill");
        }
    }
}

stock int GetGrenade(int client, grenades grenadeIndex) {
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, g_iaGrenadeOffsets[grenadeIndex]);
}

stock void RemoveNades(int client) {
    for (int i=0; i<sizeof(g_saGrenadeWeaponNames); i++) {
        SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iaGrenadeOffsets[i]);
    }
}

stock bool IsWeaponGrenade(int weaponId) {
    return weaponId == FLASHBANG_WEAPON_ID ||
        weaponId == HE_WEAPON_ID ||
        weaponId == SMOKE_WEAPON_ID ||
        weaponId == MOLOTOV_WEAPON_ID ||
        weaponId == DECOY_WEAPON_ID ||
        weaponId == INCENDIARY_WEAPON_ID;
}
