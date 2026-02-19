#include "errors.h"
#include <stdio.h>

char ADDRES[256];

const char* err2str(int err) {
    const char *val;
    static char error_message[300]; 

    switch (err) {
        case -101:
            val = "Failed to load curl.";
            break;
        case -103:
            val = "Curl received empty value.";
            break;
        case -102:
            { 
                snprintf(error_message, sizeof(error_message), 
                         "Curl failed to do the request, reason: %s", ADDRES);
                return error_message;
            }
        case -201:
            val = "Failed to open the file";
            break;
        case -202:
            val = "File does not exist, getting latest version.";
            break;
        case -203:
            val = "Could not seek to offset in file, maybe file is too small?";
            break;
        case -204:
            val = "Could not write to file.";
            break;
        case -205:
            val = "Could not close file.";
            break;
        case -301:
            val = "Version mismatch, getting new version.";
            break;
        case -401:
            val = "String not found.";
            break;
        case -501:
            val = "URL too long: replacement URL exceeds the length of the original. Binary patching requires new URL <= old URL length.";
            break;
        case -502:
            val = "URL not found in file.";
            break;
        case -503:
            val = "No URL provided for custom URL entry.";
            break;
        default:
            val = "Unknown error.";
            break;
    }
    return val;
}