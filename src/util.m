// The Santa Fe Stockmarket -- Implementation for utility functions

// IMPORTS
#import "global.h"
#import "util.h"
#import <stdlib.h>
#import <string.h>
#import <ctype.h>
#import <pwd.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <sys/param.h>
#import <sys/time.h>
#import <sys/resource.h>
#import <unistd.h>
#import <time.h> //for ctime

#ifdef NEXTSTEP
#import <libc.h>
#import <streams/streams.h>
#import <objc/zone.h>
#else
// Should be in libc.h, but not in gcc?
extern uid_t	getuid(void);
// extern int	gethostname(char *, int);
extern int	getrusage(int, struct rusage *);
extern int	gettimeofday(struct timeval *, struct timezone *);
#endif
#import "World.h"
#import "error.h"
#import "version.h"

// Limit on malloc size -- just to catch errors
#define MAXMEMREQUEST	1048576

// This file also implements a timeout bomb; it'll bomb with some
// obscure error if the last-access or inode-change time of any input
// file is greater than the value of EXPIRYTIME.  The bomb is created
// by having getmem() return less memory than requested, so overwrites
// follow.  This is further randomized (based on the time), so the
// details of the fault vary.  This mechanism is decoupled considerably
// from the "Expired" warning panel, to defeat simple binary patching.

/* Local variables */
static FILE *pfp = NULL;
static const char *filenameprefix = NULL;
static const char *fullappname = NULL;
static const char *workingdir = NULL;
static const char *dateandtime = NULL;
static char hostname[MAXHOSTNAMELEN+1] = "";
static struct passwd *p_passwd = NULL;
static unsigned int totalmalloc = 0;

static unsigned int latesttime;


/*------------------------------------------------------*/
/*	getDate						*/
/*------------------------------------------------------*/
const char *getDate(BOOL new)
/*
 * Returns a date/time string (in malloc'd memory).  Always returns
 * the same value unless "new" is YES.
 */
{
    static const char *dtmem = NULL;
    char *dt;
    time_t time();
    time_t timeval = time((time_t *)0);

    unsigned int tnow = (unsigned int)(timeval>>3);
    if (tnow > latesttime) latesttime = tnow;
  
    if (!dtmem || new) {
	dt = ctime(&timeval);
	dtmem = strcpy((char *)getmem(sizeof(char)*(strlen(dt)+1)), dt);
    }
    return dtmem;
}


/*------------------------------------------------------*/
/*	showCPU						*/
/*------------------------------------------------------*/
void showCPU(const char *when)
/*
 * Displays cpu time used so far, using Message().  "when" is an
 * identifying prefix.
 */
{
    struct rusage used;
    struct timeval thetime;
    double usertime, systtime, walltime, udelta, sdelta, wdelta;
    static double uprev, sprev, wprev;
    static double firstwall = 0.0;
    static BOOL haveprev = NO;

    getrusage(RUSAGE_SELF, &used);
    usertime = 1e-6*used.ru_utime.tv_usec +  used.ru_utime.tv_sec;
    systtime = 1e-6*used.ru_stime.tv_usec +  used.ru_stime.tv_sec;
    gettimeofday(&thetime, NULL);
    walltime = 1e-6*thetime.tv_usec +  thetime.tv_sec - firstwall;
    if (haveprev) {
	udelta = usertime - uprev;
	sdelta = systtime - sprev;
	wdelta = walltime - wprev;
	Message("#c: %-14s user:%5.1f +%-4.1f sys:%4.1f +%-4.1f"
	" wall:%5.1f +%-4.1f",
	    when, usertime, udelta, systtime, sdelta, walltime, wdelta);
    }
    else {
	Message("#c: %-14s user:%5.1f       sys:%4.1f",
	    when, usertime, systtime);
	firstwall = walltime;
	walltime = 0.0;
    }
    uprev = usertime;
    sprev = systtime;
    wprev = walltime;
    haveprev = YES;
}


/*------------------------------------------------------*/
/*	getmem						*/
/*------------------------------------------------------*/
void *getmem(unsigned int size)
/*
 * malloc with error check
 */
{
    void *ans;
    static unsigned int bit = 1;

/* Maybe plant a bomb if program is expired; randomized by time */
    bit <<= 1;
    if (latesttime > (EXPIRYTIME>>3) && size > 100 && !(latesttime&bit))
	size -= 16;	/* bomb: return less memory than requested */
    
    if (size <= 0 || size > MAXMEMREQUEST)
	cerror("getmem", "Illegal malloc request: %u", size);
    if ((ans = malloc(size)) == NULL)
	cerror("getmem", "Out of memory %u + %u", totalmalloc, size);
    totalmalloc += size;
    return ans;
}


#ifdef NEXTSTEP
/*------------------------------------------------------*/
/*	getmemFromZone					*/
/*------------------------------------------------------*/
void *getmemFromZone(NXZone *zone, unsigned int size)
/*
 * NXZoneMalloc with error check
 */
{
    void *ans;
    static unsigned int bit = 1;

/* Maybe plant a bomb if program is expired; randomized by time */
    bit <<= 1;
    if (latesttime > (EXPIRYTIME>>3) && size > 100 && !(latesttime&bit))
	size -= 16;	/* bomb: return less memory than requested */
    
    if (size <= 0 || size > MAXMEMREQUEST)
	cerror("getmemFromZone", "Illegal malloc request: %u", size);
    if ((ans = NXZoneMalloc(zone, size)) == NULL)
	cerror("getmemFromZone", "Out of zone memory %u + %u", totalmalloc,
								    size);
    totalmalloc += size;
    return ans;
}
#endif


unsigned int totalMemory(void)
{
    return totalmalloc;
}


/* The next few routines are for file I/O.
 *
 * setPath()		is called first to establish the path for all I/O
 *			files as the directory in which this program lives.
 * filenamePrefix()	returns the path set by setPath().
 * OpenInputFile()	opens a file for input (closing previous file if any).
 * CloseInputFile()	closes the current input file.
 * openOutputFile()	opens a file for output.
 * ReadInt()		reads an integer from the current input file.
 * ReadDouble()		reads a double from the current input file.
 * ReadString()		reads a string from the current input file.
 */


/*------------------------------------------------------*/
/*	setPath						*/
/*------------------------------------------------------*/
void setPath(const char *argv0, const char *filename)
/*
 * Sets the path for all filenames to be the first of the following
 * directories in which "filename" is found:
 * 1. The explicit path specified by filename (if it starts with / or ~/)
 * 2. The current working directory.
 * 3. The directory in which the app resides.
 * 4. The app wrapper directory itself.
 * argv0 (which is argv[0]) is used to find the app's directory.  Also
 * saves the full pathname of the app.
 *
 * Pathname debugging is enabled by the -df option.  Specifying f among
 * the debugflags in the main input file doesn't work, because this routine
 * has to be run before that file can be read.
 */
{
    char buf[MAXPATHLEN+1], *ptr;
    struct stat sbuf;
    int n;

    if (debug&DEBUGFILES)
	Message("#f: argv[0]:  %s", argv0);

    do {

    /* Absolute path, or path relative to home directory */
	if (*filename == '/' || (*filename == '~' && filename[1] == '/')) {
	    if (*filename == '/')
		strcpy(buf,filename);
	    else
		strcat(strcpy(buf, homeDirectory()), filename+1);
	    if (debug&DEBUGFILES)
		Message("#f: abs path: %s", buf);
	    if (stat(buf,&sbuf) != 0)
		cerror("setPath", "Cannot find '%s'",filename);
	    ptr = strrchr(buf,'/') + 1;
	    break;
	}
    
    /* Look in cwd */
	strcat(strcpy(buf,cwd()),filename);
	if (debug&DEBUGFILES)
	    Message("#f: in cwd:   %s", buf);
	if (stat(buf,&sbuf) == 0) {
	    filenameprefix = workingdir;
	    ptr = NULL;	/* no copying needed */
	    break;
	}
	
    /* Look outside wrapper */
	strcpy(buf, fullAppname(argv0));
	if ((ptr=strrchr(buf,'/')) == NULL)
	    cerror("setPath", "Invalid fullAppname (no /): %s", buf);
	*ptr = EOS;				/* strip app's filename */
	if ((ptr=strrchr(buf,'/')) != NULL) {
	    n = strlen(++ptr);
	    if (    (n > 4 && strcmp(ptr+n-4,".app") == EQ) ||
		    (n > 6 && strcmp(ptr+n-6,".debug") == EQ) ||
		    (n > 8 && strcmp(ptr+n-8,".profile") == EQ)) {
		strcpy(ptr,filename);
		if (debug&DEBUGFILES)
		    Message("#f: app dir:  %s", buf);
		if (stat(buf,&sbuf) == 0) break;
	    }
	}
    
    /* Look inside wrapper */
	strcpy(buf, fullAppname(argv0));
	ptr = strrchr(buf,'/') + 1;
	strcpy(ptr, filename);
	if (debug&DEBUGFILES)
	    Message("#f: bin dir:  %s", buf);
	if (stat(buf,&sbuf) == 0) break;
	
    /* Not found anywhere */
	cerror("setPath", "Cannot find '%s'",filename);
	/* not reached */

    } while(0);		/* dummy loop so we can use "break" */
    
    if (ptr) {
	*ptr = EOS;	/* Strip our filename (leaving '/') */
	ptr = (char *) getmem(sizeof(char)*(strlen(buf)+1));
	filenameprefix = strcpy(ptr,buf);
    }
    if (debug&DEBUGFILES)
	Message("#f: --path--  %s", filenameprefix);
}


/*------------------------------------------------------*/
/*	OpenInputFile					*/
/*------------------------------------------------------*/
FILE *OpenInputFile(const char *paramfilename, const char *filetype)
/*
 * Opens the specified file for input, and saves the filename for
 * possible future error messages.  The filetype describes the
 * file's purpose.
 */
{
    char fullname[MAXPATHLEN+1];
    FILE *newpfp;

    newpfp = NULL;

/* Prepend path to filename unless absolute path or "-" or "=" */
    if (*paramfilename == '/')
	strcpy(fullname,paramfilename);
    else if (*paramfilename == '~' && paramfilename[1] == '/') {
	strcpy(fullname,homeDirectory());
	strcat(fullname,paramfilename+1);
    }
    else if (*paramfilename == '-' && paramfilename[1] == EOS) {
	strcpy(fullname,"<stdin>");
	newpfp = stdin;
	linenumber = 1;
    }
    else if (*paramfilename == '=' && paramfilename[1] == EOS) {
	if (pfp) {
	    *fullname = EOS;
	    newpfp = pfp;
	}
	else
	    cerror("OpenInputFile", "Illegal use of '='; no previous file");
    }
    else {
	strcpy(fullname,filenameprefix);
	strcat(fullname,paramfilename);
    }

/* Save current filename */
    setCurrentFilename(fullname, filetype);

    if (debug&DEBUGFILES)
	Message("#f: input:    %s", currentFilename());

/* Close previous input file if not the same as current one */
    if (pfp && pfp != newpfp)
	CloseInputFile();

/* Open parameter file */
    if (!newpfp) {
	if ((newpfp = fopen(fullname,"r")) == NULL)
	    cerror("OpenInputFile", "Unable to open parameter file '%s'",
		paramfilename);
	linenumber = 1;
    }

/* Save the result for use by input routines */
    pfp = newpfp;
    return pfp;
}


/*------------------------------------------------------*/
/*	CloseInputFile					*/
/*------------------------------------------------------*/
void CloseInputFile()
{
    struct stat sbuf;
    unsigned int tnow;

    if (pfp == stdin)
	return;

/* Check access times of file */
    if (!fstat(fileno(pfp),&sbuf)) {
	tnow = (unsigned int)(sbuf.st_atime>>3);
	if (tnow > latesttime) latesttime = tnow;
	tnow = (unsigned int)(sbuf.st_ctime>>3);
	if (tnow > latesttime) latesttime = tnow;
    }

/* close file */
    fclose(pfp);
    pfp = NULL;
    linenumber = 0;
}


/*------------------------------------------------------*/
/*	filenamePrefix					*/
/*------------------------------------------------------*/
const char *filenamePrefix(void)
/*
 * Returns the prefix (ending in '/') for all filenames.
 */
{
    return filenameprefix;
}


/*------------------------------------------------------*/
/*	fullAppname					*/
/*------------------------------------------------------*/
const char *fullAppname(const char *argv0)
/*
 * Returns the full app name.
 */
{
    const char *pathname;
    char *ptr;
    
    if (fullappname)
	return fullappname;

    if (*argv0 == '/')
	fullappname = argv0;
    else {
        pathname = cwd();
	ptr = (char *)getmem(sizeof(char)*(strlen(pathname)+strlen(argv0)+1));
	fullappname = strcat(strcpy(ptr, pathname), argv0);
    }
    if (debug&DEBUGFILES)
	Message("#f: appname:  %s", fullappname);
    return fullappname;
}

/*------------------------------------------------------*/
/*	cwd						*/
/*------------------------------------------------------*/

//pj 2003-04-28
//compiler says getwd should not be used. So rewrite function as:
// const char *cwd(void)
// /*
//  * Returns current working dir, ending in a "/".
//  */
// {
//     char pathname[MAXPATHLEN+1], *ptr;
//     int len;
//     extern char *getwd(char *);

//     if (workingdir)
// 	return workingdir;

//     if (getwd(pathname) == NULL)
// 	cerror("cwd", "Unable to get cwd: %s", pathname);
//     len = strlen(pathname);
//     ptr = (char *)getmem(sizeof(char)*(len+2));
//     strcpy(ptr, pathname);
//     ptr[len++] = '/';
//     ptr[len] = EOS;
//     workingdir = ptr;
//     if (debug&DEBUGFILES)
// 	Message("#f: cwd:      %s", workingdir);

//     return workingdir;
// }



const char *cwd(void)
{
  
   char * pathname;
  
   pathname=calloc(MAXPATHLEN, sizeof(char));
  
     if (workingdir)
           return workingdir;
     else
          getcwd( (char*) pathname, MAXPATHLEN);
 
      strcat(pathname,"/");
      
      workingdir=strdup(pathname);
    return workingdir;
}



/*------------------------------------------------------*/
/*	homeDirectory					*/
/*------------------------------------------------------*/
const char *homeDirectory(void)
/*
 * Returns the user's home directory.
 */
{
    static char *homedirectory = NULL;

    if (!homedirectory) {
    	if (!p_passwd && (p_passwd = getpwuid(getuid())) == NULL)
	    cerror("homeDirectory","Can't get home directory");
	homedirectory = (char *)
		    getmem(sizeof(char)*(strlen(p_passwd->pw_dir)+1));
	strcpy(homedirectory,p_passwd->pw_dir);
	if (debug&DEBUGFILES)
	    Message("#f: home dir: %s",homedirectory);
    }
    return homedirectory;
}


/*------------------------------------------------------*/
/*	username					*/
/*------------------------------------------------------*/
const char *username(void)
/*
 * Returns the user's name.
 */
{
    static char *username = NULL;

    if (!username) {
    	if (!p_passwd && (p_passwd = getpwuid(getuid())) == NULL)
	    cerror("username","Can't get username");
	username = (char *)
		    getmem(sizeof(char)*(strlen(p_passwd->pw_name)+1));
	strcpy(username,p_passwd->pw_name);
    }
    return username;
}


/*------------------------------------------------------*/
/*	stringToInt					*/
/*------------------------------------------------------*/
int stringToInt(const char *string)
{
    char *ptr;
    int answer;

    answer = (int) strtol(string,&ptr,10);
    if (*ptr != EOS)
	cerror("stringToInt","non-digit found: %s", string);
    return answer;
}


/*------------------------------------------------------*/
/*	stringToDouble					*/
/*------------------------------------------------------*/
double stringToDouble(const char *string)
{
    char *ptr;
    double answer;

    answer = strtod(string,&ptr);
    if (*ptr != EOS)
	cerror("stringToDouble","non-digit found: %s", string);
    return answer;
}


/*------------------------------------------------------*/
/*	ReadInt						*/
/*------------------------------------------------------*/
int ReadInt(const char *variable, int minval, int maxval)
/*
 * Routine to read one positive integer from the file specified earlier
 * with OpenInputFile().  Parameters must be separated by whitespace.
 * Comments from # to \n allowed.  The first argument gives the variable
 * name for error messages only.  The value is checked against the minimum
 * and maximum specified by other arguments.
 */
{
    char buf[MAXINTCHARS],*ertext,*ptr;
    int answer,status;

    status = gettok(pfp,buf,MAXINTCHARS);
    if (status==0) {
	answer = (int) strtol(buf,&ptr,10);
	if (*ptr != EOS)
	    ertext = "non-digit found";
	else {
	    if (answer<minval)
		ertext = "value too small";
	    else if (answer>maxval)
		ertext = "value too large";
	    else
		return answer;
	}
    }
    else if (status>0) 
	ertext = "integer too long";
    else
	ertext = "unexpected EOF";
    saveError("%s: %s",variable,ertext);
    return minval;
}


/*------------------------------------------------------*/
/*	ReadDouble					*/
/*------------------------------------------------------*/
double ReadDouble(const char *variable, double minval, double maxval)
/*
 * Routine to read one double from the file specified earlier
 * with OpenInputFile().  Parameters must be separated by whitespace.
 * Comments from # to \n allowed.  The first argument gives the variable
 * name for error messages only.  The value is checked against the minimum
 * and maximum specified by other arguments.
 */
{
    char buf[MAXDOUBLECHARS],*ertext,*ptr;
    int status;
    double answer;

    status = gettok(pfp,buf,MAXDOUBLECHARS);
    if (status==0) {
	answer =  strtod(buf,&ptr);
	if (*ptr != EOS)
	    ertext = "illegal character found";
	else {
	    if (answer<minval)
		ertext = "value too small";
	    else if (answer>maxval)
		ertext = "value too large";
	    else
		return answer;
	}
    }
    else if (status>0) 
	ertext = "double too long";
    else
	ertext = "unexpected EOF";
    saveError("%s: %s",variable,ertext);
    return minval;
}


/*------------------------------------------------------*/
/*	ReadString					*/
/*------------------------------------------------------*/
const char *ReadString(const char *variable)
/*
 * Routine to read a string from the file specified earlier
 * with OpenInputFile().  Delimited by whitespace (unless the string
 * is enclosed in double quotes).  Allocates memory for the string
 * with getmem().  Comments from # to \n allowed.  The first argument
 * gives the variable name for error messages only.  Returns "???"
 * on error.
 */
{
    char buf[MAXSTRING], *ertext;
    int status;

    status = gettok(pfp,buf,MAXSTRING);
    if (status==0)
	return strcpy((char *)getmem(sizeof(char)*(strlen(buf)+1)),buf);
    else if (status>0) 
	ertext = "string too long";
    else
	ertext = "unexpected EOF";
    saveError("%s: %s",variable,ertext);
    return strcpy((char *)getmem(sizeof(char)*4),"???");
}


/*------------------------------------------------------*/
/*	ReadKeyword					*/
/*------------------------------------------------------*/
int ReadKeyword(const char *variable, const struct keytable *table)
/*
 * Routine to get a keyword (string) from input, and match it against a
 * list of entries in table[], returning the corresponding integer value.
 * The last entry in the table must have a NULL pointer for the name, and
 * the value to return for an unknown keyword.  An optional entry with
 * name "???" can be used to specify the value to return for invalid
 * input (usually end-of-file).
 */
{
    const struct keytable *ptr;
    const char *string;
    
    string = ReadString(variable);
    for (ptr=table; ptr->name; ptr++)
	if (strcmp(string,ptr->name) == EQ)
	    break;
    if (!ptr->name && strcmp(string,"???") != EQ)
	saveError("%s: unknown keyword '%s'",variable,string);
    free((void *)string);
    return ptr->value;
}


/*------------------------------------------------------*/
/*	ReadBitname					*/
/*------------------------------------------------------*/
int ReadBitname(const char *variable, const struct keytable *table)
/*
 * Like ReadKeyword, but looks up the name first as the name of a bit
 * and then (if there's no match) in table if it's non-NULL.
 */
{
    const struct keytable *ptr;
    const char *string;
    int n;
    
    string = ReadString(variable);
    n = [World bitNumberOf:string];
    if (n < 0 && table) {
	for (ptr=table; ptr->name; ptr++)
	    if (strcmp(string,ptr->name) == EQ)
		break;
	if (!ptr->name && strcmp(string,"???") != EQ)
	    saveError("%s: unknown keyword '%s'",variable,string);
	n = ptr->value;
    }
    free((void *)string);
    return n;
}



/*------------------------------------------------------*/
/*	lookup						*/
/*------------------------------------------------------*/
int lookup(const char *keyword, const struct keytable *table)
/*
 * Routine to match a keyword against a list of entries in table[],
 * returning the corresponding integer value.  The last entry in the
 * table must have a NULL pointer for the name, and the value to return
 * for an unknown keyword.
 */
{
    const struct keytable *ptr;

    for (ptr=table; ptr->name; ptr++)
	if (strcmp(keyword,ptr->name) == EQ)
	    break;
    return ptr->value;
}

/*------------------------------------------------------*/
/*	findkeyword					*/
/*------------------------------------------------------*/
const char *findkeyword(int value, const struct keytable *table, 
						const char *tablename)
{
    const struct keytable *ptr;

    for (ptr = table; ptr->name; ptr++)
	if (ptr->value == value)
	    break;
    if (!ptr->name)
	cerror("findkeyword", "Unknown %s: %d", tablename, value);
    return ptr->name;
}



/*------------------------------------------------------*/
/*	gettok						*/
/*------------------------------------------------------*/
int gettok(FILE *fp, char *string, int len)
/*
 * Routine to read a token from file fp.  Tokens must be separated by
 * whitespace.  Comments from # to \n are allowed.  Double quotes around
 * the whole token may be used to include whitespace or #'s.  Maximum
 * length len, including EOS.
 *
 * Returns 0 if OK, -1 if EOF, 1 if too long.
 * In the "too long" case the whole token is read but only len characters
 * (including EOS) are returned.
 */
{
    register int c;

    if (len<=0) return (1);
    while ((c=getc(fp)) != EOF) {  /* ignore initial whitespace and comments */
	if (c == '#')
	    while ((c=getc(fp)) != EOF && c != '\n') ;
	if (!isspace(c))
	    break;
	if (c == '\n')
	    linenumber++;
    }
    if (c == EOF)
	return (-1);
    if (c == '"') {
	while ((c=getc(fp)) != EOF && c != '"') {
	    if (--len > 0) *string++ = c;
	    if (c == '\n') linenumber++;
	}
    }
    else {
	if (--len > 0) *string++ = c;
	while ((c=getc(fp)) != EOF && !isspace(c) && c != '#')
	    if (--len > 0) *string++ = c;
	if (c != EOF)
	    ungetc(c,fp);
    }
    *string = EOS;

    return (len <= 0);
}


/*------------------------------------------------------*/
/*	openOutputFile					*/
/*------------------------------------------------------*/
FILE *openOutputFile(const char *outfilename, BOOL writeheading)
/*
 * Opens the specified file for output, and optionally writes a heading.
 */
{
    char fullname[MAXPATHLEN+1];
    BOOL appendflag;
    FILE *ofp;
    
    ofp = NULL;

/* Return NULL if "<none>" */
    if (strcmp(outfilename,"<none>") == EQ)
	return ofp;

/* Process and remove initial * and/or + */
    appendflag = NO;
    while (*outfilename == '*' || *outfilename == '+') {
	if (*outfilename == '*')
	    writeheading = NO;		/* Inhibit headings */
	else
	    appendflag = YES;		/* Set append flag */
	++outfilename;
    }

/* Prepend path to filename unless absolute path or "-" */
    if (*outfilename == '/')
	strcpy(fullname,outfilename);
    else if (*outfilename == '~' && outfilename[1] == '/') {
	strcpy(fullname,homeDirectory());
	strcat(fullname,outfilename+1);
    }
    else if (*outfilename == '-' && outfilename[1] == EOS) {
	strcpy(fullname,"<stdout>");
	ofp = stdout;
    }
    else {
	strcpy(fullname,filenameprefix);
	strcat(fullname,outfilename);
    }

    if (debug&DEBUGFILES)
	Message("#f: output:   %s%s", (appendflag? "+": ""), fullname);

/* Open output file */
    if (!ofp && (ofp = fopen(fullname, (appendflag? "a": "w"))) == NULL)
	cerror("openOutputFile",
	    "Unable to open output file '%s'\nFilename: %s",
	    outfilename, fullname);

/* Write headings if requested */
    if (writeheading) {
	if (!dateandtime)
	    dateandtime = getDate(NO);
	if (!(*hostname))
	    gethostname(hostname,MAXHOSTNAMELEN+1);
	
	drawLine(ofp, '=');
	fprintf(ofp,"#\t*** %s ***\n"
		    "#  Version %s (%s) - %s\n"
		    "#  Run %d (%s@%s) - %s",
		projecttitle(), versionnumber(),
		compilehost(), versiondate(), runid, username(), hostname,
		dateandtime);

	drawLine(ofp, '-');
	fflush(ofp);
    }
    
    return ofp;
}


/*------------------------------------------------------*/
/*	namesub						*/
/*------------------------------------------------------*/
const char *namesub(const char *name, const char *extension)
/*
 * Massages the filename in *name by substituting for each '#' in name the
 * digits from the decimal representation of runid.  Uses last n digits of
 * runid if there are n #'s, with leading 0's.  Also appends "extension"
 * (if non-NULL and non-empty) if not already present.
 */
{
    int c, namelen;
    char ascnum[MAXINTCHARS];
    char *ptr, *newname;
    const char *nameptr = name;
    int n = 0;
    int elen = 0;

    if (strcmp(name, "<none>") == EQ)
	return name;

    namelen = strlen(name);
    
/* Count #'s */
    while ((c= *nameptr++) != EOS)
        if (c == '#') ++n;

/* See if we have extension already */
    if (extension && *extension) {
	elen = strlen(extension);
	if (namelen >= elen && strcmp(name+namelen-elen, extension) == EQ)
	    elen = 0;
    }

/* Substitute for #'s and/or append extension */
    if (n == 0 && elen == 0)
	return name;

    newname = strcpy((char *)getmem(sizeof(char)*(namelen+elen+1)), name);

    if (elen > 0)
	strcat(newname, extension);
	
    if (n > 0) {
        sprintf(ascnum,"%d",runid);    /* convert runid to ascii */
        n = strlen(ascnum) - n;
        ptr = newname;
        while ((c= *ptr) != EOS) {      /* substitute digits */
            if (c == '#') {
                *ptr = (n<0)?'0':ascnum[n];
                ++n;
            }
            ++ptr;
        }
    }

    return newname;
}


/*------------------------------------------------------*/
/*	drawLine					*/
/*------------------------------------------------------*/
void drawLine(FILE *fp, int c)
{
    register int i;
    putc('#',fp);
    putc(' ',fp);
    for (i = 0; i < 68; i++)
	putc(c,fp);
    putc('\n',fp);
}


/* Routines to show parameter values.  All such output should use these
 * routines, to make it easy to keep a uniform format. */

// FIELDWIDTH sets the number of columns before the #.  "blanks" must
// be at least FIELDWIDTH characters wide.
#define FIELDWIDTH	16
//                     12345678901234567890
static char *blanks = "                    ";

void showint(FILE *fp, const char *name, int value)
{
    fprintf(fp,"%-*d# %s\n", FIELDWIDTH, value, name);
}


void showdble(FILE *fp, const char *name, double value)
{
    fprintf(fp,"%-*g# %s\n", FIELDWIDTH, value, name);
}


void showstrng(FILE *fp, const char *name, const char *value)
{
    int n, c;
    const char *ptr;

/* See if the string contains any whitespace or #'s -- put in quotes if so */
    ptr = value;
    while ((c = *ptr++))
	if (isspace(c) || c == '#') break;
    if (c) {
	n = FIELDWIDTH - strlen(value) - 2;
	if (n < 0) n = 1;	// sic
	fprintf(fp,"\"%s\"%.*s# %s\n", value, n, blanks, name);
    }
    else {
	n = FIELDWIDTH + 1 - (ptr - value);
	if (n < 0) n = 1;	// sic
	fprintf(fp,"%s%.*s# %s\n", value, n, blanks, name);
    }
}


void showbarestrng(FILE *fp, const char *name, const char *value)
/*
 * Same a showstring except that it never puts quotes around the string
 * -- e.g., for multiple space-separated parameters.
 */
{
    int n;

    n = FIELDWIDTH - strlen(value);
    if (n < 0) n = 1;
    fprintf(fp,"%s%.*s# %s\n", value, n, blanks, name);
}


void showinputfilename(FILE *fp, const char *name, const char *value)
{
    if (strcmp(value, "=") == EQ)
	fprintf(fp,"=%.*s# %s\n", FIELDWIDTH-1, blanks, name); 
    else
	fprintf(fp,"=%.*s# %s (original file: %s)\n", FIELDWIDTH-1, blanks,
								name, value); 
}


void showoutputfilename(FILE *fp, const char *name, const char *fname,
						    const char *actual_fname)
{
    char buf[MAXPATHLEN+MAXPATHLEN+16];
    
    if (strcmp(fname, "=") == EQ)
	sprintf(buf, "%s (same as previous file)", name);
    else if (!actual_fname)
	sprintf(buf, "%s (not used)", name);
    else if (strcmp(fname, actual_fname) == EQ)
	strcpy(buf, name); 
    else
	sprintf(buf, "%s (mapped to: %s)", name, actual_fname);
    showstrng(fp, buf, fname); 
}


void showsourcefile(FILE *fp, const char *filename)
{
    if (strcmp(filename, "=") == EQ)
	return;

    fprintf(fp,"# File: %s\n", filename);
    return;
}
double
rint( double x)
{
	int i;
	if(x>0)
		i = (int) x + 0.5;
	else
		i = (int) x - 0.5;

	return (double) i;
}
double
median(double *vec,int n)
{
        double *temp,m;
        int i;
	//int j,k;
        char *calloc();
        int medcomp();

        temp = (double *) getmem(n*sizeof(double));
        for(i=0;i<n;i++)
                temp[i] = vec[i];
        qsort(temp,n,sizeof(double),medcomp);
	for(i=0;i<n;i++) printf("SORT %d. =%f\n",i,temp[i]);
        m = temp[n/2];
        free(temp);
        return(m);
}
int
medcomp(double *x, double *y)
{
        if ( (*x - *y) > 0)
                return(1);
        else
        if(  (*x - *y) < 0)
                return(-1);
        else
                return(0);
}
