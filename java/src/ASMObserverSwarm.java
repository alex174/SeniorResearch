// Java ASM application.
// This library is distributed without any warranty; without even the
// implied warranty of merchantability or fitness for a particular
// purpose.  See file COPYING for details and terms of copying.

//package asmjava;

import swarm.Globals;
import swarm.Selector;
import swarm.defobj.Zone;

import swarm.gui.HistogramImpl;
import swarm.analysis.Averager;

import swarm.activity.Activity;
import swarm.activity.ActionGroup;
import swarm.activity.ActionGroupImpl;
import swarm.activity.Schedule;
import swarm.activity.ScheduleImpl;

import swarm.objectbase.Swarm;
import swarm.objectbase.VarProbe;
import swarm.objectbase.MessageProbe;
import swarm.objectbase.EmptyProbeMapImpl;

import swarm.analysis.EZGraph;
import swarm.analysis.EZGraphImpl;
//import swarm.analysis.ActiveGraph;

import swarm.simtoolsgui.GUISwarm;
import swarm.simtoolsgui.GUISwarmImpl;

import java.util.LinkedList;
//import java.util.Collection;

/* The ASMObserverSwarm is a Swarm with a graphical user interface
  (GUI).  It follows the prototype Swarm model, in that the Observer
  Swarm is thought of an entity that can describe or report on the
  state of a simulation, but not interact with it.  The Observer
  causes the ASMModelSwarm to be created, and it monitors various
  variables by checking directly with the agents.

  Note that the ASMObserverSwarm has a set of "standard" methods that
  Swarms have--buildObjects:, buildActions, activateIn:--and inside
  each one it makes sure that the next-lower level, the ASMModelSwarm,
  is sent the same message.

  If you don't want to watch the GUI, run the model in batch mode,
  meaning you use the -b flag on the command line.

  */


 /**
 * <p>Title: ASMObserverSwarm</p>
 * <p>Description: El ASMObserverSwarm es un Swarm con una interfaz gráfica
 * para el usuario (GUI).  Existe una única instancia de esta clase.
 * Se sigue el mismo patrón de todas las simulaciones en Swarm, en el
 * sentido de que el objeto observador es una entidad que describe e informa
 * sobre el estado de la simulación, pero no interacciona con ella.</p>
 * <p> El Observador crea y contiene en su interior al Modelo. Además, realiza
 * diversas tareas para comprobar la integridad de diversas variables de la
 * simulación y monitoriza muchas de ellas.</p>
 * <p>Como es habitual en todas las simulaciones Swarm, el Observador responde a
 * los mensajes buildObjects() (Crea Objetos), buildActions() (Crea Acciones) y
 * activateIn() (Actívate en determinada zona). Además, el Observador se encarga
 * de comunicar los mismos mensajes al siguiente nivel en la jerarquía de la
 * simulación: el Modelo (ModelSwarm).</p>
 * <p>Actualmente, sólo es posible correr la simulación en modo gráfico</p>
 *
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class ASMObserverSwarm extends GUISwarmImpl {

  /** Frecuencia de actualización de los gráficos y de escritura a los ficheros.
   *  Puede modificarse fácilmente desde la sonda del Observador*/
  public int displayFrequency;

  /** El grupo de acciones (ActionGroup) que contiene la secuencia de eventos
   *  de la interfaz gráfica (GUI). */
  public ActionGroup displayActions;

  /** El programa de acciones que debe llevar a cabo el observador.
   *  Se lleva a cabo cada "displayFrequency" periodos de simulación.*/
  public Schedule displaySchedule;

  /** Objeto que gestiona la escritura en ficheros de los parámetros y de los
   *  resultados de la simulación.*/
  public Output output; /*"An output object"*/

  /** El Modelo. Contiene a los agentes, al mundo, al market-maker o
   *  especialista y al proceso de generación de dividendos, entre otros.
   */
  public ASMModelSwarm asmModelSwarm;

  /**Indica al objeto Output si debe escribir los parámetros a fichero o no*/
  public boolean writeParams;

  /**Indica al objeto Output si debe escribir los resultados de la
   * simulación a fichero o no*/
  public boolean writeData;

  /**Gráfico en el que se representa el precio fundamental y el de mercado*/
  public EZGraph priceGraph; /*"Time plot of risk neutral and observed market price"*/

  /**Gráfico en el que se representa el volumen de negociación*/
  public EZGraph volumeGraph; /*"Time plot of market trading volume"*/

  /**Objeto que contiene los gráficos de barras de la riqueza relativa y la
   * posición de los agentes*/
  public BarChart charts;

  //This is for comparing different agents.  But since there is
  //currently only one agent this is not implemented.

  //public Graph deviationGraph; /*"As of ASM-2.0, this was commented out in ASMObserverSwarm.m"*/

  //public Averager deviationAverager; /*"ditto"*/

  //public GraphElement deviationData; /*"ditto"*/
  //public ActiveGraph deviationGrapher; /*"ditto"*/

  /**Recoge el objeto que contiene los parámetros de la simulación, creado en
   * la función main()*/
  public Parameters arguments;


  /**Constructor: Construye la sonda (probe) que nos permite modificar
   * la frecuencia de actualización de los gráficos y de escritura a los
   * ficheros (debe modificarse antes de comenzar la simulación).
   * También nos permite escribir a fichero los resultados de la
   * simulación (puede hacerse en cualquier momento) y los
   * parámetros (puede hacerse en cualquier momento).
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  ASMObserverSwarm (Zone aZone, Parameters arg) {
    super(aZone);

    arguments = arg;

    // Fill in the relevant parameters (only one, in this case).
    displayFrequency = 3;

    // Now, build a customized probe map using a `local' subclass
    // (a special kind of Java `inner class') of the
    // EmptyProbeMapImpl class.  Without a probe map, the default
    // is to show all variables and messages. Here we choose to
    // customize the appearance of the probe, give a nicer
    // interface.

    class ASMObserverProbeMap extends EmptyProbeMapImpl {
      private VarProbe probeVariable (String name) {
        return
          Globals.env.probeLibrary.getProbeForVariable$inClass
          (name, ASMObserverSwarm.this.getClass ());
      }
      private MessageProbe probeMessage (String name) {
        return
          Globals.env.probeLibrary.getProbeForMessage$inClass
          (name, ASMObserverSwarm.this.getClass ());
      }
      private void addVar (String name) {
        addProbe (probeVariable (name));
      }
      private void addMessage (String name) {
        addProbe (probeMessage (name));
      }
      public ASMObserverProbeMap (Zone _aZone, Class aClass) {
        super (_aZone, aClass);
        addVar ("displayFrequency");
        addMessage ("writeSimulationParams");
        addMessage ("toggleDataWrite");
      }
    }

    // Install our custom probeMap class directly into the
    // probeLibrary
    Globals.env.probeLibrary.setProbeMap$For
      (new ASMObserverProbeMap (aZone, getClass ()), getClass ());
  }

  /**Libera la memoria ocupada por el gráfico priceGraph
   *
   * @return this
   */
  public Object _priceGraphDeath_ (Object caller) {
    priceGraph.drop ();
    priceGraph = null;
    return this;
  }

  /**Libera la memoria ocupada por el gráfico volumeGraph
   *
   * @return this
   */
  public Object _volumeGraphDeath_ (Object caller) {
    volumeGraph.drop ();
    volumeGraph = null;
    return this;
  }


  /*"This creates the model swarm, and then creates a number of
  monitoring objects, such a graphs which show the price trends,
  volume of stock trade, and some excellent bar charts which show the
  holdings and wealth of the agents.  These bar charts (histograms)
  are available in very few other Swarm programs and if you want to
  know how it can be done, feel free to take a look!"*/

  /**<p>Este método crea el objeto Modelo (asmModelSwarm, instancia de
   * ASMModelSwarm), los gráficos que representan los precios y el volumen
   * de negociación y los diagramas de barras que representan la riqueza
   * relativa y la posición de los agentes. Los diagramas de barras requieren
   * bibliotecas adicionales (import com.jrefinery.chart.JFreeChart)</p>
   *
   * <p>Es en este método en el que el programa espera a que el usuario pulse
   * el botón "Start" del panel de control. Una vez pulsado, recoge los
   * parámetros (que el usuario puede haber modificado) y le ordena al objeto
   * asmModelSwarm que proceda a construir todos los objetos restantes en la
   * simulación (los agentes, el mundo, el market-maker o
   *  especialista y el proceso de generación de dividendos, entre otros).</p>
   *
   * @return this
   */
  public Object buildObjects () {

    int numagents;

    //need to create output and parameters so they exist from beginning
    ASMModelParams asmModelParams = arguments.getModelParams ();
    BFParams bfParams = arguments.getBFParams();
    output = new Output (this.getZone());
    output.createEnd();

    super.buildObjects ();

    // First, we create the model that we're actually observing. The
    // model is a subswarm of the observer.

    asmModelSwarm = new ASMModelSwarm (getZone ());
    asmModelSwarm.setOutputObject (output);

    // Now create probe objects on the model and ourselves. This gives a
    // simple user interface to let the user change parameters.

    Globals.env.createArchivedProbeDisplay (this, "ASMObserverSwarm");
    Globals.env.createArchivedProbeDisplay (asmModelParams, "ASMModelParams");
    Globals.env.createArchivedProbeDisplay (bfParams, "BFParams");

    // Instruct the control panel to wait for a button event: we
    // halt here until someone hits a control panel button so the
    // user can get a chance to fill in parameters before the
    // simulation runs
    getControlPanel ().setStateStopped ();

    // Don't set the parameter objects until the model starts up That
    // way, any changes typed into the gui will be taken into account by
    // the model.

    // OK - the user has specified all the parameters for the
    // simulation.  Now we're ready to start.
    arguments.init ();
    asmModelSwarm.setParamsModel$BF (asmModelParams, bfParams);


    // First, let the model swarm build its objects.
    asmModelSwarm.buildObjects ();

    numagents = asmModelParams.numBFagents;

    // Now get down to building our own display objects.


    // Create the graph widget to display prices.

    priceGraph = new EZGraphImpl
      (getZone (),
       "Evolucion temporal de precios",
       "Tiempo", "Precio",
       "priceGraph");
/*
       priceGraph = new EZGraphImpl
      (getZone (),
       "Evolucion temporal de dividendos",
       "Tiempo", "Dividendo",
       "priceGraph");
*/
    // instruct this _priceGraphDeath_ method to be called when
    // the widget is destroyed
    try {
      priceGraph.enableDestroyNotification$notificationMethod
        (this, new Selector (getClass (),
                             "_priceGraphDeath_",
                             false));
    } catch (Exception e) {
      System.err.println ("Exception _priceGraphDeath_: "
                          + e.getMessage ());
    }

 /*
     try {
      priceGraph.createSequence$withFeedFrom$andSelector
        ("Dividendo", asmModelSwarm.getWorld (),
         new Selector (Class.forName ("World"), "getDividend",
                       false));
    } catch (Exception e) {
      System.err.println ("Exception getDividend: "
                          + e.getMessage ());
    }
*/
    // create the data for the actual price

    try {
      priceGraph.createSequence$withFeedFrom$andSelector
        ("Precio de mercado", asmModelSwarm.getWorld (),
         new Selector (Class.forName("World"), "getPrice",
                       false));
    } catch (Exception e) {
      System.err.println ("Exception getPrice: "
                          + e.getMessage ());
    }


    try {
      priceGraph.createSequence$withFeedFrom$andSelector
        ("Precio expectativas racionales", asmModelSwarm.getWorld (),
         new Selector (Class.forName ("World"), "getRationalExpectations",
                       false));
    } catch (Exception e) {
      System.err.println ("Exception getRationalExpectations: "
                          + e.getMessage ());
    }


    // create the data for the risk neutral price
    try {
      priceGraph.createSequence$withFeedFrom$andSelector
        ("Precio neutral al riesgo", asmModelSwarm.getWorld (),
         new Selector (Class.forName ("World"), "getRiskNeutral",
                       false));
    } catch (Exception e) {
      System.err.println ("Exception getRiskNeutral: "
                          + e.getMessage ());
    }

    // Create the graph widget to display volume.
    volumeGraph = new EZGraphImpl
      (getZone (),
       "Volumen de negociacion",
       "Tiempo", "Volumen",
       "volumeGraph");

    // instruct this _volumeGraphDeath_ method to be called when
    // the widget is destroyed
    try {
      volumeGraph.enableDestroyNotification$notificationMethod
        (this, new Selector (getClass (),
                             "_volumeGraphDeath_",
                             false));
    } catch (Exception e) {
      System.err.println ("Exception _volumeGraphDeath_: "
                          + e.getMessage ());
    }

    // create the data for volume
    try {
      volumeGraph.createSequence$withFeedFrom$andSelector
        ("Volumen", asmModelSwarm.getSpecialist (),
         new Selector (Class.forName ("Specialist"), "getVolume",
                       false));
    } catch (Exception e) {
      System.err.println ("Exception getVolume: "
                          + e.getMessage ());
    }


    charts = new BarChart(asmModelSwarm.getAgentList(),(arguments.getModelParams()).initialcash,this.getZone());


    return this;
  }


    /*"This causes the system to save a copy of the current parameter
    settings.  It can be turned on by hitting a button in the probe
    display that shows at the outset of the model run, or any time
    thereafter."*/

  /**Este método ordena al objeto Output crear un fichero con los
   * parámetros de la simulación. Puede pulsarse antes o durante la simulación.
   *
   * @return this
   */
  public Object writeSimulationParams ()
  {
    writeParams = true;
    output.writeParams$BFAgent$Time (arguments.getModelParams(), arguments.getBFParams(), asmModelSwarm.getModelTime());

    return this;
  }

    /*"If the writeParams variable is set to YES, then this method cause
    the system to save a snapshot of the parameters after the system's
    run ends."*/

  /**Si la variable writeParams vale "true", este método ordena al objeto
   * Output crear un fichero con los
   * parámetros de la simulación después de que ésta haya concluido.
   * Este método sólo se llama en el modo batch, luego en esta primera versión
   * nunca se ejecuta.
   *
   * @return this
   */
  public Object expostParamWrite ()
  {
    if (writeParams)
      output.writeParams$BFAgent$Time (arguments.getModelParams(), arguments.getBFParams(), asmModelSwarm.getModelTime());

    return this;
  }

  /*"Returns the condition of the writeParams variable, an indicator
  that parameters should be written to files"*/

  /**Devuelve la variable writeParams, que indica si deben escribirse
   * los parámetros a fichero o no.
   *
   * @return writeParams indica si deben escribirse los parámetros a fichero
   * o no.
   */
  public boolean ifParamWrite ()
  {
    return writeParams;
  }

  /*"This toggles data writing features. It can be accessed by punching
  a button in a probe display that is shown on the screen when the simulation begins"*/

  /**Pone en marcha el proceso de escritura de los resultados de la
   * simulación a fichero. Se puede acceder a este método a través de la sonda
   * antes o durante la simulación.
   *
   * @return writeData Indica al objeto Output si debe escribir los resultados de la
   * simulación a fichero o no.
   */
  public boolean toggleDataWrite (){
    if(!writeData)
      {
        output.prepareOutputFile ();
        writeData = true;
      }
    else writeData = false;
    return writeData;
  }

  /*"If data logging is turned on, this cause data to be written whenever it is called"*/

  /**En el caso de que se haya solicitado escribir los resultados de la
   * simulación a fichero, éste es el método que se encarga de llevar a cabo
   * esa tarea. Forma parte del grupo de acciones (ActionGroup) displayActions.
   * Por tanto, se ejecuta cada "displayFrequency" periodos de simulación.
   *
   * @return this
   */
  public Object _writeRawData_ ()
  {
    if (writeData)
      output.writeData ();
    return this;
  }

  /*" Create actions and schedules onto which the actions are put.
  Since this is an observer, the actions are intended to make sure
  data is collected, displayed to the screen, and written to files
  where appropriate"*/

   /**Crea las acciones y los programas (schedules) que contienen las acciones.
    * Puesto que es un método del observador, las acciones que aquí se crean
    * son básicamente las de actualización de gráficos y escritura a ficheros.
   *
   * @return this
   */
  public Object buildActions ()
  {
    super.buildActions();

    // First, let our model swarm build its own schedule.
    asmModelSwarm.buildActions();

    displayActions = new ActionGroupImpl (getZone());

    try {
        displayActions.createActionTo$message
          (this, new Selector (getClass (), "_writeRawData_", false));
        displayActions.createActionTo$message
          (charts, new Selector (charts.getClass (), "_updateCharts_", false));
        displayActions.createActionTo$message
          (priceGraph, new Selector (priceGraph.getClass (), "step", false));
        displayActions.createActionTo$message
          (volumeGraph, new Selector (volumeGraph.getClass (), "step", false));
        // Schedule the update of the probe displays
        displayActions.createActionTo$message
          (Globals.env.probeDisplayManager,
           new Selector (Globals.env.probeDisplayManager.getClass (),
                         "update", true));
        displayActions.createActionTo$message
          (getActionCache (), new Selector
            (getActionCache ().getClass (), "doTkEvents", true));
      } catch (Exception e) {
        System.err.println ("Exception in setting up displayActions : "
                            + e.getMessage ());
      }

      displaySchedule = new ScheduleImpl (getZone (), displayFrequency);
      // insert ActionGroup instance on the repeating Schedule
      // instance
      displaySchedule.at$createAction (0, displayActions);

      return this;
  }

  /*"This method activates the model swarm within the context of this
    observer, and then it activated the observer's schedules.  This
    makes sure that the actions inserted at time t inside the model are
    placed into the overall time sequence before the observer scheduled
    actions that update graphs which describe the results"*/

   /**Este método, vital en toda simulación Swarm, activa la simulación en el
    * contexto del Observador, después activa el modelo en el mismo contexto y
    *  finalmente activa los programas de acciones (schedules) del propio
    *  observador. De esta forma, las acciones del modelo se colocan en el
    *  programa general de la simulación antes de las acciones del observador
    *  encaminadas a monitorizar las acciones del modelo, como es natural.
   *
   * @param swarmContext El entorno de nuestro Observador. (en esta primera
   * llamada: null)
   * @return getActivity() La actividad de nuestro Swarm
   */
  public Activity activateIn (Swarm swarmContext) {
    // First, activate ourselves (just pass along the context).
    super.activateIn (swarmContext);
    // Activate the model swarm in ourselves. The model swarm is a
    // subswarm of the observer swarm.
    asmModelSwarm.activateIn (this);

    // Now activate our schedule in ourselves. This arranges for
    // the execution of the schedule we built.
    displaySchedule.activateIn (this);

    // Activate returns the swarm activity - the thing that's ready to run.
    return getActivity();
  }


  /*"In order to make sure that the data is actually written to disk, it
    is necessary to pass a "drop" message down the hierarchy so that all
    data writers know it is time to finish up their work. This drop
    method is called at the end of the main.m file and it propogates
    down to all objects created in asmModelSwarm"*/

   /**Este mensaje es llamado desde la función main() y se propaga a lo largo
    * de todos los niveles inferiores de la jerarquía de la simulación. Esto
    * nos permite avisar a los ficheros de que la simulación ha terminado y
    * así poder cerrarlos sin problemas.
   *
   */
  public void drop () {
    this.expostParamWrite ();
    charts.drop();
    asmModelSwarm.drop ();
    super.drop ();
  }

}
