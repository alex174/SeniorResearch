// The Santa Fe Stock Market -- Interface for AgentManager class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _AgentManager_h
#define _AgentManager_h

#include <objc/Object.h>

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

@interface AgentManager : Object
{
// Note: the AM_* structures are defined in the .m file; there's no need
// for users to know about them, and no subclassing of this class.
    double totalholding;	// Initial sum of agent holdings
    struct AM_Agentclass *aclass; // Dynamically allocated array aclass[]
    struct AM_Agenttype *atype;	// Dynamically allocated array atype[]
    Agent **alist;		// Dynamically allocated array alist[]
    Agent **allclasslist;	// Array returned by -allAgents:inClass:
    Agent **alltypelist;	// Array returned by -allAgents:inType:
    Agent **enabledlist;	// Array returned by -enabledAgents:
    short *flaglist;		// Array returned by -flags
    int *indices;		// Array returned by -getIndices:andStarts:
    int starts[5];		// Array returned by -getIndices:andStarts:
    FILE *alistfp;		// Agent list file pointer
    int numclasses;		// Number of classes (compiled in)
    int numtypes;		// Number of types defined initially
    int numagents;		// Number of agents
    int generation;		// Generation of agents (initially 1)
    BOOL allclasslist_stale;	// YES if allclasslist may be stale
    BOOL alltypelist_stale;	// YES if alltypelist may be stale
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
- (Agent **)allAgents:(int *)len;
- (Agent **)enabledAgents:(int *)len;
- (const short *)flags;
- provideValues:(float *)values len:(int)len forProperty:(enum property)prop;
- getIndices:(int **)idxlist andStarts:(int **)startlist;
- selectList:(int *)list len:(int)len;
- (int *(*)[4])bitDistributionForSelection:(int)type;

// METHODS AT THE AGENT CLASS LEVEL
- (int)classNumber:(int)class;
- (int)classWithNumber:(int)n;
- (const char *)shortnameForClass:(int)class;
- (const char *)longnameForClass:(int)class;
- (int)classWithName:(const char *)name;
- (int)nagentsInClass:(int)class;
- (int)ntypesInClass:(int)class;
- (Agent **)allAgents:(int *)len inClass:(int)class;
- (Agent *)firstAgentInClass:(int)class;
- printDetails:(const char *)string to:(FILE *)fp forClass:(int)class;
- (int)outputInt:(int)n forClass:(int)class;
- (double)outputReal:(int)n forClass:(int)class;
- (const char *)outputString:(int)n forClass:(int)class;

// METHODS AT THE AGENT TYPE LEVEL
- (int)classOfType:(int)type;
- (const char *)typenameForType:(int)type;
- (int)typeWithName:(const char *)name;
- (const char *)longnameForType:(int)type;
- (const char *)filenameForType:(int)type;
- nametreeForType:(int)type;
- (int)nagentsOfType:(int)type;
- (Agent **)allAgents:(int *)len inType:(int)type;
- (Agent *)firstAgentInType:(int)type;
- (int)nbitsForType:(int)type;
- (int)nonnullBitsForType:(int)type;
- (int)nrulesForType:(int)type;
- (int)lastgatimeForType:(int)type;
- (int)lastgatimeInSelectionForType:(int)type;
- (int)agentBitForWorldBit:(int)n forType:(int)type;
- (int)worldBitForAgentBit:(int)n forType:(int)type;
- (int (*)[4])countBit:(int)bit forType:(int)type;
- (int *(*)[4])bitDistributionForType:(int)type;
- prepareTypesForTrading;
- printDetails:(const char *)string to:(FILE *)fp forType:(int)type;
- (int)outputInt:(int)n forType:(int)type;
- (double)outputReal:(int)n forType:(int)type;
- (const char *)outputString:(int)n forType:(int)type;

// METHODS AT THE INDIVIDUAL AGENT LEVEL
- (const char *)shortnameOf:(int)idx;
- (const char *)fullnameOf:(int)idx;
- (const char *)typenameOf:(int)idx;
- (const char *)classnameOf:(int)idx;
- (const char *)filenameOf:(int)idx;
- (int)agentWithName:(const char *)name;
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

#endif /* _AgentManager_h */
