// Code for a Social agent

#import "SOCagent.h"
#import <random.h>

#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 

@implementation SOCagent

//************************************************************************
- (BOOL)PickParents: (BFCast *)aNewForecast
{
  double psocial = 0;
  int startsocial = 0;
  BFCast * parent1, * parent2;
  id agent;
  BOOL changed = NO;
  
  psocial = privateParams->psocial;
  startsocial = privateParams->startsocial;

  //currentTime got updated right before start of GA, so we can use it
  if (currentTime < startsocial)
    {
      [super PickParents: aNewForecast];
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
	  
	  [self Crossover:  aNewForecast Parent1:  parent1 Parent2:  parent2];
	  if (aNewForecast==nil) {raiseEvent(WarningMessage,"got nil back from crossover");}
	  changed = YES;
	}
      else
	{
	  [self CopyRule: aNewForecast From: parent1];
	  if(!aNewForecast)raiseEvent(WarningMessage,"got nil back from CopyRule");
	  
	  changed = [self Mutate: aNewForecast  Status: changed];
	}
    }
  else
    {
      //First type of social behaviour: take strongest rule of agent
      //at position 0 and copy it into your own list.
      BFCast * strForecast;
      agent = [agentList atOffset: 0];
      strForecast= [agent getStrongestBFCast];	  

      [self CopyRule: aNewForecast From: strForecast];

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













