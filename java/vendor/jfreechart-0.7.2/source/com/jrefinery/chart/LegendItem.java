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
 * ---------------
 * LegendItem.java
 * ---------------
 * (C) Copyright 2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   -;
 *
 * $Id$
 *
 * Changes
 * -------
 * 07-Feb-2002 : Version 1. INCOMPLETE, PLEASE IGNORE. (DG);
 *
 */

package com.jrefinery.chart;

import java.awt.Graphics2D;
import java.awt.Shape;
import java.awt.geom.Point2D;

/**
 * Represents a single item within a legend.
 */
public class LegendItem {

    /** The label (usually a series name). */
    protected String label;

    /** The x-coordinate for the item's location. */
    protected double x;

    /** The y-coordinate for the item's location. */
    protected double y;

    /** The width of the item. */
    protected double width;

    /** The height of the item. */
    protected double height;

    /** A shape used to indicate color on the legend. */
    protected Shape marker;

    /** The label position within the item. */
    protected Point2D labelPosition;


    /**
     * Create a legend item.
     */
    public LegendItem(String label) {
        super();
        this.label = label;
    }

    public double getX() {
        return this.x;
    }

    public void setX(double x) {
        this.x = x;
    }

    public double getY() {
        return this.y;
    }

    public void setY(double y) {
        this.y = y;
    }

    public double getWidth() {
        return this.width;
    }

    public double getHeight() {
        return this.height;
    }

    public Shape getMarker() {
        return this.marker;
    }

    public void setMarker(Shape marker) {
        this.marker = marker;
    }

    public void setBounds(double x, double y, double width, double height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    public void draw(Graphics2D g2, double xOffset, double yOffset) {
        // set up a translation on g2

        // restore original g2
    }

}
