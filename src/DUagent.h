// Interface for DUagent class

#import "Agent.h"

// Parameters common to all agents in a DU type
struct DUparams {
    double bidsize;
    int class;
    int type;
    int keybit;
} ;


@interface DUagent:Agent
{
    struct DUparams	*p;
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)mytype;
+ (void *)createType:(int)mytype :(const char *)filename;
+ writeParams:(void *)theParams ToFile:(FILE *)fp;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)mytag;

// PUBLIC INSTANCE METHODS ADDED BY THIS CLASS
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;

@end
