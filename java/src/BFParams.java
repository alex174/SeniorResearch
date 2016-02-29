import swarm.objectbase.Swarm;
import swarm.objectbase.SwarmImpl;
import swarm.objectbase.SwarmObject;
import swarm.objectbase.SwarmObjectImpl;

import swarm.objectbase.VarProbe;
import swarm.objectbase.VarProbeImpl;
import swarm.objectbase.MessageProbe;
import swarm.objectbase.EmptyProbeMapImpl;

import swarm.Globals;

import swarm.defobj.Zone;


public class BFParams extends SwarmObjectImpl
{

  public int numfcasts = 100; /*"number of forecasts maintained by this agent"*/
  public  int condwords; /*"number of words of memory required to hold bits"*/
  public  int condbits = 16; /*"number of conditions bits are monitored"*/
    public int mincount = 5; /*"minimum number of times forecast must be used to become active"*/
    public int gafrequency = 250; /*"how often is genetic algorithm done?"*/
    public int firstgatime = 250; /*"after how many time steps is the genetic algorithm done"*/
    public int longtime = 250;	/*" unused time before Generalize() in genetic algorithm"*/
    public int individual = 0;
    public double tauv = 75;
    public double lambda = 0.5;
    public double maxbid = 10;
    public double bitprob = 0.1;
    public double subrange = 0.5;	/*" fraction of min-max range for initial random values"*/
    public double a_min = 0.7,a_max = 1.2;	/*" min and max for p+d coef"*/
    public double b_min = 0,b_max = 0;	/*" min and max for div coef"*/
    public double c_min = -7.293691545,c_max = 21.70630846;	/*" min and max for constant term"*/
    public double a_range,b_range,c_range;	/*" derived: max - min" */
    public double newfcastvar = 3.999769641;	/*" variance assigned to a new forecaster"*/
    public double initvar = 3.999769641;	/*" variance of overall forecast for t<200"*/
    public double bitcost = 0.01;	/*" penalty parameter for specificity"*/
    public double maxdev = 100;	/*" max deviation of a forecast in variance estimation"*/
    public double poolfrac = 0.1;	/*" fraction of rules in replacement pool"*/
    public double newfrac = 0.05;	/*" fraction of rules replaced"*/
    public double pcrossover = 0.3;	/*" probability of running Crossover()."*/
    public double plinear = 0.333;	/*" linear combination "crossover" prob."*/
    public double prandom = 0.333;	/*" random from each parent crossover prob."*/
    public double pmutation = 0.01;	/*" per bit mutation prob."*/
    public double plong = 0.05;	        /*" long jump prob."*/
    public double pshort = 0.2;	/*" short (neighborhood) jump prob."*/
    public double nhood = 0.05;	        /*" size of neighborhood."*/
    public double genfrac = 0.10;	/*" fraction of 0/1 bits to generalize"*/
    public double gaprob;	/*" derived: 1/gafrequency"*/
    public int npool;		/*" derived: replacement pool size"*/
    public int nnew;		/*" derived: number of new rules"*/
    public int nnulls = 0;            /*" unnused bits"*/
    public int[] bitlist = new int[condbits];		/*" dynamic array, length condbits"*/
    public double[] problist = new double[condbits];	/*" dynamic array, length condbits"*/

    public int npoolmax = -1;		/* size of reject array */
    public int nnewmax = -1;		/* size of newfcast array */
    public int ncondmax = -1;		/* size of newc*/

  public static final int MAXCONDBITS = 80;


  // Values in table of special bit names (negative, avoiding NULLBIT)
  public static final int ENDLIST = -2;
  public static final int ALL = -3;
  public static final int SETPROB = -4;
  public static final int BADINPUT = -5;
  public static final int NOTFOUND = -6;
  public static final int EQ = 0;
  public static final int NULLBIT = -1;
  public static KeyTable specialbits[] = new KeyTable[9];


  //Macros for bittables
  public int WORD( int bit){
    int a;
    a = bit>>4;
    return a;
  }


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


  public Object init()
  {
    int i;

    int bits[]=new int[MAXCONDBITS];
    //  double probs[MAXCONDBITS];
    //pj 2001-11-02. For ASM-2.2, I'm sticking with the ASM-2.0
    //"all agents have 16 bits" rule. But I'm not sticking with it
    //after that!  With USEALLBITS, I'm
    //just experimenting to see what difference it makes.
    //
    boolean USEALLBITS = false;

    if (USEALLBITS!=true)
      {
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
      }
    else
      {
        condbits = 60;

        for(i=0; i < condbits; i++) bits[i]=i;
      }

    for (i=0; i < condbits; i++)
      {
        bitlist[i] = bits[i];
        //params->problist[i] = probs[i];
        problist[i] = bitprob;
      }

    // Allocate space for our world bits, clear initially

    condwords = (condbits+15)/16;

    //  myworld = [[self getZone] allocBlock: condwords* sizeof(unsigned int)];

    //   for (i=0; i< condwords; i++)
    //      myworld[i] = 0;

    // Check bitcost isn't too negative
    if (1.0+bitcost*(condbits-nnulls) <= 0.0)
      System.out.println("The bitcost is too negative.");

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
    return this;//super.createEnd();
  }

  public int[] getBitListPtr()
  {
    return bitlist;
  }

  /*"if passed a pointer to an array of integers of length size, this
    frees the old bitlist and puts the new one in its place"*/
  public void copyBitList$Length (int[] x , int size)
  {
    int i;
    for (i=0; i < size; i++)
      {
        bitlist[i] = x[i];
      }
  }

  public double[] getProbListPtr()
  {
    return problist;
  }

  /*"if passed a pointer to a double with a given size, this frees the
    old bitlist and puts the new one in its place"*/
  public void copyProbList$Length (double[] p , int size)
  {
    int i;
    for (i=0; i < size; i++)
      {
        problist[i] = p[i];
      }
  }


  public int ReadBitname(String variable, KeyTable[] table)
  /*
   * Like ReadKeyword, but looks up the name first as the name of a bit
   * and then (if there's no match) in table if it's non-NULL.
   */
  {
    KeyTable[] ptr;
    int n;

    n = World.bitNumberOf(variable);
/*
    if (n < 0 && table)
      {
        for (ptr=table; ptr->name; ptr++)
          if (strcmp(variable,ptr->name) == EQ)
            break;
        if (!ptr->name && strcmp(variable,"???") != EQ)
          printf("unknown keyword '%s'\n",variable);
        n = ptr->value;
      }
*/
    return n;
  }


  /*"Create a copy of this BFParams instance. Note this copies EVERY
    instance variable, one by one"*/
  public BFParams copy( Zone aZone)
  {
    BFParams bfParams = new BFParams(aZone,true) ;

    //Why not begin with a totally fresh instance created from scratch,
    //The way your old granny used to do it?
    //if ((bfParams = (BFParams) Globals.env.lispAppArchiver.getWithZone$key(this.getZone(),"bfParams"))== null)
    //      System.out.println("Can't find the BFParam's parameters");

    //Then replace all those values granny liked (:

    bfParams.numfcasts =  numfcasts;
    bfParams.condwords = condwords ;
    bfParams.condbits = condbits;
    bfParams.mincount = mincount;
    bfParams.gafrequency = gafrequency;
    bfParams.firstgatime = firstgatime;
    bfParams.longtime = longtime;
    bfParams.individual = individual;
    bfParams.tauv = tauv;
    bfParams.lambda = lambda;
    bfParams.maxbid = maxbid;
    bfParams.bitprob = bitprob;
    bfParams.subrange = subrange;
    bfParams.a_min = a_min;
    bfParams.a_max = a_max;
    bfParams.b_min = b_min;
    bfParams.b_max = b_max;
    bfParams.c_min = c_min;
    bfParams.c_max = c_max;
    bfParams.a_range = a_range;
    bfParams.b_range = b_range;
    bfParams.c_range = c_range;
    bfParams.newfcastvar = newfcastvar;
    bfParams.initvar = initvar;
    bfParams.bitcost = bitcost;
    bfParams.maxdev = maxdev;
    bfParams.poolfrac = poolfrac;
    bfParams.newfrac = newfrac;
    bfParams.pcrossover = pcrossover;
    bfParams.plinear = plinear;
    bfParams.prandom = prandom;
    bfParams.pmutation = pmutation;
    bfParams.plong = plong;
    bfParams.pshort = pshort;
    bfParams.nhood = nhood;
    bfParams.genfrac = genfrac;
    bfParams.gaprob = gaprob;
    bfParams.npool = npool;
    bfParams.nnew = nnew;
    bfParams.nnulls = nnulls;
    bfParams.npoolmax = npoolmax;
    bfParams.nnewmax =  nnewmax;
    bfParams.ncondmax = ncondmax;

    bfParams.copyBitList$Length( bitlist , condbits);
    bfParams.copyProbList$Length( problist , condbits);
    return bfParams;
  }

  BFParams(Zone aZone){
  super (aZone);

  specialbits[0]=new KeyTable("null", NULLBIT);
  specialbits[1]=new KeyTable("end", ENDLIST);
  specialbits[2]=new KeyTable(".", ENDLIST);
  specialbits[3]=new KeyTable("all", ALL);
  specialbits[4]=new KeyTable("allbits", ALL);
  specialbits[5]=new KeyTable("p", SETPROB);
  specialbits[6]=new KeyTable("P", SETPROB);
  specialbits[7]=new KeyTable("???", BADINPUT);
  specialbits[8]=new KeyTable(null,  NOTFOUND);

    class BFParamsProbeMap extends EmptyProbeMapImpl {
      private VarProbe probeVariable (String name) {
        return
          Globals.env.probeLibrary.getProbeForVariable$inClass
          (name, BFParams.this.getClass ());
      }
      private MessageProbe probeMessage (String name) {
        return
          Globals.env.probeLibrary.getProbeForMessage$inClass
          (name, BFParams.this.getClass ());
      }
      private void addVar (String name) {
        addProbe (probeVariable (name));
      }
      private void addMessage (String name) {
        addProbe (probeMessage (name));
      }
      public BFParamsProbeMap (Zone _aZone, Class aClass) {
        super (_aZone, aClass);

     addVar ("numfcasts");
     addVar ("condwords");
     addVar ("condbits");
     addVar ("mincount");
     addVar ("gafrequency");
     addVar ("firstgatime");
     addVar ("longtime");
     addVar ("individual");
     addVar ("tauv");
     addVar ("lambda");
     addVar ("maxbid");
     addVar ("bitprob");
     addVar ("subrange");
     addVar ("a_min");
     addVar ("a_max");
     addVar ("b_min");
     addVar ("b_max");
     addVar ("c_min");
     addVar ("c_max");
     addVar ("a_range");
     addVar ("b_range");
     addVar ("c_range");
     addVar ("newfcastvar");
     addVar ("initvar");
     addVar ("bitcost");
     addVar ("maxdev");
     addVar ("poolfrac");
     addVar ("newfrac");
     addVar ("pcrossover");
     addVar ("plinear");
     addVar ("prandom");
     addVar ("pmutation");
     addVar ("plong");
     addVar ("pshort");
     addVar ("nhood");
     addVar ("genfrac");
     addVar ("gaprob");
     addVar ("npool");
     addVar ("nnew");
     addVar ("nnulls");
     addVar ("npoolmax");
     addVar ("nnewmax");
     addVar ("ncondmax");
      }
    }

    // Install our custom probeMap class directly into the
    // probeLibrary

    Globals.env.probeLibrary.setProbeMap$For
      (new BFParamsProbeMap (aZone, getClass ()), getClass ());

  }

  BFParams(Zone aZone, boolean a){
  super (aZone);
  }

}

