// The Santa Fe Stock Market -- Implementation of utility functions
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This file is a collection of small utility functions for input,
// output, system interaction, and miscellaneous tasks.
//
// FILE/DIRECTORY FUNCTIONS
//
// const char *cwd(void)
//	Returns the current working directory, ending in a "/".
//
// const char *homeDirectory(void)
//	Returns the user's home directory (without a "/" suffix).
//
// const char *fullAppname(const char *argv0)
//	Returns the full pathname of the application.  "argv0" should be the
//	argv[0] string from program startup.
//
// void setPath(const char *argv0, const char *filename)
//	Sets the path for all subsequent filenames (except those specified
//	with an explicit path).  "argv0" should be the argv[0] string from
//	program startup.  "filename" is the name of a file that should be
//	in the desired location.  The path is set to the first of the
//	following directories in which "filename" is found:
//	1. The explicit path specified by filename (if it starts with / or ~/)
//	2. The current working directory.
//	3. The directory in which the app resides.
//	4. The app wrapper directory itself. [NeXTSTEP only]
//
// const char *filenamePrefix(void)
//	Returns the path prefix (ending in PATHSEPCHAR) for all filenames.
//
// const char *namesub(const char *filename, const char *extension)
//	Processes the filename by substituting for each '#' in filename the
//	digits from the decimal representation of the run number (runid),
//	and returns the result.  Uses the last n digits of runid if there
//	are n #'s, with leading 0's.  Also appends "extension" (if non-NULL
//	and non-empty) if not already present.
//
// INPUT FUNCTIONS
//
// FILE *openInputFile(const char *filename, const char *filetype)
//	Opens the specified file for input, closing the previous one if
//	necessary -- only one is opened at a time.  The filename is saved
//	for possible future error messages.  The filetype describes the
//	file's purpose or contents, e.g., "BF agent parameters".
//
// void closeInputFile(void)
//	Closes the last input file opened by openInputFile().
//
// int gettok(FILE *fp, char *string, int len)
//	Routine to read a token from file fp.  This is the underlying routine
//	used by the readXXX() routines below.  Tokens must be separated by
//	whitespace.  Comments from # to \n are allowed.  Double quotes around
//	the whole token may be used to include whitespace (including actual
//	\n's) or #'s.  \" becomes " inside double quotes.  Maximum length len,
//	including EOS.  Returns 0 if OK, -1 if EOF, 1 if too long.  In the
//	"too long" case the whole token is read but only len characters
//	(including EOS) are returned.
//
// int readInt(const char *variable, int minval, int maxval)
//	Routine to read one positive integer from the file specified earlier
//	with openInputFile().  Parameters must be separated by whitespace.
//	Comments from # to \n are allowed.  The first argument gives the
//	variable name, for use in error messages.  The value is checked
//	against the minimum and maximum specified by the other arguments.
//	Errors are recorded with saveError() -- see error.m.
//
// double readDouble(const char *variable, double minval, double maxval)
//	Like readInt(), but reads a double.
//
// const char *readString(const char *variable)
//	Like readInt(), but reads a string.  Strings are delimited by
//	whitespace unless enclosed in double quotes (see gettok() below).
//	The string is copied to malloc() memory.  Returns "???" if an
//	error occurred, as well as calling saveError().
//
// int readKeyword(const char *variable, const struct keytable *table)
//	Routine to get a keyword (string) from input, and match it against a
//	list of entries in table[], returning the corresponding integer value.
//	See struct keytable in global.h.  The last entry in the table must
//	have a NULL pointer for the name, and the value to return for an
//	unknown keyword.  An optional entry with name "???" can be used to
//	specify the value to return for invalid input (usually end-of-file).
//
// int readBitname(const char *variable, const struct keytable *table)
//	Like readKeyword(), but looks up the name first as the name of a bit
//	and then, if there's no match, in table (unless table==NULL).
//
// OUTPUT FUNCTIONS
//
// FILE *openOutputFile(const char *name, const char *type, BOOL writeheading)
//	Opens the specified file "name" for output, and optionally writes a
//	block heading.  The heading is written only if writeheading==YES and
//	the filename does not have a "*" prefix.  A "+" prefix implies append
//	mode.  A filename of "-" means stdout.  The "type" is used to identify
//	the type of file in debugging messages.
//
// void drawLine(FILE *fp, int c)
//	Writes a line of 'c' characters (e.g., - or =) to fp.
//
// void showint(FILE *fp, const char *name, int value)
//	Writes out the integer "value" followed by the name (or explanation)
//	"name" as a comment, e.g.,
//	     1234        # run number
//	This, and the following other showXXX() routines, should be used for
//	all parameter output to the log file, to ensure uniform layout.
//
// void showdble(FILE *fp, const char *name, double value)
//	Like showint(), but writes a double.
//
// void showstrng(FILE *fp, const char *name, const char *value)
//	Like showint(), but writes a string "value".  The string will be
//	enclosed in double quotes if necessary, to make it a single token.
//
// void showbarestrng(FILE *fp, const char *name, const char *value)
//	Same as showstrng() except that double quotes are never added.
//	Used for multiple space-separated parameters.
//
// void showbarestrng2(FILE *fp, const char *name1, const char *name2,
//							const char *value)
//
// void showinputfilename(FILE *fp, const char *name, const char *value)
//	Reports an input file specification to the log file fp.  Always writes
//	"=" as the actual value, so that re-runs work, but reports the
//	description "name" in the comment field along with the original
//	filename "value" if not "=".
//
// void showoutputfilename(FILE *fp, const char *name, const char *fname,
//						    const char *actual_fname)
//	Reports an output file specification to the log file fp.  Writes the
//	original specification "fname" as the value, but also reports
//	"actual_fname" (if different) in the comment field after the
//	description "name".  "actual_fname" should be the result of applying
//	namesub() to "fname".
//
// void showsourcefile(FILE *fp, const char *filename)
//	Writes a comment heading (e.g., "# File: bsparams") to the log
//	file fp, showing the specified filename.  Does nothing if the
//	filename is "=".
//
// MISCELLANEOUS FUNCTIONS
//
// void *getmem(unsigned int size)
//	Gets a block of memory of "size" bytes.  Equivalent to malloc(),
//	but with error checking.
//
// const char *username(void)
//	Returns the user's name.
//
// const char *hostname(void)
//	Returns a hostname string (at most HNAMELEN characters).
//
// const char *getDate(BOOL new)
//	Returns a date/time string.  Always returns the same value unless
//	"new" is YES.  All returned values remain available (not freed).
//
// void showCPU(const char *when)
//	Displays cpu and wall time used so far, via message().  "when" is
//	prefixed to the message for identification.
//
// int stringToLong(const char *string)
//	Converts "string" to a long.  Causes a fatal error if "string"
//	is not a valid integer.
//
// double stringToDouble(const char *string)
//	Converts "string" to an double.  Causes a fatal error if "string"
//	is not a valid real number.
//
// int lookup(const char *keyword, const struct keytable *table)
//	Routine to match a keyword against a list of entries in table[],
//	returning the corresponding integer value.  The last entry in the
//	table must have a NULL pointer for the name, and the value to return
//	for an unknown keyword.
//
// const char *findkeyword(int value, const struct keytable *table,
//						const char *tablename)
//	Inverse of lookup() -- finds the first keyword with the specified
//	value in table[].  Causes a fatal error if not found.
//
// double median(double *vec,int n)
//

// IMPORTS
#include "global.h"
#include "util.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <pwd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/resource.h>
#include UNIXLIB
#include "world.h"
#include "error.h"
#include "version.h"

#ifdef DEFINE_GETHOSTNAME
extern int gethostname(char *, int);
#endif
#ifdef DEFINE_GETRUSAGE
extern int getrusage(int, struct rusage *);
#endif
#ifdef DEFINE_GETTIMEOFDAY
extern int gettimeofday(struct timeval *, struct timezone *);
#endif

/* Local variables */
static FILE *pfp;
static FILE *savedpfp;
static int savedlinenumber;
static const char *filenameprefix;
static const char *fullappname;
static const char *workingdir;
static struct passwd *p_passwd;

// Limit on malloc size -- just to catch errors
#define MAXMEMREQUEST	1048576

// Limit of hostname length returned (truncated if longer)
#define HNAMELEN	16

// FIELDWIDTH sets the number of columns before the #. in the log file.
// "blanks" must be at least FIELDWIDTH characters wide.
#define FIELDWIDTH	16
#define FIELDWIDTH2	9
//                     12345678901234567890
static char *blanks = "                    ";


// =================== FILE/DIRECTORY FUNCTIONS ========================

/*------------------------------------------------------*/
/*	cwd						*/
/*------------------------------------------------------*/
const char *cwd(void)
{
    char pathname[MAXPATHLEN+1], *ptr;
    int len;
    extern char *getwd(char *);

    if (workingdir)
	return workingdir;

    if (getwd(pathname) == NULL)
	cerror("cwd", "Unable to get cwd: %s", pathname);
    len = strlen(pathname);
    ptr = (char *)getmem(sizeof(char)*(len+2));
    strcpy(ptr, pathname);
    ptr[len++] = PATHSEPCHAR;
    ptr[len] = EOS;
    workingdir = ptr;
    if (debug&DEBUGFILES)
	message("#f: cwd:      %s", workingdir);

    return workingdir;
}


/*------------------------------------------------------*/
/*	homeDirectory					*/
/*------------------------------------------------------*/
const char *homeDirectory(void)
{
    static char *homedirectory = NULL;

    if (!homedirectory) {
    	if (!p_passwd && (p_passwd = getpwuid(getuid())) == NULL)
	    cerror("homeDirectory","Can't get home directory");
	homedirectory = (char *)
		    getmem(sizeof(char)*(strlen(p_passwd->pw_dir)+1));
	strcpy(homedirectory,p_passwd->pw_dir);
	if (debug&DEBUGFILES)
	    message("#f: home dir: %s",homedirectory);
    }
    return homedirectory;
}


/*------------------------------------------------------*/
/*	fullAppname					*/
/*------------------------------------------------------*/
const char *fullAppname(const char *argv0)
{
    const char *pathname;
    char *ptr;

    if (fullappname)
	return fullappname;

    if (*argv0 == PATHSEPCHAR)
	fullappname = argv0;
    else {
	pathname = cwd();
	ptr = (char *)getmem(sizeof(char)*(strlen(pathname)+strlen(argv0)+1));
	fullappname = strcat(strcpy(ptr, pathname), argv0);
    }
    if (debug&DEBUGFILES)
	message("#f: appname:  %s", fullappname);
    return fullappname;
}


/*------------------------------------------------------*/
/*	setPath						*/
/*------------------------------------------------------*/
void setPath(const char *argv0, const char *filename)
{
    char buf[MAXPATHLEN+1], *ptr;
    struct stat sbuf;

/* Pathname debugging is enabled by the -df option.  Specifying f among
 * the debugflags in the main input file doesn't work, because this routine
 * has to be run before that file can be read. */
    if (debug&DEBUGFILES)
	message("#f: argv[0]:  %s", argv0);

    do {

    /* Absolute path, or path relative to home directory */
	if (*filename == PATHSEPCHAR ||
		(*filename == '~' && filename[1] == PATHSEPCHAR)) {
	    if (*filename == PATHSEPCHAR)
		strcpy(buf,filename);
	    else
		strcat(strcpy(buf, homeDirectory()), filename+1);
	    if (debug&DEBUGFILES)
		message("#f: abs path: %s", buf);
	    if (stat(buf,&sbuf) != 0)
		cerror("setPath", "Cannot find '%s'",filename);
	    ptr = strrchr(buf,PATHSEPCHAR) + 1;
	    break;
	}

    /* Look in cwd */
	strcat(strcpy(buf,cwd()),filename);
	if (debug&DEBUGFILES)
	    message("#f: in cwd:   %s", buf);
	if (stat(buf,&sbuf) == 0) {
	    if (strchr(filename,PATHSEPCHAR) == NULL) {
		filenameprefix = workingdir;
		ptr = NULL;	/* no copying needed */
	    }
	    else /* relative path */
		ptr = strrchr(buf,PATHSEPCHAR) + 1;
	    break;
	}

#ifdef APPWRAPPER
    /* Look outside wrapper */
	strcpy(buf, fullAppname(argv0));
	if ((ptr=strrchr(buf,PATHSEPCHAR)) == NULL)
	    cerror("setPath", "Invalid fullAppname (no %c): %s",
		PATHSEPCHAR, buf);
	*ptr = EOS;				/* strip app's filename */
	if ((ptr=strrchr(buf,PATHSEPCHAR)) != NULL) {
            int n;
	    n = strlen(++ptr);
	    if (    (n > 4 && strcmp(ptr+n-4,".app") == EQ) ||
		    (n > 6 && strcmp(ptr+n-6,".debug") == EQ) ||
		    (n > 8 && strcmp(ptr+n-8,".profile") == EQ)) {
		strcpy(ptr,filename);
		if (debug&DEBUGFILES)
		    message("#f: app dir:  %s", buf);
		if (stat(buf,&sbuf) == 0) break;
	    }
	}
#endif

    /* Look where the binary is */
	strcpy(buf, fullAppname(argv0));
	ptr = strrchr(buf,PATHSEPCHAR) + 1;
	strcpy(ptr, filename);
	if (debug&DEBUGFILES)
	    message("#f: bin dir:  %s", buf);
	if (stat(buf,&sbuf) == 0) break;

    /* Not found anywhere */
	cerror("setPath", "Cannot find '%s'",filename);
	/* not reached */

    } while(0);		/* dummy loop so we can use "break" */

    if (ptr) {
	*ptr = EOS;	/* Strip our filename (leaving PATHSEPCHAR) */
	ptr = (char *) getmem(sizeof(char)*(strlen(buf)+1));
	filenameprefix = strcpy(ptr,buf);
    }
    if (debug&DEBUGFILES)
	message("#f: --path--  %s", filenameprefix);
}


/*------------------------------------------------------*/
/*	filenamePrefix					*/
/*------------------------------------------------------*/
const char *filenamePrefix(void)
{
    return filenameprefix;
}


/*------------------------------------------------------*/
/*	namesub						*/
/*------------------------------------------------------*/
const char *namesub(const char *name, const char *extension)
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
	sprintf(ascnum,"%d",runid);	/* convert runid to ascii */
	n = strlen(ascnum) - n;
	ptr = newname;
	while ((c= *ptr) != EOS) {	/* substitute digits */
	    if (c == '#') {
		*ptr = (n<0)?'0':ascnum[n];
		++n;
	    }
	    ++ptr;
	}
    }

    return newname;
}


// =================== INPUT FUNCTIONS ========================

/*------------------------------------------------------*/
/*	openInputFile					*/
/*------------------------------------------------------*/
FILE *openInputFile(const char *paramfilename, const char *filetype)
{
    char fullname[MAXPATHLEN+1];
    FILE *newpfp;

    newpfp = NULL;

/* Prepend path to filename unless absolute path or "-" or "=" */
    if (*paramfilename == PATHSEPCHAR)
	strcpy(fullname,paramfilename);
    else if (*paramfilename == '~' && paramfilename[1] == PATHSEPCHAR) {
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
	    cerror("openInputFile", "Illegal use of '='; no previous file");
    }
    else {
	strcpy(fullname,filenameprefix);
	strcat(fullname,paramfilename);
    }

/* Save current filename */
    setCurrentFilename(fullname, filetype);

    if (debug&DEBUGFILES)
	message("#f: %s: %s", filetype, currentFilename());

/* Close previous input file if not the same as current one and not saved */
    if (pfp && pfp != newpfp && pfp != savedpfp)
	closeInputFile();

/* Open input file */
    if (!newpfp) {
	if ((newpfp = fopen(fullname,"r")) == NULL)
	    cerror("openInputFile", "Unable to open input file '%s'",
		paramfilename);
	linenumber = 1;
    }

/* Save the result for use by input routines */
    pfp = newpfp;
    return pfp;
}


/*------------------------------------------------------*/
/*	saveInputFilePointer				*/
/*------------------------------------------------------*/
void saveInputFilePointer()
{
    savedpfp = pfp;
    savedlinenumber = linenumber;
    saveCurrentFilename();
}


/*------------------------------------------------------*/
/*	restoreInputFilePointer				*/
/*------------------------------------------------------*/
void restoreInputFilePointer()
{
    if (pfp && pfp != savedpfp)
	closeInputFile();
    pfp = savedpfp;
    savedpfp = NULL;
    linenumber = savedlinenumber;
    restoreCurrentFilename();
}


/*------------------------------------------------------*/
/*	closeInputFile					*/
/*------------------------------------------------------*/
void closeInputFile()
{
    if (pfp == stdin)
	return;

// Close file
    fclose(pfp);
    pfp = NULL;
    linenumber = 0;
}


/*------------------------------------------------------*/
/*	gettok						*/
/*------------------------------------------------------*/
int gettok(FILE *fp, char *string, int len)
{
    int c;
    BOOL escaped;

    if (len<=0) return (1);
    while ((c=getc(fp)) != EOF) {  /* ignore initial whitespace and comments */
	if (c == '#')
	    while ((c=getc(fp)) != EOF && c != '\n') ;
	if (!isspace(c))
	    break;
	if (c == '\n') {
	    linenumber++;
	    if (fp == savedpfp) savedlinenumber++;
	}
    }
    if (c == EOF)
	return (-1);
    if (c == '"') {
	escaped = NO;
	while ((c=getc(fp)) != EOF) {
	    if (c == '"' && !escaped) break;
	    if (--len > 0) *string++ = c;
	    if (c == '\n') {
		linenumber++;
		if (fp == savedpfp) savedlinenumber++;
	    }
	    if (c == '\\') escaped = !escaped;
	    else escaped = NO;
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
/*	readInt						*/
/*------------------------------------------------------*/
int readInt(const char *variable, int minval, int maxval)
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
/*	readDouble					*/
/*------------------------------------------------------*/
double readDouble(const char *variable, double minval, double maxval)
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
/*	readString					*/
/*------------------------------------------------------*/
const char *readString(const char *variable)
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
/*	readKeyword					*/
/*------------------------------------------------------*/
int readKeyword(const char *variable, const struct keytable *table)
{
    const struct keytable *ptr;
    const char *string;

    string = readString(variable);
    for (ptr=table; ptr->name; ptr++)
	if (strcmp(string,ptr->name) == EQ)
	    break;
    if (!ptr->name && strcmp(string,"???") != EQ)
	saveError("%s: unknown keyword '%s'",variable,string);
    free((void *)string);
    return ptr->value;
}


/*------------------------------------------------------*/
/*	readBitname					*/
/*------------------------------------------------------*/
int readBitname(const char *variable, const struct keytable *table)
{
    const struct keytable *ptr;
    const char *string;
    int n;

    string = readString(variable);
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


// =================== OUTPUT FUNCTIONS ========================

/*------------------------------------------------------*/
/*	openOutputFile					*/
/*------------------------------------------------------*/
FILE *openOutputFile(const char *outfilename, const char *filetype,
							BOOL writeheading)
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
    if (*outfilename == PATHSEPCHAR)
	strcpy(fullname,outfilename);
    else if (*outfilename == '~' && outfilename[1] == PATHSEPCHAR) {
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
	message("#f: %s: %s%s", filetype, (appendflag? "+": ""), fullname);

/* Open output file */
    if (!ofp && (ofp = fopen(fullname, (appendflag? "a": "w"))) == NULL)
	cerror("openOutputFile",
	    "Unable to open output file '%s'\nFilename: %s",
	    outfilename, fullname);

/* Write headings if requested */
    if (writeheading) {

	drawLine(ofp, '=');
	fprintf(ofp,"#\t*** %s ***\n"
		    "#  Version %s - %s\n"
		    "#  Run %d (%s@%s) - %s\n",
		PROJECTTITLE, versionnumber(),
		versiondate(), runid, username(), hostname(),
		getDate(NO));

	drawLine(ofp, '-');
	fflush(ofp);
    }

    return ofp;
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


/*------------------------------------------------------*/
/*	showint						*/
/*------------------------------------------------------*/
void showint(FILE *fp, const char *name, int value)
{
    fprintf(fp,"%-*d# %s\n", FIELDWIDTH, value, name);
}


/*------------------------------------------------------*/
/*	showdble					*/
/*------------------------------------------------------*/
void showdble(FILE *fp, const char *name, double value)
/*
 * Writes out a double with its name.  Note that there's a danger that
 * what is written out might not produce the exact same value when read
 * back in, e.g., for a replay.  This shouldn't be a problem unless real
 * values are specified with very high precision (more than about 10
 * significant figures) in the original input files.
 */
{
    fprintf(fp,"%-*.10g# %s\n", FIELDWIDTH, value, name);
}


/*------------------------------------------------------*/
/*	showstrng					*/
/*------------------------------------------------------*/
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


/*------------------------------------------------------*/
/*	showbarestrng					*/
/*------------------------------------------------------*/
void showbarestrng(FILE *fp, const char *name, const char *value)
{
    int n;

    n = FIELDWIDTH - strlen(value);
    if (n < 0) n = 1;
    fprintf(fp,"%s%.*s# %s\n", value, n, blanks, name);
}


/*------------------------------------------------------*/
/*	showbarestrng2					*/
/*------------------------------------------------------*/
void showbarestrng2(FILE *fp, const char *name1, const char *name2,
						const char *value)
{
    int n, m;

    n = FIELDWIDTH - strlen(value);
    if (n < 0) n = 1;
    m = FIELDWIDTH2 - strlen(name1);
    if (m < 0) m = 1;
    fprintf(fp,"%s%.*s# %s%.*s| %s\n", value, n, blanks, name1, m, blanks,
								name2);
}


/*------------------------------------------------------*/
/*	showinputfilename				*/
/*------------------------------------------------------*/
void showinputfilename(FILE *fp, const char *name, const char *value)
{
    if (strcmp(value, "=") == EQ)
	fprintf(fp,"=%.*s# %s\n", FIELDWIDTH-1, blanks, name);
    else
	fprintf(fp,"=%.*s# %s (original file: %s)\n", FIELDWIDTH-1, blanks,
								name, value);
}


/*------------------------------------------------------*/
/*	showoutputfilename				*/
/*------------------------------------------------------*/
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


/*------------------------------------------------------*/
/*	showsourcefile					*/
/*------------------------------------------------------*/
void showsourcefile(FILE *fp, const char *filename)
{
    if (strcmp(filename, "=") == EQ)
	return;

    fprintf(fp,"# File: %s\n", filename);
    return;
}


// ================ MISCELLANEOUS FUNCTIONS ====================

/*------------------------------------------------------*/
/*	getmem						*/
/*------------------------------------------------------*/
void *getmem(unsigned int size)
{
    void *ans;

    if (size <= 0 || size > MAXMEMREQUEST)
	cerror("getmem", "Illegal malloc request: %u", size);
    if ((ans = malloc(size)) == NULL)
	cerror("getmem", "Out of memory -- size = %u", size);
    return ans;
}


/*------------------------------------------------------*/
/*	username					*/
/*------------------------------------------------------*/
const char *username(void)
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
/*	hostname					*/
/*------------------------------------------------------*/
const char *hostname(void)
/*
 * This gets the name of the host on which we're running, or the first
 * HNAMELEN characters if longer than that.  (We don't use MAXHOSTNAMELEN
 * because it's not universally available.)
 */
{
    static char hname[HNAMELEN+1] = "";

    if (!(*hname)) {
	gethostname(hname,HNAMELEN+1);
	hname[HNAMELEN] = EOS;
    }
    return hname;
}


/*------------------------------------------------------*/
/*	getDate						*/
/*------------------------------------------------------*/
const char *getDate(BOOL new)
{
    static char *dtmem = NULL;
    int len;
    char *dt;
    time_t time(), timeval;

    if (!dtmem || new) {
	timeval = time((time_t *)0);
	dt = ctime(&timeval);
	len = strlen(dt);
    // Allocate new -- do NOT free old
	dtmem = strcpy((char *)getmem(sizeof(char)*(len+1)), dt);
	dtmem[len-1] = EOS;	// Remove newline
    }
    return (const char *)dtmem;
}


/*------------------------------------------------------*/
/*	showCPU						*/
/*------------------------------------------------------*/
void showCPU(const char *when)
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

// Note: gettimeofday()'s definition varies between different Unixes, but
// there doesn't seem to be another way of getting sub-second resolution.
// You might possibly need to remove the second argument.
    gettimeofday(&thetime, NULL);
    walltime = 1e-6*thetime.tv_usec +  thetime.tv_sec - firstwall;
    if (haveprev) {
	udelta = usertime - uprev;
	sdelta = systtime - sprev;
	wdelta = walltime - wprev;
	message("#c: %-14s user:%5.1f +%-4.1f sys:%4.1f +%-4.1f"
	" wall:%5.1f +%-4.1f",
	    when, usertime, udelta, systtime, sdelta, walltime, wdelta);
    }
    else {
	message("#c: %-14s user:%5.1f       sys:%4.1f",
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
/*	stringToLong					*/
/*------------------------------------------------------*/
long stringToLong(const char *string)
{
    char *ptr;
    long answer;

    answer = strtol(string,&ptr,10);
    if (*ptr != EOS)
	cerror("stringToLong","non-digit found: %s", string);
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
/*	lookup						*/
/*------------------------------------------------------*/
int lookup(const char *keyword, const struct keytable *table)
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
