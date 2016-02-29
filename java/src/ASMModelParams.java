//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.objectbase.Swarm;
import swarm.objectbase.SwarmImpl;
import swarm.objectbase.VarProbe;
import swarm.objectbase.MessageProbe;
import swarm.objectbase.EmptyProbeMapImpl;

import swarm.defobj.Zone;

import swarm.Globals;

/**
 * <p>Title: ASMModelParams</p>
 * <p>Description: Esta es la clase que contiene los par�metros asociados a
 * ASMModelSwarm. Todos ellos pueden modificarse a trav�s de la interfaz
 * gr�fica de la sonda de esta clase.</p>
 * <p>Esta clase no implementa ning�n m�todo propio.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organizaci�n y Gesti�n de Empresas. Universidad de Valladolid</p>
 * @author Jos� Manuel Gal�n & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class ASMModelParams extends SwarmObjectImpl
{
  /**N�mero de agentes   */
  public int numBFagents = 25;  /*" number of BFagents "*/
  /**N�mero de acciones que tiene cada agente al comenzar la simulaci�n */
  public float initholding = 1;
  /**N�mero de unidades de efectivo que tiene cada agente al comenzar la simulaci�n */
  public double initialcash = 20000;
  /**N�mero m�nimo de acciones que puede tener un agente. Si minholding es menor
   * que 0, estamos permitiendo la venta en corto.*/
  public double minholding = -5;

  /**N�mero m�nimo de unidades de efectivo que puede tener un agente. Si mincash
   *  es menor que 0, estamos permitiendo la existencia de pr�stamos.*/
  public double mincash = 0;

  /**Tasa de inter�s   */
  public double intrate = 0.1;

  //Dividend parameters

    /**L�nea media de dividendos   */
  public double baseline = 10;   //Also used by World.

    /**Dividendo m�nimo  */
  public double mindividend = 0.00005;

    /**Dividendo m�ximo   */
  public double maxdividend = 100;

  /**La amplitud de las desviaciones del error del proceso AR(1) generador del
 * dividendo medida en unidades de "baseline". La desviaci�n t�pica del error
 * del proceso es igual al producto de la amplitud por la "baseline"
   *  */
  public double amplitude = 0.02727;

  /**El periodo medio o tiempo de autocorrelaci�n del proceso AR(1) generador
   * de los dividendos. El coeficiente de autocorrelaci�n de primer orden
   * (que coincide con el par�metro del proceso) es
   * igual a rho = exp(-1/period).
   */
  public double period = 19.5;

  /**1 si queremos medias m�viles exponenciales.
   */
  public int exponentialMAs = 1;   //Also used by World.//pj:was BOOL
  //Specialist parameters
  /**Precio m�ximo   */
  public double maxprice = 500;

   /**Precio m�nimo   */
  public double minprice = 0.001;

   /**Coeficiente para calcular la media m�vil del beneficio de los agentes*/
  public double taup = 50;
  /**Indica el tipo de especialista que vamos a usar. Puede valer 0
   * (expectativas racionales), 1 (usa la pendiente de las funciones de demanda)
   *  � 2 (especialista tipo ETA).   */
  public int sptype = 1;

  /**Iteraciones m�ximas para calcular el precio de mercado
   */
  public int maxiterations = 10;

  /**Exceso de demanda m�nimo para que el especialista d� por finalizado el
   * proceso de b�squeda del precio de equilibrio.
   */
  public double minexcess = 0.01;

  /**Coeficiente por el que el especialista ETA multiplica al exceso de demanda
   * para modificar el precio de prueba en su proceso de b�squeda del precio de
   * equilibrio. Es una medida de la elasticidad-precio de la demanda de acciones
   */
  public double eta = 0.0005;

  /**
   * eta m�xima
   */
  public double etamax = 0.05;
  /**
   * eta m�nima
   */
  public double etamin = 0.00001;
   /**Coeficiente por el que el especialista de las expectativas racionales
    * multiplica al dividendo para calcular el precio de equilibrio.
    *
    */
  public double rea = 6.333855553;

  /**Coeficiente que el especialista de las expectativas racionales
    * usa como t�rmino independiente para calcular el precio de equilibrio.
    */
  public double reb = 34.71196262;

  /**Semilla para generar n�meros aleatorios.
   */
  public int randomSeed= 0;
  //Agent parameters overridden by the BFagent.
  //These might be used for other agents that a user implements.

   /**Coeficiente para calcular la varianza de los predictores (forecasters).*/
  public double tauv = 75;

  /**Coeficiente de aversi�n al riesgo de los agentes.
   */
  public double lambda = 0.5;

  /**M�xima demanda u oferta de acciones por parte de los agentes.
   */
  public double maxbid = 10;

  /**
   * Varianza inicial de los predictores (forecasters).
   */
  public double initvar = 3.999769641;

  /**
   * M�xima desviaci�n de un predictor en la estimaci�n de la varianza.
   */
  public double maxdev = 100;

  /**
   * En esta versi�n no vale para nada.
   */
  public int setOutputForData = 0;

  /**Constructor: Construye la sonda (probe) que nos permite modificar
   * los par�metros del modelo antes de que d� comienzo la simulaci�n.
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  ASMModelParams(Zone aZone){

   super (aZone);
  /*"The ASMModelParams class is a "holding class" for the parameters
    that are associated with the ASMModelSwarm class and it also
    controls the GUI probes that users can use to change variables at
    runtime.  These values are set here in order to keep the code clean
    and neat!  Several parts of the simulation need to have access to
    the information held by ASMModelParams, not just ASMModelParams, but
    also any classes that want information on system parameters.

    A big reason for keeping these values in a separate class is that
    they can be used by both batch and graphical runs of the model.

    There are values saved for these parameters in the asm.scm file, and
    the Parameters class, which orchestrates all this parameter magic,
    does the work of creating one of these ASMModelParams objects."*/

    // Now, build a customized probe map using a `local' subclass
    // (a special kind of Java `inner class') of the
    // EmptyProbeMapImpl class.  Without a probe map, the default
    // is to show all variables and messages. Here we choose to
    // customize the appearance of the probe, give a nicer
    // interface.

     class ASMModelParamsProbeMap extends EmptyProbeMapImpl {
      private VarProbe probeVariable (String name) {
        return
          Globals.env.probeLibrary.getProbeForVariable$inClass
          (name, ASMModelParams.this.getClass ());
      }
      private MessageProbe probeMessage (String name) {
        return
          Globals.env.probeLibrary.getProbeForMessage$inClass
          (name, ASMModelParams.this.getClass ());
      }
      private void addVar (String name) {
        addProbe (probeVariable (name));
      }
      private void addMessage (String name) {
        addProbe (probeMessage (name));
      }
      public ASMModelParamsProbeMap (Zone _aZone, Class aClass) {
        super (_aZone, aClass);
        addVar ("numBFagents");
        addVar ("initholding");
        addVar ("initialcash");
        addVar ("minholding");
        addVar ("mincash");
        addVar ("intrate");
        addVar ("baseline");
        addVar ("mindividend");
        addVar ("maxdividend");
        addVar ("amplitude");
        addVar ("period");
        addVar ("maxprice");
        addVar ("minprice");
        addVar ("taup");
        addVar ("exponentialMAs");
        addVar ("sptype");
        addVar ("maxiterations");
        addVar ("minexcess");
        addVar ("eta");
        addVar ("etamin");
        addVar ("etamax");
        addVar ("rea");
        addVar ("reb");
        addVar ("randomSeed");
        addVar ("tauv");
        addVar ("lambda");
        addVar ("maxbid");
        addVar ("initvar");
        addVar ("maxdev");
        addVar ("setOutputForData");

      }
    }

    // Install our custom probeMap class directly into the
    // probeLibrary
    Globals.env.probeLibrary.setProbeMap$For
      (new ASMModelParamsProbeMap (aZone, getClass ()), getClass ());
  }


}

