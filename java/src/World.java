// The Santa Fe Stockmarket -- Interface for class World

//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
//import swarm.random.UniformDoubleDistImpl;
import swarm.Globals;
import swarm.SwarmEnvironment;
import swarm.defobj.Zone;

import java.util.LinkedList;

/**
 * <p>Title: World</p>
 * <p>El Mundo es una clase que principalmente sirve para satisfacer las necesidades
 * de información de BFagents. World toma los datos del precio y los convierte en tendencias
 * medias....
 * Una instancia de este Objeto es creada para manejar las variables de world, las
 * variables globalmente visibles que reflejan el propio mercado, incluyendo sus medias
 * móviles....Todo está basado en sólo dos variables básicas, price & dividend, las cuales
 * sólo se establecen mediante los métodos setPrice() y setDividend().
 * World también maneja la lista de bits, traduciendo entre el nombre de los bits y su
 * número, y dando descripciones de las funciones de los bits.
 * </p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class World extends SwarmObjectImpl {

  /*" Number of up/down movements to store for price and dividend,
   including the current values.  Used for pup, pup1,
   ... pup[UPDOWNLOOKBACK-1], and similarly for dup[n], and for
   -pricetrend:.  The argument to pricetrend() must be UPDOWNLOOKBACK
   or less. "*/
  /**Nº de movimientos up/down que se almacenan del precio y el dividendo, incluyendo los valores actuales*/
  public static final int UPDOWNLOOKBACK = 5;
  /*" Number of moving averages "*/
  /**Nº de medias móviles*/
  public static final int NMAS = 4;
  /*" The longest allowed Moving Average "*/
  /**Nº de periodos de los que se conserva el registro del dividendo y del precio. La media móvil más larga permitida*/
  public static final int MAXHISTORY = 500;

  /**El nº de aspectos de world que son registrados como bits*/
  public static int NWORLDBITS;
  public static final int NULLBIT = -1;
   // The index of the "pup" bit
   /**El número del bit que indica si el precio ha subido o ha bajado*/
  public static final int PUPDOWNBITNUM = 42;

  // Breakpoints for price*interest/dividend and dividend/mean-dividend ratios.
  /**Puntos críticos para los ratios precio-de-mercado/precio-fundamental y
   * dividendo/dividendo-medio
   */
  public static final double ratios[] =
          {0.25, 0.5, 0.75, 0.875, 1.0, 1.125, 1.25, 1.5, 2.0, 4.0};

  /**Número de puntos críticos para los ratios
   * precio-de-mercado/precio-fundamental y dividendo/dividendo-medio
   */
  public static final int NRATIOS = ratios.length;

  public static final int EQ = 0;
  /**Tasa de interés*/
  public double intrate; /*" interest rate"*/
  /**La línea media del dividendo*/
  public double dividendscale; /*" The baseline dividend that is set by initWithBaseline: "*/

  /**Array de dimensión UPDOWNLOOKBACK que indica si el precio ha subido o
   * bajado en los últimos UPDOWNLOOKBACK periodos
   */
  public int pupdown[] = new int[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/

  /**Array de dimensión UPDOWNLOOKBACK que indica si el dividendo ha subido o
   * bajado en los últimos UPDOWNLOOKBACK periodos
   */
  public int dupdown[] = new int[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/

  /**Valor del índice de los arrays de históricos que se está modificando
   */
  public int history_top;                     /*" index value of current input into history arrays "*/

  /**Número de periodos a los que se mira atrás para rellenar los bits de
   * cambio del precio y del dividendo (¿ha subido o ha bajado?)
   */
  public int updown_top;     /*"number of time steps to look back to form pupdown and dupdown bits"*/
  /**precio que vacia el mercado*/
  public double price;     /*"market clearning price"*/
  /**precio anterior*/
  public double oldprice;  /*" previous price "*/
  /**dividend*/
  public double dividend;   /*" dividend "*/
  /**dividendo anterior*/
  public double olddividend; /*"previous dividend"*/
  /**copia del dividendo antiguo, que se usa para comprobar que no se ha
   * corrompido el valor en algun punto del programa*/
  public double saveddividend; /* copy of olddividend, used for some
                           double-checking on object integrity"*/
  /**copia del precio antiguo, que se usa para comprobar que no se
   * ha corrompido el valor en algun punto del programa*/
  public double savedprice; /* copy of oldprice, used for some
                        double-checking on object integrity"*/
  /**Precio fundamental = dividend/intrate*/
  public double riskNeutral;   /*"dividend/intrate"*/

  public double rationalExpectations;
  public double rea;
  public double reb;
  /**Beneficio por acción y periodo = price - oldprice + dividend*/
  public double profitperunit; /*"price - oldprice + dividend"*/
  /**Medida de rentabilidad = profitperunit/oldprice*/
  public double returnratio;   /*"profitperunit/oldprice"*/

  /**Este array contiene la longitud de las medias móviles que vamos a calcular.
   * (p. ej. 0, 20, 100 y 500). Su dimensión es el número de medias móviles
   * diferentes de las que disponemos.
   */
  public int malength[]= new int[NMAS];     /*" For each MA, we must specify the length over which the average is calculated. This array has one integer for each of the moving averages we plan to keep, and it is used to set the widths covered by the moving averages."*/
  /**El nº de aspectos de world que son registrados como bits*/
  public int nworldbits; /*"The number of aspects of the world that are recorded as bits"*/

  /**Array que contiene la ristra de bits que determinan el estado del
   * mercado. Este es el resultado fundamental de World.
   */
  int realworld[]; /*"An array (dynamically allocated, sorry) of ints, one for each bit being monitored. This is kept up-to-date. There's a lot of pointer math going on with this and I don't feel so glad about it (PJ: 2001-11-01)"*/

  /**True si queremos medias móviles exponenciales.
   */
  public boolean exponentialMAs; /*"Indicator variable, YES if the World is supposed to report back exponentially weighted moving averages"*/

  /**Array de instancias de MovingAverage que contiene el valor de las medias
   *  móviles calculadas sobre el precio.*/
  public MovingAverage priceMA[] = new MovingAverage[NMAS];  /*" MovingAverage objects which hold price information. There are NMAS of these, and have various widths for the moving averages "*/

  /**Array de instancias de MovingAverage que contiene el valor de las medias
   *  móviles calculadas sobre el dividendo.*/
  public MovingAverage divMA[] = new MovingAverage[NMAS];   /*"  MovingAverage objects which hold dividend moving averages. "*/

  /**Array de instancias de MovingAverage que contiene el valor de las medias
   *  móviles calculadas sobre el precio del periodo anterior.*/
  public MovingAverage oldpriceMA[] = new MovingAverage[NMAS]; /*" MovingAverage objects which hold lagged price moving averages "*/

  /**Array de instancias de MovingAverage que contiene el valor de las medias
   *  móviles calculadas sobre el dividendo del periodo anterior.*/
  public MovingAverage olddivMA[] = new MovingAverage[NMAS]; /*" MovingAverage objects which hold lagged dividend moving averages "*/

  /**Lista enlazada de java cuyos elementos son instancias de la clase BitName.
   * Cada uno de estos objetos, que definen a un bit de estado, se compone de un
   * nombre y de una breve descripción.
   */
  public static LinkedList bitnameList = new LinkedList();

  //public final double drand = Globals.env.uniformDblRand.getDoubleSample();
  //public final double urand = Globals.env.uniformDblRand.getDoubleWithMin$withMax(-1,1);

  /**Array que contiene la historia del dividendo (MAXHISTORY valores)*/
  private double divhistory[];       /*" dividend history array, goes back MAXHISTORY points"*/
  /**Array de la historia de precios (MAXHISTORY valores)*/
  private double pricehistory[];     /*" price history array "*/


    /*" bitname class holds the substantive information about various world indicators
   It is a list of bit names and descriptions
  // NB: If you change the order or meaning of bits, also check or change:
  // 1. Their computation in -makebitvector in this file.
  // 2. The PUPDOWBITNUM value.
  // 3. The NAMES documentation file -- do "market -n > NAMES".
   "*/

   /**Constructor de la clase
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  World (Zone aZone){
  super(aZone);
  }

 /**Crea e inicializa la bitnameList: lista enlazada de java cuyos elementos
  * son instancias de la clase BitName.
   * Cada uno de estos objetos, que definen a un bit de estado, se compone de un
   * nombre y de una breve descripción.
   */
  public void createBitnameList(){
    //BitName bit = new BitName("on", "dummy bit -- always on");
    //bitnameList.add(bit);   // 0

    bitnameList.add(new BitName("on", "dummy bit -- always on"));   // 0
    bitnameList.add(new BitName("off", "dummy bit -- always off"));
    bitnameList.add(new BitName("random", "random on or off"));

    bitnameList.add(new BitName("dup", "dividend went up this period"));  // 3
    bitnameList.add(new BitName("dup1", "dividend went up one period ago"));
    bitnameList.add(new BitName("dup2", "dividend went up two periods ago"));
    bitnameList.add(new BitName("dup3", "dividend went up three periods ago"));
    bitnameList.add(new BitName("dup4", "dividend went up four periods ago"));

    bitnameList.add(new BitName("d5up", "5-period MA of dividend went up"));  // 8
    bitnameList.add(new BitName("d20up", "20-period MA of dividend went up"));
    bitnameList.add(new BitName("d100up", "100-period MA of dividend went up"));
    bitnameList.add(new BitName("d500up", "500-period MA of dividend went up"));

    bitnameList.add(new BitName("d>d5",   "dividend > 5-period MA"));  // 12
    bitnameList.add(new BitName("d>d20",  "dividend > 20-period MA"));
    bitnameList.add(new BitName("d>d100", "dividend > 100-period MA"));
    bitnameList.add(new BitName("d>d500", "dividend > 500-period MA"));

    bitnameList.add(new BitName("d5>d20", "dividend: 5-period MA > 20-period MA"));  // 16
    bitnameList.add(new BitName("d5>d100", "dividend: 5-period MA > 100-period MA"));
    bitnameList.add(new BitName("d5>d500", "dividend: 5-period MA > 500-period MA"));
    bitnameList.add(new BitName("d20>d100", "dividend: 20-period MA > 100-period MA"));
    bitnameList.add(new BitName("d20>d500", "dividend: 20-period MA > 500-period MA"));
    bitnameList.add(new BitName("d100>d500", "dividend: 100-period MA > 500-period MA"));

    bitnameList.add(new BitName("d/md>1/4", "dividend/mean dividend > 1/4"));  // 22
    bitnameList.add(new BitName("d/md>1/2", "dividend/mean dividend > 1/2"));
    bitnameList.add(new BitName("d/md>3/4", "dividend/mean dividend > 3/4"));
    bitnameList.add(new BitName("d/md>7/8", "dividend/mean dividend > 7/8"));
    bitnameList.add(new BitName("d/md>1",   "dividend/mean dividend > 1  "));
    bitnameList.add(new BitName("d/md>9/8", "dividend/mean dividend > 9/8"));
    bitnameList.add(new BitName("d/md>5/4", "dividend/mean dividend > 5/4"));
    bitnameList.add(new BitName("d/md>3/2", "dividend/mean dividend > 3/2"));
    bitnameList.add(new BitName("d/md>2", "dividend/mean dividend > 2"));
    bitnameList.add(new BitName("d/md>4", "dividend/mean dividend > 4"));

    bitnameList.add(new BitName("pr/d>1/4", "price*interest/dividend > 1/4"));  // 32
    bitnameList.add(new BitName("pr/d>1/2", "price*interest/dividend > 1/2"));
    bitnameList.add(new BitName("pr/d>3/4", "price*interest/dividend > 3/4"));
    bitnameList.add(new BitName("pr/d>7/8", "price*interest/dividend > 7/8"));
    bitnameList.add(new BitName("pr/d>1",   "price*interest/dividend > 1"));
    bitnameList.add(new BitName("pr/d>9/8", "price*interest/dividend > 9/8"));
    bitnameList.add(new BitName("pr/d>5/4", "price*interest/dividend > 5/4"));
    bitnameList.add(new BitName("pr/d>3/2", "price*interest/dividend > 3/2"));
    bitnameList.add(new BitName("pr/d>2",   "price*interest/dividend > 2"));
    bitnameList.add(new BitName("pr/d>4",   "price*interest/dividend > 4"));

    bitnameList.add(new BitName("pup", "price went up this period"));  // 42
    bitnameList.add(new BitName("pup1", "price went up one period ago"));
    bitnameList.add(new BitName("pup2", "price went up two periods ago"));
    bitnameList.add(new BitName("pup3", "price went up three periods ago"));
    bitnameList.add(new BitName("pup4", "price went up four periods ago"));

    bitnameList.add(new BitName("p5up", "5-period MA of price went up")); // 47
    bitnameList.add(new BitName("p20up", "20-period MA of price went up"));
    bitnameList.add(new BitName("p100up", "100-period MA of price went up"));
    bitnameList.add(new BitName("p500up", "500-period MA of price went up"));

    bitnameList.add(new BitName("p>p5", "price > 5-period MA")); // 51
    bitnameList.add(new BitName("p>p20", "price > 20-period MA"));
    bitnameList.add(new BitName("p>p100", "price > 100-period MA"));
    bitnameList.add(new BitName("p>p500", "price > 500-period MA"));

    bitnameList.add(new BitName("p5>p20", "price: 5-period MA > 20-period MA")); // 55
    bitnameList.add(new BitName("p5>p100", "price: 5-period MA > 100-period MA"));
    bitnameList.add(new BitName("p5>p500", "price: 5-period MA > 500-period MA"));
    bitnameList.add(new BitName("p20>p100", "price: 20-period MA > 100-period MA"));
    bitnameList.add(new BitName("p20>p500", "price: 20-period MA > 500-period MA"));
    bitnameList.add(new BitName("p100>p500", "price: 100-period MA > 500-period MA"));

    NWORLDBITS = bitnameList.size();
  }

  /**Método implementado para obtener nºs enteros aleatorios en el
   * intervalo [0,x-1].
  *
  * @param x
  * @return double El número aleatorio.
  */
  public  int irand(int x){
    return Globals.env.uniformIntRand.getIntegerWithMin$withMax(0,x-1);
  }

  /*" GETMA(x,j) is a method that checks to see if we want an exponential MA or regular when we retrieve values from MA objects "*/
/**Devuelve la media móvil apropiada, comprobando si hemos elegido usar
 * medias móviles exponenciales o no.
 */
  public double GETMA(MovingAverage[] x,int j){
   return (exponentialMAs ? x[j].getEWMA():x[j].getMA());
  }
/**
 * <p>Función para pasar de un valor boolean a un entero:</p>
 * <p>true -> 1.</p>
 * <p>false -> 0.</p>
 * @param a El valor boolean (true o false).
 * @return int El valor entero (1 ó 0).
 */
  public int ChangeBooleanToInt(boolean a){
    if (a==true)
      return 1;
    else return 0;
  }
  /*" The World is a class that is mainly used to serve the information needs of BFagents.  The WOrld takes price data and converts it into a number of trends, averages, and so forth.

  One instance of this object is created to manage the "world" variables
  -- the globally-visible variables that reflect the market itself,
  including the moving averages and the world bits.  Everything is based
  on just two basic variables, price and dividend, which are set only by
  the -setPrice: and -setDividend: messages.

  The World also manages the list of bits, translating between bit names
  and bit numbers, and providing descriptions of the bits' functions.
  These are done by class methods because they are needed before the
  instnce is instantiated."*/

  /*"	Supplies a description of the specified bit, taken from the
   *	bitnamelist[] table below.  Also works for NULLBIT.
  "*/
  /**
   * Proporciona una descripción del bit especificado, tomado de la lista
   * bitnamelist[].También funciona para NULLBIT.
   * @param n Número del bit del que queremos la descripción
   * @return description Descripción del bit especificado
   */
  public static String descriptionOfBit(int n)
  {
    if (n == NULLBIT)
      return "(Unused bit for spacing)";
    else if (n < 0 || n >= NWORLDBITS)
      return "(Invalid world bit)";
    return ((BitName)(bitnameList.get(n))).description;
  }

  /*" Supplies the name of the specified bit, taken from the
  //	bitnamelist[] table below.  Also works for NULLBIT. Basically,
  //	it converts a bit number to a bit name.
  "*/

  /**
   * Proporciona el nombre del bit especificado, tomado de la tabla bitnamelist[]
   * de abajo.También funciona para NULLBIT. Básicamente, convierte un número de bit
   * en el nombre del bit
   * @param n Número del bit del que queremos el nombre.
   * @return name Nombre del bit especificado.
   */
  public static String nameOfBit (int n)
  {
    if (n == NULLBIT)
      return "null";
    else if (n < 0 || n >= NWORLDBITS)
      return "";
    return ((BitName)bitnameList.get(n)).name;
  }


  /**
   * Convierte un nombre de un bit, en un número de bit. Proporciona el nº del bit
   * dado su nombre. Nombres desconocidos devuelven NULLBIT. Es un método relativamente
   * lento (búsqueda lineal).
   * @param name Nombre del bit del que queremos el nombre.
   * @return int Número del bit especificado.
   */
  public static int bitNumberOf (String name)
  /*" Converts a bit name to a bit number. Supplies the number of a bit
   * given its name.  Unknown names return NULLBIT.  Relatively slow
   * (linear search). Could be made faster with a hash table etc, but
   * that's not worth it for the intended usage.  "*/
  {
    int n;

    for (n = 0; n < NWORLDBITS; n++)
      if (name.compareTo(((BitName)bitnameList.get(n)).name) == EQ)
        break;
    if (n >= NWORLDBITS) n = NULLBIT;

    return n;
  }

  /**
   * Fija la tasa de interés
   * @param rate Tasa de interés.
   * @return this
   */
  public Object setintrate (double rate)
    /*" Interest rate set in ASMModelSwarm."*/
  {
    intrate = rate;
    return this;
  }

  /**Fija el valor de exponentialMAs, que vale true si queremos usar medias
   * móviles y false en caso contrario. El valor de exponentialMAs se puede
   * modificar desde la sonda de la instancia asmModelParams.
   */
  public Object setExponentialMAs (boolean aBool)
    /*" Turns on the use of exponential MAs in calculations.  Can be
      turned on in GUI or ASMModelSwarm.m. If not, simple averages of
      the last N periods."*/
  {
    exponentialMAs = aBool;
    return this;
  }
  /**
   * Devuelve nworldbits; Usado por el BFagent.
   * @return nworldbits El nº de aspectos de world que son registrados como bits.
   */
  public int getNumWorldBits()
    /*" Returns numworldbits; used by the BFagent."*/
  {
    return nworldbits;
  }
/**<p>Inicializa las medias móviles, partiendo de la base de que el dividendo ha
 * valido siempre su "valor medio", o baseline. La "baseline" puede modificarse
 * desde la sonda del asmModelSwarm. Esta inicialización no es relevante
 * porque antes de la simulación se ejecuta el programa de calentamiento, mucho
 * más realista que esta suposición.</p>
 * <p>Este método sólo se ejecuta una vez.</p>
 *
 * @param baseline
 * @return this
 */
  public Object initWithBaseline (double baseline)
  /*"
  Initializes moving averages, using initial values based on
  a price scale of "baseline" for the dividend.  The baseline is
  set in ASMModelSwarm. " */
  {
    int i;
    double initprice, initdividend;

  // Check pup index
    if (World.nameOfBit(PUPDOWNBITNUM).compareTo("pup") != EQ)
      System.out.println("PUPDOWNBITNUM is incorrect");

  // Set price and dividend etc from baseline
    dividendscale = baseline;
    initprice = baseline/intrate;
    initdividend = baseline;
    saveddividend = dividend = initdividend;
    this.setDividend(initdividend);
    savedprice = price = initprice;
    this.setPrice(initprice);

  // Initialize profit measures
    returnratio = intrate;
    profitperunit = 0.0;

  // Initialize miscellaneous variables
    nworldbits = NWORLDBITS;

    malength[0] = 5;
    malength[1] = 20;
    malength[2] = 100;
    malength[3] = MAXHISTORY;

    history_top = 0;
    updown_top = 0;

    divhistory = new double[MAXHISTORY];
    pricehistory = new double[MAXHISTORY];

    realworld = new int[NWORLDBITS];

  // Initialize arrays
    for (i = 0; i < UPDOWNLOOKBACK; i++)
      {
      pupdown[i] = 0;
      dupdown[i] = 0;
      }

    for (i = 0; i < MAXHISTORY; i++)
      {
      pricehistory[i] = initprice;
      divhistory[i] = initdividend;
      }

    for (i = 0; i < NMAS; i++)
      {
        MovingAverage a= new MovingAverage(this.getZone());
        priceMA[i] = a;
        priceMA[i].initWidth$Value (malength[i], initprice);

        MovingAverage b = new MovingAverage(this.getZone());
        divMA[i] = b;
        divMA[i].initWidth$Value (malength[i], initdividend);

        MovingAverage c = new MovingAverage(this.getZone());
        oldpriceMA[i] = c;
        oldpriceMA[i].initWidth$Value (malength[i], initprice);

        MovingAverage d = new MovingAverage(this.getZone());
        olddivMA[i] = d;
        olddivMA[i].initWidth$Value (malength[i], initdividend);
      }

  // Initialize bits
    this.makebitvector();

    return this;
  }

  /*" Sets the market price to "p".  All price changes (besides trial
  prices) should use this method.  Also computes profitperunit and
  returnratio.  Checks internally for illegal changes of "price", giving us the
  effective benefit of encapsulation with the simplicity of use of
  a global variable. "*/
  /**
   * Pone el precio de mercado a "p". Todos los cambios de precios (además de los
   * trial prices) deben usar este método. También calcula profitperunit and
   * returnratio. Comprueba que no se hayan producido cambios ilegales en
   * el precio.
   * @param p precio
   * @return this
   */
  public Object setPrice (double p)
  {
    if (price != savedprice)
      System.out.println("Price was changed illegally");

    oldprice = price;
    price = p;

    profitperunit = price - oldprice + dividend;
    if (oldprice <= 0.0)
      returnratio = profitperunit*1000.0;	/* Arbitrarily large */
    else
      returnratio = profitperunit/oldprice;

    savedprice = price;

    return this;
  }

  /*"Returns the price, used by many classes."*/
  /**
   * Devuelve el precio; Usado por muchas clases.
   * @return price
   */
  public double getPrice ()
  {
    return price;
  }

  /*"Returns profitperunit, used by Specialist."*/
  /**Devuelve profitperunit, usado por Specialist
   * @return profitperunit
   */
  public double getProfitPerUnit()
  {
    return profitperunit;
  }

  /*"Sets the global value of "dividend".  All dividend changes should
          use this method.  It checks for illegal changes, as does
          -setPrice:."*/
  /**
   * Establece el valor del dividendo. Todos los cambios de dividendos
   * deben usar este método. Comprueba que no se hayan producido
   * cambios ilegales en el dividendo.
   * @param d Dividendo
   * @return this
   */
  public Object setDividend (double d)
  {
    if (dividend != saveddividend)
      System.out.println("Dividend was changed illegally.");

    olddividend = dividend;
    dividend = d;

    saveddividend = dividend;
    riskNeutral = dividend/intrate;
    rationalExpectations = rea*dividend +reb;
    return this;
  }

  /*"Returns the most recent dividend, used by many."*/
  /**
   * Devuelve el dividendo más reciente; Se llama varias veces
   * @return dividend
   */
  public double getDividend ()
  {
    return dividend;
  }

  /*"Returns the risk neutral price.  It is just dividend/intrate."*/
  /**
   * Devuelve el precio neutral al riesgo. Es simplemente dividend/intrate.
   * @return riskNeutral Precio neutral al riesgo
   */
  public double getRiskNeutral()
  {
    return riskNeutral;
  }

  public double getRationalExpectations()
  {
    return rationalExpectations;
  }

  /*" Updates the history records, moving averages, and world bits to
   * reflect the current price and dividend.  Note that this is called
   * in each period after a new dividend has been declared but before
   * the bidding and price adjustment.  The bits seen by the agents thus
   * do NOT reflect the trial price.  The "price" here becomes the
   * "oldprice" by the end of the period. It is called once per period.
   * (This could be done automatically as part of -setDividend:).
   *
   * The dividend used here is at present the latest value, though it
   * could be argued that it should be the one before, to match price.
   * For the p*r/d bits we do use the old one.
   "*/
  /**
   * Actualiza la historia, las medias móviles, y los bits del mundo para reflejar
   * el precio y el dividendo actual. Conviene darse cuenta de que es llamado cada periodo
   * después de que un nuevo dividendo es declarado pero antes del ajuste final de oferta y demanda.
   * Por lo tanto, los bits vistos por los agentes no reflejan el "trial price". "Price" aquí
   * se convierte en "oldprice" al final del periodo. Se llama una vez por periodo.
   *
   * @return this
   */
  public Object updateWorld ()
  {
    int i;

  /* Update the binary up/down indicators for price and dividend */
    updown_top = (updown_top + 1) % UPDOWNLOOKBACK;
    pupdown[updown_top] = ChangeBooleanToInt(price > oldprice);
    dupdown[updown_top] = ChangeBooleanToInt(dividend > olddividend);

  /* Update the price and dividend moving averages */
    history_top = history_top + 1 + MAXHISTORY;

    //update moving averages of price and dividend

    for (i = 0; i < NMAS; i++)
      {
        int rago = (history_top-malength[i])%MAXHISTORY;

        priceMA[i].addValue(price);
        divMA[i].addValue(dividend);

        oldpriceMA[i].addValue(pricehistory[rago]);
        olddivMA[i].addValue(divhistory[rago]);
      }


  /* Update the price and dividend histories */
    history_top %= MAXHISTORY;
    pricehistory[history_top] = price;
    divhistory[history_top] = dividend;

  /* Construct the bit vector for the current state of the world */
    this.makebitvector();

    return this;
  }
/**
 * Calcula todos los world bits a partir del dividendo actual, del precio,
 *  de las medias móviles y de los históricos. Este metodo calcula todos los
 *  elementos del array realworld,
 * bit a bit, estableciendo los valores a 0, 1 o 2, de acuerdo con los datos
 *  que han sido observados.
 * Es crucial que el orden aquí sea el mismo que en bitnamelist[]
 * @return this
 */
  private Object makebitvector()
  /*"  Set all the world bits, based on the current dividend, price,
  and  their moving averages and histories.  This moves through the
  realworld array, bit by bit, setting the values to 0, 1 or 2,
  according to the data that has been observed.  Note the pointer math, such as realworld[i++], that steps the integer i through the array.   Note that "i" increases monotonically throughout this routine, always
  being the next bit to assign.  It is crucial that the order here is the
  same as in bitnamelist[]. "*/
  {
    int i, j, k, temp;
    double multiple;

    i = 0;

    realworld[i++] = 1;
    realworld[i++] = 0;
    realworld[i++] = irand(2);

    /* Dividend went up or down, now and for last few periods */
    temp = updown_top + UPDOWNLOOKBACK;
    for (j = 0; j < UPDOWNLOOKBACK; j++, temp--)
      realworld[i++] = dupdown[temp%UPDOWNLOOKBACK];

    /* Dividend moving averages went up or down */
    for (j = 0; j < NMAS; j++)
      realworld[i++] = ChangeBooleanToInt(GETMA(divMA,j) > GETMA(olddivMA,j));

    /* Dividend > MA[j] */
    for (j = 0; j < NMAS; j++)
      realworld[i++] = ChangeBooleanToInt(dividend >  GETMA(divMA,j));

    /* Dividend MA[j] > dividend MA[k] */
    for (j = 0; j < NMAS-1; j++)
      for (k = j+1; k < NMAS; k++)
        realworld[i++] = ChangeBooleanToInt(GETMA(divMA,j) > GETMA(divMA,k));
        //  realworld[i++] = exponentialMAs ? [divMA[j] getEWMA]:[divMA[j] getMA]  > exponentialMAs ? [divMA[k] getEWMA]:[divMA[k] getMA];
        //realworld[i++] = dmav[j] > dmav[k];

    /* Dividend as multiple of meandividend */
    multiple = dividend/dividendscale;
    for (j = 0; j < NRATIOS; j++)
      realworld[i++] = ChangeBooleanToInt(multiple > ratios[j]);

    /* Price as multiple of dividend/intrate.  Here we use olddividend to
     * make a more reasonable comparison with the [old] price. */
    multiple = price*intrate/olddividend;
    for (j = 0; j < NRATIOS; j++)
      realworld[i++] = ChangeBooleanToInt(multiple > ratios[j]);

    /* Price went up or down, now and for last few periods */
    temp = updown_top + UPDOWNLOOKBACK;
    for (j = 0; j < UPDOWNLOOKBACK; j++, temp--)
      realworld[i++] = pupdown[temp%UPDOWNLOOKBACK];

    /* Price moving averages went up or down */
    for (j = 0; j < NMAS; j++)
      realworld[i++] = ChangeBooleanToInt(GETMA(priceMA,j) > GETMA(oldpriceMA,j));
      //realworld[i++] =pmav[j] > oldpmav[j];

    /* Price > MA[j] */
    for (j = 0; j < NMAS; j++)
       realworld[i++] = ChangeBooleanToInt(price > GETMA(priceMA,j));
      //  realworld[i++] = price > exponentialMAs ? [priceMA[j] getEWMA]:[priceMA[j] getMA];
    // realworld[i++] = price > pmav[j];

    /* Price MA[j] > price MA[k] */
    for (j = 0; j < NMAS-1; j++)
      for (k = j+1; k < NMAS; k++)
        realworld[i++] = ChangeBooleanToInt(GETMA(priceMA,j) > GETMA(priceMA,k));

    // Check
    if (i != NWORLDBITS)
      System.out.println("Bits calculated != bits defined.");

  /* Now convert these bits using the code:
   *  yes -> 1    (01)
   *  no  -> 2    (10)
   * Then we're able to check rule satisfaction with simple ANDs.
   */
    for (i = 0; i < NWORLDBITS; i++)
      realworld[i] = 2 - realworld[i];

    return this;
  }

  /*" Returns the real world array of bits.  Used by BFagent to compare
    their worlds to the real world."*/
  /**
   * Devuelve el array de bits realworld. Usado por BFagent para comparar
   * su mundo con realworld
   * @param anArray Array en el que se copia realworld
   * @return this
   */
  public Object getRealWorld (int[] anArray)
  {
    java.lang.System.arraycopy(realworld, 0, anArray, 0, NWORLDBITS);
    return this;
  }

/**
 * Devuelve +1, -1, ó 0 dependiendo de si el precio ha subido monotónicamente, caído
 * monotónicamente, o nada, a lo largo de n periodos. Si n es muy garnde puede causar
 * algún error
 * @param n número de periodos atrás en que se encuentra el precio referencia
 * @return int
 */
  public int pricetrend (int n)
  /*"
   * Returns +1, -1, or 0 according to whether the price has risen
   * monotonically, fallen monotonically, or neither, at the last
   * n updates. Causes
   *	an error if nperiods is too large (see UPDOWNLOOKBACK)."
   "*/
  {
    int trend, i;

    if (n > UPDOWNLOOKBACK)
      System.out.println("argument " + n + " to pricetrend() exceeds " + UPDOWNLOOKBACK);
    for (i=0, trend=0; i<n; i++)
      trend |= realworld[i+PUPDOWNBITNUM];

    if (trend == 1)
      return 1;
    else if (trend == 2)
      return -1;
    else
      return 0;
  }
/**
 * Liberador de memoria
 */

  public void drop()
  {
    super.drop();
  }

  public Object setRea$Reb(double rea1, double reb1)
  {
    rea=rea1;
    reb=reb1;
    return this;
  }
}
