/*               TSMAA for ReShade 3.1.1+
 *
 *    (Temporal Subpixel Morphological Anti-Aliasing)
 *
 *
 *     Experimental multi-frame SMAA implementation
 *
 *                        v0.11
 *
 *                     by lordbean
 *
 */
 
 // This shader includes code adapted from:
 
/** SUBPIXEL MORPHOLOGICAL ANTI-ALIASING (SMAA)
 * Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
 * Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
 * Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
 * Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
 * Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is furnished to
 * do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software. As clarification, there
 * is no requirement that the copyright notice and permission be included in
 * binary distributions of the Software.
 **/
 
 /**============================================================================


                    NVIDIA FXAA 3.11 by TIMOTHY LOTTES


------------------------------------------------------------------------------
COPYRIGHT (C) 2010, 2011 NVIDIA CORPORATION. ALL RIGHTS RESERVED.
------------------------------------------------------------------------------*/

 /*------------------------------------------------------------------------------
 * THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *-------------------------------------------------------------------------------*/
 

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP START **************************************************************/
/*****************************************************************************************************************************************/

#include "ReShadeUI.fxh"

/////////////////////////////////////////////////////// CONFIGURABLE TOGGLES //////////////////////////////////////////////////////////////

#ifndef TSMAA_ADVANCED_MODE
	#define TSMAA_ADVANCED_MODE 0
#endif

#ifndef TSMAA_OUTPUT_MODE
	#define TSMAA_OUTPUT_MODE 0
#endif

/////////////////////////////////////////////////////// GLOBAL SETUP OPTIONS //////////////////////////////////////////////////////////////

uniform int TSMAAintroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 0.11";
	ui_text = "-------------------------------------------------------------------------\n"
			"Temporal Subpixel Morphological Anti-Aliasing, a shader by lordbean\n"
			"https://github.com/lordbean-git/TSMAA/\n"
			"-------------------------------------------------------------------------\n\n"
			"Currently Compiled Configuration:\n\n"
			#if TSMAA_ADVANCED_MODE
				"Advanced Mode:            on  *\n"
			#else
				"Advanced Mode:           off\n"
			#endif
			#if TSMAA_OUTPUT_MODE == 1
				"Output Mode:        HDR nits  *\n"
			#elif TSMAA_OUTPUT_MODE == 2
				"Output Mode:     PQ accurate  *\n"
			#elif TSMAA_OUTPUT_MODE == 3
				"Output Mode:       PQ approx  *\n"
			#else
				"Output Mode:       Gamma 2.2\n"
			#endif
			
			"\nValid Output Modes (TSMAA_OUTPUT_MODE):\n"
			"0: Gamma 2.2 (default)\n"
			"1: HDR, direct nits scale\n"
			"2: HDR10, accurate encoding\n"
			"3: HDR10, fast encoding\n"
			"\n-------------------------------------------------------------------------"
			"\nSee the 'Preprocessor definitions' section for color & feature toggles.\n"
			"-------------------------------------------------------------------------";
	ui_tooltip = "experimental beta";
	ui_category = "About";
	ui_category_closed = true;
>;

uniform int TsmaaAboutEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float TsmaaJitterStrength <
	ui_type = "slider";
	ui_min = 0.1; ui_max = 0.5; ui_step = 0.001;
	ui_label = "Jitter Strength";
	ui_spacing = 2;
	ui_tooltip = "Controls the offset used for jittering the buffer";
> = 0.333333;

#if !TSMAA_ADVANCED_MODE
uniform uint TsmaaPreset <
	ui_type = "combo";
	ui_label = "Quality Preset\n\n";
	ui_tooltip = "Set TSMAA_ADVANCED_MODE to 1 to customize all options";
	ui_items = "Low\0Medium\0High\0Ultra\0";
> = 2;

#else
uniform float TsmaaEdgeThresholdCustom < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_spacing = 4;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast (luma difference) required to be considered an edge";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 0.1;

uniform float TsmaaDynamicThresholdCustom < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "% Dynamic Reduction Range";
	ui_tooltip = "Maximum dynamic reduction of edge threshold (as percentage of base threshold)\n"
				 "permitted when detecting low-brightness edges.\n"
				 "Lower = faster, might miss low-contrast edges\n"
				 "Higher = slower, catches more edges in dark scenes";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 75;

uniform uint TsmaaEdgeErrorMarginCustom <
	ui_type = "radio";
	ui_label = "Mouseover for description";
	ui_spacing = 3;
	ui_text = "Detected Edges Margin of Error:";
	ui_tooltip = "Determines maximum number of neighbor edges allowed before\n"
				"an edge is considered an erroneous detection. Low preserves\n"
				"detail, high increases amount of anti-aliasing applied. You\n"
				"can skip this check entirely by selecting 'Off'.";
	ui_items = "Low\0Balanced\0High\0Off\0";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 1;

static const float TSMAA_ERRORMARGIN_CUSTOM[4] = {4.0, 5.0, 7.0, -1.0};

uniform float TsmaaSmCorneringCustom < __UNIFORM_SLIDER_INT1
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_spacing = 2;
	ui_label = "% Corner Rounding";
	ui_tooltip = "Affects the amount of blending performed when SMAA\ndetects crossing edges";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 25;
#endif //TSMAA_ADVANCED_MODE

#if TSMAA_OUTPUT_MODE == 1
uniform float TsmaaHdrNits < 
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 500.0; ui_max = 10000.0; ui_step = 100.0;
	ui_label = "HDR Nits";
	ui_tooltip = "If the scene brightness changes after TSMAA runs, try\n"
				 "adjusting this value up or down until it looks right.";
> = 1000.0;
#endif

uniform int TsmaaOptionsEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

///////////////////////////////////////////////// HUMAN+MACHINE PRESET REFERENCE //////////////////////////////////////////////////////////

#if TSMAA_ADVANCED_MODE
uniform int TsmaaPresetBreakdown <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n"
			  "------------------------------------------------\n"
			  "|        |       Edges       |      SMAA       |\n"
	          "|--Preset|-Threshold---Range-|-Corner---%Error-|\n"
	          "|--------|-----------|-------|--------|--------|\n"
			  "|     Low|   0.100   | 33.3% |   25%  |  High  |\n"
			  "|  Medium|   0.075   | 50.0% |   33%  |  High  |\n"
			  "|    High|   0.050   | 66.7% |   50%  |  High  |\n"
			  "|   Ultra|   0.025   | 80.0% |  100%  |  Skip  |\n"
			  "------------------------------------------------";
	ui_category = "Click me to see what settings each preset uses!";
	ui_category_closed = true;
>;

#define __TSMAA_EDGE_THRESHOLD (TsmaaEdgeThresholdCustom)
#define __TSMAA_DYNAMIC_RANGE (float(TsmaaDynamicThresholdCustom) / 100.0)
#define __TSMAA_SM_CORNERS (float(TsmaaSmCorneringCustom) / 100.0)
#define __TSMAA_SM_ERRORMARGIN (TSMAA_ERRORMARGIN_CUSTOM[TsmaaEdgeErrorMarginCustom])

#else

static const float TSMAA_THRESHOLD_PRESET[4] = {0.1, 0.075, 0.05, 0.025};
static const float TSMAA_DYNAMIC_RANGE_PRESET[4] = {0.333333, 0.5, 0.666667, 0.8};
static const float TSMAA_CORNER_ROUNDING_PRESET[4] = {0.25, 0.333333, 0.5, 1.0};
static const float TSMAA_ERRORMARGIN_PRESET[4] = {7.0, 7.0, 7.0, -1.0};

#define __TSMAA_EDGE_THRESHOLD (TSMAA_THRESHOLD_PRESET[TsmaaPreset])
#define __TSMAA_DYNAMIC_RANGE (TSMAA_DYNAMIC_RANGE_PRESET[TsmaaPreset])
#define __TSMAA_SM_CORNERS (TSMAA_CORNER_ROUNDING_PRESET[TsmaaPreset])
#define __TSMAA_SM_ERRORMARGIN (TSMAA_ERRORMARGIN_PRESET[TsmaaPreset])

#endif //TSMAA_ADVANCED_MODE

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP END ****************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SYNTAX SETUP START *************************************************************/
/*****************************************************************************************************************************************/

#define __TSMAA_DISPLAY_NUMERATOR max(BUFFER_HEIGHT, BUFFER_WIDTH)
#define __TSMAA_SMALLEST_COLOR_STEP rcp(pow(2, BUFFER_COLOR_BIT_DEPTH))
#define __TSMAA_MINIMUM_CONTRAST (__TSMAA_SMALLEST_COLOR_STEP * 1.25)
#define __TSMAA_CONST_E 2.718282
#define __TSMAA_LUMA_REF float3(0.333333, 0.333334, 0.333333)

#define __TSMAA_SM_RADIUS (__TSMAA_DISPLAY_NUMERATOR * 0.125)
#define __TSMAA_BUFFER_INFO float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define __TSMAA_JITTER float2(BUFFER_RCP_WIDTH * TsmaaJitterStrength, BUFFER_RCP_HEIGHT * TsmaaJitterStrength)
#define __TSMAA_JITTER_ODD float2(BUFFER_RCP_WIDTH * TsmaaJitterStrength, -(BUFFER_RCP_HEIGHT * TsmaaJitterStrength))
#define __TSMAA_SM_AREATEX_RANGE 16
#define __TSMAA_SM_AREATEX_RANGE_DIAG 20
#define __TSMAA_SM_AREATEX_TEXEL float2(0.00625, 0.001786) // 1/{160,560}
#define __TSMAA_SM_AREATEX_SUBTEXEL 0.142857 // 1/7
#define __TSMAA_SM_SEARCHTEX_SIZE float2(66.0, 33.0)
#define __TSMAA_SM_SEARCHTEX_SIZE_PACKED float2(64.0, 16.0)

#define TSMAA_Tex2D(tex, coord) tex2Dlod(tex, (coord).xyxy)
#define TSMAA_Tex2DOffset(tex, coord, offset) tex2Dlodoffset(tex, (coord).xyxy, offset)
#define TSMAA_DecodeTex2D(tex, coord) ConditionalDecode(tex2Dlod(tex, (coord).xyxy))
#define TSMAA_DecodeTex2DOffset(tex, coord, offset) ConditionalDecode(tex2Dlodoffset(tex, (coord).xyxy, offset))

#define TSMAAmax3(x,y,z) max(max(x,y),z)
#define TSMAAmax4(w,x,y,z) max(max(w,x),max(y,z))
#define TSMAAmax5(v,w,x,y,z) max(max(max(v,w),x),max(y,z))
#define TSMAAmax6(u,v,w,x,y,z) max(max(max(u,v),max(w,x)),max(y,z))
#define TSMAAmax7(t,u,v,w,x,y,z) max(max(max(t,u),max(v,w)),max(max(x,y),z))
#define TSMAAmax8(s,t,u,v,w,x,y,z) max(max(max(s,t),max(u,v)),max(max(w,x),max(y,z)))
#define TSMAAmax9(r,s,t,u,v,w,x,y,z) max(max(max(max(r,s),t),max(u,v)),max(max(w,x),max(y,z)))
#define TSMAAmax10(q,r,s,t,u,v,w,x,y,z) max(max(max(max(q,r),max(s,t)),max(u,v)),max(max(w,x),max(y,z)))
#define TSMAAmax11(p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(p,q),max(r,s)),max(max(t,u),v)),max(max(w,x),max(y,z)))
#define TSMAAmax12(o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(o,p),max(q,r)),max(max(s,t),max(u,v))),max(max(w,x),max(y,z)))
#define TSMAAmax13(n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(n,o),max(p,q)),max(max(r,s),max(t,u))),max(max(max(v,w),x),max(y,z)))
#define TSMAAmax14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(m,n),max(o,p)),max(max(q,r),max(s,t))),max(max(max(u,v),max(w,x)),max(y,z)))

#define TSMAAmin3(x,y,z) min(min(x,y),z)
#define TSMAAmin4(w,x,y,z) min(min(w,x),min(y,z))
#define TSMAAmin5(v,w,x,y,z) min(min(min(v,w),x),min(y,z))
#define TSMAAmin6(u,v,w,x,y,z) min(min(min(u,v),min(w,x)),min(y,z))
#define TSMAAmin7(t,u,v,w,x,y,z) min(min(min(t,u),min(v,w)),min(min(x,y),z))
#define TSMAAmin8(s,t,u,v,w,x,y,z) min(min(min(s,t),min(u,v)),min(min(w,x),min(y,z)))
#define TSMAAmin9(r,s,t,u,v,w,x,y,z) min(min(min(min(r,s),t),min(u,v)),min(min(w,x),min(y,z)))
#define TSMAAmin10(q,r,s,t,u,v,w,x,y,z) min(min(min(min(q,r),min(s,t)),min(u,v)),min(min(w,x),min(y,z)))
#define TSMAAmin11(p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(p,q),min(r,s)),min(min(t,u),v)),min(min(w,x),min(y,z)))
#define TSMAAmin12(o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(o,p),min(q,r)),min(min(s,t),min(u,v))),min(min(w,x),min(y,z)))
#define TSMAAmin13(n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(n,o),min(p,q)),min(min(r,s),min(t,u))),min(min(min(v,w),x),min(y,z)))
#define TSMAAmin14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(m,n),min(o,p)),min(min(q,r),min(s,t))),min(min(min(u,v),min(w,x)),min(y,z)))

#define TSMAAdotmax(x) max(max((x).r, (x).g), (x).b)
#define TSMAAdotmin(x) min(min((x).r, (x).g), (x).b)

/*****************************************************************************************************************************************/
/********************************************************* SYNTAX SETUP END **************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SUPPORT CODE START *************************************************************/
/*****************************************************************************************************************************************/

//////////////////////////////////////////////////////// PIXEL INFORMATION ////////////////////////////////////////////////////////////////

float dotweight(float3 middle, float3 neighbor, bool useluma, float3 weights)
{
	if (useluma) return dot(neighbor, weights);
	else return dot(abs(middle - neighbor), __TSMAA_LUMA_REF);
}

/////////////////////////////////////////////////////// TRANSFER FUNCTIONS ////////////////////////////////////////////////////////////////

#if TSMAA_OUTPUT_MODE == 2
float encodePQ(float x)
{
/*	float nits = 10000.0;
	float m2rcp = 0.012683; // 1 / (2523/32)
	float m1rcp = 6.277395; // 1 / (1305/8192)
	float c1 = 0.8359375; // 107 / 128
	float c2 = 18.8515625; // 2413 / 128
	float c3 = 18.6875; // 2392 / 128
*/
	float xpm2rcp = pow(saturate(x), 0.012683);
	float numerator = max(xpm2rcp - 0.8359375, 0.0);
	float denominator = 18.8515625 - (18.6875 * xpm2rcp);
	
	float output = pow(abs(numerator / denominator), 6.277395);
#if BUFFER_COLOR_BIT_DEPTH == 10
	output *= 500.0;
#else
	output *= 10000.0;
#endif

	return output;
}
float2 encodePQ(float2 x)
{
	float2 xpm2rcp = pow(saturate(x), 0.012683);
	float2 numerator = max(xpm2rcp - 0.8359375, 0.0);
	float2 denominator = 18.8515625 - (18.6875 * xpm2rcp);
	
	float2 output = pow(abs(numerator / denominator), 6.277395);
#if BUFFER_COLOR_BIT_DEPTH == 10
	output *= 500.0;
#else
	output *= 10000.0;
#endif

	return output;
}
float3 encodePQ(float3 x)
{
	float3 xpm2rcp = pow(saturate(x), 0.012683);
	float3 numerator = max(xpm2rcp - 0.8359375, 0.0);
	float3 denominator = 18.8515625 - (18.6875 * xpm2rcp);
	
	float3 output = pow(abs(numerator / denominator), 6.277395);
#if BUFFER_COLOR_BIT_DEPTH == 10
	output *= 500.0;
#else
	output *= 10000.0;
#endif

	return output;
}
float4 encodePQ(float4 x)
{
	float4 xpm2rcp = pow(saturate(x), 0.012683);
	float4 numerator = max(xpm2rcp - 0.8359375, 0.0);
	float4 denominator = 18.8515625 - (18.6875 * xpm2rcp);
	
	float4 output = pow(abs(numerator / denominator), 6.277395);
#if BUFFER_COLOR_BIT_DEPTH == 10
	output *= 500.0;
#else
	output *= 10000.0;
#endif

	return output;
}

float decodePQ(float x)
{
/*	float nits = 10000.0;
	float m2 = 78.84375 // 2523 / 32
	float m1 = 0.159302; // 1305 / 8192
	float c1 = 0.8359375; // 107 / 128
	float c2 = 18.8515625; // 2413 / 128
	float c3 = 18.6875; // 2392 / 128
*/
#if BUFFER_COLOR_BIT_DEPTH == 10
	float xpm1 = pow(saturate(x / 500.0), 0.159302);
#else
	float xpm1 = pow(saturate(x / 10000.0), 0.159302);
#endif
	float numerator = 0.8359375 + (18.8515625 * xpm1);
	float denominator = 1.0 + (18.6875 * xpm1);
	
	return saturate(pow(abs(numerator / denominator), 78.84375));
}
float2 decodePQ(float2 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float2 xpm1 = pow(saturate(x / 500.0), 0.159302);
#else
	float2 xpm1 = pow(saturate(x / 10000.0), 0.159302);
#endif
	float2 numerator = 0.8359375 + (18.8515625 * xpm1);
	float2 denominator = 1.0 + (18.6875 * xpm1);
	
	return saturate(pow(abs(numerator / denominator), 78.84375));
}
float3 decodePQ(float3 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float3 xpm1 = pow(saturate(x / 500.0), 0.159302);
#else
	float3 xpm1 = pow(saturate(x / 10000.0), 0.159302);
#endif
	float3 numerator = 0.8359375 + (18.8515625 * xpm1);
	float3 denominator = 1.0 + (18.6875 * xpm1);
	
	return saturate(pow(abs(numerator / denominator), 78.84375));
}
float4 decodePQ(float4 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float4 xpm1 = pow(saturate(x / 500.0), 0.159302);
#else
	float4 xpm1 = pow(saturate(x / 10000.0), 0.159302);
#endif
	float4 numerator = 0.8359375 + (18.8515625 * xpm1);
	float4 denominator = 1.0 + (18.6875 * xpm1);
	
	return saturate(pow(abs(numerator / denominator), 78.84375));
}
#endif //TSMAA_OUTPUT_MODE == 2

#if TSMAA_OUTPUT_MODE == 3
float fastencodePQ(float x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float y = saturate(x) * 4.728708;
#else
	float y = saturate(x) * 10.0;
#endif
	y *= y;
	y *= y;
	return y;
}
float2 fastencodePQ(float2 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float2 y = saturate(x) * 4.728708;
#else
	float2 y = saturate(x) * 10.0;
#endif
	y *= y;
	y *= y;
	return y;
}
float3 fastencodePQ(float3 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float3 y = saturate(x) * 4.728708;
#else
	float3 y = saturate(x) * 10.0;
#endif
	y *= y;
	y *= y;
	return y;
}
float4 fastencodePQ(float4 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float4 y = saturate(x) * 4.728708;
#else
	float4 y = saturate(x) * 10.0;
#endif
	y *= y;
	y *= y;
	return y;
}

float fastdecodePQ(float x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 10000.0))) / 10.0));
#endif
}
float2 fastdecodePQ(float2 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 10000.0))) / 10.0));
#endif
}
float3 fastdecodePQ(float3 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 10000.0))) / 10.0));
#endif
}
float4 fastdecodePQ(float4 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __TSMAA_SMALLEST_COLOR_STEP, 10000.0))) / 10.0));
#endif
}
#endif //TSMAA_OUTPUT_MODE == 3

#if TSMAA_OUTPUT_MODE == 1
float encodeHDR(float x)
{
	return saturate(x) * TsmaaHdrNits;
}
float2 encodeHDR(float2 x)
{
	return saturate(x) * TsmaaHdrNits;
}
float3 encodeHDR(float3 x)
{
	return saturate(x) * TsmaaHdrNits;
}
float4 encodeHDR(float4 x)
{
	return saturate(x) * TsmaaHdrNits;
}

float decodeHDR(float x)
{
	return saturate(x / TsmaaHdrNits);
}
float2 decodeHDR(float2 x)
{
	return saturate(x / TsmaaHdrNits);
}
float3 decodeHDR(float3 x)
{
	return saturate(x / TsmaaHdrNits);
}
float4 decodeHDR(float4 x)
{
	return saturate(x / TsmaaHdrNits);
}
#endif //TSMAA_OUTPUT_MODE == 1

float ConditionalEncode(float x)
{
#if TSMAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float2 ConditionalEncode(float2 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float3 ConditionalEncode(float3 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float4 ConditionalEncode(float4 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}

float ConditionalDecode(float x)
{
#if TSMAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float2 ConditionalDecode(float2 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float3 ConditionalDecode(float3 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float4 ConditionalDecode(float4 x)
{
#if TSMAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif TSMAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif TSMAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}

//////////////////////////////////////////////////// SATURATION CALCULATIONS //////////////////////////////////////////////////////////////

float dotsat(float3 x)
{
	float xl = dot(x, __TSMAA_LUMA_REF);
	return ((TSMAAdotmax(x) - TSMAAdotmin(x)) / (1.0 - (2.0 * xl - 1.0) + trunc(xl)));
}
float dotsat(float4 x)
{
	return dotsat(x.rgb);
}

///////////////////////////////////////////////////// SMAA HELPER FUNCTIONS ///////////////////////////////////////////////////////////////

void TSMAAMovc(bool2 cond, inout float2 variable, float2 value)
{
    [flatten] if (cond.x) variable.x = value.x;
    [flatten] if (cond.y) variable.y = value.y;
}
void TSMAAMovc(bool4 cond, inout float4 variable, float4 value)
{
    TSMAAMovc(cond.xy, variable.xy, value.xy);
    TSMAAMovc(cond.zw, variable.zw, value.zw);
}

float2 TSMAADecodeDiagBilinearAccess(float2 e)
{
    e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
    return round(e);
}
float4 TSMAADecodeDiagBilinearAccess(float4 e)
{
    e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
    return round(e);
}

float2 TSMAASearchDiag1(sampler2D TSMAAedgesTex, float2 texcoord, float2 dir, out float2 e)
{
    float4 coord = float4(texcoord, -1.0, 1.0);
    float3 t = float3(__TSMAA_BUFFER_INFO.xy, 1.0);
    bool endloop = false;
    
    [loop] while (coord.z < 20.0) 
	{
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
        e = tex2Dlod(TSMAAedgesTex, coord.xyxy).rg;
        coord.w = dot(e, float(0.5).xx);
        endloop = coord.w < 0.9;
        if (endloop) break;
    }
    return coord.zw;
}
float2 TSMAASearchDiag2(sampler2D TSMAAedgesTex, float2 texcoord, float2 dir, out float2 e)
{
    float4 coord = float4(texcoord, -1.0, 1.0);
    coord.x += 0.25 * __TSMAA_BUFFER_INFO.x;
    float3 t = float3(__TSMAA_BUFFER_INFO.xy, 1.0);
    bool endloop = false;
    
    [loop] while (coord.z < 20.0) 
	{
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);

        e = tex2Dlod(TSMAAedgesTex, coord.xyxy).rg;
        e = TSMAADecodeDiagBilinearAccess(e);

        coord.w = dot(e, float(0.5).xx);
        endloop = coord.w < 0.9;
        if (endloop) break;
    }
    return coord.zw;
}

float2 TSMAAAreaDiag(sampler2D TSMAAareaTex, float2 dist, float2 e, float offset)
{
    float2 texcoord = mad(float(__TSMAA_SM_AREATEX_RANGE_DIAG).xx, e, dist);

    texcoord = mad(__TSMAA_SM_AREATEX_TEXEL, texcoord, 0.5 * __TSMAA_SM_AREATEX_TEXEL);
    texcoord.x += 0.5;
    texcoord.y += __TSMAA_SM_AREATEX_SUBTEXEL * offset;

    return tex2Dlod(TSMAAareaTex, texcoord.xyxy).rg;
}

float2 TSMAACalculateDiagWeights(sampler2D TSMAAedgesTex, sampler2D TSMAAareaTex, float2 texcoord, float2 e, float4 subsampleIndices)
{
    float2 weights = float(0.0).xx;
    float2 end;
    float4 d;
    bool checkpassed;
    d.ywxz = float4(TSMAASearchDiag1(TSMAAedgesTex, texcoord, float2(1.0, -1.0), end), 0.0, 0.0);
    
    checkpassed = e.r > 0.0;
    [branch] if (checkpassed) 
	{
        d.xz = TSMAASearchDiag1(TSMAAedgesTex, texcoord, float2(-1.0,  1.0), end);
        d.x += float(end.y > 0.9);
    }
	
	checkpassed = d.x + d.y > 2.0;
	[branch] if (checkpassed) 
	{
        float4 coords = mad(float4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), __TSMAA_BUFFER_INFO.xyxy, texcoord.xyxy);
        float4 c;
        c.xy = tex2Dlodoffset(TSMAAedgesTex, coords.xyxy, int2(-1,  0)).rg;
        c.zw = tex2Dlodoffset(TSMAAedgesTex, coords.zwzw, int2( 1,  0)).rg;
        c.yxwz = TSMAADecodeDiagBilinearAccess(c.xyzw);

        float2 cc = mad(float(2.0).xx, c.xz, c.yw);

        TSMAAMovc(bool2(step(0.9, d.zw)), cc, float(0.0).xx);

        weights += TSMAAAreaDiag(TSMAAareaTex, d.xy, cc, subsampleIndices.z);
    }

    d.xz = TSMAASearchDiag2(TSMAAedgesTex, texcoord, float2(-1.0, -1.0), end);
    d.yw = float(0.0).xx;
    
    checkpassed = TSMAA_Tex2DOffset(TSMAAedgesTex, texcoord, int2(1, 0)).r > 0.0;
    [branch] if (checkpassed) 
	{
        d.yw = TSMAASearchDiag2(TSMAAedgesTex, texcoord, float(1.0).xx, end);
        d.y += float(end.y > 0.9);
    }
	
	checkpassed = d.x + d.y > 2.0;
	[branch] if (checkpassed) 
	{
        float4 coords = mad(float4(-d.x, -d.x, d.y, d.y), __TSMAA_BUFFER_INFO.xyxy, texcoord.xyxy);
        float4 c;
        c.x  = tex2Dlodoffset(TSMAAedgesTex, coords.xyxy, int2(-1,  0)).g;
        c.y  = tex2Dlodoffset(TSMAAedgesTex, coords.xyxy, int2( 0, -1)).r;
        c.zw = tex2Dlodoffset(TSMAAedgesTex, coords.zwzw, int2( 1,  0)).gr;
        float2 cc = mad(float(2.0).xx, c.xz, c.yw);

        TSMAAMovc(bool2(step(0.9, d.zw)), cc, float(0.0).xx);

        weights += TSMAAAreaDiag(TSMAAareaTex, d.xy, cc, subsampleIndices.w).gr;
    }

    return weights;
}

float TSMAASearchLength(sampler2D TSMAAsearchTex, float2 e, float offset)
{
    float2 scale = __TSMAA_SM_SEARCHTEX_SIZE * float2(0.5, -1.0);
    float2 bias = __TSMAA_SM_SEARCHTEX_SIZE * float2(offset, 1.0);

    scale += float2(-1.0,  1.0);
    bias  += float2( 0.5, -0.5);

    scale *= 1.0 / __TSMAA_SM_SEARCHTEX_SIZE_PACKED;
    bias *= 1.0 / __TSMAA_SM_SEARCHTEX_SIZE_PACKED;

    return tex2Dlod(TSMAAsearchTex, mad(scale, e, bias).xyxy).r;
}

float TSMAASearchXLeft(sampler2D TSMAAedgesTex, sampler2D TSMAAsearchTex, float2 texcoord, float end)
{
    float2 e = float2(0.0, 1.0);
    bool endedge = false;
    [loop] while (texcoord.x > end) 
	{
        e = tex2Dlod(TSMAAedgesTex, texcoord.xyxy).rg;
        texcoord = mad(-float2(2.0, 0.0), __TSMAA_BUFFER_INFO.xy, texcoord);
        endedge = e.r > 0.0 || e.g == 0.0;
        if (endedge) break;
    }
    float offset = mad(-2.007874, TSMAASearchLength(TSMAAsearchTex, e, 0.0), 3.25); // -(255/127)
    return mad(__TSMAA_BUFFER_INFO.x, offset, texcoord.x);
}
float TSMAASearchXRight(sampler2D TSMAAedgesTex, sampler2D TSMAAsearchTex, float2 texcoord, float end)
{
    float2 e = float2(0.0, 1.0);
    bool endedge = false;
    [loop] while (texcoord.x < end) 
	{
        e = tex2Dlod(TSMAAedgesTex, texcoord.xyxy).rg;
        texcoord = mad(float2(2.0, 0.0), __TSMAA_BUFFER_INFO.xy, texcoord);
        endedge = e.r > 0.0 || e.g == 0.0;
        if (endedge) break;
    }
    float offset = mad(-2.007874, TSMAASearchLength(TSMAAsearchTex, e, 0.5), 3.25);
    return mad(-__TSMAA_BUFFER_INFO.x, offset, texcoord.x);
}
float TSMAASearchYUp(sampler2D TSMAAedgesTex, sampler2D TSMAAsearchTex, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    bool endedge = false;
    [loop] while (texcoord.y > end) 
	{
        e = tex2Dlod(TSMAAedgesTex, texcoord.xyxy).rg;
        texcoord = mad(-float2(0.0, 2.0), __TSMAA_BUFFER_INFO.xy, texcoord);
        endedge = e.r == 0.0 || e.g > 0.0;
        if (endedge) break;
    }
    float offset = mad(-2.007874, TSMAASearchLength(TSMAAsearchTex, e.gr, 0.0), 3.25);
    return mad(__TSMAA_BUFFER_INFO.y, offset, texcoord.y);
}
float TSMAASearchYDown(sampler2D TSMAAedgesTex, sampler2D TSMAAsearchTex, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    bool endedge = false;
    [loop] while (texcoord.y < end) 
	{
        e = tex2Dlod(TSMAAedgesTex, texcoord.xyxy).rg;
        texcoord = mad(float2(0.0, 2.0), __TSMAA_BUFFER_INFO.xy, texcoord);
        endedge = e.r == 0.0 || e.g > 0.0;
        if (endedge) break;
    }
    float offset = mad(-2.007874, TSMAASearchLength(TSMAAsearchTex, e.gr, 0.5), 3.25);
    return mad(-__TSMAA_BUFFER_INFO.y, offset, texcoord.y);
}

float2 TSMAAArea(sampler2D TSMAAareaTex, float2 dist, float e1, float e2, float offset)
{
    float2 texcoord = mad(float(__TSMAA_SM_AREATEX_RANGE).xx, round(4.0 * float2(e1, e2)), dist);
    
    texcoord = mad(__TSMAA_SM_AREATEX_TEXEL, texcoord, 0.5 * __TSMAA_SM_AREATEX_TEXEL);
    texcoord.y = mad(__TSMAA_SM_AREATEX_SUBTEXEL, offset, texcoord.y);

    return tex2Dlod(TSMAAareaTex, texcoord.xyxy).rg;
}

void TSMAADetectHorizontalCornerPattern(sampler2D TSMAAedgesTex, inout float2 weights, float4 texcoord, float2 d)
{
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - __TSMAA_SM_CORNERS) * leftRight;

    float2 factor = float(1.0).xx;
    factor.x -= rounding.x * tex2Dlodoffset(TSMAAedgesTex, texcoord.xyxy, int2(0,  1)).r;
    factor.x -= rounding.y * tex2Dlodoffset(TSMAAedgesTex, texcoord.zwzw, int2(1,  1)).r;
    factor.y -= rounding.x * tex2Dlodoffset(TSMAAedgesTex, texcoord.xyxy, int2(0, -2)).r;
    factor.y -= rounding.y * tex2Dlodoffset(TSMAAedgesTex, texcoord.zwzw, int2(1, -2)).r;

    weights *= saturate(factor);
}
void TSMAADetectVerticalCornerPattern(sampler2D TSMAAedgesTex, inout float2 weights, float4 texcoord, float2 d)
{
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - __TSMAA_SM_CORNERS) * leftRight;

    float2 factor = float(1.0).xx;
    factor.x -= rounding.x * tex2Dlodoffset(TSMAAedgesTex, texcoord.xyxy, int2( 1, 0)).g;
    factor.x -= rounding.y * tex2Dlodoffset(TSMAAedgesTex, texcoord.zwzw, int2( 1, 1)).g;
    factor.y -= rounding.x * tex2Dlodoffset(TSMAAedgesTex, texcoord.xyxy, int2(-2, 0)).g;
    factor.y -= rounding.y * tex2Dlodoffset(TSMAAedgesTex, texcoord.zwzw, int2(-2, 1)).g;

    weights *= saturate(factor);
}

float2 TSMAAJitterEdgeDetection(float2 texcoord, float4 offset[3], sampler2D buffersource, float threshold, bool useluma, float scale)
{
	float3 middle = TSMAA_DecodeTex2D(buffersource, texcoord).rgb;
	float2 edges = float(0.0).xx;
	
    float L = dotweight(middle, middle, useluma, __TSMAA_LUMA_REF);
    float Lleft = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[0].xy).rgb, useluma, __TSMAA_LUMA_REF);
    float Ltop = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[0].zw).rgb, useluma, __TSMAA_LUMA_REF);
    float Lright = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[1].xy).rgb, useluma, __TSMAA_LUMA_REF);
	float Lbottom = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[1].zw).rgb, useluma, __TSMAA_LUMA_REF);
	
    float4 delta = abs(L - float4(Lleft, Ltop, Lright, Lbottom));
	edges = step(threshold.xx, delta.xy);
	float2 maxDelta = max(delta.xy, delta.zw);
		
	float Lleftleft = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[2].xy).rgb, useluma, __TSMAA_LUMA_REF);
	float Ltoptop = dotweight(middle, TSMAA_DecodeTex2D(buffersource, offset[2].zw).rgb, useluma, __TSMAA_LUMA_REF);
	
	delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));
	maxDelta = max(maxDelta, delta.zw);
	float finalDelta = max(maxDelta.x, maxDelta.y);
	
	edges *= step(finalDelta, scale * delta.xy);
	
	return edges;
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

//////////////////////////////////////////////////////////// TEXTURES ///////////////////////////////////////////////////////////////////

texture TSMAAedgesTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};

texture TSMAAedgesTexX2
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};

texture TSMAAblendTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAAoldblendTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAAoldbufferTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAAnegativejitterTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAApositivejitterTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAAnegativejitteroddTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAApositivejitteroddTex
#if __RESHADE__ >= 50000
< pooled = true; >
#else
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

#if BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
#elif BUFFER_COLOR_BIT_DEPTH > 8
	Format = RGBA16F;
#else
	Format = RGBA8;
#endif
};

texture TSMAAareaTex < source = "AreaTex.png"; >
{
	Width = 160;
	Height = 560;
	Format = RG8;
};

texture TSMAAsearchTex < source = "SearchTex.png"; >
{
	Width = 64;
	Height = 16;
	Format = R8;
};

//////////////////////////////////////////////////////////// SAMPLERS ///////////////////////////////////////////////////////////////////

sampler TSMAAsamplerEdges
{
	Texture = TSMAAedgesTex;
};

sampler TSMAAsamplerEdgesX2
{
	Texture = TSMAAedgesTex;
};

sampler TSMAAsamplerWeights
{
	Texture = TSMAAblendTex;
};

sampler TSMAAsamplerOldWeights
{
	Texture = TSMAAoldblendTex;
};

sampler TSMAAsamplerOldBuffer
{
	Texture = TSMAAoldbufferTex;
};

sampler TSMAAsamplerPositiveJitter
{
	Texture = TSMAApositivejitterTex;
};

sampler TSMAAsamplerNegativeJitter
{
	Texture = TSMAAnegativejitterTex;
};

sampler TSMAAsamplerPositiveJitterOdd
{
	Texture = TSMAApositivejitteroddTex;
};

sampler TSMAAsamplerNegativeJitterOdd
{
	Texture = TSMAAnegativejitteroddTex;
};

sampler TSMAAsamplerAreaRef
{
	Texture = TSMAAareaTex;
};

sampler TSMAAsamplerSearchRef
{
	Texture = TSMAAsearchTex;
	MipFilter = Point; MinFilter = Point; MagFilter = Point;
};

//////////////////////////////////////////////////////////// VERTEX SHADERS /////////////////////////////////////////////////////////////

void TSMAAEdgeDetectionVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0, out float4 offset[3] : TEXCOORD1)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    offset[0] = mad(__TSMAA_BUFFER_INFO.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    offset[1] = mad(__TSMAA_BUFFER_INFO.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
    offset[2] = mad(__TSMAA_BUFFER_INFO.xyxy, float4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy);
}

void TSMAABlendingWeightCalculationVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0, out float2 pixcoord : TEXCOORD1, out float4 offset[3] : TEXCOORD2)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    pixcoord = texcoord * __TSMAA_BUFFER_INFO.zw;

    offset[0] = mad(__TSMAA_BUFFER_INFO.xyxy, float4(-0.25, -0.125,  1.25, -0.125), texcoord.xyxy);
    offset[1] = mad(__TSMAA_BUFFER_INFO.xyxy, float4(-0.125, -0.25, -0.125,  1.25), texcoord.xyxy);
	
	float searchrange = trunc(__TSMAA_SM_RADIUS);
	
    offset[2] = mad(__TSMAA_BUFFER_INFO.xxyy,
                    float2(-2.0, 2.0).xyxy * searchrange,
                    float4(offset[0].xz, offset[1].yw));
}

void TSMAANeighborhoodBlendingVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0, out float4 offset : TEXCOORD1)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    offset = mad(__TSMAA_BUFFER_INFO.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
}

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/********************************************************** SMAA SHADER CODE START *******************************************************/
/*****************************************************************************************************************************************/

///////////////////////////////////////////////////////// BUFFER JITTER ///////////////////////////////////////////////////////////////////
float4 TSMAAPositiveJitterPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 coords = texcoord + __TSMAA_JITTER;
	return TSMAA_Tex2D(ReShade::BackBuffer, coords);
}

float4 TSMAANegativeJitterPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 coords = texcoord - __TSMAA_JITTER;
	return TSMAA_Tex2D(ReShade::BackBuffer, coords);
}

float4 TSMAAPositiveJitterOddPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 coords = texcoord + __TSMAA_JITTER_ODD;
	return TSMAA_Tex2D(ReShade::BackBuffer, coords);
}

float4 TSMAANegativeJitterOddPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 coords = texcoord - __TSMAA_JITTER_ODD;
	return TSMAA_Tex2D(ReShade::BackBuffer, coords);
}

//////////////////////////////////////////////////// TEMPORAL EDGE TRANSFER ///////////////////////////////////////////////////////////////
float4 TSMAAMergeEdgesPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return float4(TSMAA_Tex2D(TSMAAsamplerEdges, texcoord).ba, TSMAA_Tex2D(TSMAAsamplerEdgesX2, texcoord).rg);
}

float4 TSMAAWriteEdgesPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return TSMAA_Tex2D(TSMAAsamplerWeights, texcoord);
}

//////////////////////////////////////////////////////// EDGE DETECTION ///////////////////////////////////////////////////////////////////
float4 TSMAAHybridEdgeDetectionPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float4 offset[3] : TEXCOORD1) : SV_Target
{
	float3 middle = TSMAA_DecodeTex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 adaptationaverage = middle;
	
	float basethreshold = __TSMAA_EDGE_THRESHOLD;
	
	float satmult = 1.0 - dotsat(middle);
	float lumamult = 1.0 - dot(middle, __TSMAA_LUMA_REF);
	float2 lumathreshold = mad(lumamult, -(__TSMAA_DYNAMIC_RANGE * basethreshold), basethreshold).xx;
	float2 satthreshold = mad(satmult, -(__TSMAA_DYNAMIC_RANGE * basethreshold), basethreshold).xx;
	lumathreshold = max(lumathreshold, __TSMAA_MINIMUM_CONTRAST.xx);
	satthreshold = max(satthreshold, __TSMAA_MINIMUM_CONTRAST.xx);
	
	float2 edges = float(0.0).xx;
	
    float L = dotweight(0, middle, true, __TSMAA_LUMA_REF);
	
	float3 neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[0].xy).rgb;
	adaptationaverage += neighbor;
    float Lleft = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
    float Cleft = dotweight(middle, neighbor, false, 0);
    
	neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[0].zw).rgb;
	adaptationaverage += neighbor;
    float Ltop = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
    float Ctop = dotweight(middle, neighbor, false, 0);
    
    neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[1].xy).rgb;
	adaptationaverage += neighbor;
    float Lright = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
    float Cright = dotweight(middle, neighbor, false, 0);
	
	neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[1].zw).rgb;
	adaptationaverage += neighbor;
	float Lbottom = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
	float Cbottom = dotweight(middle, neighbor, false, 0);
	
	float maxL = TSMAAmax4(Lleft, Ltop, Lright, Lbottom);
	float maxC = TSMAAmax4(Cleft, Ctop, Cright, Cbottom);
	
	bool earlyExit = (abs(L - maxL) < lumathreshold.x) && (maxC < satthreshold.x);
	if (earlyExit) return float4(edges, TSMAA_Tex2D(TSMAAsamplerEdges, texcoord).ba);
	
	adaptationaverage /= 5.0;
	
	bool useluma = abs(L - maxL) > maxC;
	
	if (useluma) satthreshold = lumathreshold;
	else lumathreshold = satthreshold;
	
	float finalDelta;
	float4 delta;
	float scale;
	
	if (useluma)
	{
    	delta = abs(L - float4(Lleft, Ltop, Lright, Lbottom));
		edges = step(lumathreshold, delta.xy);
		float2 maxDelta = max(delta.xy, delta.zw);
		
		neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[2].xy).rgb;
		adaptationaverage += neighbor;
		float Lleftleft = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
		
		neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[2].zw).rgb;
		adaptationaverage += neighbor;
		float Ltoptop = dotweight(0, neighbor, true, __TSMAA_LUMA_REF);
		
		delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));
		maxDelta = max(maxDelta, delta.zw);
		finalDelta = max(maxDelta.x, maxDelta.y);
	}
	else
	{
		delta = float4(Cleft, Ctop, Cright, Cbottom);
	    edges = step(satthreshold, delta.xy);
		float2 maxDelta = max(delta.xy, delta.zw);
		
		neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[2].xy).rgb;
		adaptationaverage += neighbor;
		float Cleftleft = dotweight(middle, neighbor, false, 0);
		
		neighbor = TSMAA_DecodeTex2D(ReShade::BackBuffer, offset[2].zw).rgb;
		adaptationaverage += neighbor;
		float Ctoptop = dotweight(middle, neighbor, false, 0);
		
		delta.zw = abs(float2(Cleft, Ctop) - float2(Cleftleft, Ctoptop));
		maxDelta = max(maxDelta, delta.zw);
		finalDelta = max(maxDelta.x, maxDelta.y);
	}
	
	adaptationaverage /= 3.0;
	
	// scale always has a range of 1.5 to e+.5 regardless of the bit depth.
	scale = 0.5 + pow(clamp(log(rcp(dot(adaptationaverage, __TSMAA_LUMA_REF))), 1.0, BUFFER_COLOR_BIT_DEPTH), rcp(log(BUFFER_COLOR_BIT_DEPTH)));
	edges *= step(finalDelta, scale * delta.xy);
	
	float2 edgejitterN = TSMAAJitterEdgeDetection(texcoord, offset, TSMAAsamplerNegativeJitter, lumathreshold.x, useluma, scale);
	float2 edgejitterP = TSMAAJitterEdgeDetection(texcoord, offset, TSMAAsamplerPositiveJitter, lumathreshold.x, useluma, scale);
	float2 edgejitterNO = TSMAAJitterEdgeDetection(texcoord, offset, TSMAAsamplerNegativeJitterOdd, lumathreshold.x, useluma, scale);
	float2 edgejitterPO = TSMAAJitterEdgeDetection(texcoord, offset, TSMAAsamplerPositiveJitterOdd, lumathreshold.x, useluma, scale);
	
	edges = saturate(edges + edgejitterN + edgejitterP + edgejitterNO + edgejitterPO);
	
	return float4(edges, TSMAA_Tex2D(TSMAAsamplerEdges, texcoord).ba);
}

/////////////////////////////////////////////////////// ERROR REDUCTION ///////////////////////////////////////////////////////////////////
float4 TSMAATemporalEdgeAggregationPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 edges = TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).rg;
	float2 aggregate = saturate(edges + TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).ba + TSMAA_Tex2D(TSMAAsamplerEdgesX2, texcoord).rg + TSMAA_Tex2D(TSMAAsamplerEdgesX2, texcoord).ba);
	
	// skip checking neighbors if there's already no detected edge or no error margin check is desired
	if (!any(aggregate) || (__TSMAA_SM_ERRORMARGIN == -1.0)) return float4(aggregate, edges);
	
	float2 mask = float2(0.0, 1.0);
	if (all(aggregate)) mask = float2(0.0, 0.0);
	else if (aggregate.g > 0.0) mask = float2(1.0, 0.0);
	
    float2 a = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, -1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, -1)).ba) - mask);
    float2 c = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, -1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, -1)).ba) - mask);
    float2 g = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, 1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, 1)).ba) - mask);
    float2 i = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, 1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, 1)).ba) - mask);
    float2 b = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(0, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(0, -1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(0, -1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(0, -1)).ba) - mask);
    float2 d = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, 0)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(-1, 0)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, 0)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(-1, 0)).ba) - mask);
    float2 f = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, 0)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(1, 0)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, 0)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(1, 0)).ba) - mask);
    float2 h = saturate(saturate(TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(0, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerWeights, texcoord, int2(0, 1)).ba + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(0, 1)).rg + TSMAA_Tex2DOffset(TSMAAsamplerEdgesX2, texcoord, int2(0, 1)).ba) - mask);
    
    // this case isn't mathematically handled by the mask value, partials can pass
    if (all(aggregate))
    {
    	a = all(a) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	c = all(c) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	g = all(g) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	i = all(i) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	b = all(b) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	d = all(d) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	f = all(f) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    	h = all(h) ? float2(1.0, 1.0) : float2(0.0, 0.0);
    }
    
	float2 adjacentsum = a + c + g + i + b + d + f + h;

	bool validedge = !any(saturate(adjacentsum - __TSMAA_SM_ERRORMARGIN));
	if (validedge) return float4(aggregate, edges);
	else return float4(0.0, 0.0, edges);
}

/////////////////////////////////////////////////// BLEND WEIGHT CALCULATION //////////////////////////////////////////////////////////////
float4 TSMAABlendingWeightCalculationPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float2 pixcoord : TEXCOORD1, float4 offset[3] : TEXCOORD2) : SV_Target
{
    float4 weights = float(0.0).xxxx;
    float2 e = TSMAA_Tex2D(TSMAAsamplerEdges, texcoord).rg;
    bool2 edges = bool2(e.r > 0.0, e.g > 0.0);
	
	[branch] if (edges.g) 
	{
        weights.rg = TSMAACalculateDiagWeights(TSMAAsamplerEdges, TSMAAsamplerAreaRef, texcoord, e, 0);
        [branch] if (weights.r == -weights.g)
        {
			float3 coords = float3(TSMAASearchXLeft(TSMAAsamplerEdges, TSMAAsamplerSearchRef, offset[0].xy, offset[2].x), offset[1].y, TSMAASearchXRight(TSMAAsamplerEdges, TSMAAsamplerSearchRef, offset[0].zw, offset[2].y));
			float e1 = TSMAA_Tex2D(TSMAAsamplerEdges, coords.xy).r;
			float2 d = coords.xz;
			d = abs(round(mad(__TSMAA_BUFFER_INFO.zz, d, -pixcoord.xx)));
			float e2 = TSMAA_Tex2DOffset(TSMAAsamplerEdges, coords.zy, int2(1, 0)).r;
			weights.rg = TSMAAArea(TSMAAsamplerAreaRef, sqrt(d), e1, e2, 0.0);
			coords.y = texcoord.y;
			TSMAADetectHorizontalCornerPattern(TSMAAsamplerEdges, weights.rg, coords.xyzy, d);
		}
		else edges.r = false;
    }
	
	[branch] if (edges.r) 
	{
        float3 coords = float3(offset[0].x, TSMAASearchYUp(TSMAAsamplerEdges, TSMAAsamplerSearchRef, offset[1].xy, offset[2].z), TSMAASearchYDown(TSMAAsamplerEdges, TSMAAsamplerSearchRef, offset[1].zw, offset[2].w));
        float e1 = TSMAA_Tex2D(TSMAAsamplerEdges, coords.xy).g;
		float2 d = coords.yz;
        d = abs(round(mad(__TSMAA_BUFFER_INFO.ww, d, -pixcoord.yy)));
        float e2 = TSMAA_Tex2DOffset(TSMAAsamplerEdges, coords.xz, int2(0, 1)).g;
        weights.ba = TSMAAArea(TSMAAsamplerAreaRef, sqrt(d), e1, e2, 0.0);
        coords.x = texcoord.x;
        TSMAADetectVerticalCornerPattern(TSMAAsamplerEdges, weights.ba, coords.xyxz, d);
    }

    return weights;
}

//////////////////////////////////////////////////// NEIGHBORHOOD BLENDING ////////////////////////////////////////////////////////////////
float3 TSMAANeighborhoodBlendingPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float4 offset : TEXCOORD1) : SV_Target
{
    float4 m = float4(TSMAA_Tex2D(TSMAAsamplerWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).zx);
    float4 mo = float4(TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerOldWeights, texcoord).zx);
	m = max(m, mo);
	float3 resultAA = TSMAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	bool modifypixel = any(m);
	
	[branch] if (modifypixel)
	{
		resultAA = ConditionalDecode(resultAA);
        bool horiz = max(m.x, m.z) > max(m.y, m.w);
        float4 blendingOffset = float4(0.0, m.y, 0.0, m.w);
        float2 blendingWeight = m.yw;
        TSMAAMovc(bool(horiz).xxxx, blendingOffset, float4(m.x, 0.0, m.z, 0.0));
        TSMAAMovc(bool(horiz).xx, blendingWeight, m.xz);
        blendingWeight /= dot(blendingWeight, float(1.0).xx);
        float4 blendingCoord = mad(blendingOffset, float4(__TSMAA_BUFFER_INFO.xy, -__TSMAA_BUFFER_INFO.xy), texcoord.xyxy);
        resultAA = blendingWeight.x * TSMAA_DecodeTex2D(ReShade::BackBuffer, blendingCoord.xy).rgb * 0.5;
        resultAA += blendingWeight.x * TSMAA_DecodeTex2D(TSMAAsamplerNegativeJitter, blendingCoord.xy).rgb * 0.125;
        resultAA += blendingWeight.x * TSMAA_DecodeTex2D(TSMAAsamplerPositiveJitter, blendingCoord.xy).rgb * 0.125;
        resultAA += blendingWeight.x * TSMAA_DecodeTex2D(TSMAAsamplerNegativeJitterOdd, blendingCoord.xy).rgb * 0.125;
        resultAA += blendingWeight.x * TSMAA_DecodeTex2D(TSMAAsamplerPositiveJitterOdd, blendingCoord.xy).rgb * 0.125;
        resultAA += blendingWeight.y * TSMAA_DecodeTex2D(ReShade::BackBuffer, blendingCoord.zw).rgb * 0.5;
        resultAA += blendingWeight.y * TSMAA_DecodeTex2D(TSMAAsamplerNegativeJitter, blendingCoord.zw).rgb * 0.125;
        resultAA += blendingWeight.y * TSMAA_DecodeTex2D(TSMAAsamplerPositiveJitter, blendingCoord.zw).rgb * 0.125;
        resultAA += blendingWeight.y * TSMAA_DecodeTex2D(TSMAAsamplerNegativeJitterOdd, blendingCoord.zw).rgb * 0.125;
        resultAA += blendingWeight.y * TSMAA_DecodeTex2D(TSMAAsamplerPositiveJitterOdd, blendingCoord.zw).rgb * 0.125;
		resultAA = ConditionalEncode(resultAA);
    }
    
	return resultAA;
}

/////////////////////////////////////////////////// TEXTURE COPY FUNCTIONS ////////////////////////////////////////////////////////////////
float4 TSMAAWeightsCopyPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return TSMAA_Tex2D(TSMAAsamplerWeights, texcoord);
}

float4 TSMAABufferCopyPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return TSMAA_Tex2D(ReShade::BackBuffer, texcoord);
}

///////////////////////////////////////////////////// PAST-FRAME BLENDING /////////////////////////////////////////////////////////////////
float4 TSMAAPastFramePS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0, float4 offset : TEXCOORD1) : SV_Target
{
    float4 m = float4(TSMAA_Tex2D(TSMAAsamplerWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).zx);
    float4 mo = float4(TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerOldWeights, texcoord).zx);
	m = max(m, mo);
	float blendweight = dot(m, float4(1.0, 1.0, 1.0, 1.0)) / 4.0;
	return lerp (TSMAA_Tex2D(ReShade::BackBuffer, texcoord), TSMAA_Tex2D(TSMAAsamplerOldBuffer, texcoord), blendweight);
}

//////////////////////////////////////////////////////// SMOOTHING ////////////////////////////////////////////////////////////////////////
float3 TSMAASmoothingPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0, float4 offset : TEXCOORD1) : SV_Target
 {
    float4 m = float4(TSMAA_Tex2D(TSMAAsamplerWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).zx);
    float4 mo = float4(TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerOldWeights, texcoord).zx);
	m = max(m, mo);
	float maxblending = 0.5 + (0.25 * (dot(m, float4(1.0, 1.0, 1.0, 1.0)) / 4.0)) + (0.25 * TSMAAmax4(m.r, m.g, m.b, m.a));
    float3 middle = TSMAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 original = middle;
    
    middle = ConditionalDecode(middle);
	
	float lumaM = dot(middle, __TSMAA_LUMA_REF);
	
	float3 neighbor = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0, 1)).rgb;
    float lumaS = dotweight(middle, neighbor, true, __TSMAA_LUMA_REF);
    float chromaS = dotweight(middle, neighbor, false, __TSMAA_LUMA_REF);
    
	neighbor = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1, 0)).rgb;
    float lumaE = dotweight(middle, neighbor, true, __TSMAA_LUMA_REF);
    float chromaE = dotweight(middle, neighbor, false, __TSMAA_LUMA_REF);
    
	neighbor = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0,-1)).rgb;
    float lumaN = dotweight(middle, neighbor, true, __TSMAA_LUMA_REF);
    float chromaN = dotweight(middle, neighbor, false, __TSMAA_LUMA_REF);
    
	neighbor = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 0)).rgb;
    float lumaW = dotweight(middle, neighbor, true, __TSMAA_LUMA_REF);
    float chromaW = dotweight(middle, neighbor, false, __TSMAA_LUMA_REF);
    
    bool useluma = TSMAAmax4(abs(lumaS - lumaM), abs(lumaE - lumaM), abs(lumaN - lumaM), abs(lumaW - lumaM)) > TSMAAmax4(chromaS, chromaE, chromaN, chromaW);
    
    if (!useluma) { lumaS = chromaS; lumaE = chromaE; lumaN = chromaN; lumaW = chromaW; lumaM = 0.0; }
	
    float rangeMax = TSMAAmax5(lumaS, lumaE, lumaN, lumaW, lumaM);
    float rangeMin = TSMAAmin5(lumaS, lumaE, lumaN, lumaW, lumaM);
	
    float range = rangeMax - rangeMin;
    
	// early exit check 2
	bool SMAAedge = any(TSMAA_Tex2D(TSMAAsamplerEdges, texcoord).rg);
    bool earlyExit = (range < max(__TSMAA_EDGE_THRESHOLD, __TSMAA_MINIMUM_CONTRAST)) && (!SMAAedge);
	if (earlyExit) return original;
	
    float lumaNW = dotweight(middle, TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1,-1)).rgb, useluma, __TSMAA_LUMA_REF);
    float lumaSE = dotweight(middle, TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1, 1)).rgb, useluma, __TSMAA_LUMA_REF);
    float lumaNE = dotweight(middle, TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1,-1)).rgb, useluma, __TSMAA_LUMA_REF);
    float lumaSW = dotweight(middle, TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 1)).rgb, useluma, __TSMAA_LUMA_REF);
	
    bool horzSpan = (abs(mad(-2.0, lumaW, lumaNW + lumaSW)) + mad(2.0, abs(mad(-2.0, lumaM, lumaN + lumaS)), abs(mad(-2.0, lumaE, lumaNE + lumaSE)))) >= (abs(mad(-2.0, lumaS, lumaSW + lumaSE)) + mad(2.0, abs(mad(-2.0, lumaM, lumaW + lumaE)), abs(mad(-2.0, lumaN, lumaNW + lumaNE))));	
    float lengthSign = horzSpan ? BUFFER_RCP_HEIGHT : BUFFER_RCP_WIDTH;
	
	float2 lumaNP = float2(lumaN, lumaS);
	TSMAAMovc(bool(!horzSpan).xx, lumaNP, float2(lumaW, lumaE));
	
    float gradientN = lumaNP.x - lumaM;
    float gradientS = lumaNP.y - lumaM;
    float lumaNN = lumaNP.x + lumaM;
	
    if (abs(gradientN) >= abs(gradientS)) lengthSign = -lengthSign;
    else lumaNN = lumaNP.y + lumaM;
	
    float2 posB = texcoord;
	
	float texelsize = 0.5;

    float2 offNP = float2(0.0, BUFFER_RCP_HEIGHT * texelsize);
	TSMAAMovc(bool(horzSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * texelsize, 0.0));
	TSMAAMovc(bool2(!horzSpan, horzSpan), posB, float2(posB.x + lengthSign / 2.0, posB.y + lengthSign / 2.0));
	
    float2 posN = posB - offNP;
    float2 posP = posB + offNP;
    
    float lumaEndN = dotweight(middle, TSMAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, useluma, __TSMAA_LUMA_REF);
    float lumaEndP = dotweight(middle, TSMAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, useluma, __TSMAA_LUMA_REF);
	
    float gradientScaled = max(abs(gradientN), abs(gradientS)) * 0.25;
    bool lumaMLTZero = mad(0.5, -lumaNN, lumaM) < 0.0;
	
	lumaNN *= 0.5;
	
    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;
	
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
    bool doneNP;
	
	// 10 pixel scan distance
	uint iterations = 0;
	uint maxiterations = 20;
	
	[loop] while (iterations < maxiterations)
	{
		doneNP = doneN && doneP;
		if (doneNP) break;
		if (!doneN)
		{
			posN -= offNP;
			lumaEndN = dotweight(middle, TSMAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, useluma, __TSMAA_LUMA_REF);
			lumaEndN -= lumaNN;
			doneN = abs(lumaEndN) >= gradientScaled;
		}
		if (!doneP)
		{
			posP += offNP;
			lumaEndP = dotweight(middle, TSMAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, useluma, __TSMAA_LUMA_REF);
			lumaEndP -= lumaNN;
			doneP = abs(lumaEndP) >= gradientScaled;
		}
		iterations++;
    }
	
	float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
	TSMAAMovc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));
	
    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5);
    float subpixOut = pixelOffset * maxblending;
	
	[branch] if (!goodSpan)
	{
		subpixOut = mad(mad(2.0, lumaS + lumaE + lumaN + lumaW, lumaNW + lumaSE + lumaNE + lumaSW), 0.083333, -lumaM) * rcp(range); //ABC
		subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0) * maxblending * pixelOffset; // DEFGH
	}

    float2 posM = texcoord;
	TSMAAMovc(bool2(!horzSpan, horzSpan), posM, float2(posM.x + lengthSign * subpixOut, posM.y + lengthSign * subpixOut));
    
	return TSMAA_Tex2D(ReShade::BackBuffer, posM).rgb;
}

////////////////////////////////////////////////////////////// SOFTENING ////////////////////////////////////////////////////////////////
float3 TSMAASofteningPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0, float4 offset : TEXCOORD1) : SV_Target
{
	float3 a, b, c, d;
	
    float4 m = float4(TSMAA_Tex2D(TSMAAsamplerWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerWeights, texcoord).zx);
    float4 mo = float4(TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.xy).a, TSMAA_Tex2D(TSMAAsamplerOldWeights, offset.zw).g, TSMAA_Tex2D(TSMAAsamplerOldWeights, texcoord).zx);
	m = max(m, mo);
    bool horiz = max(m.x, m.z) > max(m.y, m.w);
	float maxblending = (0.5 * (dot(m, float4(1.0, 1.0, 1.0, 1.0)) / 4.0)) + (0.5 * TSMAAmax4(m.r, m.g, m.b, m.a));
	
// pattern:
//  e f g
//  h a b
//  i c d

#if __RENDERER__ >= 0xa000
	float4 cdbared = tex2Dgather(ReShade::BackBuffer, texcoord, 0);
	float4 cdbagreen = tex2Dgather(ReShade::BackBuffer, texcoord, 1);
	float4 cdbablue = tex2Dgather(ReShade::BackBuffer, texcoord, 2);
	a = float3(cdbared.w, cdbagreen.w, cdbablue.w);
	float3 original = a;
	a = ConditionalDecode(a);
	b = ConditionalDecode(float3(cdbared.z, cdbagreen.z, cdbablue.z));
	c = ConditionalDecode(float3(cdbared.x, cdbagreen.x, cdbablue.x));
	d = ConditionalDecode(float3(cdbared.y, cdbagreen.y, cdbablue.y));
#else
	a = TSMAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 original = a;
	a = ConditionalDecode(a);
	b = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(1, 0)).rgb;
	c = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(0, 1)).rgb;
	d = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(1, 1)).rgb;
#endif
	float3 e = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, -1)).rgb;
	float3 f = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(0, -1)).rgb;
	float3 g = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(1, -1)).rgb;
	float3 h = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 0)).rgb;
	float3 i = TSMAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 1)).rgb;
	
	float3 x1 = (e + f + g) / 3.0;
	float3 x2 = (h + a + b) / 3.0;
	float3 x3 = (i + c + d) / 3.0;
	float3 cap = (h + e + f + g + b) / 5.0;
	float3 bucket = (h + i + c + d + b) / 5.0;
	if (!horiz)
	{
		x1 = (e + h + i) / 3.0;
		x2 = (f + a + c) / 3.0;
		x3 = (g + b + d) / 3.0;
		cap = (f + e + h + i + c) / 5.0;
		bucket = (f + g + b + d + c) / 5.0;
	}
	float3 xy1 = (e + a + d) / 3.0;
	float3 xy2 = (i + a + g) / 3.0;
	float3 diamond = (h + f + c + b) / 4.0;
	float3 square = (e + g + i + d) / 4.0;
	
	float3 highterm = TSMAAmax9(x1, x2, x3, xy1, xy2, diamond, square, cap, bucket);
	float3 lowterm = TSMAAmin9(x1, x2, x3, xy1, xy2, diamond, square, cap, bucket);
	
	float3 localavg = ((a + x1 + x2 + x3 + xy1 + xy2 + diamond + square + cap + bucket) - (highterm + lowterm)) / 8.0;
	
	return lerp (original, ConditionalEncode(localavg), maxblending);
}

/***************************************************************************************************************************************/
/********************************************************** SMAA SHADER CODE END *******************************************************/
/***************************************************************************************************************************************/

technique TSMAA <
	ui_tooltip = "============================================================\n"
				 "Temporal Subpixel Morphological Anti-Aliasing uses past\n"
				 "frame data in all stages of the shader to try to enhance the\n"
				 "overall anti-aliasing effect. This is an experimental shader\n"
				 "and may not necessarily produce desirable output.\n"
				 "============================================================";
>
{
	pass CopyOldWeights
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAAWeightsCopyPS;
		RenderTarget = TSMAAoldblendTex;
		ClearRenderTargets = true;
	}
	pass TemporalEdgeTransferMerge
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAAMergeEdgesPS;
		RenderTarget = TSMAAblendTex;
		ClearRenderTargets = true;
	}
	pass TemporalEdgeTransferWrite
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAAWriteEdgesPS;
		RenderTarget = TSMAAedgesTexX2;
		ClearRenderTargets = true;
	}
	pass PositiveJitter
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAAPositiveJitterPS;
		RenderTarget = TSMAApositivejitterTex;
		ClearRenderTargets = true;
	}
	pass NegativeJitter
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAANegativeJitterPS;
		RenderTarget = TSMAAnegativejitterTex;
		ClearRenderTargets = true;
	}
	pass PositiveJitterOdd
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAAPositiveJitterOddPS;
		RenderTarget = TSMAApositivejitteroddTex;
		ClearRenderTargets = true;
	}
	pass NegativeJitterOdd
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAANegativeJitterOddPS;
		RenderTarget = TSMAAnegativejitteroddTex;
		ClearRenderTargets = true;
	}
	pass EdgeDetection
	{
		VertexShader = TSMAAEdgeDetectionVS;
		PixelShader = TSMAAHybridEdgeDetectionPS;
		RenderTarget = TSMAAblendTex;
		ClearRenderTargets = true;
	}
	pass TemporalEdgeAggregation
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAATemporalEdgeAggregationPS;
		RenderTarget = TSMAAedgesTex;
		ClearRenderTargets = true;
	}
	pass SMAABlendCalculation
	{
		VertexShader = TSMAABlendingWeightCalculationVS;
		PixelShader = TSMAABlendingWeightCalculationPS;
		RenderTarget = TSMAAblendTex;
		ClearRenderTargets = true;
	}
	pass SMAABlending
	{
		VertexShader = TSMAANeighborhoodBlendingVS;
		PixelShader = TSMAANeighborhoodBlendingPS;
	}
	pass Softening
	{
		VertexShader = TSMAANeighborhoodBlendingVS;
		PixelShader = TSMAASofteningPS;
	}
	pass Smoothing
	{
		VertexShader = TSMAANeighborhoodBlendingVS;
		PixelShader = TSMAASmoothingPS;
	}
	pass TemporalBlending
	{
		VertexShader = TSMAANeighborhoodBlendingVS;
		PixelShader = TSMAAPastFramePS;
	}
	pass SaveBuffer
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMAABufferCopyPS;
		RenderTarget = TSMAAoldbufferTex;
		ClearRenderTargets = true;
	}
}
