//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.Globals;

import swarm.objectbase.Swarm;
import swarm.objectbase.ProbeMap;
import swarm.defobj.Zone;
//import swarm.simtools;

/**
 * <p>Title: Parameters</p>
 * <p>Description: Esta es la clase de par�metros principal.
 * Existe una �nica instancia de esta clase. Contiene en su
 * interior, como "variables instancia", el objeto que guarda los
 * par�metros del modelo (asmModelParams, instancia de la clase ASMModelParams)
 * y el objeto que guarda los par�metros de los agentes (bfParams, instancia
 * de BFParams).</p>
 * <p>En el programa original, escrito en ObjectiveC, la clase Parameters
 * descend�a de la clase Arguments_c, de forma que cab�a la posibilidad de
 * procesar par�metros a trav�s de la l�nea de comandos. Teniendo en cuenta que
 * esta primera versi�n s�lo incorpora el modo gr�fico y que, en este modo,
 * hemos creado "sondas" (probes) que nos permiten cambiar c�modamente cualquier
 * par�metro en tiempo de ejecuci�n, nosotros decidimos prescindir de las
 * facilidades del procesamiento de par�metros
 * a trav�s de la l�nea de comandos en favor de una mayor simplicidad.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organizaci�n y Gesti�n de Empresas. Universidad de Valladolid</p>
 * @author Jos� Manuel Gal�n & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class Parameters extends SwarmObjectImpl {

  /**Instancia de la clase ASMModelParams, que contiene los par�metros del
   * modelo. El objeto asmModelSwarm,
   * instancia de ASMModelSwarm usar� estos par�metros*/
  public ASMModelParams asmModelParams; /*"parameter object used by ASMModelSwarm"*/

   /**Objeto que contiene los par�metros que controlan el comportamiento de los
    * BFagents. En esta versi�n cada agente posee una copia (id�ntica, por
    * ahora) de estos par�metros, de forma que en un futuro se podr� dar a cada
    * agente unos par�metros diferentes, aumentando as� la heterogeneidad de
    * los mismos.*/
  public BFParams bfParams;/*"parameter object used by BFagent and its various objects, such as BFCast "*/

   /**Entero que nos indica el n�mero de la simulaci�n que estamos corriendo.
    * Lo incluimos para pasarlo por la l�nea de comandos en futuras versiones
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

  /**Constructor: Crea en su interior el objeto que guarda los par�metros
   * del modelo (asmModelParams, instancia de la clase ASMModelParams)
    * y el objeto que guarda los par�metros de los agentes (bfParams, instancia
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

  /**Inicializa el objeto (variable instancia) bfParams m�ndandole el mensaje
   * bfParams.init(). En la versi�n anterior
   * este m�todo tambi�n serv�a para recoger par�metros del fichero asm.scm.
   * En esta versi�n, los par�metros se modifican exclusivamente a trav�s de
   * sondas (o modificando sus valores por defecto en el c�digo).
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
   * par�metros del modelo
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
   * par�metros de los BFagents. En caso de que se desee disponer de agentes
   * con distintos par�metros, cabe la posibilidad de que cada uno de los
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

  /**Este m�todo devuelve el n�mero de la simulaci�n que estamos corriendo.
   * Este par�metro se debe pasar a trav�s de la l�nea de comandos, por lo que
   * no se puede modificar en esta versi�n
   *
 *
 * @return run Entero que nos indica el n�mero de la simulaci�n que estamos corriendo.
 */
  public int getRunArg()
  {
    return run;
  }

  /*"Sometimes we worry that the Parameter object did not get created properly, so this method tells it to speak to the command line with a warm greeting"*/

  /**A veces tenemos que asegurarnos de que el objeto que contiene todos los
   * par�metros se ha creado correctamente. Este m�todo no suele llamarse en
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

