/* header for version.m */

#import "global.h"

/* Expiry time for this version (set to MAXINT for no expiry) */
// #define EXPIRYTIME	815201999	/* Oct 31, 1995 */
// #define EXPIRYTIME	820472399	/* Dec 31, 1995 */
// #define EXPIRYTIME	825656399	/* Feb 29, 1996 */
#define EXPIRYTIME	MAXINT		/* None */

/* In principle each of these could be "const" routines, using the GNU C
 * extension.  But there are definitely bugs with that usage under NeXT's
 * cc (gcc version 1.93) supplied with NeXTOS 3.0.
 */
const char *projecttitle(void);
const char *versionnumber(void);
const char *versiondate(void);
const char *sourcedir(void);
const char *compilehost(void);
const char *versiontitle(void);
