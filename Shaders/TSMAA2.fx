/*               TSMAAv2 for ReShade 3.1.1+
 *
 *     (Temporal Subpixel Morphological Anti-Aliasing)
 *
 *
 *   Uses previous-frame compositing to enhance SMAA effect
 *
 * with customizations designed to maximize edge detection and
 *
 *                  minimize blurring
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
 **/
 
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

#ifndef TSM_ENABLE_DEBUG_PASS
	#define TSM_ENABLE_DEBUG_PASS 0
#endif
#if TSM_ENABLE_DEBUG_PASS > 1 || TSM_ENABLE_DEBUG_PASS < 0
	#undef TSM_ENABLE_DEBUG_PASS
	#define TSM_ENABLE_DEBUG_PASS 0
#endif

/////////////////////////////////////////////////////// GLOBAL SETUP OPTIONS //////////////////////////////////////////////////////////////

uniform int TSMAAintroduction <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.0\n\n";
	ui_text = "--------------------------------------------------------------------------------\n"
			"Temporal Subpixel Morphological Anti-Aliasing, a shader by lordbean\n"
			"https://github.com/lordbean-git/reshade-shaders/\n"
			"--------------------------------------------------------------------------------"
			"";
	ui_tooltip = "Experimental shader. YMMV.";
	ui_category = "About";
	ui_category_closed = true;
>;

#if TSM_ENABLE_DEBUG_PASS
/*
uniform float DV1 <
	ui_type = "slider";
	ui_category = "Debug";
	ui_category_closed = true;
	ui_spacing = 3;
	ui_label = "Debug Value 1";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.5;

uniform float DV2 <
	ui_type = "slider";
	ui_category = "Debug";
	ui_category_closed = true;
	ui_label = "Debug Value 2";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.5;
*/
uniform uint DebugMode <
	ui_type = "radio";
	ui_category = "Debug";
	ui_category_closed = true;
	ui_spacing = 3;
	ui_label = " \n\n";
	ui_text = "Debug Mode:";
	ui_items = "Off\n\n\0Detected Edges\0SMAA Blend Weights\n\n\0Temporal Composite Image\0\n\n";
> = 0;
#endif

uniform int AboutEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

/*-------------------------------------------------------------------------------------------------*/

uniform float EdgeThreshold <
	ui_type = "slider";
	ui_min = 0.02; ui_max = 1.0;
	ui_spacing = 3;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast required to be considered an edge.\n\n"
				 "Recommended range: [0.05..0.125]";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 0.05;

uniform float LowLumaThreshold <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.5; ui_step = 0.001;
	ui_label = "Low Luma Threshold";
	ui_tooltip = "Luma level below which dynamic thresholding activates\n\n"
				 "Recommended range: [0.05..0.2]";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 0.1;

uniform float DynamicThreshold <
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "% Dynamic Range";
	ui_tooltip = "Maximum reduction of edge threshold (% base threshold)\n"
				 "permitted when detecting low-brightness edges.\n"
				 "Lower = faster, might miss low-luma edges\n"
				 "Higher = slower, catches more edges in dark scenes\n\n"
				 "Recommended range: [50..100]";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 60;

uniform float ScanRadius <
	ui_type = "slider";
	ui_min = 12; ui_max = 112; ui_step = 1;
	ui_label = "Scan Distance";
	ui_tooltip = "Maximum radius from center dot\nto scan for aliasing.\n\n"
				 "Recommended range: [64..112]";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 112;

uniform bool DCBlending <
	ui_spacing = 3;
	ui_label = "Dual-Cardinal Blending";
	ui_tooltip = "Whether to perform blending using both axes\n"
				 "or just the dominant one when both horizontal\n"
				 "and vertical edges are detected near the pixel.\n"
				 "Normal SMAA uses the dominant one. The dual-\n"
				 "cardinal system reduces the blending strength\n"
				 "of diagonal edges slightly, but significantly\n"
				 "increases temporal stability of the output.\n\n"
				 "Recommended setting: enabled";
	ui_category = "SMAA";
	ui_category_closed = true;
> = true;

uniform bool CornerDetection <
	ui_label = "Perform Corner Detection";
	ui_tooltip = "Indicates whether SMAA will detect patterns\n"
				 "that look like corners in the edge data.\n"
				 "Disabling corner detection is equivalent\n"
				 "to setting corner rounding to 100%.\n\n"
				 "Recommended setting: enabled";
	ui_category = "SMAA";
	ui_category_closed = true;
> = true;

uniform float CornerRounding <
	ui_spacing = 3;
	ui_type = "slider";
	ui_min = 0; ui_max = 100; ui_step = 1;
	ui_label = "% Corner Rounding\n\n";
	ui_tooltip = "Affects the amount of blending performed when SMAA\n"
				 "detects corner patterns. Only works when corner\n"
				 "detection is enabled. Be careful with this value\n"
				 "as it can produce a large amount of blur in some\n"
				 "games, particularly at low resolutions.\n\n"
				 "Recommended range: [0..50]";
	ui_category = "SMAA";
	ui_category_closed = true;
> = 50;

/*-------------------------------------------------------------------------------------------------*/

uniform bool TemporalCompositing <
	ui_spacing = 3;
	ui_label = "Enable Temporal Compositing";
	ui_tooltip = "Enable/Disable previous-frame blending";
	ui_category = "Temporal Blending";
	ui_category_closed = true;
> = true;

uniform float TemporalBlending <
	ui_spacing = 3;
	ui_label = "Previous Frame Interpolation\n\n";
	ui_type = "slider";
	ui_min = 0.1; ui_max = 0.5; ui_step = 0.001;
	ui_category = "Temporal Blending";
	ui_category_closed = true;
> = 0.3;

/*-------------------------------------------------------------------------------------------------*/

#define __LUMA_REF float3(0.2126, 0.7152, 0.0722)
#define __SCANRADIUS round(ScanRadius)
#define __SCANRADIUSDIAG round(clamp(__SCANRADIUS * 0.2, 2.0, 20.0))
#define __BUFFERSIZE float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define __AREATEX_RANGE 16.
#define __AREATEX_TEXEL rcp(float2(160., 560.))
#define __AREATEX_SUBTEXEL 0.142857
#define __SEARCHTEX_SIZE float2(66.0, 33.0)
#define __SEARCHTEX_SIZE_PACKED float2(64.0, 16.0)
#define __8BIT_BY_7BIT 2.007874
#define __EDGETHRESHOLD clamp(EdgeThreshold, 0.02, 1.00)
#define __EDGE_FLOOR 0.008
#define __THRESHOLD_REDUCTION saturate(DynamicThreshold * 0.01)
#define __CORNER_ROUNDING saturate(CornerRounding * 0.01)

#define TSM_Tex2D(tex, coord) tex2Dlod(tex, (coord).xyxy)

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP END ****************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SUPPORT CODE START *************************************************************/
/*****************************************************************************************************************************************/

//////////////////////////////////////////////////////// HELPER FUNCTIONS ////////////////////////////////////////////////////////////////

float dotsat(float3 x)
{
	float xmax = max(max(x.r, x.g), x.b);
	float xmin = min(min(x.r, x.g), x.b);
	if (!xmax) return 0.0;
	float xmid = (x.r + x.g + x.b) - (xmax + xmin);
	float xbrightness = (xmax + xmid) * 0.5;
	return (xmax - xmin) * xbrightness;
}
float dotsat(float4 x)
{
	return dotsat(x.rgb);
}

// color delta calculator
float chromadelta(float3 pixel1, float3 pixel2)
{
	float3 delta = abs(pixel1 - pixel2);
	return max(max(delta.r, delta.g), delta.b);
}
float chromadelta(float4 pixel1, float4 pixel2)
{
		return chromadelta(pixel1.rgb, pixel2.rgb);
}

///////////////////////////////////////////////////// SMAA HELPER FUNCTIONS ///////////////////////////////////////////////////////////////

void TSMmovc(bool2 cond, inout float2 variable, float2 value)
{
    [flatten] if (cond.x) variable.x = value.x;
    [flatten] if (cond.y) variable.y = value.y;
}
void TSMmovc(bool4 cond, inout float4 variable, float4 value)
{
    TSMmovc(cond.xy, variable.xy, value.xy);
    TSMmovc(cond.zw, variable.zw, value.zw);
}

float2 TSMDecodeSubSample(float2 e)
{
    e.r = e.r * abs(5.0 * e.r - 3.75);
    return round(e);
}
float4 TSMDecodeSubSample(float4 e)
{
    e.rb = e.rb * abs(5.0 * e.rb - 3.75);
    return round(e);
}

float2 TSMScanD(sampler2D TSMedgeTEX, float2 texcoord, float2 dir, out float2 e)
{
    float4 coord = float4(texcoord, -1.0, 1.0);
    float3 t = float3(__BUFFERSIZE.xy, 1.0);
    float range = __SCANRADIUSDIAG - 1.0;
    
    [loop] while (coord.z < range) 
	{
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
        e = tex2Dlod(TSMedgeTEX, coord.xyxy).rg;
        coord.w = dot(e, 0.5);
        if (coord.w < 0.9) break;
    }
    
    return coord.zw;
}
float2 TSMScanD2(sampler2D edgesTex, float2 texcoord, float2 dir, out float2 e)
{
    float4 coord = float4(texcoord, -1.0, 1.0);
    coord.x += 0.25 * __BUFFERSIZE.x;
    float3 t = float3(__BUFFERSIZE.xy, 1.0);
    float range = __SCANRADIUSDIAG - 1.0;
    
    [loop] while (coord.z < range) 
	{
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
       
        e = tex2Dlod(edgesTex, coord.xyxy).rg;
        e = TSMDecodeSubSample(e);
        
        coord.w = dot(e, 0.5);
        if (coord.w < 0.9) break;
    }
    
    return coord.zw;
}


float2 TSMDiagArea(sampler2D TSMareaTEX, float2 dist, float2 e)
{
    float2 texcoord = mad(float(__SCANRADIUSDIAG).xx, e, dist);

    texcoord = mad(__AREATEX_TEXEL, texcoord, 0.5 * __AREATEX_TEXEL);
    texcoord.x += 0.5;

    return tex2Dlod(TSMareaTEX, texcoord.xyxy).rg;
}

float2 TSMGetDiagWt(sampler2D TSMedgeTEX, sampler2D TSMareaTEX, float2 texcoord, float2 e)
{
    float2 weights = 0;
    float2 end;
    float4 d;
    d.ywxz = float4(TSMScanD(TSMedgeTEX, texcoord, float2(1.0, -1.0), end), 0.0, 0.0);
    
    if (e.r > 0.0) 
	{
        d.xz = TSMScanD(TSMedgeTEX, texcoord, float2(-1.0,  1.0), end);
        d.x += float(end.y > 0.9);
    }
	
	if ((d.x + d.y) > 2.0) 
	{
        float4 coords = mad(float4(-d.x, d.x, d.y, -d.y), __BUFFERSIZE.xyxy, texcoord.xyxy);
        float4 c;
        c.x = tex2Dlodoffset(TSMedgeTEX, coords.xyxy, int2(-1,  0)).g;
        c.y = tex2Dlodoffset(TSMedgeTEX, coords.xyxy, int2( 0,  0)).r;
        c.z = tex2Dlodoffset(TSMedgeTEX, coords.zwzw, int2( 1,  0)).g;
        c.w = tex2Dlodoffset(TSMedgeTEX, coords.zwzw, int2( 1, -1)).r;
        
        float2 cc = mad(float(2.0).xx, c.xz, c.yw);

        TSMmovc(bool2(step(0.9, d.zw)), cc, 0.0);

        weights += TSMDiagArea(TSMareaTEX, d.xy, cc);
    }

    d.xz = TSMScanD2(TSMedgeTEX, texcoord, float2(-1.0, -1.0), end);
    d.yw = 0.0;
    
    if (TSM_Tex2D(TSMedgeTEX, texcoord + float2(BUFFER_RCP_WIDTH, 0)).r > 0.0) 
	{
        d.yw = TSMScanD2(TSMedgeTEX, texcoord, 1.0, end);
        d.y += float(end.y > 0.9);
    }
	
	if ((d.x + d.y) > 2.0) 
	{
        float4 coords = mad(float4(-d.x, -d.x, d.y, d.y), __BUFFERSIZE.xyxy, texcoord.xyxy);
        float4 c;
        c.x  = tex2Dlodoffset(TSMedgeTEX, coords.xyxy, int2(-1,  0)).g;
        c.y  = tex2Dlodoffset(TSMedgeTEX, coords.xyxy, int2( 0, -1)).r;
        c.zw = tex2Dlodoffset(TSMedgeTEX, coords.zwzw, int2( 1,  0)).gr;
        float2 cc = mad(2.0, c.xz, c.yw);

        TSMmovc(bool2(step(0.9, d.zw)), cc, 0.0);

        weights += TSMDiagArea(TSMareaTEX, d.xy, cc).gr;
    }

    return weights;
}

float TSMGetScanRef(sampler2D TSMsearchTEX, float2 e, float offset)
{
    float2 scale = __SEARCHTEX_SIZE * float2(0.5, -1.0);
    float2 bias = __SEARCHTEX_SIZE * float2(offset, 1.0);

    scale += float2(-1.0,  1.0);
    bias  += float2( 0.5, -0.5);

    scale *= rcp(__SEARCHTEX_SIZE_PACKED);
    bias *= rcp(__SEARCHTEX_SIZE_PACKED);

    return tex2Dlod(TSMsearchTEX, mad(scale, e, bias).xyxy).r;
}

float TSMScanXL(sampler2D TSMedgeTEX, sampler2D TSMsearchTEX, float2 texcoord, float end)
{
    float2 e = float2(0.0, 1.0);
    
    [loop] while (texcoord.x > end) 
	{
        e = tex2Dlod(TSMedgeTEX, texcoord.xyxy).rg;
        texcoord.x -= 2. * BUFFER_RCP_WIDTH;
        
        if (e.r || (e.g < 0.751)) break;
    }
    float offset = mad(-__8BIT_BY_7BIT, TSMGetScanRef(TSMsearchTEX, e, 0.0), 3.25);
    return mad(__BUFFERSIZE.x, offset, texcoord.x);
}
float TSMScanXR(sampler2D TSMedgeTEX, sampler2D TSMsearchTEX, float2 texcoord, float end)
{
    float2 e = float2(0.0, 1.0);
    
    [loop] while (texcoord.x < end) 
	{
        e = tex2Dlod(TSMedgeTEX, texcoord.xyxy).rg;
        texcoord.x += 2. * BUFFER_RCP_WIDTH;
        
        if (e.r || (e.g < 0.751)) break;
    }
    float offset = mad(-__8BIT_BY_7BIT, TSMGetScanRef(TSMsearchTEX, e, 0.5), 3.25);
    return mad(-__BUFFERSIZE.x, offset, texcoord.x);
}
float TSMScanYUp(sampler2D TSMedgeTEX, sampler2D TSMsearchTEX, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    
    [loop] while (texcoord.y > end) 
	{
        e = tex2Dlod(TSMedgeTEX, texcoord.xyxy).rg;
        texcoord.y -= 2. * BUFFER_RCP_HEIGHT;
        
        if (e.g || (e.r < 0.874)) break;
    }
    float offset = mad(-__8BIT_BY_7BIT, TSMGetScanRef(TSMsearchTEX, e.gr, 0.0), 3.25);
    return mad(__BUFFERSIZE.y, offset, texcoord.y);
}
float TSMScanYDn(sampler2D TSMedgeTEX, sampler2D TSMsearchTEX, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    
    [loop] while (texcoord.y < end) 
	{
        e = tex2Dlod(TSMedgeTEX, texcoord.xyxy).rg;
        texcoord.y += 2. * BUFFER_RCP_HEIGHT;
        
        if (e.g || (e.r < 0.874)) break;
    }
    float offset = mad(-__8BIT_BY_7BIT, TSMGetScanRef(TSMsearchTEX, e.gr, 0.5), 3.25);
    return mad(-__BUFFERSIZE.y, offset, texcoord.y);
}

float2 TSMGetAreaRef(sampler2D TSMareaTEX, float2 dist, float e1, float e2)
{
    float2 texcoord = mad(__AREATEX_RANGE, 4.0 * float2(e1, e2), dist);
    
    texcoord = mad(__AREATEX_TEXEL, texcoord, 0.5 * __AREATEX_TEXEL);

    return tex2Dlod(TSMareaTEX, texcoord.xyxy).rg;
}

void TSMFindCornersX(sampler2D TSMedgeTEX, inout float2 weights, float4 texcoord, float2 d)
{
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - __CORNER_ROUNDING) * leftRight;
    float2 tcs = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

    float2 factor = float(1.0).xx;
    factor.x -= rounding.x * tex2Dlod(TSMedgeTEX, texcoord.xyxy + float4(0, tcs.y, 0, 0)).r;
    factor.x -= rounding.y * tex2Dlod(TSMedgeTEX, texcoord.zwzw + float4(tcs, 0, 0)).r;
    factor.y -= rounding.x * tex2Dlod(TSMedgeTEX, texcoord.xyxy + float4(0, -3.0 * tcs.y, 0, 0)).r;
    factor.y -= rounding.y * tex2Dlod(TSMedgeTEX, texcoord.zwzw + float4(tcs.x, -3.0 * tcs.y, 0, 0)).r;

    weights *= saturate(factor);
}
void TSMFindCornersY(sampler2D TSMedgeTEX, inout float2 weights, float4 texcoord, float2 d)
{
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - __CORNER_ROUNDING) * leftRight;
    float2 tcs = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

    float2 factor = float(1.0).xx;
    factor.x -= rounding.x * tex2Dlod(TSMedgeTEX, texcoord.xyxy + float4(tcs.x, 0, 0, 0)).g;
    factor.x -= rounding.y * tex2Dlod(TSMedgeTEX, texcoord.zwzw + float4(tcs, 0, 0)).g;
    factor.y -= rounding.x * tex2Dlod(TSMedgeTEX, texcoord.xyxy + float4(-3.0 * tcs.x, 0, 0, 0)).g;
    factor.y -= rounding.y * tex2Dlod(TSMedgeTEX, texcoord.zwzw + float4(-3.0 * tcs.x, tcs.y, 0, 0)).g;

    weights *= saturate(factor);
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/******************************************************* SHADER SETUP START ************************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

//////////////////////////////////////////////////////////// TEXTURES ///////////////////////////////////////////////////////////////////

texture TSMedgeTEX
#if __RESHADE__ >= 50000
< pooled = true; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG16F;
};
sampler TSMedges {Texture = TSMedgeTEX;};

texture TSMdataTEX
#if __RESHADE__ >= 50000
< pooled = true; >
#endif
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
sampler TSMdata {Texture = TSMdataTEX;};

texture TSMareaTEX < source = "AreaTex.png"; >
{
	Width = 160;
	Height = 560;
	Format = RG8;
};
sampler TSMareaREF {Texture = TSMareaTEX;};


texture TSMsearchTEX < source = "SearchTex.png"; >
{
	Width = 64;
	Height = 16;
	Format = R8;
};
sampler TSMsearchREF {Texture = TSMsearchTEX;};

#if TSM_ENABLE_DEBUG_PASS
texture TSMdebugTEX
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
sampler TSMdebug {Texture = TSMdebugTEX;};
#endif

//////////////////////////////////////////////////////////// VERTEX SHADERS /////////////////////////////////////////////////////////////

void TSMEdgeScanVS(float2 texcoord,
                         out float4 offset[3]) {
    offset[0] = mad(__BUFFERSIZE.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    offset[1] = mad(__BUFFERSIZE.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
    offset[2] = mad(__BUFFERSIZE.xyxy, float4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy);
}
void TSMEdgeScanWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	TSMEdgeScanVS(texcoord, offset);
}

void TSMBlendCalcVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0, out float2 pixcoord : TEXCOORD1, out float4 offset[3] : TEXCOORD2)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    pixcoord = texcoord * __BUFFERSIZE.zw;

    offset[0] = mad(__BUFFERSIZE.xyxy, float4(-0.25, -0.125,  1.25, -0.125), texcoord.xyxy);
    offset[1] = mad(__BUFFERSIZE.xyxy, float4(-0.125, -0.25, -0.125,  1.25), texcoord.xyxy);
	
	float searchrange = __SCANRADIUS;
	
    offset[2] = mad(__BUFFERSIZE.xxyy,
                    float2(-2.0, 2.0).xyxy * searchrange,
                    float4(offset[0].xz, offset[1].yw));
}

void TSMBlendingVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0, out float4 offset : TEXCOORD1)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    offset = mad(__BUFFERSIZE.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
}

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/********************************************************** SMAA SHADER CODE START *******************************************************/
/*****************************************************************************************************************************************/

float2 TSMEdgeScanPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float4 offset[3] : TEXCOORD1) : SV_Target
{
	float3 middle = TSM_Tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 ref = __LUMA_REF;
	
    float L = dot(middle, ref);
    float3 top = TSM_Tex2D(ReShade::BackBuffer, offset[0].zw).rgb;
    float Dtop = chromadelta(middle, top);
    float Ltop = dot(top, ref);
    float3 left = TSM_Tex2D(ReShade::BackBuffer, offset[0].xy).rgb;
    float Dleft = chromadelta(middle, left);
    float Lleft = dot(left, ref);
    float Lavg = (L + Ltop + Lleft) * 0.333333;

	float rangemult = LowLumaThreshold ? saturate(1.0 - clamp(Lavg, 0.0, LowLumaThreshold) * rcp(LowLumaThreshold)) : 0.0;

	float edgethreshold = __EDGETHRESHOLD;

	edgethreshold = clamp(mad(rangemult, -(__THRESHOLD_REDUCTION * edgethreshold), edgethreshold), __EDGE_FLOOR, 1.00);
	
	float2 edges = step(edgethreshold, float2(Dleft, Dtop));
	if (!any(edges)) return 0.0;
    
    float3 right = TSM_Tex2D(ReShade::BackBuffer, offset[1].xy).rgb;
    float Dright = chromadelta(middle, right);
    float3 bottom = TSM_Tex2D(ReShade::BackBuffer, offset[1].zw).rgb;
    float Dbottom = chromadelta(middle, bottom);
    
    float2 maxdelta = float2(max(Dleft, Dright), max(Dtop, Dbottom));
    
    float Dleftleft = chromadelta(left, TSM_Tex2D(ReShade::BackBuffer, offset[2].xy).rgb);
    float Dtoptop = chromadelta(top, TSM_Tex2D(ReShade::BackBuffer, offset[2].zw).rgb);
	
	maxdelta = max(maxdelta, float2(Dleftleft, Dtoptop));
	float largestdelta = max(maxdelta.x, maxdelta.y);
	
	float3 localcontrast = (middle + left + top + right + bottom) * 0.2;
	float LCsat = dotsat(localcontrast);
	float LCL = dot(localcontrast, ref);
	float LCmult = length(float2(LCsat, LCL));
	float contrastadaptation = 2.0 + (localcontrast.r + localcontrast.g + localcontrast.b) * LCmult;
	edges *= step(largestdelta, contrastadaptation * float2(Dleft, Dtop));
	
	return edges;
}

float4 TSMBlendCalcPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float2 pixcoord : TEXCOORD1, float4 offset[3] : TEXCOORD2) : SV_Target
{
    float4 weights = 0;
    float2 e = TSM_Tex2D(TSMedges, texcoord).rg;
    
	[branch] if (e.g)
	{
    	float2 diagweights = TSMGetDiagWt(TSMedges, TSMareaREF, texcoord, e);
    	if (any(diagweights)) {weights.xy = diagweights; e.r = DCBlending ? e.r : 0.0;}
    	else
    	{
			float3 coords = float3(TSMScanXL(TSMedges, TSMsearchREF, offset[0].xy, offset[2].x), offset[1].y, TSMScanXR(TSMedges, TSMsearchREF, offset[0].zw, offset[2].y));
			float e1 = TSM_Tex2D(TSMedges, coords.xy).r;
			float2 d = coords.xz;
			d = abs((mad(__BUFFERSIZE.zz, d, -pixcoord.xx)));
			float e2 = TSM_Tex2D(TSMedges, coords.zy + float2(BUFFER_RCP_WIDTH, 0)).r;
			weights.rg = TSMGetAreaRef(TSMareaREF, sqrt(d), e1, e2);
			coords.y = texcoord.y;
			if (CornerDetection) TSMFindCornersX(TSMedges, weights.rg, coords.xyzy, d);
		}
    }
    
	if (!e.r) return weights;
		
    float3 coords = float3(offset[0].x, TSMScanYUp(TSMedges, TSMsearchREF, offset[1].xy, offset[2].z), TSMScanYDn(TSMedges, TSMsearchREF, offset[1].zw, offset[2].w));
    float e1 = TSM_Tex2D(TSMedges, coords.xy).g;
	float2 d = coords.yz;
    d = abs((mad(__BUFFERSIZE.ww, d, -pixcoord.yy)));
    float e2 = TSM_Tex2D(TSMedges, coords.xz + float2(0, BUFFER_RCP_HEIGHT)).g;
    weights.ba = TSMGetAreaRef(TSMareaREF, sqrt(d), e1, e2);
    coords.x = texcoord.x;
    if (CornerDetection) TSMFindCornersY(TSMedges, weights.ba, coords.xyxz, d);
    
    return weights;
}

float3 TSMNBlendingPS(float4 position : SV_Position, float2 texcoord : TEXCOORD0, float4 offset : TEXCOORD1) : SV_Target
{
	float3 resultAA = TSM_Tex2D(ReShade::BackBuffer, texcoord).rgb;
    float4 m = float4(TSM_Tex2D(TSMdata, offset.xy).a, TSM_Tex2D(TSMdata, offset.zw).g, TSM_Tex2D(TSMdata, texcoord).zx);

	[branch] if (any(m))
	{
		float maxweight = max(m.x + m.z, m.y + m.w);
		float minweight = min(m.x + m.z, m.y + m.w);
		float maxratio = maxweight * rcp(minweight + maxweight);
		float minratio = minweight * rcp(minweight + maxweight);
		
        bool horiz = (abs(m.x) + abs(m.z)) > (abs(m.y) + abs(m.w));
        
        float4 blendingOffset = 0.0.xxxx;
        float2 blendingWeight;
        
        TSMmovc(bool4(horiz, !horiz, horiz, !horiz), blendingOffset, float4(m.x, m.y, m.z, m.w));
        TSMmovc(bool(horiz).xx, blendingWeight, m.xz);
        TSMmovc(bool(!horiz).xx, blendingWeight, m.yw);
        blendingWeight *= rcp(dot(blendingWeight, float(1.0).xx));
        float4 blendingCoord = mad(blendingOffset, float4(__BUFFERSIZE.xy, -__BUFFERSIZE.xy), texcoord.xyxy);
        resultAA = (DCBlending ? maxratio : 1.0) * blendingWeight.x * TSM_Tex2D(ReShade::BackBuffer, blendingCoord.xy).rgb;
        resultAA += (DCBlending ? maxratio : 1.0) * blendingWeight.y * TSM_Tex2D(ReShade::BackBuffer, blendingCoord.zw).rgb;
        
        
        [branch] if (DCBlending && minratio != 0.0)
        {
        	blendingOffset = 0.0.xxxx;
        	TSMmovc(bool4(!horiz, horiz, !horiz, horiz), blendingOffset, float4(m.x, m.y, m.z, m.w));
	        TSMmovc(bool(!horiz).xx, blendingWeight, m.xz);
	        TSMmovc(bool(horiz).xx, blendingWeight, m.yw);
	        blendingWeight *= rcp(dot(blendingWeight, float(1.0).xx));
	        blendingCoord = mad(blendingOffset, float4(__BUFFERSIZE.xy, -__BUFFERSIZE.xy), texcoord.xyxy);
	        resultAA += minratio * blendingWeight.x * TSM_Tex2D(ReShade::BackBuffer, blendingCoord.xy).rgb;
	        resultAA += minratio * blendingWeight.y * TSM_Tex2D(ReShade::BackBuffer, blendingCoord.zw).rgb;
 	   }
    }
    
	return resultAA;
}

/***************************************************************************************************************************************/
/********************************************************** SMAA SHADER CODE END *******************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/**************************************************** TEMPORAL COMPOSITING CODE START **************************************************/
/***************************************************************************************************************************************/

float4 TSMCompositingPS(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	float4 framecurr = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy);
	float4 frameprev = tex2Dlod(TSMdata, texcoord.xyxy);
	float4 outframe = lerp(framecurr, frameprev, TemporalBlending);
	return (TemporalCompositing ? outframe : framecurr);
}

float4 TSMFramecopyPS(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	return tex2Dlod(ReShade::BackBuffer, texcoord.xyxy);
}

/***************************************************************************************************************************************/
/**************************************************** TEMPORAL COMPOSITING CODE -END- **************************************************/
/***************************************************************************************************************************************/

#if TSM_ENABLE_DEBUG_PASS
float4 TSMDebugCopyPS(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	if (DebugMode == 2) return tex2Dlod(TSMdata, texcoord.xyxy);
	if (DebugMode == 3) return tex2Dlod(ReShade::BackBuffer, texcoord.xyxy);
	return 0.0;
}

float4 TSMDebugDisplayPS(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	if (DebugMode == 0) return tex2Dlod(ReShade::BackBuffer, texcoord.xyxy);
	if (DebugMode == 1) return tex2Dlod(TSMedges, texcoord.xyxy);
	return tex2Dlod(TSMdebug, texcoord.xyxy);
}
#endif

technique TSMAA2
{
	pass TemporalCompositing
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMCompositingPS;
	}
	
	pass EdgeScan
	{
		VertexShader = TSMEdgeScanWrapVS;
		PixelShader = TSMEdgeScanPS;
		RenderTarget = TSMedgeTEX;
		ClearRenderTargets = true;
	}
	
	pass WeightCalculation
	{
		VertexShader = TSMBlendCalcVS;
		PixelShader = TSMBlendCalcPS;
		RenderTarget = TSMdataTEX;
		ClearRenderTargets = true;
	}
	
	#if TSM_ENABLE_DEBUG_PASS
	pass SaveDebugInfo
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMDebugCopyPS;
		RenderTarget = TSMdebugTEX;
		ClearRenderTargets = true;
	}
	#endif
	
	pass NeighborhoodBlending
	{
		VertexShader = TSMBlendingVS;
		PixelShader = TSMNBlendingPS;
	}
	
	pass SaveFramebuffer
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMFramecopyPS;
		RenderTarget = TSMdataTEX;
		ClearRenderTargets = true;
	}
	
	#if TSM_ENABLE_DEBUG_PASS
	pass DebugOutput
	{
		VertexShader = PostProcessVS;
		PixelShader = TSMDebugDisplayPS;
	}
	#endif
}
