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
created with its own instance of BFParams.  A lot of the really
complicated stuff that used to be in BFagent is now divided between
this class and BitVector.

This particular version of BFParams has the forecast monitoring up to
16 bits of information.  In the init method, the names of which 16
bits might be monitored are listed explicitly by name.  Then the World
object is asked for the bit number of each name, one-by-one.  That
sequential process fills up the array bitlist.  As a result, it is a
bit difficult to maintain this code and I wish there were an easy way
out of this. But I didn't find it yet (2001-11-01)

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


/*"Init does an awful lot of work for the BFParam object. It takes
  note of the number of condition bits that can be used and allocates
  space.  It also uses a special function ReadBitname to access the
  World object to find out which bit in the World represents which
  piece of information. 

  Following ASM-2.0, this version of BFParams has condbits set equal
  to 16 bits.  In the World, all possible bits are maintained, and one
  can ask for an attribute of the market history by a descriptive name
  like 'pr/d>1/4' and get back the integer value indicating which bit
  in the world keeps that information.  The integer keys for the
  moitored bits then get translated into the forecast's instance
  variable bitlist, an an array of integers. Whenever the BFagent
  needs to make sure than a forecast is up to date, it takes that
  bitlist and checks the conditions against the state of the world for
  the monitored bits.

  Again following ASM-2.0, we have here forecasts that only use a
  relatively small part of the world, 16 bits.  These particular BFCasts
  monitor 10 bits which measure the size of price*interest/dividend,
  4 more indicators of the change in moving averages of prices for
  various widths of the moving average, and two "dummy" bits fill out
  the array.

  It is possible to revise this method to allow monitoring of more
  bits.  To add more bits, it is necessary to change the condbits
  instance variable and then write out the names of some variables to
  be monitored inside this init method.  As long as the number
  condbits is correct, then the init method should recalculate the
  amount of storage required.  In future revisions of ASM, a cleanup
  and revision of this design should be a top priority.

  Another issue to consider is the assumption that all forecasts used
  by an agent will use a subset of a given set of bits from the world.
  Probably it would be better to put a bitlist into each forecast, and
  completely de-couple the forecasts.
"*/
- init;
{
  int i;

  int bits[MAXCONDBITS];
  //  double probs[MAXCONDBITS];
  //pj 2001-11-02. For ASM-2.2, I'm sticking with the ASM-2.0
  //"all agents have 16 bits" rule. But I'm not sticking with it
  //after that!  With USEALLBITS, I'm 
  //just experimenting to see what difference it makes.
  //
  BOOL USEALLBITS = NO;

  if (USEALLBITS!=YES)
    {
      bits[0] = ReadBitname("pr/d>1/4", specialbits);
      bits[1] = ReadBitname("pr/d>1/2", specialbits);
      bits[2] = ReadBitname("pr/d>3/4", specialbits);
      bits[3] = ReadBitname("pr/d>7/8", specialbits);
      bits[4] = ReadBitname("pr/d>1", specialbits);
      bits[5] = ReadBitname("pr/d>9/8", specialbits);
      bits[6] = ReadBitname("p>p5", specialbits);
      bits[7] = ReadBitname("p>p20", specialbits);
      bits[8] = ReadBitname("p>p100", specialbits);
      bits[9] = ReadBitname("p>p500", specialbits);
      bits[10] = ReadBitname("on", specialbits);
      bits[11] = ReadBitname("off", specialbits);
    }
  else
    {
      condbits = 60;
      
      for(i=0; i < condbits; i++) bits[i]=i;
    }
  bitlist= [ [self getZone] alloc: condbits * sizeof(int) ];
  problist=[ [self getZone] alloc: condbits * sizeof(double) ];


  for (i=0; i < condbits; i++) 
    {
      bitlist[i] = bits[i];
      //params->problist[i] = probs[i];
      problist[i] = bitprob;
    }

  // Allocate space for our world bits, clear initially

  condwords = (condbits+15)/16;

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

  return [super createEnd];
}

- (int*)getBitListPtr
{
  return bitlist;
}

/*"if passed a pointer to an array of integers of length size, this
  frees the old bitlist and puts the new one in its place"*/
- (void)copyBitList: (int *)x Length: (int) size
{
  int i;
  if (bitlist) [[self getZone] free: bitlist];
  bitlist = [[self getZone] alloc: size * sizeof(int) ];
  for (i=0; i < size; i++) 
    {
      bitlist[i] = x[i];
    }
}

- (double *)getProbListPtr
{
  return problist;
}

/*"if passed a pointer to a double with a given size, this frees the
  old bitlist and puts the new one in its place"*/
- (void)copyProbList: (double *) p Length: (int) size
{
  int i;
  if (problist) [[self getZone] free: problist];
  problist = [[self getZone] alloc: size * sizeof(double) ];
  for (i=0; i < size; i++) 
    {
      problist[i] = p[i];
    }
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


/*"Create a copy of this BFParams instance. Note this copies EVERY
  instance variable, one by one"*/
- (BFParams *) copy: (id <Zone>) aZone
{
  BFParams * bfParams;

  //Why not begin with a totally fresh instance created from scratch,
  //The way your old granny used to do it?
  if ((bfParams =
       [lispAppArchiver getWithZone: aZone key: "bfParams"]) == nil)
    raiseEvent(InvalidOperation,
               "Can't find the BFParam's parameters");
 
  //Then replace all those values granny liked (:

  bfParams->numfcasts =  numfcasts; 
  bfParams-> condwords = condwords ;
  bfParams->condbits = condbits; 
  bfParams->mincount = mincount; 
  bfParams->gafrequency = gafrequency; 
  bfParams->firstgatime = firstgatime;
  bfParams->longtime = longtime;	
  bfParams->individual = individual;
  bfParams->tauv = tauv;
  bfParams->lambda = lambda;
  bfParams-> maxbid = maxbid;
  bfParams->bitprob = bitprob;
  bfParams-> subrange = subrange;
  bfParams-> a_min = a_min;
  bfParams->a_max = a_max;
  bfParams-> b_min = b_min;
  bfParams->b_max = b_max;	
  bfParams->c_min = c_min;
  bfParams->c_max = c_max;	
  bfParams->a_range = a_range;
  bfParams->b_range = b_range;
  bfParams->c_range = c_range;	
  bfParams->newfcastvar = newfcastvar;	
  bfParams->initvar = initvar;	
  bfParams->bitcost = bitcost;	
  bfParams->maxdev = maxdev;	
  bfParams->poolfrac = poolfrac;	
  bfParams->newfrac = newfrac;	
  bfParams->pcrossover = pcrossover;
  bfParams->psocial = psocial;
  bfParams->startsocial = startsocial;
  bfParams->plinear = plinear;	
  bfParams->prandom = prandom;	
  bfParams->pmutation = pmutation;	
  bfParams->plong = plong;	     
  bfParams->pshort = pshort;	
  bfParams->nhood = nhood;	    
  bfParams->genfrac = genfrac;	
  bfParams->gaprob = gaprob;	
  bfParams->npool = npool;		
  bfParams->nnew = nnew;		
  bfParams->nnulls = nnulls;          
  bfParams->npoolmax = npoolmax;		
  bfParams->nnewmax =  nnewmax;		
  bfParams->ncondmax = ncondmax;		

  [bfParams copyBitList: bitlist Length: condbits];		
  [bfParams copyProbList: problist Length: condbits];	
  return bfParams;
}



- (void)lispOutDeep: stream
{
  [stream catStartMakeInstance: "BFParams"];
  [super lispOutVars: stream deep: YES];//Important to note this!!

  [super lispStoreIntegerArray: bitlist Keyword: "bitlist" Rank: 1 Dims: &condbits Stream: stream];

  [super lispStoreDoubleArray: problist Keyword: "problist" Rank: 1 Dims: &condbits Stream: stream];

  [stream catEndMakeInstance];
}





@end











