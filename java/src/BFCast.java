import swarm.objectbase.SwarmObject;
import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.Zone;


public class BFCast extends SwarmObjectImpl
{
  double forecast;	/*" this forecast of return"*/
  double lforecast;	/*" previous forecast"*/
  double variance;	/*" variance of this forecast"*/
  double strength;      /*"strength=maxdev - variance +specfactor. This was the original sfsm specification, not the ASM-2.0 specification"*/
  double a;		/*" (price + dividend) coefficient"*/
  double b;		/*" dividend coefficient "*/
  double c;		/*" constant term"*/
  double specfactor;	/*" specificty=(condbits - nnulls - specificity)* bitcost. "*/
  double bitcost; /*" cost of using bits in forecasts"*/

  BitVector conditions; /*" a BitVector object that holds records on which conditions in the world are being monitored by this forecast object"*/
  int lastactive;  /*" last time period in which this forecast was active"*/
  int specificity; /*" specificity "*/
  int count; /*" number of times this forecast has been active"*/
  int condwords; /*"number of words of memory needed to hold the conditions"*/
  int condbits; /*"number of bits of information monitored by this forecast"*/
  int nnulls; /*"number of 'unused' bits that remain in the allocated vector after the 'condbits' bits have been used"*/


  /*"A BFCast is an object that holds all the forcecasting components of
    a bit forecast.  That means it has a BitVector (a thing called
    "conditions" in the code that keeps track of which world bits are
    being monitored) as well as other coefficients that are used to
    calculate forecasts. It has instance variables that record when the
    rule was last used, how many times it has been used, how accururate
    its predictions are, and so forth."*/


  BFCast(Zone aZone){
  super(aZone);
  }

  public Object createEnd()
  {
   if ((condwords==0) || (condbits==0) ){System.out.println("Must have condwords to create BFCast.0");}

    forecast= 0.0;
    count = 0;
    lastactive=1;
    specificity = 0;
    variance = 999999999;
    conditions= new BitVector(this.getZone());
    conditions.setCondwords(condwords);
    conditions.setCondbits(condbits);
    conditions.createEnd();
    return this;
  }

  /*"The init is needed because BitVector has to be told how bit of a
    bit vector it will need"*/
  public static void init()
  {
    BitVector.init();
   return;// this;
  }

  /*"Free dynamically allocated memory"*/
  public void drop()
  {
    conditions.drop();
    super.drop();
  }

  /*"Sets the number of words-worth's of conditions that are going to be used"*/
  public void setCondwords (int x)
  {
    condwords = x;
  }

  /*"Sets the number of bits. This is the number of aspect of the world that are monitored"*/
  public void setCondbits (int x)
  {
    condbits = x;
  }

  /*"Null bits may be needed if the bit vector that is allocated is larger than the number of conditions being monitored. Since a bitvector allocates space in sizes of words, this might be important. Luckily, in the current design of ASM-2.0 (and after), there are no null bits."*/
  public void setNNulls (int x)
  {
    nnulls = nnulls;
  }

  /*"Set the variable bitcost at x"*/
  public void setBitcost (double x)
  {
    bitcost = x;
  }

  /*"Rather than individually set bits one by one, we might want to set
    all of them at once. That means we pass in a pointer to an array of
    words that is the "right size" for all the bits."*/
  public void  setConditions (int[] x)
  {
    conditions.setConditions( x);
  }

  /*"Returns a pointer to an array, the integer representation of the
    conditions"*/
  public int[] getConditions()
  {
    return conditions.getConditions();
  }

  /*"Returns an object of type BitVector, the represnetation of
    conditions that is actually used inside this class or
    calculations"*/
  public BitVector getConditionsObject()
  {
    return conditions;
  }


  /*"For low level access to a full word's-worth of the condition"*/
  public void setConditionsWord$To (int i , int value)
  {
    conditions.setConditionsWord$To( i , value);
  }

  /*"Returns the integer representation of the x'th word in the
    conditions"*/
  public int getConditionsWord (int x)
  {
    return conditions.getConditionsWord( x);
  }

  /*"Sets the value of a bit in the conditions"*/
  public void setConditionsbit$To (int bit ,int x)
  {
    conditions.setConditionsbit$To( bit , x);
  }

  /*"If a bit is currently set to 0 ("don't care"), then change it to
    something else (1 or 2)"*/
  public void setConditionsbit$FromZeroTo (int bit , int x)
  {
    conditions.setConditionsbit$FromZeroTo( bit , x);
  }

  /*"Returns 0,1,or 2, for a given bit in the conditions records"*/
  public int getConditionsbit (int bit)
  {
    return conditions.getConditionsbit( bit);
  }


  public void maskConditionsbit (int bit)
  {
    conditions.maskConditionsbit( bit);
  }


  /*"Change a YES to a NO, and vice versa"*/
  public void switchConditionsbit (int bit)
  {
    // conditions[WORD(bit)] ^= MASK[bit];
    conditions.switchConditionsbit( bit);
  }

  /*"Set a coefficient from demand equation"*/
  public void setAval (double x)
  {
    a = x;
  }

  /*"Set b coefficient from demand equation"*/
  public void setBval (double x)
  {
    b = x;
  }

  /*"Set c coefficient from demand equation"*/
  public void setCval (double x)
  {
    c = x;
  }

  /*"Return a coefficient from demand equation"*/
  public double getAval()
  {
    return a;
  }

  /*"Return b coefficient from demand equation"*/
  public double getBval()
  {
    return b;
  }

  /*"Return c coefficient from demand equation"*/
  public double getCval()
  {
    return c;
  }

  /*"Update the spec factor of this forecast. That means calculate:
  specfactor= (condbits - nnulls - specificity)* bitcost
  "*/
  public void updateSpecfactor()
  {
    //was in BFagent: specfactor = 1.0/(1.0 + x*specificity);
    //but the bfagent.m way is so much nicer
    specfactor = (condbits - nnulls - specificity)* bitcost; //follows bfagent.m

  }

  /*"Set the specfactor value of this forecast"*/
  public void setSpecfactor (double x)
  {
    specfactor = x;
  };

  /*"Return the specfactor value of this forecast"*/
  public double getSpecfactor()
  {
    return specfactor;
  }

  /*"Raise the specificity value of this forecast by one unit"*/
  public void incrSpecificity()
  {
    ++ specificity;
  }

  /*"Reduce the specificity value of this forecast by one unit"*/
  public void decrSpecificity()
  {
    --specificity;
  }

  /*"Set the specificity of this forecast"*/
  public void setSpecificity (int x)
  {
    specificity = x;
  }

  /*"Return the specificity of this forecast"*/
  public int getSpecificity()
  {
    return specificity;
  }

  /*"Set the variance of this forecast"*/
  public void setVariance (double x)
  {
    variance=x;
  }

  /*"Return the variance of this forecast"*/
  public double getVariance()
  {
    return variance;
  }


  /*"Set the time on which this forecast was last active to an input value"*/
  public void setLastactive (int x)
  {
    lastactive = x;
  }

  /*"Return the time on which this forecast was last active"*/
  public int getLastactive()
  {
    return lastactive;

  }

  /*"Return the value of count"*/
  public int getCnt()
  {
    return count;
  }


  /*"Set the count variable to an inputted value"*/
  public void setCnt (int x)
  {
    count = x;

  }

  /*"Increment this forecast's count variable"*/
  public int incrCount()
  {
    return ++count;
  }

  /*"Return strength of this forecast"*/
  public double getStrength()
  {
    return strength;
  }


  /*"Set the strength value to an inputted value"*/
  public void setStrength (double x)
  {
    strength = x;
  }

  /*"Set the previous forecast of this object to an inputted value"*/
  public void setLforecast (double x)
  {
    lforecast = x;
  }

  /*"Get forecast from the previous time period"*/
  public double getLforecast()
  {
    return lforecast;
  }


  /*"Set the forecast of this object to an inputted value"*/
  public void  setForecast (double x)
  {
    forecast = x;
  }

  /*"Return forecast from this object"*/
  public double getForecast()
  {
    return forecast;
  }

  /*"Calculate new forecast on basis of price and dividend information"*/
  public double updateForecastPrice$Dividend (double price , double dividend)
  {
    lforecast = forecast;
    forecast = a* (price+dividend) + b*dividend + c;
    return forecast;
  }


  /*"Given an input forecast object, systematically ask it for
    all its IVARs and replace current settings with them."*/
  public Object copyEverythingFrom (BFCast from)
  {
   forecast = from.getForecast();
   lforecast = from.getLforecast();
   variance = from.getVariance();
   strength =  from.getStrength();
   a= from.getAval();
   b=  from.getBval();
   c=  from.getCval();
   specfactor = from.getSpecfactor();
   lastactive = from.getLastactive();
   specificity = from.getSpecificity();
   count = from.getCnt();
   this.setConditions(from.getConditions());
   return this;
  }

  /*"Return some disgnostic information about the status of
    variables inside this forecast to the terminal"*//*
  - print
  {
    int word;
    printf("BFCast print: forecast %f lforecast %f variance %f strength %f \n",forecast,lforecast,variance,strength);
    for ( word=0; word < condwords; word++)
      [self printcond: word];
    printf("a %f b %f c %f specfactor %f, specificity %d count %d lastactive %d \n", a,b,c,specfactor,specificity,count,lastactive);

    return self;
  }
*/

  public Object printcond (int word)
  {
    //conditions.printcond( word);
    return this;
  }




}










