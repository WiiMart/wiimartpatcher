#define _POSIX_C_SOURCE 200809L 

#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <strings.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <curl/curl.h>

#include "ini.h"
#include "data.h"   
#include "errors.h"  
#include "gamesman.h" 

typedef struct {
    char gameid[GAMEID_LEN];
    const void *custom_oldurl;
    const void *custom_oldtestac;
    const void *custom_oldac;
    const void *custom_olddevac;
    const void *custom_oldtestpr;
    const void *custom_oldpr;
    const void *custom_olddevpr;
    int custom_urls_found;
} patch_ini_data;

static int patch(const char *filename, long offset, const void *data, size_t size) {
    FILE *file;
    file = fopen(filename, "rb+");
    if (file == NULL) {
        return FILE_FAIL_OPEN;
    }

    if (fseek(file, offset, SEEK_SET) != 0) {
        fclose(file);
        return FILE_SEEK_FAIL;
    }

    if (fwrite(data, 1, size, file) != size) {
        fclose(file);
        return FILE_WRITE_FAIL;
    }

    if (fclose(file) != 0) {
        return FILE_CLOSE_FAIL;
    }

    return 0;
}

static int str_patch(const char *filename, const char *old_data, const void *new_data, size_t patch_size) {
    long offset = -1;
    size_t old_size = strlen(old_data); // Length of the string content to search for

    if (patch_size > old_size) {
        fprintf(stderr, "New Data size is too large. %zu > %zu\n", patch_size, old_size);
        printf("Cannot patch string.\n");
        return FILE_WRITE_FAIL;
    }

    FILE *file = fopen(filename, "rb");
    if (file == NULL) { return FILE_FAIL_OPEN; }
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char *buffer = (char *)malloc(file_size);
    if (!buffer) { fclose(file); return -1; }
    
    if (fread(buffer, 1, file_size, file) != (size_t)file_size) {
        free(buffer); fclose(file); return -1;
    }
    fclose(file);

    char *found_ptr = NULL;
    for (long i = 0; i <= file_size - old_size; i++) {
        if (memcmp(buffer + i, old_data, old_size) == 0) {
            found_ptr = buffer + i;
            break;
        }
    }
    
    if (found_ptr == NULL) {
        printf("  Url not found in file, skipping.\n");
        free(buffer);
        return STRING_NOT_FOUND;
    }

    offset = found_ptr - buffer;
    free(buffer); 

    printf("  Found the Url's offset.\n", old_data, offset);

    if (patch_size > strlen((const char *)new_data)) {
        char *patch_buffer = (char *)malloc(old_size);
        if (!patch_buffer) { return -1; }

        memcpy(patch_buffer, new_data, strlen((const char *)new_data));

        memset(patch_buffer + strlen((const char *)new_data), '\0', old_size - strlen((const char *)new_data));

        int result = patch(filename, offset, patch_buffer, old_size);
        free(patch_buffer);
        return result;
        
    } else {
        return patch(filename, offset, new_data, old_size);
    }
}

static int get_overwrite_url(void* user, const char* section, const char* name, const char* value) {
    patch_ini_data* data = (patch_ini_data*)user;

    if (strcmp(section, data->gameid) == 0) {
        
        #define CHECK_KEY(keyname, varname) \
            if (strcmp(name, keyname) == 0) { \
                data->varname = strdup(value); \
                data->custom_urls_found = 1; \
                return 1;  \
            }
        
        CHECK_KEY("oldurl", custom_oldurl);
        CHECK_KEY("oldtestac", custom_oldtestac);
        CHECK_KEY("oldac", custom_oldac);
        CHECK_KEY("olddevac", custom_olddevac);
        CHECK_KEY("oldtestpr", custom_oldtestpr);
        CHECK_KEY("oldpr", custom_oldpr);
        CHECK_KEY("olddevpr", custom_olddevpr);
        
        #undef CHECK_KEY
    }
    
    return 0;
}

static void get_cust_patch(const char *gameid, patch_ini_data *data) {
    
    strncpy(data->gameid, gameid, GAMEID_LEN);
    data->custom_urls_found  = 0;
    
    data->custom_oldurl      = newurl;
    data->custom_oldtestac   = newtestac;
    data->custom_oldac       = newac;
    data->custom_olddevac    = newdevac;
    data->custom_oldtestpr   = newtestpr;
    data->custom_oldpr       = newpr;
    data->custom_olddevpr    = newdevpr;

    if (ini_parse(GAMES_LIST, get_overwrite_url, data) < 0) {
        printf("Games.ini has error or is not found. Using default URLs.\n");
    }
    
    if (data->custom_urls_found) {
        printf("Using custom urls in INI file\n");
    } else {
        printf("Using Default URL's\n");
    }
}


typedef struct {
  char *memory;
  size_t size; 
} MemoryStruct;

static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    MemoryStruct *mem = (MemoryStruct *)userp;

    char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    
    if (ptr == NULL) {
        return 0; 
    }

    mem->memory = ptr;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = '\0'; 

    return realsize;
}

int downloader(char *url, char *filen) {
    CURL *curl_handle;
    CURLcode res;
    int return_code = 0;

    MemoryStruct chunk; 
    chunk.memory = malloc(1);
    chunk.size = 0;

    curl_handle = curl_easy_init();
    if (!curl_handle) {
        return_code = CURL_NOT_INIT;
        goto cleanup;
    }

    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
    
    res = curl_easy_perform(curl_handle);

    if (res != CURLE_OK) {
        strncpy(ADDRES, curl_easy_strerror(res), sizeof(ADDRES) - 1);
        return_code = CURL_FAILED_REQ;
        goto cleanup;
    }
    
    if (chunk.size == 0) {
        return_code = CURL_RES_NOT_VALID;
        goto cleanup;
    }
    
    FILE *fp = fopen(filen, "w");
    if (fp == NULL) {
        return_code = FILE_FAIL_OPEN;
        goto cleanup;
    }
    
    if (fwrite(chunk.memory, 1, chunk.size, fp) != chunk.size) {
        return_code = FILE_WRITE_FAIL;
    }

    if (fclose(fp) != 0) {
        return_code = FILE_CLOSE_FAIL;
    }
    
cleanup:
    if (chunk.memory) {
        free(chunk.memory);
    }
    if (curl_handle) {
        curl_easy_cleanup(curl_handle);
    }
    return return_code;
}

int curver(void) {
    CURL *curl_handle;
    CURLcode res;
    int version_num = -1;

    MemoryStruct chunk; 
    chunk.memory = malloc(1);
    chunk.size = 0;
    if (chunk.memory == NULL) return -1; 

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl_handle = curl_easy_init();

    if (!curl_handle) {
        curl_global_cleanup();
        free(chunk.memory);
        return CURL_NOT_INIT;
    }

    curl_easy_setopt(curl_handle, CURLOPT_URL, versionurl);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk); 

    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYHOST, 2L);

    res = curl_easy_perform(curl_handle);

    if (res != CURLE_OK) {
        strncpy(ADDRES, curl_easy_strerror(res), sizeof(ADDRES) - 1);
        ADDRES[sizeof(ADDRES) - 1] = '\0';
        version_num = CURL_FAILED_REQ;
    } else {
        if (chunk.size > 0 && sscanf(chunk.memory, "%d", &version_num) == 1) {

        } else {
            version_num = CURL_RES_NOT_VALID;
        }
    }

    curl_easy_cleanup(curl_handle);
    curl_global_cleanup();
    free(chunk.memory); 

    return version_num;
}

int version(void) {
    FILE *file;
    #ifdef _WIN32
    file = fopen(".\\version.txt", "r");
    #else
    file = fopen("./version.txt", "r");
    #endif
    if (!file) {
        return FILE_FAIL_OPEN;
    }
    char ver[100];
    int vers = FILE_NOT_EXIST; 
    if (fgets(ver, 100, file) != NULL) {
        vers = atoi(ver);
    }
    fclose(file);
    return vers;
}

int isvalid(void) {
    int ver = curver();
    int currver = version();
    if (ver < 0) {
        return ver;
    } else {
        if (currver < 0) {
            return currver;
        }
        if (ver != currver) {
            return INVALID_VERSION;
        }
    }
    return 0;
} 

#ifdef _WIN32
const char *needyfucks[] = {
    ".\\wbfs",    
    ".\\wit",     
    ".\\final",    
    ".\\data",
};
#else
const char *needyfucks[] = {
    "./wbfs",    
    "./wit",     
    "./final",    
    "./data",
};
#endif


int makedirifmissing(const char *path) {
    #ifdef _WIN32
        if (mkdir(path) == 0) {
            return 0;
        }
    #else
        if (mkdir(path, 0755) == 0) {
            return 0;
        }
    #endif
    if (errno != EEXIST) {
        return -1;
    }
    return 0;
}

int mkneededdirs() {
    size_t num_dirs = sizeof(needyfucks) / sizeof(needyfucks[0]);
    int you_failure = 0;

    for (size_t i = 0; i < num_dirs; i++) {
        if (makedirifmissing(needyfucks[i]) != 0) {
            you_failure++;
        }
    }

    if (you_failure > 0) {
        printf("Failed to make %d dirs.\n", you_failure);
        return -1;
    }

    return 0;
}


int getgameid(const char *wbfsgamepath, char *gameid_buffer, char *witexec_path) {
    char command[MAX_PATH * 2];
    FILE *fp;
    
    snprintf(command, sizeof(command), "%s id \"%s\"", witexec_path, wbfsgamepath);
    
    fp = popen(command, "r");
    if (fp == NULL) return -1;
    
    if (fgets(gameid_buffer, GAMEID_LEN, fp) != NULL) {
        gameid_buffer[strcspn(gameid_buffer, "\n\r")] = '\0'; 
    }
    
    pclose(fp);
    
    if (strlen(gameid_buffer) == 6) {
        return 0;
    }
    
    return -1;
}

void patchgame(const char *wbfsgamepath, char *wit_exec) {
    char game_id[GAMEID_LEN];
    char extract_dest[MAX_PATH];
    char dol_file_path[MAX_PATH];
    char command[MAX_PATH * 2];
    patch_ini_data patch_data = {0};
    int patch_errors = 0;
    size_t patched_count = 0;
    
    if (getgameid(wbfsgamepath, game_id, wit_exec) != 0) {
        printf("Fail: Not a game.\n");
        return;
    }
    printf("ID: %s\n", game_id);

    get_cust_patch(game_id, &patch_data);
    
    #ifdef _WIN32
        snprintf(extract_dest, sizeof(extract_dest), ".\\data\\%s", game_id);
    #else
        snprintf(extract_dest, sizeof(extract_dest), "./data/%s", game_id);
    #endif

    printf("Extracting...\n");
    
    #ifdef _WIN32
    snprintf(command, sizeof(command), "%s extract \"%s\" --dest \"%s\" > NUL 2> NUL", 
             wit_exec, wbfsgamepath, extract_dest);
    #else
    snprintf(command, sizeof(command), "%s extract \"%s\" --dest \"%s\" > /dev/null 2>&1", 
             wit_exec, wbfsgamepath, extract_dest);
    #endif         
    if (system(command) != 0) {
        printf("Fail: could not extract the game.\n");
        return;
    }
    #ifdef _WIN32
        snprintf(dol_file_path, sizeof(dol_file_path), "%s\\sys\\main.dol", extract_dest);
    #else
        snprintf(dol_file_path, sizeof(dol_file_path), "%s/sys/main.dol", extract_dest);
    #endif

    printf("Patching...\n");
    struct {
        const char *original;
        const void *replacement;
        size_t size;
        const char *description;
    } patches[] = {
        { oldurl,      patch_data.custom_oldurl,     sizeof(newurl),     "ECS Url" },
        { oldtestac,   patch_data.custom_oldtestac,  sizeof(newtestac),  "Network Connection Url 1" },
        { oldac,       patch_data.custom_oldac,      sizeof(newac),      "Network Connection Url 2" },
        { olddevac,    patch_data.custom_olddevac,   sizeof(newdevac),   "Network Connection Url 3" },
        { oldtestpr,   patch_data.custom_oldtestpr,  sizeof(newtestpr),  "Network Connection Url 4" },
        { oldpr,       patch_data.custom_oldpr,      sizeof(newpr),      "Network Connection Url 5" },
        { olddevpr,    patch_data.custom_olddevpr,   sizeof(newdevpr),   "Network Connection Url 6" },
    };

    size_t num_patches = sizeof(patches) / sizeof(patches[0]);

    for (size_t i = 0; i < num_patches; ++i) {
        printf("  - Patching %s...\n", patches[i].description);
        int result = str_patch(dol_file_path, patches[i].original, patches[i].replacement, patches[i].size);
        
        if (result == 0) {
            patched_count++;
        } else if (result != STRING_NOT_FOUND) {
            patch_errors++;
        }
    }


    if (patch_errors == 0) {
        printf("Patched without errors %zu strings.\n", patched_count);
    } else {
        printf("Failed to patch %d strings.\n", patch_errors);
    }
    
    if (patch_data.custom_urls_found) {
        if (patch_data.custom_oldurl != newurl) free((void*)patch_data.custom_oldurl);
        if (patch_data.custom_oldtestac != newtestac) free((void*)patch_data.custom_oldtestac);
        if (patch_data.custom_oldac != newac) free((void*)patch_data.custom_oldac);
        if (patch_data.custom_olddevac != newdevac) free((void*)patch_data.custom_olddevac);
        if (patch_data.custom_oldtestpr != newtestpr) free((void*)patch_data.custom_oldtestpr);
        if (patch_data.custom_oldpr != newpr) free((void*)patch_data.custom_oldpr);
        if (patch_data.custom_olddevpr != newdevpr) free((void*)patch_data.custom_olddevpr);
    }

    if (patch_errors > 0) return;

    printf("Re-Compressing...\n");
    char final_path[MAX_PATH];
    #ifdef _WIN32
        snprintf(final_path, sizeof(final_path), ".\\final\\%s-patched.wbfs", game_id);
    #else
        snprintf(final_path, sizeof(final_path), "./final/%s-patched.wbfs", game_id);
    #endif
    
    #ifdef _WIN32
    snprintf(command, sizeof(command), "%s copy \"%s\" \"%s\" > NUL 2> NUL", 
             wit_exec, extract_dest, final_path);
    #else
    snprintf(command, sizeof(command), "%s copy \"%s\" \"%s\" > /dev/null 2>&1", 
             wit_exec, extract_dest, final_path);
    #endif         
    if (system(command) != 0) {
        printf("Fail: Could not re-compress.\n");
        return;
    }

    #ifdef _WIN32
    snprintf(command, sizeof(command), "RD /S /Q \"%s\"", extract_dest);
    #else
    snprintf(command, sizeof(command), "rm -rf \"%s\"", extract_dest);
    #endif
    system(command);
}

void patchgames(const char *wbfspath, char *wit_exec) {
    DIR *dir;
    struct dirent *entry;
    
    dir = opendir(wbfspath);
    if (!dir) {
        fprintf(stderr, "Dir %s not found.\n", wbfspath);
        return;
    }

    printf("\nStarting to patch the games...\n");

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        size_t name_len = strlen(entry->d_name);
        if (name_len > 4 && (strcasecmp(entry->d_name + name_len - 5, ".wbfs") == 0 || 
                             strcasecmp(entry->d_name + name_len - 4, ".iso") == 0)) {
            
            char full_wbfs_path[MAX_PATH];
            #ifdef _WIN32
                snprintf(full_wbfs_path, sizeof(full_wbfs_path), "%s\\%s", wbfspath, entry->d_name);
            #else
                snprintf(full_wbfs_path, sizeof(full_wbfs_path), "%s/%s", wbfspath, entry->d_name);
            #endif
            
            printf("File: %s\n", entry->d_name);
            patchgame(full_wbfs_path, wit_exec);
            printf("------------------\n");
        }
    }

    closedir(dir);
    printf("All done!\n");
}
