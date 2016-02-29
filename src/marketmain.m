// Main program and error handler for the batch version.
// Use "make batch" to make.


// Note that these dependencies are NOT handled automatically by
// ProjectBuilder.  Change the list in Makefile.postable if you
// change these imports.
#import "global.h"
#import <stdlib.h>
#ifdef NEXTSTEP
#import <objc/objc-runtime.h>
#else
// extern void (*_objc_error)(id object, const char *format, va_list);
#endif
#import "control.h"
#import "error.h"

int
main(int argc, char *argv[])
{
#ifdef NEXTSTEP
    _error = objcerror;
#else
    // _objc_error = objcerror;
#endif
    marketApp = nil;
    setEnvironment(argc, argv, NULL);
    startup();
    performEvents();
    while (t < lasttime) {
	if (t < 0)
	    warmup();		// Perform a fake warmup period
	else
	    period();		// Perform a normal period
	performEvents();	// Perform any scheduled events
    }
    finished();
    marketDebug();
    closeall();
    return 0;
}


void volatile fatalerror(const char * errorstring)
{
    fprintf(stderr,"Fatal error: %s\n", errorstring);
    exit(1);
}

