// The Santa Fe Stock Market -- Implementation of Output class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// One instance of this class is instantiated for each output stream that's
// defined in the marketcontrol file.  It deals with reading and logging the
// list of variables to be printed, and printing their values as needed.

// PUBLIC METHODS
//
// Most public methods are class methods which send on the appropriate message
// to each of the instances.
//
// + writeNamesToFile:(FILE *)fp
//	Writes the name and description of all the output variables to
//	file "fp".  For use by the -n option.
//
// - initWithName:(const char *)name;
//	Initializes an instance, reading the description of stream "name"
//	from the current input file.
//
// + postEvolve
//	Updates internal variables after evolution has occurred, for all
//	instances.
//
// + (BOOL)openOutputStreams
//	Opens all output streams.
//
// + closeOutputStreams;
//	Closes all output streams.
//
// + updateAccumulators;
//	Updates all the accumulation variables (specified with a CHARSUM or
//	CHARAVG prefix in the input) in all instances.  This is called once
//	per period.
//
// + resetAccumulators;
//	Resets to 0 all the accumulation variables in all instances.  Used
//	at time 0.
//
// + writeOutputToStream:(const char *)name;
//	Writes out the output specifications for the instance named "name".
//	This is called for each "w name" event.  If name is NULL (from a
//	plain "w" event), then the first instance is used.
//
// + resetAccumulatorsForStream:(const char *)name;
//	Resets to 0 the accumulation variables for the instance named "name".
//	This is called for each "reset name" event.  If name is NULL (from a
//	plain "reset" event), then the first instance is used.
//
// + writeOutputSpecifications:(FILE *)fp;
//	Write out the variable names etc for all instances to file fp
//	(the log file).

#include "global.h"
#include "output.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "amanager.h"
#include "agent.h"
#include "dividend.h"
#include "speclist.h"
#include "world.h"
#include "error.h"
#include "util.h"
#include "version.h"

// Masks and code values for "var" in the linked list of varliststruct's
// that specifies the variables to be printed.
// 1. Used for both "variable" items and "special" items:
#define V_CODEMASK	0377		// Mask for variable/special number
#define V_SPECIAL	0400		// Set if a special, not if a variable
#define V_NOSPACE	01000		// Set for no space/newline before item
#define V_USESAGID	02000		// Set if the agid variable is used
#define V_BAD		04000		// Set for invalid variable
// 2. Used only by "variable" items:
#define V_TYPEMASK	070000		// Mask for variable type:
#define V_TYPE_NONE	0		//	None -- just a format
#define V_TYPE_INT	010000		//	Integer
#define V_TYPE_REAL	020000		//	Real (double)
#define V_TYPE_BIT	030000		//	Condition bit
#define V_TYPE_STRING	040000		//	String
#define V_TYPE_ALLBITS	050000		//	All condition bits
#define V_TYPE_DETAIL	060000		//	Detail -- calls -printDetail:
#define V_SUM		0100000		// Set for an accumulation variable
#define V_NORM		0200000		// Set for normalization after summing
#define V_AVG		(V_SUM|V_NORM)	// Both set for averaging
#define V_FMT		01000000	// Set if format explicitly specified
#define V_INITIALNL	02000000	// Set if format starts with \n
#define V_FINALNL	04000000	// Set if format ends with \n
#define V_INCLASSBLOCK	010000000	// In class-level block
#define V_INTYPEBLOCK	020000000	// In type-level block
#define V_INAGENTBLOCK	040000000	// In agent-level block
#define V_INBLOCK	(V_INCLASSBLOCK|V_INTYPEBLOCK|V_INAGENTBLOCK)
#define V_NEEDSCLASS	0100000000	// Set if variable needs a class
#define V_NEEDSTYPE	0200000000	// Set if variable needs a type
#define V_NEEDSAGENT	0400000000	// Set if variable needs an agent
#define V_NEEDS		(V_NEEDSCLASS|V_NEEDSTYPE|V_NEEDSAGENT)
#define V_AGENTCLASS	01000000000	// Set if class BF, BS, DU, FF, ...
// 3. Used only by "special" items:
#define V_HASCLASS	010000		// Set if a specific class is specified
#define V_HASTYPE	020000		// Set if a specific type is specified
#define V_HASAGENT	040000		// Set if a specific agent is specified
#define V_HASCTA	(V_HASCLASS|V_HASTYPE|V_HASAGENT)
#define V_NUMERIC	0100000		// Set if class/type/agent is numeric
#define V_FORLOOP	01000000	// Set if a loop over agents
#define V_SUMLOOP	02000000	// Set if a sum over agents
#define V_AVGLOOP	04000000	// Set if an average over agents
#define V_LOOP		(V_FORLOOP|V_SUMLOOP|V_AVGLOOP)

// Variables "kind" of class
#define V_OUTSIDE	01		// Outside
#define V_BF		02		// BF
#define V_BS		04		// BS
#define V_DU		010		// DU
#define V_FF		020		// FF
#define V_O		(V_OUTSIDE|V_BF|V_BS|V_DU|V_FF)

#define V_C		V_INCLASSBLOCK
#define V_T		V_INTYPEBLOCK
#define V_A		V_INAGENTBLOCK
#define V_CTA		(V_C|V_T|V_A)

#define V_C_O		(V_C|V_O)
#define V_T_O		(V_T|V_O)
#define V_A_O		(V_A|V_O)

#define V_T_BF		(V_T|V_BF)
#define V_A_BF		(V_A|V_BF)

#define V_T_BS		(V_T|V_BS)

// Prefix characters for variable specifications
#define CHARNOSPACE	'|'
#define CHARSUM		'+'
#define CHARAVG		'@'
char nospace[] = {CHARNOSPACE, EOS};	// String version of CHARNOSPACE

// Indent string prefixed to description inside an agent block
#define INDENT		".  "

// List of variable names, default formats, and descriptions.
// NB: If you make any changes here, also check or change:
// 1. -intVariable:, -realVariable:, or -stringVariable:;
// 2. the "names" documentation file (use "market -n >names" to regenerate).
struct varnamestruct {
    const char *name;
    const char *fmt;
    unsigned long int level;
    const char *description;
};
// ------------- Integer variables (int) ------------
static struct varnamestruct intlist[] = {
// NB: "1" must be first -- index 0
{"1",		"%d",		V_O,	"1"},				// 0
{"t",		"%5d",		V_O,	"time"},
{"oldt",	"%5d",		V_O,	"time - 1"},
{"run",		"%d",		V_O,	"run number"},
{"mseed",	"%d",		V_O,	"random seed for market and agents"},
{"dseed",	"%d",		V_O,	"random seed for dividend stream"},// 5
{"nagents",	"%d",		V_O,
		"number of agents in class, type, or all *"},
{"nclasses",	"%d",		V_O,	"number of classes"},
{"ntypes",	"%d",		V_O,
		"number of types in class, type, or all *"},
{"generation",	"%d",		V_O,	"evolutionary generation"},
{"classnum",	"%d",		V_C_O,	"class number"},		// 10
{"typenum",	"%d",		V_T_O,	"type number"},
{"nrules",	"%d",		V_T_O,	"number of rules or forecasters"},
{"nbits",	"%d",		V_T_O,
		"number of condition bits/rule (excluding nulls)"},
{"nbitsall",	"%d",		V_T_O,
		"number of condition bits/rule (including nulls)"},
{"sumbits",	"%d",		V_T_O,
		"total condition bit usage for type or agent *"},	// 15
{"agentnum",	"%d",		V_A_O,	"agent number"},
{"agenttag",	"%d",		V_A_O,	"agent number - 1 (starts at 0)"},
{"index",	"%d",		V_A_O,
		"ordinal number of this agent in a loop"},
{"gacount",	"%d",		V_A_O,	"number of GA runs"},
{"mincount",	"%d",		V_T_BF,	"rules exclude than mincount"},	// 20
{"gainterval",	"%d",		V_T_BF,	"genetic algorithm is run if due"},
{"firstgatime",	"%d",		V_T_BF,	"genetic algorithm first"},
{"longtime",	"%d",		V_T_BF,	"unused time before generalize"},
{"nactive",	"%d",		V_A_BF,	"rules than conditions"}
};
// ------------- Real variables (double) ------------
static struct varnamestruct  reallist[] = {
{"p",		"%7.3f",	V_O,	"price"},			// 0
{"d",		"%7.4f",	V_O,	"dividend"},
{"d/r",		"%7.3f",	V_O,	"dividend/interest_rate"},
{"v",		"%6.3f",	V_O,	"volume"},
{"b",		"%6.3f",	V_O,	"bids"},
{"o",		"%6.3f",	V_O,	"offers"},			// 5
{"p5",		"%7.3f",	V_O,	"5-period MA of price"},
{"p20",		"%7.3f",	V_O,	"20-period MA of price"},
{"p100",	"%7.3f",	V_O,	"100-period MA of price"},
{"p500",	"%7.3f",	V_O,	"500-period MA of price"},
{"d5",		"%7.4f",	V_O,	"5-period MA of dividend"},	// 10
{"d20",		"%7.4f",	V_O,	"20-period MA of dividend"},
{"d100",	"%7.4f",	V_O,	"100-period MA of dividend"},
{"d500",	"%7.4f",	V_O,	"500-period MA of dividend"},
{"pr/d",	"%7.5f",	V_O,	"price*interest_rate/dividend"},
{"ppu",		"%7.4f",	V_O,	"profitperunit"},		// 15
{"return",	"%8.6f",	V_O,	"returnratio"},
{"vol",		"%7.4f",	V_O,	"volatility - 1 back"},
{"vol5",	"%7.4f",	V_O,	"volatility - 5 back"},
{"vol20",	"%7.4f",	V_O,	"volatility - 20 back"},
{"vol100",	"%7.4f",	V_O,	"volatility - 100 back"},	// 20
{"vol500",	"%7.4f",	V_O,	"volatility - 500 back"},
{"r",		"%6.4f",	V_O,	"intrate"},
{"eta",		"%8.6f",	V_O,	"eta"},
{"oldp",	"%7.3f",	V_O,	"old price"},
{"oldd",	"%7.4f",	V_O,	"old dividend"},		// 25
{"oldd/r",	"%7.3f",	V_O,	"old dividend/interest_rate"},
{"oldv",	"%6.3f",	V_O,	"old volume"},
{"oldb",	"%6.3f",	V_O,	"old bids"},
{"oldo",	"%6.3f",	V_O,	"old offers"},
{"avgbits",	"%7.4f",	V_T_O,
		"average condition bit usage per agent *"},		// 30
{"avgtypebits",	"%7.3f",	V_T_O,
		"average condition bit usage in type *"},
{"wealth",	"%7.1f",	V_A_O,	"wealth"},
{"relwealth",	"%6.4f",	V_A_O,	"relative wealth"},
{"position",	"%7.4f",	V_A_O,	"stock holding"},
{"holding",	"%7.4f",	V_A_O,	"stock holding"},		// 35
{"stockvalue",	"%7.2f",	V_A_O,	"stock value"},	
{"cash",	"%7.1f",	V_A_O,	"cash"},
{"profit",	"%6.3f",	V_A_O,	"profit moving average"},
{"demand",	"%7.3f",	V_A_O,	"demand"},
{"target",	"%7.3f",	V_A_O,	"target"},			// 40
{"tauv",	"%7.4f",	V_T_BF,	"moving average estimated variance"},
{"lambda",	"%7.4f",	V_T_BF,	"risk-aversion"},
{"maxbid",	"%7.4f",	V_T_BF,	"maximum bid parameter"},
{"subrange",	"%7.4f",	V_T_BF,	"random fraction of min-max range"},
{"a_min",	"%7.4f",	V_T_BF,	"min for p+d coefficient"},	// 45
{"a_max",	"%7.4f",	V_T_BF,	"max for p+d coefficient"},
{"b_min",	"%7.4f",	V_T_BF,	"min for dividend coefficient"},
{"b_max",	"%7.4f",	V_T_BF,	"max for dividend coefficient"},
{"c_min",	"%7.4f",	V_T_BF,	"min for constant term"},
{"c_max",	"%7.4f",	V_T_BF,	"max for constant term"},	// 50
{"newrulevar",	"%7.4f",	V_T_BF,	"variance to a new forecaster"},
{"initvar",	"%7.4f",	V_T_BF,
		"variance of overall forecast for t<200"},
{"bitcost",	"%7.4f",	V_T_BF,	"penalty parameter for specificity"},
{"maxdev",	"%7.4f",	V_T_BF,
		"max deviation of a forecast in variance estimation"},
{"bitprob",	"%7.4f",	V_T_BF,
		"bits probability (current, p = prob)"},		// 55
{"newfrac",	"%7.4f",	V_T_BF,	"fraction of rules replaced"},
{"pcrossover",	"%7.4f",	V_T_BF,
		"probability of running crossover() at all"},
{"plinear",	"%7.4f",	V_T_BF,	"linear combination crossover prob"},
{"prandom",	"%7.4f",	V_T_BF,
		"random from each parent crossover prob"},
{"pmutation",	"%7.4f",	V_T_BF,	"per bit mutation prob"},	// 60
{"plong",	"%7.4f",	V_T_BF,	"long jump prob"},
{"pshort",	"%7.4f",	V_T_BF,	"short (neighborhood) jump prob"},
{"nhood",	"%7.4f",	V_T_BF,	"size of neighborhood"},
{"genfrac",	"%7.4f",	V_T_BF,	"fraction of 0/1 bits to generalize"},
{"forecast",	"%7.4f",	V_A_BF,	"this forecast of return"},	// 65
{"variance",	"%7.4f",	V_A_BF,	"variance of forecast"}
};
// ------------- String variables (const char *) ------------
static struct varnamestruct stringlist[] = {
{"title",	"%s",		V_O,	"title of this program"},	// 0
{"version",	"%s",		V_O,	"version number"},
{"versiondate",	"%s",		V_O,	"version date"},
{"username",	"%s",		V_O,	"current username"},
{"hostname",	"%s",		V_O,	"current hostname"},
{"date",	"%s",		V_O,	"date and time"},		// 5
{"classname",	"%s",		V_C_O,	"name of class"},
{"typename",	"%-3s",		V_T_O,	"name of type"},
{"filename",	"%s",		V_T_O,	"type's parameter file name"},
{"agentname",	"%7s",		V_A_O,	"name of agent"},
{"shortname",	"%7s",		V_A_O,	"shortened name of agent"},	// 10
{"selectionmethod", "%8s",	V_T_BF,
		"overall forecast: average/best/roulette"},
{"individual",	"%3s",		V_T_BF,
		"overal variances are determined: no/yes"}
};

// Miscellaneous keywords with external significance
#define BLOCKENDNAME	"END"		// End of block
#define STREAMENDNAME	"end"		// End of stream
#define MAXNAME		"MAX"
#define DETAILNAME	"details"
#define AGENTSNAME	"AGENTS"
#define CLASSNAME	"CLASS"
#define TYPENAME	"TYPE"
#define AGENTNAME	"AGENT"
#define FORNAME		"FOR"
#define SUMNAME		"SUM"
#define AVGNAME		"AVG"
#define AFNAME		"AFTERFIRST"

// Special keywords for block start/end etc
struct specialstruct {
    const char *name;
    const unsigned long flags;
    const char *description;
};
static struct specialstruct speciallist[] = {
// NB: END must be first, MAX must be second (index 0 and 1)
{BLOCKENDNAME,	0,		"end of block"},			// 0
{MAXNAME,	0,		"maximum agents for a loop/sum/average"},
{AGENTSNAME, 	0,		"start of all-agents block"},
{CLASSNAME,  	V_HASCLASS,	"start of class block"},
{TYPENAME,   	V_HASTYPE,	"start of type block"},
{AGENTNAME,  	V_HASAGENT, 	"start of single agent block"},
{FORNAME,	V_FORLOOP,	"block prefix for loop over agents"},	// 5
{SUMNAME,	V_SUMLOOP,	"block prefix for sum over agents"},
{AVGNAME,	V_AVGLOOP,	"block prefix for average over agents"},
{AFNAME,	0,		"starting point after 1st pass"}
};

struct kindstruct {
    unsigned long int level;
    const char *name;
    int classindex;
};
static struct kindstruct kindarray[] = {
{V_BF,	"BF",	0},
{V_BS,	"BS",	0},
{V_DU,	"DU",	0}
};

// Derived sizes (known at compile time)
#define INTVARS		(sizeof(intlist)/sizeof(struct varnamestruct))
#define REALVARS	(sizeof(reallist)/sizeof(struct varnamestruct))
#define STRINGVARS	(sizeof(stringlist)/sizeof(struct varnamestruct))
#define NSPECIALS	(sizeof(speciallist)/sizeof(struct specialstruct))
#define KINDARRAYS	(sizeof(kindarray)/sizeof(struct kindstruct))

// Structure for list of variables to print.  In effect there are two
// versions, one for regular variables (u.v) and one for "special" entries
// (u.s) in the variable list.  Special entries are used for the beginning
// and end of agent blocks and for the AFTERFIRST marker.  The V_SPECIAL bit
// in var is set for specials, not set for regular variables.
struct varliststruct {
    struct varliststruct *next;		// Next in list
    unsigned long var;			// Variable/special code + flags
    Agent *agid;			// For single-agent accumulation
    union {
	struct {	// For regular variables
	    double accumulator;		// Running sum
	    struct varliststruct *nextaccum;	// Next accumulated variable
	    const char *fmt;		// Format string
	} v;
	struct {	// For specials
	    char *aname;		// External name of class/type/agent
	    int anum;			// Internal number of class/type/agent
	    int maxagents;		// Limit on number to list
	} s;
    } u;
};

// Maximum characters in class/type/agent name (u.s.aname)
#define MAXAGENTSPEC	(MAXNAMELEVELS*4+8)

// Class variables
static Output *firstInstance = NULL;
static Output *lastInstance = NULL;
static FILE *lastfp = NULL;
static unsigned long classable = 0;
static unsigned long *kind;
static const char **kindname;
static int multipleclass = 0;
static int multipletype = 0;

// Private function prototypes
static unsigned long needs(unsigned long level, unsigned long inblock,
					int class, int type, char *buf);
static void getCTAname(unsigned long *pvar, char **paname, int *panum);
static const char *levelVariable(unsigned long level);
static const char *kindClass(unsigned long level);
static void showVariable(FILE *fp, const char *name, const char *description,
			    const char *fmt, unsigned long v, BOOL indent);

// Private methods
@interface Output(Private)
- debugInit;
- agidList;
- (BOOL)openOutputStream;
- closeOutputStream;
- updateAccumulators;
- accumulate:(struct varliststruct *)vptr;
- resetAccumulators;
- writeOutputToStream;
- makeHeading;
- (int)intVariable:(unsigned long)v;
- (int)sumbits:(unsigned long)v;
- (double)realVariable:(unsigned long)v;
- (const char *)stringVariable:(unsigned long)v;
- writeOutputSpecifications:(FILE *)fp;
@end

@implementation Output


/*------------------------------------------------------*/
/*	+writeNamesToFile:				*/
/*------------------------------------------------------*/
+ writeNamesToFile:(FILE *)fp
{
    int i;

    drawLine(fp, '=');
    fprintf(fp,"#\t*** %s ***\n#  Version %s - %s\n",
	PROJECTTITLE, versionnumber(), versiondate());
    drawLine(fp, '=');
    fputs(
"# This is a list of the variable names and keywords that can be used in\n"
"# output specifications.  The bit names can also be used in the parameter\n"
"# files of some agent classes to name condition bits.\n"
"#\n"
"# Integer variables and bits need integer output formats (e.g., %d)\n"
"# unless averaged with '@' or AVG.  Real variables and any averaged\n"
"# variables or bits need double output formats (e.g., %f).\n"
"#\n"
"# Items marked with a '*' change their meaning according to the context in\n"
"# which they are used -- see the documentation for output specifications.\n"
"#\n"
"# Use the -n option to produce this listing.\n",
	fp);

    fputs("\n# ---------- Integer variables ----------\n", fp);
    for (i=0; i<INTVARS; i++) {
	showbarestrng2(fp, levelVariable(intlist[i].level),
			intlist[i].description, intlist[i].name);
    }

    fputs("\n# ---------- Real variables ----------\n", fp);
    for (i=0; i<REALVARS; i++) {
	showbarestrng2(fp, levelVariable(reallist[i].level),
			reallist[i].description, reallist[i].name);
    }

    fputs("\n# ---------- String variables ----------\n", fp);
    for (i=0; i<STRINGVARS; i++) {
	showbarestrng2(fp, levelVariable(stringlist[i].level),
			stringlist[i].description, stringlist[i].name);
    }

    fputs("\n# ---------- Special keywords ----------\n", fp);
    for (i=0; i<NSPECIALS; i++)
	showbarestrng(fp, speciallist[i].description, speciallist[i].name);

    putc('\n', fp);
    showbarestrng(fp, 
		"class/type/agent-dependent details specified by 'string' *",
		DETAILNAME "(string)");

// Ask the World to write all the bitnames
    fputs("\n# ---------- Bits * ----------\n", fp);
    [World writeNamesToFile:fp];

    putc('\n', fp);
    showbarestrng(fp, "all of the above bits *", "allbits");

    return self;
}


/*------------------------------------------------------*/
/*	levelVariable()					*/
/*------------------------------------------------------*/
static const char *levelVariable(unsigned long v)
{
    static char buf[24];
    int i;

    switch (v&V_CTA) {
    case V_C: strcpy(buf, "CLASS"); break;
    case V_T: strcpy(buf, "TYPE "); break;
    case V_A: strcpy(buf, "AGENT"); break;
    default:  strcpy(buf, "     "); break;
    }
    v = v&V_O;
    if (v != V_O) {
	for (i = 0; i < KINDARRAYS; i++)
	    if (v&kindarray[i].level) {
		strcat(buf, " ");
		strcat(buf, kindarray[i].name);
	    }
    }

    return buf;
}


/*------------------------------------------------------*/
/*	kindClass()					*/
/*------------------------------------------------------*/
static const char *kindClass(unsigned long v)
{
    static char buf[24];
    int i ,k;

    buf[0] = '\0';
    k = 0;
    v = v&V_O;
    if (v != V_O) {
	for (i = 0; i < KINDARRAYS; i++)
	    if (v&kindarray[i].level) {
		if (k > 0) strcat(buf, " ");
		strcat(buf, kindarray[i].name);
		k = 1;
	    }
    }

    return buf;
}


/*------------------------------------------------------*/
/*	+initClass					*/
/*------------------------------------------------------*/
+ initClass
{
    int i, n, ci, k;
    int cl = -1;

// {V_BF, "BF", classindex}, ...
    for (i = 0; i < KINDARRAYS; i++)
	kindarray[i].classindex =
		[agentManager classWithName:kindarray[i].name];

// kind[2] => V_BF, ...
    n = [agentManager numclasses];
    kind = (unsigned long int *)getmem(sizeof(unsigned long int)*n);
    kindname = (const char **)getmem(sizeof(const char *)*n);
    for (i = 0; i < n; i++) kind[i] = 0;
    for (i = 0; i < n; i++) kindname[i] = "  ";
    for (i = 0; i < KINDARRAYS; i++) {
	ci = kindarray[i].classindex;
	if (ci >= 0) {
	    kind[ci] = kindarray[i].level;
	    kindname[ci] = kindarray[i].name;
	    cl = ci;
	}
    }

// Variables and invoving all class
    classable = V_OUTSIDE;
    k = 0;
    ci = -1;
    for (i = 0; i < KINDARRAYS; i++)
	if([agentManager nagentsInClass:kindarray[i].classindex] > 0) {
	    classable |= kindarray[i].level;
	    ci = i;
	    ++k;
	}
    if (k > 1) {
	multipleclass = 1;
	multipletype = 1;
    }
    else if ([agentManager numtypes] > 1) multipletype = 1;
	
// Debug
    if (debug&DEBUGOUTPUT) {
	for (i = 0; i < KINDARRAYS; i++)
	    message("#o kindarray[%d]: level %04lo name %s classindex %d", i,
		kindarray[i].level,
		kindarray[i].name,
		kindarray[i].classindex);
	message("#o classable: %s, multipleclass: %d, multipletype: %d",
		kindClass(classable), multipleclass, multipletype);
	for (i = 0; i < n; i++)
	    message("#o kind[%d] = %04lo, kindname[%d] = %s", i, kind[i],
					i, kindname[i]);
    }

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
    unsigned long var, n, previousnospace, usesagid, inblock, inlinebit;
    unsigned long specialcode, prefixcode;
    int maxagents, anum, i;
    const char *token, *ptr;
    char *fmt, *aname, *optr, *maxstring, buf[MAXSTRING+1];
    struct varliststruct *vptr, *lastv, *blockstart;
    BOOL save, noaccumulate;

// Add this instance to the end of the list in this class
    (lastInstance? lastInstance->next: firstInstance) = self;
    lastInstance = self;
    next = NULL;

// Read and store the filename and headinginterval
    filename = readString("filename");
    headinginterval = readInt("headinginterval",-2,MAXINTGR);

// Initialize remaining instance variables
    agid = nil;
    name = myname;
    actual_filename = NULL;
    outputfp = NULL;
    varlist = NULL;
    accumulatelist = NULL;
    outputcount = 0;
    periodcount = 0;
    lasttime = MININTGR;
    a = -1;
    class = (multipleclass? -1: [agentManager classWithNumber:1]);
    if (multipleclass+multipletype == 0)
        type = [agentManager ntypesInClass:class];
    else
        type = -1;
    anum = 0;
    aname = NULL;
    i = 1;

// Read and encode the list of output variables
    previousnospace = 0;	// 0, or V_NOSPACE if previous CHARNOSPACE
    lastv = NULL;		// last varliststruct in list
    specialcode = 0;		// index into speciallist[] for current block
    prefixcode = 0;		// 0 or V_FORLOOP or V_SUMLOOP or V_AVGLOOP
    inblock = 0;		// 0 or V_INCLASSBLOCK, ..., V_INAGENTBLOCK
    usesagid = 0;		// 0 or V_USESAGID from head of block
    inlinebit = 0;		// 0 or V_NOSPACE from head of block
    noaccumulate = NO;		// YES if accumulation (@ or +) is forbidden
    blockstart = NULL;		// pointer to head of current block
    for ( ; ;free((void *)token)) {
	token = readString("varname");
	if (strcmp(token, "???") == EQ || strcmp(token, STREAMENDNAME) == EQ) {
	    if (inblock)
		saveError("end of variable list inside %s block",
						speciallist[specialcode].name);
	    break;
	}

    // Debug: token
	if (debug&DEBUGOUTPUT)
	    message("#o %3d: token: '%-12s': aname: %s anum: %d",
					i, token, (aname?aname:"-"), anum);

    // Set the NOSPACE bit if there's a leading CHARNOSPACE.  If this
    // stands alone, record it to use at the next call.
	var = previousnospace;
	ptr = token;
	if (*ptr == CHARNOSPACE) {
	    ptr++;
	    if (*ptr == EOS) { previousnospace = V_NOSPACE; continue; }
	    var = V_NOSPACE;
	}
	previousnospace = 0;

    // Strip off and record a leading sum or average prefix character
	if (*ptr == CHARSUM) { ptr++; var |= V_SUM; }
	else if (*ptr == CHARAVG) { ptr++; var |= V_AVG; }
	if ((var&V_SUM) && noaccumulate) {
	    saveError("can't accumulate '%s' inside %s %s",
					token, speciallist[specialcode].name,
					(prefixcode?"loop":"block"));
	    var |= V_BAD;
	}

    // Copy the string to our local buffer up to '(' or EOS.
	for (optr = buf; optr<buf+MAXSTRING; ) {
	    if (*ptr == '(' || *ptr == EOS) break;
	    *optr++ = *ptr++;
	}
	*optr = EOS;

    // Make a copy of the format string (in parentheses) if any
	fmt = NULL;
	if (*ptr == '(') {
	    n = strlen(ptr)-1;
	    if (ptr[n] != ')') {
		saveError("missing ')' in variable '%s' "
				    "-- missing double-quotes?", token);
	    	var |= V_BAD;
	    }
	    if (n > 0) {
		fmt = (char *)getmem(sizeof(char)*n);
	    // Translate backslash codes in format strings
		for (optr = fmt, ptr++; --n; ptr++) {
		    if (*ptr == '\\') {
			switch(*++ptr) {
			case 'a': *optr++ = '\a'; break;
			case 'b': *optr++ = '\b'; break;
			case 'f': *optr++ = '\f'; break;
			case 'n': *optr++ = '\n'; break;
			case 'r': *optr++ = '\r'; break;
			case 't': *optr++ = '\t'; break;
			case 'v': *optr++ = '\v'; break;
			case '\n': break;
			default: *optr++ = *ptr; break; // includes \\, \", etc
			}
			n--;
		    }
		    else *optr++ = *ptr;
		}
		*optr = EOS;
		var |= V_FMT;
		if (fmt[0] == '\n') var |= V_INITIALNL;
		if (optr > fmt && *--optr == '\n') var |= V_FINALNL;
	    }
	}

    // Add in usesagid and inblock bits
	var |= usesagid|inblock;

    // Look for the name in various places
	for (;;) {		// fake loop to allow break
	    save = NO;

	// Empty variable (just a format)?
	    if (buf[0] == '\0') {
		if (!fmt) {
		    saveError("empty variable name");
		    var |= V_BAD;
		    break;
		}
		if (var&V_SUM) {
		    saveError("sum/average of empty variable");
		    var |= V_BAD;
		    break;
		}
		var |= V_TYPE_NONE;
		save = YES;
		break;
	    }

	// Real variable name?
	    for (n = 0; n < REALVARS; n++)
		if (strcmp(buf, reallist[n].name) == EQ &&
		    (reallist[n].level&classable)) break;
	    if (n < REALVARS) {
		var |= needs(reallist[n].level, inblock, class, type, buf);
		var |= n | V_TYPE_REAL;
		if (!fmt) fmt = (char *)reallist[n].fmt;
		save = YES;
		break;
	    }

	// Integer variable name?
	    for (n = 0; n < INTVARS; n++)
		if (strcmp(buf, intlist[n].name) == EQ &&
		    (intlist[n].level&classable)) break;
	    if (n < INTVARS) {
		var |= needs(intlist[n].level, inblock, class, type, buf);
		var |= n | V_TYPE_INT;
		if (!fmt) {
		    if ((var&V_NORM) || (prefixcode&V_AVGLOOP))
			fmt = "%.2f";
		    else
			fmt = (char *)intlist[n].fmt;
		}
		save = YES;
		break;
	    }

	// String variable name?
	    for (n = 0; n < STRINGVARS; n++)
		if (strcmp(buf, stringlist[n].name) == EQ &&
		    (stringlist[n].level&classable)) break;
	    if (n < STRINGVARS) {
		var |= needs(stringlist[n].level, inblock, class, type, buf);
		if ((var&V_SUM) || (prefixcode&(V_SUMLOOP|V_AVGLOOP))) {
		    saveError("'%s' can't be summed/averaged", buf);
		    var |= V_BAD;
		    break;
		}
		var |= n | V_TYPE_STRING;
		if (!fmt) fmt = (char *)stringlist[n].fmt;
		save = YES;
		break;
	    }

	// Bit name?
	    n = [World bitNumberOf:buf];
	    if (n != NULLBIT) {
		var |= n | V_TYPE_BIT;
		if (inblock == V_INAGENTBLOCK) var |= V_NEEDSAGENT;
		else if (inblock == V_INTYPEBLOCK) var |= V_NEEDSTYPE;
		else if (inblock == V_INCLASSBLOCK) {
		    saveError("'%s' is invalid in a %s block", buf, CLASSNAME);
		    var |= V_BAD;
		    break;
		}
		if (!fmt) {
		    if ((var&V_NORM) || (prefixcode&V_AVGLOOP))
			fmt = "%.3f";
		    else
			fmt = ((inblock)? "%2d": "%d");
		}
		save = YES;
		break;
	    }

	// Special keyword?
	    for (n = 0; n < NSPECIALS; n++)
		if (strcmp(buf, speciallist[n].name) == EQ) break;
	    if (n < NSPECIALS) {
		aname = NULL;
		anum = 0;
		if (var&(V_FMT|V_SUM)) {
		    saveError("invalid prefix or suffix: %s", token);
		    var |= V_BAD;
		}
		if ((specialcode>0) != (n<=1)) {
		    saveError("misplaced '%s'", buf);
		    var |= V_BAD;
		    break;
		}
		switch (n) {
		case 0:					// END
		    specialcode = 0;
		    prefixcode = 0;
		    inblock = 0;
		    usesagid = 0;
		    noaccumulate = NO;
		    var = (inlinebit|V_SPECIAL); // Ignore prefixes/suffixes
		    inlinebit = 0;
		    if (multipleclass) class = -1;
		    save = YES;
		    break;
		case 2:					// AGENTS
		case 5:					// AGENT
		    inblock = V_INAGENTBLOCK;
		    inlinebit |= var&V_NOSPACE;
		    if (prefixcode) {	// FOR/SUM/AVG: assume AGENTS
		    	n = 2;
			specialcode = n;
			var = (n|V_SPECIAL|speciallist[n].flags|prefixcode|
							usesagid|inlinebit);
			noaccumulate = YES;
		    }
		    else {		// Not prefixcode: assume AGENT
		    	n = 5;
			usesagid = V_USESAGID;
			var = (n|V_SPECIAL|speciallist[n].flags|
							usesagid|inlinebit);
			if (var&V_HASCTA) getCTAname(&var, &aname, &anum);
			if (multipleclass && (var&V_HASAGENT) && anum >= 0)
			    class = [agentManager classOf:anum];
			specialcode = var&V_CODEMASK;	// n unless error
		    }
		    save = YES;
		    break;
		case 3:					// CLASS
		case 4:					// TYPE
		    inblock = (prefixcode? V_INAGENTBLOCK:
					(n==3? V_INCLASSBLOCK: V_INTYPEBLOCK));
		    inlinebit |= var&V_NOSPACE;
		    var = (n|V_SPECIAL|speciallist[n].flags|prefixcode|
							usesagid|inlinebit);
		    if (var&V_HASCTA) getCTAname(&var, &aname, &anum);
		    if (multipleclass) {
			if (var&V_HASCLASS)
			    class = anum;
			else if (var&V_HASTYPE)
			    class = [agentManager classOfType:anum];
		    }
		    specialcode = var&V_CODEMASK;	// n unless error
		    noaccumulate = YES;
		    save = YES;
		    break;
		case 6:					// FOR
		case 7:					// SUM
		case 8:					// AVG
		    if (prefixcode) {
			saveError("extra prefix '%s'", buf);
			var |= V_BAD;
			break;
		    }
		    inlinebit = var&V_NOSPACE;
		    prefixcode = speciallist[n].flags;
		    break;
		case 1:					// MAX
		    if (inblock != V_INAGENTBLOCK || blockstart->next) {
			saveError("%s not at start of loop over agents", buf);
			var |= V_BAD;
			break;
		    }
		// Value follows as another token
		    maxagents = 0;
		    maxstring = (char *)readString("MAXvalue");
		    if (strcmp(maxstring, "???") == EQ
				|| strcmp(maxstring, BLOCKENDNAME) == EQ
				|| strcmp(maxstring, STREAMENDNAME) == EQ) {
			saveError("missing value for '%s'", buf);
			var |= V_BAD;
		    }

		// Convert to integer; must be positive
		    maxagents = (int) strtol(maxstring, &optr, 10);
		    if (*optr != EOS || maxagents <= 0) {
			saveError("invalid specification '%s' for %s",
							    maxstring, buf);
			var |= V_BAD;
		    }
		    free((void *)maxstring);
		    if (maxagents <= 0) break;

		// Save in the special entry at the start of the block
		    blockstart->u.s.maxagents = maxagents;

		// If MAX=1, change start-of-block flags
		    if (maxagents == 1) {
			if (blockstart->var&V_FORLOOP) noaccumulate = NO;
			usesagid = V_USESAGID;
			blockstart->var |= V_USESAGID;
		    }
		    break;
		case 9:					// AFTERFIRST
		    var &= V_NOSPACE;
		    var |= (n|V_SPECIAL);
		    save = YES;
		    break;
		}
		break;
	    }

	// "allbits"
	    if (strcmp(buf, ALLBITSNAME) == EQ) {
		if ((var&V_SUM) || (prefixcode&(V_SUMLOOP|V_AVGLOOP))) {
		    saveError("'%s' can't be summed/averaged", buf);
		    var |= V_BAD;
		    break;
		}
		var |= V_TYPE_ALLBITS;
		if (inblock == V_INAGENTBLOCK) var |= V_NEEDSAGENT;
		else if (inblock == V_INTYPEBLOCK) var |= V_NEEDSTYPE;
		else if (inblock == V_INCLASSBLOCK) {
		    saveError("'%s' is invalid in a %s block", buf, CLASSNAME);
		    var |= V_BAD;
		    break;
		}
		if (!fmt) fmt = (inblock? "%2d": "%d");
		save = YES;
		break;
	    }

	// "details"
	    if (strcmp(buf, DETAILNAME) == EQ) {
		if (!inblock) {
		    saveError("agent variable '%s' outside block", buf);
		    var |= V_BAD;
		    break;
		}
		if ((var&V_SUM) || (prefixcode&(V_SUMLOOP|V_AVGLOOP))) {
		    saveError("'%s' can't be summed/averaged", buf);
		    var |= V_BAD;
		    break;
		}
	    // Optional value must be in parentheses -- empty if none
		if (!fmt) fmt = "";
		var |= V_TYPE_DETAIL|V_FINALNL;	// Assume it'll end with \n
		save = YES;
		break;
	    }

	// Not found
	    saveError("unknown variable name '%s'", buf);
	    var |= V_BAD;
	    break;
	}

    // Allocate and fill in a varliststruct for the variable
	if (save || (var&V_BAD)) {
	    vptr = (struct varliststruct *)
	    				getmem(sizeof(struct varliststruct));
	    vptr->next = NULL;
	    vptr->var = var;
	    if (lastv)
		lastv->next = vptr;
	    else
		varlist = vptr;
	    lastv = vptr;
	    vptr->agid = nil;
	    if (var&V_SPECIAL) {
		vptr->u.s.aname = aname;
		vptr->u.s.anum = anum;
		vptr->u.s.maxagents = 0;
		if ((var&V_CODEMASK) > 0)
		    blockstart = vptr;
	    }
	    else {
		vptr->u.v.fmt = fmt;
		vptr->u.v.accumulator = 0.0;
		if (var&V_SUM) {
		    vptr->u.v.nextaccum = accumulatelist;
		    accumulatelist = vptr;
		}
		else
		    vptr->u.v.nextaccum = NULL;
	    }
	    ++i;
	}
    }
    free((void *)token);

    [self agidList];
    if (debug&DEBUGOUTPUT) [self debugInit];

    return self;
}


/*------------------------------------------------------*/
/*	needs()						*/
/*------------------------------------------------------*/
static unsigned long needs(unsigned long level, unsigned long inblock,
		int class, int type, char *buf)
/*
 * Checks that a variable is not used outside the minimum needed block-level,
 * and sets the appropriate V_NEEDS... variable to specify what needs to be
 * known (class/type/agent) to use the variable.
 */
{
    unsigned long cta;
    unsigned long v;

    v = 0;
    if (!(level&V_OUTSIDE)) {
	v = V_AGENTCLASS;
	if (class < 0) {
	    saveError("variable %s '%s' if not class", 
					kindClass(level), buf);
	    v |= V_BAD;
	}
	else if (!(kind[class]&level)) {
	    saveError("variable %s '%s' if not %s",
			kindClass(level), buf, kindname[class]);
	    v |= V_BAD;
	}
    }

    cta = level&V_CTA;

    if (cta == V_A) {
	if (inblock < V_INAGENTBLOCK) {
	    saveError("agent variable '%s' not in agent block", buf);
	    v |= V_BAD;
	}
	v |= V_NEEDSAGENT;
    }
    else if (cta == V_T) {
//	if (type < 0 && inblock < V_INTYPEBLOCK) {
	if (inblock < V_INTYPEBLOCK) {
	    saveError("type variable '%s' not in type or agent block", buf);
	    v |= V_BAD;
	}
	v |= V_NEEDSTYPE;
    }
    else if (cta == V_C) {
	v |= V_NEEDSCLASS;
    }
    return v;
}


/*------------------------------------------------------*/
/*	getCTAname()					*/
/*------------------------------------------------------*/
static void getCTAname(unsigned long *pvar, char **paname, int *panum)
/*
 * Gets the class/type/agent name or number following a keyword
 * like CLASS.
 */
{
    unsigned long var;
    int anum;
    const char *stringname;
    char *aname, *ptr;

    var = *pvar;
    anum = 0;

// Get the name or number from the next token
    stringname = ((var&V_HASTYPE)?"typename":
		((var&V_HASCLASS)?"classname":"agentname"));
    aname = (char *)readString(stringname);

// Recover from unexpected termination
    if (strcmp(aname, "???") == EQ
		|| strcmp(aname, BLOCKENDNAME) == EQ
		|| strcmp(aname, STREAMENDNAME) == EQ) {
	saveError("missing %s for %s block", stringname,
			    speciallist[var&V_CODEMASK].name);
	var &= ~V_CODEMASK;	// specialcode = 0
	var |= V_BAD;
	free((void *)aname);
	aname = NULL;
    }

// aname
    else {
	anum = (int)strtol(aname, &ptr, 10) - 1;
	if (*ptr == EOS && anum >= 0) {		// It's numeric
	    var |= V_NUMERIC;
	    if (var&V_HASCLASS) anum = [agentManager classWithNumber:anum+1];
	}
	else {					// It isn't numeral
	    if (var&V_HASCLASS) anum = [agentManager classWithName:aname];
	    if (var&V_HASTYPE)  anum = [agentManager typeWithName:aname];
	    if (var&V_HASAGENT) {
		if (strlen(aname) < 5) var |= V_BAD;
		if ([agentManager typeWithName:aname] < 0) var |= V_BAD;
		anum = [agentManager agentWithName:aname];
	    }
	}
	if ((var&V_HASCLASS) &&
		(anum <= 0 || anum >= [agentManager numclasses])) var |= V_BAD;
	if ((var&V_HASTYPE) &&
		(anum < 0 || anum >= [agentManager numtypes])) var |= V_BAD;
	if ((var&V_HASAGENT) &&
		(anum >= 0 && anum >= [agentManager numagents])) var |= V_BAD;
	if (var&V_BAD)
	    saveError("unknown %s '%s'", stringname, aname);
    }
    *pvar = var;
    *paname = aname;
    *panum = anum;
}


/*------------------------------------------------------*/
/*	-agidList					*/
/*------------------------------------------------------*/
- agidList
/*
 * Finishes initialization of this instance, after the agid variables,
 * and recomputes the agid variables after evolution for this instance.
 */
{
    unsigned long v, specialcode;
    struct varliststruct *vptr;

// Walk down the variable list to reset the agid variable in variables
// that are in blocks (and specials that start such blocks) that are not
// iterated over.
    agid = nil;
    for (vptr = varlist; vptr; vptr = vptr->next) {
	v = vptr->var;

// Process special entries
	if ((v&V_SPECIAL) && !(v&V_BAD)) {
	    agid = nil;
	    if (v&V_USESAGID) {
		specialcode = v&V_CODEMASK;
		switch (specialcode) {
		case 2:	// AGENTS
		    agid = [agentManager idOf:0];
		    break;
		case 3:	// CLASS xxx
		    agid = [agentManager firstAgentInClass:vptr->u.s.anum];
		    break;
		case 4:	// TYPE xxx
		    agid = [agentManager firstAgentInType:vptr->u.s.anum];
		    break;
		case 5:	// AGENT xxx
		    if (!(v&V_NUMERIC)) vptr->u.s.anum =
				[agentManager agentWithName:vptr->u.s.aname];
		// We allow a named agent not to exist (it might yet evolve)
		    if (vptr->u.s.anum >= 0)
			agid = [agentManager idOf:vptr->u.s.anum];
		    break;
		case 0:	// END
		case 9:	// AFTERFIRST
		    break;
		default:
		    [self error:"Unknown specialcode %u in -agidList",
								  specialcode];
		}
	    }
	}

// Set agid in every varlist entry
	vptr->agid = agid;
    }

    return self;
}


/*------------------------------------------------------*/
/*	-debugInit					*/
/*------------------------------------------------------*/
- debugInit
/*
 * Debug -- down the variable list
 */
{
    unsigned long v;
    int i, n;
    struct varliststruct *vptr;
    const char *typ, *loop, *need, *spec;
    char acc, has, buf[MAXINTCHARS+2];

    message("#o: streamname: %s  filename: %s  headinginterval: %d",
					name, filename, headinginterval);

    for (vptr = varlist, i = 1; vptr; ++i, vptr = vptr->next) {
	v = vptr->var;
	if (v&V_SPECIAL) {
	    n = v&V_CODEMASK;
	    switch (n) {
	    case 0: spec = BLOCKENDNAME; break;
	    case 1: spec = MAXNAME; break;
	    case 2: spec = AGENTSNAME; break;
	    case 3: spec = CLASSNAME; break;
	    case 4: spec = TYPENAME; break;
	    case 5: spec = AGENTNAME; break;
	    case 6: spec = FORNAME; break;
	    case 7: spec = SUMNAME; break;
	    case 8: spec = AVGNAME; break;
	    case 9: spec = AFNAME; break;
	    default: spec = "???"; break;
	    }
	    n = v&V_LOOP;
	    switch (n) {
	    case V_FORLOOP:	loop = "FOR"; break;
	    case V_SUMLOOP:	loop = "SUM"; break;
	    case V_AVGLOOP:	loop = "AVG"; break;
	    case 0:		loop = "   "; break;
	    default:		loop = "???"; break;
	    }
	    n = v&V_HASCTA;
	    switch (n) {
	    case V_HASCLASS:	has = 'C'; break;
	    case V_HASTYPE:	has = 'T'; break;
	    case V_HASAGENT:	has = 'A'; break;
	    case 0:		has = ' '; break;
	    default:		has = '?'; break;
	    }
	    if (vptr->u.s.maxagents)
		sprintf(buf,"[%d]", vptr->u.s.maxagents);
	    else
		buf[0] = EOS;
	    message("%co%c%3d: %c %c %s %-6s%-4s %c%-4s %2d %5s %s",
		((v&V_BAD)?'*':'#'),
		((v&V_BAD)?'*':':'),
		i,
		((v&V_NOSPACE)?'|':' '),
		has,
		loop,
		spec,
		buf,
		((v&V_NUMERIC)?'#':' '),
		((vptr->u.s.aname)?vptr->u.s.aname:""),
		vptr->u.s.anum,
		((v&V_USESAGID)?"agid:":""),
		((vptr->agid)?[vptr->agid fullname]:""));
	}
	else {
	    n = v&V_TYPEMASK;
	    switch (n) {
	    case V_TYPE_NONE:	typ = "  -";    break;
	    case V_TYPE_INT:	typ = "int";    break;
	    case V_TYPE_REAL:	typ = "real";   break;
	    case V_TYPE_BIT:	typ = "bit";    break;
	    case V_TYPE_STRING:	typ = "string"; break;
	    case V_TYPE_ALLBITS:typ = "allbit"; break;
	    case V_TYPE_DETAIL:	typ = "detail"; break;
	    default:		typ = "???";    break;
	    }
	    n = v&V_AVG;
	    switch (n) {
	    case V_SUM:	acc = '+'; break;
	    case V_AVG:	acc = '@'; break;
	    case 0:	acc = ' '; break;
	    default:	acc = '?'; break;
	    }
	    n = v&V_INBLOCK;
	    switch (n) {
	    case V_INCLASSBLOCK:has = 'C'; break;
	    case V_INTYPEBLOCK:	has = 'T'; break;
	    case V_INAGENTBLOCK:has = 'A'; break;
	    case 0:		has = ' '; break;
	    default:		has = '?'; break;
	    }
	    n = v&(V_NEEDS|V_AGENTCLASS);
	    switch (n) {
	    case V_NEEDSCLASS:			need = "(c)"; break;
	    case V_NEEDSTYPE:			need = "(t)"; break;
	    case V_NEEDSAGENT:			need = "(a)"; break;
	    case V_NEEDSCLASS|V_AGENTCLASS:	need = " c "; break;
	    case V_NEEDSTYPE|V_AGENTCLASS:	need = " t "; break;
	    case V_NEEDSAGENT|V_AGENTCLASS:	need = " a "; break;
	    case 0:				need = "   "; break;
	    default:				need = "???"; break;
	    }
	    message("%co%c%3d: %c %c %c%3ld %s %-6s %s%s%s %5s %s",
		((v&V_BAD)?'*':'#'),
		((v&V_BAD)?'*':':'),
		i,
		((v&V_NOSPACE)?'|':' '),
		has,
		acc,
		v&V_CODEMASK,
		need,
		typ,
		((v&V_INITIALNL)?"\\n":"  "),
		((v&V_FMT)?"fmt":"   "),
		((v&V_FINALNL)?"\\n":"  "),
		((v&V_USESAGID)?"agid:":""),
		((vptr->agid)?[vptr->agid fullname]:""));
	}
    }
    
    return self;
}


/*------------------------------------------------------*/
/*	+postEvolve					*/
/*------------------------------------------------------*/
+ postEvolve
/*
 * Reassigns the agid variables after evolution for this instance.
 */
{
    Output *optr;

    for (optr = firstInstance; optr; optr = optr->next)
	[optr agidList];

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

// "=" is a special case -- same as previous stream
    if (strcmp(filename, "=") == EQ) {
	if (! lastfp)
	    [self error:"'=' for stream '%s' has no valid referent", name];
	outputfp = lastfp;
	actual_filename = NULL;
	return YES;
    }

// Ordinary filename (or "-" for stdout), with possible * or + prefixes
// for heading-suppression and append-mode respecively.  Write the standard
// heading unless headinginterval is -2.  -1 suppresses all the headings that
// give variable names, but leaves the block header; -2 suppresses all.
    actual_filename = namesub(filename, NULL);
    outputfp = openOutputFile(actual_filename, name, (headinginterval != -2));
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
    unsigned long v;

    for (vptr = accumulatelist; vptr; vptr = vptr->u.v.nextaccum) {
	v = vptr->var;
	if (v&V_USESAGID) {
	    agid = vptr->agid;
	    if (!agid) continue;
	}
	[self accumulate:vptr];
    }
    periodcount++;

    return self;
}


/*------------------------------------------------------*/
/*	-accumulate					*/
/*------------------------------------------------------*/
- accumulate:(struct varliststruct *)vptr
/*
 * Does the accumulation for one variable, adding its value to its
 * accumulator.  Note that accumulation is only allowed for variables
 * outside all blocks and for variables inside blocks containing a
 * single agent (not TYPE or CLASS blocks).
 */
{
    unsigned long v;
    int n;
    int (*counts)[4];

    v = vptr->var;
    switch (v&V_TYPEMASK) {
    case V_TYPE_NONE:	// Ignore
	break;
    case V_TYPE_INT:
	vptr->u.v.accumulator += (double)[self intVariable:v];
	break;
    case V_TYPE_REAL:
	vptr->u.v.accumulator += [self realVariable:v];
	break;
    case V_TYPE_BIT:
	n = (int)(v&V_CODEMASK);
	if (v&V_INAGENTBLOCK) {
	    type = [agentManager typeOf:agid->tag];
	    n = [agentManager agentBitForWorldBit:n forType:type];
	    if (n >= 0) {
		counts = [agid countBit:n cumulative:NO];
		vptr->u.v.accumulator += (*counts)[1] + (*counts)[2];
	    }
	}
    // [no need to do TYPE case here -- accumulation not allowed]
	else
	    if (realworld[n]&1) vptr->u.v.accumulator += 1.0;
	break;
    default:
	[self error:"Invalid vartype %u for accumulation", v&V_TYPEMASK];
    }

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
    for (vptr = accumulatelist; vptr; vptr = vptr->u.v.nextaccum)
	vptr->u.v.accumulator = 0.0;
    return self;
}


/*------------------------------------------------------*/
/*	+resetAccumulatorsForStream:				*/
/*------------------------------------------------------*/
+ resetAccumulatorsForStream:(const char *)thename
/*
 * Resets to 0 the accumulation variables in stream "thename", or
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
	[optr resetAccumulators];
    else
	message("*** unknown output stream '%s' -- request ignored", thename);
    return self;
}


/*------------------------------------------------------*/
/*	+writeOutputToStream:				*/
/*------------------------------------------------------*/
+ writeOutputToStream:(const char *)thename
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
	[optr writeOutputToStream];
    else
	message("*** unknown output stream '%s' -- request ignored", thename);
    return self;
}


/*------------------------------------------------------*/
/*	-writeOutputToStream				*/
/*------------------------------------------------------*/
- writeOutputToStream
/*
 * Write out the values of the specified variables for this instance,
 * unless already done at this time.
 */
{
    unsigned long v, specialcode;
    int i, n, len, maxagents, onnewline, k, nbits;
    int (*counts)[4], *(*countarrays)[4], *count1, *count2;
    BOOL accumulate, postaccumulate, normalize;
    struct varliststruct *vptr, *vptr2, *prev, *temp, *blockstart;
    Agent **idlist;
    double divisor, val;

    if (t == lasttime) return self;		// Don't do it twice
    if (! outputfp) return self;		// Disabled (<none>)

// Put out a heading line if it's time
    if ((headinginterval > 0 && outputcount%headinginterval == 0) ||
					(outputcount == headinginterval))
	[self makeHeading];

// Put out the variable values
    divisor = (double)periodcount;
    blockstart = NULL;
    a = -1;
    agid = nil;
    if (multipleclass > 0) class = -1;
    if (multipletype > 0) type = -1;
    len = 0;
    idlist = NULL;
    onnewline = 1;
    specialcode = 0;
    accumulate = NO;
    postaccumulate = NO;
    normalize = NO;
    for (vptr = varlist; vptr; vptr = vptr->next) {
	v = vptr->var;

	if (v&V_SPECIAL) {
	    if (v&V_CODEMASK) {		// Start of new block
		specialcode = v&V_CODEMASK;

	    // Put out newline at start of block (or for AFTERFIRST)
		if (!onnewline && !(v&V_NOSPACE)) {
		    putc('\n', outputfp);
		    onnewline = 1;
		}

	    // Deal with AFTERFIRST -- change start-of-list
		if (specialcode == 9) {		// AFTERFIRST
		    prev = varlist;
		    varlist = vptr->next;
		// Free skipped entries except AFTERFIRST itself
		    for (; prev!=vptr; prev = temp) {
			temp = prev->next;
			free((void *)prev);
		    }
		    specialcode = 0;
		    continue;
		}

	    // Record start of block to come back to from END
		blockstart = vptr;

	    // Get the appropriate agent or list of agents -- 4 cases
		agid = nil;
		if (multipleclass > 0) class = -1;
		if (multipletype > 0) type = -1;
		idlist = NULL;

	    // Case 1: Single agent
		if (v&V_USESAGID) {
		    agid = vptr->agid;
		    len = (agid?1:0);
		}

	    // Case 2: List of agents
		else if (v&V_LOOP) {
		    k = vptr->u.s.anum;
		    switch (specialcode) {
		    case 2:	// AGENTS
			idlist = [agentManager allAgents:&len];
			break;
		    case 3:	// CLASS xxx
			idlist = [agentManager allAgents:&len inClass:k];
			break;
		    case 4:	// TYPE xxx
			idlist = [agentManager allAgents:&len inType:k];
			break;
		    default:
			[self error:"Invalid specialcode %u", specialcode];
		    }

		// Reduce the number to show if limited by MAX(n)
		    maxagents = (int)vptr->u.s.maxagents;
		    if (maxagents > 0 && maxagents < len) len = maxagents;

		// Get the first agent (unless none)
		    agid = (len>0? idlist[0]: NULL);
		}

	    // Case 3: Single class
		else if (v&V_HASCLASS) {
		    class = vptr->u.s.anum;
		    len = 1;
		}

	    // Case 4: Single type
		else if (v&V_HASTYPE) {
		    type = vptr->u.s.anum;
		    len = 1;
		}

	    // Case 5?!!?
		else
		    [self error:"Invalid variable for output %08o"];

	    // If there's not even one agent (as can happen after evolution),
	    // we say so and then skip over the variables up to just before END
		if (len == 0) {
		    if (!onnewline) putc(' ', outputfp);
		    switch (specialcode) {
		    case 3:	// CLASS xxx
		    case 4:	// TYPE xxx
			fprintf(outputfp, "(no agents in %s %s)",
			    (specialcode==3?"class":"type"), vptr->u.s.aname);
			break;
		    case 5:	// AGENT xxx
			fprintf(outputfp, "(unknown agent %s)",
							    vptr->u.s.aname);
			break;
		    default:	// Shouldn't happen
			fprintf(outputfp, "(no agents)");
			break;
		    }
		    onnewline = 0;
		    prev = vptr;
		    vptr = vptr->next;
		    if (!vptr) break;	// shouldn't happen
		    for (; vptr; prev=vptr, vptr=vptr->next)
			if (vptr->var&V_SPECIAL) break;
		    vptr = prev;
		    a = -1;
		    continue;
		}

	    // Initialize the accumulators for a SUM or AVG loop
		if (v&(V_SUMLOOP|V_AVGLOOP)) {
		    for (vptr2 = vptr->next; vptr2; vptr2=vptr2->next) {
			if (vptr2->var&V_SPECIAL) break;
			vptr2->u.v.accumulator = 0.0;
		    }
		    accumulate = YES;
		}

	    // Initialize the loop
		a = 0;
	    }

	// END -- end of current block
	    else {

	    // Put out newline after each iteration unless NOSPACE flag
		if (!((v&V_NOSPACE) || onnewline || accumulate)) {
		    putc('\n', outputfp);
		    onnewline = 1;
		}

	    // Loop iteration -- set the next agent and go back to start
		if (++a < len) {
		    agid = idlist[a];
		    if (specialcode < 4) type = -1; // type may be different
		    vptr = blockstart;
		}

	    // End of SUM or AVG -- go back one more time to write out
		else if (accumulate) {
		    vptr = blockstart;
		    if (vptr->var&V_AVGLOOP) {
			normalize = YES;
			divisor = (double)len;
		    }
		    accumulate = NO;
		    postaccumulate = YES;
		}

	    // Final end of loop
		else {
		    blockstart = NULL;
		    specialcode = 0;
		    a = -1;
		    agid = nil;
		    if (multipleclass > 0) class = -1;
		    if (multipletype > 0) type = -1;
		    postaccumulate = NO;
		    normalize = NO;
		    divisor = (double)periodcount;
		}
	    }

	    continue;
	}

    // Just do accumulation for SUM or AVG loop
	if (accumulate) {
	    [self accumulate:vptr];
	    continue;
	}

    // Separate items by a space if needed
	if (!((v&(V_NOSPACE|V_INITIALNL)) || onnewline))
	    putc(' ', outputfp);

    // Write out an accumulated value, normalizing for averages
	if (v&V_SUM || (postaccumulate && (v&V_TYPEMASK) != V_TYPE_NONE)) {
	    val = vptr->u.v.accumulator;
	    if (((v&V_NORM) || normalize) && divisor > 0.0)
		val /= divisor;
	    if ((v&V_NORM) || normalize || (v&V_TYPEMASK) == V_TYPE_REAL)
		fprintf(outputfp, vptr->u.v.fmt, val);
	    else
		fprintf(outputfp, vptr->u.v.fmt, (int)val);
	    vptr->u.v.accumulator = 0.0;
	}

    // Write out non-accumulated variables etc
	else {
	    switch (v&V_TYPEMASK) {
	    case V_TYPE_INT:
		fprintf(outputfp, vptr->u.v.fmt, [self intVariable:v]);
		break;
	    case V_TYPE_REAL:
		fprintf(outputfp, vptr->u.v.fmt, [self realVariable:v]);
		break;
	    case V_TYPE_STRING:
		fprintf(outputfp, vptr->u.v.fmt, [self stringVariable:v]);
		break;
	    case V_TYPE_BIT:
		n = (int)(v&V_CODEMASK);
		if (v&V_INBLOCK) {	// agent or type block only
		    counts = NULL;
		    if (v&V_INTYPEBLOCK) {	// type block
			n = [agentManager agentBitForWorldBit:n forType:type];
			if (n >= 0)
			    counts = [agentManager countBit:n forType:type];
		    }
		    else {			// agent block
			if (type < 0) type = [agentManager typeOf:agid->tag];
			n = [agentManager agentBitForWorldBit:n forType:type];
			if (n >= 0)
			    counts = [agid countBit:n cumulative:NO];
		    }
		    if (counts)
			fprintf(outputfp, vptr->u.v.fmt,
					    (*counts)[1] + (*counts)[2]);
		    else
			fprintf(outputfp, vptr->u.v.fmt, 0);
		}
		else
		    fprintf(outputfp, vptr->u.v.fmt, (realworld[n]&1));
		break;
	    case V_TYPE_ALLBITS:
		if (v&V_INBLOCK) {	// agent or type block only
		    if (v&V_INTYPEBLOCK)	// type block
			countarrays=[agentManager bitDistributionForType:type];
		    else {			// agent block
			if (type < 0) type = [agentManager typeOf:agid->tag];
			countarrays = [agid bitDistribution];
		    }
		    if (countarrays) {
			nbits = [agentManager nbitsForType:type];
			count1 = (*countarrays)[1];
			count2 = (*countarrays)[2];
			fprintf(outputfp, vptr->u.v.fmt,
						    count1[0] + count2[0]);
			if (v&V_NOSPACE) {
			    for (i = 1; i < nbits; i++)
				fprintf(outputfp, vptr->u.v.fmt,
							count1[i] + count2[i]);
			}
			else {
			    for (i = 1; i < nbits; i++) {
				putc(' ', outputfp);
				fprintf(outputfp, vptr->u.v.fmt,
							count1[i] + count2[i]);
			    }
			}
		    }
		    else
			fprintf(outputfp, "(no bits for type %s)",
				    [agentManager typenameForType:type]);
		}
		else
		    for (i = 0; i < nworldbits; i++)
			fprintf(outputfp, vptr->u.v.fmt, (realworld[i]&1));
		break;
	    case V_TYPE_DETAIL:
		switch (v&V_INBLOCK) {
		case V_INCLASSBLOCK:
		    [agentManager printDetails:vptr->u.v.fmt to:outputfp
							    forClass:class];
		    break;
		case V_INTYPEBLOCK:
		    [agentManager printDetails:vptr->u.v.fmt to:outputfp
							    forType:type];
		    break;
		case V_INAGENTBLOCK:
		    [agid printDetails:vptr->u.v.fmt to:outputfp];
		    break;
		default:
		    [self error:"details(%s) outside block", vptr->u.v.fmt];
		}
		break;
	    case V_TYPE_NONE:
		fprintf(outputfp, vptr->u.v.fmt);
		break;
	    }
	}
	onnewline = (v&V_FINALNL);
    }
    if (specialcode)
	[self error:"End of variable list inside block"];

// Finish up with a newline, unless we're at the start of a line anyway
    if (!onnewline) putc('\n', outputfp);
    fflush(outputfp);

    periodcount = 0;
    outputcount++;
    lasttime = t;

    return self;
}


/*------------------------------------------------------*/
/*	-makeHeading					*/
/*------------------------------------------------------*/
- makeHeading
/*
 * This puts out a heading line (or lines) for this instance's variables.
 * The heading includes all the variable names and blocks, but not formats
 * etc.  However the layout (spacing and newlines) tries to reflect that
 * of the following variables, though this is imperfect since format
 * strings are not fully processed.
 */
{
    unsigned long v, specialcode;
    int n, maxagents, onnewline;
    BOOL putspace;
    struct varliststruct *vptr;

    putspace = YES;
    onnewline = 1;
    for (vptr = varlist; vptr; vptr = vptr->next) {
	v = vptr->var;

    // Deal with "special" items
	if (v&V_SPECIAL) {
	    specialcode = v&V_CODEMASK;

	// END of block -- put out '}' and figure out following whitespace
	    if (specialcode == 0) {
		putc('}', outputfp);
		if (v&V_NOSPACE) putspace = YES;
		else { putc('\n', outputfp); onnewline = 1; }
	    }

	// Ignore AFTERFIRST
	    else if (specialcode == 9) {	// AFTERFIRST
		if (!onnewline) { putc('\n', outputfp); onnewline = 1; }
		continue;
	    }

	// Start of new block
	    else {

	    // Put out separator(s)
		if (onnewline) fputs("# ", outputfp);
		else if (v&V_NOSPACE) putc(' ', outputfp);
		else fputs("\n# ", outputfp);

	    // Put out FOR/SUM/AVG prefix if needed
		if (v&V_LOOP) {
		    fputs(((v&V_FORLOOP)?FORNAME:
			    ((v&V_SUMLOOP)?SUMNAME:AVGNAME)), outputfp);
		    putc(' ', outputfp);
		}

	    // Put out AGENTS/CLASS/TYPE/AGENT
		fputs(speciallist[specialcode].name, outputfp);

	    // Put out class/type/agent name if needed
		if (v&V_HASCTA) {
		    putc(' ', outputfp);
		    fputs(vptr->u.s.aname, outputfp);
		}

	    // Put out [1..n] etc if limited by MAX
		maxagents = vptr->u.s.maxagents;
		if (maxagents > 0) {
		    if (maxagents == 1) fputs("[1]", outputfp);
		    else fprintf(outputfp, "[1..%d]", maxagents);
		}

	    // Put out a '{' and inhibit following whitespace
		putc('{', outputfp);
		onnewline = 0;
		putspace = NO;
	    }
	    continue;
	}

    // Ignore format-only items, except to notice leading/trailing \n's
	if ((v&V_TYPEMASK) == V_TYPE_NONE) {
	    if ((v&(V_INITIALNL|V_FINALNL)) && !onnewline) {
		putc('\n', outputfp);
		onnewline = 1;
	    }
	    continue;
	}

    // Put out start of new line, or space, or neither
	if (onnewline) { fputs("# ", outputfp); onnewline = 0; }
	else if (putspace) putc(' ', outputfp);
	putspace = YES;

    // Put out CHARAVG or CHARSUM prefix if needed
	if (v&V_NORM) putc(CHARAVG, outputfp);
	else if (v&V_SUM) putc(CHARSUM, outputfp);

    // Put out actual variable name
	n = (int)(v&V_CODEMASK);
	switch (v&V_TYPEMASK) {
	case V_TYPE_INT:
	    fputs(intlist[n].name, outputfp);
	    break;
	case V_TYPE_REAL:
	    fputs(reallist[n].name, outputfp);
	    break;
	case V_TYPE_STRING:
	    fputs(stringlist[n].name, outputfp);
	    break;
	case V_TYPE_BIT:
	    fputs([World nameOfBit:n], outputfp);
	    break;
	case V_TYPE_ALLBITS:
	    fputs(ALLBITSNAME, outputfp);
	    break;
	case V_TYPE_DETAIL:
	    if (v&V_FMT)
		fprintf(outputfp, DETAILNAME "(%s)", vptr->u.v.fmt);
	    else
		fprintf(outputfp, DETAILNAME);
	    break;
	}
    }
    if (!onnewline) fputc('\n', outputfp);

    return self;
}


/*------------------------------------------------------*/
/*	-intVariable:					*/
/*------------------------------------------------------*/
- (int)intVariable:(unsigned long)v
/*
 * Returns the value of an integer variable.  The numbering here must
 * agree with that in the intlist[] table.
 */
{
    int val = 0;
    int i;

    i = v&V_CODEMASK;

    if (v&V_AGENTCLASS) {
	switch (v&V_NEEDS) {
	case V_NEEDSCLASS:
 	    if (class < 0) {
		if (v&V_INAGENTBLOCK)
		    class = [agentManager classOf:agid->tag];
		else if (v&V_INTYPEBLOCK)
		    class = [agentManager classOfType:type];
	    }
	    if (class >= 0)
	        val = [agentManager outputInt:i forClass:class];
	    break;
	case V_NEEDSTYPE:
	    if (type < 0 && (v&V_INAGENTBLOCK))
		type = [agentManager typeOf:agid->type];
	    if (type >= 0)
	        val = [agentManager outputInt:i forType:type];
	    break;
	case V_NEEDSAGENT:
	    if (agid)
	        val = [agid outputInt:i];
	    break;
	default:
	    [self error:"Invalid NEEDS outputInt %o", v];
	    /*NOTREACHED*/
	}
	return val;
    }

    switch (i) {
    case 0:	val = 1;						break;
    case 1:	val = t;						break;
    case 2:	val = t - 1;						break;
    case 3:	val = runid;						break;
    case 4:	val = mseed;						break;
    case 5:	val = [dividendProcess seed];				break;
	    // nagents behaves specially in a CLASS or TYPE block
    case 6:	if (v&V_INCLASSBLOCK)
		    val = [agentManager nagentsInClass:class];
		else if (v&V_INTYPEBLOCK)
		    val = [agentManager nagentsOfType:type];
		else
		    val = [agentManager numagents];
									break;
    case 7:	val = [agentManager numclassesInUse];			break;
	    // ntypes behaves specially in a CLASS or TYPE block
    case 8:	if (v&V_INCLASSBLOCK)
		    val = [agentManager ntypesInClass:class];
		else if (v&V_INTYPEBLOCK)
		    val = 1;
		else
		    val = [agentManager numtypes];
									break;
    case 9:	val = [agentManager generation];			break;
// Class properties
    case 10:	if (class < 0) {
		    if (v&V_INAGENTBLOCK)
			class = [agentManager classOf:agid->tag];
		    else if (v&V_INTYPEBLOCK)
			class = [agentManager classOfType:type];
		}
		val = [agentManager classNumber:class];			break;
// Type properties
    case 11:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = type + 1;						break;
    case 12:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = [agentManager nrulesForType:type];		break;
    case 13:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = [agentManager nonnullBitsForType:type];		break;
    case 14:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = [agentManager nbitsForType:type];			break;
	    // sumbits
    case 15:	val = [self sumbits:v];					break;
// Agent properties
    case 16:	val = agid->tag + 1;					break;
    case 17:	val = agid->tag;					break;
    case 18:	val = a+1;						break;
    case 19:	val = agid->gacount;					break;
    default:
	val = 0;
	[self error:"Invalid -intVariable varcode %o", v];
	/*NOTREACHED*/
    }
    return val;
}


/*------------------------------------------------------*/
/*	-sumbits:					*/
/*------------------------------------------------------*/
- (int)sumbits:(unsigned long)v
{
    int i, nbits, sum;
    int *(*countarrays)[4], *count1, *count2;

    if (v&V_INTYPEBLOCK)	// type block
	countarrays=[agentManager bitDistributionForType:type];
    else {			// agent block
	if (type < 0) type = [agentManager typeOf:agid->tag];
	countarrays = [agid bitDistribution];
    }
    sum = 0;
    if (countarrays) {
	nbits = [agentManager nbitsForType:type];
	count1 = (*countarrays)[1];
	count2 = (*countarrays)[2];
	for (i = 0; i < nbits; i++)
	    sum += count1[i] + count2[i];
    }
    return sum;
}


/*------------------------------------------------------*/
/*	-realVariable:					*/
/*------------------------------------------------------*/
- (double)realVariable:(unsigned long)v
/*
 * Returns the value of a real variable.  The numbering here must
 * agree with that in the reallist[] table.
 */
{
    double val = 0.0;
    int i, n;

    i = v&V_CODEMASK;

    if (v&V_AGENTCLASS) {
	switch (v&V_NEEDS) {
	case V_NEEDSCLASS:
 	    if (class < 0) {
		if (v&V_INAGENTBLOCK)
		    class = [agentManager classOf:agid->tag];
		else if (v&V_INTYPEBLOCK)
		    class = [agentManager classOfType:type];
	    }
	    if (class >= 0)
	        val = [agentManager outputReal:i forClass:class];
	    break;
	case V_NEEDSTYPE:
	    if (type < 0 && (v&V_INAGENTBLOCK))
		type = [agentManager typeOf:agid->tag];
	    if (type >= 0)
	        val = [agentManager outputReal:i forType:type];
	    break;
	case V_NEEDSAGENT:
	    if (agid)
	        val = [agid outputReal:i];
	    break;
	default:
	    [self error:"Invalid NEEDS outputReal %o", v];
	    /*NOTREACHED*/
	}
	return val;
    }

    switch (i) {
    case 0:	val = price;						break;
    case 1:	val = dividend;						break;
    case 2:	val = dividend/intrate;					break;
    case 3:	val = volume;						break;
    case 4:	val = bidtotal;						break;
    case 5:	val = offertotal;					break;
    case 6:	val = pmav[0];						break;
    case 7:	val = pmav[1];						break;
    case 8:	val = pmav[2];						break;
    case 9:	val = pmav[3];						break;
    case 10:	val = dmav[0];						break;
    case 11:	val = dmav[1];						break;
    case 12:	val = dmav[2];						break;
    case 13:	val = dmav[3];						break;
    case 14:	val = price*intrate/dividend;				break;
    case 15:	val = profitperunit;					break;
    case 16:	val = returnratio;					break;
    case 17:	val = vol;						break;
    case 18:	val = volt[0];						break;
    case 19:	val = volt[1];						break;
    case 20:	val = volt[2];						break;
    case 21:	val = volt[3];						break;
    case 22:	val = intrate;						break;
    case 23:	val = [specialist eta];					break;
    case 24:	val = oldprice;						break;
    case 25:	val = olddividend;					break;
    case 26:	val = olddividend/intrate;				break;
    case 27:	val = oldvolume;					break;
    case 28:	val = oldbidtotal;					break;
    case 29:	val = oldoffertotal;					break;
// Class properties
// Type properties
	    // avgbits
    case 30:	val = (double)[self sumbits:v];	// Sets type too
		n = [agentManager nonnullBitsForType:type];
		if (n > 0) val /=(double)n;
		if (v&V_INTYPEBLOCK) {
		    n = [agentManager nagentsOfType:type];
		    if (n > 0) val /= (double)n;
		}
									break;
	    // avgtypebits
    case 31:	val = (double)[self sumbits:v];	// Sets type too
		n = [agentManager nonnullBitsForType:type];
		if (n > 0) val /=(double)n;
									break;
// Agent properties
    case 32:	val = agid->wealth;					break;
    case 33:	val = agid->wealth/initialcash;				break;
    case 34:
    case 35:	val = agid->position;					break;
    case 36:	val = agid->position*price;				break;
    case 37:	val = agid->cash;					break;
    case 38:	val = agid->profit;					break;
    case 39:	val = agid->demand;					break;
    case 40:	val = agid->position + agid->demand;			break;
    default:
	val = 0.0;
	[self error:"Invalid -realVariable varcode %o", v];
	/*NOTREACHED*/
    }
    return val;
}


/*------------------------------------------------------*/
/*	-stringVariable:					*/
/*------------------------------------------------------*/
- (const char *)stringVariable:(unsigned long)v
/*
 * Returns the value of a string variable.  The numbering here must
 * agree with that in the stringlist[] table.
 */
{
    const char *val = "???";
    int i;

    i = v&V_CODEMASK;

    if (v&V_AGENTCLASS) {
	switch (v&V_NEEDS) {
	case V_NEEDSCLASS:
 	    if (class < 0) {
		if (v&V_INAGENTBLOCK)
		    class = [agentManager classOf:agid->tag];
		else if (v&V_INTYPEBLOCK)
		    class = [agentManager classOfType:type];
	    }
	    if (class >= 0)
	        val = [agentManager outputString:i forClass:class];
	    break;
	case V_NEEDSTYPE:
	    if (type < 0 && (v&V_INAGENTBLOCK))
		type = [agentManager typeOf:agid->tag];
	    if (type >= 0)
	        val = [agentManager outputString:i forType:type];
	    break;
	case V_NEEDSAGENT:
	    if (agid)
	        val = [agid outputString:i];
	    break;
	default:
	    [self error:"Invalid NEEDS outputString %o", v];
	    /*NOTREACHED*/
	}
	return val;
    }

    switch (i) {
    case 0:	val = PROJECTTITLE;					break;
    case 1:	val = versionnumber();					break;
    case 2:	val = versiondate();					break;
    case 3:	val = username();					break;
    case 4:	val = hostname();					break;
    case 5:	val = getDate(NO);					break;
// Class properties
    case 6:	if (class < 0) {
		    if (v&V_INAGENTBLOCK)
			class = [agentManager classOf:agid->tag];
		    else if (v&V_INTYPEBLOCK)
			class = [agentManager classOfType:type];
		}
		val = [agentManager shortnameForClass:class];		break;
// Type properties
    case 7:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = [agentManager typenameForType:type];		break;
    case 8:	if (type < 0 && (v&V_INAGENTBLOCK))
		    type = [agentManager typeOf:agid->tag];
		val = [agentManager filenameForType:type];		break;
// Agent properties
    case 9:	val = [agid fullname];					break;
    case 10:	val = [agid shortname];					break;
    default:
	val = 0;
	[self error:"Invalid -stringVariable varcode %o", v];
	/*NOTREACHED*/
    }
    return val;
}


/*------------------------------------------------------*/
/*	+writeOutputSpecifications:			*/
/*------------------------------------------------------*/
+ writeOutputSpecifications:(FILE *)fp
/*
 * Writes to fp (the log file) all the parameters defining all the output
 * streams, with explanatory names/comments.
 */
{
    Output *optr;

    for (optr = firstInstance; optr; optr = optr->next)
	[optr writeOutputSpecifications:fp];

    putc('\n', fp);
    showstrng(fp, "--- end of all output stream specifications ---",
	ALLENDNAME);

    return self;
}


/*------------------------------------------------------*/
/*	-writeOutputSpecifications:			*/
/*------------------------------------------------------*/
- writeOutputSpecifications:(FILE *)fp
/*
 * Writes to fp (the log file) all the parameters defining this output
 * stream, with explanatory names/comments.
 */
{
    unsigned long v, n, specialcode;
    struct varliststruct *vptr;
    char buf[MAXSTRING+60], buf2[MAXSTRING];
    char sname[MAXSTRING+MAXAGENTSPEC+2], *sptr, *prefix;
    BOOL indent;

// Put out initial headers
    fprintf(fp, "\n# -- output stream '%s' --\n", name);
    showstrng(fp, "streamname", name);
    showoutputfilename(fp, "filename", filename, actual_filename);
    showint(fp, "headinginterval", headinginterval);
    sprintf(buf, "-- variables in stream '%s' --", name);
    showstrng(fp, buf, "");

// Loop over the variables in the list
    specialcode = 0;
    strcpy(sname, "???");
    for (vptr = varlist; vptr; vptr = vptr->next) {
	v = vptr->var;

    // Deal with specials
	if (v&V_SPECIAL) {
	    specialcode = v&V_CODEMASK;
	    if (specialcode == 0) {		// END
		sprintf(buf, "(end of %s block)", sname);
		showstrng(fp, buf, speciallist[specialcode].name);
	    }
	    else if (specialcode == 9) {	// AFTERFIRST
		showstrng(fp, "(start here after first pass)",
					    speciallist[specialcode].name);
		specialcode = 0;
	    }
	    else {	// Start of block/loop

	    // Show NOSPACE indicator on separate line
		if (v&V_NOSPACE)
		    showstrng(fp, "(following block on one line)", nospace);

	    // Set up prefix for loop/sum/average
		sptr = sname;
		if (v&V_FORLOOP) {
		    strcpy(sptr, FORNAME);
		    sptr += sizeof(FORNAME)-1;
		    *sptr++ = ' ';
		    prefix = " loop over";
		}
		else if (v&V_SUMLOOP) {
		    strcpy(sptr, SUMNAME);
		    sptr += sizeof(SUMNAME)-1;
		    *sptr++ = ' ';
		    prefix = " sum over";
		}
		else if (v&V_AVGLOOP) {
		    strcpy(sptr, AVGNAME);
		    sptr += sizeof(AVGNAME)-1;
		    *sptr++ = ' ';
		    prefix = " average over";
		}
		else
		    prefix = "";

	    // Append name (e.g., TYPE BF1, or AGENTS) and write out
		strcpy(sptr, speciallist[specialcode].name);
		if (v&V_HASCTA) {
		    strcat(sptr, " ");
		    strcat(sptr, vptr->u.s.aname);
		}
		sprintf(buf, "(start of block for%s %s)", prefix, sptr);
		showbarestrng(fp, buf, sname);

	    // Write out any MAX n specification
		if (vptr->u.s.maxagents > 0.0) {
		    sprintf(buf, MAXNAME " %d", (int)vptr->u.s.maxagents);
		    sprintf(buf2, "(maximum agents to%s)", prefix);
		    showbarestrng(fp, buf2 , buf);
		}
	    }
	    continue;
	}

    // Deal with "no-space" indicators for plain variables
	if (v&V_NOSPACE)
	    showstrng(fp, "(no space between items)", nospace);

    // Write out plain variables
	n = v&V_CODEMASK;
	indent = (specialcode != 0);
	switch (v&V_TYPEMASK) {
	case V_TYPE_INT:
	    showVariable(fp, intlist[n].name,
			intlist[n].description, vptr->u.v.fmt, v, indent);
	    break;
	case V_TYPE_REAL:
	    showVariable(fp, reallist[n].name,
			reallist[n].description, vptr->u.v.fmt, v, indent);
	    break;
	case V_TYPE_STRING:
	    showVariable(fp, stringlist[n].name,
			stringlist[n].description, vptr->u.v.fmt, v, indent);
	    break;
	case V_TYPE_BIT:
	    showVariable(fp, [World nameOfBit:n],
		    [World descriptionOfBit:n], vptr->u.v.fmt, v, indent);
	    break;
	case V_TYPE_ALLBITS:
	    showVariable(fp, ALLBITSNAME,
		    ((v&V_INAGENTBLOCK)?"all agent's bits":
		    ((v&V_INTYPEBLOCK)?"all type's bits":
				"all world bits")), vptr->u.v.fmt, v, indent);
	    break;
	case V_TYPE_DETAIL:
	    showVariable(fp, DETAILNAME, "agent's details", vptr->u.v.fmt,
								    v, indent);
	    break;
	case V_TYPE_NONE:
	    showVariable(fp, "", "(format string)", vptr->u.v.fmt, v, indent);
	    break;
	default:
	    [self error:"Illegal vartype %u", v&V_TYPEMASK];
	}
    }

    sprintf(buf, "-- end of stream '%s' --", name);
    showstrng(fp, buf, STREAMENDNAME);

    return self;
}


/*------------------------------------------------------*/
/*	showVariable()					*/
/*------------------------------------------------------*/
static void showVariable(FILE *fp, const char *name, const char *description,
				const char *fmt, unsigned long v, BOOL indent)
/*
 * Writes one variable name.
 */
{
    char vbuf[MAXSTRING*2];
    char dbuf[80];
    char *vptr;
    const char *ptr;

// Write a CHARAVG or CHARSUM prefix if needed
    vptr = vbuf;
    if (v&V_NORM) *vptr++ = CHARAVG;
    else if (v&V_SUM) *vptr++ = CHARSUM;

// Write out name (empty for a stand-alone format)
    strcpy(vptr, name);

// Append the format in parentheses if it was explicitly specified,
// translating special characters to their backslash codes.
    if (v&V_FMT) {
	vptr += strlen(name);
	*vptr++ = '(';
	for (ptr = fmt; *ptr; ptr++) {
	    switch(*ptr) {
	    case '\a': *vptr++ = '\\'; *vptr++ = 'a'; break;
	    case '\b': *vptr++ = '\\'; *vptr++ = 'b'; break;
	    case '\f': *vptr++ = '\\'; *vptr++ = 'f'; break;
	    case '\n': *vptr++ = '\\'; *vptr++ = 'n'; break;
	    case '\r': *vptr++ = '\\'; *vptr++ = 'r'; break;
	    case '\t': *vptr++ = '\\'; *vptr++ = 't'; break;
	    case '\v': *vptr++ = '\\'; *vptr++ = 'v'; break;
	    case '\\': *vptr++ = '\\'; *vptr++ = '\\'; break;
	    case '"':  *vptr++ = '\\'; *vptr++ = '"'; break;
	    default: *vptr++ = *ptr; break;
	    }
	}
	sprintf(vptr, "(%s)", fmt);
	*vptr++ = ')';
	*vptr = EOS;
    }

// Massage the description string, prefixing with indent and maybe
// "AVERAGE OF" or "SUM OF".  Then write it all out.
    if (v&V_AVG) {
	ptr = ((v&V_NORM)? "AVERAGE": "SUM");
	if (strchr(description, ' '))
	    sprintf(dbuf, "%s%s OF (%s)", (indent?INDENT:""), ptr,
								description);
	else
	    sprintf(dbuf, "%s%s OF %s", (indent?INDENT:""), ptr, description);
	if ((v&(V_CODEMASK|V_TYPEMASK|V_AVG)) == (V_TYPE_INT|V_SUM))
	    strcat(dbuf, " -- periods since last print");
	showstrng(fp, dbuf, vbuf);
    }
    else if (indent) {
	sprintf(dbuf, "%s%s", INDENT, description);
	showstrng(fp, dbuf, vbuf);
    }
    else
	showstrng(fp, description, vbuf);
}

@end
