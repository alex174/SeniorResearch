// The Santa Fe Stock Market -- Interface for Output class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _Output_h
#define _Output_h

#include <objc/Object.h>

@class Agent;

@interface Output : Object
{
    Output *next;
    Agent *agid;
    const char *name;
    const char *filename;
    const char *actual_filename;
    FILE *outputfp;
    struct varliststruct *varlist;
    struct varliststruct *accumulatelist;
    int headinginterval;
    int outputcount;
    int periodcount;
    int lasttime;
    int a;
    int class;
    int type;
}

// PUBLIC METHODS

+ initClass;
+ writeNamesToFile:(FILE *)fp;
- initWithName:(const char *)filehandle;
+ postEvolve;
+ (BOOL)openOutputStreams;
+ closeOutputStreams;
+ updateAccumulators;
+ resetAccumulators;
+ writeOutputToStream:(const char *)name;
+ resetAccumulatorsForStream:(const char *)name; 
+ writeOutputSpecifications:(FILE *)fp;

@end

#endif /* _Output_h */




