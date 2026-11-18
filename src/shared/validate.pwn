// ---------------------------------------------------------------------------
// module      : shared/validate
// entry       : -
// depends     : core/text
// owns tables : -
// public api  : Validate_Username(), Validate_Password(), Validate_FullName(),
//               Validate_PlayerId(), Command_Split()
// ---------------------------------------------------------------------------
#if defined _INC_VALIDATE
    #endinput
#endif
#define _INC_VALIDATE

#define MIN_USERNAME_LENGTH (3)
#define MAX_USERNAME_LENGTH (24)
#define MIN_PASSWORD_LENGTH (8)
#define MAX_PASSWORD_LENGTH (32)

stock bool:Validate_Username(const username[]) {
    new length = strlen(username);
    if (length < MIN_USERNAME_LENGTH || length > MAX_USERNAME_LENGTH) {
        return false;
    }
    for (new index = 0; username[index] != '\0'; index++) {
        new character = username[index];
        if (character >= 'a' && character <= 'z') continue;
        if (character >= 'A' && character <= 'Z') continue;
        if (character >= '0' && character <= '9') continue;
        if (character == '_') continue;
        return false;
    }
    return true;
}

stock bool:Validate_Password(const password[]) {
    new length = strlen(password);
    return length >= MIN_PASSWORD_LENGTH && length <= MAX_PASSWORD_LENGTH;
}

// Nama karakter: hanya huruf, 2..24 karakter.
stock bool:Validate_NamePart(const name[]) {
    new length = strlen(name);
    if (length < 2 || length > MAX_USERNAME_LENGTH) {
        return false;
    }
    return Text_OnlyLetters(name);
}

stock bool:Validate_PlayerId(playerid) {
    return playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid);
}

// "b halo semua" -> cmd="b", params="halo semua"
stock bool:Command_Split(const input[], cmd[], cmdSize, params[], paramsSize) {
    new length = strlen(input);
    new index = 0;
    new written = 0;

    while (index < length && input[index] != ' ' && written < cmdSize - 1) {
        cmd[written++] = input[index++];
    }
    cmd[written] = '\0';

    while (index < length && input[index] == ' ') {
        index++;
    }

    written = 0;
    while (index < length && written < paramsSize - 1) {
        params[written++] = input[index++];
    }
    params[written] = '\0';

    return cmd[0] != '\0';
}

// Ambil token pertama dari params, sisanya ke rest[]
stock bool:Command_NextToken(const params[], token[], tokenSize, rest[], restSize) {
    new length = strlen(params);
    new index = 0;
    new written = 0;

    while (index < length && params[index] != ' ' && written < tokenSize - 1) {
        token[written++] = params[index++];
    }
    token[written] = '\0';

    while (index < length && params[index] == ' ') {
        index++;
    }

    written = 0;
    while (index < length && written < restSize - 1) {
        rest[written++] = params[index++];
    }
    rest[written] = '\0';

    return token[0] != '\0';
}
