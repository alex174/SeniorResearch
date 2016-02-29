// The Santa Fe Stock Market -- Interface for utility functions
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _util_h
#define _util_h

// FILE/DIRECTORY FUNCTIONS
extern const char *cwd(void);
extern const char *homeDirectory(void);
extern const char *fullAppname(const char *argv0);
extern void setPath(const char *argv0, const char *filename);
extern const char *filenamePrefix(void);
extern const char *namesub(const char *filename, const char *extension);

// INPUT FUNCTIONS
extern FILE *openInputFile(const char *filename, const char *filetype);
extern void saveInputFilePointer(void);
extern void restoreInputFilePointer(void);
extern void closeInputFile(void);
extern int gettok(FILE *fp, char *string, int len);
extern int readInt(const char *variable, int minval, int maxval);
extern double readDouble(const char *variable, double minval, double maxval);
extern const char *readString(const char *variable);
extern int readKeyword(const char *variable, const struct keytable *table);
extern int readBitname(const char *variable, const struct keytable *table);

// OUTPUT FUNCTIONS
extern FILE *openOutputFile(const char *filename, const char *filetype,
							BOOL writeheading);
extern void drawLine(FILE *fp, int c);
extern void showint(FILE *fp, const char *name, int value);
extern void showdble(FILE *fp, const char *name, double value);
extern void showstrng(FILE *fp, const char *name, const char *value);
extern void showbarestrng(FILE *fp, const char *name, const char *value);
extern void showbarestrng2(FILE *fp, const char *name1, const char *name2,
							const char *value);
extern void showinputfilename(FILE *fp, const char *name, const char *value);
extern void showoutputfilename(FILE *fp, const char *name, const char *fname,
						    const char *actual_fname);
extern void showsourcefile(FILE *fp, const char *filename);

// MISCELLANEOUS FUNCTIONS
extern void *getmem(unsigned int size);
extern const char *username(void);
extern const char *hostname(void);
extern const char *getDate(BOOL new);
extern void showCPU(const char *when);
extern long stringToLong(const char *string);
extern double stringToDouble(const char *string);
extern int lookup(const char *keyword, const struct keytable *table);
extern const char *findkeyword(int value, const struct keytable *table,
						const char *tablename);

#endif /* _util_h */
