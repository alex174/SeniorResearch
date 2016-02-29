// Java ASM application.
// This library is distributed without any warranty; without even the
// implied warranty of merchantability or fitness for a particular
// purpose.  See file COPYING for details and terms of copying.

//package asmjava;

import swarm.Globals;

/**
 * <p>Title: StartASM</p>
 * <p>Description: Esta es la clase principal, que contiene la funci�n main().</p>
 * <p>Copyright: Copyright (c) 2002</p>
 * <p>Depto. de Organizaci�n y Gesti�n de Empresas. Universidad de Valladolid</p>
 * @author Jos� Manuel Gal�n & Luis R. Izquierdo
 * @version 1.0
 *
 */
public class StartASM  {
 /** <p>La funci�n main() ocupa el lugar m�s alto en la jerarqu�a de cualquier
     *  simulaci�n en Swarm. Es en main() donde todo nace. Aqu� es donde
     *  creamos el "Swarm" de mayor nivel o "theTopLevelSwarm", que es una
     *  instancia de la clase ASM<b>ObserverSwarm</b>, como es habitual en
     *  todas las simulaciones de Swarm en modo gr�fico. Un "Swarm" es un objeto
     *  que controla la gesti�n de memoria y el programa de eventos que deber�n
     *  llevarse a cabo en la simulaci�n. La simulaci�n en Swarm necesita de dos
     *  objetos fundamentales: Un Observador (ObserverSwarm) y un Modelo
     *  (ModelSwarm), normalmente contenido en el primero.
     *  Una vez creado el "Swarm" principal (instancia de
     *  ASM<b>ObserverSwarm</b>), le indicamos que cree los objetos (entre los
     *  cuales se encuentra el ASM<b>ModelSwarm</b>), las acciones y que se
     *  active. Finalmente lo ponemos en marcha.</p>
     *  <p>Es importante aclarar dos aspectos de la funci�n main().</p>
     *  <p>En primer lugar, creamos aqu� la instancia de Parameters, que
     *  contiene todos los par�metros de la simulaci�n, aunque no ser�a
     *  necesario hacerlo en main. La raz�n es que as� permitimos que en un
     *  futuro se puedan crear facilidades para introducir par�metros desde
     *  la l�nea de comandos. </p>
     *  <p>En segundo lugar, cabe resaltar que esta primera versi�n del
     *  mercado artificial s�lo admite simulaciones en modo gr�fico, aunque
     *  incluye la posibilidad de escribir a fichero los principales resultados
     *  de la simulaci�n. El modo "batch" puede a�adirse f�cilmete al programa.
     */
    public static void main (String[] args) {
        // Swarm initialization: all Swarm apps must call this first.

        Globals.env.initSwarm ("asm", "2.2", "bug-swarm@swarm.org", args);
        Parameters arguments = new Parameters (Globals.env.globalZone);
        //arguments.init ();

        // swarmGUIMode is set in initSwarm(). It's set to be `false'
        // if you typed `asm --batchmode' or `asm -b'.
        // Otherwise, it's set to `true'.

 ////////////////////////////////////////////////////////////////////////

//      if (Globals.env.guiFlag) {
            // We've got graphics, so make a full ObserverSwarm to get
            // GUI objects
            ASMObserverSwarm theTopLevelSwarm =
                new ASMObserverSwarm (Globals.env.globalZone, arguments);
//     }
        ////////////////////////////////////////////////////////////////////////

/*        else {
            ASMBatchSwarm theTopLevelSwarm =
                (ASMBatchSwarm) Globals.env.lispAppArchiver.getWithZone$key
                (Globals.env.globalZone, "asmBatchSwarm");
        }
*/
        theTopLevelSwarm.buildObjects ();

        theTopLevelSwarm.buildActions ();


        theTopLevelSwarm.activateIn(null);

        theTopLevelSwarm.go();
        (theTopLevelSwarm.getActivity()).drop();
        //theTopLevelSwarm.drop();

        if (!Globals.env.guiFlag) theTopLevelSwarm.expostParamWrite ();
        theTopLevelSwarm.drop ();

        System.exit(0);
      }
}
