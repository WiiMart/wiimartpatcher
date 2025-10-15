#ifndef _ERRORS_H_
#define _ERRORS_H_

static const int CURL_NOT_INIT = -101;
static const int CURL_FAILED_REQ = -102;
static const int CURL_RES_NOT_VALID = -103;
static const int FILE_FAIL_OPEN = -201;
static const int FILE_NOT_EXIST = -202;
static const int FILE_SEEK_FAIL = -203;
static const int FILE_WRITE_FAIL = -204;
static const int FILE_CLOSE_FAIL = -205;
static const int INVALID_VERSION = -301;
static const int STRING_NOT_FOUND = -401;

extern char ADDRES[256];

const char* err2str(int err);

#endif