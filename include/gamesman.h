#ifndef _GAMESMAN_H_
#define _GAMESMAN_H_

int version(void);
int curver(void);
int isvalid(void);
int downloader(char *url, char *filen);
int mkneededdirs();
void patchgames(const char *wbfspath, char *wit_exec);

#endif