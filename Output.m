#import "Output.h"

#include <misc.h> // stdio, time

@implementation Output

- createEnd
{
  int i;
 
  char paramFileName[100];

  char dataArchiveName[100];

  char hdfEZGraphName[100];

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

  strcpy (hdfEZGraphName,"hdfGraph");
  strcat (hdfEZGraphName, timeString);
  strcat (hdfEZGraphName, ".hdf");

#ifdef NO_LISP
  strcat (paramFileName,".hdf");
  strcat (dataArchiveName,".hdf");
#else
  strcat (paramFileName,".scm");
  strcat (dataArchiveName,".scm");
#endif
 
#ifdef NO_LISP
  archiver = [HDF5Archiver create: [self getZone] setPath: paramFileName];
  dataArchiver = [HDF5Archiver create: [self getZone] setPath: dataArchiveName];
#else
  //unlink ("settingsSaved.scm");
  archiver = [LispArchiver create: [self getZone] setPath: paramFileName];
  //unlink ("settingsSaved.scm");
  dataArchiver = [LispArchiver create: [self getZone] setPath: dataArchiveName];

#endif
  
  {
    hdf5container = [HDF5 createBegin: [self getZone]];
    [hdf5container setWriteFlag: YES];
    [hdf5container  setName: hdfEZGraphName];
    hdf5container = [hdf5container createEnd];
    
    hdfWriter = [EZGraph create: [self getZone] 
			 setHDF5Container: hdf5container
			 setPrefix: "market"];
  }

  return self;
}


- setSpecialist: (Specialist *)theSpec
{
  outputSpecialist = theSpec;

  [hdfWriter createSequence: "volume"
	     withFeedFrom: outputSpecialist
	     andSelector: M(getVolume)];
  return self;
}

- setWorld: (World *)theWorld;
{
  outputWorld = theWorld;

    
  [hdfWriter createSequence: "price"
	     withFeedFrom: outputWorld
	     andSelector: M(getPrice)];


  [hdfWriter createSequence: "dividend"
	     withFeedFrom: outputWorld
	     andSelector: M(getDividend)];
  return self;
}

- writeParams: modelParam BFAgent: bfParms Time: (long int) t
{
  char modelKey[20];
  char paramKey[20];
 

  sprintf (modelKey, "modelParams%ld",t);
  sprintf (paramKey, "bfParams%ld",t);
  
  [archiver putShallow: modelKey object: modelParam];
#ifndef NO_LISP
  [archiver sync];
#endif

   [archiver putShallow: paramKey  object: bfParms];
#ifndef NO_LISP
   [archiver sync];
#endif
   return self;
}



//Setup the output file.
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

  //**** I've got 3 ways to write out numerical results. *****//
  //**** Choose what you like ****//


  // First, just dump out the raw numbers in text.
  // This is the old standby!

  fprintf (dataOutputFile, "%10ld\t %5f\t %8f\t %f\n", 
	   t, 
           [outputWorld getPrice],
           [outputWorld getDividend], 
           [outputSpecialist getVolume]);


  // Second, dump those same values out to an hdf5 format file.  This
  // uses the Archiver library "put shallow" to dump all primitive
  // types, ints and doubles mainly.

  sprintf (worldName, "world%ld",t);
  sprintf (specName, "specialist%ld",t); 

  [dataArchiver putShallow: worldName object: outputWorld];
#ifndef NO_LISP
  [dataArchiver sync];
#endif

  [dataArchiver putShallow: specName  object: outputSpecialist];
#ifndef NO_LISP
  [archiver sync];
#endif
   // Third, now use the EZGraph dump of its time strings.
   [hdfWriter step];
   
   return self;
}


-(void) drop
{
  [hdfWriter drop];
  [archiver drop];
  [dataArchiver drop];
  [super drop];
}



@end
