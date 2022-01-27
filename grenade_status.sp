// https://forums.alliedmods.net/showthread.php?t=263982
char g_saGrenadeWeaponNames[][] = {
    "weapon_flashbang",
    "weapon_molotov",
    "weapon_smokegrenade",
    "weapon_hegrenade",
    "weapon_decoy",
    "weapon_incgrenade"
};

enum Grenades: {
    Flash,
    Molotov,
    Smoke,
    HE,
    Decoy,
    Incendiary,
    NUM_GRENADES
};

int g_iaGrenadeOffsets[sizeof(g_saGrenadeWeaponNames)];

stock void InitOffsets() {
    if (!g_iaGrenadeOffsets[0]) {
        for (int i=0; i<sizeof(g_saGrenadeWeaponNames); i++) {
            int entindex = CreateEntityByName(g_saGrenadeWeaponNames[i]);
            DispatchSpawn(entindex);
            g_iaGrenadeOffsets[i] = GetEntProp(entindex, Prop_Send, "m_iPrimaryAmmoType");
            AcceptEntityInput(entindex, "Kill");
        }
    }
}

stock int GetGrenade(int client, Grenades grenadeIndex) {
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, g_iaGrenadeOffsets[grenadeIndex]) != 0;
}

