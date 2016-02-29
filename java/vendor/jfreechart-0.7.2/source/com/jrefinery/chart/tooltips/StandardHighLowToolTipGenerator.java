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
 * ------------------------------------
 * StandardHighLowToolTipGenerator.java
 * ------------------------------------
 * (C) Copyright 2001, 2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   -;
 *
 * $Id: StandardHighLowToolTipGenerator.java,v 1.1 2002/01/29 14:13:29 mungady Exp $
 *
 * Changes
 * -------
 * 13-Dec-2001 : Version 1 (DG);
 * 16-Jan-2002 : Completed Javadocs (DG);
 *
 */

package com.jrefinery.chart.tooltips;

import com.jrefinery.data.HighLowDataset;

/**
 * A standard tooltip generator for plots that use data from a HighLowDataset.
 */
public class StandardHighLowToolTipGenerator implements HighLowToolTipGenerator {

    /**
     * Generates a tooltip text item for a particular item within a series.
     * @param data The dataset.
     * @param series The series number (zero-based index).
     * @param item The item number (zero-based index).
     */
    public String generateToolTip(HighLowDataset data, int series, int item) {

        String result = null;

        Number high = data.getHighValue(series, item);
        Number low = data.getLowValue(series, item);
        Number open = data.getOpenValue(series, item);
        Number close = data.getCloseValue(series, item);
        Number x = data.getXValue(series, item);

        result = data.getSeriesName(series);
        if (high!=null) result = result + " high="+high.toString();
        if (low!=null) result = result +" low="+low.toString();
        if (open!=null) result = result +" open="+open.toString();
        if (close!=null) result = result +" close="+close.toString();

        return result;

    }

}