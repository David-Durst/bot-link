enum weaponSlots: {
    SLOT_RIFLE,
    SLOT_PISTOL,
    SLOT_KNIFE,
    SLOT_GRENADES,
    SLOT_C4,
    NUM_WEAPON_SLOTS
};

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
