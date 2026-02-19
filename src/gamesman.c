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

#define BUILTIN_PAIR_COUNT 7
#define INITIAL_PAIR_CAPACITY 16

typedef struct {
    char  *old_url;
    char  *new_url;
    char  *description;
} url_pair;

typedef struct {
    char gameid[GAMEID_LEN];
    url_pair *pairs;
    size_t    count;
    size_t    capacity;
    int custom_urls_found;
} patch_ini_data;

static url_pair *pairs_append(patch_ini_data *d) {
    if (d->count >= d->capacity) {
        size_t new_cap = d->capacity * 2;
        url_pair *tmp = realloc(d->pairs, new_cap * sizeof(url_pair));
        if (!tmp) return NULL;
        d->pairs    = tmp;
        d->capacity = new_cap;
    }
    url_pair *p = &d->pairs[d->count++];
    p->old_url     = NULL;
    p->new_url     = NULL;
    p->description = NULL;
    return p;
}

static void patch_ini_data_free(patch_ini_data *d) {
    for (size_t i = 0; i < d->count; i++) {
        free(d->pairs[i].old_url);
        free(d->pairs[i].new_url);
        free(d->pairs[i].description);
    }
    free(d->pairs);
    d->pairs    = NULL;
    d->count    = 0;
    d->capacity = 0;
}

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
    size_t old_size = strlen(old_data);

    if (patch_size > old_size) {
        fprintf(stderr, "URL too long: replacement is %zu bytes but original is only %zu bytes.\n", patch_size, old_size);
        fprintf(stderr, "%s\n", err2str(URL_TOO_LONG));
        return URL_TOO_LONG;
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
    for (long i = 0; i <= file_size - (long)old_size; i++) {
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

    printf("  Found the Url's offset.\n");

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

#define MAX_SUFFIX 64

typedef struct {
    char  suffix[MAX_SUFFIX];
    char *old_val;
    char *new_val;
} pending_pair;

typedef struct {
    patch_ini_data *data;
    const char     *target_section; 
    pending_pair   *pending;
    size_t          pending_count;
    size_t          pending_cap;
} ini_cb_ctx;

static const char *builtin_old_suffixes[BUILTIN_PAIR_COUNT] = {
    "url", "testac", "ac", "devac", "testpr", "pr", "devpr"
};

static int builtin_index(const char *suffix) {
    for (int i = 0; i < BUILTIN_PAIR_COUNT; i++) {
        if (strcmp(suffix, builtin_old_suffixes[i]) == 0)
            return i;
    }
    return -1;
}

static pending_pair *get_pending(ini_cb_ctx *ctx, const char *suffix) {
    for (size_t i = 0; i < ctx->pending_count; i++) {
        if (strcmp(ctx->pending[i].suffix, suffix) == 0)
            return &ctx->pending[i];
    }
    if (ctx->pending_count >= ctx->pending_cap) {
        size_t new_cap = ctx->pending_cap ? ctx->pending_cap * 2 : 8;
        pending_pair *tmp = realloc(ctx->pending, new_cap * sizeof(pending_pair));
        if (!tmp) return NULL;
        ctx->pending     = tmp;
        ctx->pending_cap = new_cap;
    }
    pending_pair *p = &ctx->pending[ctx->pending_count++];
    strncpy(p->suffix, suffix, MAX_SUFFIX - 1);
    p->suffix[MAX_SUFFIX - 1] = '\0';
    p->old_val = NULL;
    p->new_val = NULL;
    return p;
}

static int ini_callback(void *user, const char *section, const char *name, const char *value) {
    ini_cb_ctx    *ctx  = (ini_cb_ctx *)user;
    patch_ini_data *data = ctx->data;

    if (strcmp(section, ctx->target_section) != 0)
        return 1;

    int is_old = (strncmp(name, "old", 3) == 0);
    int is_new = (strncmp(name, "new", 3) == 0);
    if (!is_old && !is_new)
        return 1;

    const char *suffix = name + 3;

    if (is_new) {
        int idx = builtin_index(suffix);
        if (idx >= 0) {
            free(data->pairs[idx].new_url);
            data->pairs[idx].new_url = strdup(value);
            data->custom_urls_found  = 1;
        } else {
            pending_pair *pp = get_pending(ctx, suffix);
            if (!pp) return 0;
            free(pp->new_val);
            pp->new_val = strdup(value);
            data->custom_urls_found = 1;
        }
    } else {
        int idx = builtin_index(suffix);
        if (idx >= 0) {
            free(data->pairs[idx].old_url);
            data->pairs[idx].old_url = strdup(value);
            data->custom_urls_found  = 1;
        } else {
            pending_pair *pp = get_pending(ctx, suffix);
            if (!pp) return 0;
            free(pp->old_val);
            pp->old_val = strdup(value);
            data->custom_urls_found = 1;
        }
    }

    return 1;
}

static void flush_pending(ini_cb_ctx *ctx, int is_gameid_pass) {
    patch_ini_data *data = ctx->data;

    for (size_t i = 0; i < ctx->pending_count; i++) {
        pending_pair *pp = &ctx->pending[i];

        if (!pp->old_val || !pp->new_val) {
            if (pp->old_val || pp->new_val) {
                fprintf(stderr,
                    "Warning: extra pair suffix '%s' in [%s] is missing its %s key, skipping.\n",
                    pp->suffix, ctx->target_section,
                    pp->old_val ? "new" : "old");
            }
            free(pp->old_val);
            free(pp->new_val);
            continue;
        }

        if (is_gameid_pass) {
            int found = 0;
            for (size_t j = BUILTIN_PAIR_COUNT; j < data->count; j++) {
                char expected_desc[MAX_SUFFIX + 16];
                snprintf(expected_desc, sizeof(expected_desc), "Extra pair: %s", pp->suffix);
                if (data->pairs[j].description &&
                    strcmp(data->pairs[j].description, expected_desc) == 0) {
                    free(data->pairs[j].old_url);
                    free(data->pairs[j].new_url);
                    data->pairs[j].old_url = pp->old_val;
                    data->pairs[j].new_url = pp->new_val;
                    found = 1;
                    break;
                }
            }
            if (found) continue;
        }

        url_pair *p = pairs_append(data);
        if (!p) {
            fprintf(stderr, "Warning: out of memory adding extra pair '%s', skipping.\n", pp->suffix);
            free(pp->old_val);
            free(pp->new_val);
            continue;
        }
        p->old_url     = pp->old_val;
        p->new_url     = pp->new_val;
        char desc[MAX_SUFFIX + 16];
        snprintf(desc, sizeof(desc), "Extra pair: %s", pp->suffix);
        p->description = strdup(desc);
    }

    free(ctx->pending);
    ctx->pending       = NULL;
    ctx->pending_count = 0;
    ctx->pending_cap   = 0;
}

static int run_ini_pass(patch_ini_data *data, const char *section, int is_gameid_pass) {
    ini_cb_ctx ctx = { data, section, NULL, 0, 0 };
    int ini_ret = ini_parse(GAMES_LIST, ini_callback, &ctx);
    if (ini_ret < 0) return 0; 
    flush_pending(&ctx, is_gameid_pass);
    return 1;
}

static void get_cust_patch(const char *gameid, patch_ini_data *data) {
    memset(data, 0, sizeof(*data));
    strncpy(data->gameid, gameid, GAMEID_LEN - 1);

    data->capacity = INITIAL_PAIR_CAPACITY;
    data->pairs    = calloc(data->capacity, sizeof(url_pair));
    if (!data->pairs) {
        fprintf(stderr, "Out of memory in get_cust_patch.\n");
        return;
    }

    struct { const char *old; const char *new_r; const char *desc; } defaults[BUILTIN_PAIR_COUNT] = {
        { oldurl,     newurl,     "ECS Url"                  },
        { oldtestac,  newtestac,  "Network Connection Url 1" },
        { oldac,      newac,      "Network Connection Url 2" },
        { olddevac,   newdevac,   "Network Connection Url 3" },
        { oldtestpr,  newtestpr,  "Network Connection Url 4" },
        { oldpr,      newpr,      "Network Connection Url 5" },
        { olddevpr,   newdevpr,   "Network Connection Url 6" },
    };
    for (int i = 0; i < BUILTIN_PAIR_COUNT; i++) {
        url_pair *p    = pairs_append(data);
        p->old_url     = strdup(defaults[i].old);
        p->new_url     = strdup(defaults[i].new_r);
        p->description = strdup(defaults[i].desc);
    }

    int general_found = run_ini_pass(data, "GENERAL", 0);

    int gameid_found  = run_ini_pass(data, gameid, 1);

    if (!general_found && !gameid_found) {
        printf("Games.ini has error or is not found. Using default URLs.\n");
    } else if (data->custom_urls_found) {
        printf("Using custom urls in INI file (%zu total pairs)\n", data->count);
        if (general_found && gameid_found)
            printf("  (applied [GENERAL] + [%s]; [%s] takes priority)\n", gameid, gameid);
        else if (general_found)
            printf("  (applied [GENERAL] only)\n");
        else
            printf("  (applied [%s] only)\n", gameid);
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

    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYHOST, 0L);
    
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

    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYHOST, 0L);

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
    if (currver < 0) {
        return currver;
    } else {
        if (ver < 0) {
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
    snprintf(command, sizeof(command), "%s extract \"%s\" --dest \"%s\" --psel=DATA > NUL 2> NUL", 
             wit_exec, wbfsgamepath, extract_dest);
    #else
    snprintf(command, sizeof(command), "%s extract \"%s\" --dest \"%s\" --psel=DATA > /dev/null 2>&1", 
             wit_exec, wbfsgamepath, extract_dest);
    #endif         
    if (system(command) != 0) {
        printf("Fail: could not extract the game.\n");
        patch_ini_data_free(&patch_data);
        return;
    }
    #ifdef _WIN32
        snprintf(dol_file_path, sizeof(dol_file_path), "%s\\sys\\main.dol", extract_dest);
    #else
        snprintf(dol_file_path, sizeof(dol_file_path), "%s/sys/main.dol", extract_dest);
    #endif

    printf("Patching...\n");

    for (size_t i = 0; i < patch_data.count; i++) {
        url_pair *p = &patch_data.pairs[i];
        printf("  - Patching %s...\n", p->description ? p->description : "(unnamed)");

        if (!p->old_url || p->old_url[0] == '\0' || !p->new_url || p->new_url[0] == '\0') {
            fprintf(stderr, "  %s\n", err2str(URL_NOT_PROVIDED));
            patch_errors++;
            continue;
        }

        size_t new_len = strlen(p->new_url);
        int result = str_patch(dol_file_path, p->old_url, p->new_url, new_len);
        
        if (result == 0) {
            patched_count++;
        } else if (result == STRING_NOT_FOUND || result == URL_NOT_FOUND) {
            /* not an error, just not present in this game */
        } else {
            fprintf(stderr, "  Error: %s\n", err2str(result));
            patch_errors++;
        }
    }

    if (patch_errors == 0) {
        printf("Patched without errors %zu strings.\n", patched_count);
    } else {
        printf("Failed to patch %d strings.\n", patch_errors);
    }
    
    patch_ini_data_free(&patch_data);

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