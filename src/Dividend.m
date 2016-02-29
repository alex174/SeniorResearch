// The Santa Fe Stockmarket -- Implementation of the dividend process.

// This object produces a stochastic sequence of dividends, based on one
// of several stochastic processes.  Each process is independent of the
// market and agents, depending only the parameters that are set herein
// (and on the random number generator).

// One instance of this class is used for the actual dividend process used
// in the market, and a second one is used for the dividend inspector.  The
// second one is obtained by copying the main one, not by alloc/init.

// PUBLIC METHODS
//
// - initFromFile:(const char *)paramfile
//	Initializes the instance, reading parameters from the specified
//	dividend parameters file.
//
// - writeParamsToFile:(FILE *)fp
//	Writes the current values of the parameters to a file (or msgfile
//	if fp==NULL, for use in gdb).  The parameters are written in
//	exactly the format expected by "-initFromFile:".
//
// - (double)dividend;
//	Returns the next value of the dividend.  This is the core method
//	of the Dividend object, for which all else exists.  It does NOT
//	use the global time "t", but simply assumes that one period
//	passes between each call.
//
// - setDivType:(DivType)type;
//	Sets the type of dividend process.  The available types are:
//
//	DIV_AR1		An AR(1) process (colored noise, Ornstein-Uhlenbeck).
//
//	DIV_MARKOV	A two-state process (high or low dividend) with
//			fixed probabilities for high->low and low->high
//			transitions.
//
//	DIV_WHITE	Gaussian white noise; each point is independent
//			of the previous one.
//
//	DIV_IID		A two-state process (high or low dividend) with
//			each point independent of the previous one -- a
//			Bernouilli process of independent coin flips.
//
//	DIV_SQUARE	A periodic square wave.  The up and down parts may
//			be of different duration.
//
//	DIV_TRIANGLE	A periodic triangular wave, consisting of alternating
//			up and down ramps.
//
//	DIV_SINE	A periodic sinusoidal wave.  The upwards and downwards
//			halves may be of different durations.
//
//	These processes are parameterized by some or all of the
//	following parameters:
//
//	baseline	The centerline around which deviations are computed.
//			This is equal to the mean for a symmetric process
//			(i.e., if asymmetry = 0).  "baseline" is set only
//			from the parameter file, and should NOT normally
//			be changed from the default value (10.0).
//
//	amplitude	The amplitude of the deviations from the baseline.
//			Measured in units of "baseline".  The standard
//			deviation of the process is proportional to this.
//
//	period		The period or auto-correlation time of the process.
//			Not used by the DIV_WHITE and DIV_IID processes.
//
//	asymmetry	An asymmetry parameter, from -1 to 1.  0 represents
//			a process symmetric around the baseline and/or
//			around the midpoint of "period".  For a periodic
//			process this controls the relative length of the
//			upwards and downwards pparts.  For DIV_MARKOV and
//			DIV_IID it controls the relative probability of
//			being high or low.  Not used for DIV_AR1 or DIV_WHITE.
//
// - (DivType)divType
//	Returns the type of process currently set, as a numerical code.
//
// - (const char *)divTypeNameFor:(DivType)type
//	Returns a character string describing the specified type, from
//	the dtypekeys[] table below.
//
// - (double)baseline
//	Returns the value of the "baseline" parameter.
//
// - (double)setAmplitude:(double)theAmplitude
//	Sets the "amplitude" parameter.  See "-setDivType:".  Returns the
//	value actually set, which may be clipped or rounded compared to the
//	supplied argument.
//
// - (double)amplitude
//	Returns the current value of the "amplitude" parameter.
//
// - (int)setPeriod:(int)thePeriod
//	Sets the "period" parameter.  See "-setDivType:".  Returns the
//	value actually set, which may be clipped compared to the
//	supplied argument.
//
// - (int)period
//	Returns the current value of the "period" parameter.
//
// - (double)setAsymmetry:(double)theAsymmetry
//	Sets the "asymmetry" parameter.  See "-setDivType:".  Returns the
//	value actually set, which may be clipped or rounded compared to the
//	supplied argument.
//
// - (double)asymmetry
//	Returns the current value of the "asymmetry" parameter.
//	
// - (double)mean
//	Returns the theoretical mean of the current dividend process.  This
//	is not corrected for discreteness, shocks, or clipping.
//
// - (double)sd
//	Returns the theoretical standard deviation of the current
//	dividend process.  This is not corrected for discreteness,
//	shocks, or clipping.
//
// - addShock
//	Adds a dividend shock to the current process.  A dividend shock is
//	an additive contribution to the total dividend which starts out
//	with magnitude "shocksize" (in units of "baseline") and decays away
//	exponentially with time-constant "shocktime".  Multiple shocks may
//	be imposed by calling addShock repeatedly; the total current shock
//	decays by a factor exp(-1/shocktime) at each time step.
//
// - resetShock
//	Resets the current additive shock term to 0.
// 
// - (double)setShocksize:(double)theShocksize
//	Sets the "shocksize" parameter.  See "-addShock".  Returns the
//	value actually set, which may be clipped or rounded compared to the
//	supplied argument.
//
// - (double)shocksize
//	Returns the current value of the "shocksize" parameter.
//
// - (int)setShocktime:(int)theShocktime
//	Sets the "shocktime" parameter.  See "-addShock".  Returns the
//	value actually set, which may be clipped compared to the
//	supplied argument.
//
// - (int)shocktime
//	Returns the current value of the "shocktime" parameter.
//
// - setParamFromString:(const char *)string;
//	Sets a parameter from a string value that gives the name of the
//	parameter and then its value, separated by whitespace.  E.g.,
//		amplitude 0.5
//		divtype square
//	The possible parameter names are given in the dparamkeys[] table
//	below.  This is the routine used to interpret scheduled "dividend"
//	events in the timelist file.  It also notifies the Dividend Inspector
//	(via the MarketApp frontend) when a parameter is changed.
//
// - (const char *)divParamNameFor:(DparamType)paramtype
//	Returns the name for a coded parameter type -- an entry from the
//	dparamkeys[] table below.  The Dividend Inspector uses this to
//	produce events for the timelist file.

// GLOBAL VARIABLES NEEDED
//
// id marketApp
//	Main App's id if we have a front-end; nil if batch.  Used by
//	"-setParamFromString:" to notify the Dividend Inspector when
//	parameters are changed by scheduled events. 
//
// int debug
// BOOL quiet
//	Debugging flags.

// IMPORTS
#import "global.h"
#import "Dividend.h"
#import <ctype.h>
#import <math.h>
#import "Protocols.h"
#import "random.h"
#import "error.h"
#import "util.h"

/* Constants */
#define PI		3.14159265

// Table of keywords for dividend types.  These give the keywords to use
// in the dividend parameter file.  To add a new type you need to:
// (1) add to the DivType enum definition in the .h file;
// (2) add to this table;
// (3) add desired code to each "switch (divtype)" in this file;
// (4) add radio button to dividend inspector panel and set tag;
// (5) add comment to default "dparams" file.

struct keytable dtypekeys[] = {
    {"ar1", DIV_AR1},
    {"markov", DIV_MARKOV},
    {"white", DIV_WHITE},
    {"iid", DIV_IID}, 
    {"square", DIV_SQUARE},
    {"ramp", DIV_TRIANGLE},
    {"sine", DIV_SINE},
    {NULL, -1}
};

// Table of keywords for scheduled parameter setting.  These give the
// keywords used externally in the timelist file.

struct keytable dparamkeys[] = {
    {"divtype", DPARAM_DIVTYPE},
    {"period", DPARAM_PERIOD},
    {"shocktime", DPARAM_SHOCKTIME},
    {"amplitude", DPARAM_AMPLITUDE},
    {"asymmetry", DPARAM_ASYMMETRY},
    {"shocksize", DPARAM_SHOCKSIZE},	
    {NULL, DPARAM_UNKNOWN}
};

// PRIVATE METHODS
@interface Dividend(Private)
- setDerivedParams;
@end


@implementation Dividend

// -------------------------- Designated initializer --------------------

- initFromFile:(const char *)paramfile
/*
 * Initializes the dividend routines, reading parameters from "paramfile".
 */
{
    int i;
    
/* Read parameters from file paramfile */
    (void) OpenInputFile(paramfile, "dividend parameters");
    i = ReadKeyword("divtype",dtypekeys);
    divtype = (i>=0?(DivType)i:DIV_AR1);
    baseline = ReadDouble("baseline",0.0,1000.0);
    mindividend = ReadDouble("mindividend",0.0,baseline);
    maxdividend = ReadDouble("maxdividend",baseline,2000.0);
    amplitude = ReadDouble("amplitude",0.0,1.0);
    period = ReadInt("period",2,MAXINT);
    asymmetry = ReadDouble("asymmetry",-1.0,1.0);
    shocksize = ReadDouble("shocksize",-1.0,2.0);
    shocktime = ReadInt("shocktime",0,MAXINT);
    abandonIfError("[Dividend initFromFile:]");

/* Round certain parameters for inspector display */
    amplitude = 0.0001*rint(10000.0*amplitude);
    asymmetry = 0.001*rint(1000.0*asymmetry);

/* Construct constants and initial values */
    time = 0;
    dvdnd = baseline;		/* last value returned */
    shock = 0.0;
    needsSetDerivedParams = YES;

/* Set derived parameters */
    [self setDerivedParams];

    return self;
}


// --------------------- Method to record parameters ------------------

- writeParamsToFile:(FILE *)fp
{
    const char *addnl;
    
    if (fp == NULL) fp = stderr;	// For use in gdb

    showstrng(fp, "divtype", [self divTypeNameFor:divtype]);
    showdble(fp, "baseline", baseline);
    showdble(fp, "mindividend", mindividend);
    showdble(fp, "maxdividend", maxdividend);
    showdble(fp, "amplitude", amplitude);
    showint(fp, "period", period);
    showdble(fp, "asymmetry", asymmetry);
    showdble(fp, "shocksize", shocksize);
    showint(fp, "shocktime", shocktime);
    addnl = [self addnlInfo];
    if (*addnl != EOS)
	fprintf(fp, "# %s\n", addnl);
    
    return self;
}

// --------------------- Methods to set parameters ----------------------

// Most of these return the value actually set, which may not be the same
// as that requested.  Real-valued quantities are always rounded to
// ensure reproducability and to fit screen fields.

- setParamFromString:(const char *)string
/*
 * Decodes a string from the timelist file specifying a change to a dividend
 * parameter.  Also tells the dividend inspector to update its display
 * appropriately.  Note that this method is only used for scheduled events. 
 * User-initiated events are handled by the dividend inspector, which then
 * calls the lower-level methods like -setDivType: directly.
 */
{
    const char *ptr;
    char buf[MAXSTRING];
    int c, n, dtype;
    
    for (ptr=string, n=0; (c=*ptr)!=EOS && !isspace(c); ptr++) 
	if (n < MAXSTRING-1) buf[n++] = c;
    buf[n] = EOS;
    if (c == EOS)
	[self error:"Missing value for dividend '%s' parameter",string];
    while (isspace(*ptr)) ptr++;

    switch((DparamType)lookup(buf,dparamkeys)) {
    case DPARAM_UNKNOWN:
	[self error:"Unknown dividend parameter '%s'", buf];
    case DPARAM_DIVTYPE:
	dtype = lookup(ptr,dtypekeys);
	if (dtype < 0)
	    [self error:"Unknown dividend type '%s'", ptr];
	[self setDivType:(DivType)dtype];
	break;
    case DPARAM_PERIOD:
	(void)[self setPeriod:stringToInt(ptr)];
	break;
    case DPARAM_AMPLITUDE:
	(void)[self setAmplitude:stringToDouble(ptr)];
	break; 
    case DPARAM_ASYMMETRY:
	(void)[self setAsymmetry:stringToDouble(ptr)];
	break; 
    case DPARAM_SHOCKSIZE:
	(void)[self setShocksize:stringToDouble(ptr)];
	break; 
    case DPARAM_SHOCKTIME:
	(void)[self setShocktime:stringToInt(ptr)];
	break;
    }
    [marketApp divParamsChanged:self];
    return self;
}


- setDivType:(DivType)theType
{
#ifdef DEBUG
    (void)[self divTypeNameFor:theType];
#endif
    divtype = theType;

    if (needsSetDerivedParams)
	[self setDerivedParams];

// Initialization for some DivType's -- not needed for all.
    switch (divtype) {
    case DIV_AR1:
	dvdnd = baseline + gauss*normal();
	break;
    case DIV_MARKOV:
	dvdnd = baseline + (dvdnd >= baseline)? deviation: -deviation;
	break;
    default:
	break;
    }
    [self resetShock];
    needsSetDerivedParams = YES;

    return self;
}


- (double)setAmplitude:(double)theAmplitude
{
    amplitude = theAmplitude;
    if (amplitude < 0.0) amplitude = 0.0;
    if (amplitude > 1.0) amplitude = 1.0;
    amplitude = 0.0001*rint(10000.0*amplitude);
    needsSetDerivedParams = YES;
    return amplitude;
}


- (int)setPeriod:(int)thePeriod
{
    double phase = ((double)(time%period))/period;
    
    period = thePeriod;
    if (period < 2) period = 2;
    time = (int)(phase*period + 0.5);	/* Maintain phase by shifting time */
    needsSetDerivedParams = YES;
    return period;
}


- (double)setAsymmetry:(double)theAsymmetry
{
    asymmetry = theAsymmetry;
    if (asymmetry < -1.0) asymmetry = -1.0;
    if (asymmetry > 1.0) asymmetry = 1.0;
    asymmetry = 0.001*rint(1000.0*asymmetry);
    needsSetDerivedParams = YES;
    return asymmetry;
}


- (double)setShocksize:(double)theShocksize
{
    shocksize = theShocksize;
    if (shocksize < -1.0) shocksize = -1.0;
    if (shocksize > 2.0) shocksize = 2.0;
    shocksize = 0.001*rint(1000.0*shocksize);
    needsSetDerivedParams = YES;
    return shocksize;
}


- (int)setShocktime:(int)theShocktime;
{
    shocktime = theShocktime;
    if (shocktime < 0) shocktime = 0;
    needsSetDerivedParams = YES;
    return shocktime;
}


- setDerivedParams
/*
 * Sets various parameters derived from the externally-settable ones.  This
 * is called lazily, when a parameter is needed and the needsSetDerivedParams
 * flag is set.
 */
{
    upprob = (1.0+asymmetry)/2.0;
    marktime = period*upprob;
    spacetime = period - marktime;
    deviation = baseline*amplitude;
// We round rho slightly for analytic ease
    rho = exp(-1.0/((double)period));
    rho = 0.0001*rint(10000.0*rho);	
    gauss = deviation*sqrt(1.0-rho*rho);
    shockdecay = shocktime==0? 0.0: exp(-1.0/((double)shocktime));
    if (debug&DEBUGDIVIDEND && !quiet) {
	Message("#d: deviation: %f  upprob: %f  mark/spacetime: %d/%d",
	    deviation, upprob, marktime, spacetime);		
	Message("#d: rho: %f  gauss: %f  shockdecay: %f",
	    rho, gauss, shockdecay);
    }
    needsSetDerivedParams = NO;
    return self;
}


// -------------- Accessor methods for parameters -----------------------

- (DivType)divType { return divtype; }

- (int)period { return period; }

- (int)shocktime { return shocktime; }

- (double)baseline { return baseline; }

- (double)amplitude { return amplitude; }

- (double)asymmetry { return asymmetry; }

- (double)shocksize { return shocksize; }


// --------- Methods to compute/provide derived quantities -----------

- (double)mean
{
    double meandiv;
    
    if (needsSetDerivedParams)
	[self setDerivedParams];

// Theoretical mean for each process.  Not corrected for discreteness,
// shocks, or clipping.  There should be code here for all DivType values.
    switch (divtype) {
    case DIV_AR1:
    case DIV_WHITE:
    case DIV_TRIANGLE:
    case DIV_SINE:
	meandiv = baseline;
	break;
    case DIV_MARKOV:
    case DIV_IID:
    case DIV_SQUARE:
	meandiv = baseline + asymmetry*deviation;
	break;
    }
    return meandiv;
}


- (double)sd
{
    double stddiv;
    
    if (needsSetDerivedParams)
	[self setDerivedParams];

// Theoretical standard deviation for each process.  Not corrected for
// discreteness, shocks, or clipping.  There should be code here for all
// DivType values.
    switch (divtype) {
    case DIV_AR1:
    case DIV_WHITE:
	stddiv = deviation;
	break;
    case DIV_MARKOV:
    case DIV_IID:
    case DIV_SQUARE:
	stddiv = deviation*sqrt(1.0-asymmetry*asymmetry);
	break;
    case DIV_TRIANGLE:
	stddiv = deviation/sqrt(3.0);
	break;
    case DIV_SINE:
	stddiv = deviation/sqrt(2.0);
	break;
    }
    return stddiv;
}


- (double)rho
{
    if (needsSetDerivedParams) [self setDerivedParams];

    if (divtype == DIV_AR1)
	return rho;
    else
	return 0.0;
}


- (const char *)addnlInfo
/*
 * This method returns a string of additional information for the log
 * file and for display by the dividend inspector.
 */
{
    static char buf[30];

    switch (divtype) {
    case DIV_AR1:
	if (needsSetDerivedParams) [self setDerivedParams];
	sprintf(buf,"rho: %6.4f    gauss: %6.4f", rho, gauss);
	break;
    case DIV_WHITE:
	if (needsSetDerivedParams) [self setDerivedParams];
	sprintf(buf,"upprob: %6.4f", upprob);
	break;
    case DIV_MARKOV:
    case DIV_SQUARE:
    case DIV_TRIANGLE:
    case DIV_SINE:
	if (needsSetDerivedParams) [self setDerivedParams];
	sprintf(buf,"mark/spacetime: %d/%d", marktime, spacetime);
	break;
     case DIV_IID:
	buf[0] = '\0';	// Nothing to show
	break;
    }
    return buf;
}


// ----------------- Method to calculate the next point ----------------

- (double)dividend
/*
 * Compute dividend for the current period.
 * Assumes that one period passes between each call; note that "time"
 * may not be the same as the global variable "t" because shifts are
 * introduced to maintain phase when certain parameters are changed.
 */
{
    int treduced;
    double temp;

    ++time;

    if (needsSetDerivedParams)
	[self setDerivedParams];

// Main switch on type of dividend process.  There should be code here for
// all DivType values. 
    switch (divtype) {

/* AR(1) process (colored noise) */
    case DIV_AR1:
	dvdnd = baseline + rho*(dvdnd - baseline) + gauss*normal();
	break;

/* Markovian two-state process */
    case DIV_MARKOV:
	if (dvdnd >= baseline) {
	    if (drand()*marktime < 1.0)
		dvdnd = baseline - deviation;
	    else
		dvdnd = baseline + deviation;
	}
	else {
	    if (drand()*spacetime < 1.0)
		dvdnd = baseline + deviation;
	    else
		dvdnd = baseline - deviation;
	}
	break;

/* Gaussian white noise */
    case DIV_WHITE:
	dvdnd = baseline + deviation*normal();
	break;

/* Bernouilli coin-flip */ 
    case DIV_IID:
	if( drand() < upprob)
	    dvdnd = baseline + deviation;
	else
	    dvdnd = baseline - deviation;
	break;

/* Periodic square wave */
    case DIV_SQUARE:
	if (time%period < marktime)
	    dvdnd = baseline + deviation;
	else
	    dvdnd = baseline - deviation;
	break;

/* Periodic trinagular wave (up/down ramps) */
    case DIV_TRIANGLE:
	treduced = time%period;
	if (treduced < marktime)
	    dvdnd = baseline + deviation*
			    (2.0*treduced/marktime - 1.0);
	else
	    dvdnd = baseline + deviation*
			    (2.0*(period - treduced)/spacetime - 1.0);
	break;

/* Periodic sinusoidal wave */
    case DIV_SINE:
	treduced = time%period;
	if (treduced < marktime)
	    dvdnd = baseline - deviation*
			    cos(PI*treduced/marktime);
	else
	    dvdnd = baseline - deviation*
			    cos(PI*(treduced - period)/spacetime);
	break;
    }
    
    temp = dvdnd + shock;
    if (temp < mindividend) temp = mindividend;
    if (temp > maxdividend) temp = maxdividend;
    
    shock = shockdecay*shock;

    return temp;
}


// --------------------- Methods to add/reset shocks --------------------

- addShock
/*
 * Add on dividend shock.  The shock has a sudden onset, then decays
 * exponentially with relaxation time "shocktime".
 */
{
    shock += baseline*shocksize;
    return self;
}


- resetShock
{
    shock = 0.0;
    return self;
}


// --------------------- Methods to give names for codes --------------------

- (const char *)divParamNameFor:(DparamType)paramtype
/*
 * Returns the name for a parameter type.
 */
{
    return findkeyword((int)paramtype, dparamkeys, "dividend parameter type");
}


- (const char *)divTypeNameFor:(DivType)type
{
    return findkeyword((int)type, dtypekeys, "dividend type");
}

@end

