// Code for a Social agent

#import "SOCagent.h"
#import <random.h>

#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1]
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1] 

@implementation SOCagent

//************************************************************************
- (BOOL)PickParents: (BFCast *)aNewForecast Strength: (double)medstrength
{
  double psocial = 0;
  int startsocial = 0;
  BFCast * parent1, * parent2;
  id agent;
  BOOL changed = NO;
  int numagents = [agentList getCount];
  
  psocial = privateParams->psocial;
  startsocial = privateParams->startsocial;

  //currentTime got updated right before start of GA, so we can use it
  if (currentTime < startsocial) 
  {
      changed = [super PickParents: aNewForecast Strength: medstrength];
      return changed;
    }

  if (drand() > psocial) 
    {
      //for comments on that part of if statement see same passage in BFagent.m
      do
	parent1 = [ super Tournament: fcastList ] ;
      while (parent1 == nil);
      
      if (drand() < privateParams->pcrossover) 
	{
	  do
	    parent2 = [self  Tournament: fcastList];
	  while (parent2 == parent1 || parent2 == nil) ;
	  
	  [self Crossover:  aNewForecast Parent1:  parent1 Parent2:  parent2 Strength: medstrength];
	  if (aNewForecast==nil) {raiseEvent(WarningMessage,"got nil back from crossover");}
	  changed = YES;
	}
      else
	{
	  [self CopyRule: aNewForecast From: parent1];
	  if(!aNewForecast)raiseEvent(WarningMessage,"got nil back from CopyRule");
	  changed = [self Mutate: aNewForecast  Status: changed Strength: medstrength];
	}
    }
  else
    {
      //First type of social behaviour: take strongest rule of agent
      //at position 0 and copy it into your own list.
      //      BFCast * strForecast;
      //      agent = [agentList atOffset: 0];
      //      strForecast= [agent getStrongestBFCast];
      //
      //      [self CopyRule: aNewForecast From: strForecast];
      //********************************************************************

      //Second type of social behaviour: take strongest rule of either
      //left or right agent and copy it into your own list.
      BFCast * strForecast;
      int neighbour, me;
      me = [self getID];
      
      if (irand(2) == 0) neighbour = ((me - 1)+numagents)%numagents;
      else neighbour = ((me + 1)+numagents)%numagents;
      agent = [agentList atOffset: neighbour];
      strForecast= [agent getStrongestBFCast];
      
      [self CopyRule: aNewForecast From: strForecast];
      //*******************************************************************
      
    }
 
  return changed;
}


- (void)lispOutDeep: stream
{

 [stream catStartMakeInstance: "SOCagent"];
 [super bareLispOutDeep: stream];
 [stream catEndMakeInstance];

}

@end













