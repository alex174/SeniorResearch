// The Santa Fe Stock Market -- Configuration declarations
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// The file config.h is included in almost every source file via global.h.
// It defines certain preprocessor variables to adapt the code to each
// known architecture.

#ifndef _config_h
#define _config_h

// For Linux
#if defined(__linux__)
#define ERROR_HANDLER_2
#define GETCLASS	objc_get_class
#define RUNTIME_DEFS	<objc/objc-api.h>
#define UNIXLIB		<unistd.h>
#define PATHSEPCHAR     '/'

// For NeXTSTEP
//
// NOTE: For NeXTSTEP using the gcc compiler (rather than ProjectBuilder),
// remove the "-lobjc" from the CCFLAGS definition in "makefile".
// 
#elif defined(__NeXT__)
#define ERROR_HANDLER_1
#define GETCLASS	objc_getClass
#define RUNTIME_DEFS	<objc/objc-runtime.h>
#define UNIXLIB		<libc.h>
#define PATHSEPCHAR     '/'

// Only needed for frontend version
#define APPWRAPPER

// For Solaris
//
#elif defined(__sun__) && defined(__svr4__)
//#define ERROR_HANDLER_3
#define ERROR_HANDLER_2
#define GETCLASS	objc_get_class
#define RUNTIME_DEFS	<objc/objc-api.h>
#define UNIXLIB		<unistd.h>
#define DEFINE_GETHOSTNAME
#define DEFINE_GETRUSAGE
#define PATHSEPCHAR     '/'

// For SunOS 4.x
//
#elif defined(__sun__)
#define __USE_FIXED_PROTOTYPES__
#define ERROR_HANDLER_3
#define GETCLASS	objc_get_class
#define RUNTIME_DEFS	<objc/objc-api.h>
#define UNIXLIB		<unistd.h>
#define DEFINE_GETHOSTNAME
#define DEFINE_GETRUSAGE
#define DEFINE_GETTIMEOFDAY
#define PATHSEPCHAR     '/'

// For DJGPP on MS-DOS, Windows, WindowsNT
//
#elif defined(DJGPP) || defined(CYGWINB20)
#define DOS_FILENAMES
#define ERROR_HANDLER_2
#define GETCLASS	objc_get_class
#define RUNTIME_DEFS	<objc/objc-api.h>
#define UNIXLIB		<unistd.h>
#define PATHSEPCHAR     '\\'

// For ??? on Dec-alphas (Shareen to fix)
//
#elif defined(__alpha__)
#define ERROR_HANDLER_3
#define GETCLASS	objc_get_class
#define RUNTIME_DEFS	<objc/objc-api.h>
#define UNIXLIB		<unistd.h>
#define PATHSEPCHAR     '/'

// Anything else
#else
#error Unrecognized architecture!
// You need to define the appropriate variables (hopefully some variant
// of those above) for your machine.  You can then add an #if defined()
// clause to detect it automatically (use "gcc -v -E config.h" to see
// what special variables are defined by the compiler).

#endif

#endif /* _config_h */



