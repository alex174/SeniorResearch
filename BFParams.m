#import "BFParams.h"
#import "World.h"
#import <objectbase.h>


// Values in table of special bit names (negative, avoiding NULLBIT)
#define ENDLIST		-2
#define ALL		-3
#define SETPROB		-4
#define BADINPUT	-5
#define NOTFOUND	-6
#define EQ               0
#define NULLBIT         -1

struct keytable 
{
  const char *name;
  int value;
};

static struct keytable specialbits[] = 
{
  {"null", NULLBIT},
  {"end", ENDLIST},
  {".", ENDLIST},
  {"all", ALL},
  {"allbits", ALL},
  {"p", SETPROB},
  {"P", SETPROB},
  {"???", BADINPUT},
  {NULL,  NOTFOUND}
};


int ReadBitname(const char *variable, const struct keytable *table);

id
makeProbe (id obj, const char *ivarName)
{
  id probe = [VarProbe createBegin: [obj getZone]];
  [probe setProbedClass: [obj getClass]];
  [probe setProbedVariable: ivarName];
  return [probe createEnd];
}

double
getDouble (id obj, const char *ivarName)
{
  id probe = makeProbe (obj, ivarName);
  double ret = [probe probeAsDouble: obj];
  [probe drop];
  return ret;
}

int
getInt (id obj, const char *ivarName)
{
  id probe = makeProbe (obj, ivarName);
  int ret = [probe probeAsInt: obj];
  [probe drop];
  return ret;
}


@implementation BFParams

/*"BFParams is a class that holds parameter values that might be
needed by several classes, principally, BFagent, BFCast, or BitVector.
This class is currently designed so that, if one wants the values of
the variables here to be individualized, then each agent can be
created with its own instance of BFParams.

It got to be tedious and boring to maintain getX methods, one for each
instance variable, so if other classes want values out of this class,
they can use either of 2 routes. Both are used in BFagent.m, just to
keep up the variety. One way is the standard Objective-C method to
obtain instance variable values, the -> operator. Look for usages like
"privateParams->lambda". The other is a more Swarm oriented probe
mechanism. Notice the functions at the top of the file BFParams.m,
like getInt() and getDouble().  To get the lambda parameter, one can say
getDouble(privateParams,"lambda").  Either of these works, and it
frees us from the need to constantly add and edit get methods when we
add or change instance variables in here.

"*/

-(int)lastgatime
{
  return lastgatime;
}


- init;
{
  int i;

  int bits[MAXCONDBITS];
  //  double probs[MAXCONDBITS];
 
  bitlist= [ [self getZone] allocBlock: condbits * sizeof(int) ];
  problist=[ [self getZone] allocBlock: condbits * sizeof(double) ];

  bits[0] = ReadBitname("pr/d>1/4", specialbits);
  bits[1] = ReadBitname("pr/d>1/2", specialbits);
  bits[2] = ReadBitname("pr/d>3/4", specialbits);
  bits[3] = ReadBitname("pr/d>7/8", specialbits);
  bits[4] = ReadBitname("pr/d>1", specialbits);
  bits[5] = ReadBitname("pr/d>9/8", specialbits);
  bits[6] = ReadBitname("pr/d>5/4", specialbits);
  bits[7] = ReadBitname("pr/d>3/2", specialbits);
  bits[8] = ReadBitname("pr/d>2", specialbits);
  bits[9] = ReadBitname("pr/d>4", specialbits);
  bits[10] = ReadBitname("p>p5", specialbits);
  bits[11] = ReadBitname("p>p20", specialbits);
  bits[12] = ReadBitname("p>p100", specialbits);
  bits[13] = ReadBitname("p>p500", specialbits);
  bits[14] = ReadBitname("on", specialbits);
  bits[15] = ReadBitname("off", specialbits);

   for (i=0; i < condbits; i++) 
    {
      bitlist[i] = bits[i];
      //params->problist[i] = probs[i];
      problist[i] = bitprob;
    }
  

// Allocate space for our world bits, clear initially

   condwords = (condbits+15)/16;

   myworld = [[self getZone] allocBlock: condwords* sizeof(unsigned int)];

  for (i=0; i< condwords; i++)
    myworld[i] = 0;

// Check bitcost isn't too negative
  if (1.0+bitcost*(condbits-nnulls) <= 0.0)
    printf("The bitcost is too negative.");

// Compute derived parameters
  gaprob = 1.0/(double)gafrequency;
  a_range = a_max - a_min;
  b_range = b_max - b_min;
  c_range = c_max - c_min;

  npool = (int)(numfcasts*poolfrac + 0.5);
  nnew = (int)(numfcasts*newfrac + 0.5);
    
// Record maxima needed for GA working space
  if (npool > npoolmax) npoolmax = npool;
  if (nnew > nnewmax) nnewmax = nnew;
  if (condwords > ncondmax) ncondmax = condwords;
  //  fprintf(stderr,"BFParams init complete");
  return [super createEnd];
}

-(int*) getBitListPtr
{
  return bitlist;
}

- (double *) getProbListPtr
{
  return problist;
}

- (int *) getMyworldPtr
{
  return myworld;
}


int ReadBitname(const char *variable, const struct keytable *table)
/*
 * Like ReadKeyword, but looks up the name first as the name of a bit
 * and then (if there's no match) in table if it's non-NULL.
 */
{
  const struct keytable *ptr;
  int n;

  n = [World bitNumberOf: variable];
  
  if (n < 0 && table) 
    {
      for (ptr=table; ptr->name; ptr++)
	if (strcmp(variable,ptr->name) == EQ)
	  break;
      if (!ptr->name && strcmp(variable,"???") != EQ)
	printf("unknown keyword '%s'\n",variable);
      n = ptr->value;
    }
  return n;
}


@end











