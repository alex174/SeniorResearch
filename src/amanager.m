// The Santa Fe Stock Market -- Implementation of AgentManager class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// One instance of this class is created.  It manages the lists of agents
// by class, type, and individual, deals with dispatching certain
// messages to all agents, and computes some agent-wide distributions.
// It also manages the selection of a new generation of agents when
// evolution of the agent population occurs.

// Some methods are provided here solely for use by the frontend, to
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
//    different initialization parameters.  The set of participating
//    agents is defined by the agentlist file, in which each line
//    referencing a given agent class defines a separate type and
//    specifies the file from which the initialization parameters for
//    that type are to be drawn.  E.g. the two lines
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
//    Each agent has an instance variable "p" that points to the appropriate
//    struct; e.g., p->pmutation might give an agent's mutation probability.
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
//    is initialized from the classnames[] table below.  The "class index"
//    of an agent is the index in this table for that agent's class.
//
// 2. The atype[] table lists all the types that were in use initially, in
//    their order in the agentlist file.  Evolution can cause extinction,
//    so some may drop out of use, but are still retained in the table.  The
//    "type index" of an agent is the index in this table for that agent's
//    type.
//
// 3. The alist[] table lists all agents, in the order displayed.  This
//    order is based on the order in the agentlist file, modified by the
//    cloning and deletion produced by evolution.  Clones of an agent are
//    adjacent in the list.  The "agent index" of an agent is the index in
//    this table for that agent.  The agent's "tag" is also set to this index.
//
// Pointers maintain linked lists of atype[] entries within each class, and
// alist[] entries within each type.  The first (types within a class) never
// changes, even if types end up with no agents through evolution, and is in
// the order in which types were specified.  The second (agents within a type)
// is modified by evolution but maintains agent order.
//
// These tables are only directly visible to AgentManager, but methods
// are provided to access the information.
//
// Class indices, type indices, and agent indices are used by many of the
// AgentManager's methods.  They're often referred to as class, type, and
// index respectively where no confusion seems likely.
//
// There's also a global list paramslist[] of pointers to the parameter
// structures for each agent type, indexed by the type index.  This is
// maintained and used by the agent class objects.

// GENERAL METHODS
//
// - init
//	Initializes the AgentManager and builds the aclass[] table.  The
//	AgentManager learns about the agent classes from the typenames[]
//	list below.   Edit that table to add or remove agent classes.
//
// - makeAgents:(const char *)filename
//	Makes and initializes all agent classes and instances, and the
//	atype[] and alist[] tables, based on the list in the agentlist
//	file "filename".   Each agent class object that's needed receives
//	an initClass: message.  Then, for each type, the class object
//	receives a createType:from: message and then an alloc message for each
//	agent to be constructed.  The agents receive initAgent:type: messages
//	after their allocation.  See comments above and in the default
//	agentlist file.
//
// - (int)numclasses
//	Returns the number of classes, whether in use or not.  This is the
//	length of the aclass[] table, and is fixed.
//
// - (int)numclassesInUse
//	Returns the number of classes that were in use initially; at later
//	times (after evolution) some of these classes may have zero agents,
//	but they are counted nevertheless.
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
// - (double)totalholding
//	Returns the sum of all the agents' holdings, which should remain
//	constant.
//
// - check
//	Checks integrity of the aclass[], atype[] and alist[] tables
//	(including some variables within the agent instances), and prints
//	some statistics using message().
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
//	a significant difference.  Used by the -dh option.
//
// - evolveAgents
//	Evolves the population of agents, constructing a new list with
//	membership proportional to fitness.  Agents no longer needed
//	are removed by sending them -free.  Clones of old agents are
//	created by sending them a -copy message.  Agents must respond
//	properly to both these messages, freeing or copying any extra
//	memory that they use.
//
// - level
//	Reinitializes agents' cash, wealth, and position.
//
// - (Agent **)allAgents:(int *)len
//	Returns a list of all agent id's, in order of agent index.  If
//	len is not NULL, *len is set to the length of the list (numagents).
//	The list is overwritten on each call.
//
// - (Agent **)enabledAgents:(int *)len
//	Returns a list of the agent id's of all enabled agents, in order of
//	agent index.  If len is not NULL, *len is set to the length of the
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
// - provideValues:(float *)values len:(int)len forProperty:(enum property)prop
//	Fills an array of values with the values (one per agent, in order)
//	of property "prop".  The properties are effectively defined by
//	this method (see also enum property in global.h).   "values"
//	is an array of length len passed by the caller.  Min(len,numagents)
//	values are returned.
//
// - getIndices:(int **)idxlist andStarts:(int **)startlist
//	Returns by reference two lists (allocated automatically) which
//	together specify which agents have each of the 4 possible flag codes
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
// - (int *(*)[4])bitDistributionForSelection:(int)type
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of the condition bits
//	used by currently selected agents of type "type", summed over all
//	rules/forecasters of all agents in the selection.  Returns NULL if
//	there are no selected agents of type "type" with condition bits.
//
// METHODS AT THE AGENT CLASS LEVEL
//
// - (int)classNumber:(int)class
//	Returns the class _number_ for the class with index "class".  The
//	class number is the ordinal number of creation of this class from
//	the initial agents list file.  It is never used as an index (use
//	the class index instead), but may be used in output specifications
//	(e.g., CLASS 2 ... END).
//
// - (int)classWithNumber:(int)n
//	Returns the class index for the class with number n, or -1 if
//	no match is found.  This is the reverse of -classNumber:.
//
// - (const char *)shortnameForClass:(int)class
//	Returns a shortname (2 characters, like "BS") for an agent class.
//	"class" is the class index -- an index into the aclass[] list.
//
// - (const char *)longnameForClass:(int)class
//	Returns a longname (e.g. "Bitstring") for an agent class.
//	"class" is the class index -- an index into the aclass[] list.
//
// - (int)classWithName:(const char *)name
//	Returns the class index for the class with the specified 2 character
//	name (e.g. BF), or -1 if no match is found.  "name" does not need to
//	be null-terminated; only two characters are read.  This method reports
//	on all possible classes (those in the classnames[] table), whether
//	or not they're in use.
//
// - (int)nagentsInClass:(int)class
//	Returns the number of agents in class "class".
//
// - (int)ntypesInClass:(int)class
//	Returns the number of types in class "class".
//
// - (Agent **)allAgents:(int *)len inClass:(int)class
//	Returns a list of all agent id's in class "class", in increasing
//	order of their indices.  If len is not NULL, *len is set to the
//	length of the list.  The list is overwritten on each call.
//
// - (Agent *)firstAgentInClass:(int)class
//	Returns the agent id of the first agent in class "class", or nil if
//	there are no such agents.
//
// - printDetails:(const char *)string to:(FILE *)fp forClass:(int)class
//	Sends the specified class a +printDetails:to:forClass: message,
//	telling it to write some class-specific (and "string"-specific)
//	information to the file specified by "fp".
//
// - (int)outputInt:(int)n forClass:(int)class
//
// - (double)outputReal:(int)n forClass:(int)class
//
// - (const char *)outputString:(int)n forClass:(int)class
//
// METHODS AT THE AGENT TYPE LEVEL
//
// In the following methods, "type" as an integer refers to the type index
// of a type, which is the index into the atype[] table.
//
// - (int)classOfType:(int)type
//	Returns the class index (index into aclass[]) for a type.
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
// - (Agent **)allAgents:(int *)len inType:(int)type
//	Returns a list of all agent id's in type "type", in increasing order
//	of their indices.  If len is not NULL, *len is set to the length
//	of the list.  The list is overwritten on each call.
//
// - (Agent *)firstAgentInType:(int)type
//	Returns the agent id of the first agent in type "type", or nil if
//	there are no such agents.
//
// - (int)nbitsForType:(int)type
//	Returns the number of condition bits used by agents of type "type",
//	or 0 if conditions bits aren't used.  Includes null bits.
//
// - (int)nonnullBitsForType:(int)type
//	Returns the number of condition bits used by agents of type "type",
//	or 0 if conditions bits aren't used.  Excludes null bits.
//
// - (int)nrulesForType:(int)type
//	Returns the number of rules or forecasters used by agents of type
//	"type", or 0 if rules/forecasters aren't used.
//
// - (int)lastgatimeForType:(int)type
//	Returns the latest time at which any agents of type "type" performed
//	a GA.  Returns MININTGR if no such GA has yet occured.  Used by the
//	frontend in deciding when certain displays need updating.
//
// - (int)lastgatimeInSelectionForType:(int)type
//	Returns the latest time at which any currently selected agents
//	of type "type" performed a GA.  Returns MININTGR if no such GA
//	has yet occured.  Used by the frontend in deciding when certain
//	displays need updating.
//
// - (int)agentBitForWorldBit:(int)n forType:(int)type
//	Returns the type's condition bit number for world bit n, or -1
//	if that world bit is not used by the type.
//
// - (int)worldBitForAgentBit:(int)n forType:(int)type
//	Returns the world bit number for the type's condition bit number
//	"bit", or NULLBIT for a null bit or for agents without condition bits.
//
// - (int (*)[4])countBit:(int)bit forType:(int)type
//	Returns a pointer to an array of 4 integers giving the numbers of
//	00's, 01's, 10's, and 11's for this types's condition bit n, among
//	all agents in the type and all rules/forecasters.  Types that don't
//	use condition bits return a pointer to 4 0's.  Each call overwrites
//	the last.
//
// - (int *(*)[4])bitDistributionForType:(int)type
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of the condition bits
//	used by agents of "type", summed over all rules/forecasters of all
//	agents of this type.  Agent classes that don't use condition bits
//	return NULL.
//
// - prepareTypesForTrading
//	Sends a +prepareTypeForTrading: message to all agent types that have
//	agents.
//
// - printDetails:(const char *)string to:(FILE *)fp forType:(int)type
//	Sends the appropriate class a +printDetails:to:forType: message,
//	telling it to write some type-specific (and "string"-specific)
//	information to the file specified by "fp".
//
// - (int)outputInt:(int)n forType:(int)type
//
// - (double)outputReal:(int)n forType:(int)type
//
// - (const char *)outputString:(int)n forType:(int)type
//
// METHODS AT THE INDIVIDUAL AGENT LEVEL
//
// In the following methods, "agent idx" means the agent with agent
// index idx.  idx is the index into the alist[] table.
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
// - (const char *)typenameOf:(int)idx
//	Returns the agent's 2-3 character type name (e.g. BS, BS2).
//
// - (const char *)classnameOf:(int)idx
//	Returns the agent's 2 character class name (e.g. BS).
//
// - (const char *)filenameOf:(int)idx
//	Returns the name of the file from which the parameters of this
//	agent were read, stripped of any path prefix.
//
// - (int)agentWithName:(const char *)name
//	Returns the index of the agent with the specified name,
//	or -1 if no match is found.  The name should be of the form
//	returned by -fullnameOf:.
//
// - (int)classOf:(int)idx
//	Returns the class index for agent idx.
//
// - (int)typeOf:(int)idx
//	Returns the type index for agent idx.

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


// IMPORTS
#include "global.h"
#include "agent.h"
#include "amanager.h"
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <math.h>
#include RUNTIME_DEFS
#include "procols.h"
#include "agent.h"
#include "nametree.h"
#include "output.h"
#include "random.h"
#include "error.h"
#include "util.h"

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
    {"Bitforecast", 	"BF"},
    {"Fixed_Forecast",	"FF"},
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
    int classnum;		// Ordinal number (1, 2, ...) of creation
    BOOL multipletypes;		// True if more than one type in class
} Agentclass;

// Structure for atype[] list -- list of agent types
// Items marked with # could be NULL
typedef struct AM_Agenttype {
    struct AM_Agenttype *next;	// Next type of same class (linked list)    #
    Agent *first;		// First agent in linked list of this type  #
    Agent *last;		// Last agent in linked list of this type   #
    char *fullfilename;		// Agent parameters filename
    char *filename;		// Agent parameters filename (last part)
    id classObject;		// Class object for this agent type
    id nametree;		// Name Tree for this agent type
    float initholding;		// Initial stockholding
    char typename[4];		// 2-3 characters, e.g. "BS" or "BS2"
    int nagents;		// Number of agents of this type
    short int class;		// This agent's class: index into aclass[]
    short int temp;		// Temporary for internal use
} Agenttype;

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
- createAgent:(int)a type:(int)type parent:(int)par position:(float)posn;
- (double)fitness:(const Agent *)agid;
@end


@implementation AgentManager

// ============================= GENERAL METHODS ==========================

// -------------------------------- init ----------------------------------
- init
/*
 * Initializes this object; sets up aclass[] table.
 */
{
    int class;
    Agentclass *cp;

// Set "stale" flags for arrays that certain methods return
    allclasslist_stale = YES;
    alltypelist_stale = YES;
    enabledlist_stale = YES;
    flaglist_stale = YES;
    colorlists_stale = YES;

// Count the agent types, allocate memory for aclass[] array
    for (numclasses=0; classnames[numclasses].longname != NULL; numclasses++) ;
    aclass = (Agentclass *) getmem(sizeof(Agentclass)*numclasses);

// Loop over all possible agent classes
    for (class=0; class<numclasses; class++) {
	cp = aclass + class;
	cp->classObject = nil;
	cp->ntypes = 0;
	cp->nagents = 0;
	cp->classnum = 0;
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
    [NameTree setDebugFile:msgfile];
#endif

    return self;
}


// ---------------------------- makeAgents: ------------------------------
- makeAgents:(const char *)alistfile
/*
 * Allocates and initializes all agents.
 */
{
    Agentclass *cp;
    Agenttype *tp;
    Aline *save;
    int n, class, type, anum, classcount;
    Aline *first, *last, **nextptr;
    id nametree;
    float initholding;
    char aClassName[12];
    char *filename, *ptr;

// Open agentlist file and check and store its contents.  We have to store
// it temporarily so we can see how many agents and types there are before
// actually creating the working arrays.  (Reading the file twice doesn't
// work if input files are concatenated.)
    alistfp = openInputFile(alistfile, "agentlist");
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

// Save input file pointer in case timelist file is "="
    saveInputFilePointer();

// Abandon if no agents
    if (numagents == 0)
	[self error:"No agents specified in %s file", alistfile];

// Allocate memory for atype[], alist[], indices, and paramslist
    atype = (Agenttype *) getmem(sizeof(Agenttype)*numtypes);
    alist = (Agent **) getmem(sizeof(Agent *)*numagents);
    indices = (int *) getmem(sizeof(int)*numagents);
    [Agent setnumtypes:numtypes];

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
    classcount = 0;
    for (save=first, type=0; save!=NULL; save=save->next, type++) {
	n = save->n;
	class = save->class;
	filename = save->filename;
	initholding = save->initholding;

	tp = atype + type;
	totalholding += initholding*n;
	cp = aclass + class;

	if (cp->classnum == 0) cp->classnum = ++classcount;

    // Link this type into linked list of types in this class
	if (cp->last == NULL)
	    cp->first = tp;
	else
	    cp->last->next = tp;
	tp->next = NULL;
	cp->last = tp;
	++cp->ntypes;

    // initialize atype[] entries
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

    // construct typename
	strcpy(tp->typename, cp->shortname);
	if (cp->multipletypes) {
	    if (cp->ntypes > ('9'-'1'+1 + 'z'-'a'+1))
		[self error:"Too many types in %s class", tp->typename];
	    tp->typename[2] = cp->ntypes<10? '0'+cp->ntypes: 'a'+cp->ntypes-10;
	    tp->typename[3] = EOS;
	}

    // instantiate a name tree
	tp->nametree = [[[[[NameTree alloc] init] setPathSeparator:'-']
			setPartialPathPrefix:':'] setMaxDepth:MAXNAMELEVELS];

    // create a type within this agent class (reads parameter file)
	[cp->classObject createType:type from:filename];

    // create the agents
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
    allclasslist_stale = YES;
    alltypelist_stale = YES;
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
		message("#n: NameTree for %-3s: %d nodes in use, %d bytes",
					    atype[type].typename,
					    [nametree checkIntegrity:msgfile],
					    [nametree memoryInUse]);

// Restore the file pointer from the agentslist file
    restoreInputFilePointer();

    return self;
}


// ---------------------------- getLine::: ------------------------------
- (int)getLine:(int *)class :(float *)ihptr :(char **)afilename
/*
 * Auxiliary method to read one line from the agentlist file
 */
{
#define MAXAGENTS	10000	/* just to detect stupid errors */
#if MAXAFILENAMELEN > MAXLONGNAMELEN
#define LINELEN	MAXAFILENAMELEN
#else
#define LINELEN	MAXLONGNAMELEN
#endif
    int i;
    char namebuf[LINELEN+1], buf[LINELEN+1];
    int status, c;
    char *ptr, *ertext;
    int n = 0;

// Get class name
    status = gettok(alistfp, buf, MAXLONGNAMELEN+1);
    if (status < 0 || strcmp(buf, "end") == EQ)
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

// Get number of agents
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

// Get initial holding
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

// Get parameter filename
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


// ---------------- createAgent:type:parent:position: ------------------
- createAgent:(int)a type:(int)type parent:(int)par position:(float)posn
/*
 * Creates an agent of type "type" for entry alist[a].  Sets initial
 * position to "posn", and makes it a child of "par".  All appropriate
 * instance variables and atype[type] entries are filled in or updated.
 */
{
    Agent *agid;
    char name[4];
    Agenttype *tp;

    CHECKTYPE(type)
    tp = atype + type;
    CHECKIDX(a)

// Instantiate, set position
    alist[a] = agid = [[tp->classObject alloc] initAgent:a type:type];
    agid->position = (double)posn;

// Construct name, tie into name tree
    agid->nameidx = [tp->nametree
			addName:[rng randomName:name] value:a parent:par];

// Link into list of this type of agent, increment count
    if (tp->last == NULL)
	tp->first = agid;
    else
	tp->last->next = agid;
    agid->next = NULL;
    tp->last = agid;

// Check if debugging
    if (debug&DEBUGAGENT)
	[agid check];

    return self;
}


// ---------------------------- numclasses ------------------------------
- (int)numclasses
{
    return numclasses;
}


// ------------------------- numclassesInUse ---------------------------
- (int)numclassesInUse
{
    int class, count;

    for (class = 0, count = 0; class < numclasses; class++)
	if (aclass[class].classnum > 0) count++;

    return count;
}


// ------------------------- numtypes ---------------------------
- (int)numtypes
{
    return numtypes;
}


// ------------------------- numagents ---------------------------
- (int)numagents
{
    return numagents;
}


// ------------------------- generation ---------------------------
- (int)generation
{
    return generation;
}


// ------------------------- totalholding ---------------------------
- (double)totalholding
{
    return totalholding;
}


// ------------------------- check ---------------------------
- check
/*
 * Checks integrity of the aclass[], atype[] and alist[] tables,
 * and prints some statistics.
 */
{
    Agent *agid, *prev;
    int class, type, a, aprev, nintype, ntypes, nagents, ninclass;
    int ntypesinclass;
    Agentclass *cp;
    Agenttype *tp, *tprev;
    const char *classname;
    BOOL *reflist;

// Allocate a list of flags to make sure no agent is referenced twice
    reflist = (BOOL *) getmem(sizeof(BOOL)*numagents);

// Clear some flags used to detect overlaps
    for (type=0; type < numtypes; type++)
	atype[type].temp = 0;
    for (a=0; a < numagents; a++)
	reflist[a] = NO;

    ntypes = 0;
    nagents = 0;
    for (class = 0; class < numclasses; class++) {
	cp = aclass + class;
	if (cp->ntypes > 0) {
	    classname = [cp->classObject name];
	    if (strncmp(classname, cp->shortname, 2) != EQ)
		message("*t: class name mismatch: %s %s", classname,
							    cp->shortname);
	    ninclass = 0;
	    ntypesinclass = 0;
	    tprev = NULL;
	    aprev = -1;
	    for (tp=cp->first; tp!=NULL; tprev=tp, tp=tp->next) {
		++ntypes;
		++ntypesinclass;
		type = tp-atype;
		if (tp->temp++)
		    message("*t: overlapping types: %s", tp->typename);
		if (tp->class != class)
		    message("*t: atype[].class mismatch: %s %d %d",
					    tp->typename, tp->class, class);
		if (strncmp(cp->shortname, tp->typename, 2) != EQ)
		    message("*t: type name mismatch: %s %s", tp->typename,
							    cp->shortname);
		message("#t: %3d %-3s %s", tp->nagents, tp->typename,
							    tp->filename);
		nintype = 0;
		prev = NULL;
		for (agid=tp->first; agid!=NULL; prev=agid, agid=agid->next) {
		    ++ninclass;
		    ++nintype;
		    ++nagents;
		    a = agid->tag;
		    if (a < 0 || a >= numagents)
			message("*t: invalid tag: %d", a);
		    else if (alist[a] != agid)
			message("*t: incorrect tag: %p, %p", alist[a], agid);
		    if (reflist[a]) {
			message("*t: overlapping agents: %s %d",
					    tp->typename, a);
			break;	// stop infinite loop
		    }
		    reflist[a] = YES;
		    if (a <= aprev)
			message("*t: Agents out of order %d %d", aprev, a);
		    aprev = a;
		    if (agid->type != type)
			message("*t: type mismatch: %s %d %d %d",
					    tp->typename, a, agid->type, type);
		    if (![tp->nametree validNode:agid->nameidx])
			message("*t: invalid nameidx: %s %d %d",
					    tp->typename, a, agid->nameidx);
		}
		if (nintype != tp->nagents)
		    message("*t: atype[].nagents mismatch: %s %d %d",
					tp->typename, nintype, tp->nagents);
		if (prev != tp->last)
		    message("*t: atype[].last mismatch: %s %d",
						    tp->typename, nintype);
	    }
	    if (ninclass != cp->nagents)
		message("*t: aclass[].nagents mismatch: %s %d %d",
					cp->shortname, ninclass, cp->nagents);
	    if (ntypesinclass != cp->ntypes)
		message("*t: aclass[].ntypes mismatch: %s %d %d",
				    cp->shortname, ntypesinclass, cp->ntypes);
	    if (tprev != cp->last)
		message("*t: aclass[].last mismatch: %s %d",
						cp->shortname, cp->ntypes);
	}
    }
    if (ntypes != numtypes)
	message("*t: numtypes mismatch: %d %d", ntypes, numtypes);
    if (nagents != numagents)
	message("*t: numagents mismatch: %d %d", nagents, numagents);
    for (a=0; a < numagents; a++)
	if (!reflist[a])
	    message("*t: agent %d unreferenced", a);
    free((void *)reflist);

    message("#t: %3d total (%d types)", numagents, numtypes);

    return self;
}


// ================== METHODS INVOVING ALL AGENTS ==================

// ---------------------- writeParamsToFile: ------------------------
- writeParamsToFile:(FILE *)fp
/*
 * Reconstructs the agent list and writes that out, then tells each
 * agent type to write its own parameters (if any).
 */
{
    int i;
    Agenttype *tp;
    char vbuf[MAXPATHLEN+32], dbuf[MAXPATHLEN+32];

    if (fp == NULL) fp = msgfile;	// For use in gdb

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
	[tp->classObject writeParamsToFile:fp forType:i];
    }
    return self;
}


// --------------------------- enableAll -----------------------------
- enableAll
{
    int a;

    for (a=0; a<numagents; a++)
	[alist[a] setEnabled:YES];

    enabledlist_stale = YES;
    flaglist_stale = YES;
    [marketApp updateEnabledStatus:-1];
    return self;
}


// --------------------------- checkAgents -----------------------------
- checkAgents
/*
 * Tells each agent to perform any internal checks
 */
{
    int a;

    for (a=0; a<numagents; a++)
	[alist[a] check];
    return self;
}


// ----------------------- checkTotalHolding -------------------------
- checkTotalHolding
/*
 * Checks that the sum of the positions (holdings) of the agents is
 * equal to the original value.
 */
{
    int a;
    double total, totalcash, totalwealth;
    Agent *agid;

    totalcash = totalwealth = total = 0.0;
    for (a=0; a<numagents; a++) {
	agid = alist[a];
	total += agid->position;
	totalcash += agid->cash;
	totalwealth += agid->wealth;
    }

    if (abs(total-totalholding) > 0.0001*totalholding)
	message("*h: totalholding error: %g %g",total,totalholding);
    message("#h: totals: h=%-9.5f c=%-10.4g w=%-10.4g",
				    total,totalcash,totalwealth);

    return self;
}


// ----------------------- evolveAgents -------------------------
- evolveAgents
/*
 * Creates a new generation of agents from the old one, choosing numbers
 * of agents proportional to fitness.  Disabled agents are treated specially;
 * they remain in the population (one copy of each), and remain disabled.
 * The enabled and selected flags propogate, so all the children of a
 * selected agent are selected.
 *
 * Normalization is applied to conserve the total number of shares and
 * the total cash constant after evolution.
 */
{
    int a, j, k;
    Newagentlist *nlp;
    int numdisabled, class, type, nclones;
    Agent *agid;
    Agenttype *tp;
    Newagentlist *newlist;
    id nametree;
    double thisfitness, total, norm, expected;
    char name[4];
    double beforecash, beforeshares, aftercash, aftershares;
    double shareratio, cashratio;

// Prepare frontend if any
    if (marketApp)
	[marketApp preEvolve];

// Allocate a temporary array to hold selection information for the old
// agents (fitness and desired) and temporary copies of some instance
// variables for the new agents.  These are copied back later.
    newlist = (Newagentlist *) getmem(sizeof(Newagentlist)*numagents);

// Find total cash and share holdings for renormalizing
    beforecash = beforeshares = 0.0;
    for(a=0; a<numagents;a++) {
	agid = alist[a];
	beforeshares += agid->position;
	beforecash   += agid->cash;
    }
    if (beforeshares <= 0.0) {
	message("*** enabled agents have no shares -- evolution inhibited");
	return self;
    }
    if (beforecash <= 0.0) {
	message("*** enabled agents have no cash -- evolution inhibited");
	return self;
    }

// Compute a fitness value for each agent, and a total.  Also deal with
// disabled agents.
    total = 0.0;
    numdisabled = 0;
    for (a=0; a<numagents; a++) {
	agid = alist[a];
	if (agid->enabled) {
	    thisfitness = [self fitness:agid];
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
	message(
	    "*** all enabled agents have zero fitness -- evolution inhibited");
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
	if (alist[a]->enabled) {
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
	if (newlist[a].fitness > 0.0 && newlist[a].fitness > drand(rng)) {
	    ++newlist[a].desired;
	    ++k;
	    newlist[a].fitness -= 2.0;
	}
    }

// Create the new list of agents, record types, make new names.  After
// this loop newlist[]'s newagid, newtype, newenabled, newselected, and
// newnameidx are the values for the new agents.  Order of agents
// is maintained.
    k = 0;
    for (a=0; a<numagents; a++) {
	agid = alist[a];
	type = (int)agid->type;
	nclones = newlist[a].desired;
	if (nclones > 0) {
	    for (j=0; j<nclones; j++) {
		nlp = newlist + k;
		nlp->newtype = type;
		nlp->newenabled = agid->enabled;
		nlp->newselected = agid->selected;
		if (j==0)
		    nlp->newagid = agid;
		else
		    nlp->newagid = [agid copy];
		nlp->newnameidx = [atype[type].nametree
						addName:[rng randomName:name]
						value:k parent:agid->nameidx];
		nlp->newagid->tag = k;	// Set the tag
		++k;
	    }
	}
    // Delete the agents we don't use at all
	else {
	    [atype[type].nametree removeLineage:agid->nameidx];
	    [agid free];
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
	nlp = newlist + a;
	alist[a] = agid = nlp->newagid;
	agid->type = nlp->newtype;
	agid->enabled = nlp->newenabled;
	agid->selected = nlp->newselected;
	agid->nameidx = nlp->newnameidx;
	tp = atype + agid->type;
	++tp->nagents;
	++aclass[tp->class].nagents;
	if (tp->last == NULL)
	    tp->first = agid;
	else
	    tp->last->next = agid;
	agid->next = NULL;
	tp->last = agid;
    }

// Release our temporary storage
    free(newlist);

// Compute net positions and cash
    aftercash = aftershares = 0.0;
    for(a=0; a<numagents;a++) {
	agid = alist[a];
	aftershares += agid->position;
	aftercash   += agid->cash;
    }

// Renormalize positions so total after = total before
    if (aftershares == 0.0) {
    	message("*** evolved agents have no shares -- fixed");
	aftershares = beforeshares/(double)numagents;
	for(a=0; a<numagents;a++)
	    alist[a]->position = aftershares;
    }
    else {
	shareratio = beforeshares/aftershares;
	for(a=0; a<numagents;a++)
	    alist[a]->position *= shareratio;
    }

// Renormalize cash so total after = total before
    if (aftercash == 0.0) {
    	message("*** evolved agents have no cash -- fixed");
	aftercash = beforecash/(double)numagents;
	for(a=0; a<numagents;a++)
	    alist[a]->cash = aftercash;
    }
    else {
	cashratio = beforecash/aftercash;
	for(a=0; a<numagents;a++)
	    alist[a]->cash *= cashratio;
    }

// Compute new wealth's
    for(a=0; a<numagents;a++) {
	agid = alist[a];
	agid->wealth = agid->cash + price*agid->position;
    }


// Set all "stale" bits, so lists are recomputed when next needed
    allclasslist_stale = YES;
    alltypelist_stale = YES;
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
    if (debug&(DEBUGNAMETREE) && !quiet) {
	for (type=0; type<numtypes; type++)
	    if ((nametree=atype[type].nametree) != nil) {
		message("#n: NameTree for %-3s: %d nodes in use, %d bytes",
					    atype[type].typename,
					    [nametree checkIntegrity:msgfile],
					    [nametree memoryInUse]);
	    }
    }

// Update the Output streams
    [Output postEvolve];

// Update the frontend if any
    if (marketApp)
	[marketApp postEvolve];

    return self;
}


// ---------------------------- fitness: ------------------------------
- (double)fitness:(const Agent *)agid
/*
 * Computes fitness of one agent for evolution of the population.  Fitness
 * values should be positive -- negative values will be taken as zero, and
 * will produce no offspring.
 */
{
    return agid->fitness;
}


// ------------------------------ level -------------------------------
- level
/*
 * level playing field
 */
{
    int a;
    Agent *agid;
    double newposition, newcash;

    newposition = totalholding/(double)numagents;
    newcash = initialcash + newposition*price;
    for(a=0; a<numagents;a++) {
	agid = alist[a];
	agid->position = newposition;
	agid->cash = initialcash;
	agid->wealth = newcash;
    }
    return self;
}


// --------------------------- allAgents: ----------------------------
- (Agent **)allAgents:(int *)len
{
    if (len) *len = numagents;
    return alist;
}


// --------------------------- enabledAgents: ----------------------------
- (Agent **)enabledAgents:(int *)len
{
    int a, i;
    static int nenabled;
    Agent *agid;

    if (enabledlist_stale) {
	if (!enabledlist)
	    enabledlist = (Agent **)getmem(sizeof(Agent *)*numagents);
	for (a=0, i=0; a<numagents; a++) {
	    agid = alist[a];
	    if (agid->enabled)
		enabledlist[i++] = agid;
	}
	nenabled = i;
	enabledlist_stale = NO;
    }
    if (len) *len = nenabled;
    return enabledlist;
}


// ------------------------------ flags -------------------------------
- (const short *)flags
/*
 * Returns a list of flags, one element for each agent, with each value
 * the OR of:
 *    ENABLEDBIT if enabled, 0 if not
 *    SELECTEDBIT if selected, 0 if not
 */
{
    int a;
    Agent *agid;

    if (flaglist_stale) {
	if (!flaglist)
	    flaglist = (short *)getmem(sizeof(short)*numagents);
	for (a=0; a<numagents; a++) {
	    agid = alist[a];
	    flaglist[a] = (agid->enabled?ENABLEDBIT:0) +
				    (agid->selected?SELECTEDBIT:0);
	}
	flaglist_stale = NO;
	colorlists_stale = YES;
    }
    return flaglist;
}


// -------------------- provideValues:len:forProperty: ------------------
- provideValues:(float *)values len:(int)len forProperty:(enum property)prop
{
    int a;
    int nvalues;
    double totalwealth;

    nvalues = numagents<len? numagents: len;

    switch (prop) {
    case WEALTH:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->wealth;
	break;
    case RELATIVEWEALTH:
	totalwealth = 0.0;
	for (a=0; a<numagents; a++)
	    totalwealth += alist[a]->wealth;
	if (totalwealth <= 0.0) totalwealth = 1.0;
	else totalwealth /= (double)numagents;
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->wealth/totalwealth;
	break;
    case POSITION:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->position;
	break;
    case STOCKVALUE:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->position*price;
	break;
    case CASH:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->cash;
	break;
    case PROFITMA:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->profit;
	break;
    case DEMAND:
	for (a=0; a<nvalues; a++)
	    values[a] = alist[a]->demand;
	break;
    case TARGET:
	for (a=0; a<nvalues; a++)
	    values[a] = (alist[a]->position + alist[a]->demand);
	break;
    default:
	[self error:"Illegal property %d",prop];
    }

    return self;
}


// ------------------------ getIndices:andStarts: ------------------------
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


// -------------------------- selectList:len: --------------------------
- selectList:(int *)list len:(int)len
/*
 * This method provides fast selection of a list of agents, without requiring
 * multiple messages to -select:.  All others are deselected.
 */
{
    int i;

    for (i=0; i<numagents; i++)
	alist[i]->selected = NO;

    for (i=0; i<len; i++) {
#ifdef DEBUG
	if (list[i] < 0 || list[i] >= numagents)
	    [self error:"Invalid index '%d' at %d in selection list", i,
								    list[i]];
#endif
	alist[list[i]]->selected = YES;
    }
    flaglist_stale = YES;
    return self;
}


// -------------------- bitDistributionForSelection: --------------------
- (int *(*)[4])bitDistributionForSelection:(int)type
/*
 * Construct bit distribution for current selection, assuming that type
 * gives the selected type.
 */
{
    Agent *agid;
    static int *count[4];

    for (agid = atype[type].first; agid != NULL; agid = agid->next)
	if (agid->selected) {
	    if ([agid bitDistribution:&count cumulative:NO] < 0)
		return NULL;
	    break;
	}
    if (agid == NULL)
	return NULL;
    for (agid = agid->next; agid != NULL; agid = agid->next)
	if (agid->selected)
	    (void)[agid bitDistribution:&count cumulative:YES];

    return &count;
}


// ================= METHODS AT THE AGENT CLASS LEVEL ==================

// ------------------------ classNumber: ------------------------
- (int)classNumber:(int)class
{
    CHECKCLASS(class)
    return aclass[class].classnum;
}


// ------------------------ classWithNumber: ------------------------
- (int)classWithNumber:(int)n
{
    int c;

    if (n <= 0) return -1;
    for (c=0; c < numclasses; c++)
	if (aclass[c].classnum == n) break;
    return (c < numclasses? c: -1);
}


// ------------------------ shortnameForClass: ------------------------
- (const char *)shortnameForClass:(int)class
{
    CHECKCLASS(class)
    return aclass[class].shortname;
}


// ------------------------ longnameForClass: ------------------------
- (const char *)longnameForClass:(int)class
{
    CHECKCLASS(class)
    return aclass[class].longname;
}


// --------------------------- classWithName: ---------------------------
- (int)classWithName:(const char *)name
{
    int class;
    char *classname;

    for (class=0; class<numclasses; class++) {
	classname = aclass[class].shortname;
	if (classname[0] == name[0] && classname[1] == name[1]) break;
    }
    return (class==numclasses? -1: class);
}


// ------------------------ nagentsInClass: ------------------------
- (int)nagentsInClass:(int)class
{
    CHECKCLASS(class)
    return aclass[class].nagents;
}


// ------------------------ ntypesInClass: ------------------------
- (int)ntypesInClass:(int)class
{
    CHECKCLASS(class)
    return aclass[class].ntypes;
}


// ------------------------ allAgents:inClass: ------------------------
- (Agent **)allAgents:(int *)len inClass:(int)class
{
    int a;
    static int oldclass = -1;
    static int ninclass = 0;
    Agenttype *tp;
    Agent *agid;

    CHECKCLASS(class)
    if (allclasslist_stale || class != oldclass) {
	if (!allclasslist)
	    allclasslist = (Agent **)getmem(sizeof(Agent *)*numagents);
	for (a=0, tp=aclass[class].first; tp!=NULL; tp=tp->next)
	    for (agid=tp->first; agid!=NULL; agid=agid->next)
		allclasslist[a++] = agid;
	ninclass = a;
	allclasslist_stale = NO;
	oldclass = class;
    }
    if (len) *len = ninclass;
    return allclasslist;
}


// ------------------------ firstAgentInClass: ------------------------
- (Agent *)firstAgentInClass:(int)class
/*
 * Returns the first agent in class "class".  We have to scan the types
 * within the class, because some might have disappeared through evolution.
 */
{
    Agenttype *tp;

    CHECKCLASS(class)
    for (tp=aclass[class].first; tp!=NULL; tp=tp->next)
	if (tp->first)
	    return tp->first;
    return nil;
}


// -------------------- printDetails:to:forClass: --------------------
- printDetails:(const char *)string to:(FILE *)fp forClass:(int)class
{
    CHECKCLASS(class)
    [aclass[class].classObject printDetails:string to:fp forClass:class];
    return self;
}


// -------------------- outputInt:forClass: --------------------------
- (int)outputInt:(int)n forClass:(int)class
{
    CHECKCLASS(class)
    return [aclass[class].classObject outputInt:(int)n forClass:class];
}


// -------------------- outputReal:forClass: -------------------------
- (double)outputReal:(int)n forClass:(int)class
{
    CHECKCLASS(class)
    return [aclass[class].classObject outputReal:(int)n forClass:class];
}


// -------------------- outputString:forClass: ------------------------
- (const char *)outputString:(int)n forClass:(int)class
{
    CHECKCLASS(class)
    return [aclass[class].classObject outputString:(int)n forClass:class];
}


// =================== METHODS AT THE AGENT TYPE LEVEL ==================

// --------------------------- classOfType: ---------------------------
- (int)classOfType:(int)type
{
    CHECKTYPE(type)
    return atype[type].class;
}


// ------------------------- typenameForType: -------------------------
- (const char *)typenameForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].typename;
}


// --------------------------- typeWithName: ---------------------------
- (int)typeWithName:(const char *)name
{
    int type;
    char *typename;

    for (type=0; type<numtypes; type++) {
	typename = atype[type].typename;
	if (typename[0] != name[0] || typename[1] != name[1]) continue;
	if (typename[2] == EOS || typename[2] == name[2]) break;
    }
    return (type==numtypes? -1: type);
}


// ------------------------- longnameForType: -------------------------
- (const char *)longnameForType:(int)type
{
    CHECKTYPE(type)
    return aclass[atype[type].class].longname;
}


// ------------------------- filenameForType: -------------------------
- (const char *)filenameForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].filename;
}


// ------------------------- nametreeForType: -------------------------
- nametreeForType:(int)type
{
    CHECKTYPE(type)
    return atype[type].nametree;
}


// ------------------------- nagentsOfType: -------------------------
- (int)nagentsOfType:(int)type
{
    CHECKTYPE(type)
    return atype[type].nagents;
}


// ------------------------ allAgents:inType: ------------------------
- (Agent **)allAgents:(int *)len inType:(int)type
{
    int a;
    static int oldtype = -1;
    static int nintype = 0;
    Agent *agid;

    CHECKTYPE(type)
    if (alltypelist_stale || type != oldtype) {
	if (!alltypelist)
	    alltypelist = (Agent **)getmem(sizeof(Agent *)*numagents);
	for (a=0, agid=atype[type].first; agid!=NULL; agid=agid->next)
	    alltypelist[a++] = agid;
	nintype = a;
	alltypelist_stale = NO;
	oldtype = type;
    }
    if (len) *len = nintype;
    return alltypelist;
}


// ------------------------ firstAgentInType: ------------------------
- (Agent *)firstAgentInType:(int)type
{
    CHECKTYPE(type)
    return atype[type].first;
}


// ------------------------- nbitsForType: -------------------------
- (int)nbitsForType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject nbitsForType:type];
}


// ------------------------- nonnullBitsForType: -------------------------
- (int)nonnullBitsForType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject nonnullBitsForType:type];
}


// ------------------------- nrulesForType: -------------------------
- (int)nrulesForType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject nrulesForType:type];
}


// ------------------------- lastgatimeForType: -------------------------
- (int)lastgatimeForType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject lastgatimeForType:type];
}


// -------------------- lastgatimeInSelectionForType: --------------------
- (int)lastgatimeInSelectionForType:(int)type
{
    Agent *agid;
    int greatest;

    greatest = MININTGR;
    for (agid = atype[type].first; agid != NULL; agid = agid->next)
	if (agid->selected && agid->lastgatime > greatest)
	    greatest = agid->lastgatime;

    return greatest;
}


// ------------------- agentBitForWorldBit:forType: -------------------
- (int)agentBitForWorldBit:(int)n forType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject agentBitForWorldBit:n forType:type];
}


// ------------------- worldBitForAgentBit:forType: -------------------
- (int)worldBitForAgentBit:(int)n forType:(int)type
{
    CHECKTYPE(type)
    return [atype[type].classObject worldBitForAgentBit:n forType:type];
}


// ---------------------- countBit:forType: -----------------------
- (int (*)[4])countBit:(int)bit forType:(int)type
{
    Agent *agid;
    int (*counts)[4];
    static int zeroes[4] = {0,0,0,0};

    CHECKTYPE(type)
    agid = atype[type].first;
    if (!agid) return &zeroes;

    counts = [agid countBit:bit cumulative:NO];
    for (agid = agid->next; agid != NULL; agid = agid->next)
	(void)[agid countBit:bit cumulative:YES];

    return counts;
}


// ---------------------- bitDistributionForType: -----------------------
- (int *(*)[4])bitDistributionForType:(int)type
{
    Agent *agid;
    static int *count[4];

    CHECKTYPE(type)
    agid = atype[type].first;
    if (!agid || [agid bitDistribution:&count cumulative:NO] < 0)
	return NULL;
    for (agid = agid->next; agid != NULL; agid = agid->next)
	(void)[agid bitDistribution:&count cumulative:YES];

    return &count;
}


// ----------------------- prepareTypesForTrading -----------------------
- prepareTypesForTrading
{
    int type;

    for (type=0; type<numtypes; type++)
	if (atype[type].nagents > 0)
	    [atype[type].classObject prepareTypeForTrading:type];
    return self;
}


// -------------------- printDetails:to:forType: --------------------
- printDetails:(const char *)string to:(FILE *)fp forType:(int)type
{
    CHECKTYPE(type)
    [atype[type].classObject printDetails:string to:fp forType:type];
    return self;
}


// -------------------- outputInt:forType: --------------------------
- (int)outputInt:(int)n forType:(int)type
{
    CHECKCLASS(type)
    return [atype[type].classObject outputInt:(int)n forType:type];
}


// -------------------- outputReal:forType: -------------------------
- (double)outputReal:(int)n forType:(int)type
{
    CHECKCLASS(type)
    return [atype[type].classObject outputReal:(int)n forType:type];
}


// -------------------- outputString:forType: -------------------------
- (const char *)outputString:(int)n forType:(int)type
{
    CHECKCLASS(type)
    return [atype[type].classObject outputString:(int)n forType:type];
}


// ================== METHODS AT THE INDIVIDUAL AGENT LEVEL =================

// --------------------------- shortnameOf: ---------------------------
- (const char *)shortnameOf:(int)idx
/*
 * Constructs a name with just two elements, e.g. "BS2:wej"
 */
{
    static char namebuf[8];
    short int type;

    CHECKIDX(idx)
    type = alist[idx]->type;

    strcpy(namebuf, atype[type].typename);
    (void)[atype[type].nametree pathTo:alist[idx]->nameidx
				    buf:namebuf+strlen(namebuf) len:5];
    return namebuf;
 }


// --------------------------- fullnameOf: ---------------------------
- (const char *)fullnameOf:(int)idx
/*
 * Returns full name of agent #idx, in form BS-abc-def, BS:abc-def,
 * BSn-abc-def, or BSn:abc-def.
 */
{
    static char namebuf[MAXNAMELEVELS*4+4];
    short int type;

    CHECKIDX(idx)
    type = alist[idx]->type;

    strcpy(namebuf, atype[type].typename);
    (void)[atype[type].nametree pathTo:alist[idx]->nameidx
			    buf:namebuf+strlen(namebuf) len:MAXNAMELEVELS*4+1];
    return namebuf;
}


// --------------------------- typenameOf: ---------------------------
- (const char *)typenameOf:(int)idx
{
    CHECKIDX(idx)
    return atype[(int)alist[idx]->type].typename;
}


// --------------------------- classnameOf: ---------------------------
- (const char *)classnameOf:(int)idx
{
    CHECKIDX(idx)
    return aclass[(int)atype[(int)alist[idx]->type].class].shortname;
}


// --------------------------- filenameOf: ---------------------------
- (const char *)filenameOf:(int)idx
{
    CHECKIDX(idx)
    return atype[(int)alist[idx]->type].filename;
}


// ------------------------------ agentWithName: ------------------------------
- (int)agentWithName:(const char *)name
{
    int t, node;
    id tree;

    if (strlen(name) < 4)
	return -1;
    t = [self typeWithName:name];
    if (t < 0)
	return -1;
    tree = atype[t].nametree;
    node = [tree indexForPath:name + ((name[2]=='-' || name[2]==':')?2:3)];
    return ((node > 0)? [tree valueOf:node] : -1);
}


// ------------------------------ classOf: ------------------------------
- (int)classOf:(int)idx
{
    CHECKIDX(idx)
    return atype[alist[idx]->type].class;
}


// ------------------------------ typeOf: ------------------------------
- (int)typeOf:(int)idx
{
    CHECKIDX(idx)
    return (int)alist[idx]->type;
}


// ------------------------------ idOf: ------------------------------
- (Agent *)idOf:(int)idx
{
    CHECKIDX(idx)
    return alist[idx];
}


// --------------------------- validAgent: ---------------------------
- (BOOL)validAgent:agid
{
    int a;

    for (a=0; a<numagents; a++)
	if (alist[a] == agid)
	    return YES;
    return NO;
}


// --------------------------- nameidxOf: ---------------------------
- (int)nameidxOf:(int)idx
{
    CHECKIDX(idx)
    return alist[idx]->nameidx;
}


// --------------------------- enable: ---------------------------
- enable:(int)idx
{
    Agent *agid;

    CHECKIDX(idx)
    agid = alist[idx];
    if (agid->enabled)
	return self;

    [agid setEnabled:YES];
    enabledlist_stale = YES;
    flaglist_stale = YES;

    [marketApp updateEnabledStatus:idx];
    return self;
}


// --------------------------- disable: ---------------------------
- disable:(int)idx
{
    Agent *agid;

    CHECKIDX(idx)
    agid = alist[idx];
    if (!agid->enabled)
	return self;

    [agid setEnabled:NO];
    enabledlist_stale = YES;
    flaglist_stale = YES;

    [marketApp updateEnabledStatus:idx];
    return self;
}


// --------------------------- isEnabled: ---------------------------
- (BOOL)isEnabled:(int)idx
{
    CHECKIDX(idx)
    return alist[idx]->enabled;
}


// --------------------------- select: ---------------------------
- select:(int)idx
{
    int a;

    if (idx == ALLAGENTS) {
	for (a=0; a<numagents; a++)
	    alist[a]->selected = YES;
    }
    else {
	CHECKIDX(idx)
	alist[idx]->selected = YES;
    }

    flaglist_stale = YES;
    return self;
}


// --------------------------- deselect: ---------------------------
- deselect:(int)idx
{
    int a;

    if (idx == ALLAGENTS) {
	for (a=0; a<numagents; a++)
	    alist[a]->selected = NO;
    }
    else {
	CHECKIDX(idx)
	alist[idx]->selected = NO;
    }

    flaglist_stale = YES;
    return self;
}

@end
