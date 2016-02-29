// The Santa Fe Stockmarket -- Implementation of Output class

// One instance of this class is instantiated for each output stream that's
// defined in the marketcontrol file.  It deals with reading and logging the
// list of variables to be printed, and printing their values as needed.
//
// Most methods are paired -- the instance methods perform an operation
// for one instance, while the corresponding class methods perform the
// operation for all the instances (but +writeOutputStream: is an exception).

// PUBLIC METHODS
//
// + writeNamesToFile:(FILE *)fp
//	Writes the name and description of all the output variables to
//	file "fp".
//
// - initWithName:(const char *)name;
//	Initializes an instance, reading the description of stream "name"
//	from the current input file.
//
// + (BOOL)openOutputStreams
//	Open all output streams.
//
// - (BOOL)openOutputStream;
//	Open the output stream for this instance.
//
// + closeOutputStreams;
//	Close all output streams.
//
// - closeOutputStream;
//	Close the output stream for this instance.
//
// + updateAccumulators;
//	Update all the accumulation variables (specified with a + or @ prefix
//	in the input) in all instances.  This is called once per period.
//
// - updateAccumulators;
//	Update the accumulation variables for this instance.
//
// + resetAccumulators;
//	Reset to 0 all the accumulation variables in all instances.
//
// - resetAccumulators;
//	Reset to 0 the accumulation variables for this instance.
//
// + writeOutputStream:(const char *)name;
//	Write out the values of the variables for the instance named "name".
//	This is called for each "w" event.  If name==NULL, the first
//	instance is used.
//
// - writeOutputStream;
//	Write out the values of the variables for this instance.
//
// + showOutputStreams:(FILE *)fp;
//	Write out the variable names etc for all instances to file fp
//	(the log file).
//
// - showOutputStream:(FILE *)fp;
//	Write out the variable names etc for this instances to file fp.

#import "global.h"
#import "Output.h"
#import <stdlib.h>
#import <string.h>
#import "AgentManager.h"
#import "Specialist.h"
#import "World.h"
#import "error.h"
#import "util.h"


/* Masks, code values and prefix characters for variables to be printed */
#define VARCODEMASK	127
#define VARTYPEMASK	384
#define VARTYPE_INT	128
#define VARTYPE_REAL	256
#define VARTYPE_BIT	384
#define VARTYPE_ALL	0
#define VARNOSPACE	1024
#define VARSUM		2048
#define VARNORM		4096
#define VARAVG		(VARSUM|VARNORM)
#define VARFMT		8192
#define CHARNOSPACE	'|'
#define CHARSUM		'+'
#define CHARAVG		'@'

// List of variable names, default formats, and descriptions.
// NB: If you make any changes here, also check or change:
// 1. Either -intVariable: or -realVariable:;
// 2. the NAMES documentation file.
struct varnamestruct {
    const char *name;
    const char *fmt;
    const char *description;
};
// ------------- Integer variables (int) ------------
static struct varnamestruct intvarnamelist[] = {
{"1",		"%d",		"1"},		// 0 -- don't change
{"t",		"%5d",		"time"},
{"oldt",	"%5d",		"time - 1"},
{"run",		"%d",		"run number"},
{"N",		"%d",		"number of agents"},
{"rseed",	"%d",		"random seed"}	// 5
};
// ------------- Real variables (double) ------------
static struct varnamestruct  realvarnamelist[] = {
{"p",		"%7.3f",	"price"},			// 0
{"d",		"%7.4f",	"dividend"},
{"d/r",		"%7.3f",	"dividend/interest_rate"},
{"v",		"%6.3f",	"volume"},
{"b",		"%6.3f",	"bids"},
{"o",		"%6.3f",	"offers"},			// 5
{"p5",		"%7.3f",	"5-period MA of price"},
{"p20",		"%7.3f",	"20-period MA of price"},
{"p100",	"%7.3f",	"100-period MA of price"},
{"p500",	"%7.3f",	"500-period MA of price"},
{"d5",		"%7.4f",	"5-period MA of dividend"},	// 10
{"d20",		"%7.4f",	"20-period MA of dividend"},
{"d100",	"%7.4f",	"100-period MA of dividend"},
{"d500",	"%7.4f",	"500-period MA of dividend"},
{"pr/d",	"%7.5f",	"price*interest_rate/dividend"},
{"ppu",		"%7.4f",	"profitperunit"},		// 15
{"return",	"%8.6f",	"returnratio"},
{"r",		"%6.4f",	"intrate"},
{"eta",		"%8.6f",	"eta"},
{"oldp",	"%7.3f",	"old price"},
{"oldd",	"%7.4f",	"old dividend"},		// 20
{"oldd/r",	"%7.3f",	"old dividend/interest_rate"},
{"oldv",	"%6.3f",	"old volume"},
{"oldb",	"%6.3f",	"old bids"},
{"oldo",	"%6.3f",	"old offers"}
};

// Derived sizes (known at compile time)
#define INTVARS		(sizeof(intvarnamelist)/sizeof(struct varnamestruct))
#define REALVARS	(sizeof(realvarnamelist)/sizeof(struct varnamestruct))

// Structure for list of variables to print
struct varliststruct {
    double accumulator;
    struct varliststruct *next;
    struct varliststruct *nextaccum;
    const char *fmt;
    int var;
};

// Class variables
static Output *firstInstance = NULL;
static Output *lastInstance = NULL;
static FILE *lastfp = NULL;

// Local function prototypes
static void showVariable(FILE *fp, const char *name,
			const char *description, const char *fmt, int v);
// Private methods
@interface Output(Private)
- (int)intVariable:(int)varcode;
- (double)realVariable:(int)varcode;
@end


@implementation Output

/*------------------------------------------------------*/
/*	+writeNamesToFile:				*/
/*------------------------------------------------------*/
+ writeNamesToFile:(FILE *)fp
{
    unsigned int i;

    fputs("\n# ---------- Integer variables ----------\n", fp);
    for (i=0; i<INTVARS; i++)
	showstrng(fp, intvarnamelist[i].description, intvarnamelist[i].name);

    fputs("\n# ---------- Real variables ----------\n", fp);
    for (i=0; i<REALVARS; i++)
	showstrng(fp, realvarnamelist[i].description, realvarnamelist[i].name);
    return self;
}


/*------------------------------------------------------*/
/*	-initWithName:					*/
/*------------------------------------------------------*/
- initWithName:(const char *)myname
/*
 * Read and store the specification for an output stream from the current
 * parameter file, having already seen the name "myname".
 */
{
    int previousnospace, var;
    unsigned int n;
    const char *varname, *ptr;
    char *fmt, *bufptr, buf[MAXSTRING+1];
    struct varliststruct *vptr, *lastv;

// Add this instance to the end of the list in this class
    (lastInstance? lastInstance->next: firstInstance) = self;
    lastInstance = self;
    next = NULL;

// Initialize instance variables
    name = myname;
    outputfp = NULL;
    actual_filename = NULL;
    accumulatelist = NULL;
    outputcount = 0;
    periodcount = 0;
    lasttime = MININT;

// Read and store the filename and headinginterval
    filename = ReadString("filename");
    headinginterval = ReadInt("headinginterval",-2,MAXINT);

// Read and encode the list of output variables
    previousnospace = 0;
    lastv = NULL;
    for ( ; ;free((void *)varname)) {
	varname = ReadString("varname");
	if (strcmp(varname, "end") == EQ || strcmp(varname, ".") == EQ ||
					    strcmp(varname, "???") == EQ)
	    break;

    /* Set the NOSPACE bit if there's a leading CHARNOSPACE.  If this
     * stands alone, record it to use at the next call. */
	var = previousnospace;
	ptr = varname;
	if (*ptr == CHARNOSPACE) {
	    ptr++;
	    if (*ptr == EOS) {
		previousnospace = VARNOSPACE;
		continue;
	    }
	    var = VARNOSPACE;
	}
	previousnospace = 0;

    /* Strip off and record a leading sum or average prefix character */
	if (*ptr == CHARSUM) {
	    ptr++;
	    var |= VARSUM;
	}
	else if (*ptr == CHARAVG) {
	    ptr++;
	    var |= VARAVG;
	}

    /* Copy the string to our local buffer up to '(' or EOS.  If
     * there's a format string (in parentheses), make a local copy. */
	for (bufptr = buf; bufptr<buf+MAXSTRING; ) {
	    if (*ptr == '(' || *ptr == EOS) break;
	    *bufptr++ = *ptr++;
	}
	*bufptr = EOS;
	if (bufptr == buf) {
	    saveError("missing variable name in '%s'", varname);
	    continue;
	}
	if (*ptr == '(') {
	    n = strlen(ptr)-1;
	    if (ptr[n] != ')')
		saveError("missing ')' in variable '%s' "
				    "-- missing double-quotes?", varname);
	    fmt = (char *)getmem(sizeof(char)*n);
	    strncpy(fmt, ptr+1, n-1);
	    fmt[n-1] = EOS;
	    var |= VARFMT;
	}
	else
	    fmt = NULL;

    /* Look for the name in three tables */
	for (;;) {		/* fake loop to allow break */

	/* Integer variable name? */
	    for (n = 0; n < INTVARS; n++)
		if (strcmp(buf, intvarnamelist[n].name) == EQ)
		    break;
	    if (n < INTVARS) {
		var |= n | VARTYPE_INT;
		if (!fmt)
		    fmt = ((var&VARSUM)? "%4.0f":
					    (char *)intvarnamelist[n].fmt);
		break;
	    }

	/* Real variable name? */
	    for (n = 0; n < REALVARS; n++)
		if (strcmp(buf, realvarnamelist[n].name) == EQ)
		    break;
	    if (n < REALVARS) {
		var |= n | VARTYPE_REAL;
		if (!fmt) fmt = (char *)realvarnamelist[n].fmt;
		break;
	    }

	/* Bit name? */
	    n = [World bitNumberOf:buf];
	    if ((int)n != NULLBIT) {
		var |= n | VARTYPE_BIT;
		if (!fmt)
		    fmt = ((var&VARSUM)? "%5.3f": "%d");
		break;
	    }

	/* "allbits" */
	    if (strcmp(buf, "allbits") == EQ || strcmp(buf, "all") == EQ) {
		if (var&(VARAVG|VARFMT))
		    saveError("invalid use of variable 'all'");
		var |= VARTYPE_ALL;
		fmt = NULL;
		break;
	    }

	/* Not found */
	    saveError("unknown variable name '%s'", buf);
	    break;
	}

    /* Allocate and fill in a varliststruct for the variable */
	vptr = (struct varliststruct *) getmem(sizeof(struct varliststruct));
	vptr->var = var;
	vptr->fmt = fmt;
	vptr->next = NULL;
	vptr->accumulator = 0.0;
	if (var&VARSUM) {
	    vptr->nextaccum = accumulatelist;
	    accumulatelist = vptr;
	}
	else
	    vptr->nextaccum = NULL;
	if (lastv)
	    lastv->next = vptr;
	else
	    varlist = vptr;
	lastv = vptr;
    }
    free((void *)varname);

    return self;
}


/*------------------------------------------------------*/
/*	+openOutputStreams				*/
/*------------------------------------------------------*/
+ (BOOL)openOutputStreams
/*
 * Opens all the output streams.  Returns YES if there really were any.
 */
{
    Output *optr;
    BOOL anyvalid = NO;

    lastfp = NULL;
    for (optr = firstInstance; optr; optr = optr->next)
	if ([optr openOutputStream]) anyvalid = YES;
    return anyvalid;
}


/*------------------------------------------------------*/
/*	-openOutputStream				*/
/*------------------------------------------------------*/
- (BOOL)openOutputStream
/*
 * Opens the output stream.  Returns YES if there is really a stream.
 */
{

/* "=" is a special case */
    if (strcmp(filename, "=") == EQ) {
	if (! lastfp)
	    [self error:"'=' for stream '%s' has no valid referent",
							name];
	outputfp = lastfp;
	actual_filename = NULL;
	return YES;
    }

/* Ordinary filename (or "-" for stdout), with possible * or + prefixes */
    actual_filename = namesub(filename, NULL);
    outputfp = openOutputFile(actual_filename, (headinginterval >= -1));
    if (outputfp) {
	lastfp = outputfp;
	return YES;
    }
    else {	/* filename = <none> */
	lastfp = NULL;
	actual_filename = NULL;
	return NO;
    }
}



/*------------------------------------------------------*/
/*	+closeOutputStreams				*/
/*------------------------------------------------------*/
+ closeOutputStreams
/*
 * Close all output streams
 */
{
    Output *optr;

    for (optr = firstInstance; optr; optr = optr->next)
	[optr closeOutputStream];
    return self;
}


/*------------------------------------------------------*/
/*	-closeOutputStream				*/
/*------------------------------------------------------*/
- closeOutputStream
/*
 * Close the output stream
 */
{
    if (outputfp != NULL && outputfp != stdout && actual_filename)
	fclose(outputfp);
    return self;
}


/*------------------------------------------------------*/
/*	+updateAccumulators				*/
/*------------------------------------------------------*/
+ updateAccumulators
/*
 * Update all the accumulation variables in all instances
 */
{
    Output *optr;

    for (optr = firstInstance; optr; optr = optr->next)
	[optr updateAccumulators];
    return self;
}


/*------------------------------------------------------*/
/*	-updateAccumulators				*/
/*------------------------------------------------------*/
- updateAccumulators
/*
 * Update the accumulation variables in this instance
 */
{
    struct varliststruct *vptr;
    int v;

/* Update the accumulation variables */
    for (vptr = accumulatelist; vptr; vptr = vptr->nextaccum) {
	v = vptr->var;
	switch (v&VARTYPEMASK) {
	case VARTYPE_INT:
	    vptr->accumulator += (double)[self intVariable:v&VARCODEMASK];
	    break;
	case VARTYPE_REAL:
	    vptr->accumulator += [self realVariable:v&VARCODEMASK];
	    break;
	case VARTYPE_BIT:
	    if (realworld[v&VARCODEMASK]&1) vptr->accumulator += 1.0;
	    break;
	}
    }
    periodcount++;

    return self;
}


/*------------------------------------------------------*/
/*	+resetAccumulators				*/
/*------------------------------------------------------*/
+ resetAccumulators
/*
 * Reset all the accumulation variables in all instances
 */
{
    Output *optr;

    for (optr = firstInstance; optr; optr = optr->next)
	[optr resetAccumulators];
    return self;
}


/*------------------------------------------------------*/
/*	-resetAccumulators				*/
/*------------------------------------------------------*/
- resetAccumulators
/*
 * Reset the accumulation variables in this instance
 */
{
    struct varliststruct *vptr;

    periodcount = 0;
    for (vptr = varlist; vptr; vptr = vptr->next)
	vptr->accumulator = 0.0;
    return self;
}

/*------------------------------------------------------*/
/*	+writeOutputStream:				*/
/*------------------------------------------------------*/
+ writeOutputStream:(const char *)thename
/*
 * Write out the values of the specified variables for stream "thename", or
 * for the first stream if thename==NULL.
 */
{
    Output *optr;

// Find the specified stream specification, or use first if not specified
    optr = firstInstance;
    if (thename) {
	for (; optr; optr = optr->next)
	    if (strcmp(optr->name, thename) == EQ) break;
    }
    if (optr)
	[optr writeOutputStream];
    else
	Message("*** unknown output stream '%s' -- request ignored", thename);
    return self;
}


/*------------------------------------------------------*/
/*	-writeOutputStream				*/
/*------------------------------------------------------*/
- writeOutputStream
/*
 * Write out the values of the specified variables for this instance,
 * unless already done at this time.
 */
{
    int v, i, n;
    BOOL first;
    struct varliststruct *vptr;
    double dperiodcount, val;

    if (t == lasttime) return self;	// Don't do it twice
    if (! outputfp) return self;		// Disabled (<none>)

// Put out a heading line if it's time
    if ((headinginterval > 0 && outputcount%headinginterval == 0) ||
					(outputcount == headinginterval)) {
	putc('#', outputfp);
	for (vptr = varlist; vptr; vptr = vptr->next) {
	    v = vptr->var;
	    putc(' ', outputfp);
	    if (v&VARNORM) putc(CHARAVG, outputfp);
	    else if (v&VARSUM) putc(CHARSUM, outputfp);
	    n = v&VARCODEMASK;
	    switch (v&VARTYPEMASK) {
	    case VARTYPE_INT:
		fputs(intvarnamelist[n].name, outputfp);
		break;
	    case VARTYPE_REAL:
		fputs(realvarnamelist[n].name, outputfp);
		break;
	    case VARTYPE_BIT:
		fputs([World nameOfBit:n], outputfp);
		break;
	    case VARTYPE_ALL:
		fputs("all", outputfp);
		break;
	    }
	}
	fputc('\n', outputfp);
    }

// Put out the variable values
    dperiodcount = (double)periodcount;
    for (vptr = varlist, first = YES; vptr; vptr = vptr->next) {
	v = vptr->var;
	if (!(first || (v&VARNOSPACE)))
	    putc(' ', outputfp);
	if (v&VARSUM) {
	    val = vptr->accumulator;
	    if (v&VARNORM && periodcount > 0)
		val /= dperiodcount;
	    fprintf(outputfp, vptr->fmt, val);
	    vptr->accumulator = 0.0;
	}
	else {
	    switch (v&VARTYPEMASK) {
	    case VARTYPE_INT:
		fprintf(outputfp, vptr->fmt,
					[self intVariable:v&VARCODEMASK]);
		break;
	    case VARTYPE_REAL:
		fprintf(outputfp, vptr->fmt,
					[self realVariable:v&VARCODEMASK]);
		break;
	    case VARTYPE_BIT:
		fprintf(outputfp, vptr->fmt, (realworld[v&VARCODEMASK]&1));
		break;
	    case VARTYPE_ALL:
		for (i = 0; i < nworldbits; i++)
		    putc((realworld[i]&1)+'0', outputfp);
		break;
	    }
	}
	first = NO;
    }
    putc('\n', outputfp);
    fflush(outputfp);

    periodcount = 0;
    outputcount++;
    lasttime = t;

    return self;
}


/*------------------------------------------------------*/
/*	-intVariable:					*/
/*------------------------------------------------------*/
- (int)intVariable:(int)varcode
/*
 * Returns the value of an integer variable.  The numbering here must
 * agree with that in the intvarnamelist[] table.
 */
{
    int val;

    switch (varcode) {
    case 0:	val = 1;			break;	// Must be first
    case 1:	val = t;			break;
    case 2:	val = t - 1;			break;
    case 3:	val = runid;			break;
    case 4:	val = [agentManager numagents];	break;
    case 5:	val = rseed;			break;
    default:
	val = 0;
	[self error:"Invalid varcode %d", varcode];
	/*NOTREACHED*/
    }
    return val;
}


/*------------------------------------------------------*/
/*	-realVariable:					*/
/*------------------------------------------------------*/
- (double)realVariable:(int)varcode
/*
 * Returns the value of a real variable.  The numbering here must
 * agree with that in the realvarnamelist[] table.
 */
{
    double val;

    switch (varcode) {
    case 0:	val = price;			break;
    case 1:	val = dividend;			break;
    case 2:	val = dividend/intrate;		break;
    case 3:	val = volume;			break;
    case 4:	val = bidtotal;			break;
    case 5:	val = offertotal;		break;
    case 6:	val = pmav[0];			break;
    case 7:	val = pmav[1];			break;
    case 8:	val = pmav[2];			break;
    case 9:	val = pmav[3];			break;
    case 10:	val = dmav[0];			break;
    case 11:	val = dmav[1];			break;
    case 12:	val = dmav[2];			break;
    case 13:	val = dmav[3];			break;
    case 14:	val = price*intrate/dividend;	break;
    case 15:	val = profitperunit;		break;
    case 16:	val = returnratio;		break;
    case 17:	val = intrate;			break;
    case 18:	val = [specialist eta];		break;
    case 19:	val = oldprice;			break;
    case 20:	val = olddividend;		break;
    case 21:	val = olddividend/intrate;	break;
    case 22:	val = oldvolume;		break;
    case 23:	val = oldbidtotal;		break;
    case 24:	val = oldoffertotal;		break;
    default:
	val = 0.0;
	[self error:"Invalid varcode %d", varcode];
	/*NOTREACHED*/
    }
    return val;
}


/*------------------------------------------------------*/
/*	+showOutputStreams:				*/
/*------------------------------------------------------*/
+ showOutputStreams:(FILE *)fp
/*
 * Writes to fp (the log file) all the parameters defining all the output
 * streams, with explanatory names/comments.
 */
{
    Output *optr;

    showstrng(fp, "-- output stream specifications --", "");

    for (optr = firstInstance; optr; optr = optr->next)
	[optr showOutputStream:fp];

    showstrng(fp,"(end of output stream specifications)","end");

    return self;
}


/*------------------------------------------------------*/
/*	-showOutputStream:				*/
/*------------------------------------------------------*/
- showOutputStream:(FILE *)fp
/*
 * Writes to fp (the log file) all the parameters defining this output
 * stream, with explanatory names/comments.
 */
{
    int v, n;
    struct varliststruct *vptr;
    char buf[MAXSTRING+30];

    sprintf(buf, "-- stream '%s' --", name);
    showstrng(fp, buf, "");
    showstrng(fp, "streamname", name);
    showoutputfilename(fp, "filename", filename, actual_filename);
    showint(fp, "headinginterval", headinginterval);
    sprintf(buf, "-- variables in stream '%s' --", name);
    showstrng(fp, buf, "");
    for (vptr = varlist; vptr; vptr = vptr->next) {
	v = vptr->var;
	n = v&VARCODEMASK;
	switch (v&VARTYPEMASK) {
	case VARTYPE_INT:
	    showVariable(fp, intvarnamelist[n].name,
			intvarnamelist[n].description, vptr->fmt, v);
	    break;
	case VARTYPE_REAL:
	    showVariable(fp, realvarnamelist[n].name,
			realvarnamelist[n].description, vptr->fmt, v);
	    break;
	case VARTYPE_BIT:
	    showVariable(fp, [World nameOfBit:n],
			[World descriptionOfBit:n], vptr->fmt, v);
	    break;
	case VARTYPE_ALL:
	    showVariable(fp, "all", "all world bits", NULL, v);
	    break;
	default:
	    [self error:"Illegal vartype %d", v&VARTYPEMASK];
	}
    }
    showstrng(fp,"(end of variable list)","end");

    return self;
}


/*------------------------------------------------------*/
/*	showVariable()					*/
/*------------------------------------------------------*/
static void showVariable(FILE *fp, const char *name,
			const char *description, const char *fmt, int v)
/*
 * Writes one variable name.
 */
{
    char vbuf[MAXSTRING];
    char dbuf[80];
    char *ptr;

    if (v&VARNOSPACE)
	showstrng(fp, "(no space between items)", "|");

    ptr = vbuf;
    if (v&VARNORM) *ptr++ = CHARAVG;
    else if (v&VARSUM) *ptr++ = CHARSUM;

    strcpy(ptr, name);

    if (v&VARFMT) {
	ptr += strlen(name);
	sprintf(ptr, "(%s)", fmt);
    }

    if (v&VARAVG) {
	ptr = ((v&VARNORM)? "AVERAGE": "SUM");
	if (strchr(description, ' '))
	    sprintf(dbuf, "%s OF (%s)", ptr, description);
	else
	    sprintf(dbuf, "%s OF %s", ptr, description);
	if ((v&(VARCODEMASK|VARTYPEMASK|VARAVG)) == (VARTYPE_INT|VARSUM))
	    strcat(dbuf, " -- periods since last print");
	showstrng(fp, dbuf, vbuf);
    }
    else
	showstrng(fp, description, vbuf);
}

@end
