// The Santa Fe Stockmarket -- Implementation of Agent class

// This is the abstract superclass of all agent classes; all agent classes
// are direct or indirect descendants of this one.

// Agents must respond to all the following messages, but default
// behavior may be inherited from this class (Agent) for all except
// +initClass:, +createType::, and -getDemandAndSlope:forPrice:.
//
// CLASS METHODS
//
// These messages are sent for each agent class used, so abstract
// superclasses (like Agent and Forecaster) may receive them several
// times if the lower level classes don't override them.  Such
// abstract superclasses should not be using them though.
//
// + initClass:(int)myclass
//	Initializes the class object.  "myclass" is an index into the
//	aclass array maintained by agentManager for this agent class.
//
//	There is no default for this method in the Agent class; the agent
//	subclasses MUST provide it.
//
// + (void *)createType:(int)mytype :(char *)filename
//	Sent for each type of this class, so that the class object
//	can read the appropriate parameter file and store the parameters
//	(and any derived quantities) in malloc'd space.  Returns a
//	pointer to this space.
//
//	There is no default for this method in the Agent class; the agent
//	subclasses MUST provide it.
//
// + writeParams:(void *)params ToFile:(FILE *)fp
//	Asks the agent class object to write any private parameters to "fp".
//	"params" gives  pointer to the parameter structure for this type.
//	The standard format provided by showdble() and showint() should
//	be used.
//
// + didInitialize
//	Tells the agent class object that initialization (including creation
//	of agents) is finished.
//
// + prepareForTrading:(void *)params
//	Sent for each type of this class, announcing the start of a new
//	trading period.  The class object can use this to set up any common
//	information for use by getDemandandSlope:forPrice: etc.  The
//	pointer to "params" identifies the particular type.  These class
//	messages are follwed by -prepareForTrading messages to each
//	enabled instance.
//
// + (BOOL)lastgatime:(void *)params
//	Returns the most recent time at which a GA ran for any agent of
//	this type.  "params" identifies the particular type.
//
// INSTANCE METHODS THAT MAY NEED OVERRIDING FROM Object
//
// - free
//	Free the agent.  The Agent class simply uses Object's -free method,
//	but subclasses that allocate any additional memory must implement
//	this to deallocate the memory, and then use [super free].
//
// - copyFromZone:(NXZone *)zone [NEXTSTEP]
// or
// - copy                        [gcc Objective C]
//	Copy the agent.  The Agent class simply uses Object's -copyFromZone:
//	[NEXTSTEP] or -copy [gcc] method, but subclasses that allocate any
//	additional memory must implement this to allocate and copy that
//	memory.  They should begin by using [super copyFromZone: zone]
//	or [super copy].  This method must do everything necessary to
//	create a functional agent; note that initAgent: is NOT called as
//	well when an agent is cloned.
//
// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN
//
// - setTag:(int)mytag
//	Resets the tag of this agent.  Used after copying or cloning an agent
//	for a new generation; the initial tag is set by initAgent:.
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
// - setPosition:(double)aDouble
//	Sets the agent's position (holding) to "aDouble".
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
//	subclasses that have condition bits.
//
// PUBLIC INSTANCE METHODS, OFTEN OVERRIDDEN BY SUBCLASSES
//
// - initAgent:(int)mytag
//	Initializes the agent, right after "alloc" (initAgent replaces init).
//	mytag is saved in the tag instance variable, which is an index into
//	the AgentManager's alist[] table.  Uses the parameters read by the
//	last preceding call to +createType:: -- calls to +createType:: and
//	-initAgent: must be properly interleaved.
//
//	Subclasses of Agent can override this method, but should then call
//	[super initAgent:mytag] before anything else.
//
// - check
//	Can be used to do any sort of debugging check on an agent.  Called
//	just after the agent is created and just before exit, but only if
//	the -da (or -dA) agent-debugging option is used.  The default method
//	provided by Agent does nothing.
//
// - prepareForTrading
//	Sent to each enabled agent at the start of each trading period,
//	before the first -getDemandAndSlope:forPrice: message for that
//	agent.  The class method +prepareForTrading: is sent to each type
//	before any of these messages.
//
// - (double)getDemandandSlope:(double *)slope forPrice:(double)p
//	Sent to each enabled agent during bidding to ask for its bid
//	(demand > 0) or offer (demand < 0) at price p.  The agent may
//	also return a value for d(demand)/d(price) through "slope", but
//	this is not required; *slope may be left unchanged.  This method
//	may be called one or more times in each period, depending on the
//	specialist method.  The last such call is at the final trading
//	price.  The -prepareForTrading message is sent to each enabled agent
//	before the first such call in each period.
//
//	There is no default for this method in the Agent class; the agent
//	subclasses MUST provide it.
//
// - updatePerformance
//	Sent to each enabled agent at the end of each period to tell it to
//	update its performance meaures, forecasts, etc.
//
// - enabledStatus:(BOOL)flag
//	Sent to an agent when its status changes from enabled to disabled or
//	vice-versa.  "flag" gives the new status.  The actual enabling or
//	disabling is done by the AgentManager before calling this method, but
//	some agents may want to take some additional actions.
//
// - (int)nbits
//	Returns the number of condition bits used by this agent, or 0 if
//	condition bits aren't used.
//
// - (const char *)descriptionOfBit:(int)bit
//	If the agent uses condition bits, returns a description of the
//	specified bit.  Invalid bit numbers return an explanatory message.
//	Agents that don't use condition bits return NULL.
//
// - (int)nrules
//	Returns the number of rules or forecasters used by this agent, or 0
//	if rules/forecasters aren't used.
//
// - (int)lastgatime
//	Returns the last time at which an agent's genetic algorithm was run.
//	Agents that don't use a genetic algorithm return MININT.  This may
//	be used to see if the bit distribution might have changed, since
//	a change can only occur through a genetic algorithm.
//
// - (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
//	Places in (*countptr)[0] -- (*countptr)[3] the addresses of 4
//	arrays, (*countptr)[0][i] -- (*countptr)[3][i], which are filled
//	with the number of bits that are 00, 01, 10, or 11 respectively,
//	for each condition bit i= 0, 1, nbits-1, summed over all rules or
//	forecasters.  Returns nbits, the number of condition bits.  If
//	cum is YES, adds the new counts to whatever is in the (*coutptr)
//	arrays already.  Agents that don't use condition bits return -1.
//	The 4-element array (*countptr)[4] must already exist, but the
//	arrays to which its element point are supplied dynamically.  This
//	method must be provided by each subclass that has condition bits.
//
// - (int)fMoments:(double *)moment cumulative:(BOOL)cum
//	--to be written--
//
// - pAgentStatus:(FILE *) fp
//	--to be written--
//
// GLOBAL VARIABLES USED
//
// id agentManager
//	Object to which this sends messages.
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
// There are no strictly global variables supplied by Agent, but the
// following instance variables are declared @public:
//
//    double demand;	/* bid or -offer */
//    double profit;	/* exp-weighted moving average */
//    double wealth;	/* total agent wealth */
//    double position;  /* total shares of stock */
//    double cash;	/* total agent cash position */
//    int tag;		/* agent number (index into AgentManager's alist[]) */
//    int lastgatime;	/* last time a GA was run, or MININT if none */
//
// The front end (including inspectors) can therefore access these variables
// rapidly.  Agent subclasses may also use further @public variables for the
// same reason.  But users should never CHANGE agent's instance variables
// directly; an appropriate setxxx method must be used instead in case the
// change requires side effects.  A current exception is that the Specialist
// updates "profit", "position", and "cash" in its -completeTrades method
// for efficiency.
//
// IMPORTS
#import "global.h"
#import "Agent.h"
#import "AgentManager.h"
#import "error.h"

@implementation Agent

// CLASS METHODS, FOR OVERRIDING BY SUBCLASSES

+ initClass:(int)myclass
{
    [self subclassResponsibility:_cmd];
    return self;
}


+ (void *)createType:(int)mytype :(const char *)filename
{
    [self subclassResponsibility:_cmd];
    return self;
}


+ writeParams:(void *)params ToFile:(FILE *)fp
{
    fprintf(fp,"    <no parameters for this agent type>\n");
    return self;
}


+ didInitialize
{
    return self;	// default code does nothing
}


+ prepareForTrading:(void *)params
{
    return self;	// default code does nothing
}


+ (int)lastgatime:(void *)params;
{
    return MININT;	// default for agents without GAs
}


// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN

- init
/*
 * Dummy to catch misuse -- must call designated initializer.
 */
{
    [self error:"Init message invalid; requires initAgent"];
    return nil;		// not reached
}


- setTag:(int)mytag
{
    tag = mytag;
    return self;
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


- setPosition: (double)aDouble
{
    position = aDouble;
    return self;
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
 *	cash += intrate * cash + position*dividend;	// earnings
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

// If selling, we check to make sure we have enough stock to sell
    else if (demand < 0.0 && demand + position < minholding) {
	demand = minholding - position;
	*slope = 0.0;
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

- initAgent:(int)mytag
/*
 * Designated initializer.  Most agent classes will have additional
 * initialization, but should do [super initAgent:] to run this first.
 */
{

// Initialize instance variables common to all agents
    tag = mytag;
    lastgatime = MININT;	// Never changes if no GA
    profit = 0.0;
    wealth = 0.0;
    cash = initialcash;
    position = 0.0;

    return self;
}


- check
/*
 * Subclasses should also do this, via [super check].
 */
{
    if (!quiet)
	Message("#a:%3d %s h=%-9.5f c=%-10.4g w=%-10.4g",
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


- enabledStatus:(BOOL)flag
{
    return self;	// default code does nothing
}


- (int)nbits
{
    return 0;	// default for agents without condition bits
}


- (const char *)descriptionOfBit:(int)bit
{
    return NULL;	// default for agents without condition bits
}


- (int)nrules
{
    return 0;	// default for agents without rules/forecasters
}


- (int)lastgatime
{
    return lastgatime;
}


- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
{
    return -1;		// default for agents without condition bits
}


- (int)fMoments:(double *)moments cumulative:(BOOL)cum
{
    return -1;		// default for agents without condition bits
}


- pAgentStatus:(FILE *) fp
{
    return nil;
}

@end

