// The Santa Fe Stock Market -- Implementation of Agent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This is the abstract superclass of all agent classes; all agent classes
// are direct or indirect descendants of this one.

// Agents must respond to all the following messages, but default
// behavior may be inherited from this class (Agent) for all except
// +initClass:, +createType:from:, and -getDemandAndSlope:forPrice:.
//
// CLASS METHODS FOR INITIALIZATION
//
// + setnumtypes:(int)ntypes
//	Tells Agent the number of types so that the paramslist[] array
//	can be set up.
//
// + makebittables:(int)nbits
//	Constructs global bit-packing tables for use by agents with up to
//	nbits condition bits.  Called during type initialization for each
//	type that uses condition bits.
//
// CLASS METHODS FOR OVERRIDING BY SUBCLASSES
//
// These messages are often sent for each agent class used, so abstract
// superclasses (like Agent and Forecaster) may receive them several
// times if the lower level classes don't override them.  Such
// abstract superclasses should not be using them though.
//
// + initClass:(int)theclass
//	Initializes the class object.  "theclass" is an index into the
//	aclass array maintained by agentManager for this agent class.
//	There is no default for this method in the Agent class; the agent
//	subclasses MUST provide it.
//
// + createType:(int)thetype from:(char *)filename
//	Sent for each type of this class, so that the class object
//	can read the appropriate parameter file and store the parameters
//	(and any derived quantities) in malloc'd space.  It must also set
//	the appropriate paramslist[] entry.  There is no default for this
//	method in the Agent class; the agent subclasses MUST provide it.
//
// + writeParamsToFile:(FILE *)fp forType:(int)thetype
//	Asks the agent class object to write any private parameters for type
//	"type" to file "fp".
//
// + didInitialize
//	Tells the agent class object that initialization (including creation
//	of agents) is finished.
//
// + prepareTypeForTrading:(int)thetype
//	Sent for each type of this class, announcing the start of a new
//	trading period.  The class object can use this to set up any common
//	information for use by getDemandandSlope:forPrice: etc.  These class
//	messages are follwed by -prepareForTrading messages to each
//	enabled instance.
//
// + (int)lastgatimeForType:(int)type
//	Returns the most recent time at which a GA ran for any agent of
//	type "type".  Classes that don't use a genetic algorithm return
//	MININTGR.  This may be used to see if the bit distribution might have
//	changed, since a change can only occur through a genetic algorithm.
//
// + (int)nrulesForType:(int)type
//	Returns the number of rules or forecasters used by agents of type
//	"type", or 0 if rules/forecasters aren't used.
//
// + (int)nbitsForType:(int)type
//	Returns the number of condition bits used by agents of type
//	"type", or 0 if condition bits aren't used.  Includes any null
//	bits in the count.
//
// + (int)nonnullBitsForType:(int)type
//	Returns the number of condition bits used by agents of type
//	"type", or 0 if condition bits aren't used.  Excludes any null
//	bits from the count.
//
// + (int)agentBitForWorldBit:(int)bit forType:(int)type
//	Returns the type's condition bit number for world bit n, or -1
//	if that world bit is not used by the type.
//
// + (int)worldBitForAgentBit:(int)bit forType:(int)type
//	Returns the world bit number for the type's condition bit number
//	"bit", or NULLBIT for a null bit or for agents without condition bits.
//
// + printDetails:(const char *)string to:(FILE *)fp forClass:(int)class
//	Asks the class to write some information, specified by "string", to
//	the file specified by "fp".  This depends on the particular agent
//	class -- the default method provided by Agent doesn't write anything
//	useful.  "class" is the class index.
//
// + printDetails:(const char *)string to:(FILE *)fp forType:(int)type
//	Asks the class to write some information, specified by "string", about
//	one type, to the file specified by "fp".  This depends on the
//	particular agent class -- the default method provided by Agent
//	doesn't write anything useful.  "type" is the type index.
//
// + (int)outputInt:(int)n forClass:(int)class
//
// + (double)outputReal:(int)n forClass:(int)class
//
// + (const char *)outputString:(int)n forClass:(int)class
//
// + (int)outputInt:(int)n forType:(int)type
//
// + (double)outputReal:(int)n forType:(int)type
//
// + (const char *)outputString:(int)n forType:(int)type
//
// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN
//
// - (char *)shortname
//	Returns a short name (e.g. "BS-wej") for this agent.  Each
//	call overwrites the previous value.
//
// - (char *)fullname;
//	Returns a full name (e.g. "BS2-abc-def-ghi") for this agent.  The
//	first 2-3 characters are the typename and the next is either '-', or
//	':' if ancestors have been omitted.  Each call overwrites the
//	previous one.
//
// - creditEarningsAndPayTaxes
//	Sent to each enabled agent after a dividend is declared.  The
//	agents receive the dividend for each unit of stock they hold.
//	Their "cash" in the fixed asset account also receives its
//	interest.  Then taxes are charged on the previous total wealth,
//	at a rate that balances the interest on cash -- so if the agent
//	had everything in cash it would end up at the same place.
//
// - (double)constrainDemand:(double *)slope :(double)trialprice
//	Checks "demand" against the mincash and minholding constraints
//	and clips it if necessary, then also setting *slope.  For use
//	within subclass implementations of getDemandAndSlope:forPrice:.
//
// - (int *(*)[4])bitDistribution;
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of this agent's
//	condition bits, summed over all rules/forecasters.  Agents that
//	don't use condition bits return NULL.  This uses the method
//	-bitDistribution:cumulative: described below that is provided by
//	subclasses that have condition bits.  Each call overwrites the last.
//
// PUBLIC INSTANCE METHODS, OFTEN OVERRIDDEN BY SUBCLASSES
//
// - initAgent:(int)thetag type:(int)thetype
//	Initializes the agent, right after "alloc" (used instead of -init).
//	"thetag" is saved in the tag instance variable, which is an index into
//	the AgentManager's alist[] table.  "thetype" gives the type, which
//	provides access to the appropriate parameters in paramslist[thetype].
//	Subclasses of Agent can override this method, but should then call
//	[super initAgent:thetag type:thetype] before anything else.
//
// - check
//	Can be used to do any sort of debugging check on an agent.  Called
//	only if the -da (or -dA) agent-debugging option is used.  The default
//	method provided by Agent does nothing.
//
// - prepareForTrading
//	Sent to each enabled agent at the start of each trading period,
//	before the first -getDemandAndSlope:forPrice: message for that
//	agent.  The class method +prepareTypeForTrading: is sent to each
//	type before any of these messages.
//
// - (double)getDemandandSlope:(double *)slope forPrice:(double)p
//	Sent to each enabled agent during bidding to ask for its bid
//	(demand > 0) or offer (demand < 0) at price p.  The agent may
//	also return a value for d(demand)/d(price) through "slope", but
//	this is not required; *slope may be left unchanged.  This method
//	may be called one or more times in each period, depending on the
//	specialist method.  The last such call is at the final trading
//	price.  The -prepareForTrading message is sent to each enabled agent
//	before the first such call in each period.  There is no default for
//	this method in the Agent class; the agent subclasses MUST provide it.
//
// - updatePerformance
//	Sent to each enabled agent at the end of each period to tell it to
//	update its performance meaures, forecasts, etc.
//
// - setEnabled:(BOOL)flag
//	Sent to an agent to enable/disable it; "flag" gives the new status.
//	The Agent class itself does the actual enabling/disabling, but some
//	subclasses may want to take additional actions after calling
//	[super setEnabled:flag].
//
// - (int (*)[4])countBit:(int)n cumulative:(BOOL)cum
//	Returns a pointer to an array of 4 integers giving the numbers of
//	00's, 01's, 10's, and 11's for this agent's condition bit n, among
//	all rules/forecasters.  Agents that don't use condition bits return
//	a pointer to 4 0's.  Each call overwrites the last.  If cum is YES,
//	adds the new counts to whatever was in the array already, allowing
//	accumulation over a number of agents or bits by using NO for the
//	first and then YES (but only within the same type).
//
// - (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
//	Places in (*countptr)[0], ..., (*countptr)[3] the addresses of 4
//	arrays, (*countptr)[0][i], ..., (*countptr)[3][i], which are filled
//	with the number of bits that are 00, 01, 10, or 11 respectively,
//	for each condition bit i= 0, 1, ..., nbits-1, summed over all rules
//	or forecasters.  Returns nbits, the number of condition bits.  If
//	cum is YES, adds the new counts to whatever is in the (*coutptr)
//	arrays already.  Agents that don't use condition bits return -1.
//	The 4-element array (*countptr)[4] must already exist, but the
//	arrays to which its element point are supplied dynamically.  This
//	method must be provided by each subclass that has condition bits.
//
// - printDetails:(const char *)detailtype to:(FILE *)fp
//	Prints some information about this agent to file 'fp'.  Different
//	agent classes may use this differently.  The "detailtype" string is
//	derived from the "details(detailtype)" specification in an output
//	stream description, and may be used to specify different types of
//	information to be printed.
//
// - (int)outputInt:(int)n
//
// - (double)outputReal:(int)n
//
// - (const char *)outputString:(int)n
//
// INSTANCE METHODS THAT MAY NEED OVERRIDING FROM Object
//
// - free
//	Free the agent.  The Agent class simply uses Object's -free method,
//	but subclasses that allocate any additional memory must implement
//	this to deallocate the memory, and then use [super free].
//
// - copy
//	Copy the agent.  The Agent class simply uses Object's -copy method,
//	but subclasses that allocate any additional memory must implement
//	this to allocate and copy that memory.  They should begin by using
//	[super copy].  This method must do everything necessary to
//	create a functional agent; note that initAgent: is NOT called as
//	well when an agent is cloned.
//
// GLOBAL VARIABLES USED
//
// id agentManager
//	AgentManager object to which this sends messages.
//
// double price, dividend
//	Market variables from World.
//
// double intrate, mincash, initialcash, minholding
//	Market constants from Specialist.
//
// int quiet
//	-q flag
//
// GLOBAL VARIABLES PROVIDED
//
// void **paramslist
//	Array of pointers to parameter structures, one for each type.
//
// int *SHIFT
// unsigned int *MASK, *NMASK
//	These provide tables for fast bit-packing -- se the comments in
//	+makebitarrays: below.
//
// Note that Agent's instance variables are all declared @public (see
// Agent.h), and so are also globally visible.  This favors fast simple
// access over strict encapsulation.  Agent subclasses may also use further
// @public variables for the same reason.


// IMPORTS
#include "global.h"
#include "agent.h"
#include <stdlib.h>
#include "amanager.h"
#include "util.h"
#include "error.h"

// GLOBAL VARIABLES
void **paramslist;
int *SHIFT;
unsigned int *MASK;
unsigned int *NMASK;

@implementation Agent

// CLASS METHODS FOR INITIALIZATION

+ setnumtypes:(int)ntypes
/*
 * Tells the Agent class the number of types to be allocated, so it can
 * create the paramslist[] array of pointers to parameter structures.
 */
{
    paramslist = (void **)getmem(sizeof(void *)*ntypes);
    return self;
}


+ makebittables:(int)nbits
/*
 * Construct tables for fast bit packing and condition checking for
 * classifier systems.  Sets up the global tables SHIFT[], MASK[], and
 * NMASK[] to cover "nbits" condition bits.
 *
 * Assumes 32 bit words, and storage of 16 ternary values (0, 1, or *)
 * per word, with one of the following codings:
 * Value           World coding           Rule coding
 *   0			2			1
 *   1			1			2
 *   *			-			0
 * Thus rule satisfaction can be checked with a simple AND between
 * the two types of codings.
 *
 * Sets up the tables to store maxbits ternary values in
 * maxwords = ceiling(maxbits/16) words.
 *
 * After calling this routine, given an array declared as
 *		int array[maxwords];
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
 *	for (i=0; i<maxwords; i++)
 *	    if (condition[i] & array[i]) break;
 *	if (i != maxwords) ...
 *
 */
{
    int bit;
    static int bitarraysize = 0;

    if (nbits > bitarraysize) {
	if (bitarraysize > 0) {
	    free((void *)MASK);
	    free((void *)SHIFT);
	}
	SHIFT = (int *)getmem(sizeof(int)*nbits);
	MASK = (unsigned int *)getmem(sizeof(unsigned int)*nbits*2);
	NMASK = MASK + nbits;
	bitarraysize = nbits;
	for (bit=0; bit < nbits; bit++) {
	    SHIFT[bit] = (bit%16)*2;
	    MASK[bit] = 3 << SHIFT[bit];
	    NMASK[bit] = ~MASK[bit];
	}
    }
    return self;
}


// CLASS METHODS, FOR OVERRIDING BY SUBCLASSES

+ initClass:(int)theclass
{
    [self subclassResponsibility:_cmd];
    return self;
}


+ createType:(int)thetype from:(const char *)filename
{
    [self subclassResponsibility:_cmd];
    return self;
}


+ writeParamsToFile:(FILE *)fp forType:(int)thetype;
{
    fprintf(fp,"    <no parameters for type %s>\n",
				    [agentManager typenameForType:thetype]);
    return self;
}


+ didInitialize
{
    return self;	// default code does nothing
}


+ prepareTypeForTrading:(int)thetype
{
    return self;	// default code does nothing
}


+ (int)lastgatimeForType:(int)thetype
{
    return MININTGR;	// default for agents without GAs
}


+ (int)nrulesForType:(int)thetype
{
    return 0;		// default for agents without rules/forecasters
}


+ (int)nbitsForType:(int)thetype
{
    return 0;		// default for agents without condition bits
}


+ (int)nonnullBitsForType:(int)thetype
{
    return 0;		// default for agents without condition bits
}


+ (int)agentBitForWorldBit:(int)bit forType:(int)thetype
{
    return -1;		// default for agents without condition bits
}


+ (int)worldBitForAgentBit:(int)bit forType:(int)thetype
{
    return NULLBIT;	// default for agents without condition bits
}


+ printDetails:(const char *)string to:(FILE *)fp forClass:(int)class
{
    fprintf(fp, "-- class %s can't print details(%s) --\n",
			    [agentManager shortnameForClass:class], string);
    return self;
}


+ printDetails:(const char *)string to:(FILE *)fp forType:(int)thetype
{
    fprintf(fp, "-- type %s can't print details(%s) --\n",
			    [agentManager typenameForType:thetype], string);
    return self;
}


+ (int)outputInt:(int)n forClass:(int)class
{
    return 0;
}


+ (double)outputReal:(int)n forClass:(int)class
{
    return 0.0;
}


+ (const char *)outputString:(int)n forClass:(int)class
{
    return "?";
}


+ (int)outputInt:(int)n forType:(int)thetype
{
    return 0;
}


+ (double)outputReal:(int)n forType:(int)thetype
{
    return 0.0;
}


+ (const char *)outputString:(int)n forType:(int)thetype
{
    return "?";
}


// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN

- init
/*
 * Dummy to catch misuse -- must call designated initializer.
 */
{
    [self error:"-init message invalid; requires -initAgent:type:"];
    return nil;		// not reached
}


- (const char *) shortname
/*
 * Returns a pointer to a short agent name, like "BS:wej".  Each call
 * overwrites the last.
 */
{
    return [agentManager shortnameOf:tag];
}


- (const char *)fullname
/*
 * Returns a pointer to a full agent name, like "BS2-abc-def-ghi".   The
 * first 2-3 characters are the typename and the next is either '-', or
 * ':' if ancestors have been omitted.  Each call overwrites the
 * previous one.
 */
{
    return [agentManager fullnameOf:tag];
}


- creditEarningsAndPayTaxes
/*
 * This is done in each period after the new dividend is declared.  It is
 * not normally overridden by subclases.  The taxes are assessed on the
 * previous wealth at a rate so that there's no net effect on an agent
 * with position = 0.
 *
 * In principle we do:
 *	wealth = cash + price*position;			// previous wealth
 *	cash += intrate*cash + position*dividend;	// earnings
 *	cash -= wealth*intrate;				// taxes
 * but we cut directly to the cash:
 *	cash -= (price*intrate - dividend)*position
 */
{
// Update cash
    cash -= (price*intrate - dividend)*position;
    if (cash < mincash) cash = mincash;

// Update wealth
    wealth = cash + price*position;
    return self;
}


- (double)constrainDemand:(double *)slope :(double)trialprice
/*
 * Method used by agents to constrain their demand according to the
 * mincash and minholding constraints.
 */
{
// If buying, we check to see if we're within borrowing limits,
// remembering to handle the problem of negative dividends  -
// cash might already be less than the min.  In that case we
// freeze the trader.
    if (demand > 0.0) {
	if (demand*trialprice > (cash - mincash)) {
	    if (cash - mincash > 0.0) {
		demand = (cash - mincash)/trialprice;
		*slope = -demand/trialprice;
	    }
	    else {
		demand = 0.0;
		*slope = 0.0;
	    }
	}
    }

// If selling, we check to make sure we have enough stock to sell, and
// that we're not selling short if cash < 0.
    else if (demand < 0.0) {
	if (demand + position < minholding) {
	    demand = minholding - position;
	    *slope = 0.0;
	}
	if (demand + position < 0.0 && cash < 0.0) {
	    demand = 0.0;
	    *slope = 0.0;
	}
    }

    return demand;
}


- (int *(*)[4])bitDistribution
{
    static int *count[4];

    if ([self bitDistribution:&count cumulative:NO] < 0)
	return NULL;
    else
	return &count;
}


// PUBLIC INSTANCE METHODS, OFTEN OVERRIDDEN BY SUBCLASSES

- initAgent:(int)thetag type:(int)thetype
/*
 * Designated initializer.  Most agent classes will have additional
 * initialization, but should do [super initAgent:thetag type:thetype] to
 * run this first.
 */
{

// Initialize instance variables common to all agents
    demand = 0.0;
    profit = 0.0;
    wealth = 0.0;
    position = 0.0;
    cash = initialcash;
    next = NULL;		// Set later by AgentManager
    nameidx = 0;		// Set later by AgentManager
    tag = thetag;
    lastgatime = MININTGR;	// Never changes if no GA
    gacount = 0;		// Never changes if no GA
    type = thetype;
    enabled = YES;
    selected = NO;

    return self;
}


- check
/*
 * Subclasses should also do this, via [super check].
 */
{
    if (!quiet)
	message("#a:%3d %s h=%-9.5f c=%-10.4g w=%-10.4g",
			    tag, [self fullname], position, cash, wealth);
    return self;
}


- prepareForTrading
{
    return self;	// default code does nothing
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)p
{
    [self subclassResponsibility:_cmd];
    return 0.0;		// not reached
}


- updatePerformance
{
    return self;	// default code does nothing
}


- setEnabled:(BOOL)flag
{
    enabled = flag;
    return self;
}


- (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum
{
    static int zeroes[4] = {0,0,0,0};
    return &zeroes;	// default for agents without condition bits
}


- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
{
    return -1;		// default for agents without condition bits
}


- printDetails:(const char *)detailtype to:(FILE *)fp
{
    fprintf(fp, "-- agent %s can't print details(%s) --\n",
						[self fullname], detailtype);
    return self;
}


- (int)outputInt:(int)n
{
    return 0;
}


- (double)outputReal:(int)n
{
    return 0.0;
}


- (const char *)outputString:(int)n
{
    return "?";
}

@end

