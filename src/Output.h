// The Santa Fe Stockmarket -- Interface for Output class

#import <objc/Object.h>

@interface Output: Object
{
    Output *next;
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
}

// PUBLIC METHODS

+ writeNamesToFile:(FILE *)fp;
- initWithName:(const char *)filehandle;
+ (BOOL)openOutputStreams;
- (BOOL)openOutputStream;
+ closeOutputStreams;
- closeOutputStream;
+ updateAccumulators;
- updateAccumulators;
+ resetAccumulators;
- resetAccumulators;
+ writeOutputStream:(const char *)name;
- writeOutputStream;
+ showOutputStreams:(FILE *)fp;
- showOutputStream:(FILE *)fp;

@end
