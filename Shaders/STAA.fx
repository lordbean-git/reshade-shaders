/*               STAA for ReShade 3.1.1+
 *
 *       (Subpixel-jittered Temporal Anti-Aliasing)
 *
 *                   by lordbean
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

 // Original code is copyright (c) Derek Brush aka "lordbean" (derekbrush@gmail.com)

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

uniform uint FrameCounter <source = "framecount";>;

uniform int StaaAboutSTART <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n----------------------------------- STAA 1.0 -----------------------------------";
>;

uniform int StaaIntroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.0";
	ui_text = "-------------------------------------------------------------------------\n"
			"      Subpixel-jittered Temporal Anti-Aliasing, a shader by lordbean\n"
			"             https://github.com/lordbean-git/reshade-shaders/\n"
			"-------------------------------------------------------------------------\n\n"
			"STAA uses one QXAA pass to pre-smoothen the scene followed by two\n"
			"temporal jitter blending passes and then one CAS pass to counter some\n"
			"of the incurred blurring. Settings for QXAA and CAS are calculated using\n"
			"the TAA configuration in order to produce good output. Additional\n"
			"sharpening is recommended after STAA runs.\n"
			"\n-------------------------------------------------------------------------"
			"\nSee the 'Preprocessor definitions' section for color & feature toggles.\n"
			"-------------------------------------------------------------------------";
	ui_tooltip = "Can now be considered a BIT less change-prone.";
	ui_category = "About";
	ui_category_closed = true;
>;

uniform int StaaAboutEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float EdgeThreshold <
	ui_type = "slider";
	ui_label = "Edge Threshold";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Minimum contrast delta to be considered an edge.\n"
			   "To control ghosting, temporal jittering only runs\n"
			   "where edges are detected. Default should work well\n"
			   "in most cases, 0 can be used to process full scene.";
> = 0.04;

uniform float JitterOffset <
	ui_type = "slider";
	ui_label = "Jitter Offset";
	ui_min = 0.0; ui_max = 0.5; ui_step = 0.001;
	ui_tooltip = "Distance (in pixels) that temporal samples\n"
				 "will be jittered. Higher counteracts more\n"
				 "aliasing and shimmering but increases blur.";
> = 0.333333;

uniform float TemporalWeight <
	ui_type = "slider";
	ui_label = "Temporal Blend Weight";
	ui_min = 0.0; ui_max = 0.5; ui_step = 0.001;
	ui_tooltip = "Amount of weight given to previous frame.\n"
				 "Causes a bit of ghosting, but helps to\n"
				 "cover shimmering and temporal aliasing.\n"
				 "STAA still works with this set to zero,\n"
				 "and will not produce any ghosting. It is\n"
				 "simply less effective against shimmering.";
> = 0.25;

uniform float MinimumBlend <
	ui_type = "slider";
	ui_label = "Minimum Blend Strength";
	ui_tooltip = "Blends at least this much of the calculated\n"
				 "jitter result when processing edges. The\n"
				 "remaining portion is flexible and determined\n"
				 "by the detection strength of the edge.";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.333333;

uniform int StaaOptionsEOF <
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

#define __STAA_SMALLEST_COLOR_STEP rcp(pow(2., BUFFER_COLOR_BIT_DEPTH))
#define __STAA_CONST_E 2.7182818284590452353602874713527
#define __STAA_CONST_HALFROOT2 (sqrt(2.)/2.)
#define __STAA_LUMA_REF float3(0.2126, 0.7152, 0.0722)
#define __STAA_AVERAGE_REF float3(0.333333, 0.333334, 0.333333)
#define __STAA_GREEN_LUMA float3(1./5., 7./10., 1./10.)
#define __STAA_RED_LUMA float3(5./8., 1./4., 1./8.)
#define __STAA_BLUE_LUMA float3(1./8., 3./8., 1./2.)
#define __STAA_BUFFER_STEP float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define __STAA_OFFSET float2(JitterOffset * __STAA_BUFFER_STEP)
#define __STAA_REVERSE float2(__STAA_OFFSET.x, -__STAA_OFFSET.y)

#define STAA_Tex2D(tex, coord) tex2Dlod(tex, (coord).xyxy)

#define STAAmax3(x,y,z) max(max(x,y),z)
#define STAAmax4(w,x,y,z) max(max(w,x),max(y,z))
#define STAAmax5(v,w,x,y,z) max(max(max(v,w),x),max(y,z))
#define STAAmax6(u,v,w,x,y,z) max(max(max(u,v),max(w,x)),max(y,z))
#define STAAmax7(t,u,v,w,x,y,z) max(max(max(t,u),max(v,w)),max(max(x,y),z))
#define STAAmax8(s,t,u,v,w,x,y,z) max(max(max(s,t),max(u,v)),max(max(w,x),max(y,z)))
#define STAAmax9(r,s,t,u,v,w,x,y,z) max(max(max(max(r,s),t),max(u,v)),max(max(w,x),max(y,z)))
#define STAAmax10(q,r,s,t,u,v,w,x,y,z) max(max(max(max(q,r),max(s,t)),max(u,v)),max(max(w,x),max(y,z)))
#define STAAmax11(p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(p,q),max(r,s)),max(max(t,u),v)),max(max(w,x),max(y,z)))
#define STAAmax12(o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(o,p),max(q,r)),max(max(s,t),max(u,v))),max(max(w,x),max(y,z)))
#define STAAmax13(n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(n,o),max(p,q)),max(max(r,s),max(t,u))),max(max(max(v,w),x),max(y,z)))
#define STAAmax14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) max(max(max(max(m,n),max(o,p)),max(max(q,r),max(s,t))),max(max(max(u,v),max(w,x)),max(y,z)))
#define STAAmin3(x,y,z) min(min(x,y),z)
#define STAAmin4(w,x,y,z) min(min(w,x),min(y,z))
#define STAAmin5(v,w,x,y,z) min(min(min(v,w),x),min(y,z))
#define STAAmin6(u,v,w,x,y,z) min(min(min(u,v),min(w,x)),min(y,z))
#define STAAmin7(t,u,v,w,x,y,z) min(min(min(t,u),min(v,w)),min(min(x,y),z))
#define STAAmin8(s,t,u,v,w,x,y,z) min(min(min(s,t),min(u,v)),min(min(w,x),min(y,z)))
#define STAAmin9(r,s,t,u,v,w,x,y,z) min(min(min(min(r,s),t),min(u,v)),min(min(w,x),min(y,z)))
#define STAAmin10(q,r,s,t,u,v,w,x,y,z) min(min(min(min(q,r),min(s,t)),min(u,v)),min(min(w,x),min(y,z)))
#define STAAmin11(p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(p,q),min(r,s)),min(min(t,u),v)),min(min(w,x),min(y,z)))
#define STAAmin12(o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(o,p),min(q,r)),min(min(s,t),min(u,v))),min(min(w,x),min(y,z)))
#define STAAmin13(n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(n,o),min(p,q)),min(min(r,s),min(t,u))),min(min(min(v,w),x),min(y,z)))
#define STAAmin14(m,n,o,p,q,r,s,t,u,v,w,x,y,z) min(min(min(min(m,n),min(o,p)),min(min(q,r),min(s,t))),min(min(min(u,v),min(w,x)),min(y,z)))

/*****************************************************************************************************************************************/
/********************************************************* SYNTAX SETUP END **************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SUPPORT CODE START *************************************************************/
/*****************************************************************************************************************************************/

void STAAMovc(bool2 cond, inout float2 variable, float2 value)
{
    [flatten] if (cond.x) variable.x = value.x;
    [flatten] if (cond.y) variable.y = value.y;
}
void STAAMovc(bool4 cond, inout float4 variable, float4 value)
{
    STAAMovc(cond.xy, variable.xy, value.xy);
    STAAMovc(cond.zw, variable.zw, value.zw);
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

float lnand(float x, float y)
{
	return y == 0.0 ? x : 0.0;
}
float2 lnand(float2 x, float2 y)
{
	return float2(lnand(x.x, y.x), lnand(x.y, y.y));
}
float3 lnand(float3 x, float3 y)
{
	return float3(lnand(x.x, y.x), lnand(x.yz, y.yz));
}
float4 lnand(float4 x, float4 y)
{
	return float4(lnand(x.xy, y.xy), lnand(x.zw, y.zw));
}

float chromadelta(float3 pixel1, float3 pixel2)
{
	return dot(abs(pixel1 - pixel2), float3(0.333333, 0.333334, 0.333333));
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

//////////////////////////////////////////////////////////// TEXTURES ///////////////////////////////////////////////////////////////////

texture StaaJitterTex0
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	#if BUFFER_COLOR_BIT_DEPTH == 8
	Format = RGBA8;
	#elif BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
	#else
	Format = RGBA16F;
	#endif
};
sampler JitterTex0 {Texture = StaaJitterTex0;};

texture StaaJitterTex1
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	#if BUFFER_COLOR_BIT_DEPTH == 8
	Format = RGBA8;
	#elif BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
	#else
	Format = RGBA16F;
	#endif
};
sampler JitterTex1 {Texture = StaaJitterTex1;};

texture StaaJitterTex2
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	#if BUFFER_COLOR_BIT_DEPTH == 8
	Format = RGBA8;
	#elif BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
	#else
	Format = RGBA16F;
	#endif
};
sampler JitterTex2 {Texture = StaaJitterTex2;};

texture StaaJitterTex3
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	#if BUFFER_COLOR_BIT_DEPTH == 8
	Format = RGBA8;
	#elif BUFFER_COLOR_BIT_DEPTH == 10
	Format = RGB10A2;
	#else
	Format = RGBA16F;
	#endif
};
sampler JitterTex3 {Texture = StaaJitterTex3;};

texture StaaEdgesTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = R32F; // high precision desired due to use in every pass
};
sampler EdgesTex {Texture = StaaEdgesTex;};

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/************************************************************ SHADER CODE START **********************************************************/
/*****************************************************************************************************************************************/

float EdgeDetectionPS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 middle = STAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float2 hvstep = __STAA_BUFFER_STEP;
	float2 diagstep = hvstep * __STAA_CONST_HALFROOT2;
	
    float Dtop = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord - float2(0, hvstep.y)).rgb);
    float Dleft = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord - float2(hvstep.x, 0)).rgb);
    float Dright = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(hvstep.x, 0)).rgb);
    float Dbottom = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0, hvstep.y)).rgb);
	float Dtopleft = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord - diagstep).rgb);
	float Dbottomright = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord + diagstep).rgb);
	float Dtopright = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(diagstep.x, -diagstep.y)).rgb);
	float Dbottomleft = chromadelta(middle, STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-diagstep.x, diagstep.y)).rgb);
	
	float crossedges = STAAmax4(Dleft, Dtop, Dright, Dbottom);
	float diagedges = STAAmax4(Dtopleft, Dbottomright, Dtopright, Dbottomleft);
	
	float edges = max(crossedges, diagedges);
	edges *= step(EdgeThreshold, edges);
	
	return edges;
}

float4 GenerateBufferJitterPS(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 offsetdir = 0.0.xx;
	if (FrameCounter & 1 == 0) offsetdir = __STAA_OFFSET;
	else offsetdir = __STAA_REVERSE;
	return (STAA_Tex2D(ReShade::BackBuffer, texcoord + offsetdir) + STAA_Tex2D(ReShade::BackBuffer, texcoord - offsetdir)) / 2.0;
}

float4 TransferJitterTexPS(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_Target
{
	return STAA_Tex2D(JitterTex0, texcoord);
}

float4 TransferJitterTexTwoPS(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_Target
{
	return STAA_Tex2D(JitterTex2, texcoord);
}

float4 TemporalBlendingPS(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_Target
{
	float edges = STAA_Tex2D(EdgesTex, texcoord).r;
	float4 original = STAA_Tex2D(ReShade::BackBuffer, texcoord);
	if (!edges) return original;
	float blendweight = (1.0 - MinimumBlend) * sqrt(edges) + MinimumBlend;
	float4 jitter0 = STAA_Tex2D(JitterTex0, texcoord);
	float4 jitter1 = STAA_Tex2D(JitterTex1, texcoord);
	float4 temporaljitter = lerp(jitter0, jitter1, TemporalWeight);
	return lerp(original, temporaljitter, blendweight);
}

float4 TemporalBlendingTwoPS(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_Target
{
	float edges = STAA_Tex2D(EdgesTex, texcoord).r;
	float4 original = STAA_Tex2D(ReShade::BackBuffer, texcoord);
	if (!edges) return original;
	float blendweight = (1.0 - MinimumBlend) * sqrt(edges) + MinimumBlend;
	float4 jitter0 = STAA_Tex2D(JitterTex2, texcoord);
	float4 jitter1 = STAA_Tex2D(JitterTex3, texcoord);
	float4 temporaljitter = lerp(jitter0, jitter1, TemporalWeight);
	return lerp(original, temporaljitter, blendweight);
}

float3 QXAAPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
 {
    float3 original = STAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float edges = STAA_Tex2D(EdgesTex, texcoord).r;
	if (!edges) return original;
	
	float3 middle = original;
	float maxchannel = STAAmax3(middle.r, middle.g, middle.b);
    float3 ref;
	if (middle.g == maxchannel) ref = __STAA_GREEN_LUMA;
	else if (middle.r == maxchannel) ref = __STAA_RED_LUMA;
	else ref = __STAA_BLUE_LUMA;
	float lumaM = dot(middle, ref);
	float2 lengthSign = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	
    float lumaS = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0.0, lengthSign.y)).rgb, ref);
    float lumaE = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(lengthSign.x, 0.0)).rgb, ref);
    float lumaN = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0.0, -lengthSign.y)).rgb, ref);
    float lumaW = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-lengthSign.x, 0.0)).rgb, ref);
    float4 crossdelta = abs(lumaM - float4(lumaS, lumaE, lumaN, lumaW));
	float2 weightsHV = float2(crossdelta.x + crossdelta.z, crossdelta.y + crossdelta.w);
    
    // pattern
    // * z *
    // w * y
    // * x *
    
	float2 diagstep = lengthSign * __STAA_CONST_HALFROOT2;
    float lumaNW = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord - diagstep).rgb, ref);
    float lumaSE = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + diagstep).rgb, ref);
    float lumaNE = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(diagstep.x, -diagstep.y)).rgb, ref);
    float lumaSW = dot(STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-diagstep.x, diagstep.y)).rgb, ref);
    float4 diagdelta = abs(lumaM - float4(lumaNW, lumaSE, lumaNE, lumaSW));
	float2 weightsDI = float2(diagdelta.w + diagdelta.z, diagdelta.x + diagdelta.y);
    
    // pattern
    // x * z
    // * * *
    // w * y
    
	float4 crosscheck = max(crossdelta, diagdelta);
	float2 stepcheck = max(crosscheck.xy, crosscheck.zw);
    float range = max(stepcheck.x, stepcheck.y);
	
	if (range < EdgeThreshold) return original;
	
	bool diagSpan = max(weightsDI.x, weightsDI.y) * float(bool(lxor(weightsDI.x, weightsDI.y))) > max(weightsHV.x, weightsHV.y);
	bool inverseDiag = diagSpan && (weightsDI.y > weightsDI.x);
	bool horzSpan = weightsHV.x > weightsHV.y;
	
	float2 lumaNP = float2(lumaN, lumaS);
	STAAMovc(!horzSpan.xx, lumaNP, float2(lumaW, lumaE));
	STAAMovc(diagSpan.xx, lumaNP, float2(lumaNW, lumaSE));
	STAAMovc((diagSpan && inverseDiag).xx, lumaNP, float2(lumaSW, lumaNE));
    float gradientN = abs(lumaNP.x - lumaM);
    float gradientP = abs(lumaNP.y - lumaM);
    float lumaNN = lumaNP.x + lumaM;
    if (gradientN >= gradientP && !diagSpan) lengthSign = -lengthSign;
    if (diagSpan && inverseDiag) lengthSign.y = -lengthSign.y;
    if (gradientP > gradientN) lumaNN = lumaNP.y + lumaM;
    float gradientScaled = max(gradientN, gradientP) * 0.25;
    bool lumaMLTZero = mad(0.5, -lumaNN, lumaM) < 0.0;
	
    float2 posB = texcoord;
	float texelsize = clamp(2. * (0.5 - JitterOffset), 0.25, 1.0);
    float2 offNP = float2(0.0, BUFFER_RCP_HEIGHT * texelsize);
	STAAMovc(bool(horzSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * texelsize, 0.0));
	STAAMovc(bool(diagSpan).xx, offNP, float2(BUFFER_RCP_WIDTH * texelsize, BUFFER_RCP_HEIGHT * texelsize));
	if (diagSpan && inverseDiag) offNP.y = -offNP.y;
	
	STAAMovc(bool2(!horzSpan || diagSpan, horzSpan || diagSpan), posB, float2(posB.x + lengthSign.x * 0.333333, posB.y + lengthSign.y * 0.333333));
	
    float2 posN = posB - offNP;
    float2 posP = posB + offNP;
    float lumaEndN = dot(STAA_Tex2D(ReShade::BackBuffer, posN).rgb, ref);
    float lumaEndP = dot(STAA_Tex2D(ReShade::BackBuffer, posP).rgb, ref);
	lumaNN *= 0.5;
    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
	
	uint iterations = 0;
	uint maxiterations = round(8. / texelsize);
	[loop] while (iterations < maxiterations)
	{
		if (doneN && doneP) break;
		if (!doneN)
		{
			posN -= offNP;
			lumaEndN = dot(STAA_Tex2D(ReShade::BackBuffer, posN).rgb, ref);
			lumaEndN -= lumaNN;
			doneN = abs(lumaEndN) >= gradientScaled;
		}
		if (!doneP)
		{
			posP += offNP;
			lumaEndP = dot(STAA_Tex2D(ReShade::BackBuffer, posP).rgb, ref);
			lumaEndP -= lumaNN;
			doneP = abs(lumaEndP) >= gradientScaled;
		}
		iterations++;
    }
	
	float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
	STAAMovc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));
	STAAMovc(bool(diagSpan).xx, dstNP, float2(sqrt(pow(abs(texcoord.y - posN.y), 2.0) + pow(abs(texcoord.x - posN.x), 2.0)), sqrt(pow(abs(posP.y - texcoord.y), 2.0) + pow(abs(posP.x - texcoord.x), 2.0))));
	
	//perform span check
    float endluma = (dstNP.x < dstNP.y) ? lumaEndN : lumaEndP;
    bool goodSpan = endluma < 0.0 != lumaMLTZero;
	
	//calculate offset from origin
    float pixelOffset = abs(mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5));
	
	//calculate offset weight
    float subpixOut = 1.0;
	if (!goodSpan) // bad span
	{
		subpixOut = mad(mad(2.0, lumaS + lumaE + lumaN + lumaW, lumaNW + lumaSE + lumaNE + lumaSW), 0.083333, -lumaM) * rcp(range); //ABC
		subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0); // DEFGH
	}
	subpixOut *= pixelOffset;
	
	//generate final sampling coordinates
    float2 posM = texcoord;
	STAAMovc(bool2(!horzSpan || diagSpan, horzSpan || diagSpan), posM, float2(posM.x + lengthSign.x * subpixOut, posM.y + lengthSign.y * subpixOut));
    
	//fart result
	return STAA_Tex2D(ReShade::BackBuffer, posM).rgb;
}

float3 CASPS(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float edges = STAA_Tex2D(EdgesTex, texcoord).r;
    float3 e = STAA_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	if (!edges) return e;
	
	float SharpeningStrength = saturate(sqrt(edges));
	float SharpeningContrast = saturate(edges);
	
	float offset = saturate(0.6 + JitterOffset);
	float2 bstep = offset * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	float2 diagstep = (sqrt(2.)/2.) * bstep;
	
    float3 a = STAA_Tex2D(ReShade::BackBuffer, texcoord - diagstep).rgb;
    float3 b = STAA_Tex2D(ReShade::BackBuffer, texcoord - float2(0., bstep.y)).rgb;
    float3 c = STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(diagstep.x, -diagstep.y)).rgb;
    float3 d = STAA_Tex2D(ReShade::BackBuffer, texcoord - float2(bstep.x, 0.)).rgb;
    float3 g = STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(-diagstep.x, diagstep.y)).rgb;
    float3 f = STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(bstep.x, 0.)).rgb;
    float3 h = STAA_Tex2D(ReShade::BackBuffer, texcoord + float2(0., bstep.y)).rgb;
    float3 i = STAA_Tex2D(ReShade::BackBuffer, texcoord + diagstep).rgb;

    float3 mnRGB = min(min(min(d, e), min(f, b)), h);
    float3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
    mnRGB += mnRGB2;

    float3 mxRGB = max(max(max(d, e), max(f, b)), h);
    float3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
    mxRGB += mxRGB2;

    float3 rcpMRGB = rcp(mxRGB);
    float3 ampRGB = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);    
    
    ampRGB = rsqrt(ampRGB);
    
    float peak = -3.0 * SharpeningContrast + 8.0;
    float3 wRGB = -rcp(ampRGB * peak);

    float3 rcpWeightRGB = rcp(4.0 * wRGB + 1.0);

    float3 window = (b + d) + (f + h);
    float3 outColor = saturate((window * wRGB + e) * rcpWeightRGB);
    
	return lerp(e, outColor, SharpeningStrength);
}

/*****************************************************************************************************************************************/
/************************************************************* SHADER CODE END ***********************************************************/
/*****************************************************************************************************************************************/

// pass ordering:
// frame start
// relevant pre-processing here (single pass QXAA to pre-smooth)
// Generate jitter of current buffer to textures
// buffer blending pass
// transfer this frame's jitters to n-1 textures
// relevant post-processing here (sharpening)
// frame end

technique STAA
{
	pass EdgeDetection
	{
		VertexShader = PostProcessVS;
		PixelShader = EdgeDetectionPS;
		RenderTarget = StaaEdgesTex;
		ClearRenderTargets = true;
	}
	pass QXAA
	{
		VertexShader = PostProcessVS;
		PixelShader = QXAAPS;
	}
	pass EdgeDetection
	{
		VertexShader = PostProcessVS;
		PixelShader = EdgeDetectionPS;
		RenderTarget = StaaEdgesTex;
		ClearRenderTargets = true;
	}
	pass FreshJitter
	{
		VertexShader = PostProcessVS;
		PixelShader = GenerateBufferJitterPS;
		RenderTarget = StaaJitterTex0;
		ClearRenderTargets = true;
	}
	pass TemporalBlending
	{
		VertexShader = PostProcessVS;
		PixelShader = TemporalBlendingPS;
	}
	pass FrameTransfer
	{
		VertexShader = PostProcessVS;
		PixelShader = TransferJitterTexPS;
		RenderTarget = StaaJitterTex1;
		ClearRenderTargets = true;
	}
	pass EdgeDetection
	{
		VertexShader = PostProcessVS;
		PixelShader = EdgeDetectionPS;
		RenderTarget = StaaEdgesTex;
		ClearRenderTargets = true;
	}
	pass FreshJitterTwo
	{
		VertexShader = PostProcessVS;
		PixelShader = GenerateBufferJitterPS;
		RenderTarget = StaaJitterTex2;
		ClearRenderTargets = true;
	}
	pass TemporalBlendingTwo
	{
		VertexShader = PostProcessVS;
		PixelShader = TemporalBlendingTwoPS;
	}
	pass FrameTransferTwo
	{
		VertexShader = PostProcessVS;
		PixelShader = TransferJitterTexTwoPS;
		RenderTarget = StaaJitterTex3;
		ClearRenderTargets = true;
	}
	pass EdgeDetection
	{
		VertexShader = PostProcessVS;
		PixelShader = EdgeDetectionPS;
		RenderTarget = StaaEdgesTex;
		ClearRenderTargets = true;
	}
	pass Sharpening
	{
		VertexShader = PostProcessVS;
		PixelShader = CASPS;
	}
}
