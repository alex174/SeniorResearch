// The Santa Fe Stock Market -- Implementation of top-level control routines
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This is the top level controller for the whole market.  The routines
// here can be called either from the graphical front-end or from the
// batch-mode main program.

#include "global.h"
#include "control.h"
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include "amanager.h"
#include "agent.h"
#include "speclist.h"
#include "dividend.h"
#include "schedule.h"
#include "world.h"
#include "output.h"
#include "random.h"
#include "error.h"
#include "util.h"
#include "version.h"

// Keywords with external significance
#define CONTROLFILE	"mcontrol"
#if defined DOS_FILENAMES
#define IDFILE		"runid.txt"
#else
#define IDFILE		"~/.market"
#endif

#define EXTENSIONNAME	".smt"		// Filename suffix for logfile
#define ALLAGENTSNAME	"all"		// For enable events

// Local function prototypes
static int dooptions(int argc, char *argv[]);
static void writeUsage(FILE *fp, const char *argv0);
static void getpreviousrun(void);
static void setrunid(int rid);
static void controlReadParams(const char *filename);
static void outputReadParams(const char *filename);
static void logParameters(FILE *fp);
static void controlWriteParams(FILE *fp);
static void writeEpilogue(FILE *fp);

// Global variables
int t = MININTGR;
int lasttime;
int runid;
int linenumber = 0;
long mseed;
long olddseed;
FILE *logfile = NULL;
id rng;
id specialist;
id dividendProcess;
id agentManager;
id world;
id scheduler;
id marketApp;		// nil if no frontend
BOOL commandline;	// launched from shell?

// Local variables
static long oldmseed;
static long specifiedseed;
static BOOL listnames = NO;
static BOOL listusage = NO;
static char idfile[] = IDFILE;
static char *idfilename;
static FILE *idfp = NULL;

static BOOL writestreams;	// Set if any 'w' events are in the timelist
static BOOL shocking;	  // Set if any 'r' or 's' events are in the timelist

// Filenames.  Those for agents are defined in the individual class files.
// Those for output streams are defined in Output.m.
static const char *cparamfilename;
static const char *timefilename;
static const char *agentlistfilename;
static const char *mparamfilename;
static const char *dparamfilename;
static const char *outputfilename;
static const char *logfilename;
static const char *actual_logfilename = NULL;


/*------------------------------------------------------*/
/*	setEnvironment					*/
/*------------------------------------------------------*/
void setEnvironment(int argc, char *argv[], const char *filename)
/*
 * Sets up the basic environment, including filename paths, options, run
 * number, and debugging flags.  Called very early in start-up.  The
 * arguments are the usual command line arguments and the parameter
 * filename (or NULL for the default).  See writeUsage() for usage.
 */
{
// Get options from command line
    argc = dooptions(argc,argv);
    commandline = (*argv[0] != '/');

// Just list usage information (options etc) and exit if -h or -? option
    if (listusage) {
	writeUsage(stdout, argv[0]);
	exit(0);
    }

// Just list our internal names and exit if -n option
    if (listnames) {
	[Output writeNamesToFile:stdout];
	exit(0);
    }

// Get details from previous run, add 1 to run number
    getpreviousrun();
    ++runid;

// Save controlfile filename if non-NULL; otherwise use internal default
    if (filename)
	cparamfilename = filename;
    else if (argc == 2)
	cparamfilename = argv[1];
    else
	cparamfilename = CONTROLFILE;

// Set path for all auxiliary files to wherever the controlfile is found
    setPath(argv[0],cparamfilename);
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
	    c = *ap++;			// Option byte
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
	    case 'h':
	    case '?':
		listusage = YES;
		break;
	    default:
		saveError("Invalid option '%s': use -h for usage",argv[i]);
	    }
	}
    }

    abandonIfError("dooptions");
    return (j);			// Return new argc
}


/*------------------------------------------------------*/
/*	writeUsage					*/
/*------------------------------------------------------*/
static void writeUsage(FILE *fp, const char *argv0)
{
    fprintf(fp, "\nUsage: %s [options] [controlfilename]\n", argv0);
    fputs(
"\nOptions:\n"
"      -d...   Debug -- one or more letters can follow -d to turn on\n"
"              different debugging options, e.g., -dafh.  See below.\n"
"      -h      Help -- list this usage information and exit.\n"
"      -n      Names -- list variable names etc to stdout and exit.\n"
"      -q      Quiet -- suppress messages to stderr except errors.\n"
"\nDebugging flags:\n",
    fp);
    writeDebugBits(fp);
}


/*------------------------------------------------------*/
/*	getpreviousrun					*/
/*------------------------------------------------------*/
static void getpreviousrun(void)
/*
 * Get the run number from the users' dotfile.
 * [Under NeXTSTEP we could use the defaults database.]
 */
{
    int status;
    char buf[MAXINTCHARS];

// Defaults if no valid previous values
    runid = 0;
    oldmseed = 0;
    olddseed = 0;

// Construct file name -- only ~/ is specially processed
    if (idfile[0] == '~' && idfile[1] == '/') {
	idfilename = (char *)getmem(sizeof(char)*(strlen(idfile) +
					strlen(homeDirectory())));
	strcat(strcpy(idfilename, homeDirectory()), idfile+1);
    }
    else
	idfilename = idfile;

// Read value
    if ((idfp = fopen(idfilename,"r")) != NULL) {
	status = gettok(idfp, buf, MAXINTCHARS);
	if (status >= 0) runid = (int)stringToLong(buf);
	status = gettok(idfp, buf, MAXINTCHARS);
	if (status >= 0) oldmseed = stringToLong(buf);
	status = gettok(idfp, buf, MAXINTCHARS);
	if (status >= 0) olddseed = stringToLong(buf);
	fclose(idfp);
	idfp = NULL;
    }

}


/*------------------------------------------------------*/
/*	setrunid					*/
/*------------------------------------------------------*/
static void setrunid(int rid)
/*
 * Stores a new value for the run number.  The stream is not closed
 * because we'll write some more to it at the end of the run.
 */
{
// Reopen for writing
    idfp = fopen(idfilename,"w");

    if (idfp) {
	fprintf(idfp,"# %s\n"
		     "# This file is updated automatically at each run\n\n",
		     PROJECTTITLE);
	showint(idfp, "number of last run", rid);
	fflush(idfp);
    }
}


/*------------------------------------------------------*/
/*	startup						*/
/*------------------------------------------------------*/
void startup(void)
/*
 * Start up the market and agents, initializing everything.
 */
{
// Show timing
    if (debug&DEBUGCPU) showCPU("startup entry");

// Save the new run number
    setrunid(runid);

// Get general control parameters
    controlReadParams(cparamfilename);

// Open logfile, write headings
    actual_logfilename = namesub(logfilename, EXTENSIONNAME);
    logfile = openOutputFile(actual_logfilename, "log file", YES);

// Echo run number if batch or debugging or command-line use
    if (!marketApp || debug || commandline)
	message(">>> Run %d  Version %s <<<", runid, versionnumber());

// Initialise random number stream.  0 means set randomly, -1 means use last
// value from previous run, to chain runs.
    specifiedseed = mseed;
    if (mseed < 0) mseed = oldmseed;
    rng = [[Random alloc] initWithSeed:&mseed];	// resets actual seed if 0

// Initialize the dividend, specialist, and world (order is crucial)
    dividendProcess = [[Dividend alloc] initFromFile:dparamfilename];
    specialist = [[Specialist alloc] initFromFile:mparamfilename];
    world = [[World alloc] init];
    t = -[world initWithBaseline:[dividendProcess baseline]];

// Initialize the agent modules and create the agents
    agentManager = [[AgentManager alloc] init];
    [agentManager makeAgents:agentlistfilename];

// Initialize the output
    outputReadParams(outputfilename);

// Initialize the scheduler, read times from file
    scheduler = [[Scheduler alloc] initFromFile:timefilename];
    lasttime = [scheduler maxtime];
    writestreams = [scheduler haveEventsOfType:EV_WRITESTREAM]
				|| [scheduler haveEventsOfType:EV_RESETSTREAM];
    shocking = [scheduler haveEventsOfType:EV_SHOCK]
				|| [scheduler haveEventsOfType:EV_RESETSHOCK];
// Close last input file
    closeInputFile();

// Open output files if needed, write headings to each
    if (writestreams)
	writestreams = [Output openOutputStreams];

// Log all our parameters
    logParameters(logfile);

// Show timing
    if (debug&DEBUGCPU) showCPU("startup exit");
}


/*------------------------------------------------------*/
/*	controlReadParams				*/
/*------------------------------------------------------*/
static void controlReadParams(const char *paramfile)
/*
 * Reads parameters from the control parameter file "paramfile"
 */
{
    const char *flagstring;

    (void) openInputFile(paramfile, "control parameters");

    flagstring = readString("debugflags");
    setDebugBits(flagstring);
    free((void *)flagstring);

    mseed = readInt("mseed",-1,MAXINTGR);

    dparamfilename = readString("dparamfilename");
    mparamfilename = readString("mparamfilename");
    agentlistfilename = readString("agentlistfilename");
    outputfilename = readString("outputfilename");
    timefilename = readString("timefilename");

    logfilename = readString("logfilename");

    abandonIfError("controlReadParams");
}


/*------------------------------------------------------*/
/*	outputReadParams				*/
/*------------------------------------------------------*/
static void outputReadParams(const char *paramfile)
/*
 * Reads the specifications for each output stream -- file "paramfile"
 */
{
    const char *name;

    (void) openInputFile(paramfile, "output parameters");

    [Output initClass];

    for (;;) {
	name = readString("streamname");
	if (strcmp(name, ALLENDNAME) == EQ || strcmp(name, "???") == EQ) {
	    free((void *)name);
	    break;
	}
	[[Output alloc] initWithName:name];
    }

    abandonIfError("outputReadParams");
}


/*------------------------------------------------------*/
/*	logParameters					*/
/*------------------------------------------------------*/
void logParameters(FILE *fp)
/*
 * Asks each module to write out its parameters to the log file.
 */
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

    fprintf(fp, "\n# --- Output ---\n");
    showsourcefile(fp, outputfilename);
    [Output writeOutputSpecifications:fp];

    fprintf(fp, "\n# --- Time schedule ---\n");
    showsourcefile(fp, timefilename);
    [scheduler writeParamsToFile:fp];
    fflush(fp);
}


/*------------------------------------------------------*/
/*	controlWriteParams				*/
/*------------------------------------------------------*/
void controlWriteParams(FILE *fp)
/*
 * Writes out our parameters for the log file.
 */
{
    if (fp == NULL) fp = msgfile;	// For use in gdb

    showstrng(fp, "debugflags", debugstring());
    if (specifiedseed < 0) {
	if (oldmseed == 0)
	    showint(fp, "mseed (random -- originally -1)", mseed);
	else
	    showint(fp, "mseed (from previous run -- originally -1)", mseed);
    }
    else if (specifiedseed == 0)
	showint(fp, "mseed (random -- originally 0)", mseed);
    else
	showint(fp, "mseed", mseed);
    showinputfilename(fp, "dparamfilename", dparamfilename);
    showinputfilename(fp, "mparamfilename", mparamfilename);
    showinputfilename(fp, "agentlistfilename", agentlistfilename);
    showinputfilename(fp, "outputfilename", outputfilename);
    showinputfilename(fp, "timefilename", timefilename);
    showoutputfilename(fp, "logfilename", logfilename, actual_logfilename);
}


/*------------------------------------------------------*/
/*	warmup						*/
/*------------------------------------------------------*/
void warmup(void)
/*
 * Run a warmup period, for use before the market is active.  Used to
 * create an artificial prehistory for the moving averages etc.  Similar to
 * period(), but with a fake price-setting mechanism and no involvement of
 * the agents.  Used with t < 0 on entry.
 */
{
    double newdividend;

// Time passes
    t++;

// Obtain new dividend from stochastic process
    newdividend = [dividendProcess dividend];

// Set the new dividend, update dividend moving averages etc
    [world setDividend:newdividend];

// Make a new world bit vector
    [world makeBitVector];

// Set a fake price (crude fundamental value), update price MAs etc
    [world setPrice:dividend/intrate];

// Update accumulation variables
    [Output updateAccumulators];
}


/*------------------------------------------------------*/
/*	period						*/
/*------------------------------------------------------*/
void period(void)
/*
 * Run one period of the market.  Used with t >= 0 on entry.
 */
{
    Agent **idlist;
    int i, nenabled;
    double newdividend, newprice;

// Time passes
    t++;

// Obtain new dividend from stochastic process
    newdividend = [dividendProcess dividend];

// Set the new dividend, update dividend moving averages, etc
    [world setDividend:newdividend];

// Make a new world bit vector
    [world makeBitVector];

// Get list of enabled agents
    idlist = [agentManager enabledAgents:&nenabled];

// Tell the agents to credit their earnings and pay their taxes
    for (i=0; i<nenabled; i++)
	[idlist[i] creditEarningsAndPayTaxes];

// Tell all types with nagents > 0 to get ready for trading
    [agentManager prepareTypesForTrading];

// Tell individual agents to get ready  for trading (they may run GAs here)
    for (i=0; i<nenabled; i++)
	[idlist[i] prepareForTrading];

// Do the trading -- agents make bids/offers at one or more trial prices
    newprice = [specialist performTrading];

// Set the new price from the last trial price, update price MAs etc
    [world setPrice:newprice];

// Complete the trades -- change agents' position, cash, and profit
    [specialist completeTrades];

// Tell the agents to update their performance measures etc
    for (i=0; i<nenabled; i++)
	[idlist[i] updatePerformance];

// Update accumulation variables
    [Output updateAccumulators];
}


/*------------------------------------------------------*/
/*	performEvents					*/
/*------------------------------------------------------*/
void performEvents(void)
/*
 * Perform any events scheduled for this time.  This is called after
 * each period.
 */
{
    BOOL done = NO;

// Special event at time 0
    if (t == 0)
	[Output resetAccumulators];

    do {
	switch([scheduler nextEvent]) {

	case EV_WRITESTREAM:	// Write output values
	    if (writestreams)
		[Output writeOutputToStream:paramstring];
	    break;

	case EV_RESETSTREAM:	// Reset accumulators in output stream 
	    if (writestreams)
		[Output resetAccumulatorsForStream:paramstring];
	    break;

	case EV_EVOLVE:		// Evolve agents
	    [agentManager evolveAgents];
	    break;

	case EV_ENABLEAGENT:	// Enable one or all agents
	    if (strcmp(paramstring, ALLAGENTSNAME) == EQ)
		[agentManager enableAll];
	    else
		[agentManager enable:(int)stringToLong(paramstring)];
	    break;

	case EV_DISABLEAGENT:	// Disable an agent
	    [agentManager disable:(int)stringToLong(paramstring)];
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

// Write out the epilogue to the .market file
    writeEpilogue(idfp);

// Show timing
    if (debug&DEBUGCPU) showCPU("finished");
}


/*------------------------------------------------------*/
/*	writeEpilogue					*/
/*------------------------------------------------------*/
/*
 * Writes information about the run to the id file.
 */
void writeEpilogue(FILE *fp)
{
    if (!fp) return;
    showint(fp, "ending market rng seed", (int)[rng rngstate]);
    showint(fp, "ending dividend rng seed",
				    (int)[[dividendProcess rng] rngstate]);
    showint(fp, "maximum time", t);
    showstrng(fp, "logfilename",
			    (actual_logfilename?actual_logfilename:"<none>"));
}



/*------------------------------------------------------*/
/*	closeall					*/
/*------------------------------------------------------*/
void closeall(void)
/*
 * Close all files.  Called just before exit.
 */
{
// Close the id file if any
    if (idfp) fclose(idfp);

// Close the logfile if any (except stdout)
    if (logfile != NULL && logfile != stdout) fclose(logfile);

// Close all the output styreams
    [Output closeOutputStreams];

// Show timing
    if (debug&DEBUGCPU) showCPU("closeall");
}


/*------------------------------------------------------*/
/*	marketDebug					*/
/*------------------------------------------------------*/
void marketDebug(void)
/*
 * Debugging for the market.  May be called at regular intervals.
 */
{
    static int prevt = MAXINTGR;

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

}
