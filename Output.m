#import "Output.h"

#include <misc.h> // stdio, time



/*"
To show the possible data output tools, I have 3
different ways of saving the output time streams from the model.  All
three should be similar/equivalent representations of the numbers.

1) Text output of data streams.
2) HDF5 or LISP format output of object dumps from a "putShallow"
   call to a data archiver object. This dumps full snapshots of
   the world and the specialist into a LISP on hdf5 archive.
3) HDF5 output EZGraph which writes one vector per plotted line
   into an hdf5 file.

This code has a preprocessor flag to control the behavior of data
storage. If compile without any CPP flags, then the data files are
saved in the .scm format, which is "scheme".  Otherwise, use the flag
NO_LISP, and it uses hdf5 format. In Swarm, that means you type the
make command:

 make EXTRACPPFLAGS=-DNO_LISP


The buttons in the ASMObserverSwarm display turn on data saving.  Look
for "writeSimulationParams" and the other "toggleDataWrite".  These
were in the original ASM Swarm model, but I've replaced the
functionality with the newer storage methods.  The data is saved only
if you turn on the writeData option. If "toggleDataWrite" is empty or
false, hit that button and it shows "true". When the model runs,
output will be created. If you run the program in batch mode, it
automatically turns on the data writing.

Please note that if you want the simulation to save your parameter
values to a file, you can click the GUI button
"writeSimulationParams." If you push that button, the system writes
the parameter values into a file, such as

guiSettingsThu_Jun_28_23_48_00_2001.scm


if you did not compile with the NO_LISP flag.  Otherwise you get a
.hdf file.  One key change from the old ASM is that you can push that
button at time 0, and it will save a snap at that time, and any time
you stop the model, you can change parameters and punch the button
again, and it will also save a snapshot at quit time.  I believe this
works fine now, but it was a little tricky making sure the objects are
created in the right order and early enough to allow this to work.

Now, just a word about data formatting.  Because it is familiar and
compatible with existing programs, I often prefer to save data in raw
ASCII format.  In case you want text output, this shows you how to do it.
I think filenames that have the date in them are good to
help remember when they were originally created, for example.  It
creates an ASCII file, for example,

output.data_Thu_Jun_28_23_48_00_2001


However, I understand the reasons others are pushing to use more
refined formats.  Many people are digging into hdf5 format for data
storage, and I've taken a look at that too.  I took the easy road and
just dumped the whole world and specialist class with swarm's
archiver. It seems to work great?!  The output file is called
something like

swarmDataArchiveFri_Jun_29_16_29_25_2001.hdf
or
swarmDataArchiveFri_Jun_29_16_22_59_2001.scm

You note here that output uses the current time and date to write the
output file names. Today I ran an example and ended up with these
three files of output:

output.dataWed_Oct_24_11_30_18_2001
swarmDataArchiveWed_Oct_24_11_30_18_2001.scm
hdfGraphWed_Oct_24_11_30_18_2001.hdf
"*/
@implementation Output


/*"createEnd does a lot of specific things that make the data output
  objects work. It gets the system time, uses that to fashion a
  filename that includes the time, then where necessary it creates
  archivers which will later be called on to get readings on the
  system and record them."*/
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

/*"The output object needs to have a reference to a Specialist object, from whom it can gather data on the volume of trade."*/
- setSpecialist: (Specialist *)theSpec
{
  outputSpecialist = theSpec;

  [hdfWriter createSequence: "volume"
	     withFeedFrom: outputSpecialist
	     andSelector: M(getVolume)];
  return self;
}

/*"The output object must have a reference to a World object, from which it can get price, dividend, or any other information it wants"*/
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

/*"This flushes a snapshot of the current parameter settings from
  both the ASMModelParams and BFAgentParams into a file"*/
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



/*"Because it is possible for users to turn on data writing during a
  run of the simulation, it is necessary to have this method which can
  initialize the data output files. Each time this is called, it
  checks to see if the files have already been initialized. That way
  it does not initialize everything twice."*/
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


/*"The write data method dumps out measures of the price, dividend, and volume indicators into several formats"*/
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

/*"It is necessary to drop the data writing objects in order to make
sure they finish their work.
"*/
-(void) drop
{
  if (dataOutputFile) fclose(dataOutputFile);
  [hdfWriter drop];
  [archiver drop];
  [dataArchiver drop];
  [super drop];
}

@end



