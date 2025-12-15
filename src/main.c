#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "errors.h"
#include "gamesman.h"
#include "data.h"

void helpmenu(char *appname){
    printf("Usage: %s [--help] [--wit-path path] [--wbfs-path path]\n", appname);
    printf("Options:\n");
    printf("   --wit-path path      The path to the WIT utilities,\n");
    printf("   --wbfs-path path     The path to your wbfs game files\n");
    printf("                        Required if you do not have it set in path or in the specified folder\n");
    printf("   --help               Prints out this menu\n");
    printf("   --init               Makes the needed folders in the current directory\n");
}

int main(int argc, char *argv[]) {
    char *witpath = "wit";
    bool witset = false;
    #ifdef _WIN32
    char *wbfspath = ".\\wbfs";
    #else
    char *wbfspath = "./wbfs";
    #endif
    if (argc == 2) {
        if (strcmp(argv[1], "--help") == 0) {
            helpmenu(argv[0]);
            return 0;
        } else if (strcmp(argv[1], "--init") == 0) {
            mkneededdirs();
            return 0;
        }
    } 
    if (argc == 3 && strcmp(argv[1], "--wit-path") == 0) {
        if (!argv[2] || strcmp(argv[2], "--wbfs-path") == 0) {
            printf("Argument --wit-path is empty\n"); 
            return -1;
        } else {
            printf("Set path for wit to %s\n",argv[2]);
            witpath = argv[2];
            witset = true;
        }
    } else if (argc == 3 && strcmp(argv[1], "--wbfs-path") == 0) {
        if (!argv[2]) {
            printf("Argument --wbfs-path is empty\n");
            return -1;
        } else {
            printf("Set path for wbfs files to %s\n",argv[2]);
            wbfspath = argv[2];
        }
    }
    if (argc == 4 && strcmp(argv[3], "--wbfs-path") == 0) {
        if (!argv[4]) {
            printf("Argument --wbfs-path is empty\n");
            return -1;
        } else {
            printf("Set path for wbfs files to %s\n",argv[2]);
            wbfspath = argv[4];
        }
    }
    printf("Checking dependencies...\n");
    printf(" - Checking for Wit ");
    #ifdef _WIN32
    if (system("wit --help > NUL 2> NUL") != 0) {
    #else
    if (system("wit --help > /dev/null 2> /dev/null") != 0) {
    #endif
        if (witset == true){
            printf("ERROR\nWit is NOT installed in PATH.\nChecking in %s for wit\n", witpath);
            char command[512];
            #ifdef _WIN32
            snprintf(command, sizeof(command), "%s\\bin\\wit.exe --help > NUL 2> NUL", witpath);
            #else
            snprintf(command, sizeof(command), "%s/bin/wit --help > /dev/null 2> /dev/null", witpath);
            #endif
            if (system(command) != 0) { 
                #ifdef _WIN32
                printf("Wit is NOT installed in %s.\nChecking in .\\wit for wit\n", witpath);
                if (system(".\\wit\\bin\\wit.exe --help > NUL 2> NUL") != 0) {
                #else
                printf("Wit is NOT installed in %s.\nChecking in ./wit for wit\n", witpath);
                if (system("./wit/bin/wit --help > /dev/null 2> /dev/null") != 0) {
                #endif
                    #ifdef _WIN32
                    printf("Wit is NOT installed in .\\wit .\nPlease install Wit or extract it in .\\wit .\nIf you do have Wit installed but is not in PATH or .\\wit , specify it with --wit-path and then the path to wit.\n");
                    system("start https://wit.wiimm.de/download.html");
                    #else
                    printf("Wit is NOT installed in ./wit .\nPlease install Wit or extract it in ./wit .\nIf you do have Wit installed but is not in PATH or ./wit , specify it with --wit-path and then the path to wit.\n");
                    system("xdg-open https://wit.wiimm.de/download.html");
                    #endif
                    printf("If your browser did not open, go to https://wit.wiimm.de/download.html to download Wit.\n");
                    return -1;
                }
                #ifdef _WIN32
                witpath = ".\\wit\\bin\\wit.exe";
                #else
                witpath = "./wit/bin/wit";
                #endif
                printf("Found Wit, Continuing...\n");
            } else {
                printf("Found Wit, Continuing...\n");
            }
        } else {
            #ifdef _WIN32
            printf("ERROR\nWit is NOT installed in PATH.\nChecking in .\\wit for wit\n");
            if (system(".\\wit\\bin\\wit.exe --help > NUL 2> NUL") != 0) {
                printf("Wit is NOT installed in .\\wit .\nPlease install Wit or extract it in .\\wit .\nIf you do have Wit installed but is not in PATH or .\\wit , specify it with --wit-path and then the path to wit.\n");
                system("start https://wit.wiimm.de/download.html");
            #else
            printf("ERROR\nWit is NOT installed in PATH.\nChecking in ./wit for wit\n");
            if (system("./wit/bin/wit --help > /dev/null 2> /dev/null") != 0) {
                printf("Wit is NOT installed in ./wit .\nPlease install Wit or extract it in ./wit .\nIf you do have Wit installed but is not in PATH or ./wit , specify it with --wit-path and then the path to wit.\n");
                system("xdg-open https://wit.wiimm.de/download.html");
            #endif
                printf("If your browser didnt open, go to https://wit.wiimm.de/download.html to download Wit\n");
                return -1;
            }
            #ifdef _WIN32
            witpath = ".\\wit\\bin\\wit.exe";
            #else
            witpath = "./wit/bin/wit";
            #endif
            printf("Found Wit, Continuing...\n");
        }
    } else {
        printf("OK\n");
    }
    printf(" - Checking current version ");
    int validver = isvalid();
    if (validver < 0) {
        printf("ERROR\n");
        if (validver == INVALID_VERSION) {
            printf(err2str(validver));
            printf("\n");
            #ifdef _WIN32
            downloader(versionurl, ".\\version.txt");
            downloader(gamesurl, ".\\games.ini");
            #else
            downloader(versionurl, "./version.txt");
            downloader(gamesurl, "./games.ini");
            #endif
            validver = isvalid();
            if (validver < 0) {
                printf("There is an issue with the version.\nPlease delete both version.txt and games.ini and restart the program.\n");
                return -1;
            }
            printf("Got latest version.\n");
        } else if (validver == FILE_NOT_EXIST || validver == FILE_FAIL_OPEN) { 
            printf(err2str(validver));
            printf("\n");
            #ifdef _WIN32
            downloader(versionurl, ".\\version.txt");
            downloader(gamesurl, ".\\games.ini");
            #else
            downloader(versionurl, "./version.txt");
            downloader(gamesurl, "./games.ini");
            #endif
            validver = isvalid();
            if (validver < 0) {
                printf("There is an issue with the version.\nPlease delete both version.txt and games.ini and restart the program.\n");
                return -1;
            }
            printf("Got latest version.\n");
        } else {
            printf(err2str(validver));
            printf("\n");
            return -1;
        }
    } else {
        printf("OK\n");
    }
    patchgames(wbfspath, witpath);
    return 0;
}