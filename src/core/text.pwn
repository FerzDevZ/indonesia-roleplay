// ---------------------------------------------------------------------------
// module      : core/text
// entry       : -
// depends     : -
// owns tables : -
// public api  : Text_Trim(), Text_SplitKeyValue(), Text_IsEmpty(),
//               Text_CountChars(), Text_OnlyLetters(), Text_FormatNumber()
// ---------------------------------------------------------------------------
#if defined _INC_TEXT
    #endinput
#endif
#define _INC_TEXT

stock Text_Trim(dest[], const source[], maxlength = sizeof (dest)) {
    new start = 0;
    new finish = strlen(source);

    while (start < finish && (source[start] == ' ' || source[start] == '\t')) {
        start++;
    }
    while (finish > start && (source[finish - 1] == ' ' || source[finish - 1] == '\t'
        || source[finish - 1] == '\r' || source[finish - 1] == '\n')) {
        finish--;
    }

    return strmid(dest, source, start, finish, maxlength);
}

stock bool:Text_IsEmpty(const value[]) {
    new trimmed[2];
    Text_Trim(trimmed, value, sizeof (trimmed));
    return trimmed[0] == '\0';
}

stock bool:Text_SplitKeyValue(const source[], key[], keySize, value[], valueSize) {
    new separator = -1;
    for (new index = 0; source[index] != '\0'; index++) {
        if (source[index] == '=') {
            separator = index;
            break;
        }
    }
    if (separator < 1) {
        return false;
    }

    new rawKey[64], rawValue[128];
    strmid(rawKey, source, 0, separator, sizeof (rawKey));
    strmid(rawValue, source, separator + 1, strlen(source) + 1, sizeof (rawValue));

    Text_Trim(key, rawKey, keySize);
    Text_Trim(value, rawValue, valueSize);
    return true;
}

stock Text_CountChars(const value[]) {
    return strlen(value);
}

stock bool:Text_OnlyLetters(const value[], bool:allowUnderscore = false) {
    if (value[0] == '\0') {
        return false;
    }
    for (new index = 0; value[index] != '\0'; index++) {
        new character = value[index];
        new isLetter = (character >= 'a' && character <= 'z')
            || (character >= 'A' && character <= 'Z');
        if (!isLetter && !(allowUnderscore && character == '_')) {
            return false;
        }
    }
    return true;
}

// 1250000 -> "1.250.000"
stock Text_FormatNumber(value, dest[], maxlength = sizeof (dest)) {
    new negative = value < 0;
    new remaining = negative ? -value : value;
    new digits[24];
    format(digits, sizeof (digits), "%d", remaining);

    new length = strlen(digits);
    new written = 0;

    if (negative && written < maxlength - 1) {
        dest[written++] = '-';
    }

    for (new index = 0; index < length; index++) {
        if (index > 0 && ((length - index) % 3) == 0 && written < maxlength - 1) {
            dest[written++] = '.';
        }
        if (written < maxlength - 1) {
            dest[written++] = digits[index];
        }
    }
    dest[written] = '\0';
    return written;
}
