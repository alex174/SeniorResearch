#include <misc.h> // random
// Interface for random.m

// Define the basic generator.  See random.m comments.
#define RANDOM		random()
#define MAXRAND         ((int)0x7fffffff)

#define RANDFACT	(1.0/(MAXRAND+1.0))
#define URANDFACT	(2.0/MAXRAND)

#define irand(x)	((int)(((double)RANDOM)*RANDFACT*(double)(x)))
#define drand()		(((double)RANDOM)*RANDFACT)
#define urand()		(((double)RANDOM)*URANDFACT-1.0)

extern double normal(void);
extern char *randomName(char *buf);
extern int randset(int seed);
extern void saveRandom(void);
extern void restoreRandom(void);
