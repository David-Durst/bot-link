// https://sm.alliedmods.net/api/index.php?fastload=file&id=40
enum weaponSlots: {
    SLOT_RIFLE,
    SLOT_PISTOL,
    SLOT_KNIFE,
    SLOT_GRENADES,
    SLOT_C4,
    NUM_WEAPON_SLOTS
};

#define ZEUS_WEAPON_ID 31

stock int GetActiveWeaponEntityId(int client) {
    return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

stock int GetRifleEntityId(int client) {
    return GetPlayerWeaponSlot(client, SLOT_RIFLE);
}

stock int GetPistolEntityId(int client) {
    return GetPlayerWeaponSlot(client, SLOT_PISTOL);
}

stock int GetC4EntityId(int client) {
    return GetPlayerWeaponSlot(client, SLOT_C4);
}

stock int GetWeaponIdFromEntityId(int entity) {
    return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
}

stock int GetWeaponClipAmmo(int entity) {
    return GetEntProp(entity, Prop_Send, "m_iClip1");
}

stock int GetWeaponReserveAmmo(int entity) {
    return GetEntProp(entity, Prop_Send, "m_iPrimaryReserveAmmoCount");
}

stock bool IsWeaponReloading(int entity) {
    return GetEntProp(entity, Prop_Data, "m_bInReload") != 0;
}

stock bool HaveZeus(int client) {
    int m_hMyWeapons_size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");

    for (int i = 0; i < m_hMyWeapons_size; i++) {
        int entityId = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (entityId != -1 && GetWeaponIdFromEntityId(entityId) == ZEUS_WEAPON_ID) {
            return true;
        }
    }

    return false;
}
