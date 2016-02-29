// The Santa Fe Stock Market -- main() and error handler for batch version
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This file is only used for the batch version, when there's no graphical
// frontend.  It contains the main() routine and a fatalerror() routine,
// replacing those in Market_main.m and MarketApp.m respectively in the
// frontend version.


// IMPORTS
//
// Note for NextStep only : these includes are NOT handled automatically by
// "make depend" or  ProjectBuilder.  Change the list in Makefile.postamble
// if you change these imports.
//
#include "global.h"
#include <stdlib.h>
#include RUNTIME_DEFS
#include "control.h"
#include "error.h"


int main(int argc, char *argv[])
/*
 * Main program for batch version.
 */
{
// Set the error handler (defined in util.m)
#if defined ERROR_HANDLER_1
    _error = objcerror;
#elif defined ERROR_HANDLER_2
    objc_set_error_handler(objcerror);
#elif defined ERROR_HANDLER_3
    extern void (*_objc_error)(id object, const char *format, va_list);
    _objc_error = objcerror;
#else
#error no ERROR_HANDLER defined
#endif

    marketApp = nil;

// Set up the basic environment (paths, options, run number)
    setEnvironment(argc, argv, NULL);

// Start up the market and agents, initializing everything
    startup();

// Perform any events scheduled for startup
    performEvents();

// Main loop on periods
    while (t < lasttime) {

    // Either perform a fake warmup period or a normal one (increments t)
	if (t < 0)
	    warmup();
	else
	    period();

    // Perform any scheduled events
	performEvents();
    }

// Finish up everything and exit
    finished();
    marketDebug();
    closeall();
    exit(0);
}


void volatile fatalerror(const char * errorstring)
/*
 * Fatal error handling routine -- just writes the message and quits.
 */
{
    fprintf(msgfile,"Fatal error: %s\n", errorstring);
    exit(1);
}

