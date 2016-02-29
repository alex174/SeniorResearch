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
 * -----------------
 * CategoryAxis.java
 * -----------------
 * (C) Copyright 2000-2002, by Simba Management Limited.
 *
 * Original Author:  David Gilbert;
 * Contributor(s):   -;
 *
 * $Id: CategoryAxis.java,v 1.6 2002/01/29 13:56:20 mungady Exp $
 *
 * Changes (from 21-Aug-2001)
 * --------------------------
 * 21-Aug-2001 : Added standard header. Fixed DOS encoding problem (DG);
 * 18-Sep-2001 : Updated e-mail address in header (DG);
 * 04-Dec-2001 : Changed constructors to protected, and tidied up default values (DG);
 *
 */

package com.jrefinery.chart;

import java.awt.*;
import java.awt.font.*;
import java.awt.geom.*;
import java.util.*;

/**
 * An axis that displays categories.
 * <P>
 * Used for bar charts and line charts.
 * <P>
 * The axis needs to rely on the plot for placement of labels, since the plot controls how the
 * categories are distributed.
 */
public abstract class CategoryAxis extends Axis {

    /**
     * Constructs a category axis.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     * @param labelPaint The paint used to draw the axis label.
     * @param labelInsets Determines the amount of blank space around the label.
     * @param categoryLabelsVisible Flag indicating whether or not category labels are visible.
     * @param categoryLabelFont The font used to display category (tick) labels.
     * @param categoryLabelPaint The paint used to draw category (tick) labels.
     * @param categoryLabelInsets The insets for the category labels.
     * @param tickMarksVisible Flag indicating whether or not tick marks are visible.
     * @param tickMarkStroke The stroke used to draw tick marks (if visible).
     */
    protected CategoryAxis(String label,
                           Font labelFont, Paint labelPaint, Insets labelInsets,
			   boolean categoryLabelsVisible,
                           Font categoryLabelFont, Paint categoryLabelPaint,
                           Insets categoryLabelInsets,
                           boolean tickMarksVisible,
                           Stroke tickMarkStroke) {

	super(label,
              labelFont, labelPaint, labelInsets,
	      categoryLabelsVisible,
              categoryLabelFont, categoryLabelPaint, categoryLabelInsets,
	      tickMarksVisible,
              tickMarkStroke);

    }

    /**
     * Constructs a category axis, using default values where necessary.
     * @param label The axis label.
     */
    protected CategoryAxis(String label) {

	this(label,
             Axis.DEFAULT_AXIS_LABEL_FONT,
             Axis.DEFAULT_AXIS_LABEL_PAINT,
             Axis.DEFAULT_AXIS_LABEL_INSETS,
             true, // category labels visible
             Axis.DEFAULT_TICK_LABEL_FONT,
             Axis.DEFAULT_TICK_LABEL_PAINT,
             Axis.DEFAULT_TICK_LABEL_INSETS,
             false, // tick marks visible (not supported anyway)
             Axis.DEFAULT_TICK_STROKE);

    }

}
