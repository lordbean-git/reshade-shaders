/*               Image Softening for ReShade 3.1.1+
 *
 *   (Smart Error-Controlled Geometric Pattern Average Blur Shader)
 *
 *                         by lordbean
 *
 *              (c) 2022 Derek Brush aka lordbean
 *				      derekbrush@gmail.com
 */
 
/**
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

uniform int ImageSoftenIntroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.0";
	ui_text = "-------------------------------------------------------------------------\n"
			"Smart Image Softening, a shader by lordbean\n"
			"https://github.com/lordbean-git/reshade-shaders/\n"
			"-------------------------------------------------------------------------\n\n"
			"This shader measures multiple geometric patterns around each pixel and\n"
			"controls for spurious readings by omitting the strongest and weakest\n"
			"recorded patterns. The final result is interpolated with the original dot\n"
			"to produce a subtle blur effect.\n\n"
			"-------------------------------------------------------------------------";
	ui_tooltip = "Based on HQAA 27.5";
	ui_category = "About";
	ui_category_closed = true;
>;

uniform int ImageSoftenIntroEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float ImageSoftenStrength <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Softening Strength";
	ui_tooltip = "Interpolation factor with original pixel";
> = 0.75;

uniform float ImageSoftenOffset <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.001;
	ui_label = "Sampling Offset";
	ui_tooltip = "Distance (in pixels) from center dot\n"
				 "to measure geometric patterns.\n"
				 "Lower gives the middle more weight,\n"
				 "higher increases the amount of blur.";
> = 0.75;

uniform int ImageSoftenEOF <
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

#define ISmax3(x,y,z) max(max(x,y),z)
#define ISmax4(w,x,y,z) max(max(w,x),max(y,z))
#define ISmax5(v,w,x,y,z) max(max(max(v,w),x),max(y,z))
#define ISmax6(u,v,w,x,y,z) max(max(max(u,v),max(w,x)),max(y,z))
#define ISmax7(t,u,v,w,x,y,z) max(max(max(t,u),max(v,w)),max(max(x,y),z))
#define ISmax8(s,t,u,v,w,x,y,z) max(max(max(s,t),max(u,v)),max(max(w,x),max(y,z)))
#define ISmax9(r,s,t,u,v,w,x,y,z) max(max(max(max(r,s),t),max(u,v)),max(max(w,x),max(y,z)))
#define ISmax10(q,r,s,t,u,v,w,x,y,z) max(max(max(max(q,r),max(s,t)),max(u,v)),max(max(w,x),max(y,z)))
#define ISmax11(p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(p,q),max(r,s)),max(max(t,u),v)),max(max(w,x),max(y,z)))
#define ISmax12(o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(o,p),max(q,r)),max(max(s,t),max(u,v))),max(max(w,x),max(y,z)))
#define ISmax13(n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(n,o),max(p,q)),max(max(r,s),max(t,u))),max(max(max(v,w),x),max(y,z)))
#define ISmax14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(m,n),max(o,p)),max(max(q,r),max(s,t))),max(max(max(u,v),max(w,x)),max(y,z)))
#define ISmax15(l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(l,m),max(n,o)),max(max(p,q),max(r,s))),max(max(max(t,u),max(v,w)),max(max(x,y),z)))
#define ISmax16(k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(k,l),max(m,n)),max(max(o,p),max(q,r))),max(max(max(s,t),max(u,v)),max(max(w,x),max(y,z))))

#define ISmin3(x,y,z) min(min(x,y),z)
#define ISmin4(w,x,y,z) min(min(w,x),min(y,z))
#define ISmin5(v,w,x,y,z) min(min(min(v,w),x),min(y,z))
#define ISmin6(u,v,w,x,y,z) min(min(min(u,v),min(w,x)),min(y,z))
#define ISmin7(t,u,v,w,x,y,z) min(min(min(t,u),min(v,w)),min(min(x,y),z))
#define ISmin8(s,t,u,v,w,x,y,z) min(min(min(s,t),min(u,v)),min(min(w,x),min(y,z)))
#define ISmin9(r,s,t,u,v,w,x,y,z) min(min(min(min(r,s),t),min(u,v)),min(min(w,x),min(y,z)))
#define ISmin10(q,r,s,t,u,v,w,x,y,z) min(min(min(min(q,r),min(s,t)),min(u,v)),min(min(w,x),min(y,z)))
#define ISmin11(p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(p,q),min(r,s)),min(min(t,u),v)),min(min(w,x),min(y,z)))
#define ISmin12(o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(o,p),min(q,r)),min(min(s,t),min(u,v))),min(min(w,x),min(y,z)))
#define ISmin13(n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(n,o),min(p,q)),min(min(r,s),min(t,u))),min(min(min(v,w),x),min(y,z)))
#define ISmin14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(m,n),min(o,p)),min(min(q,r),min(s,t))),min(min(min(u,v),min(w,x)),min(y,z)))
#define ISmin15(l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(l,m),min(n,o)),min(min(p,q),min(r,s))),min(min(min(t,u),min(v,w)),min(min(x,y),z)))
#define ISmin16(k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(k,l),min(m,n)),min(min(o,p),min(q,r))),min(min(min(s,t),min(u,v)),min(min(w,x),min(y,z))))

#include "ReShade.fxh"

/*****************************************************************************************************************************************/
/********************************************************* SYNTAX SETUP END **************************************************************/
/*****************************************************************************************************************************************/

/***************************************************************************************************************************************/
/******************************************************* SOFTENER SHADER CODE START ****************************************************/
/***************************************************************************************************************************************/

float3 ImageSoftenerPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 offset = float2(ImageSoftenOffset * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)).xyxy;
	
// pattern:
//  e f g
//  h a b
//  i c d

	float3 a = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy).rgb;
	float3 b = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(1, 0).xyxy * offset).rgb;
	float3 c = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(0, 1).xyxy * offset).rgb;
	float3 d = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(1, 1).xyxy * offset).rgb;
	float3 e = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(-1, -1).xyxy * offset).rgb;
	float3 f = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(0, -1).xyxy * offset).rgb;
	float3 g = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(1, -1).xyxy * offset).rgb;
	float3 h = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(-1, 0).xyxy * offset).rgb;
	float3 i = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy + float2(-1, 1).xyxy * offset).rgb;
	
	float3 x1 = (e + f + g) / 3.0;
	float3 x2 = (h + b) / 2.0;
	float3 x3 = (i + c + d) / 3.0;
	float3 y1 = (e + h + i) / 3.0;
	float3 y2 = (f + c) / 2.0;
	float3 y3 = (g + b + d) / 3.0;
	float3 xy1 = (e + d) / 2.0;
	float3 xy2 = (i + g) / 2.0;
	float3 diamond = (h + f + c + b) / 4.0;
	float3 square = (e + g + i + d) / 4.0;
	float3 cap = (h + e + f + g + b) / 5.0;
	float3 bucket = (h + i + c + d + b) / 5.0;
	float3 letter = (f + e + h + i + c) / 5.0;
	float3 magnet = (f + g + b + d + c) / 5.0;
	float3 box = (e + f + g + b + d + c + i + h) / 8.0;
	
	float3 highterm = ISmax15(x1, x2, x3, y1, y2, y3, xy1, xy2, diamond, square, cap, bucket, letter, magnet, box);
	float3 lowterm = ISmin15(x1, x2, x3, y1, y2, y3, xy1, xy2, diamond, square, cap, bucket, letter, magnet, box);
	
	float3 localavg = ((x1 + x2 + x3 + y1 + y2 + y3 + xy1 + xy2 + diamond + square + cap + bucket + letter + magnet + box) - (highterm + lowterm)) / 13.0;
	
	return lerp(a, localavg, ImageSoftenStrength);
}

/***************************************************************************************************************************************/
/******************************************************** SOFTENER SHADER CODE END *****************************************************/
/***************************************************************************************************************************************/

technique ImageSoftening <
	ui_tooltip = "============================================================\n"
				 "This shader measures an error-controlled average of many\n"
				 "geometric patterns around each pixel to generate a subtle\n"
				 "blur effect. Warning: may eat stars.\n"
				 "============================================================";
>
{
	pass ImageSoftening
	{
		VertexShader = PostProcessVS;
		PixelShader = ImageSoftenerPS;
	}
}
