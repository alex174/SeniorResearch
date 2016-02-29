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
 * ValueAxis.java
 * --------------
 * (C) Copyright 2000-2002, by Simba Management Limited and Contributors.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   Jonathan Nash;
 *
 * $Id: ValueAxis.java,v 1.9 2002/01/29 13:56:21 mungady Exp $
 *
 * Changes (from 18-Sep-2001)
 * --------------------------
 * 18-Sep-2001 : Added standard header and fixed DOS encoding problem (DG);
 * 23-Nov-2001 : Overhauled standard tick unit code (DG);
 * 04-Dec-2001 : Changed constructors to protected, and tidied up default values (DG);
 * 12-Dec-2001 : Fixed vertical gridlines bug (DG);
 * 16-Jan-2002 : Added an optional crosshair, based on the implementation by Jonathan Nash (DG);
 * 23-Jan-2002 : Moved the minimum and maximum values to here from NumberAxis, and changed the type
 *               from Number to double (DG);
 *
 */

package com.jrefinery.chart;

import java.awt.*;
import java.awt.event.*;
import java.awt.geom.*;
import java.text.*;
import javax.swing.*;
import com.jrefinery.chart.event.*;

/**
 * The base class for axes that display value data (a "value" can be a Number or a Date).
 */
public abstract class ValueAxis extends Axis {

    /** The default minimum axis value. */
    public static final double DEFAULT_MINIMUM_AXIS_VALUE = 0.0;

    /** The default maximum axis value. */
    public static final double DEFAULT_MAXIMUM_AXIS_VALUE = 1.0;

    /** The default grid line stroke. */
    public static final Stroke DEFAULT_GRID_LINE_STROKE = new BasicStroke(0.5f,
                                                                          BasicStroke.CAP_BUTT,
					                                  BasicStroke.JOIN_BEVEL,
                                                                          0.0f,
					                                  new float[] {2.0f, 2.0f},
                                                                          0.0f);

    /** The default grid line paint. */
    public static final Paint DEFAULT_GRID_LINE_PAINT = Color.gray;

    /** The default crosshair stroke. */
    public static final Stroke DEFAULT_CROSSHAIR_STROKE = DEFAULT_GRID_LINE_STROKE;

    /** The default crosshair paint. */
    public static final Paint DEFAULT_CROSSHAIR_PAINT = Color.blue;

    /** Flag that indicates whether or not the axis automatically scales to fit the chart data. */
    protected boolean autoRange;

    /** The lowest value showing on the axis. */
    protected double minimumAxisValue;

    /** The highest value showing on the axis. */
    protected double maximumAxisValue;

    /** Flag that indicates whether or not the tick unit is selected automatically. */
    protected boolean autoTickUnitSelection;

    /** An index into an array of standard tick values. */
    protected int autoTickIndex;

    /** Flag that indicates whether or not grid lines are visible. */
    protected boolean gridLinesVisible;

    /** The stroke used to draw grid lines. */
    protected Stroke gridStroke;

    /** The paint used to draw grid lines. */
    protected Paint gridPaint;

    /** The anchor value for this axis. */
    protected double anchorValue;

    /** A flag that controls whether or not a crosshair is drawn for this axis. */
    protected boolean crosshairVisible = true;

    /** A flag that controls whether or not the crosshair locks onto actual data points. */
    protected boolean crosshairLockedOnData = true;

    /** The crosshair value for this axis. */
    protected double crosshairValue;

    /** The pen/brush used to draw the crosshair (if any). */
    protected Stroke crosshairStroke;

    /** The color used to draw the crosshair (if any). */
    protected Paint crosshairPaint;

    /**
     * Constructs a value axis, using default values where necessary.
     * @param label The axis label.
     */
    public ValueAxis(String label) {

	this(label,
             Axis.DEFAULT_AXIS_LABEL_FONT,
             Axis.DEFAULT_AXIS_LABEL_PAINT,
             Axis.DEFAULT_AXIS_LABEL_INSETS,
             true, // tick labels visible
             Axis.DEFAULT_TICK_LABEL_FONT,
             Axis.DEFAULT_TICK_LABEL_PAINT,
             Axis.DEFAULT_TICK_LABEL_INSETS,
             true, // tick marks visible
             Axis.DEFAULT_TICK_STROKE,
             true, // auto range
             true, // auto tick unit
             true, // show grid lines
             ValueAxis.DEFAULT_GRID_LINE_STROKE,
             ValueAxis.DEFAULT_GRID_LINE_PAINT,
             0.0,  // crosshair
             ValueAxis.DEFAULT_CROSSHAIR_STROKE,
             ValueAxis.DEFAULT_CROSSHAIR_PAINT);

    }

    /**
     * Constructs a value axis.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     * @param labelPaint The paint used to draw the axis label.
     * @param labelInsets Determines the amount of blank space around the label.
     * @param tickLabelsVisible Flag indicating whether or not the tick labels are visible.
     * @param tickLabelFont The font used to display tick labels.
     * @param tickLabelPaint The paint used to draw tick labels.
     * @param tickLabelInsets Determines the amount of blank space around tick labels.
     * @param tickMarksVisible Flag indicating whether or not the tick marks are visible.
     * @param tickMarkStroke The stroke used to draw tick marks (if visible).
     * @param autoRange Flag indicating whether or not the axis range is automatically adjusted to
     *                  fit the data.
     * @param autoTickUnitSelection A flag indicating whether or not the tick unit is automatically
     *                              selected.
     * @param gridLinesVisible Flag indicating whether or not grid lines are visible.
     * @param gridStroke The Stroke used to display grid lines (if visible).
     * @param gridPaint The Paint used to display grid lines (if visible).
     * @param crosshairValue The value at which to draw an optional crosshair (null permitted).
     * @param crosshairStroke The pen/brush used to draw the crosshair.
     * @param crosshairPaint The color used to draw the crosshair.
     */
    protected ValueAxis(String label,
                        Font labelFont, Paint labelPaint, Insets labelInsets,
		        boolean tickLabelsVisible,
                        Font tickLabelFont, Paint tickLabelPaint, Insets tickLabelInsets,
		        boolean tickMarksVisible, Stroke tickMarkStroke,
		        boolean autoRange, boolean autoTickUnitSelection,
		        boolean gridLinesVisible, Stroke gridStroke, Paint gridPaint,
                        double crosshairValue,
                        Stroke crosshairStroke, Paint crosshairPaint) {

	super(label,
              labelFont, labelPaint, labelInsets,
	      tickLabelsVisible,
              tickLabelFont, tickLabelPaint, tickLabelInsets,
	      tickMarksVisible, tickMarkStroke);

	this.autoRange = autoRange;
	this.autoTickUnitSelection = autoTickUnitSelection;
	this.gridLinesVisible = gridLinesVisible;
	this.gridStroke = gridStroke;
	this.gridPaint = gridPaint;
        this.crosshairValue = crosshairValue;
        this.crosshairStroke = crosshairStroke;
        this.crosshairPaint = crosshairPaint;

    }

    /**
     * Returns true if the axis range is automatically adjusted to fit the data, and false
     * otherwise.
     */
    public boolean isAutoRange() {
	return autoRange;
    }

    /**
     * Sets a flag that determines whether or not the axis range is automatically adjusted to fit
     * the data, and notifies registered listeners that the axis has been modified.
     * @param auto Flag indicating whether or not the axis is automatically scaled to fit the data.
     */
    public void setAutoRange(boolean auto) {

	if (this.autoRange!=auto) {
	    this.autoRange=auto;
	    if (autoRange) autoAdjustRange();
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the minimum value for the axis.
     * @return The minimum value for the axis.
     */
    public double getMinimumAxisValue() {
	return minimumAxisValue;
    }

    /**
     * Sets the minimum value for the axis.
     * <P>
     * Registered listeners are notified that the axis has been modified.
     * @param value The new minimum.
     */
    public void setMinimumAxisValue(double value) {

	if (this.minimumAxisValue!=value) {
	    this.minimumAxisValue = value;
            this.autoRange = false;
            notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Returns the maximum value for the axis.
     */
    public double getMaximumAxisValue() {
	return maximumAxisValue;
    }

    /**
     * Sets the maximum value for the axis.
     * <P>
     * Registered listeners are notified that the axis has been modified.
     * @param value The new maximum.
     */
    public void setMaximumAxisValue(double value) {

	if (this.maximumAxisValue!=value) {
	    this.maximumAxisValue = value;
            this.autoRange = false;
            notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Sets the axis range.
     * @param lower The lower axis limit.
     * @param upper The upper axis limit.
     */
    public void setAxisRange(double lower, double upper) {

        this.autoRange = false;
        this.minimumAxisValue = lower;
        this.maximumAxisValue = upper;
        notifyListeners(new AxisChangeEvent(this));

    }

    /**
     * Returns a flag indicating whether or not the tick unit is automatically selected from a
     * range of standard tick units.
     * @return A flag indicating whether or not the tick unit is automatically selected.
     */
    public boolean isAutoTickUnitSelection() {
	return autoTickUnitSelection;
    }

    /**
     * Sets a flag indicating whether or not the tick unit is automatically selected from a
     * range of standard tick units.
     * <P>
     * Registered listeners are notified of a change to the axis.
     * @param flag The new value of the flag.
     */
    public void setAutoTickUnitSelection(boolean flag) {

        if (this.autoTickUnitSelection!=flag) {
            this.autoTickUnitSelection = flag;
	    notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Returns true if the grid lines are showing, and false otherwise.
     * @return True if the grid lines are showing, and false otherwise.
     */
    public boolean isGridLinesVisible() {
	return gridLinesVisible;
    }

    /**
     * Sets the visibility of the grid lines and notifies registered listeners that the axis has
     * been modified.
     * @param flag The new setting.
     */
    public void setGridLinesVisible(boolean flag) {

        if (gridLinesVisible!=flag) {
            gridLinesVisible = flag;
	    notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Returns the Stroke used to draw the grid lines (if visible).
     */
    public Stroke getGridStroke() {
	return gridStroke;
    }

    /**
     * Sets the Stroke used to draw the grid lines (if visible) and notifies registered listeners
     * that the axis has been modified.
     * @param stroke The new grid line stroke.
     */
    public void setGridStroke(Stroke stroke) {

        // check arguments...
        if (stroke==null) {
            throw new IllegalArgumentException("ValueAxis.setGridStroke(...): null not permitted");
        }

        // make the change...
        gridStroke = stroke;
	notifyListeners(new AxisChangeEvent(this));

    }

    /**
     * Returns the grid line color.
     * @return The grid line color.
     */
    public Paint getGridPaint() {
	return gridPaint;
    }

    /**
     * Sets the Paint used to color the grid lines (if visible) and notifies registered listeners
     * that the axis has been modified.
     * @param paint The new grid paint.
     */
    public void setGridPaint(Paint paint) {

        // check arguments...
        if (paint==null) {
            throw new IllegalArgumentException("ValueAxis.setGridPaint(...): null not permitted");
        }
	gridPaint = paint;
	notifyListeners(new AxisChangeEvent(this));
    }

    /**
     * Returns the anchor value for this axis.
     */
    public double getAnchorValue() {
        return anchorValue;
    }

    /**
     * Sets the anchor value for this axis.
     */
    public void setAnchorValue(double value) {
        this.anchorValue = value;
        notifyListeners(new AxisChangeEvent(this));
    }

    /**
     * Returns a flag indicating whether or not a crosshair is visible for this axis.
     */
    public boolean isCrosshairVisible() {
        return this.crosshairVisible;
    }

    /**
     * Sets the flag indicating whether or not a crosshair is visible for this axis.
     * @param flag The new value of the flag.
     */
    public void setCrosshairVisible(boolean flag) {

        if (this.crosshairVisible!=flag) {
            this.crosshairVisible=flag;
            notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Returns a flag indicating whether or not the crosshair should "lock-on" to actual data
     * values.
     */
    public boolean isCrosshairLockedOnData() {
        return this.crosshairLockedOnData;
    }

    /**
     * Sets the flag indicating whether or not the crosshair should "lock-on" to actual data
     * values.
     */
    public void setCrosshairLockedOnData(boolean flag) {

        if (this.crosshairLockedOnData!=flag) {
            this.crosshairLockedOnData=flag;
            notifyListeners(new AxisChangeEvent(this));
        }

    }

    /**
     * Returns the crosshair value.
     */
    public double getCrosshairValue() {
        return this.crosshairValue;
    }

    /**
     * Sets the crosshair value for the axis.
     * <P>
     * Registered listeners are notified that the axis has been modified.
     * @param value The new value (null permitted).
     */
    public void setCrosshairValue(double value) {

        this.crosshairValue = value;
        notifyListeners(new AxisChangeEvent(this));

    }

    /**
     * Returns the Stroke used to draw the crosshair (if visible).
     */
    public Stroke getCrosshairStroke() {
	return crosshairStroke;
    }

    /**
     * Sets the Stroke used to draw the grid lines (if visible) and notifies registered listeners
     * that the axis has been modified.
     * @param stroke The new grid line stroke.
     */
    public void setCrosshairStroke(Stroke stroke) {
	crosshairStroke = stroke;
	notifyListeners(new AxisChangeEvent(this));
    }

    /**
     * Returns the grid line color.
     * @return The grid line color.
     */
    public Paint getCrosshairPaint() {
	return crosshairPaint;
    }

    /**
     * Sets the Paint used to color the grid lines (if visible) and notifies registered listeners
     * that the axis has been modified.
     * @param paint The new grid paint.
     */
    public void setCrosshairPaint(Paint paint) {
	crosshairPaint = paint;
	notifyListeners(new AxisChangeEvent(this));
    }

    /**
     * Converts a value from the dataset to a Java2D user-space co-ordinate relative to the
     * specified plotArea.  The coordinate will be an x-value for horizontal axes and a y-value
     * for vertical axes (refer to the subclass).
     * <p>
     * Note that it is possible for the coordinate to fall outside the plotArea.
     */
    public abstract double translateValueToJava2D(double dataValue, Rectangle2D plotArea);
    public abstract double translateJava2DtoValue(float java2DValue, Rectangle2D plotArea);

    /**
     * Automatically determines the maximum and minimum values on the axis to 'fit' the data.
     */
    public abstract void autoAdjustRange();

    public void setAnchoredRange(double range) {
        double min = this.anchorValue - range/2;
        double max = this.anchorValue + range/2;
        this.setAxisRange(min, max);
    }

}
