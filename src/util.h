// The Santa Fe Stockmarket -- Interface for utility functions

#ifdef NEXTSTEP
#import <objc/zone.h>
#define GETMEM(x)	getmemFromZone(zone,x)
#else
#define GETMEM(x)	getmem(x)
#endif

extern const char *getDate(BOOL new);
extern void showCPU(const char *when);
extern void *getmem(unsigned int size);
#ifdef NEXTSTEP
extern void *getmemFromZone(NXZone *zone, unsigned int size);
#endif
extern unsigned int totalMemory(void);
extern void setPath(const char *argv0, const char *filename);
extern FILE *OpenInputFile(const char *filename, const char *filetype);
extern const char *filenamePrefix(void);
extern const char *fullAppname(const char *argv0);
extern const char *cwd(void);
extern const char *homeDirectory(void);
extern const char *username(void);
extern int stringToInt(const char *string);
extern double stringToDouble(const char *string);
extern int ReadInt(const char *variable, int minval, int maxval);
extern double ReadDouble(const char *variable, double minval, double maxval);
extern const char *ReadString(const char *variable);
extern int ReadKeyword(const char *variable, const struct keytable *table);
extern int ReadBitname(const char *variable, const struct keytable *table);
extern int lookup(const char *keyword, const struct keytable *table);
extern const char *findkeyword(int value, const struct keytable *table, 
						const char *tablename);
extern void CloseInputFile(void);
extern int gettok(FILE *fp, char *string, int len);
extern FILE *openOutputFile(const char *filename, BOOL writeheading);
extern const char *namesub(const char *name, const char *extension);
extern void drawLine(FILE *fp, int c);
extern void showint(FILE *fp, const char *name, int value);
extern void showdble(FILE *fp, const char *name, double value);
extern void showstrng(FILE *fp, const char *name, const char *value);
extern void showbarestrng(FILE *fp, const char *name, const char *value);
extern void showinputfilename(FILE *fp, const char *name, const char *value);
extern void showoutputfilename(FILE *fp, const char *name, const char *fname,
						    const char *actual_fname);
extern void showsourcefile(FILE *fp, const char *filename);

double median();
double rint();
