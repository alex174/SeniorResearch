// The Santa Fe Stockmarket -- Interface for Scheduler class

#import <objc/Object.h>

// This enum numbers the possible event types.  Except inside the
// Scheduler, these events are known only by these constants.  To add
// a new event, you need to add to eventtypetable[] in Scheduler.m.
typedef enum {
	EV_NONE=-1,	// Signals no event etc.  Must be only negative one.
	EV_DISPLAY=0,
	EV_WRITEWORLD,
	EV_WRITEAGENTINFO,
	EV_ENABLEAGENT,
	EV_DISABLEAGENT,
	EV_EVOLVE,
	EV_SHOCK,
	EV_RESETSHOCK,
	EV_LEVEL,
	EV_SET_SPECIALIST_PARAM,
	EV_SET_DIVIDEND_PARAM,
	EV_DEBUG
} EventType; 


@interface Scheduler: Object
{
    int maxbatchtime;
    int maxdisplaytime;
    int maxtype;
}

// PUBLIC METHODS

- initFromFile:(const char *)filename;
- (int)maxtime;
- (BOOL)haveEventsOfType:(EventType)type;
- (EventType)nextEvent;
- (BOOL)nextEventOfType:(EventType)type;
- (int)extendScheduleForType:(EventType)type;
- (int)currentIncrementForType:(EventType)type;
- writeParamsToFile:(FILE *)fp;
- recordEventOfType:(EventType)type toFile:(FILE *)fp
				withFormat:(const char *)format, ...;

@end

