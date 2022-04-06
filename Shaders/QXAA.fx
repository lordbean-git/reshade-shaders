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


                    NVIDIA QXAA 3.11 by TIMOTHY LOTTES


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
#endif //HQAA_TARGET_COLOR_SPACE

#ifndef QXAA_MULTISAMPLING
	#define QXAA_MULTISAMPLING 2
#endif

/////////////////////////////////////////////////////// GLOBAL SETUP OPTIONS //////////////////////////////////////////////////////////////

uniform int QXAAintroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.0.2751";
	ui_text = "-------------------------------------------------------------------------\n"
			"high-Quality approXimate Anti-Aliasing, a shader by lordbean\n"
			"https://github.com/lordbean-git/reshade-shaders/\n"
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
			#endif //HQAA_TARGET_COLOR_SPACE
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

uniform int QxaaAboutEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float QxaaThreshold < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_spacing = 3;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast (luma difference) required to be considered an edge.\nQXAA does not do dynamic thresholding, but it\nhandles extreme settings very well.";
	ui_category = "QXAA";
> = 0.025;

uniform uint QxaaScanIterations < __UNIFORM_SLIDER_INT1
	ui_min = 1; ui_max = 200; ui_step = 1;
	ui_label = "Gradient Scan Iterations";
	ui_tooltip = "Edge gradient search iterations.\nNote that this is per-pass, not total.";
	ui_category = "QXAA";
> = 50;

uniform float QxaaTexelSize < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.1; ui_max = 2.0; ui_step = 0.001;
	ui_label = "Edge Gradient Texel Size";
	ui_tooltip = "Determines how far along an edge QXAA will move\nfrom one scan iteration to the next.\n\nLower = slower, more accurate\nHigher = faster, more artifacts";
	ui_category = "QXAA";
> = 0.5;

uniform float QxaaStrength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "% Effect Strength\n\n";
	ui_tooltip = "Although more costly, you can get better results\nby using multisampling and a lower strength.";
	ui_category = "QXAA";
> = 50;

#if QXAA_OUTPUT_MODE == 1
uniform float QxaaHdrNits < 
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 500.0; ui_max = 10000.0; ui_step = 100.0;
	ui_label = "HDR Nits";
	ui_tooltip = "If the scene brightness changes after QXAA runs, try\n"
				 "adjusting this value up or down until it looks right.";
> = 1000.0;
#endif //HQAA_TARGET_COLOR_SPACE

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
#define __QXAA_LUMA_REF float3(0.333333, 0.333334, 0.333333)

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

//////////////////////////////////////////////////////// PIXEL INFORMATION ////////////////////////////////////////////////////////////////

float dotweight(float3 middle, float3 neighbor, bool useluma, float3 weights)
{
	if (useluma) return dot(neighbor, weights);
	else return dot(abs(middle - neighbor), __QXAA_LUMA_REF);
}

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

float squared(float x)
{
	return x * x;
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

/***************************************************************************************************************************************/
/********************************************************** QXAA SHADER CODE START *****************************************************/
/***************************************************************************************************************************************/

float4 QXAAPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
 {
    float4 original = QXAA_Tex2D(ReShade::BackBuffer, texcoord);
	float3 middle = ConditionalDecode(original.rgb);
	
	float lumaM = dot(middle, __QXAA_LUMA_REF);
	
	float3 neighbor = QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0, 1)).rgb;
    float lumaS = dotweight(middle, neighbor, true, __QXAA_LUMA_REF);
    float chromaS = dotweight(middle, neighbor, false, __QXAA_LUMA_REF);
    
	neighbor = QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1, 0)).rgb;
    float lumaE = dotweight(middle, neighbor, true, __QXAA_LUMA_REF);
    float chromaE = dotweight(middle, neighbor, false, __QXAA_LUMA_REF);
    
	neighbor = QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 0,-1)).rgb;
    float lumaN = dotweight(middle, neighbor, true, __QXAA_LUMA_REF);
    float chromaN = dotweight(middle, neighbor, false, __QXAA_LUMA_REF);
    
	neighbor = QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 0)).rgb;
    float lumaW = dotweight(middle, neighbor, true, __QXAA_LUMA_REF);
    float chromaW = dotweight(middle, neighbor, false, __QXAA_LUMA_REF);
    
    bool useluma = QXAAmax4(abs(lumaS - lumaM), abs(lumaE - lumaM), abs(lumaN - lumaM), abs(lumaW - lumaM)) > QXAAmax4(chromaS, chromaE, chromaN, chromaW);
    
    if (!useluma) { lumaS = chromaS; lumaE = chromaE; lumaN = chromaN; lumaW = chromaW; lumaM = 0.0; }
	
    float rangeMax = QXAAmax5(lumaS, lumaE, lumaN, lumaW, lumaM);
    float rangeMin = QXAAmin5(lumaS, lumaE, lumaN, lumaW, lumaM);
	
    float range = rangeMax - rangeMin;
    
	// early exit check
    bool earlyExit = (range < QxaaThreshold);
	if (earlyExit) return original;
	
    float lumaNW = dotweight(middle, QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1,-1)).rgb, useluma, __QXAA_LUMA_REF);
    float lumaSE = dotweight(middle, QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1, 1)).rgb, useluma, __QXAA_LUMA_REF);
    float lumaNE = dotweight(middle, QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2( 1,-1)).rgb, useluma, __QXAA_LUMA_REF);
    float lumaSW = dotweight(middle, QXAA_DecodeTex2DOffset(ReShade::BackBuffer, texcoord, int2(-1, 1)).rgb, useluma, __QXAA_LUMA_REF);
	
    bool horzSpan = (abs(mad(-2.0, lumaW, lumaNW + lumaSW)) + mad(2.0, abs(mad(-2.0, lumaM, lumaN + lumaS)), abs(mad(-2.0, lumaE, lumaNE + lumaSE)))) >= (abs(mad(-2.0, lumaS, lumaSW + lumaSE)) + mad(2.0, abs(mad(-2.0, lumaM, lumaW + lumaE)), abs(mad(-2.0, lumaN, lumaNW + lumaNE))));	
    float lengthSign = horzSpan ? BUFFER_RCP_HEIGHT : BUFFER_RCP_WIDTH;
	
	float2 lumaNP = float2(lumaN, lumaS);
	
	QXAAMovc(bool(!horzSpan).xx, lumaNP, float2(lumaW, lumaE));
	
    float gradientN = lumaNP.x - lumaM;
    float gradientS = lumaNP.y - lumaM;
    float lumaNN = lumaNP.x + lumaM;
	
    if (abs(gradientN) >= abs(gradientS)) lengthSign = -lengthSign;
    else lumaNN = lumaNP.y + lumaM;
	
    float2 posB = texcoord;
    float2 offNP = float2(0.0, BUFFER_RCP_HEIGHT * QxaaTexelSize);
	
	QXAAMovc(bool(horzSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * QxaaTexelSize, 0.0));
	QXAAMovc(bool2(!horzSpan, horzSpan), posB, float2(posB.x + lengthSign / 2.0, posB.y + lengthSign / 2.0));
	
    float2 posN = posB - offNP;
    float2 posP = posB + offNP;
    
    float lumaEndN = dotweight(middle, QXAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, useluma, __QXAA_LUMA_REF);
    float lumaEndP = dotweight(middle, QXAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, useluma, __QXAA_LUMA_REF);
	
    float gradientScaled = max(abs(gradientN), abs(gradientS)) * 0.25;
    bool lumaMLTZero = mad(0.5, -lumaNN, lumaM) < 0.0;
	
	lumaNN *= 0.5;
	
    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;
	
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
    bool doneNP;
	
	uint iterations = 0;
	
	[loop] while (iterations < QxaaScanIterations)
	{
		doneNP = doneN && doneP;
		if (doneNP) break;
		if (!doneN)
		{
			posN -= offNP;
			lumaEndN = dotweight(middle, QXAA_DecodeTex2D(ReShade::BackBuffer, posN).rgb, useluma, __QXAA_LUMA_REF);
			lumaEndN -= lumaNN;
			doneN = abs(lumaEndN) >= gradientScaled;
		}
		if (!doneP)
		{
			posP += offNP;
			lumaEndP = dotweight(middle, QXAA_DecodeTex2D(ReShade::BackBuffer, posP).rgb, useluma, __QXAA_LUMA_REF);
			lumaEndP -= lumaNN;
			doneP = abs(lumaEndP) >= gradientScaled;
		}
		iterations++;
    }
	
	float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
	QXAAMovc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));
	
	float effectstrength = QxaaStrength / 100.0;
	
    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5);
    float subpixOut = pixelOffset * effectstrength;
	
	[branch] if (!goodSpan)
	{
		subpixOut = mad(mad(2.0, lumaS + lumaE + lumaN + lumaW, lumaNW + lumaSE + lumaNE + lumaSW), 0.083333, -lumaM) * rcp(range); //ABC
		subpixOut = squared(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut))) * effectstrength * pixelOffset; // DEFGH
	}

    float2 posM = texcoord;
	QXAAMovc(bool2(!horzSpan, horzSpan), posM, float2(posM.x + lengthSign * subpixOut, posM.y + lengthSign * subpixOut));
    
	return QXAA_Tex2D(ReShade::BackBuffer, posM);
}

/***************************************************************************************************************************************/
/********************************************************** QXAA SHADER CODE END *******************************************************/
/***************************************************************************************************************************************/

technique QXAA <
	ui_tooltip = "============================================================\n"
				 "high-Quality approXimate Anti-Aliasing is a stand-alone\n"
				 "version of the QXAA pass used in HQAA. It is more costly\n"
				 "than normal QXAA but typically yields excellent results for\n"
				 "its execution cost.\n"
				 "============================================================";
>
{
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
}
