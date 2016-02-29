/* Interface for control.m */

#import <objc/objc.h>

extern void setEnvironment(int argc, char *argv[], const char *filename);
extern void startup(void);
extern void warmup(void);
extern void period(void);
extern void performEvents();
extern void finished(void);
extern void closeall(void);
extern void marketDebug(void);

