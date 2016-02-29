// The Santa Fe Stockmarket -- Interface for AgentManager

#import <objc/Object.h>

@class Agent;

// Maximum retained hierarchical levels in agent names
#define MAXNAMELEVELS		6

// Maximum characters in a "long" agent-type name
#define MAXLONGNAMELEN		20

// Symbolic constant for -select: and -deselect:
#define ALLAGENTS	-1

// Symbolic constants for flags (don't change!)
#define SELECTEDBIT	2
#define ENABLEDBIT	1
   
@interface AgentManager:Object
{
// Note: the AM_* structures are defined in the .m file; there's no need
// for users to know about them, and no subclassing of this class.
    double totalholding;	// Initial sum of agent holdings
    struct AM_Agentclass *aclass;   // Dynamically allocated array aclass[]
    struct AM_Agenttype *atype;	    // Dynamically allocated array atype[]
    struct AM_Agentlist *alist;	    // Dynamically allocated array alist[]
    Agent **alllist;		// Array returned by allAgents: 
    Agent **enabledlist;	// Array returned by enabledAgents: 
    short *flaglist;		// Array returned by flags 
    int *indices;		// Array returned by getIndices:andStarts:
    int starts[5];		// Array returned by getIndices:andStarts:
    FILE *alistfp;		// Agent list file pointer
    int numclasses;		// Number of classes (compiled in)
    int numtypes;		// Number of types defined initially
    int numagents;		// Number of Agents
    int generation;		// Generation of agents (initially 1)
    BOOL alllist_stale;		// YES if alllist may be stale
    BOOL enabledlist_stale;	// YES if enabledlist may be stale
    BOOL flaglist_stale;	// YES if flaglist may be stale
    BOOL colorlists_stale;	// YES if indices or starts may be stale
}

// GENERAL METHODS
- init;
- makeAgents:(const char *)filename;
- (int)numclasses;
- (int)numclassesInUse;
- (int)numtypes;
- (int)numagents;
- (int)generation;
- (double)totalholding;
- check;

// METHODS INVOVING ALL AGENTS
- writeParamsToFile:(FILE *)fp;
- enableAll;
- checkAgents;
- checkTotalHolding;
- evolveAgents;
- level;
- printAgentInfo:(FILE *)fp;
- (Agent **)allAgents:(int *)len;
- (Agent **)enabledAgents:(int *)len;
- (const short *)flags;
- getValues:(float *)values len:(int)len forProperty:(enum property)prop;
- getIndices:(int **)idxlist andStarts:(int **)startlist;
- selectList:(int *)list len:(int)len;
- (int)lastgatimeForSelection:(int)type;
- (int *(*)[4])bitDistributionForSelection:(int)type;

// METHODS AT THE AGENT CLASS LEVEL
- (const char *)shortnameForClass:(int)class;
- (const char *)longnameForClass:(int)class;
- (int)nagentsInClass:(int)class;

// METHODS AT THE AGENT TYPE LEVEL
- (int)classOfType:(int)type;
- (const char *)typenameForType:(int)type;
- (int)typeWithName:(const char *)name;
- (const char *)longnameForType:(int)type;
- (const char *)filenameForType:(int)type;
- nametreeForType:(int)type;
- (int)nagentsOfType:(int)type;
- (int)nbitsForType:(int)type;
- (int)nrulesForType:(int)type;
- (const char *)descriptionOfBit:(int)bit forType:(int)type;
- (int)lastgatimeForType:(int)type;
- (int *(*)[4])bitDistributionForType:(int)type;
- (double *)fMomentsForType:(int)type;
- prepareTypesForTrading;

// METHODS AT THE INDIVIDUAL AGENT LEVEL
- (const char *)shortnameOf:(int)idx;
- (const char *)fullnameOf:(int)idx;
- (int)classOf:(int)idx;
- (int)typeOf:(int)idx;
- (Agent *)idOf:(int)idx;
- (BOOL)validAgent:agid;
- (int)nameidxOf:(int)idx;
- enable:(int)idx;
- disable:(int)idx;
- (BOOL)isEnabled:(int)idx;
- select:(int)idx;
- deselect:(int)idx;

@end
