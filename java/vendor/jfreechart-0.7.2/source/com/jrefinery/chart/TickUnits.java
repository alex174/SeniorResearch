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
 * --------------
 * TickUnits.java
 * --------------
 * (C) Copyright 2001, 2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   -;
 *
 * $Id: TickUnits.java,v 1.2 2002/01/29 13:56:21 mungady Exp $
 *
 * Changes
 * -------
 * 23-Nov-2001 : Version 1 (DG);
 *
 */

package com.jrefinery.chart;

import java.util.*;

/**
 * A collection of tick units.
 */
public class TickUnits {

    /** Storage for the tick units. */
    protected List units;

    /**
     * Constructs a new collection of tick units.
     */
    public TickUnits() {
        this.units = new ArrayList();
    }

    /**
     * Adds a tick unit to the collection.
     * <P>
     * The tick units are maintained in ascending order.
     */
    public void add(TickUnit unit) {

        units.add(unit);
        Collections.sort(units);

    }

    /**
     * Returns the tick unit in the collection that is closest in size to the specified unit.
     * @param unit The unit.
     * @returns The unit in the collection that is closest in size to the specified unit.
     */
    public TickUnit getNearestTickUnit(TickUnit unit) {

        int index = Collections.binarySearch(units, unit);
        if (index>=0) {
            return (TickUnit)units.get(index);
        }
        else {
            index = -(index + 1);
            return (TickUnit)units.get(Math.min(index, units.size()));
        }

    }

    /**
     * Finds the tick unit that is closest to the specified value.
     */
    public TickUnit getNearestTickUnit(Number value) {

        return this.getNearestTickUnit(new NumberTickUnit(value, null));

    }

}