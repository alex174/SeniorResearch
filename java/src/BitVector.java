import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.Zone;

public class BitVector extends SwarmObjectImpl {

  int condwords; /*"Number of words of memory required to hold bits in this model"*/
  int condbits;  /*"The number of conditions bits we expect to actually use"*/
  int conditions[]; /*points to a dynamically allocated array of "condwords" elements"*/
  public static final int MAXCONDBITS = 80;
  public static int SHIFT[]=new int[MAXCONDBITS];
  public static int MASK[]= new int[MAXCONDBITS];
  public static int NMASK[]= new int[MAXCONDBITS];



  //needed for bit math. same as in BFAgent was.

  BitVector (Zone aZone){
  super(aZone);
  }

  public int WORD( int bit){
    int a;
    a = bit>>4;
    return a;
  }

  /*" This class is the "hairy guts" that makes bit forecasts possible.

  A bit vector is a group of "words", and each "word" contains 16
  indicators.  In this model, the bit vectors have 5 words, which means
  there are 80 indicators possible.

  In the substance of this model, a "bit" is an aspect of the world
  being monitored.  In genetic algorithm terms, one can say "NO", "YES"
  or "don't care", for each piece of information. A bit has values in
  integer format of 0, 1, or 2. But in binary, that is 00, 01, and 10,
  and in this class those binary representations are clumped together to
  be represented by a 32 bit integer, as in

  0110001000011000010101100100100101010101

  which holds the status of 16 bits.  There can be as many as 5 of these
  in a BitVector.  Those words are referred to by the pointer
  "conditions".  The first word can be found at conditions[0], the
  second at conditions[1], and so forth.  Note that these are integer
  values, but the bit math does work on the binary values.  I probably
  need a computer scientist to translate this for me...

  The world in the ASM can give a vector as well, telling us in binary
  many indicators, whether they are good or bad, 0 or 1.  So the bit
  forecasting agent takes the 0's and 1's from the world, and checks to
  see if they are used in the forecast, and makes a forecast.  All of
  the checking and setting of forecast bits is handled by this BitVector
  class.

  I suppose, if you are like me and don't like bit math, this is all
  confusing and you don't care, in which case you can readily ignore the
  details and just proceed to set the values of bits according to the
  interface below. Its pretty obvious.

  But if you want details, here is a very telling piece of documentation
  that goes with the function "makebittables", which used to be at the
  top of BFagent, but now its here, hidden in the dark and not so scary
  to users:

   *
   * Construct tables for fast bit packing and condition checking for
   * classifier systems.  Assumes 32 bit words, and storage of 16 ternary
   * values (0, 1, or *) per word, with one of the following codings:
   * Value       Message-board coding         Rule coding

   *   0			2			1
   *   1			1			2
   *   *			-			0

  * Thus rule satisfaction can be checked with a simple AND between
   * the two types of codings.
   *
   * Sets up the tables to store MAXCONDBITS ternary values in
   * CONDWORDS = ceiling(MAXCONDBITS/16) words.
   *
   * After calling this routine, given an array declared as
   *		int array[CONDWORDS];
   * you can do the following:
   *
   * a. Store "value" (0, 1, 2, using one of the codings above) for bit n with
   *	array[WORD(n)] |= value << SHIFT[n];
   *    if the stored value was previously 0; or
   *
   * b. Store "value" (0, 1, 2, using one of the codings above) for bit n with
   *	array[WORD(n)] = (array[WORD(n)] & NMASK[n]) | (value << SHIFT[n]);
   *    if the initial state is unknown.
   *
   * c. Store value 0 for bit n with
   *	array[WORD(n)] &= NMASK[n];
   *
   * d. Extract the value of bit n (0, 1, 2, or possibly 3) with
   *	value = (array[WORD(n)] >> SHIFT[n]) & 3;
   *
   * e. Test for value 0 for bit n with
   *	if ((array[WORD(n)] & MASK[n]) == 0) ...
   *
   * f. Check whether a condition is fulfilled (using the two codings) with
   *	for (i=0; i<CONDWORDS; i++)
   *	    if (condition[i] & array[i]) break;
   *	if (i != CONDWORDS) ...
   *
   "*/


  /*"Allocate dynamic memory to hold the bit vector.  There are "condwords"*sizeof(unsigned int) words of memory allocated."*/

  public Object createEnd()
  {
    int i;

    if (condwords==0 ){System.out.println("Must have condwords to create BFCast. 1");}

    conditions = new int[condwords];
    for(i=0;i<condwords;i++)
      conditions[i]=0;
    return this;
  }

  /*"init runs the makebittables function, which creates some statically allocated vectors that are used in bit math."*/
  public static void init()
  {
    makebittables();
    return ;//this;
  }

  /*"Sets the number of words-worth of memory will be used"*/
  public void setCondwords (int x)
  {
    condwords = x;
  }

  /*"Sets the number of bits that this bit vector is supposed to take care of"*/
  public void setCondbits (int x)
  {
    condbits=x;
  }


  /*"Suppose a pointer to a set of conditions, x, already exists.  This
  method takes that pointer and then copies its values into the
  conditions of the current bit vector"*/

  public void setConditions (int[] x)
  {
    int i;
    for(i=0;i<condwords;i++) conditions[i]=x[i];
  }


  /*"Returns a pointer to the current conditions of the bit vector"*/
  public int[] getConditions()
  {
    return conditions;
  }

  /*"Set the i'th word of condition to a value"*/
  public void setConditionsWord$To( int i , int value)
  {
    conditions[i]= value;
  }

  /*"Returns the i'th word of conditions"*/
  public int getConditionsWord (int i)
  {
    return conditions[i];
  }


  /*"Dig into the conditions, find the given bit, and set its value to x"*/
  public void setConditionsbit$To (int bit , int x)
  {
    conditions[WORD(bit)] = (conditions[WORD(bit)] & NMASK[bit]) | (x << SHIFT[bit]);
  }


  /*"Change a given bit from zero to 1 or 2"*/
  public void setConditionsbit$FromZeroTo (int bit , int x)
  {
    conditions[WORD(bit)] |= x <<SHIFT[bit];
  }

  /*"Returns an integer (0,1,2) indicating the status of a given bit"*/
  public int getConditionsbit (int bit)
  {
    int value;
    value = (conditions[WORD(bit)] >> SHIFT[bit]) &3;
    return  value;
  }

  /*"The value 3 is used to indicate that a bit is not in use"*/
  public void setConditionsbitToThree (int bit)
  {
    conditions[WORD(bit)] |= MASK[bit];
  }

  public void maskConditionsbit (int bit)
  {
    conditions[WORD(bit)] &= NMASK[bit];
    // specificity --;
  }

  /*"If the bit is 1, change it to 2, or vice versa"*/
  public void switchConditionsbit (int bit)
  {
      conditions[WORD(bit)] ^= MASK[bit];
  }

  /*"Release freed memory"*/
  public void drop()
  {
    super.drop();
  }

  /*"Dump the current conditions to the screen. Use for debugging"*//*
  public Object printcond (int word)
  {
    int i;
    int n = sizeof(int) * CHAR_BIT;
    int mask = 1 << (n-1);
    int  input=conditions[word];


    for ( i=1; i <= n; ++i)
      {
        putchar(((input & mask) == 0) ? '0' : '1');
        input <<= 1;
        if (i % CHAR_BIT == 0 && i < n)
          putchar(' ');
     }
    return self;
  }
*/


  public static void makebittables()
  /*
   * Construct tables for fast bit packing and condition checking for
   * classifier systems.  Assumes 32 bit words, and storage of 16 ternary
   * values (0, 1, or *) per word, with one of the following codings:
   * Value       Message-board coding         Rule coding
   *   0			2			1
   *   1			1			2
   *   *			-			0
   * Thus rule satisfaction can be checked with a simple AND between
   * the two types of codings.
   *
   * Sets up the tables to store MAXCONDBITS ternary values in
   * CONDWORDS = ceiling(MAXCONDBITS/16) words.
   *
   * After calling this routine, given an array declared as
   *		int array[CONDWORDS];
   * you can do the following:
   *
   * a. Store "value" (0, 1, 2, using one of the codings above) for bit n with
   *	array[WORD(n)] |= value << SHIFT[n];
   *    if the stored value was previously 0; or
   *
   * b. Store "value" (0, 1, 2, using one of the codings above) for bit n with
   *	array[WORD(n)] = (array[WORD(n)] & NMASK[n]) | (value << SHIFT[n]);
   *    if the initial state is unknown.
   *
   * c. Store value 0 for bit n with
   *	array[WORD(n)] &= NMASK[n];
   *
   * d. Extract the value of bit n (0, 1, 2, or possibly 3) with
   *	value = (array[WORD(n)] >> SHIFT[n]) & 3;
   *
   * e. Test for value 0 for bit n with
   *	if ((array[WORD(n)] & MASK[n]) == 0) ...
   *
   * f. Check whether a condition is fulfilled (using the two codings) with
   *	for (i=0; i<CONDWORDS; i++)
   *	    if (condition[i] & array[i]) break;
   *	if (i != CONDWORDS) ...
   * */
  {
    int bit;

    for (bit=0; bit < MAXCONDBITS; bit++)
      {
        SHIFT[bit] = (bit%16)*2;
        MASK[bit] = 3 << SHIFT[bit];
        NMASK[bit] = ~MASK[bit];
      }
  }
}
