// The Santa Fe Stock Market -- Global declarations
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This file is included in almost every source file, either directly or
// via Frontend.h.  It defines some widely-used constants, and declares
// some global variables.  Global variables spoil the encapsulation of
// the object framework, but are used for efficiency and code simplicity.

#ifndef _global_h
#define _global_h

#include "config.h"
#include <stdarg.h>	// Must precede stdio.h in gcc
#include <stdio.h>	// For FILE
#include <objc/objc.h>

// Useful constants
#define MAXINTGR	((int)0x7fffffff)	/* maximum integer */
#define MININTGR	((int)0x80000000)	/* minimum integer */
#define MAXINTCHARS	12	/* 1 + maximum digits in an integer */
#define MAXDOUBLECHARS	24	/* 1 + maximum digits in a double */
#define MAXSTRING	81	/* 1 + maximum chars in an input string */
#define EOS		'\0'
#define EQ		0
#define UNKNOWN		(BOOL)2			/* 3rd case for a BOOL */
#define NULLBIT		-1		/* bit number for an inactive bit */

// Global names
#define	PROJECTTITLE	"The Santa Fe Stock Market"
#define ALLENDNAME	"end"		// End of all output specifications
#define ALLBITSNAME	"allbits"	// All available condition/world bits

// Structure for key-value tables
struct keytable {
    const char *name;
    int value;
};

// Property codes for AgentManager and frontend
enum property {
	WEALTH,
	RELATIVEWEALTH,
	POSITION,
	STOCKVALUE,
	CASH,
	PROFITMA,
	TARGET,
	DEMAND
};

// Global variables defined in control.m
extern int t;
extern int lasttime;
extern int runid;
extern int linenumber;
extern long mseed;
extern long olddseed;
extern FILE *logfile;
extern id rng;
extern id specialist;
extern id dividendProcess;
extern id agentManager;
extern id scheduler;
extern id world;
extern id marketApp;

// Global variables defined in World.m
extern double price;
extern double oldprice;
extern double dividend;
extern double olddividend;
extern double profitperunit;
extern double returnratio;
extern double vol;
extern int nmas;
extern int matime[];
extern double pmav[];
extern double oldpmav[];
extern double dmav[];
extern double olddmav[];
extern double volt[];
extern int nworldbits;
extern int realworld[];

// Global variables defined in Specialist.m
extern double bidtotal;
extern double offertotal;
extern double volume;
extern double oldbidtotal;
extern double oldoffertotal;
extern double oldvolume;
extern int auctioncount;

extern double intrate;
extern double intratep1;
extern double minholding;
extern double mincash;
extern double initialcash;
extern BOOL exponentialMAs;

// Global variables defined in Scheduler.m
extern const char *paramstring;

// Global variables defined in error.m
extern FILE *msgfile;
extern int debug;
extern BOOL quiet;

#endif /* _global_h */
