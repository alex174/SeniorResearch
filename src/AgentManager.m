// The Santa Fe Stockmarket -- Implementation of AgentManager

// One instance of this class is created.  It manages the lists of agents
// by class, type, and individual, deals with dispatching certain
// messages to all agents, and computes some agent-wide distributions.
// It also manages the selection of a new generation of agents when
// evolution of the agent population occurs.

// Some methods are provided here solely for use by the front end, to
// manage selection, and to provide bit distributions.  These are unused
// in the batch and gcc versions

// CLASSES, TYPES, AND INDIVIDUALS
//
// Agents are organized by class (e.g. BS), type within class (e.g. BS1,
// BS2), and individual within type (e.g. BS1-bar).
//
// 1. Agent classes correspond directly to distinct ObjC classes, so have
//    independently-defined methods (besides common inheritance of some 
//    superclass methods).  The agent class name (e.g. BS) and ObjC class
//    name (e.g. BSagent) are directly related by appending "agent".
//
// 2. Agent types within a class all share the same methods, but have
//    different initialization parameters.  When the set of participating
//    agents is defined by the agent list file, each line referencing a
//    given agent class defines a type and specifies a file from which the
//    initialization parameters are to be drawn.  E.g. the two lines
//		BS  10  1.0 bsparams
//		BS  20  1.0 bsp2
//    would construct 30 BS agents in all, 10 of type BS1 with parameters
//    taken from file "bsparams", and 20 of type BS2 with parameters drawn
//    from file "bsp2".  The type names (BS1, BS2, ...) are assigned
//    sequentially.  If there's only one one type in a class, then the
//    class name (e.g. BS) is used as the type name too.
//
//    The initialization parameters defining each type within a class are
//    stored in a struct in dynamic memory allocated by the class object.
//    An instance variable "p" in the class points to the appropriate struct
//    for each agent; e.g., p->pmutation might give the agent's mutation
//    probability (if applicable).
//
// 3. Individual agents within a type are instances of the agent class with
//    the pointer "p" pointing to the parameter struct for that type.  Such
//    instances have identical parameters and methods.  However they
//    typically won't behave identically because their instance variables
//    will become different due to random processes (including random
//    initialization, random GAs, stochastic market, etc).
//
// LISTS OF CLASSES, TYPES, AND INDIVIDUALS
//
// Three major tables are maintained by the agent manager, one for each
// level of the class/type/individual hierarchy:
//  
// 1. The aclass[] table lists all agent classes, whether used or not.  This
//    is initialized from the classnames[] table below.  The "class number"
//    of an agent is the index in this table for that agent's class.
//
// 2. The atype[] table lists all the types that were in use initially, in
//    the order in the agent list file.  Evolution can cause extinction,
//    so some may drop out of use, but are still retained in the table.  The
//    "type number" of an agent is the index in this table for that agent's
//    type.
//
// 3. The alist[] table lists all agents, in the order displayed.  This
//    order is based on the order in the agent list file, modified by the
//    cloning and deletion produced by evolution.  Clones of an agent are
//    adjacent in the list.  The "agent number" of an agent is the index in
//    this table for that agent.
//
// Pointers in these tables maintain linked lists of atype[] entries within
// each class, and alist[] entries within each type.  There is no specified
// order for these linked lists.
//
// These tables are only directly visible to AgentManager, but methods
// are provided to access the information.
//
// Class numbers, type numbers, and agent numbers are used by many of the
// AgentManager's methods.  They're often referred to as class, type, and
// index respectively where no confusion seems likely. 

// GENERAL METHODS
//
// - init
//	Initializes the AgentManager and builds the aclass[] table.  The
//	AgentManager learns about the agent classes from the typenames[]
//	list below.   Edit that table to add or remove agent classes.
//
// - makeAgents:(const char *)filename
//	Makes and initializes all agent classes and instances, and the
//	atype[] and alist[] tables, based on the list in the agent list
//	file "filename".   Each agent class object that's needed receives
//	an initClass: message.  Then, for each type, the class object
//	receives a createType:: message and then an alloc message for each
//	agent to be constructed.  The agents receive initAgent: and
//	setPosition: messages after their allocation.  See comments above
//	and in the default agent list file.
//
// - (int)numclasses
//	Returns the number of classes, whether in use or not.  This is the
//	length of the aclass[] table, and is fixed.
//
// - (int)numclassesInUse
//	Returns the number of classes that have one or more agents.
//	  
// - (int)numtypes
//	Returns the number of types.  This is the length of the atype[]
//	table, and is fixed.  It is the number of types that were in use
//	initially; at later times (after evolution) some of these types
//	may have zero agents, but they are retained nevertheless.
//
// - (int)numagents
//	Returns the number of agents.  This is the length of the alist[]
//	table.  At present it is fixed, but future changes might involve
//	a variable number of agents, so it's best to call this method
//	again whenever the number of agents is needed.
//
// - (int)generation
//	Returns the generation of the agents.  Initially this is 1, and
//	is incremented by one each time the agents are evolved.
//
// - check
//	Checks integrity of the aclass[], atype[] and alist[] tables,
//	and prints some statistics using Message().
//
// METHODS INVOVING ALL AGENTS
//
// Note: Several of the methods listed below return lists, using memory
// allocated by this object.  They all say "the list is overwritten on
// each call".  However the different lists are independent---the list
// returned by method A is not overwritten by a call to method B.  Memory
// is only allocated for those lists actually used.
//
// - writeParamsToFile:(FILE *)fp
//	Writes the agent list to file fp, and then tells the class object
//	of each agent type to write its parameters there too.
//
// - enableAll
//	Enables all agents.  Tells the frontend to update too.  All agents
//	are enabled when created, but may be disabled by a disable: message. 
//
// - checkAgents
//	Sends each agent a -check message, to tell it to perform any
//	internal checks.
//
// - checkTotalHolding
//	Checks that the sum of the holdings (positions) of the agents is
//	equal to the original value.  Writes a warning message if there's
//	a significant difference.  This is run at regular intervals
//	(debuginterval) if the -dh (or -dA) flag is used.
//
// - evolveAgents
//	Evolves the population of agents, constructing a new list with
//	membership proportional to fitness.  Agents no longer needed
//	are removed by sending them -free.  Clones of old agents are
//	created by sending them a -copy message.  Agents must respond
//	properly to both these messages, freeing or copying any extra
//	memory that they use (besides instance variables).
//
// - level
//	Reinitializes agents' cash, wealth, and position.
//
// - printAgentInfo:(FILE *)fp
//	For each agent, writes a summary line and then sends the agent
//	a pAgentStatus: message. 
//	
// - (Agent **)allAgents:(int *)len
//	Returns a list of all agent id's, in order of agent number.  If
//	len is not NULL, *len is set to the length of the list (numagents).
//	The list is overwritten on each call.
//	
// - (Agent **)enabledAgents:(int *)len
//	Returns a list of the agent id's of all enabled agents, in order of
//	agent number.  If len is not NULL, *len is set to the length of the
//	list (<= numagents).  The list is overwritten on each call.
//
// - (const short *)flags
//	Returns a list of length numagents giving a code that specifies
//	the enabled and selected bits for each agent.  Given the values
//	of SELECTEDBIT and ENABLEDBIT, the codes are:
//		0   disabled, not selected
//		1   enabled, not selected  (usual case)
//		2   disabled, selected
//		3   enabled, selected
//	The list is overwritten on each call.
//
// - getValues:(float *)values len:(int)len forProperty:(enum property)prop
//	Fills an array of values with the values (one per agent, in order)
//	of property "prop".  The properties are eseentially defined by
//	this method (see also enum property in global.h).   "values"
//	is an array of length len passed by the caller.  Min(len,numagents)
//	values are returned.
// 
// - getIndices:(int **)idxlist andStarts:(int **)startlist
//	Returns by reference two lists (allocated here) which together
//	specify which agents have each of the 4 possible flag codes
//	(see the flags method, above).  On return idxlist points to an array
//	of length numagents, containing first the indices of agents with
//	flag code 0, then those with flag code 1, then 2, then 3.  startlist
//	points to an array of length 5 specifying where each group of
//	indices starts and ends.  For example, the indices for code=2
//	are in locations *idxlist + (*startlist)[2] through *idxlist +
//	(*startlist)[3] - 1.  The lists are overwritten on each call.
//
// - selectList:(int *)list len:(int)len
//	Selects agents with indices list[0], list[1], ... list[len-1] and
//	deselects all others.  For use by the frontend; selection has no
//	effect on the simulation itself.
//
// - (BOOL)anyBitsChangedForSelection:(int)type
//	Returns YES if the condition bits of any of currently selected
//	agents of type "type" have changed since the last call of this
//	method or of -anyBitsChangedForType:.  Returns NO if there are
//	no selected agents of type "type" with condition bits, or if the
//	bits haven't changed.
//
// - (int *(*)[4])bitDistributionForSelection:(int)type
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of the condition bits
//	used by currently selected agents of type "type", summed over all
//	rules/forecasters of all agents in the selection.  Returns NULL if
//	there are no selected agents of type "type" with condition bits.
//
// METHODS AT THE AGENT CLASS LEVEL
//
// - (const char *)shortnameForClass:(int)class
//	Returns a shortname (2 characters, like "BS") for an agent class.
//	"class" is the class numbber -- an index into the aclass[] list.
//
// - (const char *)longnameForClass:(int)class
//	Returns a longname (e.g. "Bitstring") for an agent class.
//	"class" is the class numbber -- an index into the aclass[] list.
//
// - (int)nagentsInClass:(int)class
//	Returns the number of agents in class "class".
//
// METHODS AT THE AGENT TYPE LEVEL
//
// In the following methods, "type" as an integer refers to the type number
// of a type, which is the index into the atype[] table.
//
// - (int)classOfType:(int)type
//	Returns the class number (index into aclass[]) for a type.
//
// - (const char *)typenameForType:(int)type
//	Returns the 2-3 character name for a type (e.g. BS, BS2).
//
// - (int)typeWithName:(const char *)name
//	Returns the type with a given 2-3 character name (e.g. BS, BS2),
//	or -1 if no match is found.  "name" does not need to be
//	null-terminated; only three characters are read.
//
// - (const char *)longnameForType:(int)type
//	Returns the longname for the agent class to which "type" belongs.
//	Shortcut for longnameForClass:[AgentManager classOfType:type].
//
// - (const char *)filenameForType:(int)type
//	Returns the name of the file from which the parameters of this
//	type were read, stripped of any path prefix.
//
// - nametreeForType:(int)type
//	Returns the id of the name tree (an instance of NameTree) for agents
//	of type "type".
//
// - (int)nagentsOfType:(int)type
//	Returns the number of agents of type "type".
//
// - (int)nbitsForType:(int)type
//	Returns the number of condition bits used by agents of type "type",
//	or 0 if conditions bits aren't used.
//
// - (int)nrulesForType:(int)type
//	Returns the number of rules or forecasters used by agents of type
//	"type", or 0 if rules/forecasters aren't used. 
//
// - (const char *)descriptionOfBit:(int)bit forType:(int)type
//	If agent of type "type" use condition bits, returns a description
//	of the specified bit.  Invalid bit numbers return an explanatory
//	message.  Agent types that don't use condition bits return NULL. 
//
// - (BOOL)anyBitsChangedForType:(int)type
//	Returns YES if agents of this "type" have condition bits and if any
//	of their condition bits have changed since the last call of this
//	method or of -anyBitsChangedForSelection.
//
// - (int *(*)[4])bitDistributionForType:(int)type;
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of the condition bits
//	used by agents of "type", summed over all rules/forecasters of all
//	agents of this type.  Agent classes that don't use condition bits
//	return NULL.
// 
// - prepareTypesForTrading
//	Sends a +prepareForTrading: message to all agent types that have
//	agents.
//
// METHODS AT THE INDIVIDUAL AGENT LEVEL
//
// In the following methods, "agent idx" means the agent with agent
// number idx.  idx is the index into the alist[] table.
//
// - (const char *)shortnameOf:(int)idx
//	Returns an abbreviated name of agent idx.  E.g.: BS-abc, BS2-abc,
//	BS:abc, BS2:abc.  Each call overwrites the previous one.
//
// - (const char *)fullnameOf:(int)idx
//	Returns the full name of agent idx.  The full name is of the
//	form "BS2-abc-def-ghi", where the first 2-3 characters are the
//	typename and the next is either '-', or ':' if ancestors have
//	been omitted because of the MAXNAMELEVELS limit.  Each call
//	overwrites the previous one.
//
// - (int)classOf:(int)idx
//	Returns the class number for agent idx.
//
// - (int)typeOf:(int)idx
//	Returns the type number for agent idx.

// - (Agent *)idOf:(int)idx
//	Returns the id of agent idx.
//
// - (BOOL)validAgent:agid
//	Returns YES if "agid" is the id of an existing agent.  Used for
//	debugging checks.
//
// - (int)nameidxOf:(int)idx
//	Returns the index into its nametree of agent idx.  The nametree
//	itself is obtained with the nametreeForType: method.
//
// - enable:(int)idx
//	Enables agent idx.  Has no effect if already enabled.  Tells the
//	frontend to update too.
//
// - disable:(int)idx
//	Disables agent idx.  Has no effect if already disabled.  Tells the
//	frontend to update too.
//
// - (BOOL)isEnabled:(int)idx
//	Returns YES if agent idx is enabled.
//
// - select:(int)idx
//	Selects agent idx.  For use by the frontend; selection has no effect
//	on the simulation itself.  Has no effect if already selected.  If
//	idx<0 then ALL agents are selected.
//
// - deselect:(int)idx
//	Deselects agent idx.  For use by the frontend.   If idx<0 then ALL
//	agents are deselected.


#import "global.h"
#import "Agent.h"
#import "AgentManager.h"
#import <stdlib.h>
#import <string.h>
#import <sys/param.h>
#import <math.h>
#ifdef NEXTSTEP
#import <objc/objc-runtime.h>
#define GETCLASS	objc_getClass
#else
#import <objc/objc-api.h>
#define GETCLASS	objc_get_class
#endif
#import "Protocols.h"
#import "Agent.h"
#import "NameTree.h"
#import "random.h"
#import "error.h"
#import "util.h"

// Maximum characters in an agent filename
#define MAXAFILENAMELEN		60

// classnames[] table -- list of agent class names.
// The main agent class table aclass[] is initialized from this one.  If
// you add agents you must insert entries here for them to be found.
// Conversely, there must be classes (named XXagent) for XX equal to
// all of the shortnames listed here.
//
struct {char *longname; char *shortname;} classnames[] = {
    {"Dumb",		"DU"},
    {"Bitstring",	"BS"},
    {"Linear",		"LI"},
    {"Bitforecast", 	"BF"},
    {NULL,		NULL}	// marks end of list
};

// Structure for aclass[] list -- list of agent classes
typedef struct AM_Agentclass {
    struct AM_Agenttype *first;	// First type in linked list of this class
    struct AM_Agenttype *last;	// Last type in linked list of this class
    id classObject;		// Class object for this agent class
    char *longname;		// Long name, e.g. "Bitstring"
    char *shortname;		// Short name, 2 characters, e.g. "BS"
    int ntypes;			// Number of agent types in this class
    int nagents;		// Total number of agents in this class
    BOOL multipletypes;		// True if more than one type in class
} Agentclass;

// Structure for atype[] list -- list of agent types
typedef struct AM_Agenttype {
    struct AM_Agenttype *next;	// Next agent of same class (linked list)
    struct AM_Agentlist *first;	// First agent in linked list of this type
    struct AM_Agentlist *last;	// Last agent in linked list of this type
    void *params;		// Pointer to agent parameters structure
    char *fullfilename;		// Agent parameters filename
    char *filename;		// Agent parameters filename (last part)
    id classObject;		// Class object for this agent class
    id nametree;		// Name Tree for this agent type
    float initholding;		// Initial stockholding
    char typename[4];		// 2-3 characters, e.g. "BS" or "BS2"
    int nagents;		// Number of agents of this type
    short int class;		// This agent's class: index into aclass[]
    short int temp;		// Temporary for internal use
} Agenttype;

// Structure for alist[] list -- list of all agents
typedef struct AM_Agentlist {
    struct AM_Agentlist *next;	// Next agent of same type (linked list)
    Agent *agid;		// Id of this agent
    int nameidx;		// Index of name of this agent in nameTree
    short int type;		// This agent's type: index into atype[]
    BOOL enabled;		// Is agent enabled?
    BOOL selected;		// Is agent selected? (for frontend)
    BOOL flag1;			// Temporary for internal use
    BOOL flag2;			// Temporary for internal use
} Agentlist;

// Structure for use while reading agentlist file
typedef struct AM_Aline {
    struct AM_Aline *next;
    struct AM_Aline *prev;
    char *filename;
    float initholding;
    int class;
    int n;
} Aline;

// Structure used when performing evolution
typedef struct AM_Newagentlist {
    Agent *newagid;
    double fitness;
    int newnameidx;
    int desired;
    short int newtype;
    BOOL newenabled;
    BOOL newselected;
} Newagentlist;

// Macros to check arguments for debugging
#ifdef DEBUG
#define CHECKCLASS(c)	{if ((c) < 0 || (c) >= numclasses) \
			    [self error:"Invalid class '%d'", (c)];}
#define CHECKTYPE(type)	{if ((type) < 0 || (type) >= numtypes) \
			    [self error:"Invalid type '%d'", (type)];}
#define CHECKIDX(idx)	{if ((idx) < 0 || (idx) >= numagents) \
			    [self error:"Invalid agent index '%d'", (idx)];}
#else
#define CHECKCLASS(c)	{}
#define CHECKTYPE(type)	{}
#define CHECKIDX(idx)	{}
#endif

// PRIVATE METHODS
@interface AgentManager(Private)
- (int)getLine:(int *)class :(float *)ihptr :(char **)filename;
- createAgent:(int)agnum type:(int)type parent:(int)par position:(float)posn;
- (double)fitness:(const Agent *)agid;
@end


@implementation AgentManager

// ============================= GENERAL METHODS ==========================

- init
/*
 * Initializes this object; sets up aclass[] table.
 */
{
    register int class;
    register Agentclass *cp;

// Set "stale" flags for arrays that certain methods return
    alllist_stale = YES;
    enabledlist_stale = YES;
    flaglist_stale = YES;
    colorlists_stale = YES;

// Count the agent types, allocate memory for aclass[] array
    for (numclasses=0; classnames[numclasses].longname != NULL; numclasses++) ;
    aclass = (Agentclass *) getmem(sizeof(Agentclass)*numclasses);

// Loop over all agent classes
    for (class=0; class<numclasses; class++) {
	cp = aclass + class;
	cp->classObject = nil;
	cp->ntypes = 0;
	cp->nagents = 0;
	cp->first = cp->last = NULL;

	// Check names
	cp->longname = classnames[class].longname;
	cp->shortname = classnames[class].shortname;
	if (strlen(cp->longname) > MAXLONGNAMELEN)
	    [self error:"Long class name '%s' too long; MAXLONGNAMELEN = %d",
						cp->longname, MAXLONGNAMELEN];
	if (strlen(cp->shortname) != 2)
	    [self error:"Short class name '%s' is not 2 characters",
							cp->shortname];
    }

// Initialize the NameTree class object
#ifdef DEBUG
    [NameTree setDebugFile:stderr];
#endif

    return self;
}


- makeAgents:(const char *)alistfile
/*
 * Allocates and initializes all agents.
 */
{
    register Agentclass *cp;
    register Agenttype *tp;
    register Aline *save;
    int n, class, type, anum;
    unsigned int amemory, ntmemory;
    Aline *first, *last, **nextptr;
    id nametree;
    float initholding;
    char aClassName[12];
    char *filename, *ptr;

// Record memory in use for later comarison
    amemory = totalMemory();

// Open agentlist file and check and store its contents.  We have to store
// it temporarily so we can see how many agents and types there are before
// actually creating the working arrays.  (Reading the file twice doesn't
// work if input files are concatenated.)
    alistfp = OpenInputFile(alistfile, "agent list");
    numagents = 0;
    numtypes = 0;
    nextptr = &first;	// Make a double-linked list
    last = NULL;
    while ((n = [self getLine:&class :&initholding :&filename]) >= 0) {
	if (n > 0) {	/* n may be zero if error detected */
	    cp = aclass + class;
	    numagents += n;
	    cp->nagents += n;
	    ++cp->ntypes;
	    save = (Aline *)getmem(sizeof(Aline));
	    save->class = class;
	    save->initholding = initholding;
	    save->n = n;
	    save->filename = filename;
	    *nextptr = save;
	    nextptr = &save->next;
	    save->prev = last;
	    last = save;
	    ++numtypes;
	}
    }
    *nextptr = NULL;

// Done with agentlist file
    abandonIfError("[AgentManager makeAgents:]");

// Abandon if no agents
    if (numagents == 0)
	[self error:"No agents specified in %s file", alistfile];

// Allocate memory for atype[], alist[], indices
    atype = (Agenttype *) getmem(sizeof(Agenttype)*numtypes);
    alist = (Agentlist *) getmem(sizeof(Agentlist)*numagents);
    indices = (int *) getmem(sizeof(int)*numagents);

// Initialize the agent class object for each class that's in use
    for (class = 0; class < numclasses; class++) {
	cp = aclass + class;
	if (cp->ntypes > 0) {
	    strcpy(aClassName, cp->shortname);
	    strcat(aClassName, "agent");
	    cp->classObject = GETCLASS(aClassName);
	    if (!cp->classObject)
		[self error:"Nonexistent agent class %s", aClassName];
	    [cp->classObject initClass:class];
	}
	cp->multipletypes = cp->ntypes > 1;
	cp->ntypes = 0;	/* reset for second pass */
    }

// Second pass through list -- create agents, atype[], alist[], and nametrees.
    anum = 0;
    totalholding = 0.0;
    for (save=first, type=0; save!=NULL; save=save->next, type++) {
	n = save->n;
	class = save->class;
	filename = save->filename;
	initholding = save->initholding;

	tp = atype + type;
	totalholding += initholding*n;
	cp = aclass + class;

    /* Link this type into linked list of types in this class */
	if (cp->last == NULL)
	    cp->first = tp;
	else
	    cp->last->next = tp;
	tp->next = NULL;
	cp->last = tp;
	++cp->ntypes;

    /* initialize atype[] entries */
	tp->first = tp->last = NULL;
	tp->nagents = n;
	tp->initholding = initholding;
	tp->nametree = nil;
	tp->class = class;
	tp->classObject = cp->classObject;
	tp->fullfilename = filename;
	if ((ptr=strrchr(filename,'/')) != NULL)
	    tp->filename = ptr+1;	/* strip path prefix */
	else
	    tp->filename = filename;
		
    /* construct typename */
	strcpy(tp->typename, cp->shortname);
	if (cp->multipletypes) {
	    if (cp->ntypes > ('9'-'1'+1 + 'z'-'a'+1))
		[self error:"Too many types in %s class", tp->typename];
	    tp->typename[2] = cp->ntypes<10? '0'+cp->ntypes: 'a'+cp->ntypes-10;
	    tp->typename[3] = EOS;
	}

    /* instantiate a name tree */
	tp->nametree = [[[[[NameTree alloc] init] setPathSeparator:'-']
			setPartialPathPrefix:':'] setMaxDepth:MAXNAMELEVELS];

    /* create a type within this agent class (reads parameter file) */
	tp->params = [cp->classObject createType:type :filename];

    /* create the agents */
	while (n--)
	    [self createAgent:anum++ type:type parent:0 position:initholding];
    }
    if (anum != numagents)
	[self error:"Internal error creating agents:\n"
			"anum = %d, numagents = %d", anum, numagents];

// Free our temporary list
    for (save=last->prev; last; last=save, save=(save?save->prev:NULL))
	free(last);
 
// Tell the agent classes we're done creating agents
    for (class = 0; class < numclasses; class++)
	if (aclass[class].ntypes > 0)
	    [aclass[class].classObject didInitialize];

// Set all the "stale" flags
    alllist_stale = YES;
    enabledlist_stale = YES;
    flaglist_stale = YES;

// We now have the first generation
    generation = 1;

// Check our tables
    if (debug&DEBUGTYPES)
	[self check];

// Check the name trees
    if (debug&DEBUGNAMETREE && !quiet)
	for (type=0; type<numtypes; type++)
	    if ((nametree=atype[type].nametree) != nil)
		Message("#n: NameTree for %-3s: %d nodes in use, %d bytes",
					    atype[type].typename,
					    [nametree checkIntegrity:stderr],
					    [nametree memoryInUse]);

// Report memory usage (not including object instantiation memory)
    if (debug&DEBUGMEMORY && !quiet) {
	ntmemory = 0;
	for (type=0; type<numtypes; type++)
	    if ((nametree=atype[type].nametree) != nil)
		ntmemory += [nametree memoryInUse];
	amemory = totalMemory() - amemory;
	Message("#m: agents: malloc: %u  nametrees: %u", amemory, ntmemory); 
    }
	
    return self;
}


- (int)getLine:(int *)class :(float *)ihptr :(char **)afilename
/*
 * Auxiliary method to read one line from the agent list file
 */
{
#define MAXAGENTS	1000	/* just to detect stupid errors */
#if MAXAFILENAMELEN > MAXLONGNAMELEN
#define LINELEN	MAXAFILENAMELEN
#else
#define LINELEN	MAXLONGNAMELEN
#endif
    register int i;
    char namebuf[LINELEN+1], buf[LINELEN+1];
    int status, c;
    char *ptr, *ertext;
    long strtol();
    int n = 0;

    status = gettok(alistfp, buf, MAXLONGNAMELEN+1);
    if (status < 0 || strcmp(buf, ".") == EQ || strcmp(buf, "end") == EQ)
	return (-1);
    strcpy(namebuf,buf);	/* for error messages */
    if (status > 0)
	{ ertext = "agent class name too long"; goto bad; }
    else {
	for (i=0; i<numclasses; i++)
	    if (strcmp(buf,aclass[i].longname) == EQ ||
		    strcmp(buf,aclass[i].shortname) == EQ) {
		*class = i;
		break;
	    }
	if (i >= numclasses)
	    { ertext = "unknown agent class"; goto bad; }
    }

    status = gettok(alistfp, buf, LINELEN+1);
    if (status < 0)	/* EOF */
	return (-1);
    if (status > 0)
	{ ertext = "agent count too long"; goto bad; }
    else {
	n = (int) strtol(buf, &ptr, 10);
	if (*ptr != EOS || n <= 0 || n > MAXAGENTS)
	    { ertext = "invalid agent count"; goto bad; }
    }

    status = gettok(alistfp, buf, LINELEN+1);
    if (status < 0)	/* EOF */
	return (-1);
    if (status > 0)
	{ ertext = "agent initial holding too long"; goto bad; }
    else {
	*ihptr = (float)strtod(buf, &ptr);
	if (*ptr != EOS || *ihptr < minholding)
	    { ertext = "invalid agent initial holding"; goto bad; }
    }

    status = gettok(alistfp, buf, MAXAFILENAMELEN+1);
    if (status < 0)	/* EOF */
	return (-1);
    if (status > 0)
	{ ertext = "agent parameter filename too long"; goto bad; }
    else if (afilename)
	*afilename = strcpy((char *)getmem(sizeof(char)*(strlen(buf)+1)),buf);

    return n;

bad:
    saveError("%s: %s (%s)",namebuf, ertext, buf);
    while ((c = getc(alistfp)) != EOF && c != '\n') ;
    return 0;
}


- createAgent:(int)a type:(int)type parent:(int)par position:(float)posn
/*
 * Creates an agent of type "type" for entry alist[a].  Sets initial
 * position to "posn", and makes it a child of "par".  All appropriate
 * alist[a] and atype[type] entries are filled in or updated. 
 */
{ 
    register Agentlist *alp;
    Agent *agid;
    char name[4];
    Agenttype *tp;

    CHECKTYPE(type)
    tp = atype + type;
    CHECKIDX(a)
    alp = alist + a;

// Instantiate, set position
    agid = [[tp->classObject alloc] initAgent:a];
    [agid setPosition:(double)posn];

// Construct name, tie into name tree
    alp->nameidx = [tp->nametree addName:randomName(name) value:a parent:par];

// Fill in miscellaneous alist[] entries
    alp->agid = (Agent *)agid;
    alp->type = type;
    alp->enabled = YES;
    alp->selected = NO;

// Link into list of this type of agent, increment count
    if (tp->last == NULL)
	tp->first = alp;
    else
	tp->last->next = alp;
    alp->next = NULL;
    tp->last = alp;

// Check if debugging
    if (debug&DEBUGAGENT)
	[agid check];

    return self;
}


- (int)numclasses
{ return numclasses; }


- (int)numclassesInUse
{
    register int class, count;

    for (class = 0, count = 0; class < numclasses; class++)
	if (aclass[class].nagents > 0) count++;

    return count;
}


- (int)numtypes
{ return numtypes; }


- (int)numagents
{ return numagents; }


- (int)generation
{ return generation; }


- (double)totalholding
{ return totalholding; }


- check
/*
 * Checks integrity of the aclass[], atype[] and alist[] tables,
 * and prints some statistics.
 */
{
    register Agentlist *alp, *prev;
    int class, type, a, nintype, ntypes, nagents, ninclass, ntypesinclass;
    Agentclass *cp;
    Agenttype *tp, *tprev;
    const char *classname;

// Clear some flags used to detect overlaps
    for (type=0; type < numtypes; type++)
	atype[type].temp = 0;
    for (a=0; a < numagents; a++)
	alist[a].flag1 = NO;

    ntypes = 0;
    nagents = 0;
    for (class = 0; class < numclasses; class++) {
	cp = aclass + class;
	if (cp->ntypes > 0) {
	    classname = [cp->classObject name];
	    if (strncmp(classname, cp->shortname, 2) != EQ)
		Message("*t: class name mismatch: %s %s", classname,
							    cp->shortname);
	    ninclass = 0;
	    ntypesinclass = 0;
	    tprev = NULL;
	    for (tp=cp->first; tp!=NULL; tprev=tp, tp=tp->next) {
		++ntypes;
		++ntypesinclass;
		type = tp-atype;
		if (tp->temp++)
		    Message("*t: overlapping types: %s", tp->typename);
		if (tp->class != class)
		    Message("*t: atype[].class mismatch: %s %d %d",
					    tp->typename, tp->class, class);
		if (strncmp(cp->shortname, tp->typename, 2) != EQ)
		    Message("*t: type name mismatch: %s %s", tp->typename,
							    cp->shortname);
		Message("#t: %3d %-3s %s", tp->nagents, tp->typename,
							    tp->filename);
		nintype = 0;
		prev = NULL;
		for (alp=tp->first; alp!=NULL; prev=alp, alp=alp->next) {
		    ++ninclass;
		    ++nintype;
		    ++nagents;
		    if (alp->flag1) {
			Message("*t: overlapping agents: %s %d",
					    tp->typename, (int)(alp-alist));
			break;	// stop infinite loop
		    }
		    alp->flag1 = YES;
		    if (alp->type != type)
			Message("*t: alist[].type mismatch: %s %d %d %d",
			tp->typename, (int)(alp-alist), (int)alp->type, type);
		    if (![tp->nametree validNode:alp->nameidx])
			Message("*t: invalid alist[].nameidx: %s %d %d",
				tp->typename, (int)(alp-alist), alp->nameidx);
		}
		if (nintype != tp->nagents)
		    Message("*t: atype[].nagents mismatch: %s %d %d",
					tp->typename, nintype, tp->nagents);
		if (prev != tp->last)
		    Message("*t: atype[].last mismatch: %s %d",
						    tp->typename, nintype);
	    }
	    if (ninclass != cp->nagents)
		Message("*t: aclass[].nagents mismatch: %s %d %d",
					cp->shortname, ninclass, cp->nagents);
	    if (ntypesinclass != cp->ntypes)
		Message("*t: aclass[].ntypes mismatch: %s %d %d",
				    cp->shortname, ntypesinclass, cp->ntypes);
	    if (tprev != cp->last)
		Message("*t: aclass[].last mismatch: %s %d",
						cp->shortname, cp->ntypes);
	}
    }
    if (ntypes != numtypes)
	Message("*t: numtypes mismatch: %d %d", ntypes, numtypes);
    if (nagents != numagents)
	Message("*t: numagents mismatch: %d %d", nagents, numagents);
    Message("#t: %3d total (%d types)", numagents, numtypes);

    return self;
}


// ======================== METHODS INVOVING ALL AGENTS ====================

- writeParamsToFile:(FILE *)fp
/*
 * Reconstructs the agent list and writes that out, then tells each
 * agent type to write its own parameters (if any).
 */
{
    register int i;
    register Agenttype *tp;
    char vbuf[MAXPATHLEN+32], dbuf[MAXPATHLEN+32];

    if (fp == NULL) fp = stderr;	// For use in gdb

    for (i=0; i<numtypes; i++) {
	tp = atype + i;
	if (strcmp(tp->fullfilename, "<none>") == EQ ||
					strcmp(tp->fullfilename, "=") == EQ) {
	    sprintf(vbuf,"%s %2d %g %s",
		    aclass[tp->class].shortname, tp->nagents,
		    tp->initholding, tp->fullfilename);
	    sprintf(dbuf,"type %s", tp->typename);
	}
	else {
	    sprintf(vbuf,"%s %2d %g =",
		    aclass[tp->class].shortname, tp->nagents,
		    tp->initholding);
	    sprintf(dbuf,"type %s (original file: %s)",
		    tp->typename, tp->fullfilename);
	}
	showbarestrng(fp, dbuf, vbuf);
    }
    showstrng(fp, "(end of agent list)", "end");
    fprintf(fp,"# %d agents in all\n",numagents);

// Tell each agent type to write out its own parameters
    for (i=0; i<numtypes; i++) {
	tp = atype + i;
	fprintf(fp, "\n# --- Agent type %s parameters ---\n", tp->typename);
	showsourcefile(fp, tp->filename);
	[tp->classObject writeParams:tp->params ToFile:fp];
    }
    return self;
}


- enableAll
{
    register int a;
    for (a=0; a<numagents; a++) {
	alist[a].enabled = YES;
	[alist[a].agid enabledStatus:NO];
    }

    enabledlist_stale = YES;
    flaglist_stale = YES;
    [marketApp updateEnabledStatus:-1];
    return self;
}


- checkAgents
/*
 * Tells each agent to perform any internal checks
 */
{
    register int a;

    for (a=0; a<numagents; a++)
	[alist[a].agid check];
    return self;
}


- checkTotalHolding
/*
 * Checks that the sum of the positions (holdings) of the agents is
 * equal to the original value.
 */
{
    register int a;
    double total,totalcash,totalwealth;

    totalcash = totalwealth = total = 0.0;
    for (a=0; a<numagents; a++) {
	total += alist[a].agid->position;
	totalcash += alist[a].agid->cash;
	totalwealth += alist[a].agid->wealth;
    }

    if (abs(total-totalholding) > 0.0001*totalholding)
	Message("*h: totalholding error: %g %g",total,totalholding);
    Message("#h: totals: h=%-9.5f c=%-10.4g w=%-10.4g",
				    total,totalcash,totalwealth);

    return self;
}


- evolveAgents
/*
 * Creates a new generation of agents from the old one, choosing numbers
 * of agents proportional to fitness.  Disabled agents are treated specially;
 * they remain in the population (one copy of each), and remain disabled.
 * The enabled and selected flags propogate, so all the children of a
 * selected agent are selected.
 *
 * Normalization added by Blake 
 * This is to keep shares and total cash holdings constant after
 * evolution.  The formulas uses the proportions determined by
 * evolution, but the total values are taken from the previous ones.
 */ 
{
    register int a, j, k;
    register Newagentlist *nlp;
    int numdisabled, class, type, nclones;
    Agentlist *alp;
    Agenttype *tp;
    Newagentlist *newlist;
    id nametree;
    unsigned int ntmemory;
    double thisfitness, total, norm, expected;
    char name[4];
    double beforecash,beforeshares;	// Shares and cash before evolution
    double totalcash,totalshares;
    
// Prepare frontend if any
    if (marketApp)
	[marketApp preEvolve];

// Allocate a temporary array to hold selection information for the old
// agents (fitness and desired) and temporary copies of the variables in
// alist[] for the new agents.  These are copied back to alist[] before exit.
    newlist = (Newagentlist *) getmem(sizeof(Newagentlist)*numagents);

// Find total cash and share holdings for renormalizing
    beforecash = beforeshares = 0;
    for(a=0; a<numagents;a++) {
	beforeshares += alist[a].agid->position;
	beforecash   += alist[a].agid->cash;
    }

// Compute a fitness value for each agent, and a total.  Also deal with
// disabled agents.
    total = 0.0;
    numdisabled = 0;
    for (a=0; a<numagents; a++) {
	if (alist[a].enabled) {
	    thisfitness = [self fitness:alist[a].agid];
	    if (thisfitness < 0.0) thisfitness = 0.0;
	    total += newlist[a].fitness = thisfitness;
	}
	else {
	    newlist[a].desired = 1;
	    newlist[a].fitness = -1.0;
	    ++numdisabled;
	}
    }
    if (total == 0.0) {
	Message("*** all enabled agents have zero fitness");
	return self;
    }

// Decide how many copies we'll have of each old agent.  We use "stochastic
// remainder selection without replacement" -- see Goldberg's book.  First
// we calculate an expected number of offspring for each parent, and
// directly choose a number of copies equal to the integer part.  Then
// we repeatedly go through the list of fractional parts, choosing to
// include each with probability equal to the fractional part.
    k = numdisabled;				// counter for offspring
    norm = (numagents-numdisabled)/total;
    for (a=0; a<numagents && k<numagents; a++) {
	if (alist[a].enabled) {
	    expected = newlist[a].fitness * norm;
	    j = (int)expected;
	    newlist[a].fitness = expected - j;	// now contains remainder
	    if (j > 0) {
		if (j+k > numagents) j = numagents - k;
		newlist[a].desired = j;
		k += j;
	    }
	    else
		newlist[a].desired = 0;
	}
    }
    a = 0;
    while (k < numagents) {
	++a;
	if (a >= numagents) a = 0;
	if (newlist[a].fitness > 0.0 && newlist[a].fitness > drand()) {
	    ++newlist[a].desired;
	    ++k;
	    newlist[a].fitness -= 2.0;
	}
    }

// Delete the agents we won't use at all
    for (a=0; a<numagents; a++) {
	if (newlist[a].desired == 0) {
	    [alist[a].agid free];
	    [atype[alist[a].type].nametree removeLineage:alist[a].nameidx];
	}
    }

// Create the new list of agents, record types, make new names.  After
// this loop newlist[]'s newagid, newtype, newenabled, newselected, and
// newnameidx are the alist[] entries for the new agents.  Order of agents
// is maintained.
    k = 0;
    for (a=0; a<numagents; a++) {
	alp = alist + a;
	type = (int)alp->type;
	nclones = newlist[a].desired;
	for (j=0; j<nclones; j++) {
	    nlp = newlist + k;
	    nlp->newtype = type;
	    nlp->newenabled = alp->enabled;
	    nlp->newselected = alp->selected;
	    if (j==0)
		nlp->newagid = alp->agid;
	    else
		nlp->newagid = [alp->agid copy];
	    nlp->newnameidx = [atype[type].nametree
		    addName:randomName(name) value:k parent:alp->nameidx];
	    [nlp->newagid setTag:k];
	    ++k;
	}
    }
    if (k != numagents)
	[self error:"Internal error reproducing agents, k=%d", k];

// Clean up our own lists
    for (type=0; type<numtypes; type++) {
	tp = atype + type;
	tp->first = NULL;
	tp->last = NULL;
	tp->nagents = 0;
    }
    for (class=0; class < numclasses; class++)
	aclass[class].nagents = 0;
    for (a=0; a<numagents; a++) {
	alp = alist + a;
	nlp = newlist + a;
	alp->type = nlp->newtype;
	alp->agid = nlp->newagid;
	alp->enabled = nlp->newenabled;
	alp->selected = nlp->newselected;
	alp->nameidx = nlp->newnameidx;
	tp = atype + alp->type;
	++tp->nagents;
	++aclass[tp->class].nagents;
	if (tp->last == NULL)
	    tp->first = alp;
	else
	    tp->last->next = alp;
	alp->next = NULL;
	tp->last = alp;
    }

// Release our temporary storage
    free(newlist);

// Renormalize positions
    totalcash = totalshares = 0;
    for(a=0; a<numagents;a++) {
	totalshares += alist[a].agid->position;
	totalcash   += alist[a].agid->cash;
    }

    for(a=0; a<numagents;a++) {
	alist[a].agid->position = alist[a].agid->position/totalshares *
		beforeshares;
	alist[a].agid->cash     = alist[a].agid->cash/totalcash * 
		beforecash;
    }

// Set all "stale" bits, so lists are recomputed when next needed
    alllist_stale = YES;
    enabledlist_stale = YES;
    flaglist_stale = YES;

// Increment generation
    ++generation;

// Check the new type tables
    if (debug&DEBUGTYPES)
	[self check];

// Check the new agents
    if (debug&DEBUGAGENT)
	[self checkAgents];

// Check the name trees
    if (debug&(DEBUGNAMETREE|DEBUGMEMORY) && !quiet) {
	ntmemory = 0;
	for (type=0; type<numtypes; type++)
	    if ((nametree=atype[type].nametree) != nil) {
		if (debug&DEBUGNAMETREE)
		    Message("#n: NameTree for %-3s: %d nodes in use, %d bytes",
					    atype[type].typename,
					    [nametree checkIntegrity:stderr],
					    [nametree memoryInUse]);
		if (debug&DEBUGMEMORY)
		    ntmemory += [nametree memoryInUse];
	    }
	if (debug&DEBUGMEMORY)
	    Message("#m: nametrees: %u", ntmemory);
    }

// 
// Update the frontend if any
    if (marketApp)
	[marketApp postEvolve];

    return self;	
}


- (double)fitness:(const Agent *)agid
/*
 * Computes fitness of one agent for evolution of the population.  Fitness
 * values should be positive -- negative values will be taken as zero, and
 * will produce no offspring.   
 */
{
    return agid->wealth;	/* use agent wealth as fitness */
}


- level
/* 
 * level playing field
 */
{
    register int a;

    for(a=0; a<numagents;a++) {
	alist[a].agid->position = 1;
	alist[a].agid->cash = initialcash;
	alist[a].agid->wealth = initialcash + price;
    }
    return self; 
}


- printAgentInfo:(FILE *)fp
/*
 * Print out some general information and then ask each agent to print
 * its own information.
 */
{
    register int i;
    //register int a;
    int *(*bitlist)[4];
    double *moments;
    int *count1,*count2;
    int cbits;
    double sum;
    
// Print heading
    fprintf(fp,"%d %d ",t,numagents);

// Print the bit distribution (0+1 bits) for agents of type=0.
// Needs fixing -- type=0 my not be what we want.
    cbits = [self nbitsForType:0];
    bitlist = [self bitDistributionForType:0];
    count1 = (*bitlist)[1];
    count2 = (*bitlist)[2];
    sum = 0.0;
    for(i=0;i<cbits;i++)
    	sum += count1[i]+count2[i];
    sum /= ((double)cbits);
    for(i=0;i<cbits;i++) 
    	fprintf(fp,"%d ",count1[i]+count2[i]);
    fprintf(fp,"%f ",sum);
    moments = [self fMomentsForType:0];
    for(i=0;i<6;i++)
        if( (i!=2) && (i!=3))
	fprintf(fp,"%f ",moments[i]);
    fprintf(fp,"\n");

// Print one line for each agent and then whatever the agent wants to
// report.
/*
Print out details for each agent.  I'd love to be able to turn this on
and off.  PARAM
    for(a=0; a<numagents;a++) {
    	fprintf(fp,"%d %s %e %e\n",
		a,
		[alist[a].agid shortname],
		alist[a].agid -> wealth/initialcash,
		alist[a].agid -> position
		);

	[alist[a].agid pAgentStatus:fp];
    }
*/
    fflush(fp);
    return self;
}


- (Agent **)allAgents:(int *)len
{
    register int a;

    if (alllist_stale) {
	if (!alllist)
	    alllist = (Agent **)getmem(sizeof(Agent *)*numagents);
	for (a=0; a<numagents; a++)
	    alllist[a] = alist[a].agid;
	alllist_stale = NO;
    }
    if (len) *len = numagents;
    return alllist;
}


- (Agent **)enabledAgents:(int *)len
{
    register int a, i;
    static int nenabled;

    if (enabledlist_stale) {
	if (!enabledlist)
	    enabledlist = (Agent **)getmem(sizeof(Agent *)*numagents);
	for (a=0, i=0; a<numagents; a++)
	    if (alist[a].enabled)
		enabledlist[i++] = alist[a].agid;
	nenabled = i;
	enabledlist_stale = NO;
    }
    if (len) *len = nenabled;
    return enabledlist;
}


- (const short *)flags
/*
 * Returns a list of flags, one element for each agent, with each value
 * the OR of:
 *    ENABLEDBIT if enabled, 0 if not
 *    SELECTEDBIT if selected, 0 if not
 */
{
    register int a;

    if (flaglist_stale) {
	if (!flaglist)
	    flaglist = (short *)getmem(sizeof(short)*numagents);    
	for (a=0; a<numagents; a++)
	    flaglist[a] = (alist[a].enabled?ENABLEDBIT:0) +
				    (alist[a].selected?SELECTEDBIT:0);
	flaglist_stale = NO;
	colorlists_stale = YES;
    }
    return flaglist;
}


- getValues:(float *)values len:(int)len forProperty:(enum property)prop
{
    register int a;
    int nvalues;

    nvalues = numagents<len? numagents: len;

    switch (prop) {
    case WEALTH:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->wealth;
	break;
    case RELATIVEWEALTH:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->wealth/initialcash;	// stupid, fix!
	break;
    case POSITION:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->position;
	break;
    case STOCKVALUE:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->position*price;
	break;
    case CASH:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->cash;
	break;
    case PROFITMA:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->profit;
	break;
    case DEMAND:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a].agid->demand;
	break;
    case TARGET:
	for (a=0; a<nvalues; a++)
	    values[a] = (alist[a].agid->position + alist[a].agid->demand);
	break;
    default:
	[self error:"Illegal property %d",prop];
    }

    return self;
}


- getIndices:(int **)idxlist andStarts:(int **)startlist
/*
 * Returns by reference a list of agent indices (numagents in all) ordered
 * by their "flags" value and a list (length 5) of where each flag value
 * starts and ends.  E.g., the list for flag value =2 is from
 *    *idxlist + (*startlist)[2]  to  *idxlist + (*startlist)[3] -1.
 * Both arrays are returned from local storage here, and may be overwritten
 * by subsequent calls.
 */
{
    int a, k;
    short f;

    if (flaglist_stale)
	(void)[self flags];	// Sets colorlists_stale

    if (colorlists_stale) {
	for (f=0, k=0; f<4 && k<numagents; f++) {
	    starts[f] = k;
	    for (a=0; a<numagents; a++)
		if (flaglist[a] == f)
		    indices[k++] = a;
	}	
	for (; f<5; f++)
	    starts[f] = numagents;
	colorlists_stale = NO;
    }
    *idxlist = indices;
    *startlist = starts;
    return self;
}


- selectList:(int *)list len:(int)len
/*
 * This method provides fast selection of a list of agents, without requiring
 * multiple messages to -select:.  All others are deselected.
 */
{
    register int i;

    for (i=0; i<numagents; i++)
	alist[i].selected = NO;

    for (i=0; i<len; i++) {
#ifdef DEBUG
	if (list[i] < 0 || list[i] >= numagents)
	    [self error:"Invalid index '%d' at %d in selection list", i,
								    list[i]];
#endif
	alist[list[i]].selected = YES;
    }
    flaglist_stale = YES;
    return self;
}


- (int)lastgatimeForSelection:(int)type
{
    Agentlist *alp;
    register int greatest;
    
    greatest = MININT;
    for (alp = atype[type].first; alp != NULL; alp = alp->next)
	if (alp->selected && alp->agid->lastgatime > greatest)
	    greatest = alp->agid->lastgatime;

    return greatest;
}


- (int *(*)[4])bitDistributionForSelection:(int)type
/*
 * Construct bit distribution for current selection, assuming that type
 * gives the selected type.
 */
{
    Agentlist *alp;
    static int *count[4];

    for (alp = atype[type].first; alp != NULL; alp = alp->next)
	if (alp->selected) {
	    if ([alp->agid bitDistribution:&count cumulative:NO] < 0)
		return NULL;
	    break;
	}
    if (alp == NULL)
	return NULL;
    for (alp = alp->next; alp != NULL; alp = alp->next)
	if (alp->selected)
	    (void)[alp->agid bitDistribution:&count cumulative:YES];

    return &count;
}


// =================== METHODS AT THE AGENT CLASS LEVEL ==================

- (const char *)shortnameForClass:(int)class;
{
    CHECKCLASS(class)
    return aclass[class].shortname;
}


- (const char *)longnameForClass:(int)class;
{
    CHECKCLASS(class)
    return aclass[class].longname;
}


- (int)nagentsInClass:(int)class
{
    CHECKCLASS(class)
    return aclass[class].nagents;
}


// =================== METHODS AT THE AGENT TYPE LEVEL ==================

- (int)classOfType:(int)type
{
    CHECKTYPE(type)
    return atype[type].class;
}


- (const char *)typenameForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].typename;
}


- (int)typeWithName:(const char *)name
{
    register int type;
    char *typename;
    
    for (type=0; type<numtypes; type++) {
	typename = atype[type].typename;
	if (typename[0] != name[0] || typename[1] != name[1]) continue;
	if (typename[2] == EOS || typename[2] == name[2]) break;
    }
    return (type==numtypes? -1: type);
}


- (const char *)longnameForType:(int)type
{
    CHECKTYPE(type)
    return aclass[atype[type].class].longname;
}


- (const char *)filenameForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].filename;
}


- nametreeForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].nametree;
}


- (int)nagentsOfType:(int)type
{
    CHECKTYPE(type)
    return atype[type].nagents;
}


- (int)nbitsForType:(int)type
{
    Agent *agid;
    
    CHECKTYPE(type)
    agid = atype[type].first->agid;
    if (agid)
	return [agid nbits];
    else
	return 0;
}


- (int)nrulesForType:(int)type
{
    Agent *agid;
    
    CHECKTYPE(type)
    agid = atype[type].first->agid;
    if (agid)
	return [agid nrules];
    else
	return 0;
}


- (const char *)descriptionOfBit:(int)bit forType:(int)type
{
    Agent *agid;
    
    CHECKTYPE(type)
    agid = atype[type].first->agid;
    if (agid)
	return [agid descriptionOfBit:bit];
    else
	return NULL;
}


- (int)lastgatimeForType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject lastgatime:atype[type].params];
}


-(int *(*)[4])bitDistributionForType:(int)type
{
    Agentlist *alp, *first;
    static int *count[4];

    CHECKTYPE(type)
    first = atype[type].first;
    if ([first->agid bitDistribution:&count cumulative:NO] < 0)
	return NULL;
    for (alp = first->next; alp != NULL; alp = alp->next)
	(void)[alp->agid bitDistribution:&count cumulative:YES];

    return &count;
}

-(double *)fMomentsForType:(int)type
{
    Agentlist *alp, *first;
    static double moment[6];
    int counttype = 1,nrules=1;
    int i;

    CHECKTYPE(type)
    first = atype[type].first;
    [first->agid fMoments:moment cumulative:NO];
    for (alp = first->next; alp != NULL; alp = alp->next) {
	nrules = [alp->agid fMoments:moment cumulative:YES];
        counttype++;
    }
    for(i=0;i<6;i++)
	moment[i]/= ((double)nrules*counttype);
    for(i=1;i<6;i+=2)
        moment[i] -= moment[i-1]*moment[i-1];

    return moment;
}


- prepareTypesForTrading
{
    register int type;

    for (type=0; type<numtypes; type++)
	if (atype[type].nagents > 0)
	    [atype[type].classObject prepareForTrading:atype[type].params];
    return self;
}


// ================== METHODS AT THE INDIVIDUAL AGENT LEVEL =================

- (const char *)shortnameOf:(int)idx
/*
 * Constructs a name with just two elements, e.g. "BS2:wej"
 */
{
    static char namebuf[8];
    short int type;
    
    CHECKIDX(idx)
    type = alist[idx].type;

    strcpy(namebuf, atype[type].typename);
    (void)[atype[type].nametree pathTo:alist[idx].nameidx
				    buf:namebuf+strlen(namebuf) len:5];
    return namebuf;
 }


- (const char *)fullnameOf:(int)idx
/*
 * Returns full name of agent #idx, in form BS-abc-def, BS:abc-def,
 * BSn-abc-def, or BSn:abc-def.
 */
{
    static char namebuf[MAXNAMELEVELS*4+4];
    short int type;
    
    CHECKIDX(idx)
    type = alist[idx].type;
    
    strcpy(namebuf, atype[type].typename);
    (void)[atype[type].nametree pathTo:alist[idx].nameidx
			    buf:namebuf+strlen(namebuf) len:MAXNAMELEVELS*4+1];
    return namebuf;
}


- (int)classOf:(int)idx
{
    CHECKIDX(idx)
    return atype[alist[idx].type].class;
}


- (int)typeOf:(int)idx
{
    CHECKIDX(idx)
    return (int)alist[idx].type;
}


- (Agent *)idOf:(int)idx
{
    CHECKIDX(idx)
    return alist[idx].agid;
}


- (BOOL)validAgent:agid
{
    register int a;

    for (a=0; a<numagents; a++)
	if (alist[a].agid == agid)
	    return YES;
    return NO;
}


- (int)nameidxOf:(int)idx
{
    CHECKIDX(idx)
    return alist[idx].nameidx;
}


- (BOOL)isEnabled:(int)idx
{
    CHECKIDX(idx)
    return alist[idx].enabled;
}


- enable:(int)idx
{
    CHECKIDX(idx)
    if (alist[idx].enabled)
	return self;
    
    alist[idx].enabled = YES;
    enabledlist_stale = YES;
    flaglist_stale = YES;
    [alist[idx].agid enabledStatus:YES];

    [marketApp updateEnabledStatus:idx];
    return self;
}


- disable:(int)idx
{
    CHECKIDX(idx)
    if (!alist[idx].enabled)
	return self;
    
    alist[idx].enabled = NO;
    enabledlist_stale = YES;
    flaglist_stale = YES;
    [alist[idx].agid enabledStatus:NO];

    [marketApp updateEnabledStatus:idx];
    return self;
}


- select:(int)idx
{
    register int a;
    
    if (idx == ALLAGENTS) {
	for (a=0; a<numagents; a++)
	    alist[a].selected = YES;
    }
    else {
	CHECKIDX(idx)
	alist[idx].selected = YES;
    }

    flaglist_stale = YES;
    return self;
}


- deselect:(int)idx
{
    register int a;
    
    if (idx == ALLAGENTS) {
	for (a=0; a<numagents; a++)
	    alist[a].selected = NO;
    }
    else {
	CHECKIDX(idx)
	alist[idx].selected = NO;
    }

    flaglist_stale = YES;
    return self;
}

@end
