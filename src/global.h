/* Global declarations for AHLPT Stockmarket Project.
 * This file is included in almost every source file.
 */

#import <stdarg.h>	// Must precede stdio.h in gcc
#import <stdio.h>	// For FILE
#import <objc/objc.h>

/* Useful constants */
#define MAXINT		((int)0x7fffffff)	/* maximum integer */
#define MININT		((int)0x80000000)	/* minimum integer */
#define MAXINTCHARS	12	/* 1 + maximum digits in an integer */
#define MAXDOUBLECHARS	24	/* 1 + maximum digits in a double */
#define MAXSTRING	81	/* 1 + maximum chars in an input string */
#define EOS		'\0'
#define EQ		0
#define UNKNOWN		(BOOL)2			/* 3rd case for a BOOL */
#define NULLBIT		-1		/* bit number for an inactive bit */

/* Macros */
#define WORD(bit)	(bit>>4)

// Maximum number of condition bits allowed.  If this is less than nworldbits
// then an attempt to use 'all' will be denied.  See also the comments in
// getDemand:andSlope: in BFagent and BSagent.
#define MAXCONDBITS	80

/* Structure for key-value tables */
struct keytable {
    const char *name;
    int value;
};

/* Property codes for AgentManager and frontend */
enum property {
	WEALTH,
	RELATIVEWEALTH,
	POSITION,
	STOCKVALUE,
	CASH,
	PROFITMA,
	TARGET,
	DEMAND
};

/* Global variables defined in control.m */
extern int t;
extern int lasttime;
extern int runid;
extern int linenumber;
extern int rseed;
extern FILE *logfile;
extern id specialist;
extern id dividendProcess;
extern id agentManager;
extern id scheduler;
extern id world;
extern id marketApp;
extern const char *colorsfilename;
extern const char *graysfilename;
extern int SHIFT[MAXCONDBITS];
extern unsigned int MASK[MAXCONDBITS];
extern unsigned int NMASK[MAXCONDBITS];

/* Global variables defined in World.m */
extern double price;
extern double oldprice;
extern double dividend;
extern double olddividend;
extern double profitperunit;
extern double returnratio;
extern int nmas;
extern int matime[];
extern double pmav[];
extern double oldpmav[];
extern double dmav[];
extern double olddmav[];
extern int nworldbits;
extern int realworld[];

/* Global variables defined in Specialist.m */
extern double bidtotal;
extern double offertotal;
extern double volume;
extern double oldbidtotal;
extern double oldoffertotal;
extern double oldvolume;

extern double intrate;
extern double intratep1;
extern double minholding;
extern double mincash;
extern double initialcash;
extern BOOL exponentialMAs;

/* Global variables defined in Scheduler.m */
extern const char *paramstring;

/* Global variables defined in error.m */
extern FILE *msgfile;
extern int debug;
extern BOOL quiet;
