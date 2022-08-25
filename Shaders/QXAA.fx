/*               QXAA for ReShade 3.1.1+
 *
 *          (high-Quality approXimate Anti-Aliasing)
 *
 *		  Quality-optimized stand-alone FXAA shader
 *
 *			based on the implementation in HQAA
 *
 *                     by lordbean
 *
 */
 
 // This shader includes code adapted from:
 
 /**============================================================================


                    NVIDIA FXAA 3.11 by TIMOTHY LOTTES


------------------------------------------------------------------------------
COPYRIGHT (C) 2010, 2011 NVIDIA CORPORATION. ALL RIGHTS RESERVED.
------------------------------------------------------------------------------*/

/* AMD CONTRAST ADAPTIVE SHARPENING
// =======
// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// --------*/

 // All original code not attributed to the above authors is copyright (c) Derek Brush aka "lordbean" (derekbrush@gmail.com)

/** Permission is hereby granted, free of charge, to any person obtaining a copy
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

#ifndef QXAA_OUTPUT_MODE
	#define QXAA_OUTPUT_MODE 0
#endif //QXAA_TARGET_COLOR_SPACE

#ifndef QXAA_MULTISAMPLING
	#define QXAA_MULTISAMPLING 2
#endif

/////////////////////////////////////////////////////// GLOBAL SETUP OPTIONS //////////////////////////////////////////////////////////////

uniform int QXAAintroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.8";
	ui_text = "-------------------------------------------------------------------------\n"
			"      high-Quality approXimate Anti-Aliasing, a shader by lordbean\n"
			"             https://github.com/lordbean-git/reshade-shaders/\n"
			"-------------------------------------------------------------------------\n\n"
			"Currently Compiled Configuration:\n\n"
			#if QXAA_OUTPUT_MODE == 1
				"Output Mode:        HDR nits  *\n"
			#elif QXAA_OUTPUT_MODE == 2
				"Output Mode:     PQ accurate  *\n"
			#elif QXAA_OUTPUT_MODE == 3
				"Output Mode:       PQ approx  *\n"
			#else
				"Output Mode:       Gamma 2.2\n"
			#endif //QXAA_TARGET_COLOR_SPACE
			#if QXAA_MULTISAMPLING < 2
				"Multisampling:           off  *\n"
			#elif QXAA_MULTISAMPLING > 3
				"Multisampling:            4x  *\n"
			#elif QXAA_MULTISAMPLING > 2
				"Multisampling:            3x  *\n"
			#elif QXAA_MULTISAMPLING > 1
				"Multisampling:            2x\n"
			#endif //QXAA_MULTISAMPLING
			
			"\nRemarks:\n"
			
			"\nQXAA sharpening/tonemap processing has no performance penalty when\n"
			"disabled. It shares the same pass used to run Hysteresis correction and\n"
			"is compiled out of the shader when ReShade is in Performance Mode.\n"
			
			"\nTry using more than two multisamples if you have GPU headroom! Quality\n"
			"typically increases slightly with each extra pass. Valid up to 4.\n"
			"\nValid Output Modes (QXAA_OUTPUT_MODE):\n"
			"0: Gamma 2.2 (default)\n"
			"1: HDR, direct nits scale\n"
			"2: HDR10, accurate encoding\n"
			"3: HDR10, fast encoding\n"
			"\n-------------------------------------------------------------------------"
			"\nSee the 'Preprocessor definitions' section for color & feature toggles.\n"
			"-------------------------------------------------------------------------";
	ui_tooltip = "Because it worked so well when it was an accident";
	ui_category = "About";
	ui_category_closed = true;
>;

#if QXAA_OUTPUT_MODE == 1
uniform float QxaaHdrNits < 
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 500.0; ui_max = 10000.0; ui_step = 100.0;
	ui_label = "HDR Nits";
	ui_tooltip = "If the scene brightness changes after QXAA runs, try\n"
				 "adjusting this value up or down until it looks right.";
> = 1000.0;
#endif //QXAA_TARGET_COLOR_SPACE

uniform int QxaaAboutEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float QxaaThreshold <
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast (luma difference) required to be considered an edge.\nQXAA does not do dynamic thresholding, but it\nhandles extreme settings very well.";
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 0.015;

uniform uint QxaaScanIterations <
	ui_type = "slider";
	ui_min = 1; ui_max = 200; ui_step = 1;
	ui_label = "Gradient Scan Iterations";
	ui_tooltip = "Edge gradient search iterations.\nNote that this is per-pass, not total.";
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 30;

uniform float QxaaTexelSize <
	ui_type = "slider";
	ui_min = 0.1; ui_max = 2.0; ui_step = 0.001;
	ui_label = "Edge Gradient Texel Size";
	ui_tooltip = "Determines how far along an edge QXAA will move\nfrom one scan iteration to the next.\n\nLower = slower, more accurate\nHigher = faster, more artifacts";
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 0.333333;

uniform float QxaaStrength <
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "Effect Strength";
	ui_tooltip = "Although more costly, you can get better results\nby using multisampling and a lower strength.";
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 100;

uniform float QxaaHysteresisStrength <
	ui_spacing = 3;
	ui_label = "Hysteresis Strength";
	ui_tooltip = "Performs detail reconstruction to minimize the\n"
				 "visual impact of artifacts that may be caused\n"
				 "by QXAA.";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 0.125;

uniform float QxaaHysteresisFudgeFactor <
	ui_label = "Hysteresis Fudge Factor";
	ui_tooltip = "Pixels that have changed less than this\n"
				 "amount will be skipped.";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.2; ui_step = 0.001;
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 0.04;

uniform float QxaaNoiseControlStrength <
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "Noise Control Strength\n\n";
	ui_tooltip = "Determines how strongly QXAA will clamp its output\n"
				 "when the resulting blend will have a high luma delta.\n"
				 "Useful when using more than two anti-aliasing passes.";
	ui_category = "Anti-Aliasing";
	ui_category_closed = true;
> = 0;

uniform bool QxaaEnableSharpening <
	ui_spacing = 3;
	ui_label = "Enable Sharpening";
	ui_tooltip = "Performs fast CAS sharpening when enabled.";
	ui_category = "Sharpening";
	ui_category_closed = true;
> = false;

uniform float QxaaSharpenerStrength <
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Strength";
	ui_tooltip = "Amount of sharpening to apply. 1.0 is default.";
	ui_category = "Sharpening";
	ui_category_closed = true;
> = 0.625;

uniform float QxaaSharpenerAdaptation <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Contrast Adaptation\n\n";
	ui_tooltip = "Adjusts the amount of high-contrast sharpening\n"
				 "applied. 0.0 is default, above 0.5 is not recommended.";
	ui_category = "Sharpening";
	ui_category_closed = true;
> = 0.125;

uniform bool QxaaEnableTonemap <
	ui_label = "Enable Tonemap Processing";
	ui_spacing = 3;
	ui_tooltip = "Enables processing of this category. Individual\n"
				 "effects will still be compiled out when they\n"
				 "do not result in a change to the output.";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = false;
				 
uniform uint QxaaTonemapping <
	ui_spacing = 3;
	ui_type = "combo";
	ui_label = "Tonemapping Function";
	ui_items = "None\0Reinhard Extended\0Reinhard Luminance\0Reinhard-Jodie\0Uncharted 2\0ACES approx\0Logarithmic Fake HDR\0Dynamic Range Compression\0";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = 0;

uniform float QxaaTonemappingParameter <
	ui_type = "slider";
	ui_label = "Tonemapping Function Parameter";
	ui_tooltip = "Input parameter for tonemapping functions that use one.\n"
				 "Logarithmic functions will generate artifacts if the\n"
				 "value exceeds euler's number (~2.718282).";
	ui_min = 0.0; ui_max = 2.718; ui_step = 0.001;
	ui_category = "Tonemap";
	ui_category_closed = true;
> = 1.0;

uniform float QxaaGainStrength <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_spacing = 3;
	ui_label = "Brightness Gain";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = 0.0;

uniform bool QxaaGainLowLumaCorrection <
	ui_label = "Contrast Washout Correction";
	ui_tooltip = "Calculates new expected black point after gain\n"
				 "and adjusts saturation levels to reduce perceived\n"
				 "contrast washout (or 'airy' look).";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = false;

uniform float QxaaBlueLightFilter <
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Blue Light Filter";
	ui_tooltip = "Reduces strength of blue light for eye comfort.\n";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = 0.0;

uniform float QxaaSaturationStrength <
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Saturation\n\n";
	ui_tooltip = "Increases or decreases saturation of the scene.\n"
				 "Higher makes colors appear more vibrant, lower\n"
				 "washes them out. 0.5 is neutral.";
	ui_category = "Tonemap";
	ui_category_closed = true;
> = 0.5;

uniform int QxaaOptionsEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP END ****************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SYNTAX SETUP START *************************************************************/
/*****************************************************************************************************************************************/

#define __QXAA_MIN_STEP rcp(pow(2., BUFFER_COLOR_BIT_DEPTH))
#define __QXAA_LUMA_REF float3(0.2126, 0.7152, 0.0722)
#define __QXAA_GREEN_LUMA float3(1./5., 7./10., 1./10.)
#define __QXAA_RED_LUMA float3(5./8., 1./4., 1./8.)
#define __QXAA_BLUE_LUMA float3(1./8., 3./8., 1./2.)
#define __QXAA_CONST_E 2.7182818284590452353602874713527
#define __QXAA_CONST_HALFROOT2 (sqrt(2.)/2.)

#define QXAA_Tex2D(tex, coord) tex2Dlod(tex, (coord).xyxy)
#define QXAA_Tex2DOffset(tex, coord, offset) tex2Dlodoffset(tex, (coord).xyxy, offset)
#define QXAA_DecodeTex2D(tex, coord) ConditionalDecode(tex2Dlod(tex, (coord).xyxy))
#define QXAA_DecodeTex2DOffset(tex, coord, offset) ConditionalDecode(tex2Dlodoffset(tex, (coord).xyxy, offset))

#define QXAAmax3(x,y,z) max(max(x,y),z)
#define QXAAmax4(w,x,y,z) max(max(w,x),max(y,z))
#define QXAAmax5(v,w,x,y,z) max(max(max(v,w),x),max(y,z))
#define QXAAmax6(u,v,w,x,y,z) max(max(max(u,v),max(w,x)),max(y,z))
#define QXAAmax7(t,u,v,w,x,y,z) max(max(max(t,u),max(v,w)),max(max(x,y),z))
#define QXAAmax8(s,t,u,v,w,x,y,z) max(max(max(s,t),max(u,v)),max(max(w,x),max(y,z)))
#define QXAAmax9(r,s,t,u,v,w,x,y,z) max(max(max(max(r,s),t),max(u,v)),max(max(w,x),max(y,z)))
#define QXAAmax10(q,r,s,t,u,v,w,x,y,z) max(max(max(max(q,r),max(s,t)),max(u,v)),max(max(w,x),max(y,z)))
#define QXAAmax11(p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(p,q),max(r,s)),max(max(t,u),v)),max(max(w,x),max(y,z)))
#define QXAAmax12(o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(o,p),max(q,r)),max(max(s,t),max(u,v))),max(max(w,x),max(y,z)))
#define QXAAmax13(n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(n,o),max(p,q)),max(max(r,s),max(t,u))),max(max(max(v,w),x),max(y,z)))
#define QXAAmax14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(m,n),max(o,p)),max(max(q,r),max(s,t))),max(max(max(u,v),max(w,x)),max(y,z)))

#define QXAAmin3(x,y,z) min(min(x,y),z)
#define QXAAmin4(w,x,y,z) min(min(w,x),min(y,z))
#define QXAAmin5(v,w,x,y,z) min(min(min(v,w),x),min(y,z))
#define QXAAmin6(u,v,w,x,y,z) min(min(min(u,v),min(w,x)),min(y,z))
#define QXAAmin7(t,u,v,w,x,y,z) min(min(min(t,u),min(v,w)),min(min(x,y),z))
#define QXAAmin8(s,t,u,v,w,x,y,z) min(min(min(s,t),min(u,v)),min(min(w,x),min(y,z)))
#define QXAAmin9(r,s,t,u,v,w,x,y,z) min(min(min(min(r,s),t),min(u,v)),min(min(w,x),min(y,z)))
#define QXAAmin10(q,r,s,t,u,v,w,x,y,z) min(min(min(min(q,r),min(s,t)),min(u,v)),min(min(w,x),min(y,z)))
#define QXAAmin11(p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(p,q),min(r,s)),min(min(t,u),v)),min(min(w,x),min(y,z)))
#define QXAAmin12(o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(o,p),min(q,r)),min(min(s,t),min(u,v))),min(min(w,x),min(y,z)))
#define QXAAmin13(n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(n,o),min(p,q)),min(min(r,s),min(t,u))),min(min(min(v,w),x),min(y,z)))
#define QXAAmin14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(m,n),min(o,p)),min(min(q,r),min(s,t))),min(min(min(u,v),min(w,x)),min(y,z)))

#define QXAAdotmax(x) max(max((x).r, (x).g), (x).b)
#define QXAAdotmin(x) min(min((x).r, (x).g), (x).b)

/*****************************************************************************************************************************************/
/********************************************************* SYNTAX SETUP END **************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SUPPORT CODE START *************************************************************/
/*****************************************************************************************************************************************/

/////////////////////////////////////////////////////// TRANSFER FUNCTIONS ////////////////////////////////////////////////////////////////

#if QXAA_OUTPUT_MODE == 2
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
#endif //QXAA_OUTPUT_MODE == 2

#if QXAA_OUTPUT_MODE == 3
float fastencodePQ(float x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float y = saturate(x) * 4.728708;
	float z = 500.0;
#else
	float y = saturate(x) * 10.0;
	float z = 10000.0;
#endif
	y *= y;
	y *= y;
	return clamp(y, 0.0, z);
}
float2 fastencodePQ(float2 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float2 y = saturate(x) * 4.728708;
	float z = 500.0;
#else
	float2 y = saturate(x) * 10.0;
	float z = 10000.0;
#endif
	y *= y;
	y *= y;
	return clamp(y, 0.0, z);
}
float3 fastencodePQ(float3 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float3 y = saturate(x) * 4.728708;
	float z = 500.0;
#else
	float3 y = saturate(x) * 10.0;
	float z = 10000.0;
#endif
	y *= y;
	y *= y;
	return clamp(y, 0.0, z);
}
float4 fastencodePQ(float4 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	float4 y = saturate(x) * 4.728708;
	float z = 500.0;
#else
	float4 y = saturate(x) * 10.0;
	float z = 10000.0;
#endif
	y *= y;
	y *= y;
	return clamp(y, 0.0, z);
}

float fastdecodePQ(float x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 10000.0))) / 10.0));
#endif
}
float2 fastdecodePQ(float2 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 10000.0))) / 10.0));
#endif
}
float3 fastdecodePQ(float3 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 10000.0))) / 10.0));
#endif
}
float4 fastdecodePQ(float4 x)
{
#if BUFFER_COLOR_BIT_DEPTH == 10
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 500.0))) / 4.728708));
#else
	return saturate((sqrt(sqrt(clamp(x, __QXAA_MIN_STEP, 10000.0))) / 10.0));
#endif
}
#endif //QXAA_OUTPUT_MODE == 3

#if QXAA_OUTPUT_MODE == 1
float encodeHDR(float x)
{
	return saturate(x) * QxaaHdrNits;
}
float2 encodeHDR(float2 x)
{
	return saturate(x) * QxaaHdrNits;
}
float3 encodeHDR(float3 x)
{
	return saturate(x) * QxaaHdrNits;
}
float4 encodeHDR(float4 x)
{
	return saturate(x) * QxaaHdrNits;
}

float decodeHDR(float x)
{
	return saturate(x / QxaaHdrNits);
}
float2 decodeHDR(float2 x)
{
	return saturate(x / QxaaHdrNits);
}
float3 decodeHDR(float3 x)
{
	return saturate(x / QxaaHdrNits);
}
float4 decodeHDR(float4 x)
{
	return saturate(x / QxaaHdrNits);
}
#endif //QXAA_OUTPUT_MODE == 1

float ConditionalEncode(float x)
{
#if QXAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float2 ConditionalEncode(float2 x)
{
#if QXAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float3 ConditionalEncode(float3 x)
{
#if QXAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}
float4 ConditionalEncode(float4 x)
{
#if QXAA_OUTPUT_MODE == 1
	return encodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return encodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastencodePQ(x);
#else
	return x;
#endif
}

float ConditionalDecode(float x)
{
#if QXAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float2 ConditionalDecode(float2 x)
{
#if QXAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float3 ConditionalDecode(float3 x)
{
#if QXAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}
float4 ConditionalDecode(float4 x)
{
#if QXAA_OUTPUT_MODE == 1
	return decodeHDR(x);
#elif QXAA_OUTPUT_MODE == 2
	return decodePQ(x);
#elif QXAA_OUTPUT_MODE == 3
	return fastdecodePQ(x);
#else
	return x;
#endif
}

////////////////////////////////////////////////////// HELPER FUNCTIONS ////////////////////////////////////////////////////////////////

void QXAAMovc(bool2 cond, inout float2 variable, float2 value)
{
    [flatten] if (cond.x) variable.x = value.x;
    [flatten] if (cond.y) variable.y = value.y;
}
void QXAAMovc(bool4 cond, inout float4 variable, float4 value)
{
    QXAAMovc(cond.xy, variable.xy, value.xy);
    QXAAMovc(cond.zw, variable.zw, value.zw);
}

float lxor(float x, float y)
{
	bool valid = (x == 0.0) ? ((y == 0.0) ? false : true) : ((y == 0.0) ? true : false);
	if (valid) return x + y;
	else return 0.0;
}
float2 lxor(float2 x, float2 y)
{
	return float2(lxor(x.x, y.x), lxor(x.y, y.y));
}
float3 lxor(float3 x, float3 y)
{
	return float3(lxor(x.x, y.x), lxor(x.yz, y.yz));
}
float4 lxor(float4 x, float4 y)
{
	return float4(lxor(x.xy, y.xy), lxor(x.zw, y.zw));
}

/*
Ey = 0.299R+0.587G+0.114B
Ecr = 0.713(R - Ey) = 0.500R-0.419G-0.081B
Ecb = 0.564(B - Ey) = -0.169R-0.331G+0.500B

where Ey, R, G and B are in the range [0,1] and Ecr and Ecb are in the range [-0.5,0.5]
*/
float3 RGBtoYUV(float3 input)
{
	float3 argb = saturate(input); // value must be between [0,1]
	float3 yuv;
	
	yuv.x = saturate((0.299 * argb.r) + (0.587 * argb.g) + (0.114 * argb.b));
	yuv.y = clamp(0.713 * (argb.r - yuv.x), -0.5, 0.5);
	yuv.z = clamp(0.564 * (argb.b - yuv.x), -0.5, 0.5);
	
	return yuv;
}
float4 RGBtoYUV(float4 input)
{
	return float4(RGBtoYUV(input.rgb), input.a);
}

/*
/* reverse transfer accomplished by solving original equations for R and B and then
/* using those channels to solve the luma equation for G
*/
float3 YUVtoRGB(float3 yuv)
{
	yuv.x = saturate(yuv.x);
	yuv.yz = clamp(yuv.yz, -0.5, 0.5);
	
	float3 argb;
	
	argb.r = (1.402525 * yuv.y) + yuv.x;
	argb.b = (1.77305 * yuv.z) + yuv.x;
	argb.g = (1.703578 * yuv.x) - (0.50937 * argb.r) - (0.194208 * argb.b);
	
	return argb;
}
float4 YUVtoRGB(float4 yuv)
{
	return float4(YUVtoRGB(yuv.xyz), yuv.a);
}

float dotsat(float3 x)
{
	// trunc(xl) only = 1 when x = float3(1,1,1)
	// float3(1,1,1) produces 0/0 in the original calculation
	// this should change it to 0/1 to avoid the possible NaN out
	float xl = dot(x, __QXAA_LUMA_REF);
	return ((QXAAdotmax(x) - QXAAdotmin(x)) / (1.0 - (2.0 * xl - 1.0) + trunc(xl)));
}
float dotsat(float4 x)
{
	return dotsat(x.rgb);
}

float3 AdjustSaturation(float3 input, float requestedadjustment)
{
	// change to YCrCb (component) color space
	// access: x=Y, y=Cr, z=Cb
	float3 yuv = RGBtoYUV(input);
	
	// convert absolute saturation to adjustment delta
	float adjustment = 2.0 * (saturate(requestedadjustment) - 0.5);
	
	// for a positive adjustment, determine ceiling and clamp if necessary
	if (adjustment > 0.0)
	{
		float maxboost = 1.0 / (max(abs(yuv.y), abs(yuv.z)) / 0.5);
		if (adjustment > maxboost) adjustment = maxboost;
	}
	
	// compute delta Cr,Cb
	yuv.y = yuv.y > 0.0 ? (yuv.y + (adjustment * yuv.y)) : (yuv.y - (adjustment * abs(yuv.y)));
	yuv.z = yuv.z > 0.0 ? (yuv.z + (adjustment * yuv.z)) : (yuv.z - (adjustment * abs(yuv.z)));
	
	// change back to ARGB color space
	return YUVtoRGB(yuv);
}

float3 tonemap_adjustluma(float3 x, float xl_out)
{
	float xl = dot(x, __QXAA_LUMA_REF);
	return x * (xl_out / xl);
}
float3 reinhard_jodie(float3 x)
{
	float xl = dot(x, __QXAA_LUMA_REF);
	float3 xv = x / (1.0 + x);
	return lerp(x / (1.0 + xl), xv, xv);
}
float3 extended_reinhard(float3 x)
{
	float whitepoint = QxaaTonemappingParameter;
	float3 numerator = x * (1.0 + (x / (whitepoint * whitepoint)));
	return numerator / (1.0 + x);
}
float3 extended_reinhard_luma(float3 x)
{
	float whitepoint = QxaaTonemappingParameter;
	float xl = dot(x, __QXAA_LUMA_REF);
	float numerator = xl * (1.0 + (xl / (whitepoint * whitepoint)));
	float xl_shift = numerator / (1.0 + xl);
	return tonemap_adjustluma(x, xl_shift);
}
float3 uncharted2_partial(float3 x)
{
	float A = 0.15;
	float B = 0.5;
	float C = 0.1;
	float D = 0.2;
	float E = 0.02;
	float F = 0.3;
	
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}
float3 uncharted2_filmic(float3 x)
{
	float exposure_bias = 2.0;
	float3 curr = uncharted2_partial(x * exposure_bias);
	float3 whitescale = rcp(uncharted2_partial(float(11.2).xxx));
	return curr * whitescale;
}
float3 aces_approx(float3 x)
{
	float3 xout = x * 0.6;
	float A = 2.51;
	float B = 0.03;
	float C = 2.43;
	float D = 0.59;
	float E = 0.14;
	
	return saturate((xout*(A*xout+B))/(xout*(C*xout+D)+E));
}
float3 logarithmic_fake_hdr(float3 x)
{
	return saturate(pow(abs(__QXAA_CONST_E + (QxaaTonemappingParameter * (0.5 - log2(1.0 + dot(x, __QXAA_LUMA_REF))))), log(clamp(x, __QXAA_MIN_STEP, 1.0))));
}
float3 logarithmic_range_compression(float3 x)
{
	float luma = dot(x, __QXAA_LUMA_REF);
	float offset = QxaaTonemappingParameter * (0.5 - luma);
	float3 result = pow(abs(__QXAA_CONST_E - offset), log(clamp(x, __QXAA_MIN_STEP, 1.0)));
	return saturate(result);
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

texture QXAAHysteresisInfoTex
#if __RESHADE__ < 50000
< pooled = false; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = R32F;
};

sampler OriginalLuma { Texture = QXAAHysteresisInfoTex; };

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

/***************************************************************************************************************************************/
/********************************************************** QXAA SHADER CODE START *****************************************************/
/***************************************************************************************************************************************/

float QXAAInitPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 pixel = QXAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	return dot(ConditionalDecode(pixel), __QXAA_LUMA_REF);
}

float3 QXAAPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
 {
    float3 original = QXAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	
	//determine detection method
	float edgethreshold = QxaaThreshold;
	float3 middle = ConditionalDecode(original);
	float maxchannel = QXAAmax3(middle.r, middle.g, middle.b);
    float3 ref;
	if (middle.g == maxchannel) ref = __QXAA_GREEN_LUMA;
	else if (middle.r == maxchannel) ref = __QXAA_RED_LUMA;
	else ref = __QXAA_BLUE_LUMA;
	float lumaM = dot(middle, ref);
	float2 lengthSign = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	
	//setup cartesian neighbor data
    float lumaS = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(0.0, lengthSign.y)).rgb, ref);
    float lumaE = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(lengthSign.x, 0.0)).rgb, ref);
    float lumaN = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(0.0, -lengthSign.y)).rgb, ref);
    float lumaW = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(-lengthSign.x, 0.0)).rgb, ref);
    float4 crossdelta = abs(lumaM - float4(lumaS, lumaE, lumaN, lumaW));
	float2 weightsHV = float2(crossdelta.x + crossdelta.z, crossdelta.y + crossdelta.w);
    
    // pattern
    // * z *
    // w * y
    // * x *
    
	//setup diagonal neighbor data
	//diagonal reads are performed at the same distance from origin as cartesian reads
	//solve using pythagorean theorem yields 1/2 sqrt(2) to match horz/vert distance
	//this bakes in a weighting bias to horz/vert giving diag code priority only when
	//it's the only viable option
	float2 diagstep = lengthSign * __QXAA_CONST_HALFROOT2;
    float lumaNW = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord - diagstep).rgb, ref);
    float lumaSE = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + diagstep).rgb, ref);
    float lumaNE = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(diagstep.x, -diagstep.y)).rgb, ref);
    float lumaSW = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + float2(-diagstep.x, diagstep.y)).rgb, ref);
    float4 diagdelta = abs(lumaM - float4(lumaNW, lumaSE, lumaNE, lumaSW));
	float2 weightsDI = float2(diagdelta.w + diagdelta.z, diagdelta.x + diagdelta.y);
    
    // pattern
    // x * z
    // * * *
    // w * y
    
	//detect edge pattern
	bool diagSpan = max(weightsDI.x, weightsDI.y) * float(bool(lxor(weightsDI.x, weightsDI.y))) > max(weightsHV.x, weightsHV.y);
	bool inverseDiag = diagSpan && (weightsDI.y > weightsDI.x);
	bool horzSpan = weightsHV.x > weightsHV.y;
	
	// get highest single-point delta
	float4 crosscheck = max(crossdelta, diagdelta);
	float2 stepcheck = max(crosscheck.xy, crosscheck.zw);
    float range = max(stepcheck.x, stepcheck.y);
    
    // abort if not above edge threshold
	if (range < edgethreshold) return original;
	
	//setup scanning gradient
	float2 lumaNP = float2(lumaN, lumaS);
	QXAAMovc(!horzSpan.xx, lumaNP, float2(lumaW, lumaE));
	QXAAMovc(diagSpan.xx, lumaNP, float2(lumaNW, lumaSE));
	QXAAMovc((diagSpan && inverseDiag).xx, lumaNP, float2(lumaSW, lumaNE));
    float gradientN = abs(lumaNP.x - lumaM);
    float gradientP = abs(lumaNP.y - lumaM);
    float lumaNN = lumaNP.x + lumaM;
    if (gradientN >= gradientP && !diagSpan) lengthSign = -lengthSign;
    if (diagSpan && inverseDiag) lengthSign.y = -lengthSign.y;
    if (gradientP > gradientN) lumaNN = lumaNP.y + lumaM;
    float gradientScaled = max(gradientN, gradientP) * 0.25;
    bool lumaMLTZero = mad(0.5, -lumaNN, lumaM) < 0.0;
	
	//setup gradient scanning texel step
    float2 posB = texcoord;
	float texelsize = QxaaTexelSize;
    float2 offNP = float2(0.0, BUFFER_RCP_HEIGHT * texelsize);
	QXAAMovc(bool(horzSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * texelsize, 0.0));
	QXAAMovc(bool(diagSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * texelsize, BUFFER_RCP_HEIGHT * texelsize));
	if (diagSpan && inverseDiag) offNP.y = -offNP.y;
	
	// 1/3 is the magic number here, I don't know how NVIDIA got 0.5.	
	QXAAMovc(bool2(!horzSpan || diagSpan, horzSpan || diagSpan), posB, float2(posB.x + lengthSign.x * 0.333333, posB.y + lengthSign.y * 0.333333));
	
	//init scan tracking and do first iteration
    float2 posN = posB - offNP;
    float2 posP = posB + offNP;
    float lumaEndN = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, ref);
    float lumaEndP = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, ref);
	lumaNN *= 0.5;
    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
	
	//perform gradient scanning
	uint iterations = 0;
	uint maxiterations = QxaaScanIterations;
	[loop] while (iterations < maxiterations)
	{
		if (doneN && doneP) break;
		if (!doneN)
		{
			posN -= offNP;
			lumaEndN = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, ref);
			lumaEndN -= lumaNN;
			doneN = abs(lumaEndN) >= gradientScaled;
		}
		if (!doneP)
		{
			posP += offNP;
			lumaEndP = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, ref);
			lumaEndP -= lumaNN;
			doneP = abs(lumaEndP) >= gradientScaled;
		}
		iterations++;
    }
	
	//determine resulting distance from origin
	//pythagorean theorem used to generate diagonal N/P distances [hypotenuse = sqrt(pow(x,2) + pow(y,2))]
	float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
	QXAAMovc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));
	QXAAMovc(bool(diagSpan).xx, dstNP, float2(sqrt(pow(abs(texcoord.y - posN.y), 2.0) + pow(abs(texcoord.x - posN.x), 2.0)), sqrt(pow(abs(posP.y - texcoord.y), 2.0) + pow(abs(posP.x - texcoord.x), 2.0))));
	
	//perform noise control calculations
    float endluma = (dstNP.x < dstNP.y) ? lumaEndN : lumaEndP;
    bool goodSpan = endluma < 0.0 != lumaMLTZero;
    float blendclamp = goodSpan ? 1.0 : (1.0 - abs(endluma - lumaM) * (QxaaNoiseControlStrength / 100.));
	
	//calculate offset from origin
    float pixelOffset = abs(mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5)) * clamp(QxaaStrength / 100.0, 0.0, blendclamp);
	
	//calculate offset weight
    float subpixOut = 1.0;
	if (!goodSpan) // bad span
	{
		subpixOut = mad(mad(2.0, lumaS + lumaE + lumaN + lumaW, lumaNW + lumaSE + lumaNE + lumaSW), 0.083333, -lumaM) * (1.0 / range); //ABC
		subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0); // DEFGH
	}
	subpixOut *= pixelOffset;
	
	//generate final sampling coordinates
    float2 posM = texcoord;
	QXAAMovc(bool2(!horzSpan || diagSpan, horzSpan || diagSpan), posM, float2(posM.x + lengthSign.x * subpixOut, posM.y + lengthSign.y * subpixOut));
    
	//fart result
	return QXAA_Tex2D(ReShade::BackBuffer, posM).rgb;
}

// ordering = sharpen > hysteresis > tonemap > brightness > blue filter > saturation
float3 QXAAHysteresisPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 pixel = QXAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 original = pixel;
	float preluma = QXAA_Tex2D(OriginalLuma, texcoord).r;
	bool altered = false;
	
	if (!QxaaEnableSharpening) pixel = ConditionalDecode(pixel);
	if (QxaaEnableSharpening)
	{
		float2 hvstep = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
		float2 diagstep = hvstep * __QXAA_CONST_HALFROOT2;
		float3 casdot = pixel;
		float3 a = QXAA_Tex2D(ReShade::BackBuffer, texcoord - diagstep).rgb;
		float3 c = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(diagstep.x, -diagstep.y)).rgb;
		float3 g = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-diagstep.x, diagstep.y)).rgb;
		float3 i = QXAA_Tex2D(ReShade::BackBuffer, texcoord + diagstep).rgb;
		float3 b = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0.0, -hvstep.y)).rgb;
		float3 d = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-hvstep.x, 0.0)).rgb;
		float3 f = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(hvstep.x, 0.0)).rgb;
		float3 h = QXAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0.0, hvstep.y)).rgb;
	
		float3 mnRGB = QXAAmin5(d, casdot, f, b, h);
		float3 mnRGB2 = QXAAmin5(mnRGB, a, c, g, i);

		float3 mxRGB = QXAAmax5(d, casdot, f, b, h);
		float3 mxRGB2 = QXAAmax5(mxRGB,a,c,g,i);
	
		casdot = ConditionalDecode(casdot);
		mnRGB = ConditionalDecode(mnRGB);
		mnRGB2 = ConditionalDecode(mnRGB2);
		mxRGB = ConditionalDecode(mxRGB);
		mxRGB2 = ConditionalDecode(mxRGB2);
	
		mnRGB += mnRGB2;
		mxRGB += mxRGB2;
	
		float3 ampRGB = 1.0 / sqrt(saturate(min(mnRGB, 2.0 - mxRGB) * (1.0 / mxRGB)));    
		float3 wRGB = -(1.0 / (ampRGB * mad(-3.0, QxaaSharpenerAdaptation, 8.0)));
		float3 window = (b + d) + (f + h);
	
		float3 outColor = saturate(mad(window, wRGB, casdot) * (1.0 / mad(4.0, wRGB, 1.0)));
		casdot = lerp(casdot, outColor, QxaaSharpenerStrength);
	
		pixel = casdot;
		altered = true;
	}
	
	float hysteresis = (dot(pixel, __QXAA_LUMA_REF) - preluma) * QxaaHysteresisStrength;
	if (abs(hysteresis) > QxaaHysteresisFudgeFactor)
	{
		bool3 truezero = !pixel;
		pixel = pow(abs(1.0 + hysteresis) * 2.0, log2(pixel));
		pixel *= float3(!truezero);
		altered = true;
	}
	
	if (QxaaEnableTonemap && (QxaaTonemapping > 0))
	{
		bool3 truezero = !pixel;
		if (QxaaTonemapping == 1) pixel = extended_reinhard(pixel);
		if (QxaaTonemapping == 2) pixel = extended_reinhard_luma(pixel);
		if (QxaaTonemapping == 3) pixel = reinhard_jodie(pixel);
		if (QxaaTonemapping == 4) pixel = uncharted2_filmic(pixel);
		if (QxaaTonemapping == 5) pixel = aces_approx(pixel);
		if (QxaaTonemapping == 6) pixel = logarithmic_fake_hdr(pixel) * float3(!truezero);
		if (QxaaTonemapping == 7) pixel = logarithmic_range_compression(pixel) * float3(!truezero);
		altered = true;
	}
	
	if (QxaaEnableTonemap && (QxaaGainStrength > 0.0))
	{
		float3 outdot = pixel;
		float presaturation = dotsat(outdot);
		float preluma = dot(outdot, __QXAA_LUMA_REF);
		bool3 truezero = !outdot;
		float colorgain = 2.0 - log2(QxaaGainStrength + 1.0);
		float channelfloor = __QXAA_MIN_STEP;
		outdot = log2(clamp(outdot, channelfloor, 1.0 - channelfloor));
		outdot = pow(abs(colorgain), outdot);
		if (QxaaGainLowLumaCorrection)
		{
			// calculate new black level
			channelfloor = pow(abs(colorgain), log2(channelfloor));
			// calculate reduction strength to apply
			float contrastgain = log(1.0 / (dot(outdot, __QXAA_LUMA_REF) - channelfloor)) * pow(__QXAA_CONST_E, (1.0 + channelfloor) * __QXAA_CONST_E) * QxaaGainStrength * QxaaGainStrength;
			outdot = pow(abs(2.0 + contrastgain) * 5.0, log10(outdot));
			float lumadelta = dot(outdot, __QXAA_LUMA_REF) - preluma;
			outdot = RGBtoYUV(outdot);
			outdot.x = saturate(outdot.x - lumadelta * channelfloor);
			outdot = YUVtoRGB(outdot);
			float newsat = dotsat(outdot);
			float satadjust = abs(((newsat - presaturation) / 2.0) * (1.0 + QxaaGainStrength)); // compute difference in before/after saturation
			if (satadjust != 0.0) outdot = AdjustSaturation(outdot, 0.5 + satadjust);
		}
		pixel = float3(!truezero) * outdot;
		altered = true;
	}

	if (QxaaEnableTonemap && (QxaaBlueLightFilter != 0.0))
	{
		float3 outdot = RGBtoYUV(pixel);
		float strength = 1.0 - QxaaBlueLightFilter;
		float signalclamp = (outdot.x * 0.5) * dotsat(pixel) * abs(outdot.y);
		if (outdot.z > 0.0) outdot.z = clamp(outdot.z * strength, signalclamp, 0.5);
		pixel = YUVtoRGB(outdot);
		altered = true;
	}
	
	if (QxaaEnableTonemap && (QxaaSaturationStrength != 0.5))
	{
		float3 outdot = AdjustSaturation(pixel, QxaaSaturationStrength);
		pixel = outdot;
		altered = true;
	}
	
	if (altered) return ConditionalEncode(pixel);
	else return original;
}

/***************************************************************************************************************************************/
/********************************************************** QXAA SHADER CODE END *******************************************************/
/***************************************************************************************************************************************/

technique QXAA <
	ui_tooltip = "============================================================\n"
				 "high-Quality approXimate Anti-Aliasing is a stand-alone\n"
				 "version of the FXAA pass used in HQAA. It is more costly\n"
				 "than normal FXAA but typically yields excellent results for\n"
				 "its execution cost.\n"
				 "============================================================";
>
{
	pass Init
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAInitPS;
		RenderTarget = QXAAHysteresisInfoTex;
		ClearRenderTargets = true;
	}
	pass QXAA
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAPS;
	}
#if QXAA_MULTISAMPLING > 1
	pass QXAA
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAPS;
	}
#if QXAA_MULTISAMPLING > 2
	pass QXAA
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAPS;
	}
#if QXAA_MULTISAMPLING > 3
	pass QXAA
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAPS;
	}
#endif //QXAA_MULTISAMPLING 3
#endif //QXAA_MULTISAMPLING 2
#endif //QXAA_MULTISAMPLING 1
	pass Hysteresis
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAHysteresisPS;
	}
}
