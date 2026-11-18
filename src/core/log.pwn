// ---------------------------------------------------------------------------
// module      : core/log
// entry       : Log_Boot()
// depends     : core/text, core/settings
// owns tables : -
// public api  : Log_Boot(), Log_Info(), Log_Warn(), Log_Error(), Log_Debug(),
//               Log_Module()
// Catatan     : sengaja tanpa argumen variadik. Pawn tidak mendukung forward
//               variadik tanpa YSI, dan menambah YSI hanya untuk log melanggar
//               aturan "tidak ada dependensi untuk hal sepele".
// ---------------------------------------------------------------------------
#if defined _INC_LOG
    #endinput
#endif
#define _INC_LOG

#pragma warning disable 208

#define LOG_FILE        "server.log"
// Konstanta level sengaja memakai #define, bukan enum: compiler Pawn 3.10.11
// tidak menerima `enum { ... }` tanpa nama, dan enum bertag memicu tag mismatch
// di setiap switch.
#define LOG_LEVEL_ERROR 0
#define LOG_LEVEL_WARN  1
#define LOG_LEVEL_INFO  2
#define LOG_LEVEL_DEBUG 3

static gLogReady = 0;

stock Log_Boot() {
    new File:handle = fopen(LOG_FILE, io_append);
    if (!handle) {
        print("[log] file log tidak bisa dibuka, lanjut console saja");
        gLogReady = 0;
        return 1;
    }
    fclose(handle);
    gLogReady = 1;
    return 1;
}

stock Log_Info(const module[], const message[]) {
    return Log_Write(LOG_LEVEL_INFO, module, message);
}

stock Log_Warn(const module[], const message[]) {
    return Log_Write(LOG_LEVEL_WARN, module, message);
}

stock Log_Error(const module[], const message[]) {
    return Log_Write(LOG_LEVEL_ERROR, module, message);
}

stock Log_Debug(const module[], const message[]) {
    if (!Settings_DebugEnabled()) {
        return 0;
    }
    return Log_Write(LOG_LEVEL_DEBUG, module, message);
}

stock Log_Module(const module[], const message[]) {
    return Log_Write(LOG_LEVEL_INFO, module, message);
}

static Log_Write(level, const module[], const message[]) {
    if (level > Settings_LogLevel()) {
        return 0;
    }

    new levelName[8];
    Log_LevelName(level, levelName, sizeof (levelName));

    new line[512];
    format(line, sizeof (line), "[%s] [%s] %s", levelName, module, message);
    print(line);

    if (!gLogReady) {
        return 1;
    }

    new File:handle = fopen(LOG_FILE, io_append);
    if (!handle) {
        return 0;
    }
    fwrite(handle, line);
    fwrite(handle, "\r\n");
    fclose(handle);
    return 1;
}

// Pawn tidak bisa `return "string"`; hasil ditulis ke buffer pemanggil.
stock Log_LevelName(level, dest[], maxlength = sizeof (dest)) {
    switch (level) {
        case LOG_LEVEL_ERROR: return format(dest, maxlength, "ERROR");
        case LOG_LEVEL_WARN:  return format(dest, maxlength, "WARN");
        case LOG_LEVEL_DEBUG: return format(dest, maxlength, "DEBUG");
    }
    return format(dest, maxlength, "INFO");
}
