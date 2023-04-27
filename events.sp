//https://wiki.alliedmods.net/Counter-Strike:_Global_Offensive_Events
#define MAX_HURT_EVENTS_PER_TICK 50
int curHurtIndex = 0;
int hurtVictimId[MAX_HURT_EVENTS_PER_TICK];
int hurtAttackerId[MAX_HURT_EVENTS_PER_TICK];
int hurtHealth[MAX_HURT_EVENTS_PER_TICK];
int hurtArmor[MAX_HURT_EVENTS_PER_TICK];
int hurtHealthDamage[MAX_HURT_EVENTS_PER_TICK];
int hurtArmorDamage[MAX_HURT_EVENTS_PER_TICK];
int hurtHitgroup[MAX_HURT_EVENTS_PER_TICK];
#define MAX_WEAPON_LENGTH 64
char hurtWeapon[MAX_HURT_EVENTS_PER_TICK][MAX_WEAPON_LENGTH];

static char hurtFilePath[] = "addons/sourcemod/bot-link-data/hurt.csv";
static char tmpHurtFilePath[] = "addons/sourcemod/bot-link-data/hurt.csv.tmp.write";
File tmpHurtFile;
bool tmpHurtOpen = false;

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    hurtVictimId[curHurtIndex] = GetClientOfUserId(event.GetInt("userid"));
    hurtAttackerId[curHurtIndex] = GetClientOfUserId(event.GetInt("attacker"));
    hurtHealth[curHurtIndex] = event.GetInt("health");
    hurtArmor[curHurtIndex] = event.GetInt("armor");
    hurtHealthDamage[curHurtIndex] = event.GetInt("dmg_health");
    hurtArmorDamage[curHurtIndex] = event.GetInt("dmg_armor");
    hurtHitgroup[curHurtIndex] = event.GetInt("hitgroup");
    event.GetString("weapon", hurtWeapon[curHurtIndex], MAX_WEAPON_LENGTH);
    curHurtIndex++;
}

stock void WritePlayerHurt() {
    if (tmpHurtOpen) {
        tmpHurtFile.Close();
        tmpHurtOpen = false;
    }
    tmpHurtFile = OpenFile(tmpHurtFilePath, "w", false, "");
    tmpHurtOpen = true;
    if (tmpHurtFile == null) {
        PrintToServer("opening tmpHurtFile returned null");
        return;
    }
    tmpHurtFile.WriteLine("Victim Id,Attacker Id,Health,Armor,Armor,Health Damage,Armor Damage,Hitgroup,Weapon");

    for (int i = 0; i < curHurtIndex; i++) {
        tmpHurtFile.WriteLine("%i,%i,%i,%i,%i,%i,%i,%s", 
            hurtVictimId[i], hurtAttackerId[i], hurtHealth[i], hurtArmor[i], hurtHealthDamage[i], hurtArmorDamage[i], hurtHitgroup[i], hurtWeapon[i]);
    }

    tmpHurtFile.Close();
    tmpHurtOpen = false;
    RenameFile(hurtFilePath, tmpHurtFilePath);
    curHurtIndex = 0;
}


int curWeaponFireIndex = 0;
int weaponFireShooterId[MAX_HURT_EVENTS_PER_TICK];
char weaponFireWeapon[MAX_HURT_EVENTS_PER_TICK][MAX_WEAPON_LENGTH];

static char weaponFireFilePath[] = "addons/sourcemod/bot-link-data/weaponFire.csv";
static char tmpWeaponFireFilePath[] = "addons/sourcemod/bot-link-data/weaponFire.csv.tmp.write";
File tmpWeaponFireFile;
bool tmpWeaponFireOpen = false;

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast) {
    weaponFireShooterId[curWeaponFireIndex] = GetClientOfUserId(event.GetInt("userid"));
    event.GetString("weapon", weaponFireWeapon[curWeaponFireIndex], MAX_WEAPON_LENGTH);
    curWeaponFireIndex++;
}

stock void WriteWeaponFire() {
    if (tmpWeaponFireOpen) {
        tmpWeaponFireFile.Close();
        tmpWeaponFireOpen = false;
    }
    tmpWeaponFireFile = OpenFile(tmpWeaponFireFilePath, "w", false, "");
    tmpWeaponFireOpen = true;
    if (tmpWeaponFireFile == null) {
        PrintToServer("opening tmpWeaponFireFile returned null");
        return;
    }
    tmpWeaponFireFile.WriteLine("Shooter Id,Weapon");

    for (int i = 0; i < curWeaponFireIndex; i++) {
        tmpWeaponFireFile.WriteLine("%i,%s", weaponFireShooterId[i], weaponFireWeapon[i]);
    }

    tmpWeaponFireFile.Close();
    tmpWeaponFireOpen = false;
    RenameFile(weaponFireFilePath, tmpWeaponFireFilePath);
    curWeaponFireIndex = 0;
}

bool unwrittenRoundStart = false;

static char roundStartFilePath[] = "addons/sourcemod/bot-link-data/roundStart.csv";
static char tmpRoundStartFilePath[] = "addons/sourcemod/bot-link-data/roundStart.csv.tmp.write";
File tmpRoundStartFile;
bool tmpRoundStartOpen = false;

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    unwrittenRoundStart = true;
}

stock void WriteRoundStart(int currentFrame) {
    if (tmpRoundStartOpen) {
        tmpRoundStartFile.Close();
        tmpRoundStartOpen = false;
    }

    if (unwrittenRoundStart) {
        tmpRoundStartFile = OpenFile(tmpRoundStartFilePath, "w", false, "");
        tmpRoundStartOpen = true;
        if (tmpRoundStartFile == null) {
            PrintToServer("opening tmpRoundStartFile returned null");
            return;
        }
        tmpRoundStartFile.WriteLine("State Frame");

        tmpRoundStartFile.WriteLine("%i", currentFrame);

        tmpRoundStartFile.Close();
        tmpRoundStartOpen = false;
        RenameFile(roundStartFilePath, tmpRoundStartFilePath);
    }
}
