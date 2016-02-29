// The Santa Fe Stockmarket --  Implementation of the Scheduler.

// One instance of this class is used to manage the scheduling of a
// set of prespecified events.  When initialized it reads from a file
// a list of times at which particular events should occur.  Events
// may be specified to occur once only, or repetively with a certain
// period between a starting time and an ending time (for single-time
// events the starting and ending times are the same).  Once
// initialized, the Scheduler can be called in an event loop to return
// the events which occur at the current time t (global).  The Scheduler
// doesn't drive anything; it just responds to queries.

// PUBLIC METHODS
//
// - initFromFile:(const char *)filename
//	Initializes the Scheduler instance, reading the whole schedule
//	from the specified file.  The schedule can include both single-time
//	events and recurring events; see the sample file "timelist" for
//	details.
//
// - (int)maxtime
//	Returns the time until which the simulation should run so as to
//	process all the relevant events.  Only some types of events are
//	counted in this; see the event type table below.
//
// - (BOOL)haveEventsOfType:(EventType)type
//	Returns YES if there are any events of type "type" scheduled (at
//	any time: past, present, or future).  Event types are defined in
//	Scheduler.h; see also the event type table below.
//
// - (EventType)nextEvent
//	Returns the next event at the current time.  This method should
//	normally be called repeatedly at each time to process all the
//	events for that time.  It returns EV_NONE (the only negative
//	EventType) when there are no more events to process.  For each
//	event returned, the global variable "paramstring" is set to the
//	corresponding parameter string (or NULL if none).  There may be more
//	than one event of a given type.  Events are returned in order of
//	their starting times, and in order of appearance in the timelist
//	file for the same starting time.  
// 
// - (BOOL)nextEventOfType:(EventType)type
//	Like -nextEvent, but only looks for events of the specified type.
//	Returns YES as long as there's an event of type "type" to process
//	at the current time.  Messages to -nextEventOfType: and -nextEvent
//	are independent of each other.  Every time that -nextEventOfType: is
//	called with a different type, the list of potential messages is
//	searched again from the beginning, so to get all events of a given
//	type the calls for that type must be contiguous.
//
// - (int)extendScheduleForType:(EventType)type
//	Effectively extends the schedule for type "type" to infinity,
//	using the same increment as the last entry for that type.
//	If there are no entries of type "type", then one is added with
//	an increment of 1.  The new ending time (MAXINT) is returned.
//	
// - (int)currentIncrementForType:(EventType)type
//	Returns the increment currently in use for events of type "type",
//	if a repeating pattern is in effect, or a suitable increment that
//	was used recently, or will be used next.  This uses simple
//	heuristics to produce a increment suitable for imitating the current
//	behavior of a repeating process, without any guarantee of
//	verisimilitude.
//
// - writeParamsToFile:(FILE *)fp
//	Writes out the schedule that was read in originally.  The order
//	may not be exactly as was read in, but should be such as to give
//	identical results if re-read.  fp=NULL gives output to msgfile,
//	for use in gdb.
//
// - recordEventOfType:(EventType)type toFile:(FILE *)fp
//				withFormat:(const char *)format, ...;
//	Writes a line to file "fp" representing an event of type "type"
//	at the current time.  This is used when the user causes some
//	action (e.g. pressing a button) that can be scheduled, so that
//	rereading the output as part of the timelist file will reproduce
//	the event automatically.  The "format" argument is a printf-style
//	format string that specifies the parameter string that should
//	follow the event name.  It should be followed by further arguments
//	as necessary, as with printf.  It may be NULL or empty if no
//	parameter string is needed.
//
// GLOBAL VARIABLES NEEDED
//
// int t
//	Current time.  Assumes that this increases monotonically.
//
// int debug
//	Debugging bits.
//
// GLOBAL VARIABLES SUPPLIED
//
// const char *paramstring
//	Parameter string for the event returned by -nextEvent or
//	-nextEventOfType:.  Changed by each call to one of these
//	methods. 

// IMPLEMENTATION NOTES:
//
// 1. This could be made more space-efficient by using two types of
//    timelist entries in the list (or two lists), a full type and a short
//    type without endtime or modtime, for non-repetitive events.  A bit
//    in the "type" could indicate the difference.
// 2. This could perhaps be made faster for calls to -nextEventOfType: by
//    adding a linked list of items for each type.  But in fact we only
//    use this method for one type (display).

#import "global.h"
#import "Scheduler.h"
#import <stdlib.h>
#import <string.h>
#import <ctype.h>
#import "error.h"
#import "util.h"

struct eventtypeentry {
    EventType type;
    char *keyword;
    BOOL batch_waitfor;
    BOOL display_waitfor;
};

// Table of allowed types and their keywords.  Each type can have more
// than one keyword, in which case all are accepted on input and the first
// is used on output.
// The third and fourth columns specify whether or not the simulation should
// continue until all events with the specified keyword have been done, for
// the batch and display version respectively.  The stopping time for each
// version is the largest endtime in the timelist file with a corresponding
// entry marked by YES in this table.

static struct eventtypeentry eventtypetable[] = {
    {EV_DISPLAY,		"d",		NO,	YES},
    {EV_WRITEWORLD,		"w",		YES,	YES},
    {EV_WRITEAGENTINFO,		"a",		YES,	YES},
    {EV_ENABLEAGENT,		"E",		NO,	NO},
    {EV_ENABLEAGENT,		"enable",	NO,	NO},
    {EV_DISABLEAGENT,		"D",		NO,	NO},
    {EV_EVOLVE,			"e",		NO,	NO},
    {EV_SHOCK,			"s",		NO,	NO},
    {EV_RESETSHOCK,		"r",		NO,	NO},
    {EV_LEVEL,			"level",	NO,	NO},
    {EV_SET_SPECIALIST_PARAM,	"specialist",	NO,	NO},
    {EV_SET_DIVIDEND_PARAM,	"dividend",	NO,	NO},
    {EV_DEBUG,			"debug",	NO,	NO},
    {EV_NONE, NULL, NO, NO}			// Required last entry
};


// Constants
#define MAXLINE		80	// max chars - 1 on an input line

// Structure for each timelist entry.  There's a linked list of all these
// entries, initially sorted in order of increasing starttime.

struct timelistentry {
    struct timelistentry *next;
    EventType type;
    int starttime;
    int endtime;
    int modtime;
    char *string;
};

// Dummy first entry of linked list; first.next gives the first real entry.

static struct timelistentry first = {NULL, EV_NONE, MININT, MININT, 1, NULL};

// Pointer to last entry that has been completed (endtime < t).  The first
// active entry is at lastdone->next.  Up to and including the lastdone entry,
// the list consists of inactive entries, in the order in which they became
// inactive.  From lastdone->next onwards the entries are active (or yet to
// be activated), sorted in order of starttime.

static struct timelistentry *lastdone = &first;

// Global variables

const char *paramstring;	// Passes back the current parameter string


// Private methods
@interface Scheduler(Private)
- (struct eventtypeentry *)findentry:(EventType)type;
- showEvent:(struct timelistentry *)tptr;
@end


@implementation Scheduler

- initFromFile:(const char *)filename
/*
 * Initializes everything, reading in the event schedule from the specified
 * file.  See comments in the sample file "timelist" for details.
 */
{
    struct eventtypeentry *eptr;
    FILE *infile;
    char line[MAXLINE], buf[MAXINTCHARS], *ptr, *string;
    int starttime, endtime, modtime, status, c;
    struct timelistentry *new, **nextptr;
    
    maxbatchtime = MININT;   
    maxdisplaytime = MININT;   

// Open input file, loop to read lines 
    infile = OpenInputFile(filename, "time list");
    for (;;) {

    // Read one, two, or three integers, then keyword

	status = gettok(infile,buf,MAXINTCHARS);
	if (status < 0) break;
	if (status > 0) goto badtok;
	if (strcmp(buf,".") == EQ) break;
	starttime = (int) strtol(buf,&ptr,10);

	if (*ptr != EOS)
	    [self error:"Invalid starttime in %s file", filename];

	status = gettok(infile,buf,MAXINTCHARS);
	if (status!=0) goto badtok;
	endtime = (int) strtol(buf,&ptr,10);

	if (*ptr == EOS) {
	    status = gettok(infile,buf,MAXINTCHARS);
	    if (status!=0) goto badtok;
	    modtime = (int) strtol(buf,&ptr,10);

	    if (*ptr == EOS) {
		status = gettok(infile,buf,MAXINTCHARS);
		if (status!=0) goto badtok;
		ptr = buf;
	    }
	    else
		modtime = 1;
	}
	else {
	    endtime = starttime;
	    modtime = 1;
	}

    // Look up keyword (in buf)
	for (eptr=eventtypetable; eptr->type >= 0; eptr++)
	    if (strcmp(eptr->keyword,buf) == EQ) break;
	if (eptr->type < 0)
	    [self error:"Invalid event type in %s file: %s", filename, buf];

    // Read to end of line (or #) to get parameter string.  Remove
    // leading and trailing whitespace.
	string = NULL;
	if (fgets(line,MAXLINE,infile) == NULL) *line = EOS;
	linenumber++;	// Well, usually...
	for (ptr = line; (c=*ptr) != EOS && c != '\n' && c != '#'; ptr++) ;
	while (ptr > line && isspace(*--ptr)) ;
	*++ptr = EOS;
	for (ptr = line; isspace(*ptr); ptr++) ;
	if (*ptr != EOS)
	    string = strcpy((char *)getmem(sizeof(char)*(strlen(ptr)+1)),ptr);
	
    // Allocate and construct a new timelistentry
	new = (struct timelistentry *)getmem(sizeof(struct timelistentry));
	new->type = eptr->type;
	new->starttime = starttime;
	new->endtime = endtime;
	new->modtime = modtime;
	new->string = string;

    // Insert in list before first entry with larger starttime
	for (nextptr = &first.next; *nextptr != NULL;
			nextptr = &(*nextptr)->next)
	    if ((*nextptr)->starttime > starttime) break;
	new->next = *nextptr;
	*nextptr = new;

    // Record maximum endtimes seen
	if (endtime > maxbatchtime && eptr->batch_waitfor)
	    maxbatchtime = endtime;
	if (endtime > maxdisplaytime && eptr->display_waitfor)
	    maxdisplaytime = endtime;
    }

// All done
    abandonIfError("[Scheduler initFromFile:]");
    return self;

// Alternate exit for bad input
badtok:
    if (status>0) 
	[self error:"Token too long"];
    else
	[self error:"Unexpected EOF"];
    /*NOTREACHED*/
    return nil;
}


- (int)maxtime
{
    return (marketApp? maxdisplaytime: maxbatchtime);
}


- (BOOL)haveEventsOfType:(EventType)type;
{
    struct timelistentry *tptr;

#ifdef DEBUG
    (void)[self findentry:type];
#endif
    for (tptr = first.next; tptr; tptr=tptr->next)
	if (tptr->type == type)
	    return YES;
    return NO;
}


- (EventType)nextEvent
{
    static struct timelistentry *prev = NULL;
    static int prevt = MININT;
    struct timelistentry *tptr;
    int dt;

#ifdef DEBUG
    if (t < prevt)
	[self error:"Time went backwards: %d < %d", t, prevt];
#endif
    if (t > prevt) {
	prev = lastdone;
	prevt = t;
    }

    for (tptr = prev->next; tptr; prev = tptr, tptr = tptr->next) {
	dt = t - tptr->starttime;
	if (dt < 0) break;
	if (tptr->endtime < t) {	// Move to inactive part of list
	    if (prev == lastdone)
		lastdone = tptr;
	    else {
		prev->next = tptr->next;
		tptr->next = lastdone->next;
		lastdone->next = tptr;
		lastdone = tptr;
		tptr = prev;
	    }
	    continue;
	}
	if ((dt % tptr->modtime) == 0) {
	    paramstring = tptr->string;
	    prev = tptr;
	    if (debug&DEBUGEVENTS && !quiet && tptr->type != EV_DISPLAY)
		[self showEvent:tptr];
	    return tptr->type;
	}
    }
    
    return EV_NONE;
}


- (BOOL)nextEventOfType:(EventType)type
/*
 * Says whether event "type" occurs at the current time, and sets the global
 * "paramstring" appropriately if YES.  If this is called repeatedly
 * for the same arguments, it will set successive paramstrings for
 * that same time, and return NO when there are none left. 
 */
{
    static EventType prevtype = EV_NONE;
    static struct timelistentry *prev = NULL;
    static int prevt = MININT;
    struct timelistentry *tptr;
    int dt;

#ifdef DEBUG
    if (t < prevt)
	[self error:"Time went backwards: %d < %d", t, prevt];
    (void)[self findentry:type];
#endif
    if (t > prevt || type != prevtype) {
	prev = lastdone;
	prevt = t;
	prevtype = type;
    }

    for (tptr = prev->next; tptr; prev = tptr, tptr = tptr->next) {
	dt = t - tptr->starttime;
	if (dt < 0) break;
	if (tptr->endtime < t) {	// Move to inactive part of list
	    if (prev == lastdone)
		lastdone = tptr;
	    else {
		prev->next = tptr->next;
		tptr->next = lastdone->next;
		lastdone->next = tptr;
		lastdone = tptr;
		tptr = prev;
	    }
	    continue;
	}
	if (tptr->type == type && (dt % tptr->modtime) == 0) {
	    paramstring = tptr->string;
	    prev = tptr;
	    if (debug&DEBUGEVENTS && !quiet && type != EV_DISPLAY)
		[self showEvent:tptr];
	    return YES;
	}
    }
    
    return NO;
}

- (int)extendScheduleForType:(EventType)type;
/*
 * Effectively extends the schedule for type "type" to infinity,
 * using the same increment as the last entry (largest endtime) for that
 * type.  An increment of 1 is used if there are no entries of type "type".
 */
{
    struct timelistentry *tptr, *last;
    int maxendtime = MININT;

#ifdef DEBUG
    (void)[self findentry:type];
#endif

// Find the *active* entry (if any) with the latest endtime.  If there is
// one (unlikely), just modify its endtime and exit.
    last = NULL;
    for (tptr = lastdone->next; tptr; tptr = tptr->next)
	if (tptr->type == type && tptr->endtime > maxendtime) {
	    maxendtime = tptr->endtime;
	    last = tptr;
	}
    if (last) {
	last->endtime = MAXINT;
	return MAXINT;
    }

// Find the *inactive* entry (if any) with the latest endtime.
    last = NULL;
    for (tptr = first.next; tptr; tptr = tptr->next)
	if (tptr->type == type && tptr->endtime > maxendtime) {
	    maxendtime = tptr->endtime;
	    last = tptr;
	}
    
// Create a new entry
    tptr = (struct timelistentry *)getmem(sizeof(struct timelistentry));
    tptr->type = type;
    tptr->endtime = MAXINT;

// Copy values from last existing entry, or create default values
    if (last) {
	tptr->starttime = last->starttime;
	tptr->modtime = last->modtime;
	tptr->string = last->string;
    }
    else {
	tptr->starttime = MININT;
	tptr->modtime = 1;
	tptr->string = NULL;
    }

// Insert entry at start of active part of list
    tptr->next = lastdone->next;
    lastdone->next = tptr;

    return MAXINT;
}


- (int)currentIncrementForType:(EventType)type
/*
 * Returns the increment currently in use for type "type", or
 * (if none) the next increment that will be applicable, or 
 * (if none) the last increment that was applicable, or 
 * (if none) 1.
 * Before trading starts, it uses t=1 instead of the actual time.
 */
{
    int gap, tt;
    struct timelistentry *tptr;
    int lasttime = MININT;
    int mingap = MAXINT;
    struct timelistentry *nextentry = NULL;
    struct timelistentry *lastentry = NULL;

#ifdef DEBUG
    (void)[self findentry:type];
#endif

    tt = (t>=1? t: 1);
    
    for (tptr = first.next; tptr; tptr=tptr->next) {
	if (tptr->type != type)
	    continue;
	if (tt <= tptr->endtime && tt >= tptr->starttime)
	    return tptr->modtime;
	gap = tptr->starttime - tt;
	if (gap > 0 && gap <= mingap) {
	    mingap = gap;
	    nextentry = tptr;
	}
	if (tptr->endtime > lasttime) {
	    lasttime = tptr->endtime;
	    lastentry = tptr;
	}
    }
    if (nextentry)
	return nextentry->modtime;
    else if (lastentry)
	return lastentry->modtime;	// entry with largest endtime
    else
	return 1;
}


- writeParamsToFile:(FILE *)fp;
{
    struct timelistentry *tptr;
    struct eventtypeentry *eptr;

    if (fp == NULL) fp = stderr;	// For use in gdb

    for (tptr = first.next; tptr; tptr=tptr->next) {
	fprintf(fp,"%d",tptr->starttime);
	if (tptr->starttime != tptr->endtime) {
	    fprintf(fp," %d",tptr->endtime);
	    if (tptr->modtime != 1)
		fprintf(fp," %d", tptr->modtime);
	}
	for (eptr=eventtypetable; eptr->type >= 0; eptr++)
	    if (eptr->type == tptr->type) break;
	if (eptr->type < 0)
	    [self error:"Unknown event type '%d'", tptr->type];
	fprintf(fp, " %s", eptr->keyword);
	if (tptr->string)
	    fprintf(fp," %s\n", tptr->string);
	else
	    putc('\n',fp);
	if (tptr == lastdone)
	    fprintf(fp,"# Active entries:\n");
    }
    fprintf(fp,"# End of preprogrammed schedule\n");
    return self;
}


- recordEventOfType:(EventType)type toFile:(FILE *)fp
				withFormat:(const char *)format, ...
{
    struct eventtypeentry *eptr;
    va_list args;

    if (!fp)
	return self;

    eptr = [self findentry:type];    
    fprintf(fp,"%d %s", t, eptr->keyword);
    if (format && *format) {
	putc(' ',fp);
	va_start(args, format);
	vfprintf(fp, format, args);
	va_end(args);
    }
    putc('\n',fp);
    fflush(fp);
    return self;
}


- (struct eventtypeentry *)findentry:(EventType)type
{
    struct eventtypeentry *eptr;

    for (eptr=eventtypetable; eptr->type >= 0; eptr++)
	if (eptr->type == type) break;
    if (eptr->type < 0)
	[self error:"Invalid event type '%d'", type];
    return eptr;
}


- showEvent:(struct timelistentry *)tptr
{
    struct eventtypeentry *eptr;

    eptr = [self findentry:tptr->type];    
    if (tptr->string)
	Message("#e: %s %s", eptr->keyword, tptr->string);
    else
	Message("#e: %s", eptr->keyword);
    return self;
}

@end
