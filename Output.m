#import "Output.h"

#include <misc.h> // stdio, time

@implementation Output

- createEnd
{
  int i;
 
  char paramFileName[100];
  if(!runTime)
    runTime = time(NULL);
  dataFileExists = NO;
 
  if (swarmGUIMode == 1)
    strcpy (paramFileName,"guiSettings");
  else
    strcpy (paramFileName,"batchSettings");
  strcat (paramFileName, ctime (&runTime));
  for (i = 0; i < 256; i++)
    {
      if (paramFileName[i] == ' ' || paramFileName[i] == ':')
	paramFileName[i] = '_';
      else if (paramFileName[i] == '\n')
	paramFileName[i] = '\0';
    }

#ifndef USE_LISP
  strcat (paramFileName,".hdf");
#else
  strcat (paramFileName,".scm");
#endif
 
#ifndef USE_LISP
  archiver = [HDF5Archiver create: [self getZone] setPath: paramFileName];
#else
  unlink ("settingsSaved.scm");
  archiver = [LispArchiver create: [self getZone] setPath: paramFileName];
#endif
 
  return self;
}


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

- writeParams: modelParam BFAgent: bfParms Time: (long int) t
{
  char modelKey[20];
  char paramKey[20];
  sprintf (modelKey, "modelParams-%ld",t);
  sprintf (paramKey, "bfParams-%ld",t);
  
  [archiver putShallow: modelKey object: modelParam];
#ifdef USE_LISP
  [archiver sync];
#endif

   [archiver putShallow: paramKey  object: bfParms];
#ifdef USE_LISP
   [archiver sync];
#endif
   return self;
}


- prepareOutputFile
{
  char outputFile[256];
  int i;

  if (dataFileExists == YES) return self;

  else{
    
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
   dataFileExists = YES;
 }
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
