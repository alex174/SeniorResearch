// Code for a dumb agent that simply buys or sells on the basis of one
// of the "world" bits.

#import "global.h"
#import "DUagent.h"
#import <stdlib.h>
#import "World.h"
#import "util.h"
#import "error.h"

// Local variables
static int class;
static struct DUparams *params;


@implementation DUagent

+ initClass:(int)myclass
{
    class = myclass;	// save our class
    return self;
}


+ (void *)createType:(int)mytype :(const char *)filename
{
// Allocate space for our parameters
    params = (struct DUparams *)getmem(sizeof(struct DUparams));
    params->class = class;	// not used, but useful in debugger
    params->type = mytype;	// not used, but useful in debugger
   
// Open parameter file for DUagents
    (void) OpenInputFile(filename, "DU agent parameters");

// Read in the parameters
    params->bidsize = ReadDouble("bidsize",-100.0,100.0);
    params->keybit = ReadBitname("keybit",NULL);
    abandonIfError("[DUagent +createType::]");

/* Note that, as well as returning it, the current value of "params" is
 * available as a static variable in this file.  initAgent: uses that. */
    return (void *)params;
}


+ writeParams:(void *)theParams ToFile:(FILE *)fp
{
    char buf[16];
    struct DUparams *parm = (struct DUparams *)theParams;
    
    showdble(fp, "bidsize", parm->bidsize);
    sprintf(buf,"keybit (%d)", parm->keybit);
    showstrng(fp, buf, [World nameOfBit:parm->keybit]);
    return self;
}


- initAgent:(int)mytag
{

// Initialize generic variables common to all agents, link into list
    [super initAgent:mytag];

    p = params;		/* last parameter values set by +createAgent:: */
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
{
    double dummyslope;

    demand = (realworld[p->keybit] == 1? p->bidsize: -p->bidsize);
    return [super constrainDemand:&dummyslope:trialprice];
}


@end
