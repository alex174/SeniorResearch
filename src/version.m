// The Santa Fe Stock Market -- Implementation of versioning routines
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// These routines provide version information for use in the header of
// output files (and in the Info panel if the frontend is used).  The
// version number and version date are intended to be updated automatically
// each time the source is compiled.  This works if you use the makefile,
// which calls the "newversion" script to edit this file.

// FUNCTIONS
//
// const char *versionnumber(void)
//	A version number such as 6.22.123, with B appended for batch versions
//	and D appended if it was compiled with DEBUG set.
//
// const char *versiondate(void)
//	The date on which this version was compiled.
//
// GLOBAL VARIABLES USED
//
// id marketApp
//	Non-nil for the frontend version, nil otherwise.

#include "global.h"
#include "version.h"
#include <string.h>

// The following definition is updated automatically by "newversion"
#define VERSIONNUMBER	"7.1.2"

#define VERSIONDATE	__DATE__

#define VBUFLEN	16

const char *versionnumber(void)
{
    static char buf[VBUFLEN] = "";

    if (buf[0] == EOS) {
	strncpy(buf, VERSIONNUMBER, VBUFLEN-2);
	buf[VBUFLEN-3] = EOS;
	if (marketApp)
	    strcat(buf, "F");
#ifdef DEBUG
	strcat(buf, "D");
#endif
    }
    return buf;
}

const char *versiondate(void)
{
    static const char *vdate = VERSIONDATE;
    if (strlen(vdate) > 11)
	return vdate+4;	// Skip day of week if present
    else
	return vdate;
}






















