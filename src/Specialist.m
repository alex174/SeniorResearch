// The Santa Fe Stockmarket -- Implementation of Specialist class

// One instance of this class is used to manage the trading and
// set the stock price.  It also manages the market-level parameters
// read from the mparams file.

// PUBLIC METHODS
//
// - initFromFile:(const char *)paramfile
//	Initializes the instance, reading parameters from the specified
//	market parameters file.
//
// - writeParamsToFile:(FILE *)fp
//	Writes the current values of the parameters to a file (or msgfile
//	if fp==NULL, for use in gdb).  The parameters are written in
//	exactly the format expected by "-initFromFile:".
//
// - (double)performTrading
//	This is the core method that sets a succession of trial prices
//	and asks the agents for their bids or offer at each, generally
//	adjusting the price towards reducing |bids - offers|.
//
// - completeTrades
//	Updates the agents cash and position to consummate the trades
//	previously negotiated in -performTrading, with rationing if
//	necessary.
//
// - setParamFromString:(const char *)string
//	Sets one of the parameters for a scheduled "specialist" event with
//	parameter string "string".
//
// - setEta:(double)eta
//	Resets the value of eta.  For scheduled events.
//
// - setEtaIncrement:(double)etaIncrement
//	Resets the value of etaincrement.  For scheduled events.
//
// - (double)eta
//	Returns the value of eta.  For front end.
//
// - (double)etaIncrement
//	Returns the eta increment value.  For front end.
//
// - setSpecialistType:(SpecialistType)stype
//	Resets the type of specialist.  For scheduled events.
//
// - (SpecialistType)specialistType
//	Returns the type of specialist.  For front end.
//
// - (const char *)specialistTypeNameFor:(SpecialistType)type
//	Returns the name of the specialist type "type".

// GLOBAL VARIABLES NEEDED
//
// id agentManager, world, marektApp
//	Objects to which this object sends messages.
//
// double price, dividend, profitperunit
//	Global market variables in World.
//
// FILE *msgfile
//	Output file pointer for error messages etc.

// GLOBAL VARIABLES SUPPLIED
//
// double bidtotal, offertotal, volume
//	The most recent total number of bids and offers, and the trading
//	volume, which is the smaller of bidtotal and offertotal.
//
// double oldbidtotal, oldoffertotal, oldvolume
//	The previous values of the above variables (from one period ago).
//
// Note that the following are really general market constants, not
// directly related to the specialist's trading function.  But the
// specialist also manages them (reading them from the market parameter
// file) for convenience.  It would be easy to separate out this
// function if desired.
//
// double intrate, intratep1
//	The interest rate (r), and r+1.
//
// double minholding
//	The minimum position allowed for each agent.  This may be zero or
//	negative; a negative value allows selling short.  The constraint
//	is applied in Agent's -constrainDemand:: method.
//
// double mincash
//	The minimum allowed cash for each agent.  This may be zero or
//	negative; a negative value allows borrowing.  The constraint
//	is applied in Agent's -constrainDemand:: method.
//
// double initialcash
//	The initial value of "cash" for new agents.
//
// BOOL exponentialMAs
//	Whether the moving averages of price and dividend in World.m are
//	calculated with exponential (YES) or uniform (NO) weighting.

// IMPORTS
#import "global.h"
#import "Specialist.h"
#import <ctype.h>
#import "AgentManager.h"
#import "Agent.h"
#import "Protocols.h"
#import "World.h"
#import "error.h"
#import "util.h"
#import "math.h"

// ------ Global variables defined in this file -------
// These may be read anywhere, but are only changed by this object.
// They could be made into instance variables with accessor methods.

// Global variables from the Specialist itself 
double bidtotal;
double offertotal;
double volume;
double oldbidtotal;
double oldoffertotal;
double oldvolume;

// Global constants managed by the Specialist
double intrate;
double intratep1;
double minholding;
double mincash;
double initialcash;
BOOL exponentialMAs;

// ------ Local variables -------
static double taup;
static double taupdecay;
static double taupnew;
static double taulpv;
static double taulpvdecay;
static double taulpvnew;

// Table of keywords for specialist types.  These give the keywords to use
// in the parameter file.  To add a new type you need to (1) add to the
// SpecialistType enum definition in the .h file; (2) add to this table;
// (3) add desired code to all branches on sptypesin this file; (4) add
// popup item to main stockmarket window and set tag; (5) add comment
// to default "mparams" file.
struct keytable stypekeys[] = {
    {"fixed", SP_ETA},
    {"adaptive", SP_ADAPTIVEETA},
    {"re", SP_RE},
    {"vcvar", SP_VCVAR},
    {"slope", SP_SLOPE},
    {NULL, -1}
};

// Codes and table of keywords for scheduled parameter setting using
// EV_SET_SPECIALIST_PARAM events.
typedef enum {
	SPARAM_UNKNOWN=0,
	SPARAM_SPTYPE,
	SPARAM_ETA,
	SPARAM_ETAINC
} SparamType;
struct keytable sparamkeys[] = {
    {"sptype", SPARAM_SPTYPE},
    {"eta", SPARAM_ETA},
    {"etaincrement", SPARAM_ETAINC},
    {NULL, SPARAM_UNKNOWN}
};

// Keywords for moving average type
struct keytable matypekeys[] = {
    {"uniform", 0},
    {"exponential", 1},
    {NULL, -1}
};


@implementation Specialist

-initFromFile:(const char *)paramfile
{
    int i;

/* Read in parameters from paramfile */
    (void) OpenInputFile(paramfile, "market parameters");

    intrate = ReadDouble("intrate",0.0,0.5);
    initialcash = ReadDouble("initialcash",0,1e7);
    maxprice = ReadDouble("maxprice",1.0,99999.9);
    minprice = ReadDouble("minprice",0.0,100.0);
    taup = ReadDouble("taup",1.0,100000.0);
    minholding = ReadDouble("minholding",-100000.0,0.0);
    mincash    = ReadDouble("mincash",-1e20,10000.0);
    exponentialMAs = (ReadKeyword("matype", matypekeys) > 0);

    i = ReadKeyword("sptype",stypekeys);
    sptype = (i>=0?(SpecialistType)i:SP_ETA);
    maxiterations = ReadInt("maxiterations",1,MAXINT);
    minexcess = ReadDouble("minexcess",0.0,1000.0);
    eta = ReadDouble("eta",0.0,5.0);
    etaincrement = ReadDouble("etaincrement",0.0,1.0);
    etamax = ReadDouble("etamax",0.0,5.0);
    etamin = ReadDouble("etamin",0.0,1.0);
    rea = ReadDouble("rea",0.0,1000.0);
    reb = ReadDouble("reb",-1000.0,1000.0);
    taulpv = ReadDouble("taulpv",1.0,100000.0);
    ldelpmax = ReadDouble("ldelpmax",0.0,100.0);
    abandonIfError("[Specialist initFromFile:]");

/* construct constants and initial values */
    intratep1 = intrate + 1.0;
    bidtotal = 0.0;
    offertotal = 0.0;
    volume = 0.0;
    oldbidtotal = 0;
    oldoffertotal = 0;
    oldvolume = 0.0;
    var = 0.0;
    cvar = 0.0;
    varcount = 0;
    taulpvnew = -expm1(-1.0/taulpv);
    taulpvdecay = 1.0 - taulpvnew;
    taupnew = -expm1(-1.0/taup);
    taupdecay = 1.0 - taupnew;

    return self;
}


- writeParamsToFile: (FILE *)fp
{
    if (fp == NULL) fp = stderr;	// For use in debugging with gdb

    showdble(fp, "intrate", intrate);
    showdble(fp, "initialcash", initialcash);
    showdble(fp, "maxprice", maxprice);
    showdble(fp, "minprice", minprice);
    showdble(fp, "taup", taup);
    showdble(fp, "minholding", minholding);
    showdble(fp, "mincash", mincash);
    showstrng(fp, "matype",
		findkeyword((exponentialMAs? 1: 0), matypekeys, "ma type"));
    showstrng(fp, "-- specialist parameters --", "");
    showstrng(fp, "sptype", [self specialistTypeNameFor:sptype]);
    showint(fp, "maxiterations", maxiterations);
    showdble(fp, "minexcess", minexcess);
    showdble(fp, "eta", eta);
    showdble(fp, "etaincrement", etaincrement);
    showdble(fp, "etamax", etamax);
    showdble(fp, "etamin", etamin);
    showdble(fp, "rea", rea);
    showdble(fp, "reb", reb);
    showdble(fp, "taulpv", taulpv);
    showdble(fp, "ldelpmax", ldelpmax);

// Compute derived parameters
    etainitial = eta;

    return self;
}


- (double)performTrading
/*
 * Performs the trading, getting bids and offers from the agents and
 * adjusting the price.  Returns the final trading price, which becomes
 * the next market price.  Various methods are implemented, but all
 * have the structure:
 *  1. Set a trial price
 *  2. Send each agent a -getDemandAndSlope:forPrice: message and
 *     accumulate the total number of bids and offers at that price.
 *  3. [In some cases] go to 1.
 *  4. Return the last trial price.
 */
{
    int i, mcount;
    BOOL done;
    double demand, slope, ldelp, imbalance;
    double slopetotal = 0.0;
    double trialprice = 0.0;

// Get list of enabled agents
    idlist = [agentManager enabledAgents:&nenabled];

// Save previous values
    oldbidtotal = bidtotal;
    oldoffertotal = offertotal;
    oldvolume = volume;


// Main loop on {set price, get demand}
    for (mcount = 0, done = NO; mcount < maxiterations && !done; mcount++) {

    // Set trial price -- various methods
	switch (sptype) {

	case SP_RE:
	// Rational expectations benchmark:  The rea and reb parameters must
	// be calculated by hand (highly dependent on agent and dividend).
	    trialprice = rea*dividend + reb;
	    done = YES;		// One pass
	    break;

	case SP_ADAPTIVEETA:
	    if (mcount == 0)
		trialprice = price;
	    else {
	    // Adjust eta if:
	    // (a) price moved in same direction for the last 5 periods; and
	    // (b) there were both bids and offers
		if (bidtotal && offertotal && [world pricetrend:5] != 0) {
		    eta += etaincrement;
		    if (eta > etamax) eta = etamax;
		}
		else {
		    eta -= etaincrement;
		    if (eta < etamin) eta = etamin;
		}
		trialprice = price*(1.0 + eta*(bidtotal-offertotal));
		done = YES;	// Two passes
	    }
	    break;

	case SP_ETA:
	    if (mcount == 0)
		trialprice = price;
	    else {
		trialprice = price*(1.0 + eta*(bidtotal-offertotal));
		done = YES;	// Two passes
	    }
	    break;

	case SP_VCVAR:
	    if (mcount == 0)
		trialprice = price;
	    else {
	    // Adjust eta based on smoothed variance/covariance ratio
		if (varcount < taulpv)
		    eta = etainitial;
		else if (cvar != 0.0) {
		    eta = -var/cvar;
		    if (eta > etamax) eta = etamax;
		    else if (eta < etamin) eta = etamin;
		}
		else
		    eta = etamax;
		trialprice = price*(1.0 + eta*(bidtotal-offertotal));
		done = YES;	// Two passes
	    }
	    break;

	case SP_SLOPE:
	    if (mcount == 0)
		trialprice = price;
	    else {
	    // Use demand and slope information from the agent to set a new
	    // price where the market should clear if the slopes are all
	    // present and correct.  Iterate until it's close or until
	    // maxiterations is reached.
	    imbalance = bidtotal - offertotal;
	    if (imbalance <= minexcess && imbalance >= -minexcess) {
		done = YES;
		continue;
	    }
	    // Update price using demand curve slope information
	    if (slopetotal != 0)
		trialprice -= imbalance/slopetotal;
	    else
		trialprice *= 1 + eta*imbalance;
	    }
	    break;
	}

    // Clip trial price
	if (trialprice < minprice) trialprice = minprice;
	if (trialprice > maxprice) trialprice = maxprice;

    // Get each agent's requests and sum up bids, offers, and slopes
	bidtotal = 0.0;
	offertotal = 0.0;
	slopetotal = 0.0;
	for (i = 0; i < nenabled; i++) {
	    slope = 0.0;
	    demand = [idlist[i] getDemandAndSlope: &slope forPrice:trialprice];
	    slopetotal += slope;
	    if (demand > 0.0)      bidtotal += demand;
	    else if (demand < 0.0) offertotal -= demand;
	}

    // Match up the bids and offers
	volume = (bidtotal > offertotal ? offertotal : bidtotal);
	bidfrac = (bidtotal > 0.0 ? volume / bidtotal : 0.0);
	offerfrac = (offertotal > 0.0 ? volume / offertotal : 0.0);
    }

// Update log(price) variance and log(price)/excess-demand covariance
    if (sptype == SP_VCVAR) {
	if (trialprice != price && trialprice > 0.0 && price > 0.0)
	    ldelp = log(trialprice/price);
	else
	    ldelp = 0.0;
	if (ldelp > ldelpmax) ldelp = ldelpmax;
	else if (ldelp < -ldelpmax) ldelp = -ldelpmax;
	var  = taulpvdecay*var  + taulpvnew*ldelp*ldelp;
	cvar = taulpvdecay*cvar + taulpvnew*ldelp*
			((bidtotal-offertotal)-(oldbidtotal-oldoffertotal));
	varcount++;
    }
    else
	varcount = 0;

// Return the last trial price, which will become the new market price
    return trialprice;
}


- completeTrades
/*
 * Makes the actual trades at the last trial price (which is now the
 * market price), by adjusting the agents' holdings and cash.  The
 * actual purchase/sale my be less than that requested if rationing
 * is impsed by the specialist -- usually one of "bidfrac" and
 * "offerfrac" will be less than 1.0.
 *
 * This could easiliy be done by the agents themselves, but we let
 * the specialist do it for efficiency.
 */
{
    int i;
    Agent *agid;
    double bfp, ofp, tp;

// Intermediates, for speed
    bfp = bidfrac*price;
    ofp = offerfrac*price;
    tp = taupnew*profitperunit;

// Loop over enabled agents
    for (i=0; i<nenabled; i++) {
	agid = idlist[i];

    // Update profit (moving average) using previous position
	agid->profit = taupdecay*agid->profit + tp*agid->position;

    // Make the actual trades
	if (agid->demand > 0.0) {
	    agid->position += agid->demand*bidfrac;
	    agid->cash     -= agid->demand*bfp;
	}
	else if (agid->demand < 0.0) {
	    agid->position += agid->demand*offerfrac;
	    agid->cash     -= agid->demand*ofp;
	}
    }

    return self;
}


// ------------------- Parameter setting/getting methods -------------------

- setParamFromString:(const char *)string
/*
 * Decodes a string from the timelist file specifying a change to a specialist
 * parameter.  Also tells the frontend to update its display appropriately.
 * Note that this method is only used for scheduled events.  User-initiated
 * events are handled by the frontend, which then calls the lower-level
 * methods like -setSpecialistType: and -setEta: directly.
 */
{
    const char *ptr;
    char buf[MAXSTRING];
    int c, n, stype;

    for (ptr=string, n=0; (c=*ptr)!=EOS && !isspace(c); ptr++)
	if (n < MAXSTRING-1) buf[n++] = c;
    buf[n] = EOS;
    if (c == EOS)
	[self error:"Missing value for specialist '%s' parameter",string];
    while (isspace(*ptr)) ptr++;

    switch((SparamType)lookup(buf,sparamkeys)) {
    case SPARAM_UNKNOWN:
	[self error:"Unknown specialist parameter '%s'", buf];
    case SPARAM_SPTYPE:
	stype = lookup(ptr,stypekeys);
	if (stype < 0)
	    [self error:"Unknown specialist type '%s'", ptr];
	[self setSpecialistType:(SpecialistType)stype];
	[marketApp updateSpecialistType];
	[marketApp updateEtaFields];
	break;
    case SPARAM_ETA:
	[self setEta:stringToDouble(ptr)];
	[marketApp updateEtaFields];
	break;
    case SPARAM_ETAINC:
	[self setEtaIncrement:stringToDouble(ptr)];
	[marketApp updateEtaFields];
	break;
    }
    return self;
}


- setEta:(double)aDouble
{
    eta = 1e-7*rint(1e7*aDouble);		// round to multiple of 1e-7
    return self;
}


- setEtaIncrement:(double)aDouble
{
    etaincrement = 1e-7*rint(1e7*aDouble);	// round to multiple of 1e-7
    return self;
}


- (double)eta
{
    return eta;
}


- (double)etaIncrement
{
    return etaincrement;
}


- setSpecialistType:(SpecialistType)stype
{
#ifdef DEBUG
    (void)[self specialistTypeNameFor:stype];
#endif

    sptype = stype;
    eta = etainitial;

    return self;
}


- (SpecialistType)specialistType
{
    return sptype;
}


- (const char *)specialistTypeNameFor:(SpecialistType)type
{
    return findkeyword((int)type, stypekeys, "specialist type");
}

@end
