/* Arthur-Holland-LeBaron-Palmer-Tayler Stockmarket Project */

// This is the top level controller for the whole market.  The routines
// here could be called either from the graphical front-end or from a
// batch-mode main program (as long as the appropriate version of the
// error manager is used).

#import "global.h"
#import "control.h"
#import <stdlib.h>
#import <string.h>
#import <sys/param.h>
#import "AgentManager.h"
#import "Agent.h"
#import "Specialist.h"
#import "Dividend.h"
#import "Scheduler.h"
#import "World.h"
#import "Output.h"
#import "random.h"
#import "error.h"
#import "util.h"
#import "version.h"

/* Constants */
#define CONTROLFILE	"marketcontrol"
#define IDFILE		"~/.market"

// Tables for fast bit packing, for use by agents with condition bits
int SHIFT[MAXCONDBITS];
unsigned int MASK[MAXCONDBITS];
unsigned int NMASK[MAXCONDBITS];

// Local function prototypes
static int getrunid(void);
static void setrunid(int rid);
static int dooptions(int argc, char *argv[]);
static void controlReadParams(const char *filename);
static void controlWriteParams(FILE *fp);
static void logParameters(FILE *fp);
static void writeAllNames(FILE *fp);
static void makebittables(void);

// Global variables
int t = MININT;
int lasttime;
int runid;
int linenumber = 0;
int rseed;
FILE *logfile = NULL;
id specialist;
id dividendProcess;
id agentManager;
id world;
id scheduler;
id marketApp;		// nil if no frontend
BOOL commandline;	// launched from shell
const char *colorsfilename;
const char *graysfilename;

// Local variables
static BOOL randomseed;
static BOOL listnames = NO;
static FILE *agentstatfile = NULL;
static char idfile[] = IDFILE;
static FILE *idfp;

static BOOL writeagents;/* Set if 'a' events are in the timelist */
static BOOL writeworld;	/* Set if 'w' events are in the timelist */
static BOOL shocking;	/* Set if 'r' or 's' events are in the timelist */

// Filenames.  Those for agents are defined in the individual class files.
// Those for output streams are defined in World.m.
static const char *cparamfilename;
static const char *timefilename;
static const char *agentlistfilename;
static const char *mparamfilename;
static const char *dparamfilename;
static const char *logfilename;
static const char *agentstatfilename;
static const char *actual_logfilename = NULL;
static const char *actual_agentstatfilename = NULL;


/*------------------------------------------------------*/
/*	setEnvironment					*/
/*------------------------------------------------------*/
void setEnvironment(int argc, char *argv[], const char *filename)
/*
 * Sets up the basic environment, including filename paths, options, run
 * number, and debugging flags.  Called very early in start-up.  The
 * arguments are the usual command line arguments and the parameter
 * filename (or NULL for the default).  The command line arguments are:
 *	-q	Quiet -- suppress messages to msgfile except errors
 *	-d...	Debug; one or more letters can follow -d to turn on
 *		different debugging options, e.g., -dafh.  See the default
 *		marketcontrol file for details.
 *	-n	List variable and bit names to stdout and exit.
 */
{
/* Get options from command line */
    argc = dooptions(argc,argv);
    commandline = (*argv[0] != '/');

/* Just list our internal names and exit if -n option */
    if (listnames) {
	writeAllNames(stdout);
	exit(0);
    }

/* Get previous run number, add 1 */
    runid = getrunid() + 1;

/* Save filename if non-NULL; otherwise use internal default */
    if (filename)
	cparamfilename = filename;
    else if (argc == 2)
	cparamfilename = argv[1];
    else
	cparamfilename = CONTROLFILE;

/* Set path for all auxiliary files to wherever cparamfilename is found */
    setPath(argv[0],cparamfilename);
}


/*------------------------------------------------------*/
/*	startup						*/
/*------------------------------------------------------*/
void startup(void)
/*
 * Start up the market and agents, initializing everything.
 */
{
/* Show timing */
    if (debug&DEBUGCPU)
	showCPU("startup entry");

/* Save the new run number */
    setrunid(runid);

/* Get general control parameters and output specifications */
    controlReadParams(cparamfilename);

/* Open logfile, write headings */
    actual_logfilename = namesub(logfilename, ".skmt");
    logfile = openOutputFile(actual_logfilename, YES);

/* Echo run number if batch or debugging or [usual] command-line use */
    if (!marketApp || debug || commandline)
	Message(">>> Run %d  Version %s <<<", runid, versionnumber());

/* Initialise random number stream (0 means set randomly) */
    randomseed = (rseed == 0);
    rseed = randset(rseed);	// returns actual seed if 0

/* Make global bit-packing tables */
    makebittables();

/* Initialize the dividend, specialist, and world (order is crucial) */
    dividendProcess = [[Dividend alloc] initFromFile:dparamfilename];
    specialist = [[Specialist alloc] initFromFile:mparamfilename];
    world = [[World alloc] init];
    t = -[world initWithBaseline:[dividendProcess baseline]];

/* Initialize the agent modules and create the agents */
    agentManager = [[AgentManager alloc] init];
    [agentManager makeAgents:agentlistfilename];

/* Initialize the scheduler, read times from file */ 
    scheduler = [[Scheduler alloc] initFromFile:timefilename];
    lasttime = [scheduler maxtime];
    writeworld = [scheduler haveEventsOfType:EV_WRITEWORLD];
    writeagents = [scheduler haveEventsOfType:EV_WRITEAGENTINFO];
    shocking = [scheduler haveEventsOfType:EV_SHOCK] 
				|| [scheduler haveEventsOfType:EV_RESETSHOCK];

/* Close last input file */
    CloseInputFile();
    
/* Open auxiliary output files if needed, write headings to each */
    if (writeworld)
	writeworld = [Output openOutputStreams];

    if (writeagents) {
        actual_agentstatfilename = namesub(agentstatfilename, NULL);
	agentstatfile = openOutputFile(actual_agentstatfilename, YES);
	if (!agentstatfile) {	/* filename = <none> */
	    writeagents = NO;
	    actual_agentstatfilename = NULL;
	}
    }

/* Log all our parameters */
    logParameters(logfile);

/* Show timing */
    if (debug&DEBUGCPU)
	showCPU("startup exit");
}

/*------------------------------------------------------*/
/*	warmup						*/
/*------------------------------------------------------*/
void warmup(void)
/*
 * Run a warmup period, for use before the market is active.  Used to
 * create an artificial prehistory for the moving averages etc.  Similar to
 * period(), but with a fake price-setting mechanism replacing the agents. 
 */  
{
    double newdividend;

// Time passes
    t++;

// Obtain new dividend from stochastic process
    newdividend = [dividendProcess dividend];

// Set the new dividend
    [world setDividend:newdividend];

// Update world -- moving averages, bits, etc
    [world updateWorld];

// Fake price setting (crude fundamental value)
    [world setPrice:dividend/intrate];

// Update accumulation variables    
    [Output updateAccumulators];
}


/*------------------------------------------------------*/
/*	period						*/
/*------------------------------------------------------*/
void period(void)
/*
 * Run one period of the market.
 */  
{
    Agent **idlist;
    int i, nenabled;
    double newdividend, newprice;

// Time passes
    t++;

// Obtain new dividend from stochastic process
    newdividend = [dividendProcess dividend];

// Set the new dividend
    [world setDividend:newdividend];

// Get list of enabled agents
    idlist = [agentManager enabledAgents:&nenabled];

// Tell the agents to credit their earnings and pay their taxes
    for (i=0; i<nenabled; i++)
	[idlist[i] creditEarningsAndPayTaxes];

// Update world -- moving averages, bits, etc
    [world updateWorld];

// Tell all types with nagents > 0 to get ready for trading
    [agentManager prepareTypesForTrading];

// Tell individual agents to get ready  for trading (they may run GAs here)
    for (i=0; i<nenabled; i++)
	[idlist[i] prepareForTrading];

// Do the trading -- agents make bids/offers at one or more trial prices
    newprice = [specialist performTrading];

// Set the new price from the last trial price
    [world setPrice:newprice];

// Complete the trades -- change agents' position, cash, and profit
    [specialist completeTrades];

// Tell the agents to update their performance
    for (i=0; i<nenabled; i++)
	[idlist[i] updatePerformance];

// Update accumulation variables
    [Output updateAccumulators];
}


/*------------------------------------------------------*/
/*	performEvents					*/
/*------------------------------------------------------*/
void performEvents()
{
    BOOL done = NO;
    BOOL agentsdone = NO;

// Special event at time 0
    if (t == 0)
	[Output resetAccumulators];
    
    do {
	switch([scheduler nextEvent]) { 

	case EV_WRITEAGENTINFO:	// Write agent info
	    if (writeagents && !agentsdone)
		[agentManager printAgentInfo:agentstatfile];
	    agentsdone = YES;
	    break;

	case EV_WRITEWORLD:	// Write world (market) information
	    if (writeworld)
		[Output writeOutputStream:paramstring];
	    break;

	case EV_EVOLVE:		// Evolve agents
	    [agentManager evolveAgents];
	    break;

	case EV_ENABLEAGENT:	// Enable one or all agents
	    if (strcmp(paramstring,"all") == EQ)
		[agentManager enableAll];
	    else
		[agentManager enable:stringToInt(paramstring)];
	    break;

	case EV_DISABLEAGENT:	// Disable an agent
	    [agentManager disable:stringToInt(paramstring)];
	    break;
    
	case EV_SHOCK:		// Add a dividend shock
	    [dividendProcess addShock];
	    break;
	    
	case EV_RESETSHOCK:	// Reset dividend shock
	    [dividendProcess resetShock];
	    break;
	
	case EV_LEVEL:
	    [agentManager level];
	    break;

	case EV_SET_SPECIALIST_PARAM:
	    [specialist setParamFromString:paramstring];
	    break;

	case EV_SET_DIVIDEND_PARAM:
	    [dividendProcess setParamFromString:paramstring];
	    break;

	case EV_DEBUG:
	    if (debug)
		marketDebug();
	    break;

	case EV_NONE:	// No more
	    done = YES;
	    break;

	default:	// Ignore anything else
	    break;
	}
    } while (!done);
}


/*------------------------------------------------------*/
/*	finished					*/
/*------------------------------------------------------*/
/*
 * Wrap-up for the market.  Called after last period.
 */
void finished(void)
{
    if (debug&DEBUGCPU)
	showCPU("finished");
}


/*------------------------------------------------------*/
/*	closeall					*/
/*------------------------------------------------------*/
void closeall(void)
/*
 * Close all files.  Called just before exit.
 */
{
    if (logfile != NULL && logfile != stdout)
	fclose(logfile);
    [Output closeOutputStreams];
    if (agentstatfile != NULL && agentstatfile != stdout)
	fclose(agentstatfile);
    if (debug&DEBUGCPU)
	showCPU("closeall");
}


/*------------------------------------------------------*/
/*	getrunid					*/
/*------------------------------------------------------*/
// This routine gets the run id.  We use a dotfile for this, rather
// than the defaults database, so that it's not NeXTSTEP dependent.
static int getrunid(void)
{
    int id1, status;
    char buf[MAXINTCHARS];
    char idfilename[MAXPATHLEN+1];

// Default if no valid previous value
    id1 = 0;

// Construct file name -- only ~/ is specially processed
    if (idfile[0] == '~' && idfile[1] == '/')
	strcat(strcpy(idfilename, homeDirectory()), idfile+1);
    else
	strcpy(idfilename, idfile);

// Read value, set up file for writing
    if ((idfp = fopen(idfilename,"r+")) != NULL) {
	status = gettok(idfp, buf, MAXINTCHARS);
	if (status >= 0)
	    id1 = stringToInt(buf);
	rewind(idfp);
    }
    else
	idfp = fopen(idfilename,"w");	// Set up to write it back later

    return id1;
}


/*------------------------------------------------------*/
/*	setrunid					*/
/*------------------------------------------------------*/
// Stores a new value for the runid.
static void setrunid(int rid)
{
    if (idfp) {
	fprintf(idfp,"# %s\n"
		     "%d # number of last run\n\n"
		     "# This file is updated automatically at each run\n",
		     projecttitle(), rid);
	fclose(idfp);
    }
}


/*------------------------------------------------------*/
/*	marketDebug					*/
/*------------------------------------------------------*/
void marketDebug(void)
/*
 * Debugging for the market.  May be called at regular intervals.
 */
{
    static int prevt = MAXINT;
    
    if (t == prevt)
	return;		// Only do once at a given time
    prevt = t;

// Check world
    if (debug&DEBUGWORLD)
	[world check];

// Check agents
    if (debug&DEBUGAGENT)
	[agentManager checkAgents];

// Check total holding
    if (debug&DEBUGHOLDING)
	[agentManager checkTotalHolding];

// Report memory usage
    if (debug&DEBUGMEMORY && !quiet)
	Message("#m: total malloc = %u", totalMemory());

}


/*------------------------------------------------------*/
/*	dooptions					*/
/*------------------------------------------------------*/
static int dooptions(int argc, char *argv[])
/*
 * dooptions is called to process command line arguments.
 * It returns a new value of argc and changes argv[] appropriately.
 * (Code based on public-domain Decus cpp)
 */
{
    register int c,i,j;
    char *ap;

    for (i=j=1; i<argc; i++) {
	ap = argv[i];
	if (*ap++ != '-' || *ap == EOS)
	    argv[j++] = argv[i];
	else {
	    c = *ap++;			/* Option byte */
	    switch (c) {
	    case 'q':
		quiet = YES;
		break;
	    case 'd':
	    case '#':
		setDebugBits(ap);
		break;
	    case 'n':
		listnames = YES;
		break;
	    default:
		saveError("Invalid option: %s",argv[i]);
	    }
	}
    }

    abandonIfError("dooptions");
    return (j);			/* Return new argc */
}


/*------------------------------------------------------*/
/*	controlReadParams				*/
/*------------------------------------------------------*/
static void controlReadParams(const char *paramfile)
/*
 * Reads parameters from control parameter file paramfile
 */
{
    const char *flagstring, *name;

    (void) OpenInputFile(paramfile, "control parameters");

    flagstring = ReadString("debugflags");
    setDebugBits(flagstring);
    free((void *)flagstring);    

    rseed = ReadInt("rseed",0,MAXINT);

    dparamfilename = ReadString("dparamfilename");
    mparamfilename = ReadString("mparamfilename");
    agentlistfilename = ReadString("agentlistfilename");
    timefilename = ReadString("timefilename");
    colorsfilename = ReadString("colorsfilename");
    graysfilename = ReadString("graysfilename");

    logfilename = ReadString("logfilename");
    agentstatfilename = ReadString("agentstatfilename");

// Read the specifications for each output stream
    for (;;) {
	name = ReadString("streamname");
	if (strcmp(name, "end") == EQ || strcmp(name, ".") == EQ ||
					strcmp(name, "???") == EQ) {
	    free((void *)name);
	    break;
	}
	[[Output alloc] initWithName:name];
    }

    abandonIfError("controlReadParams");
}


/*------------------------------------------------------*/
/*	controlWriteParams				*/
/*------------------------------------------------------*/
void controlWriteParams(FILE *fp)
/*
 * Writes out our parameters
 */
{
    if (fp == NULL) fp = stderr;	// For use in gdb

    showstrng(fp, "debugflags", debugstring());
    showint(fp, (randomseed? "rseed (originally 0)": "rseed"), rseed);
    showinputfilename(fp, "dparamfilename", dparamfilename);
    showinputfilename(fp, "mparamfilename", mparamfilename);
    showinputfilename(fp, "agentlistfilename", agentlistfilename);
    showinputfilename(fp, "timefilename", timefilename);
    showstrng(fp, "colorsfilename", colorsfilename);
    showstrng(fp, "graysfilename", graysfilename);
    showoutputfilename(fp, "logfilename", logfilename,
						    actual_logfilename);
    showoutputfilename(fp, "agentstatfilename", agentstatfilename,
						    actual_agentstatfilename);
    [Output showOutputStreams:fp];
}


/*------------------------------------------------------*/
/*	logParameters					*/
/*------------------------------------------------------*/
void logParameters(FILE *fp)
{
    if (!fp) return;
    
    showsourcefile(fp, cparamfilename);
    fprintf(fp, "\n# --- Control parameters ---\n");
    controlWriteParams(fp);

    fprintf(fp, "\n# --- Dividend parameters ---\n");
    showsourcefile(fp, dparamfilename);
    [dividendProcess writeParamsToFile:fp];

    fprintf(fp, "\n# --- Market parameters ---\n");
    showsourcefile(fp, mparamfilename);
    [specialist writeParamsToFile:fp];

    fprintf(fp, "\n# --- Agent list ---\n");
    showsourcefile(fp, agentlistfilename);
    [agentManager writeParamsToFile:fp];	// Also lists agents' params

    fprintf(fp, "\n# --- Time schedule ---\n");
    showsourcefile(fp, timefilename);
    [scheduler writeParamsToFile:fp];
    fflush(fp);
}


/*------------------------------------------------------*/
/*	writeAllNames					*/
/*------------------------------------------------------*/
static void writeAllNames(FILE *fp)
{
    drawLine(fp, '=');
    fprintf(fp,"#\t*** %s ***\n#  Version %s (%s) - %s\n",
	projecttitle(), versionnumber(), compilehost(), versiondate());
    drawLine(fp, '=');
    fputs(
"# This is a list of the variable and bit names that are recognized.\n"
"# Any of these names, including bit names, may be used in output\n"
"# specifications.  The bit names may also be used to name condition\n"
"# bits for certain agent classes.\n"
"#\n"
"# Integer variables and bits need integer output formats (e.g., %d)\n"
"# unless accumulated with '+' or '@' (see marketcontrol).  Real\n"
"# variables and any accumulated variables or bits need double output\n"
"# formats (e.g., %f)\n"
"#\n"
"# Use the -n option to produce this listing.\n",
	fp);
    [Output writeNamesToFile:fp];
    [World writeNamesToFile:fp];
    putc('\n', fp);
    showstrng(fp, "all of the above bits", "allbits");
}


/*------------------------------------------------------*/
/*	makebittables					*/
/*------------------------------------------------------*/
static void
makebittables()
/*
 * NOTE: These comments date from when we packed the whole of "realworld"
 * into a bit string.  Now only certain agents do this, for selected bits,
 * but the overall design still applies.
 *
 * Construct tables for fast bit packing and condition checking for
 * classifier systems.  Assumes 32 bit words, and storage of 16 ternary
 * values (0, 1, or *) per word, with one of the following codings:
 * Value       Message-board coding         Rule coding
 *   0			2			1
 *   1			1			2
 *   *			-			0
 * Thus rule satisfaction can be checked with a simple AND between
 * the two types of codings.
 *
 * Sets up the tables to store MAXCONDBITS ternary values in
 * CONDWORDS = ceiling(MAXCONDBITS/16) words.
 *
 * After calling this routine, given an array declared as
 *		int array[CONDWORDS];
 * you can do the following:
 *
 * a. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] |= value << SHIFT[n];
 *    if the stored value was previously 0; or
 * 
 * b. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] = (array[WORD(n)] & NMASK[n]) | (value << SHIFT[n]);
 *    if the initial state is unknown.
 *
 * c. Store value 0 for bit n with
 *	array[WORD(n)] &= NMASK[n];
 *
 * d. Extract the value of bit n (0, 1, 2, or possibly 3) with
 *	value = (array[WORD(n)] >> SHIFT[n]) & 3;
 *
 * e. Test for value 0 for bit n with
 *	if ((array[WORD(n)] & MASK[n]) == 0) ...
 *
 * f. Check whether a condition is fulfilled (using the two codings) with
 *	for (i=0; i<CONDWORDS; i++)
 *	    if (condition[i] & array[i]) break;
 *	if (i != CONDWORDS) ...
 *
 */
{
    register int bit;

    for (bit=0; bit < MAXCONDBITS; bit++) {
	SHIFT[bit] = (bit%16)*2;
	MASK[bit] = 3 << SHIFT[bit];
	NMASK[bit] = ~MASK[bit];
    }
}
