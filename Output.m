#import "Output.h"

#include <misc.h> // stdio, time

@implementation Output

- setSpecialist: (Specialist *)theSpec
{
  outputSpecialist = theSpec;
  return self;
}

- setWorld: (World *)theWorld;
{
  outputWorld = theWorld;
  return self;
}

- setNumBFagents: (int)BFagents
{
  numBFagents = BFagents;
  return self;
}

- setInitHolding: (float)Holding
{
  initholding = Holding;
  return self;
}

- setInitialCash: (double)initcash;
{
  initialcash = initcash;
  return self;
}

- setminHolding: (double)holding   minCash: (double)minimumcash
{
  minholding = holding;
  mincash = minimumcash;
  return self;
}

- setIntRate: (double)Rate
{
  intrate = Rate;
  return self;
}

- setBaseline: (double)theBaseline
{
  baseline = theBaseline;
  return self;
}

- setmindividend: (double)minimumDividend
{
  mindividend = minimumDividend;
  return self;
}

- setmaxdividend: (double)maximumDividend
{
  maxdividend = maximumDividend;
  return self;
}

- setTheAmplitude: (double)theAmplitude
{
  amplitude = theAmplitude;
  return self;
}

- setThePeriod: (int)thePeriod
{
  period = thePeriod;
  return self;
}

- setExponentialMAs: (BOOL)aBool
{
  exponentialMAs = aBool;
  return self;
}

- setMaxPrice: (double)maximumPrice
{
  maxprice = maximumPrice;
  return self;
}

- setMinPrice: (double)minimumPrice
{
  minprice = minimumPrice;
  return self;
}

- setTaup: (double)aTaup
{
  taup = aTaup;
  return self;
}

- setSPtype: (int)i
{
  sptype = i;
  return self;
}

- setMaxIterations: (int)someIterations
{
  maxiterations = someIterations;
  return self;
}

- setMinExcess: (double)minimumExcess
{
  minexcess = minimumExcess;
  return self;
}

- setETA: (double)ETA
{
  eta = ETA;
  return self;
}

- setETAmin: (double)ETAmin
{
  etamin = ETAmin;
  return self;
}

- setETAmax: (double) ETAmax
{
  etamax = ETAmax;
  return self;
}

- setREA: (double)REA
{
  rea = REA;
  return self;
}

- setREB: (double)REB
{
  reb = REB;
  return self;
}

- setSeed: (int)aSeed;
{
  seed = aSeed;
  return self;

}

- setTauv: (double)aTauv
{
  tauv = aTauv;
  return self;
}


- setLambda: (double)aLambda
{
  lambda = aLambda;
  return self;
}


- setMaxBid: (double)maximumBid
{
  maxbid = maximumBid;
  return self;
}


- setInitVar: (double)initialVar
{
  initvar = initialVar; 
  return self;
}


- setMaxDev: (double)maximumDev
{
  maxdev = maximumDev;
  return self;
}


- writeParams
{
  char paramFile[256];
  int i;
  
  if (!runTime)
    runTime = time(NULL);
  
  strcpy (paramFile,"param.data");
  strcat (paramFile," ");
    
  strcat (paramFile, ctime (&runTime));
  for (i = 0; i < 256; i++)
    {
      if (paramFile[i] == ' ' || paramFile[i] == ':')
	paramFile[i] = '_';
      if (paramFile[i] == '\n')
	paramFile[i] = '\0';
    }
  
  if(!(paramOutputFile = fopen(paramFile, "w")))
    abort();

  fprintf (paramOutputFile, "@begin\n");
  fprintf (paramOutputFile, "numBFagents %d\n",numBFagents);
  fprintf (paramOutputFile, "initholding %f\n",initholding);
  fprintf (paramOutputFile, "initialcash %f\n",initialcash);
  fprintf (paramOutputFile, "minholding %f\n",minholding);
  fprintf (paramOutputFile, "mincash %f\n",minholding);
  fprintf (paramOutputFile, "intrate %f\n",intrate);
  
  fprintf (paramOutputFile, "baseline %f\n",baseline);
  fprintf (paramOutputFile, "mindividend %f\n",mindividend);
  fprintf (paramOutputFile, "maxdividend %f\n",maxdividend);
  fprintf (paramOutputFile, "amplitude %f\n",amplitude);
  fprintf (paramOutputFile, "period %d\n",period);

  fprintf (paramOutputFile, "exponentialMAs %d\n",exponentialMAs);

  fprintf (paramOutputFile, "maxprice %f\n",maxprice);
  fprintf (paramOutputFile, "minprice %f\n",minprice);
  fprintf (paramOutputFile, "taup %f\n",taup);
  fprintf (paramOutputFile, "sptype %d\n",sptype);
  fprintf (paramOutputFile, "maxiterations %d\n",maxiterations);
  fprintf (paramOutputFile, "minexcess %f\n",minexcess);
  fprintf (paramOutputFile, "eta %f\n",eta);
  fprintf (paramOutputFile, "etamax %f\n",etamax);
  fprintf (paramOutputFile, "etamin %f\n",etamin);
  fprintf (paramOutputFile, "rea %f\n",rea);
  fprintf (paramOutputFile, "reb %f\n",reb);

  fprintf (paramOutputFile, "randomSeed %d\n",seed);

  fprintf (paramOutputFile, "tauv %f\n",tauv);
  fprintf (paramOutputFile, "lambda %f\n",lambda);
  fprintf (paramOutputFile, "maxbid %f\n",maxbid);
  fprintf (paramOutputFile, "initvar %f\n",initvar);
  fprintf (paramOutputFile, "maxdev %f\n",maxdev);
  fprintf (paramOutputFile, "@end\n");

  fclose(paramOutputFile);

  return self;
}


- prepareOutputFile
{
  char outputFile[256];
  int i;
  
  if(!runTime)
    runTime = time(NULL);
          
  strcpy (outputFile,"output.data");
  strcat (outputFile," ");
    
  strcat (outputFile,ctime (&runTime));
  for (i = 0; i < 256; i++)
    {
      if (outputFile[i] == ' ' || outputFile[i] == ':')
	outputFile[i] = '_';
      else if (outputFile[i] == '\n')
	outputFile[i] = '\0';
    }
      
  if(!(dataOutputFile = fopen(outputFile,"w")))
    abort();
  fprintf (dataOutputFile, "currentTime\t price\t\t dividend\t volume\n\n");
  return self;
}


-writeData
{
  fprintf (dataOutputFile, "%10ld\t %5f\t %8f\t %f\n", 
           getCurrentTime (), 
           [outputWorld getPrice],
           [outputWorld getDividend], 
           [outputSpecialist getVolume]);
  
  return self;
}

@end
