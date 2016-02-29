// Artificial Stock Market Swarm Version Output File Interface

import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.HDF5ArchiverImpl;
import swarm.analysis.EZGraphImpl;
import swarm.defobj.HDF5Impl;
import swarm.defobj.LispArchiverImpl;
import swarm.Globals;
import swarm.defobj.Zone;
import swarm.defobj.HDF5Impl;
import swarm.Selector;

import java.util.Date;
import java.io.*;

/**
 * <p>Title: Output</p>
 * <p>Description: Existe una única instancia de esta clase.
 * Esa instancia es la encargada de escribir los parámetros y
 * los resultados de la simulación a fichero. Lo cierto es que esta clase se
 * encuentra en un estado bastante precario, sobre todo si la comparamos con
 * la versión anterior
 * del mercado, escrita en ObjectiveC. Esta nueva versión no ofrece más
 * que un único formato de fichero, aunque funciona correctamente y sin problemas. </p>
 * <p>Si queremos obtener un fichero con todos los parámetros de la simulación,
 * bastará con que pulsemos el botón "writeSimulationParams" de la interfaz gráfica de
 * la sonda del ASMObserverSwarm en cualquier momento de la simulación.</p>
 * <p>Si queremos un fichero en el que figuren el precio, el dividendo y el
 * volumen de negociación de cada periodo de la simulación, deberemos pulsar
 * el botón "toggleDataWrite" de la interfaz gráfica de
 * la sonda del ASMObserverSwarm. Podemos pulsar este botón durante la
 * ejecución de la simulación, obteniendo entonces los resultados a partir
 * de ese momento. La
 *  periodicidad de escritura a fichero viene dada por "displayFrequency", que
 *  también puede modificarse en el misma sonda pero siempre ANTES de que comience la
 *  simulación.
 * </p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class Output extends SwarmObjectImpl
{

/**
 * Indica si se ha abierto el fichero de resultados o no.
 */
  private boolean dataFileExists; /*"Indicator that dataFile initialization has alreadyoccurred"*/

  /**
   * Referencia el objeto world, desde el que se recogen datos.
   */
  World outputWorld;  /*"Reference to the world, where we can get data!"*/

  /**
   * Referencia el objeto world, desde el que se recogen datos.
   */
  Specialist outputSpecialist; /*" Reference to the Specialist object, where we can get data!"*/
  /**
   * La hora actual en milisegundos. En realidad mide en
   * milisegundos la diferencia entre el momento actual y la medianoche del
   * 1 de Enero de 1970 UTC.
   */
  long runTime = java.lang.System.currentTimeMillis(); /*"Return from the systems time() function"*/

  /**
   * La fecha y hora de hoy.
   */
  Date today = new Date(runTime);/*"a verbose description of current time"*/

  /**
   * La fecha y hora de hoy.
   */
  String timeString = new String(today.toString());

/**Entero que representa el tiempo actual en la simulación*/
  public int currentTime; /*"current time of simulation"*/


 /**
  * Nombre del fichero de resultados (precio, dividendo y volumen).
  */
    String outputFile;
   /**
  * Nombre del fichero de los parámetros.
  */
    String paramFileName;

/**
 * Se utiliza para escribir en el fichero de los parámetros.
 */
    FileWriter fw;
  /**
 * Se utiliza para escribir en el fichero de los parámetros.
 */
    BufferedWriter bw;
    /**
 * Fichero de los parámetros.
 */
    PrintWriter salida;

    /**
 * Se utiliza para escribir en el fichero de resultados (precio, dividendo y volumen).
 */
    FileWriter fw2;
       /**
 * Se utiliza para escribir en el fichero de resultados (precio, dividendo y volumen).
 */
    BufferedWriter bw2;
       /**
 * Fichero de resultados (precio, dividendo y volumen).
 */
    PrintWriter salida2;

  /**Constructor de la clase
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  Output(Zone aZone){
    super(aZone);
  }

  /*"createEnd does a lot of specific things that make the data output
    objects work. It gets the system time, uses that to fashion a
    filename that includes the time, then where necessary it creates
    archivers which will later be called on to get readings on the
    system and record them."*/

/**
 * Crea un String con la fecha y hora de hoy y sin caracteres que puedan ser
 * problemáticos. Además crea el nombre del fichero de los parámetros
 * (paramFileName).
 *
 * @return this
 */
  public Object createEnd()
  {
    int i;

    dataFileExists = false;

    timeString = timeString.replace(':', '_');
    timeString = timeString.replace(' ', '_');

    if (Globals.env.guiFlag == true){
      paramFileName = new String("guiSettings");
      }
    else{
      paramFileName = new String("batchSettings");
      }

    paramFileName = paramFileName.concat(timeString);
    paramFileName = paramFileName.concat(".scm");

    return this;
  }

  /*"The output object needs to have a reference to a Specialist object, from whom it can gather data on the volume of trade."*/
  /**
   * El objeto output necesita una referencia al especialista para poder recoger
   * de él el volumen de negociación.
   * @return this
   */
  public Object setSpecialist (Specialist theSpec)
  {
    outputSpecialist = theSpec;
    return this;
  }

  /*"The output object must have a reference to a World object, from which it can get price, dividend, or any other information it wants"*/

  /**
   * El objeto output necesita una referencia al mundo para poder recoger
   * de él el precio y el dividendo.
   * @return this
   */
  public Object setWorld (World theWorld)
  {
    outputWorld = theWorld;
    return this;
  }

  /*"This flushes a snapshot of the current parameter settings from
    both the ASMModelParams and BFAgentParams into a file"*/

  /**
   * Este método crea el fichero de los parámetros.
   *
   * @param modelParam Parámetros del modelo.
   * @param bfParms Parámetros de los bfagents.
   * @param t Entero que representa el tiempo actual en la simulación.
   *
   * @return this
   */
  public Object writeParams$BFAgent$Time( ASMModelParams modelParam, BFParams bfParms , long t)
  {


  try{
      fw = new FileWriter(paramFileName);
      bw = new BufferedWriter(fw);
      salida= new PrintWriter(bw);

      salida.println("Parameters at " + t);

      salida.println("\nModel Parameters\n");
      salida.println("\tnumBFagents = " + modelParam.numBFagents);  /*" number of BFagents "*/
      salida.println("\tinitholding = " + modelParam.initholding);
      salida.println("\tinitialcash = " + modelParam.initialcash);
      salida.println("\tminholding = " + modelParam.minholding);
      salida.println("\tmincash = " + modelParam.mincash);
      salida.println("\tintrate = " + modelParam.intrate);

      salida.println("\n\tDividend parameters\n");
      salida.println("\tbaseline = " + modelParam.baseline);   //Also used by World.
      salida.println("\tmindividend = " + modelParam.mindividend);
      salida.println("\tmaxdividend = " + modelParam.maxdividend);
      salida.println("\tamplitude = " + modelParam.amplitude);
      salida.println("\tperiod = " + modelParam.period);
      salida.println("\texponentialMAs = " + modelParam.exponentialMAs);   //Also used by World.//pj:was BOOL
      salida.println("\n\tSpecialist parameters\n");
      salida.println("\tmaxprice = " + modelParam.maxprice);
      salida.println("\tminprice = " + modelParam.minprice);
      salida.println("\ttaup = " + modelParam.taup);
      salida.println("\tsptype = " + modelParam.sptype);
      salida.println("\tmaxiterations = " + modelParam.maxiterations);
      salida.println("\tminexcess = " + modelParam.minexcess);
      salida.println("\teta = " + modelParam.eta);
      salida.println("\tetamax = " + modelParam.etamax);
      salida.println("\tetamin = " + modelParam.etamin);
      salida.println("\trea = " + modelParam.rea);
      salida.println("\treb = " + modelParam.reb);
      salida.println("\trandomSeed= " + modelParam.randomSeed);

      salida.println("\n\tAgent parameters\n");
      //These might be used for other agents that a user implements.
      salida.println("\ttauv = " + modelParam.tauv);
      salida.println("\tlambda = " + modelParam.lambda);
      salida.println("\tmaxbid = " + modelParam.maxbid);
      salida.println("\tinitvar = " + modelParam.initvar);
      salida.println("\tmaxdev = " + modelParam.maxdev);
      salida.println("\tsetOutputForData = " + modelParam.setOutputForData);

      salida.println("\n\nBF Agents Parameters\n");
      salida.println("\tnumfcasts = " + bfParms.numfcasts); /*"number of forecasts maintained by this agent"*/
      salida.println("\tcondwords =" + bfParms.condwords) ; /*"number of words of memory required to hold bits"*/
      salida.println("\tcondbits = " + bfParms.condbits); /*"number of conditions bits are monitored"*/
      salida.println("\tmincount = " + bfParms.mincount); /*"minimum number of times forecast must be used to become active"*/
      salida.println("\tgafrequency = " + bfParms.gafrequency); /*"how often is genetic algorithm done?"*/
      salida.println("\tfirstgatime = " + bfParms.firstgatime); /*"after how many time steps is the genetic algorithm done"*/
      salida.println("\tlongtime = " + bfParms.longtime);	/*" unused time before Generalize() in genetic algorithm"*/
      salida.println("\tindividual = " + bfParms.individual);
      salida.println("\ttauv = " + bfParms.tauv);
      salida.println("\tlambda = " + bfParms.lambda);
      salida.println("\tmaxbid = " + bfParms.maxbid);
      salida.println("\tbitprob = " + bfParms.bitprob);
      salida.println("\tsubrange = " + bfParms.subrange);	/*" fraction of min-max range for initial random values"*/
      salida.println("\ta_min = " + bfParms.a_min);
      salida.println("\ta_max = " + bfParms.a_max);	/*" min and max for p+d coef"*/
      salida.println("\tb_min = " + bfParms.b_min);
      salida.println("\tb_max = " + bfParms.b_max);
      salida.println("\tc_min = " + bfParms.c_min);
      salida.println("\tc_max = " + bfParms.c_max);
      salida.println("\ta_range = " + bfParms.a_range);
      salida.println("\tb_range = " + bfParms.b_range);
      salida.println("\tc_range = " + bfParms.c_range);
      salida.println("\tnewfcastvar = " + bfParms.newfcastvar);	/*" variance assigned to a new forecaster"*/
      salida.println("\tinitvar = " + bfParms.initvar);	/*" variance of overall forecast for t<200"*/
      salida.println("\tbitcost = " + bfParms.bitcost);	/*" penalty parameter for specificity"*/
      salida.println("\tmaxdev = " + bfParms.maxdev);	/*" max deviation of a forecast in variance estimation"*/
      salida.println("\tpoolfrac = " + bfParms.poolfrac);	/*" fraction of rules in replacement pool"*/
      salida.println("\tnewfrac = " + bfParms.newfrac);	/*" fraction of rules replaced"*/
      salida.println("\tpcrossover = " + bfParms.pcrossover);	/*" probability of running Crossover()."*/
      salida.println("\tplinear = " + bfParms.plinear);	/*" linear combination "crossover" prob."*/
      salida.println("\tprandom = " + bfParms.prandom);	/*" random from each parent crossover prob."*/
      salida.println("\tpmutation = " + bfParms.pmutation);	/*" per bit mutation prob."*/
      salida.println("\tplong = " + bfParms.plong);	        /*" long jump prob."*/
      salida.println("\tpshort = " + bfParms.pshort);	/*" short (neighborhood) jump prob."*/
      salida.println("\tnhood = " + bfParms.nhood);	        /*" size of neighborhood."*/
      salida.println("\tgenfrac = " + bfParms.genfrac);	/*" fraction of 0/1 bits to generalize"*/
      salida.println("\tgaprob = " + bfParms.gaprob);	/*" derived: 1/gafrequency"*/
      salida.println("\tnpool = " + bfParms.npool) ;		/*" derived: replacement pool size"*/
      salida.println("\tnnew = " + bfParms.nnew);		/*" derived: number of new rules"*/
      salida.println("\tnnulls = " + bfParms.nnulls);            /*" unnused bits"*/
      salida.close();

      }catch(java.io.IOException e){
      System.err.println ("Exception writing Parameters");}

    return this;
  }



  /*"Because it is possible for users to turn on data writing during a
    run of the simulation, it is necessary to have this method which can
    initialize the data output files. Each time this is called, it
    checks to see if the files have already been initialized. That way
    it does not initialize everything twice."*/

/**
 * Este método prepara el fichero de los resultados. Se ejecuta cuando
 * pulsamos el botón "toggleDataWrite" de la interfaz gráfica de
 * la sonda del ASMObserverSwarm por primera vez.
 *
 * @return this
 */
  public Object prepareOutputFile()
  {

    if (dataFileExists == true) return this;

    else{

      outputFile = new String ("output.data");
      outputFile = outputFile.concat(timeString);

      try{
      fw2 = new FileWriter(outputFile);
      bw2 = new BufferedWriter(fw2);
      salida2= new PrintWriter(bw2);
        salida2.println("currentTime\t price\t dividend\t volume\n\n");
        }catch(java.io.IOException e){
          System.err.println ("Exception writing data");}


      dataFileExists = true;
    }

    return this;
  }



  /*"The write data method dumps out measures of the price, dividend, and volume indicators into several formats"*/

    /**
   * Este método escribe el precio, el dividendo y el volumen en el
   * fichero de los resultados. Se ejecuta con periodicidad "displayFrequency"
   * siempre que se haya solicitado la creación del fichero.
   *
   *
   * @return this
   */
  public Object writeData()
  {

    long t = Globals.env.getCurrentTime();
    String worldName = new String("world");
    String specName= new String("specialist");


    try {

    salida2.print(t);
    salida2.print("\t\t");
    salida2.print((float)outputWorld.getPrice());
    salida2.print("\t");
    salida2.print((float)outputWorld.getDividend());
    salida2.print("\t");
    salida2.print((float)outputSpecialist.getVolume());
    salida2.print("\n");
     } catch (Exception e) {
      System.err.println ("Exception dataOutputFile.writeChars: " + e.getMessage ());
      }

    return this;
  }

  /*"It is necessary to drop the data writing objects in order to make
  sure they finish their work.
  "*/

  /**
   * Cierra el fichero y libera la memoria.
   */
 public void drop()
  {
    if (salida2 != null)
      salida2.close();

    super.drop();
  }


}
