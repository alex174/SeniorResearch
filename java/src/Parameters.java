//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.Globals;

import swarm.objectbase.Swarm;
import swarm.objectbase.ProbeMap;
import swarm.defobj.Zone;
//import swarm.simtools;

/**
 * <p>Title: Parameters</p>
 * <p>Description: Esta es la clase de parámetros principal.
 * Existe una única instancia de esta clase. Contiene en su
 * interior, como "variables instancia", el objeto que guarda los
 * parámetros del modelo (asmModelParams, instancia de la clase ASMModelParams)
 * y el objeto que guarda los parámetros de los agentes (bfParams, instancia
 * de BFParams).</p>
 * <p>En el programa original, escrito en ObjectiveC, la clase Parameters
 * descendía de la clase Arguments_c, de forma que cabía la posibilidad de
 * procesar parámetros a través de la línea de comandos. Teniendo en cuenta que
 * esta primera versión sólo incorpora el modo gráfico y que, en este modo,
 * hemos creado "sondas" (probes) que nos permiten cambiar cómodamente cualquier
 * parámetro en tiempo de ejecución, nosotros decidimos prescindir de las
 * facilidades del procesamiento de parámetros
 * a través de la línea de comandos en favor de una mayor simplicidad.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class Parameters extends SwarmObjectImpl {

  /**Instancia de la clase ASMModelParams, que contiene los parámetros del
   * modelo. El objeto asmModelSwarm,
   * instancia de ASMModelSwarm usará estos parámetros*/
  public ASMModelParams asmModelParams; /*"parameter object used by ASMModelSwarm"*/

   /**Objeto que contiene los parámetros que controlan el comportamiento de los
    * BFagents. En esta versión cada agente posee una copia (idéntica, por
    * ahora) de estos parámetros, de forma que en un futuro se podrá dar a cada
    * agente unos parámetros diferentes, aumentando así la heterogeneidad de
    * los mismos.*/
  public BFParams bfParams;/*"parameter object used by BFagent and its various objects, such as BFCast "*/

   /**Entero que nos indica el número de la simulación que estamos corriendo.
    * Lo incluimos para pasarlo por la línea de comandos en futuras versiones
    * que implementen esta facilidad.*/
  int run; /*an integer indicating the run number of the current simulation. This is passed in as a command line parameter, as in --run=666 or such."*/

    /*"The Artificial Stock Market model has a very large set of
  parameters.  Until ASM-2.2, these paramters were set inside various
  implementation files, making them difficult to find/maintain. Now all
  parameters are set through separate objects, which can be called upon
  whenever needed.

  The originalParameters class is an example of a general
  purpose Swarm command-line processing class. Nevertheless, in this java translated
  version, we have extremely simplified the class as a very first attempt to make
  the model run*/
  /*
  + createBegin: aZone
  {
    static struct argp_option options[] = {
       {"run",            'R',"RunNumber",0,"Run is...",7},
       { 0 }
    };

    Parameters *obj = [super createBegin: aZone];

    [obj addOptions: options];

    return obj;
  }
*/

  /**Constructor: Crea en su interior el objeto que guarda los parámetros
   * del modelo (asmModelParams, instancia de la clase ASMModelParams)
    * y el objeto que guarda los parámetros de los agentes (bfParams, instancia
    * de BFParams).
    *
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  Parameters(Zone aZone){
  super(aZone);

  asmModelParams = new ASMModelParams(aZone);
  bfParams = new BFParams(aZone);
  }
  /*"In order to parse command line parameters, this method runs.
    Because Parameters is subclassed from the Swarm Arguments class,
    whatever keys we check for in this method will always be checked.
    Since processing of command line parameters has not yet been a focal
    point, only one parameter, the "run" number, is processed here.
    This is included mainly as an example of how other parameters might
    be managed."*/
    /*
  - (int)parseKey: (int) key arg: (const char*) arg
  {
    if (key == 'R')
      {
        run = atoi(arg);
        return 0;
      }

   else
      return [super parseKey: key arg: arg];
  }
  */

  /*"This performs the vital job of using the lispAppArchiver to read
    the baseline values of the parameters out of the asm.scm file and
    then creating the parameter objects--asmModelParms and
    bfParams--that hold those values and make them avalable to the
    various objects in the model "*/

  /**Inicializa el objeto (variable instancia) bfParams mándandole el mensaje
   * bfParams.init(). En la versión anterior
   * este método también servía para recoger parámetros del fichero asm.scm.
   * En esta versión, los parámetros se modifican exclusivamente a través de
   * sondas (o modificando sus valores por defecto en el código).
    *
    * @return this
    */
  public Object init()
  {
  /////////////////////////////////////
  /*
    if ((asmModelParams = (ASMModelParams) Globals.env.lispAppArchiver.getWithZone$key
                (this.getZone(), "asmModelParams"))==null)
      System.err.println ("Can't find the modelSwarm parameters");

    if (  (bfParams = (BFParams) Globals.env.lispAppArchiver.getWithZone$key
                (this.getZone(), "bfParams"))==null)
      System.err.println ("Can't find the BFParam's parameters");
*/

    bfParams.init();
    return this;
  }

  /*"Returns an instance of ASMModelParams, the object which holds the model-level input parameters"*/

  /**Devuelve la variable instancia asmModelParams, que contiene los
   * parámetros del modelo
    *
    * @return asmModelParams instancia de ASMModelParams
    */
  public ASMModelParams getModelParams()
  {
    return asmModelParams;
  }


  /*"Returns an instance of the BFParams class, an object which holds
    the default parameter of the BFagents.  If they desire to do so,
    BFagents can create their own instances of BFParams, copy default
    settings, and then allow their parameters to 'wander'.  (As far as I
    know, this potential did not exist before and has not been
    used. PJ-2001-10-31) "*/

    /**Devuelve la variable instancia bfParams, que contiene los
   * parámetros de los BFagents. En caso de que se desee disponer de agentes
   * con distintos parámetros, cabe la posibilidad de que cada uno de los
   * BFagents cree una copia de la instancia bfParams y luego la modifique a
   * su antojo.
    *
    * @return bfParams instancia de BFParams
    */
  public BFParams getBFParams()
  {
    return bfParams;
  }


  /*"Unless one wants to make all IVARS public and access them with ->, then one should create get methods, one for each argument. This gets the run number."*/

  /**Este método devuelve el número de la simulación que estamos corriendo.
   * Este parámetro se debe pasar a través de la línea de comandos, por lo que
   * no se puede modificar en esta versión
   *
 *
 * @return run Entero que nos indica el número de la simulación que estamos corriendo.
 */
  public int getRunArg()
  {
    return run;
  }

  /*"Sometimes we worry that the Parameter object did not get created properly, so this method tells it to speak to the command line with a warm greeting"*/

  /**A veces tenemos que asegurarnos de que el objeto que contiene todos los
   * parámetros se ha creado correctamente. Este método no suele llamarse en
   * condiciones normales.
   *
 *
 * @return this
 */
  public Object sayHello()
  {
    System.out.println("Lo que hacemos en vida se refleja en la eternidad");
    return this;
  }

}

