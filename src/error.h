/* Interface for error routines */

#import <stdarg.h>

/* Constants for debug bitmap; see comments for startup() in control.m */
#define DEBUGWORLD	01
#define DEBUGAGENT	02
#define DEBUGHOLDING	04
#define DEBUGNAMETREE	010
#define DEBUGFILES	020
#define DEBUGTYPES	040
#define DEBUGBROWSER	0100
#define DEBUGCPU	0200
#define DEBUGEVENTS	0400
#define DEBUGDIVIDEND	01000
#define DEBUGMEMORY	02000
#define DEBUGALL	03777

@class Object;

/* Routines.  volatile and __attribute__ are GNU C extensions */
extern void Message(const char *format, ...)
				    __attribute__ ((format (printf, 1, 2)));
extern void objcerror(id obj, const char *myformat, va_list ap);
extern void volatile cerror(const char *routine, const char *format, ...)
				    __attribute__ ((format (printf, 2, 3)));
extern void saveError(const char *format, ...)
				    __attribute__ ((format (printf, 1, 2)));
extern void abandonIfError(const char *routine);
extern void setCurrentFilename(const char *filename, const char *filetype);
extern const char *currentFilename(void);
extern void setDebugBits(const char *keys);
extern const char *debugstring(void);

