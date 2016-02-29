//package asmjava;

import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.Zone;

/**
 * <p>Title: MovingAverage</p>
 * <p>Description: Esta es la clase encargada de crear las medias móviles. Las
 * medias móviles podrán tener pesos iguales o decrecientes exponencialmente, a
 * elección del usuario.</p>
 *
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class MovingAverage extends SwarmObjectImpl {

/**
 * Número de observaciones que se usan para calcular una media móvil
 */
  int width;  /*"number of observations used for a fixed interval moving average"*/
  /**
   * Número de observaciones que se han insertado desde que se creó el objeto.
   * Incluye las 502 de calentamiento.
   */
  int numInputs; /*"number of observations that have already been inserted"*/

/**
 * Contiene los datos que se utilizarán para
 * calcular la media móvil. Tendrá "width" elementos.
 */
  double maInputs[]; /*"historical inputs are kept in this array."*/

  /**
   * Indica la posición del último elemento del array maInputs[]
   * que se ha insertado.
   */
  int arrayPosition; /*"element of maInputs that has been most recently inserted"*/

  /**
   * Suma de los últimos "width" datos que se han insertado.
   */
  double sumOfInputs;/*"sum of the last 'width' inputs"*/

  /**
   * Suma de todos los datos utilizados desde que se creó el objeto media móvil.
   */
  double uncorrectedSum; /*"sum of all inputs since object was created"*/
 /**
  * Media móvil con pesos decrecientes exponencialmente.
  */
  double expWMA;  //exponentially weighted moving average

  /**
   * Pesos que se utilizan para calcular las medias móviles exponenciales.
   */
  double aweight, bweight; /*"Weights used to calculate exponentially weighted moving averages.  These depend on the specified 'width' according to: bweight = -expm1(-1.0/w);aweight = 1.0 - bweight; ewma=aweight*ma(x)+bweight*x"*/

  /**Constructor de la clase
    *
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  MovingAverage(Zone aZone){
  super(aZone);
  }
  /*"This is a general purpose class for creating Moving Averages, either flat "equally weighted" moving averages or exponentially weighted moving averages"*/

/**
 * Este método se usaba para crear e inicializar dinámicamente el array maInputs
 * en la versión de ObjectiveC. En esta versión nunca se llama.
 *
 * @param w Número de observaciones que se usan para calcular la media móvil.
 * Dimensión del array maInputs, que contiene los datos que se utilizarán para
 * calcular la media móvil.
 *
 * @return this
 */
  public Object initWidth (int w)
  {
    int i;
    width=w;

    maInputs = new double[w];
    for(i=0; i < w; i++)
      {
        maInputs[i] = 0;
      }
    numInputs=0;
    sumOfInputs=0;
    arrayPosition=0;
    uncorrectedSum=0;

    bweight = 1-Math.exp(-1.0/w);  //weight for expWMA
    aweight = 1.0 - bweight;   //weight for expWMA; ma=a*ma(x)+b*x

    return this;
  }

  /**
 * Este método se utiliza para inicializar las medias móviles. Cada media
 * móvil lo llama una única vez.
 *
 * @param w Número de observaciones que se usan para calcular la media móvil.
 * Dimensión del array maInputs, que contiene los datos que se utilizarán para
 * calcular la media móvil.
 * @param val Valor con el que se inicializan todos los elementos del array
 * maInputs
 *
 * @return this
 */
  public Object initWidth$Value(int w, double val)
  {
    int i;
    width=w;
    maInputs = new double[w];
    for(i=0; i < w; i++)
      {
        maInputs[i] = val;
      }
    numInputs=w;
    sumOfInputs=w*val;
    arrayPosition=0;
    uncorrectedSum=w*val;

    bweight = 1-Math.exp(-1.0/w);  //weight for expWMA
    aweight = 1.0 - bweight;   //weight for expWMA; ma=a*ma(x)+b*x
    expWMA = val;

    return this;
  }


  /**
   * Devuelve el número de observaciones que se han insertado desde que
   * se creó el objeto. No se utiliza en condiciones normales.
   *
   * @return numInputs
   */
  public int getNumInputs ()
  {
    return numInputs;
  }


 /**
   * Devuelve la media móvil.
   *
   * @return movingAverage
   */
  public double getMA ()
  {
    double movingAverage;
    if (numInputs == 0) return 0;
    else if (numInputs < width)
      {
        movingAverage=  (double)sumOfInputs / (double)  numInputs;
      }
    else
      {
        movingAverage = (double)sumOfInputs / (double) width;
      }
    return movingAverage;
  }

  /**
   * Devuelve la media (suma-de-todos-los-datos/número-de-datos) desde que se
   * creó el objeto media móvil.
   */
  public double getAverage()
  {
    if (numInputs ==0) return 0;
    else return (double)uncorrectedSum/numInputs;
  }

 /**
   * Devuelve la media móvil exponencial.
   *
   * @return expWMA
   */
public double getEWMA()
  {
    return expWMA;
  }

/**
 * Añade un nuevo valor x a la base de datos necesaria para calcular las
 * medias móviles.
 *
 * @param x Nuevo valor que se pretende añadir a la media móvil.
 */
public void addValue ( double x)
  {
    arrayPosition = (width + numInputs) % width;
    if(numInputs < width)
      {
      sumOfInputs+=x;
      maInputs[arrayPosition]=x;
      }
    else
      {
        sumOfInputs=sumOfInputs - maInputs[arrayPosition] + x ;
        maInputs[arrayPosition]=x;
      }
    numInputs++;
    uncorrectedSum+=x;
    expWMA = aweight*expWMA + bweight*x;
  }

  /**
   * Liberador de memoria.
   */
  public void drop()
  {
    super.drop();
  }

}
