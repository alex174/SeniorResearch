//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.Zone;
import java.util.LinkedList;

/**
 * <p>Title: Specialist</p>
 * <p>Description: Existe una única instancia de esta clase.
 * Esa instancia es la encargada de recoger las demandas
 * (positivas o negativas) de los agentes y calcular, mejor o peor, el precio
 * que vacía el mercado (o al menos lo intenta).</p>
 * <p>Existen tres tipos de especialistas diferentes, aunque todos siguen el
 * mismo procedimiento para calcular el precio de mercado:</p>
 * <ul><li>1. Lanzan un precio de prueba
 * <li>2. Mandan a cada agente un mensaje solicitándole su demanda y su
 * sensibilidad al precio.
 * <li>3. En algunos casos, vuelven al primer paso y lanzan un nuevo precio de
 * prueba calculado a partir de la oferta y demanda acumuladas de los agentes.
 * <li>4. Devuelven el último precio calculado.
 * </ul>
 * <p>Una vez que han calculado el precio de mercado, dicen a los agentes que
 * actualicen su posición, sus ganancias y sus posesiones de efectivo.</p>
 * <p>Los tres tipos de especialistas implementados en esta versión son:
 * <ul><li>0. Especialista "Expectativas racionales". (ER)
 * <li>1. Especialista de pendiente (P)
 * <li>2. Especialista de ETA fija. (ETA)
 * </ul>
 *
 * </p>
 * <p>El especialista "Expectativas racionales" (ER) calcula el precio sin
 * iterar como una función lineal del dividendo (precio = rea*dividendo + reb).
 * Partiendo de la hipótesis de
 * que los agentes participantes son homogéneos con expectativas racionales y
 * teniendo en cuenta que forman sus expectativas para el próximo precio como
 * una función lineal del dividendo,
 * se calculan los coeficientes de esta ecuación (rea y reb). El precio
 * calculado usando esta ecuación y esos coeficientes es el que impone este
 * especialista. La utilidad de este especialista es comprobar si el modelo
 * soporta las predicciones del modelo neoclásico estándar. Si así fuera, se
 * debería observar un mercado estático (como efectivamente ocurre).
 * El cálculo de los coeficientes rea y reb no es inmediato aunque tampoco es
 * complicado. Para más detalles, consúltese el proyecto de fin de carrera de
 * Luis R. Izquierdo. </p>
 *
 * <p>El especialista de pendiente (P) calcula el exceso de oferta o de
 * demanda para un precio de prueba y, teniendo en cuenta la pendiente de las
 * curvas de oferta y demanda, lanza un nuevo precio de prueba. El proceso de
 * búsqueda termina cuando el desajuste entre oferta es suficientemente pequeño
 * (<minexcess) o después de maxiterations iteraciones. Si las curvas de
 * oferta y demanda fueran rectas, el especialista de pendiente llegaría al
 * precio de mercado en dos pasos. Lo que ocurre es que la demanda
 * (positiva o negativa) de cada agente no es una recta infinita, puesto que
 * pueden existir algunas restricciones de número de acciones o de unidades de
 * efectivo mínimo (venta en corto y préstamos restringidos). Además puede haber
 *  precios máximo y mínimo. </p>
 *
 * <p>Finalmente, el Especialista de ETA fija (ETA) lanza como primer precio de prueba el
 * precio del último periodo. Recoge las demandas de activos de los agentes
 * para ese precio y calcula el exceso de demanda o el exceso de oferta que
 * se produzca para dicho precio. Multiplica este exceso de oferta o demanda por
 * un coeficiente constante (ETA) y entonces fija el precio de mercado de acuerdo
 * con la siguiente ecuación:</p>
 * <p>precio = precio-de-prueba*(1 + ETA*(desajuste)) </p>
 * <p>El proceso de búsqueda del precio de mercado finaliza en dos pasos.
 *
 *
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class Specialist extends SwarmObjectImpl {

/*typedef enum
{
  SP_RE = 0,
  SP_SLOPE = 1,
  SP_ETA = 2
} SpecialistType;
*/

/**
 * Especialista "Expectativas racionales"
 */
  final int SP_RE = 0;
  /**
   * Especialista de pendiente
   */
  final int SP_SLOPE = 1;
  /**
   * Especialista de ETA fija
   */
  final int SP_ETA = 2;
  /**Precio máximo   */
  double maxprice; /*"Ceiling on stock price"*/
  /**Precio mínimo   */
  double minprice; /*"Floor under stock price"*/
  /**Se usa para ajustar el precio ante un desequilibrio oferta-demanda */
  double eta;  /*"Used in adjusting price to balance supply/demand"*/
  // double etainitial; /not used in ASM-2.0
  /**El desajuste |demanda - oferta| debe ser inferior a minexcess para que
   * el especialista deje de iterar por esta razón. */
  double minexcess; /*"excess demand must be smaller than this if the price adjustment process is to stop"*/
  /**Usado por el especialista ER para calcular el precio de mercado:
   * precio = rea*dividendo + reb   */
  double rea; /*"rational expectations benchmark"*/
  /**Usado por el especialista ER para calcular el precio de mercado:
   * precio = rea*dividendo + reb   */
  double reb; /*" trialprice = rea*dividend + reb "*/
  /**Proporción de demanda satisfecha: volume/bidtotal
   */
  double bidfrac; /*"used in completing trades: volume/bidtotal"*/
  /**Proporción de oferta satisfecha: volume/offertotal
   */
  double offerfrac; /*"used in completing trades: volume/offertotal"*/
  /**
   * Número máximo de iteraciones para calcular el precio de mercado
   */
  int maxiterations; /*" maximum passes while adjusting trade conditions"*/
  //  id agentList; /*" set of traders whose demands must be reconciled"*/
  /**Volumen de negociación
   */
  double volume; /*" volume of trades conducted"*/
  /**Coeficiente para calcular la media móvil del beneficio de los agentes.
   * Este coeficiente es el peso de la media móvil anterior.*/
  double taupdecay; /*"The agent's profit is calculated as an exponentially weighted moving average.  This coefficient weights old inputs in the EWMA"*/
   /**Coeficiente para calcular la media móvil del beneficio de los agentes.
   * Este coeficiente es el peso de la nueva entrada.*/
  double taupnew; /*"Used in calculating exponentially weighted moving average;  taupnew = -expm1(-1.0/aTaup); taupdecay =  1.0 - taupnew; "*/
    //   World * worldForSpec; /*" reference to World object that keeps data"*/
    /**Tipo de especialista que se está usando.
     * <p>Los tres tipos de especialistas implementados en esta versión son:
     * <ul><li>0. Especialista "Expectativas racionales". (ER)
     * <li>1. Especialista de pendiente (P)
     * <li>2. Especialista de ETA fija. (ETA)
     * </ul>
     *
     * </p>
     *
     */
  int sptype; /*" an enumerated type indicating the sort of Specialist is being used, valued 0, 1, or 2"*/

  // The Santa Fe Stockmarket -- Implementation of Specialist class


  /*" One instance of this class is used to manage the trading and
    set the stock price.  It also manages the market-level parameters."*/

  /**Constructor de la clase
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  Specialist (Zone aZone){
  super(aZone);
  }

  /**
   * Fija el precio máximo
   *
   * @param maximumPrice
   * @return this
   */
  public Object setMaxPrice (double maximumPrice)
  {
    maxprice = maximumPrice;
    return this;
  }

  /**
   * Fija el precio mínimo
   *
   * @param minimumPrice
   * @return this
   */
  public Object setMinPrice (double minimumPrice)
  {
    minprice = minimumPrice;
    return this;
  }

  /**
   * Calcula los pesos de la media móvil del beneficio de los agentes.
   *
   * @param aTaup Coeficiente para calcular la media móvil del beneficio de los agentes
   * @return this
   */
  public Object setTaup (double aTaup)
  {
    taupnew = 1-Math.exp(-1.0/aTaup); //pj: moved here from init method
    taupdecay = 1.0 - taupnew;   // moved to simplify!
    return this;
  }



  /*"The specialist can be set to type 0, 1, or 2. If this variable is
  set to any other value, the model will set the Specialist to type 1
  and give a warning in the terminal"*/

  /**Fija el tipo de especialista que vamos a usar. Por defecto se usa el
   * especialista pendiente.
   *
   * @param i Tipo de especialista
   * @return this*/
  public Object setSPtype (int i)
  {
    if(i != 0 && i != 1 && i != 2)
      {
        System.out.println("The specialist type chosen is invalid.  Only 0, 1, or 2 are acceptable.  The Specialist will be set to Slope (i.e., 1).");
        i = 1;
      }
    sptype = i;

    return this;
  }

  /*" Set the maximum number of interations to be done while looking for a market clearing price"*/
    /**
   * Fija el número máximo de iteraciones para calcular el precio de mercado
   *
   * @param someIterations
   * @return this
   */
  public Object setMaxIterations (int someIterations)
  {
    maxiterations = someIterations;
    return this;
  }


    /**
   * Fija el mínimo desajuste |demanda - oferta| para que
   * el especialista deje de iterar por esta razón.
   *
   * @param minimumExcess
   * @return this
   */
  public Object setMinExcess (double minimumExcess)
  {
    minexcess = minimumExcess;
    return this;
  }

    /**
   * Fija eta
   *
   * @param ETA
   * @return this
   */
  public Object setETA (double ETA)
  {
    eta = ETA;
    return this;
  }

     /**
   * Fija rea
   *
   * @param REA
   * @return this
   */
  public Object setREA (double REA)
  {
    rea = REA;
    return this;
  }

     /**
   * Fija reb
   *
   * @param REB
   * @return this
   */
  public Object setREB (double REB)
  {
    reb = REB;
    return this;
  }

/**
 * Este es el método principal de la clase. En este método se calcula
 * el precio de mercado de acuerdo con el especialista elegido.
 * <p>Existen tres tipos de especialistas diferentes, aunque todos siguen el
 * mismo procedimiento para calcular el precio de mercado:</p>
 * <ul><li>1. Lanzan un precio de prueba
 * <li>2. Mandan a cada agente un mensaje solicitándole su demanda y su
 * sensibilidad al precio.
 * <li>3. En algunos casos, vuelven al primer paso y lanzan un nuevo precio de
 * prueba calculado a partir de la oferta y demanda acumuladas de los agentes.
 * <li>4. Devuelven el último precio calculado.
 * </ul>
 * <p>Una vez que han calculado el precio de mercado, dicen a los agentes que
 * actualicen su posición, sus ganancias y sus posesiones de efectivo.</p>
 *
 * @param agentList La lista enlazada de Java que contiene a todos los agentes.
 * @param worldForSpec Referencia al mundo.
 *
 * @return trialprice Precio de mercado
 */
  public double performTrading$Market (LinkedList agentList, World worldForSpec)
  /*" This is the core method that sets a succession of trial prices and
   *  asks the agents for their bids or offer at each, generally
   *  adjusting the price towards reducing |bids - offers|.  * It gets
   *  bids and offers from the agents and * adjuss the price.  Returns
   *  the final trading price, which becomes * the next market price.
   *  Various methods are implemented, but all * have the structure:
   *  1. Set a trial price

      2. Send each agent a -getDemandAndSlope:forPrice: message and accumulate the total
   *  number of bids and offers at that price.

      3. [In some cases] go to  1.

      4. Return the last trial price.  "*/
  {
    int mcount;
    boolean done;
    double demand, slope, imbalance, dividend;
    double slopetotal = 0.0;
    double trialprice = 0.0;
    double offertotal = 0.0;
    double bidtotal = 0.0;

    Agent agent;
    LinkedList index = new LinkedList();

    volume = 0.0;

    // Save previous values
    //oldbidtotal = bidtotal;  //pj: old variables were never used anywhere
    //oldoffertotal = offertotal;
    //oldvolume = volume;

    dividend = worldForSpec.getDividend();
  // Main loop on {set price, get demand}
    for (mcount = 0, done = false; mcount < maxiterations && !done; mcount++)
      {
        // Set trial price -- various methods
        switch (sptype)
          {
          case SP_RE:
            // Rational expectations benchmark:  The rea and reb parameters must
            // be calculated by hand (highly dependent on agent and dividend).
            trialprice = rea*dividend + reb;
            done = true;		// One pass
            break;

          case SP_SLOPE:
            if (mcount == 0)
              trialprice = worldForSpec.getPrice();
            else
              {
                // Use demand and slope information from the agent to set a new
                // price where the market should clear if the slopes are all
                // present and correct.  Iterate until it's close or until
                // maxiterations is reached.
                imbalance = bidtotal - offertotal;
                if (imbalance <= minexcess && imbalance >= -minexcess)
                  {
                    done = true;
                    continue;
                  }
                // Update price using demand curve slope information
                if (slopetotal != 0)
                  trialprice -= imbalance/slopetotal;
                else
                  trialprice *= 1 + eta*imbalance;
              }
            break;

          case SP_ETA:
            //Need to use this for ANNagent.
            if (mcount == 0)
              {
                trialprice = worldForSpec.getPrice();
              }
            else
              {
                trialprice = (worldForSpec.getPrice())*(1.0 +
                                                     eta*(bidtotal-offertotal));
                done = true;	// Two passes
              }
            break;
          }

        // Clip trial price
        if (trialprice < minprice)
          trialprice = minprice;
        if (trialprice > maxprice)
          trialprice = maxprice;

        // Get each agent's requests and sum up bids, offers, and slopes
        bidtotal = 0.0;
        offertotal = 0.0;
        slopetotal = 0.0;
        index = agentList;
        for(int i=0; i < index.size(); i++)
          {
            agent = (Agent)index.get(i);
            slope = 0.0;
            demand = agent.getDemandAndSlope$forPrice( slope,trialprice);
            slopetotal += slope;
            if (demand > 0.0)
              bidtotal += demand;
            else if (demand < 0.0)
              offertotal -= demand;
            //System.out.println("bidtotal is " + bidtotal + "and offertotal is " + offertotal);
          }

        // Match up the bids and offers
        volume = (bidtotal > offertotal ? offertotal : bidtotal);
        bidfrac = (bidtotal > 0.0 ? volume / bidtotal : 0.0);
        offerfrac = (offertotal > 0.0 ? volume / offertotal : 0.0);
      }

    return trialprice;
  }

  /*"Returns the volume of trade to anybody that wants, such as the observer or output objects"*/
  public double getVolume ()
  {
    return volume;
  }

/**
 * Actualiza la posición y el efectivo de cada agente después de que
 * se lleven a cabo los intercambios acordados. En ocasiones (casi siempre)
 * es necesario prorratear.
 *
 * @param agentList La lista enlazada de Java que contiene a todos los agentes.
 * @param worldForSpec Referencia al mundo.
 *
 * @return this
 */
  public Object completeTrades$Market(LinkedList agentList, World worldForSpec)
  /*"Updates the agents cash and position to consummate the trades
    previously negotiated in -performTrading, with rationing if
    necessary.

   * Makes the actual trades at the last trial price (which is now the
   * market price), by adjusting the agents' holdings and cash.  The
   * actual purchase/sale my be less than that requested if rationing
   * is imposed by the specialist -- usually one of "bidfrac" and
   * "offerfrac" will be less than 1.0.
   *
   * This could easiliy be done by the agents themselves, but we let
   * the specialist do it for efficiency.
   "*/
  {
    Agent agent;
    LinkedList index = new LinkedList();
    double bfp, ofp, tp, profitperunit;
    double price = 0.0; //pj: was IVAR

    price = worldForSpec.getPrice();
    profitperunit = worldForSpec.getProfitPerUnit();

  // Intermediates, for speed
    bfp = bidfrac*price;
    ofp = offerfrac*price;
    tp = taupnew*profitperunit;

  // Loop over enabled agents
    index = agentList;

    for(int i=0; i < index.size(); i++)
      {
        agent = (Agent)index.get(i);
        // Update profit (moving average) using previous position
        agent.profit = taupdecay*agent.profit + tp*agent.position;

        // Make the actual trades
        if (agent.demand > 0.0)
          {
            agent.position += agent.demand*bidfrac;
            agent.cash     -= agent.demand*bfp;
          }
        else if (agent.demand < 0.0)
          {
            agent.position += agent.demand*offerfrac;
            agent.cash     -= agent.demand*ofp;
          }
      }

    return this;
  }
  /**
   * Liberador de memoria.
   */
  public void drop()
  {
    super.drop();
  }
}

