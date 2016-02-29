import swarm.objectbase.SwarmObjectImpl;
import swarm.Globals;
import swarm.defobj.Zone;

import com.jrefinery.chart.JFreeChart;
import com.jrefinery.chart.JFreeChartFrame;
import com.jrefinery.chart.ChartFactory;
import com.jrefinery.data.DefaultCategoryDataset;

import java.util.LinkedList;


/**
 * <p>Title: BarChart</p>
 * <p>Description: Esta es la clase encargada de crear los diagramas de barras.
 * Lo cierto es que está en un estado bastante precario, aunque funciona
 * correctamente. Los diagramas de barras no se han podido implementar como
 * en versiones anteriores porque el método drawHistogramWithDouble() no está
 * disponible para Java. En esas versiones se llama histogramas a los diagramas
 * de barras, lo que puede traer más de una confusión.</p>
 * <p>Decimos que está en un estado bastante precario por dos razones. La
 * primera es que es necesario hacer uso de algunas librerías externas
 * adicionales. La segunda es porque una única instancia de esta clase genera
 * los dos diagramas, reduciendo así las ventajas derivadas de la programación
 * orientada a objetos. Arreglar esto llevaría poquísimo tiempo, pero ahora no
 * lo tenemos.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organización y Gestión de Empresas. Universidad de Valladolid</p>
 * @author José Manuel Galán & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class BarChart extends SwarmObjectImpl {

  /**
   * Diagrama de barras en el que se representa la posición de los agentes
   */
  public JFreeChart positionChart;/*"Chart showing amount of stock held by each individual agent"*/

  /**
   * Objeto que contiene los datos a representar en el diagrama de barras
   *  en el que se representa la posición de los agentes
   */
  public DefaultCategoryDataset positionData;

  /**
   * Marco para el diagrama de barras en el que se representa
   * la posición de los agentes
   */
  public JFreeChartFrame positionFrame;

  /**
   * Diagrama de barras en el que se representa la riqueza relativa de los agentes
   */
  public JFreeChart relativeWealthChart;/*"Chart showing wealth of agents"*/
  /**
   * Objeto que contiene los datos a representar en el diagrama de barras
   *  en el que se representa la riqueza relativa de los agentes
   */
  public DefaultCategoryDataset relativeWealthData;

  /**
   * Marco para el diagrama de barras en el que se representa
   * la riqueza relativa de los agentes
   */
  public JFreeChartFrame relativeWealthFrame;

  public JFreeChart divisorChart;
  public DefaultCategoryDataset divisorData;
  public JFreeChartFrame divisorFrame;

  /**
   * Lista enlazada de agentes
   */
  public LinkedList agentList = new LinkedList();

  /**
   * Número de agentes
   */
  public int numagents;

  /**Número de unidades de efectivo que tiene cada agente al comenzar la simulación */
  public double initialCash;


  /**Constructor: Construye los dos diagramas de barras.
    *
    * @param list Lista enlazada de agentes
    * @param initCash Número de unidades de efectivo que tiene cada agente al comenzar la simulación
    * @param aZone Zona de memoria Swarm en la que se aloja el objeto Swarm
    */
  BarChart(LinkedList list,double initCash, Zone aZone){

    super(aZone);
    agentList = list;
    initialCash = initCash;
    numagents = agentList.size();

    String numbers[] = new String[numagents];
    for (int i = 0;i<numagents;i++)
      {
      Integer a = new Integer(i+1);
      numbers[i]= a.toString();
      }

    String asm[] = new String[1];
    asm[0]= new String("ASM");

    Double positionFirst[][] = new Double[1][numagents];
    Double relativeWealthFirst[][] = new Double[1][numagents];
    Double divisorFirst[][] = new Double[1][numagents];

    positionData = new DefaultCategoryDataset(asm,numbers,positionFirst);
    positionChart = ChartFactory.createVerticalBarChart3D("POSICION DE LOS AGENTES","Agentes","Posicion",positionData,true);

    positionFrame = new JFreeChartFrame("Posicion de los agentes", positionChart);
    positionFrame.pack();
    positionFrame.setVisible(true);

    relativeWealthData = new DefaultCategoryDataset(asm,numbers,relativeWealthFirst);
    relativeWealthChart = ChartFactory.createVerticalBarChart3D("RIQUEZA RELATIVA DE LOS AGENTES","Agentes","Riqueza relativa",relativeWealthData,true);

    relativeWealthFrame = new JFreeChartFrame("Riqueza relativa de los agentes", relativeWealthChart);
    relativeWealthFrame.pack();
    relativeWealthFrame.setVisible(true);

    divisorData = new DefaultCategoryDataset(asm,numbers,divisorFirst);
    divisorChart = ChartFactory.createVerticalBarChart3D("MEDIA MÓVIL DEL ERROR DE LA REGLA USADA","Agentes","Error",divisorData,true);

    divisorFrame = new JFreeChartFrame("Media móvil del error de la regla usada", divisorChart);
    divisorFrame.pack();
    divisorFrame.setVisible(true);
  }


  /*" This method gathers data about the agents, puts it into arrays,
    and then passes those arrays to the histogram objects. As soon as we
    tell the histograms to draw themselves, we will see the result"*/

    /**
     * Actualiza el contenido de los dos diagramas de barras.
     */
  public Object _updateCharts_ ()
  {
    BFagent agent;
    int i;

    for(i=0; i < numagents; i++)
      {
        agent = (BFagent)agentList.get(i);
        Integer a = new Integer(i+1);

        positionData.setValue(0,a.toString(),new Double(agent.getAgentPosition ()));
        relativeWealthData.setValue(0,a.toString(),new Double(agent.getWealth()/initialCash));
        divisorData.setValue(0,a.toString(),new Double(agent.getError()));
      }

    positionChart.setDataset(positionData);
    relativeWealthChart.setDataset(relativeWealthData);
    divisorChart.setDataset(divisorData);
    /////////////////////////////////////////////////


    return this;
  }


  /**
   * Cierra las ventanas cuando la simulación ha terminado.
   */
    public void drop () {

    positionFrame.dispose();
    relativeWealthFrame.dispose();
    super.drop ();

  }

}