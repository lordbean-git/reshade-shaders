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
	ui_label = "Version: 1.5.2814";
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
			
			"\nMultisampling can be used to increase correction strength\n"
			"when encountering edges with more than one color gradient or\n"
			"irregular geometry. Costs some performance for each extra pass.\n"
			"Valid range: 1 to 4. Higher values are ignored.\n"
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
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast (luma difference) required to be considered an edge.\nQXAA does not do dynamic thresholding, but it\nhandles extreme settings very well.";
> = 0.01;

uniform uint QxaaScanIterations <
	ui_type = "slider";
	ui_min = 1; ui_max = 200; ui_step = 1;
	ui_label = "Gradient Scan Iterations";
	ui_tooltip = "Edge gradient search iterations.\nNote that this is per-pass, not total.";
> = 64;

uniform float QxaaTexelSize <
	ui_type = "slider";
	ui_min = 0.1; ui_max = 2.0; ui_step = 0.001;
	ui_label = "Edge Gradient Texel Size";
	ui_tooltip = "Determines how far along an edge QXAA will move\nfrom one scan iteration to the next.\n\nLower = slower, more accurate\nHigher = faster, more artifacts";
> = 0.5;

uniform float QxaaNoiseControlStrength <
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "Noise Control Strength";
	ui_tooltip = "Determines how strongly QXAA will clamp its output\n"
				 "when the resulting blend will have a high luma delta.";
> = 40;

uniform float QxaaStrength <
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "Effect Strength";
	ui_tooltip = "Although more costly, you can get better results\nby using multisampling and a lower strength.";
> = 80;

uniform float QxaaHysteresisStrength <
	ui_spacing = 3;
	ui_label = "Hysteresis Strength";
	ui_tooltip = "Performs detail reconstruction to minimize the\n"
				 "visual impact of artifacts that may be caused\n"
				 "by QXAA.";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.333333;

uniform float QxaaHysteresisFudgeFactor <
	ui_label = "Hysteresis Fudge Factor";
	ui_tooltip = "Pixels that have changed less than this\n"
				 "amount will be skipped.";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.2; ui_step = 0.001;
> = 0.02;

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

#define __QXAA_MIN_STEP rcp(pow(2, BUFFER_COLOR_BIT_DEPTH))
#define __QXAA_LUMA_REF float3(0.2126, 0.7152, 0.0722)
#define __QXAA_GREEN_LUMA float3(1./5., 7./10., 1./10.)
#define __QXAA_RED_LUMA float3(5./8., 1./4., 1./8.)
#define __QXAA_BLUE_LUMA float3(1./8., 3./8., 1./2.)
#define __QXAA_CONST_HALFROOT2 0.70710678118654752440084436210485
#define __QXAA_SM_BUFFERINFO float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)

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
	
	//setup cartesian neighbor data
    float lumaS = dot(QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0, 1)).rgb, ref);
    float lumaE = dot(QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1, 0)).rgb, ref);
    float lumaN = dot(QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0,-1)).rgb, ref);
    float lumaW = dot(QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 0)).rgb, ref);
    float4 crossdelta = abs(lumaM - float4(lumaS, lumaE, lumaN, lumaW));
	float2 weightsHV = float2((crossdelta.x + crossdelta.z) / 2.0, (crossdelta.y + crossdelta.w) / 2.0);
    
    // pattern
    // * z *
    // w * y
    // * x *
    
	//setup diagonal neighbor data
	//diagonal reads are performed at the same distance from origin as cartesian reads
	//solve using pythagorean theorem yields 1/2 sqrt(2) to match horz/vert distance
	//this bakes in a weighting bias to horz/vert giving diag code priority only when
	//it's the only viable option
    float lumaNW = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + (-__QXAA_SM_BUFFERINFO.xy * __QXAA_CONST_HALFROOT2)).rgb, ref);
    float lumaSE = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + (__QXAA_SM_BUFFERINFO.xy * __QXAA_CONST_HALFROOT2)).rgb, ref);
    float lumaNE = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + (__QXAA_SM_BUFFERINFO.xy * __QXAA_CONST_HALFROOT2 * float2(1, -1))).rgb, ref);
    float lumaSW = dot(QXAA_DecodeTex2D(ReShade::BackBuffer, texcoord + (__QXAA_SM_BUFFERINFO.xy * __QXAA_CONST_HALFROOT2 * float2(-1, 1))).rgb, ref);
    float4 diagdelta = abs(lumaM - float4(lumaNW, lumaSE, lumaNE, lumaSW));
	float2 weightsDI = float2((diagdelta.w + diagdelta.z) / 2.0, (diagdelta.x + diagdelta.y) / 2.0);
    
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
    float range = QXAAmax4(crosscheck.x, crosscheck.y, crosscheck.z, crosscheck.w);
    
    // abort if not above edge threshold
	if (range < edgethreshold) discard;
	
	//setup scanning gradient
	float2 lumaNP = float2(lumaN, lumaS);
	QXAAMovc(!horzSpan.xx, lumaNP, float2(lumaW, lumaE));
	QXAAMovc(diagSpan.xx, lumaNP, float2(lumaNW, lumaSE));
	QXAAMovc((diagSpan && inverseDiag).xx, lumaNP, float2(lumaSW, lumaNE));
    float gradientN = abs(lumaNP.x - lumaM);
    float gradientP = abs(lumaNP.y - lumaM);
    float lumaNN = lumaNP.x + lumaM;
	float2 lengthSign = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
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
	QXAAMovc(bool2(!horzSpan || diagSpan, horzSpan || diagSpan), posB, float2(posB.x + lengthSign.x / 2.0, posB.y + lengthSign.y / 2.0));
	
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
    float blendclamp = saturate(1.0 - abs(endluma - lumaM) * (QxaaNoiseControlStrength / 100.0));
	
	//calculate offset from origin
    float pixelOffset = abs(mad(-(1.0 / (dstNP.y + dstNP.x)), min(dstNP.x, dstNP.y), 0.5)) * clamp(QxaaStrength / 100.0, 0.0, blendclamp);
	
	//check span result, calculate offset weight if bad
    float subpixOut = 1.0;
    bool goodSpan = endluma < 0.0 != lumaMLTZero;
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

float3 QXAAHysteresisPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 pixel = QXAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float preluma = QXAA_Tex2D(OriginalLuma, texcoord).r;
	
	float3 result = ConditionalDecode(pixel.rgb);
	bool altered = false;

	float hysteresis = (dot(result, __QXAA_LUMA_REF) - preluma) * QxaaHysteresisStrength;
	if (abs(hysteresis) > QxaaHysteresisFudgeFactor)
	{
		result = pow(abs(1.0 + hysteresis) * 2.0, log2(result));
		altered = true;
	}
	
	if (altered) return ConditionalEncode(result);
	else return pixel.rgb;
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
