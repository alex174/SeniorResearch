// Routine to get version information

// This information appears in the header of output files and/or in
// the Info panel.  Some parameters are updated automatically by the
// make file.  Note that there's also an expiry date set in the
// version.h file.

// This is written as a set of simple functions rather than using compile-time
// strings directly so that only this file has to be recompiled each time
// the version information changes. 

#import "global.h"
#import "version.h"
#import <string.h>


// The following definitions are updated automatically at each make.
#define VERSIONNUMBER	"6.21.26"
#define SOURCEDIR	"/home/pauljohn/swarm/PJProjects/sourceforge/Real_sfsm/src"
#define COMPILEHOST	"pauljohn@pjdell"

#define VERSIONDATE	__DATE__
#define	PROJECTTITLE	"The Santa Fe Stockmarket"

const char *projecttitle(void) { return PROJECTTITLE; }

const char *versionnumber(void)
{
    static char buf[12] = "";
    extern char *strcat(), *strcpy();

    if (buf[0] == EOS) {
	strcpy(buf, VERSIONNUMBER);
	if (!marketApp)
	    strcat(buf, "B");
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
	return vdate+4;	/* Skip day of week if present */
    else
	return vdate;
}

const char *sourcedir(void) { return SOURCEDIR; }

const char *compilehost(void) { return COMPILEHOST; }


// The versiontitle() is the text for the boldface copyright notice.  This is
// wrapped as needed, but explicit newlines (\n) may also be included.  The
// height of the Info panel is adjusted to accomodate the text.

const char *versiontitle(void)
{
    return "Copyright (C) 1995 Santa Fe Institute.";
}
