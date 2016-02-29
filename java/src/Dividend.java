// The Santa Fe Stockmarket -- Interface for the dividend process
//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.random.NormalDistImpl;
import swarm.Globals;
import swarm.defobj.Zone;

/**
 * <p>Title: Dividend</p>
 * <p>Existe una �nica instancia de esta clase. Esa instancia
 *  se encarga de generar una secuencia estoc�stica de dividendos.
 * El proceso de generaci�n de dividendos es ex�geno, independiente del mercado
 * y de los agentes. �nicamente depende de los par�metros del proceso AR(1) y
 * de la semilla utilizada.
 * </p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organizaci�n y Gesti�n de Empresas. Universidad de Valladolid</p>
 * @author Jos� Manuel Gal�n & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class Dividend extends SwarmObjectImpl {

 /**L�nea media de dividendos   */
  double baseline; /*"The centerline around which deviations are computed.
  //			This is equal to the mean for a symmetric process
  //			(i.e., if asymmetry = 0).  "baseline" is set only
  //			from the parameter file, and should NOT normally
  //			be changed from the default value (10.0)."*/
  //
/**La amplitud de las desviaciones del error del proceso AR(1) generador del
 * dividendo medida en unidades de "baseline". La desviaci�n t�pica del error
 * del proceso es igual al producto de la amplitud por la "baseline"
   *  */
  double amplitude; /*"The amplitude of the deviations from the baseline.
  //			Measured in units of "baseline".  The standard
  //			deviation of the process is proportional to this."*/

  /**El periodo medio o tiempo de autocorrelaci�n del proceso AR(1) generador
   * de los dividendos. El coeficiente de autocorrelaci�n de primer orden
   * (que coincide con el par�metro del proceso) es
   * igual a rho = exp(-1/period).
   */
  double period;  /*"The period or auto-correlation time of the process."*/

   /**Dividendo m�nimo  */
  double mindividend;  /*"floor under dividend values"*/
   /**Dividendo m�ximo   */
  double maxdividend; /*"ceiling for dividend values"*/
  /**
   * Desviaci�n t�pica del error del proceso AR(1) generador de los dividendos.
   */
  double deviation;

    /**Coeficiente de autocorrelaci�n de primer orden del proceso AR(1).
     * Se calcula a partir de period: rho = exp(-1/period).
   */
  double rho;

  /**
   * <p>Desviaci�n t�pica del proceso AR(1) generador de los dividendos.</p>
   * <p>gauss = deviation*Math.sqrt(1.0-rho*rho);</p>
   */
  double gauss;
  /**
   * Dividendo
   */
  double dvdnd;
  //NormalDistImpl normal = new NormalDistImpl(); /*"A Swarm Normal Generator object"*/

  /**
   * Objeto de Swarm generador de una distribuci�n normal.
   */
  NormalDistImpl normal;
  /*"
  // This object produces a stochastic sequence of dividends.  The process
  // is independent of the market and agents, depending only the parameters
  // that are set for the dividend process (and on the random number generator).
  "*/

  /**Constructor de la clase
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  Dividend(Zone aZone){

  super(aZone);

  }
  /*"Creates a Swarm Normal Distribution object"*/
  /**
   * Crea el objeto de Swarm generador de una distribuci�n normal est�ndar.
   * @return this
   */
  public Object initNormal ()
  {
    normal= new NormalDistImpl(this.getZone(), Globals.env.randomGenerator, 0, 1 );
    return this;
  }

  /**
   * Fija la baseline.
   *
   * @param theBaseline
   * @return this
   */
  public Object setBaseline(double theBaseline)
  {
    baseline = theBaseline;
    return this;
  }

  /**
   * Fija el dividendo m�nimo.
   *
   * @param minimumDividend
   * @return this
   */
  public Object setmindividend (double minimumDividend)
  {
    mindividend = minimumDividend;
    return this;
  }

  /**
   * Fija el dividendo m�ximo.
   *
   * @param maximumDividend
   * @return this
   */
  public Object setmaxdividend (double maximumDividend)
  {
    maxdividend = maximumDividend;
    return this;
  }


  /*" Sets the "amplitude" parameter.    Returns the
  //	value actually set, which may be clipped or rounded compared to the
  //	supplied argument. See "setDivType:".
  "*/

  /**
   * Fija la amplitud de las desviaciones del error del proceso AR(1) generador del
    * dividendo.
   *
   * @param theAmplitude
   * @return amplitude Devuelve amplitude ligeramente corregida.
   */
  public double setAmplitude (double theAmplitude)
  {
    amplitude = theAmplitude;
    if (amplitude < 0.0)
      amplitude = 0.0;
    if (amplitude > 1.0)
      amplitude = 1.0;
    amplitude = 0.0001*(int)(10000.0*amplitude);
    return amplitude;
  }

  /*" Sets the "period" parameter.   Returns the
  // value actually set, which may be clipped compared to the supplied
  // argument. See "setDivType:". "*/

 /**
   * <p>Fija el periodo medio o tiempo de autocorrelaci�n del proceso AR(1) generador
   * de los dividendos. Se utiliza para calcular el par�metro del proceso
   * (que coincide con el coeficiente de autocorrelaci�n de primer orden).</p>
   * <p>rho = exp(-1/period).</p>
   * <p> Si period es menor que 2, lo pone a 2.
   *
   * @param thePeriod
   * @return period Devuelve period ligeramente corregido.
   */
  public double setPeriod (double thePeriod)
  {
    period = thePeriod;
    if (period < 2)
      period = 2;
    return period;
  }


  public Object setDerivedParams ()
  /*
   * Sets various parameters derived from the externally-settable ones.  This
   * is called lazily, when a parameter is needed and the needsSetDerivedParams
   * flag is set.
   */

   /**
    * Calcula algunos par�metros que se derivan de otros ya conocidos
    *
    * @return this
    */
  {
    deviation = baseline*amplitude;
  // We round rho slightly for analytic ease
    rho = Math.exp(-1.0/((double)period));
    rho = 0.0001*(int)(10000.0*rho);
    gauss = deviation*Math.sqrt(1.0-rho*rho);
    //pj:
    //dvdnd = baseline + gauss*normal();
    dvdnd = baseline + gauss*(normal.getDoubleSample());
    return this;
  }

  /*" Returns the next value of the dividend.  This is the core method
    of the Dividend object, for which all else exists.  It does NOT use
    the global time, but simply assumes that one period passes between
    each call.  Note that "time" may not be the same as the global
    variable "t" because shifts are introduced to maintain phase when
    certain parameters are changed."*/

    /**
     * Devuelve el valor del pr�ximo dividendo. Este es el m�todo principal
     * de la clase, para el cual todos los dem�s trabajan. Cabe destacar que
     * no usamos el tiempo de la simulaci�n, sino que se presupone que entre
     * llamada y llamada al m�todo ha transcurrido un periodo.
     *
     * @return dvdnd El dividendo
     */
  public double dividend ()
  {
    //pj:
    // dvdnd = baseline + rho*(dvdnd - baseline) + gauss*normal();
      dvdnd = baseline + rho*(dvdnd - baseline) + gauss*(normal.getDoubleSample());
    if (dvdnd < mindividend)
      dvdnd = mindividend;
    if (dvdnd > maxdividend)
      dvdnd = maxdividend;

    //   printf(" \n \n World dividend %f baseline %f rho %f max %f min  %f\n \n", dvdnd, baseline, rho, maxdividend, mindividend);

    return dvdnd;
  }

  /**
   * Liberador de memoria.
   */
  public void drop()
  {
    super.drop();
  }
}