/* =======================================
 * JFreeChart : a Java Chart Class Library
 * =======================================
 *
 * Project Info:  http://www.jrefinery.com/jfreechart;
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
 * -----------------------
 * ToolTipsCollection.java
 * -----------------------
 * (C) Copyright 2001, 2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   -;
 *
 * $Id: ToolTipsCollection.java,v 1.1 2002/01/29 14:13:29 mungady Exp $
 *
 * Changes
 * -------
 * 13-Dec-2001 : Version 1 (DG);
 * 16-Jan-2002 : Completed Javadocs (DG);
 *
 */

package com.jrefinery.chart.tooltips;

import java.awt.Shape;

/**
 * Defines the methods that a tooltip manager should implement.
 * <P>
 * The StandardToolTipsCollection class provides one implementation of this interface.
 */
public interface ToolTipsCollection {

    /**
     * Clears all tooltips.
     */
    public void clearToolTips();

    /**
     * Adds a tooltip for the specified area.
     * @param text The tooltip text.
     * @param area The area that the tooltip is relevant to.
     */
    public void addToolTip(String text, Shape area);

    /**
     * Returns a tooltip for the specified coordinates.
     * @param x The x coordinate.
     * @param y The y coordinate.
     * @return The tooltip text.
     */
    public String getToolTipText(double x, double y);

}