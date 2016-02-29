/* =======================================
 * JFreeChart : a Java Chart Class Library
 * =======================================
 *
 * Project Info:  http://www.jrefinery.com/jfreechart
 * Project Lead:  David Gilbert (david.gilbert@jrefinery.com);
 *
 * (C) Copyright 2000-2002, by Simba Management Limited and Contributors.
 *
 * This library is free software; you can redistribute it and/or modify it under the terms
 * of the GNU Lesser General Public License as published by the Free Software Foundation;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License along with this
 * library; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * -------------------------------
 * AxisNotCompatibleException.java
 * -------------------------------
 * (C) Copyright 2000-2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   -;
 *
 * $Id: AxisNotCompatibleException.java,v 1.6 2002/01/29 13:56:20 mungady Exp $
 *
 * Changes (from 21-Aug-2001)
 * --------------------------
 * 21-Aug-2001 : Added standard header. Fixed DOS encoding problem (DG);
 * 18-Sep-2001 : Updated e-mail address in header (DG);
 * 30-Nov-2001 : Now extends RuntimeException rather than Exception, as suggested by Joao Guilherme
 *               Del Valle (DG);
 *
 */

package com.jrefinery.chart;

/**
 * An exception that is generated when assigning an axis to a plot *if* the axis is not compatible
 * with the plot type.  For example, a CategoryAxis is not compatible with an XYPlot.
 * <P>
 * Note:  there is more work to be done on these exceptions.
 */
public class AxisNotCompatibleException extends RuntimeException {

    /**
     * Constructs a new exception.
     * @param msg A message describing the exception.
     */
    public AxisNotCompatibleException(String message) {
	super(message);
    }

}
