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
 * ---------
 * Axis.java
 * ---------
 * (C) Copyright 2000-2002, by Simba Management Limited and Contributors.
 *
 * Original Author:  David Gilbert;
 * Contributor(s):   Bill Kelemen;
 *
 * $Id: Axis.java,v 1.12 2002/01/29 13:56:20 mungady Exp $
 *
 * Changes (from 21-Aug-2001)
 * --------------------------
 * 21-Aug-2001 : Added standard header, fixed DOS encoding problem (DG);
 * 18-Sep-2001 : Updated e-mail address in header (DG);
 * 07-Nov-2001 : Allow null axis labels (DG);
 *             : Added default font values (DG);
 * 13-Nov-2001 : Modified the setPlot(...) method to check compatibility between the axis and the
 *               plot (DG);
 * 30-Nov-2001 : Changed default font from "Arial" --> "SansSerif" (DG);
 * 06-Dec-2001 : Allow null in setPlot(...) method (BK);
 *
 */

package com.jrefinery.chart;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.Paint;
import java.awt.Insets;
import java.awt.Stroke;
import java.awt.BasicStroke;
import java.awt.font.FontRenderContext;
import java.awt.geom.AffineTransform;
import java.awt.geom.Rectangle2D;
import java.util.Iterator;
import com.jrefinery.chart.event.*;

/**
 * The base class for all axes used by JFreeChart.
 * @see CategoryAxis
 * @see ValueAxis
 */
public abstract class Axis {

    /** The default axis label font. */
    public static final Font DEFAULT_AXIS_LABEL_FONT = new Font("SansSerif", Font.PLAIN, 12);

    /** The default axis label paint. */
    public static final Paint DEFAULT_AXIS_LABEL_PAINT = Color.black;

    /** The default axis label insets. */
    public static final Insets DEFAULT_AXIS_LABEL_INSETS = new Insets(2, 2, 2, 2);

    /** The default tick label font. */
    public static final Font DEFAULT_TICK_LABEL_FONT = new Font("SansSerif", Font.PLAIN, 10);

    /** The default tick label paint. */
    public static final Paint DEFAULT_TICK_LABEL_PAINT = Color.black;

    /** The default tick stroke. */
    public static final Stroke DEFAULT_TICK_STROKE = new BasicStroke(1);

    /** The default tick label insets. */
    public static final Insets DEFAULT_TICK_LABEL_INSETS = new Insets(2, 1, 2, 1);

    /** A reference back to the plot that the axis is currently assigned to (can be null if the axis
	hasn't been assigned yet). */
    protected Plot plot;

    /** The label for the axis. */
    protected String label;

    /** The font for displaying the axis label. */
    protected Font labelFont;

    /** The paint for drawing the axis label. */
    protected Paint labelPaint;

    /** The insets for the axis label. */
    protected Insets labelInsets;

    /** A flag that indicates whether or not tick labels are visible for the axis. */
    protected boolean tickLabelsVisible;

    /** The font used to display the tick labels. */
    protected Font tickLabelFont;

    /** The color used to display the tick labels. */
    protected Paint tickLabelPaint;

    /** The blank space around each tick label. */
    protected Insets tickLabelInsets;

    /** A flag that indicates whether or not tick marks are visible for the axis. */
    protected boolean tickMarksVisible;

    /** The line type used to draw tick marks. */
    protected Stroke tickMarkStroke;

    /** A working list of ticks - this list is refreshed as required. */
    protected java.util.List ticks;

    /** Storage for registered listeners (objects interested in receiving change events for the
	axis). */
    protected java.util.List listeners;

    /**
     * Constructs an axis, using default values where necessary.
     * @param label The axis label (null permitted).
     */
    protected Axis(String label) {

	this(label,
             DEFAULT_AXIS_LABEL_FONT,
             DEFAULT_AXIS_LABEL_PAINT,
             DEFAULT_AXIS_LABEL_INSETS,
             true,  // tick labels visible
             DEFAULT_TICK_LABEL_FONT,
             DEFAULT_TICK_LABEL_PAINT,
             DEFAULT_TICK_LABEL_INSETS,
             true,  // tick marks visible
             DEFAULT_TICK_STROKE);

    }

    /**
     * Constructs an axis.
     * @param label The axis label.
     * @param labelFont The font for displaying the axis label.
     * @param labelPaint The paint used to draw the axis label.
     * @param labelInsets Determines the amount of blank space around the label.
     * @param tickLabelsVisible Flag indicating whether or not the tick labels are visible.
     * @param tickLabelFont The font used to display tick labels.
     * @param tickLabelPaint The paint used to draw tick labels.
     * @param tickLabelInsets Determines the amount of blank space around tick labels.
     * @param tickMarksVisible Flag indicating whether or not tick marks are visible.
     * @param tickMarkStroke The stroke used to draw tick marks (if visible).
     */
    protected Axis(String label,
                   Font labelFont, Paint labelPaint, Insets labelInsets,
		   boolean tickLabelsVisible,
                   Font tickLabelFont, Paint tickLabelPaint, Insets tickLabelInsets,
		   boolean tickMarkVisible, Stroke tickMarkStroke) {

	this.label = label;
	this.labelFont = labelFont;
	this.labelPaint = labelPaint;
	this.labelInsets = labelInsets;
	this.tickLabelsVisible = tickLabelsVisible;
	this.tickLabelFont = tickLabelFont;
	this.tickLabelPaint = tickLabelPaint;
	this.tickLabelInsets = tickLabelInsets;
	this.tickMarksVisible = tickMarksVisible;
	this.tickMarkStroke = tickMarkStroke;

	this.ticks = new java.util.ArrayList();
	this.listeners = new java.util.ArrayList();

    }

    /**
     * Returns the plot that the axis is assigned to.
     * <P>
     * This method will return null if the axis is not currently assigned to a plot.
     * @return The plot that the axis is assigned to.
     */
    public Plot getPlot() {
	return plot;
    }

    /**
     * Sets a reference to the plot that the axis is assigned to.
     * <P>
     * This method is called by Plot in the setHorizontalAxis() and setVerticalAxis() methods.
     * You shouldn't need to call the method yourself.
     * @param plot The plot that the axis belongs to.
     */
    public void setPlot(Plot plot) throws PlotNotCompatibleException {

        if (this.isCompatiblePlot(plot) || plot == null) {
	    this.plot = plot;
        }
        else throw new PlotNotCompatibleException("Axis.setPlot(...): "
                                                 +"plot not compatible with axis.");

    }

    /**
     * Returns the label for the axis.
     * @return The label for the axis (null possible).
     */
    public String getLabel() {
	return label;
    }

    /**
     * Sets the label for the axis.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param label The new label for the axis (null permitted).
     */
    public void setLabel(String label) {

        String existing = this.label;
        if (existing!=null) {
	    if (!existing.equals(label)) {
	        this.label = label;
	        notifyListeners(new AxisChangeEvent(this));
	    }
        }
        else {
            if (label!=null) {
	        this.label = label;
	        notifyListeners(new AxisChangeEvent(this));
            }
        }

    }

    /**
     * Returns the font for the axis label.
     * @return The font for the axis label.
     */
    public Font getLabelFont() {
	return labelFont;
    }

    /**
     * Sets the font for the axis label.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param font The new label font.
     */
    public void setLabelFont(Font font) {

        // check arguments...
        if (font==null) {
            throw new IllegalArgumentException("Axis.setLabelFont(...): null not permitted.");
        }

        // make the change (if necessary)...
	if (!this.labelFont.equals(font)) {
	    this.labelFont = font;
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the color/shade used to draw the axis label.
     * @return The color/shade used to draw the axis label.
     */
    public Paint getLabelPaint() {
	return this.labelPaint;
    }

    /**
     * Sets the color/shade used to draw the axis label.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param paint The new color/shade for the axis label.
     */
    public void setLabelPaint(Paint paint) {

        // check arguments...
        if (paint==null) {
            throw new IllegalArgumentException("Axis.setLabelPaint(...): null not permitted.");
        }

        // make the change (if necessary)...
	if (!this.labelPaint.equals(paint)) {
	    this.labelPaint = paint;
	    notifyListeners(new AxisChangeEvent(this));
	}
    }


    /**
     * Returns the insets for the label (that is, the amount of blank space that should be left
     * around the label).
     */
    public Insets getLabelInsets() {
	return this.labelInsets;
    }

    /**
     * Sets the insets for the axis label, and notifies registered listeners that the axis has been
     * modified.
     * @param insets The new label insets;
     */
    public void setLabelInsets(Insets insets) {
	if (!insets.equals(this.labelInsets)) {
	    this.labelInsets = insets;
	    notifyListeners(new AxisChangeEvent(this));
	}
    }

    /**
     * Returns a flag indicating whether or not the tick labels are visible.
     * @return A flag indicating whether or not the tick labels are visible.
     */
    public boolean isTickLabelsVisible() {
	return tickLabelsVisible;
    }

    /**
     * Sets the flag that determines whether or not the tick labels are visible.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param flag The flag.
     */
    public void setTickLabelsVisible(boolean flag) {

	if (flag!=tickLabelsVisible) {
	    tickLabelsVisible = flag;
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the font used for the tick labels (if showing).
     * @return The font used for the tick labels.
     */
    public Font getTickLabelFont() {
	return tickLabelFont;
    }

    /**
     * Sets the font for the tick labels.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param font The new tick label font.
     */
    public void setTickLabelFont(Font font) {

        // check arguments...
        if (font==null) {
            throw new IllegalArgumentException("Axis.setTickLabelFont(...): null not permitted.");
        }

        // apply change if necessary...
	if (!this.tickLabelFont.equals(font)) {
	    this.tickLabelFont = font;
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the color/shade used for the tick labels.
     * @return The color/shade used for the tick labels.
     */
    public Paint getTickLabelPaint() {
	return this.tickLabelPaint;
    }

    /**
     * Sets the color/shade used to draw tick labels (if they are showing).
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param paint The new color/shade.
     */
    public void setTickLabelPaint(Paint paint) {

        // check arguments...
        if (paint==null) {
            throw new IllegalArgumentException("Axis.setTickLabelPaint(...): null not permitted.");
        }

        // make the change (if necessary)...
	if (!this.tickLabelPaint.equals(paint)) {
	    this.tickLabelPaint = paint;
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the insets for the tick labels.
     * @return The insets for the tick labels.
     */
    public Insets getTickLabelInsets() {
	return this.tickLabelInsets;
    }

    /**
     * Sets the insets for the tick labels, and notifies registered listeners that the axis has
     * been modified.
     * @param insets The new tick label insets.
     */
    public void setTickLabelInsets(Insets insets) {

        // check arguments...
        if (insets==null) {
            throw new IllegalArgumentException("Axis.setTickLabelInsets(...): null not permitted.");
        }

        // apply change if necessary...
	if (!this.tickLabelInsets.equals(insets)) {
	    this.tickLabelInsets = insets;
	    notifyListeners(new AxisChangeEvent(this));
	}
    }

    /**
     * Returns the flag that indicates whether or not the tick marks are showing.
     * @return The flag that indicates whether or not the tick marks are showing.
     */
    public boolean isTickMarksVisible() {
	return tickMarksVisible;
    }

    /**
     * Sets the flag that indicates whether or not the tick marks are showing.
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param flag The flag.
     */
    public void setTickMarksVisible(boolean flag) {

	if (flag!=tickMarksVisible) {
	    tickMarksVisible = flag;
	    notifyListeners(new AxisChangeEvent(this));
	}

    }

    /**
     * Returns the pen/brush used to draw tick marks (if they are showing).
     * @return The pen/brush used to draw tick marks.
     */
    public Stroke getTickMarkStroke() {
	return tickMarkStroke;
    }

    /**
     * Sets the pen/brush used to draw tick marks (if they are showing).
     * <P>
     * Registered listeners are notified of a general change to the axis.
     * @param stroke The new pen/brush (null not permitted).
     */
    public void setTickMarkStroke(Stroke stroke) {

        // check arguments...
        if (stroke==null) {
            throw new IllegalArgumentException("Axis.setTickMarkStroke(...): null not permitted.");
        }

        // make the change (if necessary)...
	if (!this.tickMarkStroke.equals(stroke)) {
	    this.tickMarkStroke = stroke;
	    notifyListeners(new AxisChangeEvent(this));
	}
    }

    /**
     * Draws the axis on a Java 2D graphics device (such as the screen or a printer).
     * @param g2 The graphics device.
     * @param drawArea The area within which the axes and plot should be drawn.
     * @param plotArea The area within which the plot should be drawn.
     */
    public abstract void draw(Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea);

    /**
     * Calculates the positions of the ticks for the axis, storing the results in the
     * tick list (ready for drawing).
     * @param g2 The graphics device.
     * @param drawArea The area within which the axes and plot should be drawn.
     * @param plotArea The area within which the plot should be drawn.
     */
    public abstract void refreshTicks(Graphics2D g2, Rectangle2D drawArea, Rectangle2D plotArea);

    /**
     * Configures the axis to work with the specified plot.  Override this method to perform any
     * special processing (such as auto-rescaling).
     */
    public abstract void configure();

    /**
     * Returns the maximum width of the ticks in the working list (that is set up by
     * refreshTicks()).
     * @param g2 The graphics device.
     * @param plotArea The area within which the plot is to be drawn.
     */
    protected double getMaxTickLabelWidth(Graphics2D g2, Rectangle2D plotArea) {

	double maxWidth = 0.0;
	Font font = getTickLabelFont();
	FontRenderContext frc = g2.getFontRenderContext();

	Iterator iterator = this.ticks.iterator();
	while (iterator.hasNext()) {
	    Tick tick = (Tick)iterator.next();
	    Rectangle2D labelBounds = font.getStringBounds(tick.getText(), frc);
	    if (labelBounds.getWidth()>maxWidth) {
		maxWidth = labelBounds.getWidth();
	    }
	}
	return maxWidth;

    }

    /**
     * Returns true if the plot is compatible with the axis, and false otherwise.
     * @param plot The plot.
     * @return True if the plot is compatible with the axis, and false otherwise.
     */
    protected abstract boolean isCompatiblePlot(Plot plot);

    /**
     * Notifies all registered listeners that the axis has changed.  The AxisChangeEvent provides
     * information about the change.
     * @param event Information about the change to the axis.
     */
    protected void notifyListeners(AxisChangeEvent event) {
	java.util.Iterator iterator = listeners.iterator();
	while (iterator.hasNext()) {
	    AxisChangeListener listener = (AxisChangeListener)iterator.next();
	    listener.axisChanged(event);
	}
    }

    /**
     * Registers an object for notification of changes to the axis.
     * @param listener The object that is being registered.
     */
    public void addChangeListener(AxisChangeListener listener) {
	listeners.add(listener);
    }

    /**
     * Deregisters an object for notification of changes to the axis.
     * @param listener The object to deregister.
     */
    public void removeChangeListener(AxisChangeListener listener) {
	listeners.remove(listener);
    }

    /**
     * A utility method for drawing text vertically.
     * @param text The text.
     * @param g2 The graphics device.
     * @param x The x-coordinate.
     * @param y The y-coordinate.
     */
    protected void drawVerticalString(String text, Graphics2D g2, float x, float y) {

	AffineTransform saved = g2.getTransform();

	// apply a 90 degree rotation
	AffineTransform rotate = AffineTransform.getRotateInstance(-Math.PI/2, x, y);
	g2.transform(rotate);
	g2.drawString(text, x, y);

	g2.setTransform(saved);

    }

}
