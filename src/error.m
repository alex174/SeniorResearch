// The Santa Fe Stockmarket -- Implementation of error handling routines

// These methods and functions are used to process all errors, warnings,
// and debugging messages.  The Message() function is used for anything
// non-fatal, and writes an error to "msgfile", which is defined here to
// be stderr.  Fatal errors use one of:
//
// 1. For objects: [self error:...].  This results in a call to objerror()
//    in this module, since we reset "_error" (a NeXTSTEP global). 
//    NEEDS FIXING FOR gcc ObjC
//
// 2. For non-objects: cerror(...).
//
// Both of these result in a call to commonerror() in this file.  This
// massages the error and then calls fatalerror(), which is in
// MarketApp.m (for the display version) or marketmain.m (for the batch
// version).  That puts up a "Fatal Error" panel if possible, or writes a
// message to "msgfile".
//
// During processing of an input file it is desirable to collect errors
// and list them all at the end, rather than stopping on the first one
// found.  The saveError() and abandonIfError() functions accomplish this.

// PUBLIC FUNCTIONS AND METHODS
//
// Message(format, ...)
//	Writes a message to msgfile, prepending the time.  Syntax is
//	just like printf().  Output is suppressed if "quiet" is set unless
//	format starts with a "*".
//
// - error:format, ...
//	This is Object's error method, but actally generates a call to
//	objcerror() in this file.  It can be sent to any object.  Syntax
//	like printf() following the "error:".  Produces a fatal error
//	message and terminates the program.  This may also be used
//	automatically by the run-time system.
//
// cerror(routinename, format, ...)
//	Another way to produce a fatal error message and termination, for
//	non-object callers.  "routinename" should be the name of the
//	routine reporting the error; the remaining arguments are like
//	printf()'s.
//
// saveError(format, ...)
//	Saves an error message (printf() syntax) for future use by
//	abandonIfError().
//
// abandonIfError(routinename)
//	Produces a fatal error message and terminates the program if
//	there were any previous calls to saveError().  Includes the
//	text of the messages sent to saveError().  "routinename" should be
//	the name of the routine reporting the error, or "[Class method]"
//	for  method.
//
// setCurrentFilename(filename, filetype)
//	Stores a filename and type (string saying what it's for) to
//	mention in any future fatal error message.  A filetype argument
//	of NULL (or an empty filetype string) disables any such mention.
//	A filename of NULL (or an empty filename string) leaves the
//	previous stored filename unchanged.
//
// const char *currentFilename(void)
//	Returns the last filename stored by setCurrentFilename, or NULL
//	if none. 
//
// void setDebugBits(const char *keys)
//	Or's the appropriate bits into "debug" for the single characters
//	appearing in keys.  Uses saveError() for unknown keys. 

// GLOBAL VARIABLES
//
// int t
//	Current time: used in error messages.
//
// FILE *msgfile
//	Output file pointer for error messages etc.  This is defined below
//	as stderr.  stderr is never used directly.
//
// int debug
//	Debugging code bitmap -- different bits are used for different options.
//	See error.h.
//
// BOOL quiet
//	If YES, Message() suppresses its output unless the message starts
//	with '*'.

// NOTES
//
// 1. In all cases, the message produced by printf()-like arguments has
//    a \n appended to it automatically if it doesn't already end in one.
//    Message() appends a \n even if there already is one.
//
// 2. Multi-line messages (with internal \n's) are permitted.   
//
// 3. Several functions here use the "volatile" attribute to imply that
//    they never return.  This is a GNU C extension.

// IMPORTS
#import "global.h"
#import "error.h"
#import <stdlib.h>
#import <string.h>
#import "Agent.h"
#import "util.h"

// External routines
extern void volatile fatalerror(const char *);	// Different in app and batch

// Global variables defined here
// FILE *msgfile = stderr;
int debug = 0;
BOOL quiet = NO;

// Local variables
static int errcnt;
static char *currentfilename;
static char *currentfiletype;

// Buffer for errors.  We assume this is large enough...
#define EBUFSIZE	1024
static char errorbuf[EBUFSIZE];
static char *ebufptr = errorbuf;

// Local routines
static void volatile commonerror(const char *type, const char *name,
					const char *format, va_list ap);


/*------------------------------------------------------*/
/*	Message						*/
/*------------------------------------------------------*/
void Message(const char *format, ...)
/*
 * Handles warning and debugging messages other than fatal errors.  Syntax
 * like printf().  The messages are written to msgfile, prefixed by the
 * time unless it's MININT.  The -q (quiet) option suppresses all messages
 * except those with '*' as the first character.  By convention, messages have
 * the following prefixes:
 *    ***   Non-fatal error
 *    >>>   Information (not an error)
 *    *x:   Non-fatal Error detected by debugging option -dx
 *    #x:   Information (not an error) produced by debugging option -dx
 */
{
    va_list args;

    if (!quiet || *format == '*') {
	if (t != MININT)
	    fprintf(stderr,"%6d ",t);
	else
	    fprintf(stderr,"       ");
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
	putc('\n', stderr);
    }
}


/*------------------------------------------------------*/
/*	objcerror					*/
/*------------------------------------------------------*/
void objcerror(id anObject, const char *format, va_list ap)
/*
 * Called by runtime system for messages to "error:" etc, and for errors 
 * generated internally by the runtime system.
 */
{
    id sender = anObject;

    if ([sender isKindOf:[Agent class]])
	commonerror("agent", [sender shortname], format, ap);
    else
	commonerror("object", [sender name], format, ap);
   /*NOTREACHED*/
}


/*------------------------------------------------------*/
/*	cerror						*/
/*------------------------------------------------------*/
void volatile cerror(const char *routine, const char *format, ...)
/*
 * Used by non-object portions of the code to report fatal
 * errors.  Usage: cerror("routinename", "format", ...).
 */
{
    va_list args;

    va_start(args, format);
    commonerror((*routine == '['? "method": "routine"), routine, format, args);
    /*NOTREACHED*/
}


/*------------------------------------------------------*/
/*	commonerror					*/
/*------------------------------------------------------*/
static void volatile commonerror(const char *type, const char *name,
					const char *format, va_list ap)
/*
 * Common path for all errors.
 */
{
    static int recursioncount = 0;

    if (recursioncount++) {
	*ebufptr = EOS;
	fprintf(stderr,"\nRecursive error: %s\n", errorbuf);
	exit(1);
    }

// Put the main error message into our error buffer, append \n if none
    vsprintf(ebufptr, format, ap);
    ebufptr += strlen(ebufptr);
    if (*(ebufptr-1) != '\n') *ebufptr++ = '\n';
    va_end(ap);

// Append some additional information
    if (currentfiletype && currentfilename) {
	sprintf(ebufptr, "\nFilename: %s\n", currentfilename);
	ebufptr += strlen(ebufptr);
	if (linenumber > 0) {
	    sprintf(ebufptr, "Line: %d\n", linenumber);
	    ebufptr += strlen(ebufptr);
	}
    }
    if (t == MININT)
	sprintf(ebufptr, "\nError reported by %s %s during startup",
								type, name);
    else
	sprintf(ebufptr, "\nError reported by %s %s at time %d",
								type, name, t);
    ebufptr += strlen(ebufptr);
    *ebufptr = EOS;
    
    if (debug&DEBUGMEMORY && !quiet)
	Message("#m: errorbuf usage: %d/%d", ebufptr-errorbuf+1, EBUFSIZE);

// Pass the error upstairs.  A different fatalerror() routine is
// linked into the program depending on whether we have a GUI
// interface or not.  fatalerror() should not return.  
    fatalerror(errorbuf);
    /*NOTREACHED*/
}


/*------------------------------------------------------*/
/*	saveError					*/
/*------------------------------------------------------*/
void saveError(const char *format, ...)
/*
 * Saves an error message in a buffer while error checking continues.
 * Note: Under NextStep this was done with a memory buffer using
 * NXOpenMemory() etc, but we switched to a fixed buffer for gcc.
 */
{
    va_list args;

    ++errcnt;	/* count errors */
    if (errcnt == 1 && currentfiletype) {
	sprintf(ebufptr, "Error(s) in %s file:\n\n", currentfiletype);
	ebufptr += strlen(ebufptr);
    }
    if (linenumber > 0) {
	sprintf(ebufptr, "Line %d: ", linenumber);
	ebufptr += strlen(ebufptr);
    }
    va_start(args, format);
    vsprintf(ebufptr, format, args);
    va_end(args);
    ebufptr += strlen(ebufptr);
    if (*(ebufptr-1) != '\n') *ebufptr++ = '\n';
}


/*------------------------------------------------------*/
/*	abandonIfError					*/
/*------------------------------------------------------*/
void abandonIfError(const char *routine)
/*
 * Generates an error if saveError was called previously.
 */
{
    if (!errcnt) {
	setCurrentFilename(NULL, NULL);	// Since used on completing a file
	return;
    }

    cerror(routine, "\nAbandoned due to above error%s\n", (errcnt>1?"s":""));
    /*NOTREACHED*/
}


/*------------------------------------------------------*/
/*	setCurrentFilename				*/
/*------------------------------------------------------*/
void setCurrentFilename(const char *filename, const char *filetype)
/*
 * Stores a filename and type (string saying what it's for) to
 * mention in any future error (but not warning) message.  A
 * filetype argument of NULL disables any such mention.  A filename
 * of NULL leaves the previous stored filename unchanged.
 */
{
    if (currentfiletype)
	free((void *)currentfiletype);
    if (filetype && *filetype != EOS) {
	currentfiletype = (char *)getmem(sizeof(char)*(strlen(filetype)+1));
	strcpy(currentfiletype, filetype);
    }
    else
	currentfiletype = NULL;

    if (filename && *filename != EOS) {
	if (currentfilename)
	    free((void *)currentfilename);
	currentfilename = (char *)getmem(sizeof(char)*(strlen(filename)+1));
	strcpy(currentfilename, filename);
    }
}


/*------------------------------------------------------*/
/*	currentFilename					*/
/*------------------------------------------------------*/
const char *currentFilename(void)
{
    return currentfilename;
}


void setDebugBits(const char *keys)
{
    register int c;
    
    while ((c= *keys++) != EOS) {
	switch (c) {
	case 'a': debug |= DEBUGAGENT; break;
	case 'b': debug |= DEBUGBROWSER; break;
	case 'c': debug |= DEBUGCPU; break;
	case 'd': debug |= DEBUGDIVIDEND; break;
	case 'e': debug |= DEBUGEVENTS; break;
	case 'f': debug |= DEBUGFILES; break;
	case 'h': debug |= DEBUGHOLDING; break;
	case 'm': debug |= DEBUGMEMORY; break;
	case 'n': debug |= DEBUGNAMETREE; break;
	case 't': debug |= DEBUGTYPES; break;
	case 'w': debug |= DEBUGWORLD; break;
	case 'A':
	case '#': debug = DEBUGALL; break;
	case '0': break;
	default: saveError("Invalid debugging option: '%c'", c);
	}
    }
}


const char *debugstring(void)
{
    static char buf[16];
    char *ptr;
    
    ptr = buf;
    if (debug&DEBUGAGENT) *ptr++ = 'a';
    if (debug&DEBUGBROWSER) *ptr++ = 'b';
    if (debug&DEBUGCPU) *ptr++ = 'c';
    if (debug&DEBUGDIVIDEND) *ptr++ = 'd';
    if (debug&DEBUGEVENTS) *ptr++ = 'e';
    if (debug&DEBUGFILES) *ptr++ = 'f';
    if (debug&DEBUGHOLDING) *ptr++ = 'h';
    if (debug&DEBUGMEMORY) *ptr++ = 'm';
    if (debug&DEBUGNAMETREE) *ptr++ = 'n';
    if (debug&DEBUGTYPES) *ptr++ = 't';
    if (debug&DEBUGWORLD) *ptr++ = 'w';

    if (ptr == buf) *ptr++ = '0';
    *ptr = EOS;
    return buf;
}
