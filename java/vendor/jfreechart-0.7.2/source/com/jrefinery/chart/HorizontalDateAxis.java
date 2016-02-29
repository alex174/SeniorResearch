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
 * -----------------------
 * HorizontalDateAxis.java
 * -----------------------
 * (C) Copyright 2000-2002, by Simba Management Limited and Contributors.
 *
 * Original Author:  David Gilbert (for Simba Management Limited);
 * Contributor(s):   David Li;
 *                   Jonathan Nash;
 *
 * $Id: HorizontalDateAxis.java,v 1.9 2002/01/29 13:56:21 mungady Exp $
 *
 * Changes (from 23-Jun-2001)
 * --------------------------
 * 23-Jun-2001 : Modified to work with null data source (DG);
 * 18-Sep-2001 : Updated e-mail address (DG);
 * 07-Nov-2001 : Updated configure() method (DG);
 * 30-Nov-2001 : Cleaned up default values in constructor (DG);
 * 12-Dec-2001 : Grid lines bug fix (DG);
 * 16-Jan-2002 : Added an optional crosshair, based on the implementation by Jonathan Nash (DG);
 *
 */

package com.jrefinery.chart;

import java.awt.*;
import java.awt.font.*;
import java.awt.geom.*;
import java.text.*;
import java.util.*;

/**
 * A horizontal axis that displays date values.  Used in XY plots.
 * @see XYPlot
 */
public class HorizontalDateAxis extends DateAxis implements HorizontalAxis {

    /** A flag indicating whether or not tick labels are drawn vertically. */
    protected boolean verticalTickLabels;

    /**
      * Constructs a horizontal date axis, using default values where necessary.
     */
    public HorizontalDateAxis() {

	this(null,
             Axis.DEFAULT_AXIS_LABEL_FONT,
             Axis.DEFAULT_AXIS_LABEL_PAINT,
             Axis.DEFAULT_AXIS_LABEL_INSETS,
	     true,  // tick labels visible
             Axis.DEFAULT_TICK_LABEL_FONT,
             Axis.DEFAULT_TICK_LABEL_PAINT,
             Axis.DEFAULT_TICK_LABEL_INSETS,
	     true,  // vertical tick labels
             true,  // tick marks visible
             Axis.DEFAULT_TICK_STROKE,
	     true, // auto range off
             null, null,
             true, // auto tick unit selection off
             new DateUnit(Calendar.DATE, 1),
	     new SimpleDateFormat(),
             true,
             ValueAxis.DEFAULT_GRID_LINE_STROKE,
             ValueAxis.DEFAULT_GRID_LINE_PAINT,
             DateAxis.DEFAULT_CROSSHAIR_DATE,
             ValueAxis.DEFAULT_CROSSHAIR_STROKE,
             ValueAxis.DEFAULT_CROSSHAIR_PAINT);

    }

    /**
     * Constructs a horizontal date axis, using default values where necessary.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     */
    public HorizontalDateAxis(String label) {

	this(label,
             Axis.DEFAULT_AXIS_LABEL_FONT,
             Axis.DEFAULT_AXIS_LABEL_PAINT,
             Axis.DEFAULT_AXIS_LABEL_INSETS,
	     true,  // tick labels visible
             Axis.DEFAULT_TICK_LABEL_FONT,
             Axis.DEFAULT_TICK_LABEL_PAINT,
             Axis.DEFAULT_TICK_LABEL_INSETS,
	     false,  // vertical tick labels
             true,  // tick marks visible
             Axis.DEFAULT_TICK_STROKE,
	     true, // auto range off
             null, null,
             true, // auto tick unit selection off
             new DateUnit(Calendar.DATE, 1),
	     new SimpleDateFormat(),
             true,
             ValueAxis.DEFAULT_GRID_LINE_STROKE,
             ValueAxis.DEFAULT_GRID_LINE_PAINT,
             DateAxis.DEFAULT_CROSSHAIR_DATE,
             ValueAxis.DEFAULT_CROSSHAIR_STROKE,
             ValueAxis.DEFAULT_CROSSHAIR_PAINT);

    }

    /**
     * Constructs a horizontal date axis, using default values where necessary.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     * @param minimumDate The earliest date shown on the axis.
     * @param maximumDate The latest date shown on the axis.
     */
    public HorizontalDateAxis(String label, Font labelFont,
			      Date minimumDate, Date maximumDate) {

	this(label,
             labelFont,
             Axis.DEFAULT_AXIS_LABEL_PAINT,
             Axis.DEFAULT_AXIS_LABEL_INSETS,
	     true,  // tick labels visible
             Axis.DEFAULT_TICK_LABEL_FONT,
             Axis.DEFAULT_TICK_LABEL_PAINT,
             Axis.DEFAULT_TICK_LABEL_INSETS,
	     true,  // vertical tick labels
             true,  // tick marks visible
             Axis.DEFAULT_TICK_STROKE,
	     false, // auto range off
             minimumDate, maximumDate,
             true, // auto tick unit selection off
             new DateUnit(Calendar.DATE, 1),
	     new SimpleDateFormat(),
             true,
             ValueAxis.DEFAULT_GRID_LINE_STROKE,
             ValueAxis.DEFAULT_GRID_LINE_PAINT,
             DateAxis.DEFAULT_CROSSHAIR_DATE,
             ValueAxis.DEFAULT_CROSSHAIR_STROKE,
             ValueAxis.DEFAULT_CROSSHAIR_PAINT);

    }

    /**
     * Constructs a horizontal date axis.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     * @param labelPaint The paint used to draw the axis label.
     * @param labelInsets The blank space around the axis label.
     * @param showTickLabels Flag indicating whether or not tick labels are visible.
     * @param tickLabelFont Font for displaying tick labels.
     * @param tickLabelPaint The paint used to display the tick labels.
     * @param tickLabelInsets The blank space around the tick labels.
     * @param verticalTickLabels A flag indicating whether or not tick labels are drawn vertically.
     * @param showTickMarks Flag indicating whether or not tick marks are visible.
     * @param tickMarkStroke The stroke used to draw tick marks (if visible).
     * @param autoScale Flag indicating whether or not the axis is automatically scaled to fit the
     *                  data.
     * @param min The lowest value shown on the axis.
     * @param max The highest value shown on the axis.
     * @param autoUnits A flag indicating whether or not the tick units are automatically
     *                  selected.
     * @param tickUnits The tick units.
     * @param tickLabelFormatter The format object used to display tick labels.
     * @param gridVisible Flag indicating whether or not grid lines are visible for this axis.
     * @param gridStroke The Stroke used to display grid lines (if visible).
     * @param gridPaint The Paint used to display grid lines (if visible).
     * @param crosshairDate The date at which to draw the crosshair line (null permitted).
     * @param crosshairStroke The pen/brush used to draw the data line.
     * @param crosshairPaint The color used to draw the data line.
     */
    public HorizontalDateAxis(String label,
                              Font labelFont, Paint labelPaint, Insets labelInsets,
			      boolean showTickLabels,
                              Font tickLabelFont, Paint tickLabelPaint, Insets tickLabelInsets,
			      boolean verticalTickLabels,
			      boolean showTickMarks, Stroke tickMarkStroke,
			      boolean autoRange, Date minimumDate, Date maximumDate,
			      boolean autoUnits,
                              DateUnit tickUnits, SimpleDateFormat tickLabelFormatter,
			      boolean gridVisible, Stroke gridStroke, Paint gridPaint,
                              Date crosshairDate, Stroke crosshairStroke, Paint crosshairPaint) {

	super(label,
              labelFont, labelPaint, labelInsets,
	      showTickLabels,
              tickLabelFont, tickLabelPaint, tickLabelInsets,
	      showTickMarks, tickMarkStroke,
	      autoRange, minimumDate, maximumDate,
              autoUnits, tickUnits, tickLabelFormatter,
	      gridVisible, gridStroke, gridPaint,
              crosshairDate, crosshairStroke, crosshairPaint);

	this.verticalTickLabels = verticalTickLabels;

    }

    /**
     * Returns a flag indicating whether the tick labels are drawn 'vertically'.
     */
    public boolean getVerticalTickLabels() {
	return this.verticalTickLabels;
    }

    /**
     * Sets the flag that determines whether the tick labels are drawn 'vertically'.
     * @param flag The new value of the flag;
     */
    public void setVerticalTickLabels(boolean flag) {
	this.verticalTickLabels = flag;
	this.notifyListeners(new com.jrefinery.chart.event.AxisChangeEvent(this));
    }

    /**
     * Configures the axis to work with the specified plot.  If the axis has auto-scaling, then sets
     * the maximum and minimum values.
     */
    public void configure() {
	if (isAutoRange()) {
	    this.autoAdjustRange();
	}
    }

    public double translateDateToJava2D(Date date, Rectangle2D dataArea) {
	double value = (double)date.getTime();
	double axisMin = (double)minimumDate.getTime();
	double axisMax = (double)maximumDate.getTime();
	double plotX = dataArea.getX();
	double plotMaxX = dataArea.getMaxX();
	return plotX + ((value - axisMin)/(axisMax - axisMin)) * (plotMaxX - plotX);
    }

    /**
     * Translates the data value to the display coordinates (Java 2D User Space) of the chart.
     * @param date The date to be plotted.
     * @param dataArea The data area in Java 2D User Space.
     */
    public double translateValueToJava2D(double value, Rectangle2D dataArea) {

	double axisMin = (double)minimumDate.getTime();
	double axisMax = (double)maximumDate.getTime();
	double plotX = dataArea.getX();
	double plotMaxX = dataArea.getMaxX();
	return plotX + ((value - axisMin)/(axisMax - axisMin)) * (plotMaxX - plotX);

    }

    public double translateJava2DtoValue(float java2DValue, Rectangle2D dataArea) {

	double axisMin = (double)minimumDate.getTime();
	double axisMax = (double)maximumDate.getTime();
	double plotX = dataArea.getX();
	double plotMaxX = dataArea.getMaxX();
        double result = axisMin + ((java2DValue - plotX)/(plotMaxX - plotX)*(axisMax - axisMin));
        return result;

    }

    /**
     * Rescales the axis to ensure that all data is visible.
     */
    public void autoAdjustRange() {
	if (plot!=null) {
	    if (plot instanceof HorizontalValuePlot) {
		HorizontalValuePlot hvp = (HorizontalValuePlot)plot;

                Number u = hvp.getMaximumHorizontalDataValue();
                long upper = new Date().getTime()+24L*60L*60L*1000L;
                if (u!=null) {
		    upper = u.longValue();
                }

                Number l = hvp.getMinimumHorizontalDataValue();
                long lower = new Date().getTime();
                if (l!=null) {
		    lower = l.longValue();
                }

		long range = upper-lower;
		upper = upper+(range/20);
		lower = lower-(range/20);
		this.minimumDate=new Date(lower);
                this.minimumAxisValue=(double)lower;
		this.maximumDate=new Date(upper);
                this.maximumAxisValue=(double)upper;
	    }
	}
    }

    /**
     * Recalculates the ticks for the date axis.
     */
    public void refreshTicks(Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea) {

	this.ticks.clear();
	g2.setFont(tickLabelFont);
	if (this.autoTickUnitSelection) {
	    calculateAutoTickUnits(g2, drawArea, plotArea);
	}

	Date tickDate = this.calculateLowestVisibleTickValue(tickUnit);
	while (tickDate.before(this.maximumDate)) {
	    // work out the value, label and position
	    double xx = this.translateDateToJava2D(tickDate, plotArea);
	    String tickLabel = this.tickLabelFormatter.format(tickDate);
	    Rectangle2D tickLabelBounds = tickLabelFont.getStringBounds(tickLabel,
									g2.getFontRenderContext());
	    float x = 0.0f;
	    float y = 0.0f;
	    if (this.verticalTickLabels) {
		x = (float)(xx+tickLabelBounds.getHeight()/2);
		y = (float)(plotArea.getMaxY()+tickLabelInsets.top+tickLabelBounds.getWidth());
	    }
	    else {
		x = (float)(xx-tickLabelBounds.getWidth()/2);
		y = (float)(plotArea.getMaxY()+tickLabelInsets.top+tickLabelBounds.getHeight());
	    }
	    Tick tick = new Tick(tickDate, tickLabel, x, y);
	    ticks.add(tick);
	    tickDate = this.tickUnit.addToDate(tickDate);
	}

    }

    /**
     * Draws the plot on a Java 2D graphics device (such as the screen or a printer).
     * @param g2 The graphics device.
     * @param drawArea The area within which the chart should be drawn.
     * @param plotArea The area within which the plot should be drawn (a subset of the drawArea).
     */
    public void draw(Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea) {

	// draw the axis label
	if (this.label!=null) {
	    g2.setFont(labelFont);
	    g2.setPaint(labelPaint);
	    FontRenderContext frc = g2.getFontRenderContext();
	    Rectangle2D labelBounds = labelFont.getStringBounds(label, frc);
	    LineMetrics lm = labelFont.getLineMetrics(label, frc);
	    float labelx = (float)(plotArea.getX()+plotArea.getWidth()/2-labelBounds.getWidth()/2);
	    float labely = (float)(drawArea.getMaxY()-labelInsets.bottom
                                   -lm.getDescent()-lm.getLeading());
	    g2.drawString(label, labelx, labely);
	}

	// draw the tick labels and marks
	this.refreshTicks(g2, drawArea, plotArea);
	float maxY = (float)plotArea.getMaxY();
	g2.setFont(getTickLabelFont());

	Iterator iterator = ticks.iterator();
	while (iterator.hasNext()) {
	    Tick tick = (Tick)iterator.next();
	    float xx = (float)this.translateValueToJava2D(tick.getNumericalValue(), plotArea);

	    if (tickLabelsVisible) {
		g2.setPaint(this.tickLabelPaint);
		if (this.verticalTickLabels) {
		    drawVerticalString(tick.getText(), g2, tick.getX(), tick.getY());
		}
		else {
		    g2.drawString(tick.getText(), tick.getX(), tick.getY());
		}
	    }

	    if (tickMarksVisible) {
		g2.setStroke(this.getTickMarkStroke());
		Line2D mark = new Line2D.Float(xx, maxY-2, xx, maxY+2);
		g2.draw(mark);
	    }

	    if (gridLinesVisible) {
		g2.setStroke(gridStroke);
		g2.setPaint(gridPaint);
		Line2D gridline = new Line2D.Float(xx, (float)plotArea.getMaxY(), xx,
						   (float)plotArea.getMinY());
		g2.draw(gridline);
	    }

	}

    }

    /**
     * Returns the height required to draw the axis in the specified draw area.
     * @param g2 The graphics device;
     * @param plot The plot that the axis belongs to;
     * @param drawArea The area within which the plot should be drawn.
     */
    public double reserveHeight(Graphics2D g2, Plot plot, Rectangle2D drawArea) {

	// calculate the height of the axis label...
	double labelHeight = 0.0;
	if (label!=null) {
	    LineMetrics metrics = labelFont.getLineMetrics(label, g2.getFontRenderContext());
	    labelHeight = this.labelInsets.top+metrics.getHeight()+this.labelInsets.bottom;
	}

	// calculate the height required for the tick labels (if visible);
	double tickLabelHeight = tickLabelInsets.top+tickLabelInsets.bottom;
	if (tickLabelsVisible) {
	    g2.setFont(tickLabelFont);
	    this.refreshTicks(g2, drawArea, drawArea);
	    tickLabelHeight = tickLabelHeight+getMaxTickLabelHeight(g2, drawArea,
								    this.verticalTickLabels);
	}
	return labelHeight+tickLabelHeight;

    }

    /**
     * Returns area in which the axis will be displayed.
     */
    public Rectangle2D reserveAxisArea(Graphics2D g2, Plot plot, Rectangle2D drawArea,
				       double reservedWidth) {

	// calculate the height of the axis label...
	LineMetrics metrics = labelFont.getLineMetrics(label, g2.getFontRenderContext());
	double labelHeight = this.labelInsets.top+metrics.getHeight()+this.labelInsets.bottom;

	// calculate the height required for the tick labels (if visible);
	double tickLabelHeight = tickLabelInsets.top+tickLabelInsets.bottom;
	if (tickLabelsVisible) {
	    g2.setFont(tickLabelFont);
	    this.refreshTicks(g2, drawArea, drawArea);
	    tickLabelHeight = tickLabelHeight+getMaxTickLabelHeight(g2, drawArea,
								    this.verticalTickLabels);
	}

	return new Rectangle2D.Double(drawArea.getX(), drawArea.getMaxY(),
				      drawArea.getWidth()-reservedWidth,
				      labelHeight+tickLabelHeight);

    }

    /**
     * Determines an appropriate tick value for the axis...
     */
    private void calculateAutoTickUnits(Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea) {

	// find the index of the largest standard tick magnitude that fits into the axis range
	int index = this.findAxisMagnitudeIndex();
	boolean labelsFit = true;
	while (labelsFit && index>0) {
	    index=index-1;
	    labelsFit = tickLabelsFit(index, g2, drawArea, plotArea);
	}

	if (labelsFit) {
	    this.autoTickIndex=index;
	}
	else {
	    this.autoTickIndex=Math.min(index+1, this.standardTickUnitMagnitudes.length);
	}

	this.tickLabelFormatter.applyPattern(this.standardTickFormats[autoTickIndex]);
	this.tickUnit = new DateUnit(this.standardTickUnits[autoTickIndex][0],
				     this.standardTickUnits[autoTickIndex][1]);

	// there are two special cases to handle
	// (1) the highest index doesn't fit, but there is no "next one up" to use;
	// (2) the lowest index DOES fit, so we should use it rather than the next one up
	// otherwise, step up one index and use it
    }

    /**
     * Determines whether or not the tick labels fit given the available space.
     */
    private boolean tickLabelsFit(int index,
				  Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea) {

	// generate one label at a time until all are done OR there is an overlap (so fit==FALSE)
	SimpleDateFormat dateFormatter = new SimpleDateFormat(standardTickFormats[index]);
	DateUnit units = new DateUnit(this.standardTickUnits[index][0],
                                      this.standardTickUnits[index][1]);
	double lastLabelExtent = Double.NEGATIVE_INFINITY;
	double labelExtent;
	boolean labelsFit = true;
	Date tickDate = this.calculateLowestVisibleTickValue(units);
	while (tickDate.before(this.maximumDate) && labelsFit) {
	    double xx = this.translateDateToJava2D(tickDate, plotArea);
	    String tickLabel = dateFormatter.format(tickDate);
	    Rectangle2D tickLabelBounds = tickLabelFont.getStringBounds(tickLabel,
									g2.getFontRenderContext());
	    if (this.verticalTickLabels) {
		labelExtent = xx-(tickLabelBounds.getHeight()/2);
		if (labelExtent<lastLabelExtent) labelsFit = false;
		lastLabelExtent = xx+(tickLabelBounds.getHeight()/2);
	    }
	    else {
		labelExtent = xx-(tickLabelBounds.getWidth()/2);
		if (labelExtent<lastLabelExtent) labelsFit = false;
		lastLabelExtent = xx+(tickLabelBounds.getWidth()/2);
	    }
	    tickDate = units.addToDate(tickDate);
	}

	return labelsFit;

    }

    /**
     * A utility method for determining the height of the tallest tick label.
     */
    private double getMaxTickLabelHeight(Graphics2D g2, Rectangle2D drawArea, boolean vertical) {
	Font font = getTickLabelFont();
	g2.setFont(font);
	FontRenderContext frc = g2.getFontRenderContext();
	double maxHeight = 0.0;
	if (vertical) {
	    Iterator iterator = this.ticks.iterator();
	    while (iterator.hasNext()) {
		Tick tick = (Tick)iterator.next();
		Rectangle2D labelBounds = font.getStringBounds(tick.getText(), frc);
		if (labelBounds.getWidth()>maxHeight) {
		    maxHeight = labelBounds.getWidth();
		}
	    }
	}
	else {
	    LineMetrics metrics = font.getLineMetrics("Sample", frc);
	    maxHeight = metrics.getHeight();
	}
	return maxHeight;
    }

    /**
     * Returns true if the specified plot is compatible with the axis, and false otherwise.
     *
     * The HorizontalDateAxis class expects the plot to implement the HorizontalValuePlot interface.
     * @param plot The plot;
     */
    protected boolean isCompatiblePlot(Plot plot) {
        if (plot instanceof HorizontalValuePlot) return true;
        else return false;
    }

}
