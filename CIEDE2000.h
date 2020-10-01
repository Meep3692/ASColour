/*
 * CIEDE2000.h
 * Part of http://github.com/gfiumara/CIEDE2000 by Gregory Fiumara.
 * The MIT License (MIT)
 * 
 * Copyright (c) 2015 Greg Fiumara
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
 
#ifndef GPF_CIEDE2000_H_
#define GPF_CIEDE2000_H_

#include <ostream>

#ifndef M_PI
#define M_PI        3.14159265358979323846264338327950288   /* pi */
#endif

/** Namespace containing all necessary objects and methods for CIEDE2000 */
namespace CIEDE2000
{
	/***********************************************************************
	 * Types.
	 **********************************************************************/

	/** A color in CIELAB colorspace */
	struct LAB
	{
		/** Lightness */
		double l;
		/** Color-opponent a dimension */
		double a;
		/** Color-opponent b dimension */
		double b;
	};
	/** Convenience definition for struct LAB */
	using LAB = struct LAB;

	/***********************************************************************
	 * Operations.
	 **********************************************************************/

	/**
	 * @brief
	 * Obtain Delta-E 2000 value.
	 * @details
	 * Based on the paper "The CIEDE2000 Color-Difference Formula: 
	 * Implementation Notes, Supplementary Test Data, and Mathematical 
	 * Observations" by Gaurav Sharma, Wencheng Wu, and Edul N. Dalal,
	 * from http://www.ece.rochester.edu/~gsharma/ciede2000/.
	 *
	 * @param lab1
	 * First color in LAB colorspace.
	 * @param lab2
	 * Second color in LAB colorspace.
	 *
	 * @return
	 * Delta-E difference between lab1 and lab2.
	 */
	double
	CIEDE2000(
	    const LAB &lab1,
	    const LAB &lab2);
	    
	/***********************************************************************
	 * Conversions.
	 **********************************************************************/
		
    	/**
    	 * @brief
    	 * Convert degrees to radians.
    	 *
    	 * @param deg
    	 * Angle in degrees.
    	 *
    	 * @return
    	 * deg in radians.
    	 */
	constexpr double
	deg2Rad(
	    const double deg);
	
	/**
    	 * @brief
    	 * Convert radians to degrees.
    	 *
    	 * @param rad
    	 * Angle in radians.
    	 *
    	 * @return
    	 * rad in degrees.
    	 */
        constexpr double
	rad2Deg(
	    const double rad);
}

/*******************************************************************************
 * Conversions.
 ******************************************************************************/

/**
 * @brief
 * LAB output stream operator.
 *
 * @param s
 * Output stream.
 * @param labColor
 * Color to output.
 *
 * @return
 * s with labColor appended.
 */
std::ostream&
operator<<(
    std::ostream &s,
    const CIEDE2000::LAB &labColor);
    
#endif /* GPF_CIEDE2000_H_ */