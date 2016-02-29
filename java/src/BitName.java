//package asmjava;

/**
 * <p>Title: BitName</p>
 * <p>Description: Esta clase se utiliza para crear la lista de bits que
 * posee el objeto mundo. Cada elemento de esa lista, cada bit, es una instancia
 * de esta clase. Cada bit tiene un nombre y una breve descripci�n.</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Esta clase no implementa m�todos propios.
 * <p>Depto. de Organizaci�n y Gesti�n de Empresas. Universidad de Valladolid</p>
 * @author Jos� Manuel Gal�n & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class BitName {

  /**
   * Nombre del bit
   */
  public String name;
  /**
   * Breve descripci�n
   */
  public String description;

  /**Constructor de la clase
    *
    * @param n Nombre del bit
    * @param d Breve descripci�n
    */
  BitName(String n, String d){
  name = n;
  description = d;
  }
}