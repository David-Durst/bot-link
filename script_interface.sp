char scriptBuffer[MAX_INPUT_LENGTH];

static char scriptFilePath[] = "addons/sourcemod/bot-link-data/script.txt";
static char tmpScriptFilePath[] = "addons/sourcemod/bot-link-data/script.txt.tmp.read";
File tmpScriptFile;
bool tmpScriptOpen = false;

stock void ReadExecuteScript() {
    if (tmpScriptOpen) {
        tmpScriptFile.Close();
        tmpScriptOpen = false;
    }
    // move file to tmp location so not overwritten, then read it and run each line in console
    if (FileExists(scriptFilePath)) {
        RenameFile(tmpScriptFilePath, scriptFilePath);

        tmpScriptFile = OpenFile(tmpScriptFilePath, "r", false, "");
        tmpScriptOpen = true;
        tmpScriptFile.ReadLine(scriptBuffer, MAX_INPUT_LENGTH);

        while(!tmpScriptFile.EndOfFile()) {
            tmpScriptFile.ReadLine(scriptBuffer, MAX_INPUT_LENGTH);
            ServerCommand(scriptBuffer);
        }

        tmpScriptFile.Close();
        tmpScriptOpen = false;
    }
}
