#import "Output.h"

#include <misc.h> // stdio, time

@implementation Output

- createEnd
{
  int i;
 
  char paramFileName[100];

  char dataArchiveName[100];

  if(!runTime)
    runTime = time(NULL);
  dataFileExists = NO;
 
  strcpy (timeString, ctime(&runTime));

  for (i = 0; i < 100; i++)
    {
      if (timeString[i] == ' ' || timeString[i] == ':')
	timeString[i] = '_';
      else if (timeString[i] == '\n')
	timeString[i] = '\0';
    }



  if (swarmGUIMode == 1)
    strcpy (paramFileName,"guiSettings");
  else
    strcpy (paramFileName,"batchSettings");

  strcat (paramFileName, timeString);
 

  strcpy (dataArchiveName,"swarmDataArchive");
  strcat (dataArchiveName, timeString);


#ifndef USE_LISP
  strcat (paramFileName,".hdf");
  strcat (dataArchiveName,".hdf");
#else
  strcat (paramFileName,".scm");
  strcat (dataArchiveName,".scm");
#endif
 
#ifndef USE_LISP
  archiver = [HDF5Archiver create: [self getZone] setPath: paramFileName];
  dataArchiver = [HDF5Archiver create: [self getZone] setPath: dataArchiveName];
#else
  //unlink ("settingsSaved.scm");
  archiver = [LispArchiver create: [self getZone] setPath: paramFileName];
  //unlink ("settingsSaved.scm");
  dataArchiver = [LispArchiver create: [self getZone] setPath: dataArchiveName];


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

  if (dataFileExists == YES) return self;

  else{
    
    strcpy (outputFile,"output.data");
    strcat (outputFile, timeString);
 
    
    if(!(dataOutputFile = fopen(outputFile,"w")))
      abort();
    fprintf (dataOutputFile, "currentTime\t price\t\t dividend\t volume\n\n");
    dataFileExists = YES;
  }
  return self;
}


-writeData
{

  long t = getCurrentTime();
  char worldName[50];
  char specName[50];

  fprintf (dataOutputFile, "%10ld\t %5f\t %8f\t %f\n", 
	   t, 
           [outputWorld getPrice],
           [outputWorld getDividend], 
           [outputSpecialist getVolume]);

   sprintf (worldName, "world-%4.0ld",t);
   sprintf (specName, "specialist-%4.0ld",t); 

   [dataArchiver putShallow: worldName object: outputWorld];
#ifdef USE_LISP
  [dataArchiver sync];
#endif

   [dataArchiver putShallow: specName  object: outputSpecialist];
#ifdef USE_LISP
   [archiver sync];
#endif

  
  return self;
}

@end
