// Java ASM application.
// This library is distributed without any warranty; without even the
// implied warranty of merchantability or fitness for a particular
// purpose.  See file COPYING for details and terms of copying.

//package asmjava;

import swarm.Globals;
import swarm.Selector;
import swarm.defobj.Zone;
import swarm.defobj.SymbolImpl;

import swarm.defobj.FArguments;
import swarm.defobj.FArgumentsImpl;
import swarm.defobj.FCall;
import swarm.defobj.FCallImpl;

import swarm.activity.Activity;
import swarm.activity.ActionGroup;
import swarm.activity.ActionGroupImpl;
import swarm.activity.Schedule;
import swarm.activity.ScheduleImpl;
import swarm.activity.FActionForEach;

import swarm.objectbase.Swarm;
import swarm.objectbase.SwarmImpl;
import swarm.objectbase.VarProbe;
import swarm.objectbase.MessageProbe;
import swarm.objectbase.EmptyProbeMapImpl;

import java.util.LinkedList;



/*"The ASMModelSwarm is where the substantive work of the simulation
  is orchestrated.  The ASMModelSwarm object is told where to get its
  parameters, and then it buildsObjects (agents, markets, etc), it
  builds up a phony history of the market, and then it schedules the
  market opening and gives the agents a chance to buy and sell.

 This model presents an interesting scheduling challenge. We want to
  generate 501 periods of history that agents can refer to when they
  make decisions.  The warmUp schedule is a repeating schedule, and we
  want its actions done 501 times, and when that is finished, we want
  the periodSchedule to begin at time 0, the starting time of actual
  agent involvement.  When I looked at the original, I shuddered at
  the complexity of it.  I thought to myself, there must be a simpler
  way to do this [grin :)], and it turns out there is.  Now, in case
  you are comparing the new code against the old code, understand that
  the old ASM-2.0 way was like this.  First, the warmUp schedule is
  created.  Then a second nonrepeating schedule is created, called
  "startupSchedule."  At time 0 in the model, that startupSchedule
  controls the first action, and the action it executes is a method
  that causes the warmUp schedule to run 501 steps of prehistory. I
  don't know why they had 501 steps, but they did.  That's the warmUp
  method.  The warmUp method gets that done by creating a temporary
  Swarm class without any context (activateIn: nil) and then
  activating the startupSchedule in there, so it runs "doWarmupStep"
  501 steps, but none of the 501 steps count against time in the
  larger context of the model.


  As of ASM-2.2, I have gotten rid of that complicated setup. Instead
  of creating the phony swarm and activating the warmup schedule
  inside it, I created a method in ASMModelSwarm.m that carries out
  one time step's worth of warmup.  And then I dumped 501
  createActionTo methods on the startup schedule that execute the
  required startup steps.  I've verified the results are numerically
  identical to the original model.  And the scheduling is much easier
  to understand.

  After the warmUp, then an ActionGroup called "periodActions" comes
  to the forefront.  The periodSchedule is a repeating schedule, which
  causes the periodActions to happen at every time step in the larger
  model.

  In ASM-2.0, there was another initial schedule called
  initPeriodSchedule.  After looking at it for a long time, I
  concluded it was doing nothing necessary, it was basically just
  running the periodActions at time 0 only. We might as well just
  schedule that action at time 0 in the startupSchedule. I have
  verified that the model runs exactly the same (numerically
  identical).  Now, as noted below, I think this step is logically
  unnecessary, but removing it changes the numerical path of the
  simulation, so I'm leaving it in for comparison.  "*/

/**
 * <p>Title: ASMModelSwarm</p>
 * <p>Description: El ASMModelSwarm es donde se lleva a cabo todo el trabajo
 * de peso. Existe una única instancia de esta clase.
 * La instancia de esta clase es asmModelSwarm. Cuando el usuario pone
 * en marcha la simulación, esta instancia recibe los parámetros, probablemente
 * modificados desde las sondas. A continuación crea todos los objetos
 * relevantes (agentes, mundo, especialista y dividendo, principalmente)
 * por medio del método buildObjects(). Una vez creados los agentes, crea una
 * historia ficticia del mercado para que las condiciones iniciales del mundo
 * (por ejemplo la media móvil de 500 periodos) tengan sentido. Por último, hace
 * sonar la campana de apertura del mercado y deja a los agentes que hagan el
 * resto.</p>
 *
 * <p>El programa de acciones del modelo es bastante complejo, aunque lo fue
 * muchísimo más en las primeras versiones del mercado en ObjectiveC. Lo
 * que se persigue es conseguir crear una historia ficticia inicial de 502
 * periodos de forma que cuando los agentes empiecen a negociar dispongan de
 * datos que tengan un mínimo de sentido. Para conseguir este objetivo se crean
 * dos programas de acciones. El primero, llamado startupSchedule, será el
 * encargado de crear la historia ficticia inicial. El segundo, llamado
 * periodSchedule, será el que se repita cada periodo normal de simulación. </p>
 *
 * <p>El primer programa (startupSchedule) se compone únicamente de una acción
 * (doWarmupStep), pero que se repite 502 veces (lo matizaremos más tarde).
 * Esta acción de calentamiento
 * lo único que hace es crear un dividendo (mediante un proceso AR(1)) y
 * fijar el precio como el precio fundamental (dividendo/tasa de interés). Como
 * este proceso se lleva a cabo 502 veces, cuando termina la ejecución del
 * programa startupSchedule (que no se ejecuta más que una única vez, aunque
 * comprenda 502 acciones iguales), resulta
 * que disponemos de una situación bursátil más o menos creíble. Es decir,
 * todos los parámetros tales como medias móviles sobre el precio o sobre el
 * dividendo contienen datos más o menos válidos. De la misma forma, disponemos
 * de la historia de los 500 últimos dividendos, así como de la historia de los
 *  500 últimos precios (fundamentales). Cabe resaltar que durante la ejecución
 *  de los 502 "doWarmStep", los agentes no han intervenido para nada. Este
 *  periodo de calentamiento no aparecerá ni en las salidas gráficas, ni en
 *  los ficheros. No forma parte de la simulación propiamente dicha.</p>
 *
 * <p>Bien es cierto que lo expuesto en el párrafo anterior con fines didácticos
 * no es del todo exacto. El programa startupSchedule también contiene un
 * grupo de acciones adicional (periodActions) que se ejecutará después de las
 * 502 acciones de calentamiento (doWarmupStep). Este grupo de acciones es el
 * que determina la ejecución normal de la simulación y que luego se repetirá
 * cada periodo de simulación, aunque formando parte del segundo programa. </p>
 *
 * <p>En definitiva, podemos resumir diciendo que el primer programa
 * (startupSchedule) se ejecuta una sola vez antes de nada en la simulación
 * (en t=0). Este programa se compone de 502 acciones
 * iguales (doWarmupStep) y un grupo de acciones (periodActions). Las primeras
 * 502 acciones de calentamiento crean la historia ficticia inicial del
 * mercado, mientras que la ejecución del grupo de acciones periodActions se
 * encarga de que se lleve a cabo el primer intercambio bursátil de la
 * simulación. Este programa, una vez ejecutado, desaparece y deja paso al
 * programa que gestiona la ejecución normal de la simulación: el
 *  periodSchedule.</p>
 *
 * <p>El segundo programa (periodSchedule) es el que determina el curso normal
 * de la simulación. Se repite cada vez que avanza el reloj de la simulación
 * (al contrario que el primer programa: startupSchedule) y
 * comprende un único grupo de acciones, el ya conocido periodActions. Este
 * grupo de acciones regula la ejecución normal de la simulación.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class ASMModelSwarm extends SwarmImpl
{
  // simulation parameters

  /**Entero que representa el tiempo actual en la simulación*/
  int modelTime;    /*"An integer used to represent the current timestep"*/

  /**El grupo de acciones que se ejecutará secuencialmente en cada periodo de
   * simulación. Se compone de 7 acciones diferentes, entre las que se
   * encuentran la generación del dividendo, la determinación del precio de
   * mercado y la actualización del mundo, entre otras.*/
  public ActionGroup periodActions; /*" An ActionGroup that collects things that are supposed to happen in a particular sequential order during each timestep "*/

  /**Programa que contiene únicamente al grupo de acciones periodActions. Es el
   * programa que determina el curso normal de la simulación. Se repite cada
   * vez que avanza el reloj de la simulación. */
  public Schedule periodSchedule; /*" Schedule on which we add period (repeating) actions, most importantly, the action group periodActions"*/

  /**Este programa se ejecuta una sola vez antes de nada en la simulación
  * (en t=0). Se compone de 502 acciones iguales (doWarmupStep) y el grupo de
  * acciones periodActions.*/
  public Schedule startupSchedule;

  /**La lista enlazada de Java que contiene a todos los agentes.
   */
  public LinkedList agentList = new LinkedList();       /*"A Swarm collection of agents "*/

  /**El especialista o market-maker, que vacia el mercado.
   */
  public Specialist specialist;      /*"Specialist who clears the market   "*/

  /** El objeto instancia de la clase Dividend que genera el dividendo mediante
   *  un proceso AR(1).
   */
  public Dividend dividendProcess; /*"Dividend process that generates dividends  "*/

  /** El mundo. Contiene la situación actual y pasada del mercado.
   */
  public World world;          /*"A World object, a price historian, really   "*/

  /** Objeto creado en ASMObserverSwarm que gestiona la escritura en ficheros
   *  de los parámetros y de los resultados de la simulación.*/
  public Output output;         /*"An Output object   "*/

  /** Objeto instancia de BFParams que contiene los parámetros de los
   *  bfAgents.
   */
  public BFParams bfParams;          /*" A (BFParams) parameter object holding BFagent parameters"*/

  /** Objeto instancia de ASMModelParams que contiene los parámetros del
   *  modelo.
   */
  public ASMModelParams asmModelParams;  /*" A (ASMModelParms) parameter object holding parameters of Models"*/

  /**Utilizado para crear acciones para cada uno de los agentes.
   */
  public FActionForEach actionForEach;

  /**Constructor de la clase. Ponemos a 0 el reloj de la simulación.
   *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  ASMModelSwarm (Zone aZone) {
    super (aZone);
    modelTime = 0;
  }

  /*"This is very vital.  When the ASMModelSwarm is created, it needs to
   * be told where to find many constants that determine how agents are
   * created. This passes handles of objects that have the required
   * data."*/

  /**Cuando creamos el asmModelSwarm, necesitamos comunicarle dónde encontrar
   * los parámetros para que cree los agentes y demás objetos conforme a los
   * parámetros introducidos por el usuario.
   *
   * @param modelParams Objeto instancia de ASMModelParams que contiene
   * los parámetros del modelo.
   * @param bfp Objeto instancia de BFParams que contiene los parámetros de los
   *  bfAgents.
   * @return this
   */
  public Object setParamsModel$BF (ASMModelParams modelParams, BFParams bfp)
  {
    bfParams = bfp;
    asmModelParams=modelParams;
    return this;
  }


  /**Le indicamos dónde encontrar el objeto que gestiona la escritura en
   * ficheros de los parámetros y de los resultados de la simulación.
   *
   * @param obj Objeto instancia de Output que gestiona la escritura en
   * ficheros de los parámetros y de los resultados de la simulación.
   *
   * @return this*/
  public Object setOutputObject(Output obj)
  {
    output = obj;
    return this;
  }

  /**Devuelve el número de bfagents, variable instancia de asmModelParams
   *
   * @return asmModelParams.numBFagents número de agentes bfAgents*/
  public int getNumBFagents ()
  {
    return asmModelParams.numBFagents;
  }

  /**Devuelve la posesión inicial de efectivo de los bfagents, variable
   * instancia de asmModelParams
   * @return asmModelParams.initialcash posesión inicial de efectivo de
   *  los bfagents
   * */
  public double getInitialCash ()
  {
    return asmModelParams.initialcash;
  }

  /**Devuelve la lista enlazada de agentes
   * @return agentList lista enlazada de agentes
   * */
  public LinkedList getAgentList ()
  {
    return agentList;
  }

  /*" Returns a handle of the world object, the place where historical
    price/dividend information is maintained.  It is also the place
    where the BFagents can retrieve information in bit string form."*/

  /**Devuelve una referencia al mundo (objeto world), donde se registra la
   * situación actual y pasada del mercado.
   *
   * @return world El mundo. Contiene la situación actual y pasada del mercado.
   */
  public World getWorld ()
  {
    if (world == null) System.out.println("Empty world!");
    return world;
  }

    /*" Return a pointer to the Specialist object"*/

  /**Devuelve una referencia al market-maker (objeto specialist).
   *
   * @return specialist El especialista o market-maker, que vacia el mercado.
   */
  public Specialist getSpecialist ()
  {
    return specialist;
  }

  /*" Return a pointer to an object of the Output class. Sometimes it is
    necessary for other classes to find out who the output record keeper
    is and send that class a message."*/

  /**Devuelve una referencia al objeto output.
   *
   * @return output Objeto instancia de Output que gestiona la escritura en
   * ficheros de los parámetros y de los resultados de la simulación.
   * */
  public Output getOutput ()
  {
    return output;
  }

  /*"
    Returns the integer time-step of the current simulation.
    "*/

  /**Devuelve el entero que representa el tiempo actual en la simulación.
   *
   * @return modelTime Entero que representa el tiempo actual en la simulación.
   * */

  public int getModelTime ()
  {
    return modelTime;
  }

    /*"The value of the randomSeed that starts the simulation will remain
    fixed, unless you change it by using this method"*/

  /**El valor de la semilla (randomSeed) para generar números aleatorios
   * permanece constante a no ser que se modifique a través de este método.
    *
    * @param newSeed Semilla para la generación de números aleatorios.
    * @return this
    */
  public Object setBatchRandomSeed (int newSeed)
  {
    asmModelParams.randomSeed = newSeed;
    return this;
  }

 /*"Build and initialize objects"*/
 /**Construye e inicializa los objetos principales de la simulación:
  * el dividendo, el mundo, el especialista y los agentes.
  *
  * @return this
  *
  */
  public Object buildObjects ()
  {
    int i;

  if(asmModelParams.randomSeed != 0)
    Globals.env.randomGenerator.setStateFromSeed(asmModelParams.randomSeed);
    //pj: note I'm making this like other swarm apps. Same each time, new seeds only if precautions taken.


  /* Initialize the dividend, specialist, and world (order is crucial) */
  dividendProcess = new Dividend (this.getZone());
  dividendProcess.initNormal ();
  dividendProcess.setBaseline (asmModelParams.baseline);
  dividendProcess.setmindividend (asmModelParams.mindividend);
  dividendProcess.setmaxdividend (asmModelParams.maxdividend);
  dividendProcess.setAmplitude (asmModelParams.amplitude);
  dividendProcess.setPeriod (asmModelParams.period);
  dividendProcess.setDerivedParams ();

  world = new World (this.getZone());
  world.createBitnameList();
  world.setintrate (asmModelParams.intrate);
  if(asmModelParams.exponentialMAs == 1) world.setExponentialMAs (true);
    else  world.setExponentialMAs (false);
  world.initWithBaseline (asmModelParams.baseline);
  world.setRea$Reb(asmModelParams.rea, asmModelParams.reb);

  specialist = new Specialist (this.getZone());
  specialist.setMaxPrice (asmModelParams.maxprice);
  specialist.setMinPrice (asmModelParams.minprice);
  specialist.setTaup (asmModelParams.taup);
  specialist.setSPtype (asmModelParams.sptype);
  specialist.setMaxIterations (asmModelParams.maxiterations);
  specialist.setMinExcess (asmModelParams.minexcess);
  specialist.setETA (asmModelParams.eta);
  specialist.setREA (asmModelParams.rea);
  specialist.setREB (asmModelParams.reb);

  output.setWorld (world);
  output.setSpecialist (specialist);

  /* Initialize the agent modules and create the agents */

  /* Set class variables */
  BFagent.init ();
  BFagent.setBFParameterObject (bfParams);
  BFagent.setWorld (world);

  //nowObject create the agents themselves
  for (i = 0; i < asmModelParams.numBFagents; i++)
    {
      BFagent agent;
      agent = new BFagent (this.getZone());
      agent.setID (i);
      agent.setintrate (asmModelParams.intrate);
      agent.setminHolding$minCash(asmModelParams.minholding,asmModelParams.mincash);
      agent.setInitialCash (asmModelParams.initialcash);
      agent.setInitialHoldings();
      agent.setPosition (asmModelParams.initholding);
      agent.initForecasts ();
      agentList.add(agent);
    }

  return this;
}

  /*"This triggers a writing of the model parameters, for record keeping."*/

  /**Este método ordena al objeto Output crear un fichero con los
   * parámetros de la simulación.
   *
   * @return this
   */
  public Object writeParams ()
  {
     if (asmModelParams != null && bfParams != null)
      output.writeParams$BFAgent$Time(asmModelParams,bfParams,modelTime);
    return this;
  }

/*"Create the model actions, separating into two different action
 * groups, the warmup period and the actual period.  Note that time is
 * not calculated by a t counter but internally within Swarm.  Time is
 * recovered by the getTime message"*/

 /**<p>Crea las acciones. Como ya hemos indicado en la introducción a esta clase,
  * el modelo consta de dos programas de acciones: el startupSchedule y el
  * periodSchedule.</p>
  * <p>startupSchedule se compone de 502 acciones iguales (doWarmupStep)
  * y un grupo de acciones (periodActions). Se ejecuta un única vez en t=0.</p>
  * <p>periodSchedule es el programa que determina el curso normal
 * de la simulación. Se repite cada vez que avanza el reloj de la simulación
 * (al contrario que el primer programa: startupSchedule) y
 * comprende un único grupo de acciones, el ya conocido periodActions.</p>
 * <p>Cabe destacar que el tiempo de generación no se calcula a través de un
 * contador, sino que es Swarm quien lo calcula internamente. Podremos cosultar
 * el tiempo de simulación en cualquier momento mediante el método getTime.</p>
 * @return this
  */
  public Object buildActions () {
    super.buildActions();

   //Define the actual period's actions.
    periodActions = new ActionGroupImpl (getZone ());

  //Set the new dividend.  This method is defined below.
    try {
      periodActions.createActionTo$message
        (this, new Selector (getClass (), "periodStepDividend", false));
    } catch (Exception e) {
      System.err.println ("Exception periodStepDividend: " + e.getMessage ());
    }

  // Tell agents to credit their earnings and pay taxes
    try {
      Agent proto = (Agent) agentList.get (0);
      Selector sel =
        new Selector (proto.getClass (), "creditEarningsAndPayTaxes", false);
      actionForEach =
        periodActions.createFActionForEachHomogeneous$call
        (agentList,
         new FCallImpl (this, proto, sel,
                        new FArgumentsImpl (this, sel)));
    } catch (Exception e) {
      e.printStackTrace (System.err);
    }

  // Update world -- moving averages, bits, etc
    try {
      periodActions.createActionTo$message
        (world, new Selector (world.getClass (), "updateWorld", false));
    } catch (Exception e) {
      System.err.println ("Exception updateWorld: " + e.getMessage ());
    }

  // Tell BFagents to get ready for trading (they may run GAs here)
  try {
      Agent proto = (Agent) agentList.get (0);
      Selector sel =
        new Selector (proto.getClass (), "prepareForTrading", false);
      actionForEach =
        periodActions.createFActionForEachHomogeneous$call
        (agentList,
         new FCallImpl (this, proto, sel,
                        new FArgumentsImpl (this, sel)));
    } catch (Exception e) {
      e.printStackTrace (System.err);
    }

  // Do the trading -- agents make bids/offers at one or more trial prices
  // and price is set.  This is defined below.
    try {
      periodActions.createActionTo$message
        (this, new Selector (getClass (), "periodStepPrice", false));
    } catch (Exception e) {
      System.err.println ("Exception periodStepPrice: " + e.getMessage ());
    }

  // Complete the trades -- change agents' position, cash, and profit

    try {
      periodActions.createActionTo$message
        (specialist, new Selector (Class.forName ("Specialist"), "completeTrades$Market", false),agentList,world);
    } catch (Exception e) {
      System.err.println ("Exception periodStepPrice: " + e.getMessage ());
    }

  // Tell the agents to update their performance
    try {
      Agent proto = (Agent) agentList.get (0);
      Selector sel =
        new Selector (proto.getClass (), "updatePerformance", false);
      actionForEach =
        periodActions.createFActionForEachHomogeneous$call
        (agentList,
         new FCallImpl (this, proto, sel,
                        new FArgumentsImpl (this, sel)));
    } catch (Exception e) {
      e.printStackTrace (System.err);
    }

  // Create the model schedule
    startupSchedule = new ScheduleImpl (getZone (), true);


    //force the system to do 502 "warmup steps" at the beginning of the
    //startup Schedule.  Note that, since these phony steps are just
    //handled by telling classes to do the required steps, nothing fancy
    //is required.

    for (int i = 0; i < 502; i++){
      try {
        startupSchedule.at$createActionTo$message (0, this,
            new Selector (this.getClass (), "doWarmupStep",false));
      } catch (Exception e) {
        System.err.println ("Exception doWarmStep: " + e.getMessage ());
      }
    }


    //pj: 2001-10-30. This was in the original model, I don't know why, but
    //taking it out changes the numerical results, so I'm leaving it in,
    //even though it is not logically necessary.

    startupSchedule.at$createAction (0, periodActions);

    periodSchedule = new ScheduleImpl (getZone (),1);

    periodSchedule.at$createAction (0, periodActions);

    return this;
  }

    /*"Ask the dividend object for a draw from the dividend distribution, then tell the world about it. Tell the world to do an update of to respond to the dividend. Then calculate the price the divident implies and insert it into the world"*/

  /**Este método se ejecuta 502 veces en tiempo de simulación t=0 con el
   * objetivo de crear una historia bursátil ficticia inicial. Básicamente, lo
   * que hace es generar un dividendo, actualizar el mundo y fijar el precio de
   * mercado como el precio fundamental.
   *
   * @return this
   *
   */
  public Object doWarmupStep ()
  {
    double div = dividendProcess.dividend ();
    world.setDividend (div);
    world.updateWorld ();
    world.setPrice ((div/(double)asmModelParams.intrate));
    return this;
  }

  /*" Have the dividendProcess calculate a new dividend. Then tell the
    world about the dividendProcess output.  Also this increment the
    modelTime variable"*/

   /**Dice al objeto dividendProcess que genere un nuevo dividendo, se lo
    * envía al mundo e incrementa el tiempo de simulación en 1.
   *
   * @return this
   *
   */
  public Object periodStepDividend ()
  {
    modelTime++;
    world.setDividend (dividendProcess.dividend ());
    return this;
  }

    /*"Have the Specialist perform the trading process. Then tell the world about the price that resulted from the Specialist's action."*/
   /**En primer lugar le dice al market-maker que fije el precio de mercado.
    * Después se lo notifica al mundo.
   *
   * @return this
   *
   */
  public Object periodStepPrice ()
  {
    world.setPrice (specialist.performTrading$Market (agentList,world));
    return this;
  }


    /*"The activities of the ASMModelSwarm are brought into time-sync with
    higher level Swarm activities. Basically, each time the higher level
    takes a step, this one will too, and the higher one won't step again
    until this one is finished with its turn."*/

   /**En este método se activan los programas del asmModelSwarm.
   *
   * @param swarmContext El entorno de nuestro Swarm.
   * @return getActivity() La actividad de nuestro Swarm.
   */
  public Activity activateIn (Swarm swarmContext) {

    // First, activate ourselves via the superclass
    // activateIn: method.  Just pass along the context: the
    // activity library does the right thing.
    super.activateIn (swarmContext);

     // Now activate our own schedules.
    startupSchedule.activateIn (this);
    periodSchedule.activateIn (this);

    // Finally, return our activity.
    return getActivity ();
  }

   /**Este mensaje nos permite avisar a los distintos objetos de que la
    * simulación ha terminado. Liberamos memoria y cerramos ficheros.
   *
   */
  public void drop () {

    dividendProcess.drop ();
    world.drop ();
    specialist.drop ();
    output.drop ();
    super.drop ();
  }

}
