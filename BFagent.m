// Code for a "bitstring forecaster" (BF) agent

// +init
//     Initializes the class, setting parameters and allocating space
//     for arrays.
//
// +didInitialize
//     Tells the agent class object that initialization (including creation
//     of agents) is finished.
//
// +prepareForTrading
//	Sent for each type of this class, announcing the start of a new
//	trading period.  The class object can use this to set up any common
//	information for use by getDemandandSlope:forPrice: etc.  The
//	pointer to "params" identifies the particular type.  These class
//	messages are follwed by -prepareForTrading messages to each
//	enabled instance.
//
// +(BOOL)lastgatime
//	Returns the most recent time at which a GA ran for any agent of
//	this type.  
//
// -free
//      frees space used by forecast lists
//
// -(int *(*)[4])bitDistribution;
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of this agent's
//	condition bits, summed over all rules/forecasters.  Agents that
//	don't use condition bits return NULL.  This uses the method
//	-bitDistribution:cumulative: described below that is provided by
//	subclasses that have condition bits.
//
// -(int)nbits
//	Returns the number of condition bits used by this agent, or 0 if
//	condition bits aren't used.
//
// -(const char *)descriptionOfBit: (int)bit
//	If the agent uses condition bits, returns a description of the
//	specified bit.  Invalid bit numbers return an explanatory message.
//	Agents that don't use condition bits return NULL.
//
// -(int)nrules
//	Returns the number of rules or forecasters used by this agent, or 0
//	if rules/forecasters aren't used.
//
// -(int)lastgatime
//	Returns the last time at which an agent's genetic algorithm was run.
//	Agents that don't use a genetic algorithm return MININT.  This may
//	be used to see if the bit distribution might have changed, since
//	a change can only occur through a genetic algorithm.
//
// -(int)bitDistribution:(int *(*)[4])countptr cumulative: (BOOL)cum
//	Places in (*countptr)[0] -- (*countptr)[3] the addresses of 4
//	arrays, (*countptr)[0][i] -- (*countptr)[3][i], which are filled
//	with the number of bits that are 00, 01, 10, or 11 respectively,
//	for each condition bit i= 0, 1, nbits-1, summed over all rules or
//	forecasters.  Returns nbits, the number of condition bits.  If
//	cum is YES, adds the new counts to whatever is in the (*coutptr)
//	arrays already.  Agents that don't use condition bits return -1.
//	The 4-element array (*countptr)[4] must already exist, but the
//	arrays to which its element point are supplied dynamically.  This
//	method must be provided by each subclass that has condition bits.
// 
/*
pj: change comments May 30, 2000

1. The BFCast class now has taken the place of the struct BF_cast.
Any bit manipulation that needs to be done is done in there, in a way
that is hidden from this class.  This class talks to forecast objects
and tells them to set bits to certain values with messages like
"setConditionsBit: 5 To: 2" and BFCast can handle the rest.

2. The BFParams class now has taken the place of the struct BF_Params.
This uses lispAppArchiver, see the initial values in asm.scm.  In the
original ASM-2.0 code, there is a "global" variable params and there
are private copies of this same thing. So far, I see no point in
having a private copy, so the variables "privateParams" and "params"
point to the same single object created by ASMModelSwarm, and
parameters retrieved from either are thus the same.  Note further, I
did not write "get" methods for every variable in the BFParams
class. It just seemed onerous to do so.  There are 2
alternatives. First, I declared the IVARS in BFParams to be public, so
they can be retrieved with the symbol -> as if the parameter object
were a pointer to a struct, as in: privateParams->condwords.  I hate
doing that, and have the long term plan of replacing all of these
usages with get messages, but in the short term I used the getDouble()
and getInt() functions which can be used to do the same thing, as in
getInt(privateParams,"condwords").

3. The "homemade" linked lists, built with pointers and other C
concepts, are replaced by Swarm collections.  Iteration now uses Swarm
index objects.

4. Global pointers and lists and anything else has been replaced
wherever possible by automatic variables (inside methods) or instance
variables.

5. Genetic Algorithm now is written in Obj-C methods that pass
whatever arguments are needed, rather than using C functions with a
lot of global variables. Agent's don't share workspace for the GA.  
*/



#import "BFagent.h"
#import <random.h> 
#import "World.h"
#include <misc.h>
#import "BFParams.h"
#import "BFCast.h"

extern World *worldForAgent;
//pj: wish I could get rid of that one too, since each agent could just have a pointer
//pj: to a common world object. However, there are serveral class methods that use it.

//pj: 
//convenience macros to replace stuff from ASM random with Swarm random stuff 
 
#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1] 
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1]  
 
//Macros for bit manipulation
//pj: almost all of this stuff moved to BFCast, but this is needed once or twice here.
#define WORD(bit)	(bit>>4)
#define MAXCONDBITS	80

#define extractvalue(variable, trit) ((variable[WORD(trit)] >> ((trit%16)*2))&3) 

// Type of forecasting.  WEIGHTED forecasting is untested in its present form.
//pj: bluntly, WEIGHTED does not work and is incomplete
#define WEIGHTED 0

//static void makebittables(void); //now in BFCast.m

//pj: this is a static global declaration of the params object, shared by all instances.
//pj: note there is also a local copy which is, in current code, intitially the same thing,
//pj: and it never changes.  The original code had 3 of these, so I'm slimmer by 1/3.
static BFParams *  params;

//pj: other global variables were moved either to the performGA method where they are 
//pj: needed or into the BFParams class, where they are used to create BFParams objects

//pj: I don't want to share this across agents.  Now it is an IVAR.
// Working space, dynamically allocated, shared by all instances
//    static struct BF_fcast	**reject;	/* GA temporary storage */
//    static struct BF_fcast	*newfcast;	/* GA temporary storage */

//pj:  extern int ReadBitname(const char *variable, const struct keytable *table);
//pj:  ReadBitname moved to BFParams


// PRIVATE METHODS
@interface BFagent(Private)
- performGA;

//pj: methods now replace previous functions:
- (BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from;
- (void) MakePool: rejects From: (id <Array>) list;
- (BOOL) Mutate: (BFCast *) new Status: (BOOL) changed;
- (BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2;
- (void) TransferFcastsFrom: newList To:  forecastList Replace: rejects; 
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects;
- (void) Generalize: (id) list AvgStrength: (double) avgstrength;
- (BFCast *) Tournament: (id <Array>) list;

@end


@implementation BFagent

+(void)setBFParameterObject: x
{
    params=x;
}

+(void)init
{
  return;
}

//pj: none of this functionality is needed anymore
//  +didInitialize
//  {
//    struct BF_fcast *fptr, *topfptr;
//    unsigned int *conditions;
//    unsigned int *newconds;	
    //pj: no longer needed because these are converted to arrays in +init  
  //  // Free working space we're done with
  //    free(probs);
  //    free(bits);



//  // Allocate working space for GA
//    int npoolmax = getDouble(params,"npoolmax");
//    int nnewmax = getDouble(params,"nnewmax");
//    int ncondmax = getDouble (params,"ncondmax");

//    reject = calloc(npoolmax,sizeof(struct BF_fcast *));
//    if(!reject)
//      printf("There was an error allocating space for reject.");

//    newfcast = calloc(nnewmax,sizeof(struct BF_fcast));
//    if(!newfcast)
//      printf("There was an error allocating space for newfcast.");
    
//    newconds = calloc(ncondmax*nnewmax,sizeof(unsigned int));
//    if(!newconds)
//      printf("There was an error allocating space for newconds.");

//  // Tie up pointers for conditions
//    topfptr = newfcast + nnewmax;
//    conditions = newconds;
//    for (fptr = newfcast; fptr < topfptr; fptr++) 
//      {
//        fptr->conditions = conditions;
//        conditions += ncondmax;
//      }

//    return self;
//  }


//pj: note this is a CLASS METHOD because, as originally designed, each agent
//pj: has the exact same bit-space and the same "real world" as a result.
//pj: Should be easy to rewrite so each agent can have own selection of bits
//pj: to track and a instance variable "my world". This method would be rewritten.

+prepareForTrading      //called at the start of each trading period
{
  int i, n;
  int * myRealWorld=NULL;
  int nworldbits;
  int * bitlist;
  //previously were global vars
  int condbits;
  int condwords;
  unsigned int * myworld; //pj: was just int. Unsigned vital for bit math
  BFParams * pp;

  //pj: The possibility is that pp could be set to some other thing, like an
  //pj: IVAR privateParams, which could differentiate the conditions used by agents. 
  pp = params;  //must refer to same object as params are gotten from below.
  
  condwords = getInt(pp,"condwords");
  condbits = getInt(pp,"condbits");

  //bitlist = pp->bitlist;
  bitlist = [pp getBitListPtr];

  //myworld = pp->myworld;
  myworld = [pp getMyworldPtr];

  for (i = 0; i < condwords; i++)
    myworld[i] = 0;
  //pj: nworldbits = [self setNumWorldBits];
  //replace with:
   nworldbits = [worldForAgent getNumWorldBits];

   //pj: this was not freed in ASM-2.0
    myRealWorld = calloc(nworldbits, sizeof(int));//was memcpy in other file, 
    if(!myRealWorld)
      printf("There was an error allocating space for myRealWorld.");
    //pj: won't work in class method: myRealWorld = [[self getZone] alloc: nworldbits*sizeof(int)];

  [worldForAgent getRealWorld: myRealWorld];

  for (i=0; i < condbits; i++) 
    {
      if ((n = bitlist[i]) >= 0)
	//	myworld[WORD(i)] |= myRealWorld[n] << SHIFT[i];
	myworld[WORD(i)] |= myRealWorld[n] << ((i%16)*2);
    }

  for(i=0; i<condbits; i++)
    {
      n=bitlist[i];
      //printf("diagnostic: Real/ME:%d, %d \n ",myRealWorld[n],(myworld[WORD(i)] >> ((i%16)*2))&3);
    }

  free(myRealWorld);
  //pj: wont work in class method: [[self getZone] free: myRealWorld];

  return self;
}



//Don't need a class method here for this.
//  +(int)lastgatime
//  {
//    //  pp = (struct BFparams *)params;
//    //return pp->lastgatime;
//    return params->lastgatime;
//  }


//pj: yikes, pointer usage, be careful. changes to array affect the world.
+setRealWorld: (int *)array
{
  [worldForAgent getRealWorld: array];
  return self;
}

//pj: superfluous method: never called anymore
+(int)setNumWorldBits
{
  int numofbits;
  numofbits = [worldForAgent getNumWorldBits];
  return numofbits;
}

-createEnd
{

  //pj: this is moved from "didInitialize" because these are now IVARS.
  //  struct BF_fcast *fptr, *topfptr;
  //  unsigned int *conditions;
  //  unsigned int *newconds;	


// Allocate working space for GA
//    int npoolmax = getDouble(params,"npoolmax");
//    int nnewmax = getDouble(params,"nnewmax");
//    int ncondmax = getDouble (params,"ncondmax");

 //   reject = calloc(npoolmax,sizeof(struct BF_fcast *));
//    if(!reject)
//      printf("There was an error allocating space for reject.");

//    newfcast = calloc(nnewmax,sizeof(struct BF_fcast));
//    if(!newfcast)
//      printf("There was an error allocating space for newfcast.");
    
//    newconds = calloc(ncondmax*nnewmax,sizeof(unsigned int));
//    if(!newconds)
//      printf("There was an error allocating space for newconds.");

  // Tie up pointers for conditions
//    topfptr = newfcast + nnewmax;
//    conditions = newconds;
//    for (fptr = newfcast; fptr < topfptr; fptr++) 
//      {
//        fptr->conditions = conditions;
//        conditions += ncondmax;
//      }
  activeList=[List create: [self getZone]];
  oldActiveList=[List create: [self getZone]];
  return [super createEnd];
}




-initForecasts
{
  //struct BF_fcast *fptr, *topfptr;
  //unsigned int *conditions, *cond;
  //int word, 
  //  int bit;
  int  sumspecificity = 0;
  //  int condbits;
  // int condwords;
  //double *problist;
  // double abase, bbase, cbase, asubrange, bsubrange, csubrange;
  // double newfcastvar, bitcost;
  //int *bitlist;

  //pj:new vars
  int i;
  BFCast * aForecast; id index;
  int numfcasts;

// Initialize our instance variables

  //pj: in the future, it may be good to have a separate parameter object for each BFagent.
  //pj: now it makes little sense, so I'm commenting out the creation code here and just setting
  //pj: privateParams equal to the global variable that is passed in.
 //    if ((privateParams =
//           [lispAppArchiver getWithZone: [self getZone] key: "bfParams"]) == nil)
//        raiseEvent(InvalidOperation,
//                   "Can't find the BFParams parameters");
//      [privateParams init];

  privateParams= params;

  // newfcast = [Array create: [self getZone] setCount: getInt(privateParams,"nnewmax")];

  //newconds = [Array create: [self getZone] setCount: getInt(privateParams,"ncondmax")*getInt(privateParams,"nnewmax")];

  numfcasts=getInt(privateParams,"numfcasts");

  fcastList=[Array create: [self getZone] setCount: numfcasts];

  avspecificity = 0.0;
  oldActiveList = activeList = nil;

  gacount = 0;

  variance = getDouble(privateParams, "initvar");
  [self getPriceFromWorld];
  [self getDividendFromWorld];
  global_mean = price + dividend;
  forecast = lforecast = global_mean;

//  // Extract some things for rapid use
//    // condwords = p->condwords;
//    condwords = getInt (privateParams,"condwords");
//    // condbits = p->condbits;
//    condbits = getInt (privateParams,"condbits");
//    // bitlist = p->bitlist;
//    bitlist = [privateParams getBitListPtr];
//    //problist = p->problist;
//    problist = [privateParams getProbListPtr];
//    newfcastvar = getDouble(privateParams,"newfcastvar");
//    bitcost = getDouble (privateParams, "bitcost");

// Allocate memory for forecasts and their conditions
//    fcast = calloc(privateParams->numfcasts,sizeof(struct BF_fcast));
//    if(!fcast)
//      printf("There was an error allocating space for fcast.");

//pj: now allocated inside BFCast objects  
//    conditions = calloc(privateParams->numfcasts*condwords,sizeof(unsigned int));
//    if(!conditions)
//      printf("There was an error allocating space for conditions.");


// Iniitialize the forecasts
//    topfptr = fcast + privateParams->numfcasts;
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        fptr->forecast = 0.0;
//        fptr->lforecast = global_mean;
//        fptr->count = 0;
//        fptr->lastactive = 1;
//        fptr->specificity = 0;
//        fptr->next = fptr->lnext = NULL;

   /* Allocate space for this forecast's conditions out of total allocation */
//        fptr->conditions = conditions;
//        conditions += condwords;

  //   /* Initialise all conditions to don't care */
//        cond = fptr->conditions;
//        for (word = 0; word < condwords; word++)
//  	cond[word] = 0;

    /* Add non-zero bits as specified by probabilities */
   //     if(fptr!=fcast) /* protect rule 0 */
//  	for (bit = 0; bit < condbits; bit++) 
//  	  {
//  	    if (bitlist[bit] < 0)
//  	      cond[WORD(bit)] |= MASK[bit];	/* Set spacing bits to 3 */
//  	    else if (drand() < problist[bit]){
//  	      cond[WORD(bit)] |= (irand(2)+1) << SHIFT[bit];
//  	      ++fptr->specificity;
//  	    }
//  	  }
  //      fptr->specfactor = 1.0/(1.0 + bitcost*fptr->specificity);
  //    fptr->variance = newfcastvar;
  //    fptr->strength = fptr->specfactor/fptr->variance;
  //  }

  //pj:??? note specfactor in bfagent is different: rptr->specfactor =
  //(condbits - p->nnulls - rptr->specificity)*bitcost;


  //keep the 0'th forecast in a  "know nothing" condition
  [fcastList atOffset: 0 put: [self createNewForecast]];

  //create rest of forecasts with random conditions
  for ( i = 1; i < numfcasts; i++)
    {
      id aForecast =[self createNewForecast] ;
      [self setConditionsRandomly: aForecast];
      [fcastList atOffset: i put: aForecast];
     }

/* Compute average specificity */
 //   specificity = 0;
//    for (fptr = fcast; fptr < topfptr; fptr++)
//      specificity += fptr->specificity;
//    avspecificity = ((double) specificity)/(double)privateParams->numfcasts;

  //pj: Proper way to iterate over Swarm collections
  index=[ fcastList begin: [self getZone] ];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
    sumspecificity += [aForecast getSpecificity];
    [aForecast  print];
    }
  avspecificity = ((double) sumspecificity)/(double)numfcasts;
  [index drop];

//  /* Set the forecasting parameters for each fcast to random values in a
//   * fraction "subrange" of their range, centered at the midpoint.  For
//   * subrange=1 this is the whole range (min to max).  For subrange=0.5,
//   * values lie between 1/4 and 3/4 of this range.  subrange=0 gives
//   * homogeneous agents, with values at the middle of their min-max range. 
//   */
//    abase = privateParams->a_min + 0.5*(1.-privateParams->subrange)*privateParams->a_range;
//    bbase = privateParams->b_min + 0.5*(1.-privateParams->subrange)*privateParams->b_range;
//    cbase = privateParams->c_min + 0.5*(1.-privateParams->subrange)*privateParams->c_range;
//    asubrange = privateParams->subrange*privateParams->a_range;
//    bsubrange = privateParams->subrange*privateParams->b_range;
//    csubrange = privateParams->subrange*privateParams->c_range;
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        fptr->a = abase + drand()*asubrange;
//        fptr->b = bbase + drand()*bsubrange;
//        fptr->c = cbase + drand()*csubrange;
//      }
  
  return self;
}


//  -free
//  {
//    //  free(fcast->conditions);
//    // free(fcast);
//    return [super free];
//  }


//all condition bits are 0 here, "don't care for all"
- (BFCast *) createNewForecast
{
  BFCast * aForecast;
  double abase = privateParams->a_min + 0.5*(1.0-privateParams->subrange)*privateParams->a_range;
  double bbase = privateParams->b_min + 0.5*(1.0-privateParams->subrange)*privateParams->b_range;
  double cbase = privateParams->c_min + 0.5*(1.0-privateParams->subrange)*privateParams->c_range;
  double asubrange = privateParams->subrange*privateParams->a_range;
  double bsubrange = privateParams->subrange*privateParams->b_range;
  double csubrange = privateParams->subrange*privateParams->c_range;

  aForecast= [BFCast createBegin: [self getZone]]; 
  [aForecast setCondwords: privateParams->condwords];
  [aForecast setCondbits: privateParams->condbits];
  [aForecast setNNulls: privateParams->nnulls];
  [aForecast setBitcost: privateParams->bitcost];
  aForecast = [aForecast createEnd];
  [aForecast setLforecast: global_mean];
  //note aForecast has the forecast conditions=0 by its own createEnd.
  //also inside its createEnd, lastactive =1, specificity=0, variance=99999;


  [aForecast setVariance: privateParams->newfcastvar];  
  [aForecast setStrength: [aForecast getSpecfactor] / [aForecast getVariance]];
  //??? bfagent has:  rptr->specfactor = (condbits - p->nnulls - rptr->specificity)*bitcost;
  //??? bfagent:  nr->variance = p->maxdev-nr->strength+nr->specfactor;
  //        nr->strength = p->maxdev - (rule[0].variance - madv) +
  //                                                          nr->specfactor;
     
  /* Set the forecasting parameters for each fcast to random values in a
   * fraction "subrange" of their range, centered at the midpoint.  For
   * subrange=1 this is the whole range (min to max).  For subrange=0.5,
   * values lie between 1/4 and 3/4 of this range.  subrange=0 gives
   * homogeneous agents, with values at the middle of their min-max range. 
   */
  [aForecast setAval : abase + drand()*asubrange];
  [aForecast setBval : bbase + drand()*bsubrange];
  [aForecast setCval : cbase + drand()*csubrange];

  return aForecast;   
}


-setConditionsRandomly: (BFCast *) fcastObject
{
  int bit;
  double *problist;
  int *bitlist;

  bitlist = [privateParams getBitListPtr];
 
  problist = [privateParams getProbListPtr];

  for(bit=0; bit< privateParams->condbits; bit++)
    {
      if (bitlist[bit] < 0)
	{
	  [fcastObject setConditionsbit: bit FromZeroTo: 3];//3=11 is a "filler"
	}
      else if (drand() < problist[bit])
	{  
	  [fcastObject setConditionsbit: bit FromZeroTo:  irand(2)+1];
	  //remember 1 means yes, or binary 01, and 2 means no, or 10
	  [fcastObject incrSpecificity];//I wish this were automatic!
	  [fcastObject updateSpecfactor];
	}
    }
  return self;
}


-prepareForTrading
/*
 * Set up a new active list for this agent's forecasts, and compute the
 * coefficients pdcoeff and offset in the equation
 *	forecast = pdcoeff*(trialprice+dividend) + offset
 *
 * The active list of all the fcasts matching the present conditions is saved
 * for later updates.
 */
{
  //register struct BF_fcast *fptr, *topfptr, **nextptr;
  unsigned int real0 = 0;
  unsigned int real1, real2, real3, real4;
  double weight, countsum, forecastvar=0.0;
  int mincount;

  int * myworld;

  //pj new
  BFCast *  aForecast;
  id <Index> index;

#if  WEIGHTED == 1    
  static double a, b, c, sum, sumv;
#else
  //struct BF_fcast *bestfptr;
  BFCast *  bestForecast;
  double maxstrength;
#endif

  //topfptr = fcast + privateParams->numfcasts;
  
// First the genetic algorithm is run if due
  currentTime = getCurrentTime( );
 
     
  if (currentTime >= privateParams->firstgatime && drand() < privateParams->gaprob) 
    {
      [self performGA]; 
      [activeList removeAll];
      [oldActiveList removeAll];
   }	    
  else
    {
      [self copyList: activeList To: oldActiveList];
      [activeList removeAll];  
    }
  //this is an IVar lforecast.
   lforecast = forecast;
    
//pj: list maintenance,
//  for (fptr = activelist; fptr!=NULL; fptr = fptr->next) 
//      {
//        fptr->lnext = fptr->next;
//        fptr->lforecast = fptr->forecast;
//      }


   index=[ oldActiveList begin: [self getZone] ];
    for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
      {
      [aForecast setLforecast: [aForecast getForecast]];
      }
    [index drop];


// Main inner loop over forecasters.  We set this up separately for each
// value of condwords, for speed.  It's ugly, but fast.  Don't mess with
// it!  Taking out fptr->conditions will NOT make it faster!  The highest
// condwords allowed for here sets the maximum number of condition bits
// permitted (no matter how large MAXCONDBITS).

  //pj:  nextptr = &activelist;	/* start of linked list */

   //pj:  myworld = p->myworld;
   myworld = [params  getMyworldPtr];// must refere to same param object.

   //pj:  if(!myworld)  //I have no idea why this was here, BL didn't either.
    real0 = myworld[0];
  switch (privateParams->condwords) {
  case 1:
//pj:      for (fptr = fcast; fptr < topfptr; fptr++) 
//pj:        {
//pj:  	if (fptr->conditions[0] & real0) continue;
//pj:  	*nextptr = fptr;
//pj:  	nextptr = &fptr->next;
//pj:        }

//      index=[ fcastList begin: [self getZone]];
//      for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
//      {
//        printf("The value of (conditions:0 & real0)=%d.: \n", [aForecast getConditionsWord: 0] & real0  );
//        [self printcond: [aForecast getConditionsWord: 0]];printf("  Conditions[0]\n");
//        [self printcond: real0]; printf("  real0\n \n");
//        if ( [aForecast getConditionsWord: 0] & real0 ) 
//  	 {
//  	   printf("The if statement says those two match value %d \n", [aForecast getConditionsWord: 0] & real0  );
//   	   continue ;
//  	 }
//         [activeList addLast: aForecast];
//      }
//      [index drop];

        index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      unsigned int flag=0;
      unsigned int trit;
      unsigned int predictedvalue=999;
     
      trit=-1;
      while ( flag == 0 && ++trit < privateParams-> condbits )
	    {
	      if ( (predictedvalue=[aForecast getConditionsbit: trit]) != 0 )
		{
		  if ( predictedvalue!= ((myworld[WORD(trit)] >> ((trit%16)*2))&3) )
		    {
		      flag=1;
		    }
		}
	        		
	   //       fprintf(stderr,"trit:%d flag: %d  predictionl=%d,  world=%d\n", 
	      //  			trit, flag, predictedvalue,
	      //  			extractvalue(myworld,trit) );  
	         }
     
	    if ( flag!=1 )  [activeList addLast: aForecast];
    
        }
    [index drop];


    break;
  
    case 2:
      real1 = myworld[1];

//      for (fptr = fcast; fptr < topfptr; fptr++) 
//        {
//  	if (fptr->conditions[0] & real0) continue;
//  	if (fptr->conditions[1] & real1) continue;
//  	*nextptr = fptr;
//  	nextptr = &fptr->next;
//        }

   index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & real0 ) continue ;
       if ( [aForecast getConditionsWord: 1] & real1 ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];

      break;
    case 3:
      real1 = myworld[1];
      real2 = myworld[2];
//      for (fptr = fcast; fptr < topfptr; fptr++) 
//        {
//  	if (fptr->conditions[0] & real0) continue;
//  	if (fptr->conditions[1] & real1) continue;
//  	if (fptr->conditions[2] & real2) continue;
//  	*nextptr = fptr;
//  	nextptr = &fptr->next;
//        }


  index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & real0 ) continue ;
       if ( [aForecast getConditionsWord: 1] & real1 ) continue ;
       if ( [aForecast getConditionsWord: 2] & real2 ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];
     break;
    case 4:
      real1 = myworld[1];
      real2 = myworld[2];
      real3 = myworld[3];
//      for (fptr = fcast; fptr < topfptr; fptr++) 
//        {
//  	if (fptr->conditions[0] & real0) continue;
//  	if (fptr->conditions[1] & real1) continue;
//  	if (fptr->conditions[2] & real2) continue;
//  	if (fptr->conditions[3] & real3) continue;
//  	*nextptr = fptr;
//  	nextptr = &fptr->next;
//        }
    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & real0 ) continue ;
       if ( [aForecast getConditionsWord: 1] & real1 ) continue ;
       if ( [aForecast getConditionsWord: 2] & real2 ) continue ;
       if ( [aForecast getConditionsWord: 3] & real3 ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];

      break;
    case 5:
      real1 = myworld[1];
      real2 = myworld[2];
      real3 = myworld[3];
      real4 = myworld[4];
//      for (fptr = fcast; fptr < topfptr; fptr++) 
//        {
//  	if (fptr->conditions[0] & real0) continue;
//  	if (fptr->conditions[1] & real1) continue;
//  	if (fptr->conditions[2] & real2) continue;
//  	if (fptr->conditions[3] & real3) continue;
//  	if (fptr->conditions[4] & real4) continue;
//  	*nextptr = fptr;
//  	nextptr = &fptr->next;
//        }
    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & real0 ) continue ;
       if ( [aForecast getConditionsWord: 1] & real1 ) continue ;
       if ( [aForecast getConditionsWord: 2] & real2 ) continue ;
       if ( [aForecast getConditionsWord: 3] & real3 ) continue ;
       if ( [aForecast getConditionsWord: 4] & real4 ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];
      break;
      //pj??? There ought to be a "default" action here for other cases.

#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif

  }
  // *nextptr = NULL;	/* end of linked list */

#if WEIGHTED == 1
// Construct weighted-average forecast
// The individual forecasts are:  p + d = a(p+d) + b(d) + c
// We often lock b at 0 by setting b_min = b_max = 0.

  //pj: note I started updating this code to match the rest, but then
  //pj: I realized it did not work as it was before, so I stopped
  //pj: messing with it.

  a = 0.0;
  b = 0.0;
  c = 0.0;
  sumv = 0.0;
  sum = 0.0;
  nactive = 0;
  mincount = privateParams->mincount;
//    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) 
//      {
//        fptr->lastactive = t;
//        if (++fptr->count >= mincount) 
//  	{
//  	  ++nactive;
//  	  a += fptr->strength*fptr->a;
//  	  b += fptr->strength*fptr->b;
//  	  c += fptr->strength*fptr->c;
//  	  sum += fptr->strength;
//  	  sumv += fptr->variance;
//  	}
//      }

  
  index=[ activeList begin: [self getZone] ];
  if ( [activeList getCount]>0 )
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast setLastactive: t];
      if ( [aForecast incrCount] >= mincount )
      {
	double sumstrength;
	double strength;
	strength=[aForecast getStrength];
	++nactive;

  	  a += strength*[aForecast getAval];
  	  b += strength*[aForecast getBval] ;
  	  c += strength*[aForecast getCval] ;
  	  sum += strength;
  	  sumv += [aForecast getVariance];
      }
    }
  [index drop];

  if (nactive) 
    {
      pdcoeff = a/sum;
      offset = (b/sum)*dividend + (c/sum);
      forecastvar = privateParams->individual? sumv/((double)nactive) :variance;
    }
#else

// Now go through the list and find best forecast
  maxstrength = -1e50;
  //bestfptf=NULL
  bestForecast = nil;
  nactive = 0;
  mincount = getInt(privateParams,"mincount");
//    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) 
//      {
//        fptr->lastactive = currentTime;
//        if (++fptr->count >= mincount) 
//  	{
//  	  ++nactive;
//  	  if (fptr->strength > maxstrength) 
//  	    {
//  	      maxstrength = fptr->strength;
//  	      bestfptr = fptr;
//  	    }
//  	}
//      }
  
  index=[activeList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast setLastactive: currentTime];
      if([aForecast incrCount] >= mincount)
      {
	double strength=[aForecast getStrength];
	++nactive;
	if (strength > maxstrength)
	  {
	    maxstrength = strength;
	    bestForecast= aForecast;
	  }
      }
    }
  //printf("active list has %d \n",[activeList getCount]);
  [index drop];


//    if (nactive) 
//      {
//        pdcoeff = bestfptr->a;
//        offset = bestfptr->b*dividend + bestfptr->c;
//        forecastvar = (privateParams->individual? bestfptr->variance :variance);
//      }

  fprintf(stderr,"nactive = %d  activeList getCount is %d\n",nactive, [activeList getCount]);
  if (nactive)  // meaning that at least some forecasts are active
    {
      pdcoeff = [bestForecast getAval];
      offset = [bestForecast getBval]*dividend + [bestForecast getCval];
      forecastvar = getInt(privateParams,"individual")? [bestForecast getVariance]:variance;
    }

#endif
  else  // meaning "nactive" zero, no forecasts are active 
    {
      // No forecast!!
      // Use weighted (by count) average of all rules
      countsum = 0.0;
      pdcoeff = 0.0;
      offset = 0.0;
      mincount = getInt(privateParams,"mincount");

 //       for (fptr = fcast; fptr < topfptr; fptr++)
//  	if (fptr->count >= mincount) 
      // 	  {
//  	    countsum += weight = (double)fptr->strength;
//  	    offset += (fptr->b*dividend + fptr->c)*weight;
//  	    pdcoeff += fptr->a*weight;
//  	  }
 //     if (countsum > 0.0) 
//  	{
//  	  offset /= countsum;
//  	  pdcoeff /= countsum;
//  	}
//        else
//  	offset = global_mean;
//        forecastvar = variance;
//      }

  index=[ fcastList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      if ([aForecast getCnt] >= mincount)
	{  
      	    countsum += weight = [aForecast getStrength];
	    offset += ([aForecast getBval]*dividend + [aForecast getCval])*weight;
	    pdcoeff += [aForecast getAval]*weight;
	}
  
     if (countsum > 0.0) 
	{
	  offset /= countsum;
	  pdcoeff /= countsum;
	}
      else
	{
	offset = global_mean;
	}
      forecastvar = variance;
    }
 [index drop];
    }

divisor = getDouble(privateParams,"lambda")*forecastvar;
    
return self;
}


-getInputValues      //does nothing, used only if their are ANNagents
{
  return self;
}


-feedForward        //does nothing, used only if their are ANNagents
{
  return self;
}


-(double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice
  /*
 * Returns the agent's requested bid (if >0) or offer (if <0) using
 * best (or mean) linear forecast chosen by -prepareForTrading
 */
{
  // The actual forecast is given by
  //       forecast = pdcoeff*(trialprice+dividend) + offset
  // where pdcoeff and offset are set by -prepareForTrading.
  forecast = (trialprice + dividend)*pdcoeff + offset;

  // A risk aversion computation now gives a target holding, and its
  // derivative ("slope") with respect to price.  The slope is calculated
  // as the linear approximated response of a change in price on the traders'
  // demand at time t, based on the change in the forecast according to the
  // currently active linear rule.
  if (forecast >= 0.0) 
    {
      demand = -((trialprice*intratep1 - forecast)/divisor + position);
      *slope = (pdcoeff-intratep1)/divisor;
    }
  else 
    {
      forecast = 0.0;
      demand = - (trialprice*intratep1/divisor + position);
      *slope = -intratep1/divisor;
    }

  // Clip bid or offer at "maxbid".  This is done to avoid problems when
  // the variance of the forecast becomes very small, thought it's not clear
  // that this is the best solution.
  if (demand > privateParams->maxbid) 
    { 
      demand = privateParams->maxbid;
      *slope = 0.0;
    }
  else if (demand < -privateParams->maxbid) 
    {
      demand = -privateParams->maxbid;
      *slope = 0.0;
    }
    
  [super constrainDemand:slope:trialprice];
  return demand;
}


-(double)getRealForecast
{
  return forecast;
}


-updatePerformance
{
  //pj: register struct BF_fcast *fptr;
  BFCast *  aForecast;
  id <Index> index = nil;
  double deviation, ftarget, tauv, a, b, c, av, bv, maxdev;
    
   // Now update all the forecasts that were active in the previous period,
  // since now we know how they performed.

  // Precompute things for speed
  tauv = privateParams->tauv;
  a = 1.0/tauv;
  b = 1.0-a;
  // special rates for variance
  // We often want this to be different from tauv
  // PARAM:  100. should be a parameter  BL
  av = 1.0/(double)100.0;
  bv = 1.0-av;

    /* fixed variance if tauv at max */
  if (tauv == 100000) 
    {
      a = 0.0;
      b = 1.0;
      av = 0.0;
      bv = 1.0;
    }
  maxdev = privateParams->maxdev;

// Update global mean (p+d) and our variance
  [self getPriceFromWorld];
  ftarget = price + dividend;


// Update global mean (p+d) and our variance
    
  realDeviation = deviation = ftarget - lforecast;
  if (fabs(deviation) > maxdev) deviation = maxdev;
  global_mean = b*global_mean + a*ftarget;
  // Use default for initial variances - for stability at startup
  currentTime = getCurrentTime( );
  if (currentTime < 1)
    variance = privateParams->initvar;
  else
    variance = bv*variance + av*deviation*deviation;

 //??cant find anywhere in ASM-2.0 an update of the forecast's
 //forecast. but it is clearly needed if you look at bfagent from the
 //objc version???
  //??This seems to fix the strange time series properties too??//
 
  index = [ activeList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast updateForecastPrice: price Dividend: dividend];
    }
  [index drop];
   

// Update all the forecasters that were activated.
//    if (currentTime > 0)
//      for (fptr=lactivelist; fptr!=NULL; fptr=fptr->lnext) 
//        {
//          deviation = (ftarget - fptr->lforecast)*(ftarget - fptr->lforecast);

//  // 	Benchmark test line - replace true deviation with random one
//  //      PARAM: Might be coded as a parameter sometime 
//  //      deviation = drand(); 

//  //      Only necessary for absolute deviations
//  //      if (deviation < 0.0) deviation = -deviation;

//  	if (deviation > maxdev) deviation = maxdev;
//    	if (fptr->count > tauv)
//  	  fptr->variance = b*fptr->variance + a*deviation;
//  	else 
//  	  {
//  	    c = 1.0/(1.+fptr->count);
//  	    fptr->variance = (1.0 - c)*fptr->variance +
//  						c*deviation;
//  	  }
//          fptr->strength = fptr->specfactor/fptr->variance;
//        }

  if (currentTime > 0)
    {
      index = [ oldActiveList begin: [self getZone]];
      for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	{
	  double lastForecast;
	  lastForecast=[aForecast getLforecast];
	  deviation = (ftarget - lastForecast)*(ftarget - lastForecast);

	  if (deviation > maxdev) deviation = maxdev;
	  if ([aForecast getCnt] > tauv)
	    [aForecast setVariance : b*[aForecast getVariance] + a*deviation];
	  else 
	    {
	      c = 1.0/(double) (1.0 +[aForecast getCnt]);  //??bfagent had no 1+ here ??
	      [aForecast setVariance: (1.0 - c)*[aForecast getVariance] +
			 c*deviation];
	    }
	  //[aForecast setStrength: [aForecast getSpecfactor] / [aForecast getVariance]];
	  [aForecast setStrength: privateParams->maxdev - [aForecast getVariance] + [aForecast getSpecfactor]];  //based on bfagent.m
	  // original  bfagent has this:
	  //    rptr->strength = p->maxdev - rptr->variance + rptr->specfactor;
	  // BFagent had this:   fptr->strength = fptr->specfactor/fptr->variance;
	}

      [index drop];
    }
  // NOTE: On exit, fptr->forecast is only guaranteed to be valid for
  // forcasters which matched.  The inspector has to calculate the rest
  // itself if it wants to show them all.  This is for speed.
  return self;
}


-(double)getDeviation
{
  return fabs(realDeviation);
}


-updateWeights         //does nothing, used only if their are ANNagents
{
  return self;
}


-(int)nbits
{
  return privateParams->condbits;
}


-(int)nrules
{
  return privateParams->numfcasts;
}


-(int)lastgatime
{
  return lastgatime;
}


//pj: Never gets called. Worry about it later ??????????

//  -(int)bitDistribution: (int *(*)[4])countptr cumulative: (BOOL)cum
//  {
//    struct BF_fcast *fptr, *topfptr;
//    unsigned int *agntcond;
//    int i;
//    int condbits;
 

//    static int *count[4];	// Dynamically allocated 2-d array
//    static int countsize = -1;	// Current size/4 of count[]
//    static int prevsize = -1;

//    condbits = getInt (privateParams, "condbits");

//    if (cum && condbits != prevsize)
//      printf("There is an error with an agent's condbits.");
//    prevsize = condbits;

//  // For efficiency the static array can grow but never shrink
//    if (condbits > countsize) 
//      {
//        if (countsize > 0) free(count[0]);
//        count[0] = calloc(4*condbits,sizeof(int));
//        if(!count[0])
//  	printf("There was an error allocating space for count[0].");
//        count[1] = count[0] + condbits;
//        count[2] = count[1] + condbits;
//        count[3] = count[2] + condbits;
//        countsize = condbits;
//      }
  
//    (*countptr)[0] = count[0];
//    (*countptr)[1] = count[1];
//    (*countptr)[2] = count[2];
//    (*countptr)[3] = count[3];

//    if (!cum)
//      for(i=0;i<condbits;i++)
//        count[0][i] = count[1][i] = count[2][i] = count[3][i] = 0;

//    topfptr = fcast + privateParams->numfcasts;
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        agntcond = fptr->conditions;
//        for (i = 0; i < condbits; i++)
//  	count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
//      }

//    return condbits;
//  }

//pj: this method was never called anywhere
//  -(int)fMoments: (double *)moment cumulative: (BOOL)cum
//  {
//    struct BF_fcast *fptr, *topfptr;
//    int i;
//    int condbits;

//    condbits = getInt (privateParams, "condbits");
  
//    if (!cum)
//  	for(i=0;i<6;i++)
//  	  moment[i] = 0;
  
//    topfptr = fcast + privateParams->numfcasts;
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        moment[0] += fptr->a;
//        moment[1] += fptr->a*fptr->a;
//        moment[2] += fptr->b;
//        moment[3] += fptr->b*fptr->b;
//        moment[4] += fptr->c;
//        moment[5] += fptr->c*fptr->c;
//      }
    
//    return privateParams->numfcasts;
//  }

//pj: this method is not called anywhere
//  -(const char *)descriptionOfBit: (int)bit
//  {
//    if (bit < 0 || bit > getInt(privateParams,"condbits"))
//      return "(Invalid condition bit)";
//    else
//      return [World descriptionOfBit:privateParams->bitlist[bit]];
//  }


// Genetic algorithm
//
//  1. MakePool() makes a list in reject[] of the "npool" weakest rules.
//
//  2. "nnew" new rules are created in newrules[], using tournament
//     selection, crossover, and mutation.  "Tournament selection"
//     means picking two candidates purely at random and then choosing
//     the one with the higher strength.  See the Crossover() and
//     Mutate() routines for more details about how they work.
//
//  3. The nnew new rules replace nnew of the npool weakest old ones found in
//     step 1.  GetMort() is called for each of the nnew new rules and
//     selects one to replace out of the remainder of the original npool weak
//     ones.  It pays no attention to strength, but looks at similarity of
//     the bitstrings -- rather like tournament selection, we pick two
//     candidates at random and choose the one with the MORE similar
//     bitstring to be replaced.  This maintains more diversity.
//
//  4. Generalize() looks for rules that haven't been triggered for
//     "longtime" and generalizes them by changing a randomly chosen
//     fraction "genfrac" of 0/1 bits to "don't care".  It does this
//     independently of strength to all rules in the population.
//
// Parameter list:
//
//   npool	-- size of pool of weakest rules for possible relacement;
//		   specified as a fraction of numfcasts by "poolfrac"
//   nnew	-- number of new rules produced
//		   specified as a fraction of numfcasts by "newfrac"
//   pcrossover -- probability of running Crossover() at all.
//   plinear    -- linear combination "crossover" prob.
//   prandom    -- random from each parent crossover prob.
//   pmutation  -- per bit mutation prob.
//   plong      -- long jump prob.
//   pshort     -- short (neighborhood) jump prob.
//   nhood      -- size of neighborhood.
//   longtime	-- generalize if rule unused for this length of time
//   genfrac	-- fraction of 0/1 bits to make don't-care when generalising

- performGA
{
  // register struct BF_fcast *fptr;
  //  struct BF_fcast *nr;
  register int f;
  int  new;
  BFCast * parent1, * parent2;
 
  double ava,avb,avc,sumc;
  double temp;  //for holding values needed shortly
  //pj: previously declared as globals
  int * bitlist;
  //int condbits;
  //int condwords;
  id newList = [List create: [self getZone]]; //to collect the new forecasts; 
  id rejectList = [Array create: [self getZone] setCount: getInt(privateParams,"npoolmax")];
  static double avstrength,minstrength;	

  ++gacount;
  currentTime = getCurrentTime();

  privateParams->lastgatime= params->lastgatime = lastgatime = currentTime;

  bitlist = privateParams->bitlist;

  // Find the npool weakest rules, for later use in TrnasferFcasts
  //MakePool(fcastList);
  [self  MakePool: rejectList From: fcastList];


  // Compute average strength (for assignment to new rules)
  avstrength = ava = avb = avc = sumc = 0.0;
  minstrength = 1.0e20;

  for (f=0; f < privateParams->numfcasts; f++) 
    {
      double varvalue = 0;
      if ( [[fcastList atOffset: f] getCnt] > 0)
	{
	  if ( (varvalue= [ [fcastList atOffset:f] getVariance]) !=0  )
	    {
	      avstrength += [ [ fcastList atOffset: f] getStrength];
	      sumc += 1.0/ varvalue ;
	      ava +=  [[fcastList atOffset: f] getAval] / varvalue ;
	      avb +=  [[fcastList atOffset: f] getBval] / varvalue;
	      avc +=  [[fcastList atOffset: f] getCval] / varvalue ;
	    }
	  if( (temp = [[fcastList atOffset: f] getStrength]) < minstrength)
	    minstrength = temp;
	}
    }
  //    ava /= sumc;
  //        avb /= sumc;
  //        avc /= sumc;

  /*
   * Set rule 0 (always all don't care) to inverse variance weight 
   * of the forecast parameters.  A somewhat Bayesian way for selecting 
   * the params for the unconditional forecast.  Remember, rule 0 is imune to
   * all mutations and crossovers.  It is the default rule.
   */
  [[fcastList atOffset: 0] setAval: ava/ sumc ];
  [[fcastList atOffset: 0] setBval: avb/ sumc ];
  [[fcastList atOffset: 0] setCval: avc/ sumc ];
  
  avstrength /= privateParams->numfcasts;
    
// Loop to construct nnew new rules
  for (new = 0; new < privateParams->nnew; new++) 
    {
      BOOL changed;
 
      changed = NO;
      // Loop used if we force diversity
      do 
	{
	  BFCast * aNewForecast=nil;

   	  aNewForecast= [BFCast createBegin: [self getZone]]; 
	  [aNewForecast setCondwords: privateParams->condwords];
	  [aNewForecast setCondbits: privateParams->condbits];
	  [aNewForecast setLforecast: global_mean];
	  aNewForecast= [aNewForecast createEnd];
	  //pj: ?? should set some initial values here. Lets try these for size:
	  [aNewForecast setCnt: 0];
	  [aNewForecast updateSpecfactor];
	  [aNewForecast setStrength: avstrength];
	  [aNewForecast setVariance: [aNewForecast getSpecfactor]/[aNewForecast getStrength]];
          [aNewForecast setLastactive: currentTime];

	  //?? bfagent had:   nr->variance = p->maxdev-nr->strength+nr->specfactor;
	  ///  / If variance unreasonably low - move to reasonable level
	  //                  if (nr->variance<(rule[0].variance-madv)) {
	  //                      nr->variance = rule[0].variance-madv;
	  //                      nr->strength = p->maxdev - (rule[0].variance - madv) +
	  //                                                              nr->specfactor;
	  //                  }
	  //  //  If new rule variance is negative, move to median strength
	  //                  if (nr->variance <= 0) {
	  //                      nr->variance = p->maxdev - medianstrength + nr->specfactor;
	  //                      nr->strength = medianstrength;
	  //                  }
	  //  // Initialize variables for new rule
	  //                  nr->forecast = 0.0;
	  //                  nr->oldforecast = global_mean;
	  //                  nr->count = 0;
	  //                  nr->birth = nr->lastused = nr->lastactive = t;
	  //                  nr->next = nr->oldnext = NULL;
	  //            }



	  [newList addLast: aNewForecast]; //?? were these not initialized in original?//
          
	  printf("\n New Forecast diagnostic: \n");
	  [aNewForecast print];

	  // Pick first parent using touranment selection
	  //pj: ??should this operate on all or only active forecasts???
	  do
	    parent1 = [ self Tournament: fcastList ] ;
	  while (parent1 == nil);

	  // Perhaps pick second parent and do crossover; otherwise just copy
	  if (drand() < privateParams->pcrossover) 
	    {
	      do
		parent2 = [self  Tournament: fcastList];
	      while (parent2 == parent1 || parent2 == nil) ;

	      //  Crossover(aNewForecast,parent1, parent2);
	      [self Crossover:  aNewForecast Parent1:  parent1 Parent2:  parent2];
	      if (aNewForecast==nil) {fprintf(stderr,"got nil back from crossover");}
	      changed = YES;
	    }
	  else
	    {
	      //CopyRule(aNewForecast,parent1);
	      [self CopyRule: aNewForecast From: parent1];
	      if(!aNewForecast)fprintf(stderr,"got nil back from CopyRule");
	
	      changed = [self Mutate: aNewForecast Status: changed];
	    }
 
	  // Set strength and lastactive if it's really new
	  if (changed) 
	    {
	      //    nr = newfcast + new;
	      //    nr->strength = avstrength;
	      //    nr->variance = nr->specfactor/nr->strength;
	      //    nr->lastactive = currentTime;
	      [aNewForecast setStrength: avstrength];
	      [aNewForecast setVariance: [aNewForecast getSpecfactor]/[aNewForecast getStrength]];
	      [aNewForecast setLastactive: currentTime];
	    }
	  [aNewForecast print];
	} while (0);
      /* Replace while(0) with while(!changed) to force diversity */
    }

  // Replace nnew of the weakest old rules by the new ones
  //TransferFcasts ( newList, fcastList , rejectList);

  [self  TransferFcastsFrom: newList To: fcastList Replace: rejectList];

// Generalize any rules that haven't been used for a long time
  [self Generalize: fcastList AvgStrength: avstrength ];

  // Compute average specificity
  {
    int specificity = 0;
    //note here a "raw" for loop around the fcastList. I could create an index
    //and do the swarm thing, but I leave this here to keep myself humble.

    for (f = 0; f < privateParams->numfcasts; f++) 
      {
	parent1 = [fcastList atOffset:0];
	specificity += [parent1 getSpecificity];
      }
    avspecificity = ((double) specificity)/(double)privateParams->numfcasts;

  }

  [newList deleteAll]; 
  [newList drop];
  [rejectList drop];

  return self;
}



/*------------------------------------------------------*/
/*	CopyRule					*/
/*------------------------------------------------------*/
-(BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from
{
  //    unsigned int *conditions;
  //    int i;

      //    conditions = to->conditions;	// save pointer to conditions
      //    *to = *from;			// copy whole fcast structure
      //    to->conditions = conditions;	// restore pointer to conditions
      //    for (i=0; i<condwords; i++)
      //      conditions[i] = from->conditions[i];	// copy actual conditions
      //    if(from->count==0)
      //      to->strength = minstrength;

  double minstrength = 1.0e20;
  [to setForecast: [from getForecast]];
  [to setLforecast: [from getLforecast]];
  [to setVariance: [from getVariance]];
  [to setStrength: [from getStrength]];
  [to setAval: [from getAval]];
  [to setBval: [from getBval]];
  [to setCval: [from getCval]];
  [to setSpecfactor: [from getSpecfactor]];
  [to setLastactive: [from getLastactive]];
  [to setSpecificity: [from getSpecificity]];
  [to setConditions: [from getConditions]];
  [to setCnt: [from getCnt]];
  if ( [from getCnt] ==0)
    [to setStrength: minstrength];
  return to;

}



/*------------------------------------------------------*/
/*	MakePool					*/
/*------------------------------------------------------*/
-(void) MakePool: rejects From: (id <Array>) list
{
  //    register int j, top;
  //    register struct BF_fcast *fptr, *topfptr;
  //  // Dumb bubble sort
  //    topfptr = fcastinput + pp->npool;
  //    top = -1;
  //    for (fptr = fcastinput; fptr < topfptr; fptr++) 
  //      {
  //        for (j = top; j >= 0 && fptr->strength < reject[j]->strength; j--)
  //  	reject[j+1] = reject[j];
  //        reject[j+1] = fptr;
  //        top++;
  //      }
  //    topfptr = fcastinput + pp->numfcasts;
  //    for (; fptr < topfptr; fptr++) {
  //      if (fptr->strength < reject[top]->strength) 
  //        {
  //  	for (j = top-1; j>=0 && fptr->strength < reject[j]->strength; j--)
  //  	  reject[j+1] = reject[j];
  //  	reject[j+1] = fptr;
  //        }
  //    }
  //      /* protect all don't cares (first) from elimination - bl */
  //    for(j=0;j<pp->npool;j++)
  //      if (reject[j]==fcastinput) reject[j] = NULL;
  //  /* Note that reject[npool-1]->strength gives the "dud threshold" */
  register int top;
  int i,j = 0 ;
  BFCast * aForecast;
  BFCast * aReject;
  
  top = -1;
  //pj: why not just start at 1 so we never worry about putting forecast 0 into the mix?
  for ( i=1; i < getInt(privateParams,"npool"); i++)
    {
      aForecast=[list atOffset: i];
      for ( j=top;  j >= 0 && (aReject=[rejects atOffset:j])&& ([aForecast getStrength] < [aReject  getStrength] ); j--)
	{
	  [rejects atOffset: j+1 put: aReject ];
	}  //note j decrements at the end of this loop
      [rejects atOffset: j+1 put: aForecast];
      top++;
    }
	  
  for ( ; i < getInt(privateParams,"numfcasts"); i++)
    {
      aForecast=[list atOffset: i];
      if ( [aForecast  getStrength]  < [[ rejects atOffset: top] getStrength ] ) 
	{
	  for ( j = top-1; j >= 0 && (aReject=[rejects atOffset:j]) && [aForecast getStrength] < [aReject  getStrength]; j--)
	    {
	      [rejects atOffset: j+1 put: aReject];
	    }
	}
      [rejects atOffset: j+1 put: aForecast];
    }
  //pj:note: we are not checking to see if forecast 0 is in here
}




/*------------------------------------------------------*/
/*	Tournament					*/
/*------------------------------------------------------*/
- (BFCast *) Tournament: (id <Array>) list
{
  
  int  numfcasts=[list getCount];
  BFCast * candidate1 = [list atOffset: irand(numfcasts)];
  BFCast *  candidate2;
    
  do
    candidate2 = [list atOffset: irand(numfcasts)];
  while (candidate2 == candidate1);

  if ([candidate1 getStrength] > [candidate2 getStrength])
    return candidate1;
  else
    return candidate2;
}




/*------------------------------------------------------*/
/*	Mutate						*/
/*------------------------------------------------------*/
-(BOOL) Mutate: (BFCast *) new Status: (BOOL) changed
  /*
     * For the condition bits, Mutate() looks at each bit with
     * probability pmutation.  If chosen, a bit is changed as follows:
     *    0  ->  * with probability 2/3, 1 with probability 1/3
     *    1  ->  * with probability 2/3, 0 with probability 1/3
     *    *  ->  0 with probability 1/3, 1 with probability 1/3,
     *           unchanged with probability 1/3
     * This maintains specificity on average.
     *VERY CONFUSING, because the values are actually 0,1, and 2
     CONVERTED LIKE SO

     0      1    1/3          2       1/3
     1      0    2/3          2       1/3
     2      0    2/3          1       1/3

     *
     * For the forecasting parameters, Mutate() may do one of two things,
     * independently for each parameter.
     * 1. "Long jump": the parameter is chosen randomly from its min-max
     *    range.
     * 2. "Short jump": the parameter is chosen randomly from a uniform
     *    distribution from oldvalue-nhood*range to oldvalue+nhood*range,
     *    where range = max-min.  Values outside the min-max range are
     *    mapped to the endpoint.
     * Method 1 is used with probability plong, method 2 is used with
     * probability pshort, and the parameter is left unchanged with
     * probability 1-plong-pshort.
     *
     * Returns YES if it actually changed anything, otherwise NO.
     */
{
  register int bit;
  //  register struct BF_fcast *nr = newfcast + new;
  //  unsigned int *cond, *cond0;
  double choice, temp;
  BOOL bitchanged = NO;
  int * bitlist= NULL;
  
  //recall pp same as privateParams
  bitlist= [privateParams getBitListPtr];
  //pj: dont know why BFagents introduced bitchanged.??
  bitchanged = changed;
  if (privateParams->pmutation > 0) 
    {
      for (bit = 0; bit < privateParams->condbits; bit++) 
	{
	  if (bitlist[bit] < 0) continue;
	  if (drand() < privateParams->pmutation) 
	    {
	      //cond = cond0 + WORD(bit);
	      //if (*cond & MASK[bit])
	      if ([new getConditionsbit: bit] > 0 ) 
		{
		  if (irand(3) > 0) 
		    {
		      // *cond &= NMASK[bit];
		      //nr->specificity--;
		      [new maskConditionsbit: bit];
		      [new decrSpecificity];
		    }
		  else
		    //   *cond ^= MASK[bit];
		    [new switchConditionsbit: bit];
		    
		  bitchanged = changed = YES;
		}
	      else if (irand(3) > 0) 
		{
		 
		  //  *cond |= (irand(2)+1) << SHIFT[bit];
		  //  nr->specificity++;
		  [new setConditionsbit: bit FromZeroTo: (irand(2)+1)];
		  [new incrSpecificity];
		  bitchanged = changed = YES;
		}
	    }
	}
    }

  /* mutate p+d coefficient */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setAval:   privateParams->a_min + privateParams->a_range*drand()] ;
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getAval] + privateParams->a_range*privateParams->nhood*urand();
      [new setAval: (temp > privateParams->a_max? privateParams->a_max:
		     (temp < privateParams->a_min? privateParams->a_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  /* mutate dividend coefficient */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setBval:  privateParams->b_min + privateParams->b_range*drand() ];
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getBval] + privateParams->b_range*privateParams->nhood*urand();
      [new setBval: (temp > privateParams->b_max? privateParams->b_max:
		     (temp < privateParams->b_min? privateParams->b_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  /* mutate constant term */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setCval:  privateParams->c_min + privateParams->c_range*drand()];
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getCval] + privateParams->c_range*privateParams->nhood*urand();
      [new setCval: (temp > privateParams->c_max? privateParams->c_max:
		     (temp < privateParams->c_min? privateParams->c_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  [new setCnt: 0];

  if (changed) 
    {
      //[new setSpecFactorParam: privateParams->bitcost];
      [new updateSpecfactor];
    }
  printf("We mutated \n");
  return(changed);
}





/*------------------------------------------------------*/
/*	Crossover					*/
/*------------------------------------------------------*/
-(BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2
  /*
     * On the condition bits, Crossover() uses uniform crossover -- each
     * bit is chosen randomly from one parent or the other.
     * For the real-valued forecasting parameters, Crossover() does
     * one of three things:
     * 1. Choose a linear combination of the parents' parameters,
     *    weighted by strength.
     * 2. Choose each parameter randomly from each parent.
     * 3. Choose one of the parents' parameters (all from one or all
     *    from the other).
     * Method 1 is chosen with probability plinear, method 2 with
     * probability prandom, method 3 with probability 1-plinear-prandom.
     */
{
  //    register int bit;
  //    unsigned int *cond1, *cond2, *newcond;
  //    struct BF_fcast *nr = newfcast + new;
  //    int word, parent, specificity;
  //    double weight1, weight2, choice;
  //    int bitparent;

  /* Uniform crossover of condition bits */
  register int bit;
  // unsigned int *cond1, *cond2, *newcond;
  int word;
  double weight1, weight2, choice;
      

  //      newcond= [newForecast getConditions];

  //  cond1 = [parent1 getConditions];
  //    cond2 = [parent2 getConditions];

  [newForecast setSpecificity: 0];

  for (word = 0; word <privateParams->condwords; word++)
    [newForecast setConditionsWord: word To: 0];

  for (bit = 0; bit < privateParams->condbits; bit++)
    {
      //	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];
      if ( irand(2) == 0)
	{
	  int value=[parent1 getConditionsbit: bit];
	  [newForecast setConditionsbit: bit FromZeroTo: value];
	  if (value > 0) [newForecast incrSpecificity]; 
	}
      else
	{
	  int value= [parent2 getConditionsbit: bit];
	  [newForecast setConditionsbit: bit FromZeroTo: value ];
	  if (value > 0) [newForecast incrSpecificity]; 
	}
    }
  //pj:???wont those changes automatically show up in newForecast??//
    
  // checked with Blake: this was a remnant, only need first if, as above
  //   if(irand(1)==0) 
  //      {
  //        for (word = 0; word <condwords; word++)
  //  	newcond[word] = 0;
  //        for (bit = 0; bit < condbits; bit++)
  //  	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];
  //      }

  //    else 
  //      {
  //        bitparent = irand(2);
  //        for (word = 0; word <condwords; word++)
  //  	newcond[word] = 0;
  //        for (bit = 0; bit < condbits; bit++)
  //  	newcond[WORD(bit)] |= (bitparent?cond1:cond2)[WORD(bit)]&MASK[bit];
  //      }

  /* Select one crossover method for the forecasting parameters */
  choice = drand();
  if (choice < privateParams->plinear) 
    {
      /* Crossover method 1 -- linear combination */
      weight1 = [parent1 getStrength] / ([parent1 getStrength] +
					 [parent2 getStrength]);
      weight2 = 1.0-weight1;
      [ newForecast setAval:  weight1*[parent1 getAval] + weight2*[parent2 getAval] ]; 
      [ newForecast setBval:  weight1*[parent1 getBval] + weight2*[parent2 getBval] ];
      [ newForecast setCval:  weight1*[parent1 getCval] + weight2*[parent2 getCval]] ;
    }
  else if (choice < privateParams->plinear + privateParams->prandom) 
    {
      /* Crossover method 2 -- randomly from each parent */
      if(irand(2))
	[newForecast setAval: [parent1 getAval]] ; else [newForecast setAval: [parent2 getAval]];
      if(irand(2))
	[newForecast setBval: [parent1 getBval]] ; else [newForecast setBval: [parent2 getBval]];   
      if(irand(2))
	[newForecast setCval: [parent1 getCval]] ; else [newForecast setCval: [parent2 getCval]];
    }
  else 
    {
      /* Crossover method 3 -- all from one parent */
      if (irand(2))
	{
	  [newForecast setAval: [parent1 getAval]] ;  
	  [newForecast setBval: [parent1 getBval]] ;    
	  [newForecast setCval: [parent1 getCval]] ;
	}
      else
	{
	  [newForecast setAval: [parent2 getAval]] ;  
	  [newForecast setBval: [parent2 getBval]] ;    
	  [newForecast setCval: [parent2 getCval]] ;
	}
    }

  {  //This is just error checking!
    int * newcond;
    int specificity=0;
    /* Set miscellanaeous variables (but not lastactive, strength, variance) */
    [newForecast setCnt: 0 ];	// call it new in any case
    //[newforecast setSpecficity = -pp->nnulls]; //?? omit this!!
    newcond = [newForecast getConditions];
    for (bit = 0; bit < privateParams->condbits; bit++)
      //if ((newcond[WORD(bit)]&MASK[bit]) != 0)
      if ((newcond[WORD(bit)]&( 3 << ((bit%16)*2))) != 0)
	{
	  specificity++;
	}
    //  nr->specificity = specificity;
    printf("CrossoverDiagnostic: newforecast Specificity %d should equal %d \n", [newForecast getSpecificity],specificity);
    //nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
  }
 
  [newForecast updateSpecfactor];
  //bfagent:  nr->strength = 0.5*(rule[parent1].strength+rule[parent2].strength);

  [newForecast setStrength :  0.5*([parent1 getStrength] + [parent2 getStrength])];

  return newForecast;
}


/*------------------------------------------------------*/
/*	TransferFcasts					*/
/*------------------------------------------------------*/
- (void) TransferFcastsFrom: newList To:  forecastList Replace: rejects 
{
  //register struct BF_fcast *fptr, *nr;
  //register int new;
  //      int nnew;
  id ind;
  BFCast * aForecast;
  BFCast * toDieForecast;

      //nnew = pp->nnew;
 
  ind = [newList begin: [self getZone]];
  for ( aForecast = [ind next]; [ind getLoc]==Member; aForecast=[ind next] )
    {
      //toDieForecast = GetMort(aForecast, rejects);
      toDieForecast = [self GetMort: aForecast Rejects: rejects];
      toDieForecast = [self CopyRule: toDieForecast From: aForecast];
    }
  [ind drop];
	
  ///      for (new = 0; new < nnew; new++) 
  //  	{
  //  	  nr = newfcast + new;
  //  	  fptr = GetMort(nr);
      
  //  	  // Copy the whole structure and conditions
  //  	  CopyRule(fptr, nr);
  //	}
}



/*------------------------------------------------------*/
/*	GetMort						*/
/*------------------------------------------------------*/
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects
  /* GetMort() selects one of the npool weak old fcasts to replace
     * with a newly generated rule.  It pays no attention to strength,
     * but looks at similarity of the condition bits -- like tournament
     * selection, we pick two candidates at random and choose the one
     * with the MORE similar bitstring to be replaced.  This maintains
     * more diversity.
     */
{
  //register int bit, temp1, temp2, different1, different2;
  // struct BF_fcast *fptr;
  //unsigned int *cond1, *cond2, *newcond;
  //int npool, r1, r2, word, bitmax;

  unsigned int *cond1; unsigned int *cond2; unsigned int * newcond;
  int numrejects, r1, r2, word, bitmax = 0;
  int bit, different1, different2, temp1, temp2;
  BFCast * aReject;
  
  numrejects = privateParams->npool;
  //npool=[reject getCount];

  do 
    {
      r1 = irand(numrejects);
    }
  while ( [rejects atOffset: r1] == nil );
  

  do
    {
      r2 = irand(numrejects);
    }
  while (r1 == r2 || [rejects atOffset: r2] == nil);
      

  cond1 = [[rejects atOffset: r1] getConditions];
  cond2 = [[rejects atOffset: r2] getConditions];

  newcond = [new getConditions];

  different1 = 0;
  different2 = 0;
  bitmax = 16;
  for (word = 0; word < privateParams->condwords; word++) 
    {
      temp1 = cond1[word] ^ newcond[word];
      temp2 = cond2[word] ^ newcond[word];
      if (word == privateParams->condwords-1)
	bitmax = ((privateParams->condbits-1)&15) + 1;
      for (bit = 0; bit < bitmax; temp1 >>= 2, temp2 >>= 2, bit++) 
	{
	  if (temp1 & 3)
	    different1++;
	  if (temp2 & 3)
	    different2++;
	}
    }

  /*
   *  This is the big decision whether to push diversity by selecting rules
   *  to leave.  Original version is 1 which choses the least different rules
   *  to leave.  Version 2 choses at random, and version 3 choses the least
   *  frequently used rule.  
   */
  if (different1 < different2) 
    {
      aReject = [rejects atOffset: r1];
      [ rejects atOffset: r1  put: nil] ;
    }
  else 
    {
      aReject = [rejects atOffset: r2];
      [ rejects atOffset: r2 put:  nil] ;
    }
  /*
    fptr = reject[r1];
    reject[r1] = NULL;
  */
  /*
    if(reject[r1]->count < reject[r2]->count) {
    fptr = reject[r1];
    reject[r1] = NULL;
    }
    else {
    fptr = reject[r2];
    reject[r1] = NULL;
    }
  */
  
  return aReject;
}



/*------------------------------------------------------*/
/*	Generalize					*/
/*------------------------------------------------------*/
-(void) Generalize: (id) list AvgStrength: (double) avgstrength
  /*
     * Each forecast that hasn't be used for longtime is generalized by
     * turning a fraction genfrac of the 0/1 bits to don't-cares.
     */
{
  register struct BFCast *aForecast;
  register int f;
  int bit, j;
  BOOL changed;
  // int currentTime;
 int * bitlist=NULL;

 bitlist = [privateParams getBitListPtr];

  currentTime = getCurrentTime();

  for (f = 0; f < privateParams->numfcasts; f++) 
    {
      aForecast = [ list atOffset: f ] ;
      if (currentTime - [aForecast getLastactive] > privateParams->longtime) 
	{
	  changed = NO;
	  j = (int)ceil([aForecast getSpecificity]*privateParams->genfrac);
	  for (;j>0;) 
	    {
	      bit = irand(privateParams->condbits);
	      if (bitlist[bit] < 0) continue;
	      // if ((aForecast->conditions[WORD(bit)]&MASK[bit])) 
	      if ( [aForecast getConditionsbit: bit] > 0)
		{
		  // aForecast->conditions[WORD(bit)] &= NMASK[bit];
		  [aForecast maskConditionsbit: bit];
		  [aForecast decrSpecificity];
		  changed = YES;
		  j--;
		}
	    }
	  if (changed) 
	    {
	      [aForecast setCnt: 0];
	      [aForecast setLastactive: currentTime];
	      [aForecast updateSpecfactor];
	      [aForecast setVariance: [aForecast getSpecfactor] / avgstrength];
	      [aForecast setStrength: [aForecast getSpecfactor]/[aForecast getVariance]];
	      //???????????????????????
	      //??bfagent has:   
	      /*  rptr->specfactor = (condbits - pp->nnulls - rptr->specificity)*
		  pp->bitcost;
		  medvar = pp->maxdev-medianstrength+rptr->specfactor;
		  if (medvar >= 0.0)
		  rptr->variance = medvar;
		  rptr->strength = medianstrength;*/

	    }
	}
    }
}


//pj: in case you want to see the 0101 representation of an integer:
- printcond: (int) word
{
  int i;
  int n = sizeof(int) * CHAR_BIT;
  int mask = 1 << (n-1);
  int  input=word;

  for ( i=1; i <= n; ++i)
    {
      putchar(((input & mask) == 0) ? '0' : '1');
      input <<= 1;
      if (i % CHAR_BIT == 0 && i < n)
  	putchar(' ');
    }
  return self;
}

- copyList: list To: outputList
{
  id index, anObject;

 [outputList removeAll];
  index = [ list begin: [self getZone] ];
  for( anObject = [index next]; [index getLoc]==Member; anObject=[index next] )
    {
      [outputList addLast: anObject];
    }
  return self;
}


@end













