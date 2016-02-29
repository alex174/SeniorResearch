// The Santa Fe Stock Market -- Interface for error handling routines
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _error_h
#define _error_h

#include "config.h"
#include <stdarg.h>

// Constants for debug bitmap; see commentis error.m
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
#define DEBUGSPECIALIST	02000
#define DEBUGOUTPUT	04000
#define DEBUGALL	03777

@class Object;

// Routines.
// volatile and __attribute__ are GNU C extensions
extern void message(const char *format, ...)
				    __attribute__ ((format (printf, 1, 2)));
#if defined ERROR_HANDLER_2
extern BOOL objcerror(id obj, int code, const char *format, va_list ap);
#else
extern void objcerror(id obj, const char *format, va_list ap);
#endif
extern void volatile cerror(const char *routine, const char *format, ...)
				    __attribute__ ((format (printf, 2, 3)));
extern void saveError(const char *format, ...)
				    __attribute__ ((format (printf, 1, 2)));
extern void abandonIfError(const char *routine);
extern void setCurrentFilename(const char *filename, const char *filetype);
extern void saveCurrentFilename(void);
extern void restoreCurrentFilename(void);
extern const char *currentFilename(void);
extern void setDebugBits(const char *keys);
extern void writeDebugBits(FILE *fp);
extern const char *debugstring(void);

#endif /* _error_h */
