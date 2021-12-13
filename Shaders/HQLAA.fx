/**
 *               HQLAA for ReShade 3.1.1+
 *
 *   (Hybrid high-Quality Luma-adaptive Anti-Aliasing)
 *
 *   Smooshes FXAA and SMAA together as a single shader
 *
 * Uses customized FXAA passes for dynamic luma channel select
 *
 *                       v0.6 beta
 *
 *                     by lordbean
 *
 */
 
 // This shader includes code adapted from:
 
 /*============================================================================


                    NVIDIA FXAA 3.11 by TIMOTHY LOTTES


------------------------------------------------------------------------------
COPYRIGHT (C) 2010, 2011 NVIDIA CORPORATION. ALL RIGHTS RESERVED.
------------------------------------------------------------------------------*/


//------------------------------- UI setup -----------------------------------------------

#include "ReShadeUI.fxh"

uniform float EdgeThreshold < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Edge Detection Threshold";
	ui_tooltip = "Local contrast required to run shader";
        ui_category = "Normal Usage";
> = 0.075;

uniform float Subpix < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Subpixel Effects Strength";
	ui_tooltip = "Lower = sharper image, Higher = more AA effect";
        ui_category = "Normal Usage";
> = 0.375;

uniform int PmodeWarning <
	ui_type = "radio";
	ui_label = " ";	
	ui_text ="\n>>>> WARNING <<<<\n\nVirtual Photography mode allows HQLAA to exceed its normal\nlimits when processing subpixel aliasing and will probably\nresult in too much blurring for everyday usage.\n\nIt is only intended for virtual photography purposes where\nthe game's UI is typically not present on the screen.";
	ui_category = "Virtual Photography";
>;

uniform bool Overdrive <
        ui_label = "Enable Virtual Photography Mode";
        ui_category = "Virtual Photography";
> = false;

uniform float SubpixBoost < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Extra Subpixel Effects Strength";
	ui_tooltip = "Additional boost to subpixel aliasing processing";
        ui_category = "Virtual Photography";
> = 0.00;

//------------------------------ Shader Setup -------------------------------------------

/****** COMPATIBILITY DEFINES (hopefully) *******************/
#ifdef FXAA_QUALITY_PRESET
	#undef FXAA_QUALITY_PRESET
#endif
#ifdef FXAA_GREEN_AS_LUMA
	#undef FXAA_GREEN_AS_LUMA
#endif
#ifdef FXAA_LINEAR_LIGHT
	#undef FXAA_LINEAR_LIGHT
#endif
#ifdef FXAA_PC
	#undef FXAA_PC
#endif
#ifdef FXAA_HLSL_3
	#undef FXAA_HLSL_3
#endif
#ifdef FXAA_GATHER4_ALPHA
	#undef FXAA_GATHER4_ALPHA
#endif
#ifdef FxaaTexAlpha4
	#undef FxaaTexAlpha4
#endif
#ifdef FxaaTexOffAlpha4
	#undef FxaaTexOffAlpha4
#endif
#ifdef FxaaTexGreen4
	#undef FxaaTexGreen4
#endif
#ifdef FxaaTexOffGreen4
	#undef FxaaTexOffGreen4
#endif

#ifdef SMAA_PRESET_LOW
	#undef SMAA_PRESET_LOW
#endif
#ifdef SMAA_PRESET_MEDIUM
	#undef SMAA_PRESET_MEDIUM
#endif
#ifdef SMAA_PRESET_HIGH
	#undef SMAA_PRESET_HIGH
#endif
#ifdef SMAA_PRESET_ULTRA
	#undef SMAA_PRESET_ULTRA
#endif
#ifdef SMAA_PRESET_CUSTOM
	#undef SMAA_PRESET_CUSTOM
#endif
#ifdef SMAA_THRESHOLD
	#undef SMAA_THRESHOLD
#endif
#ifdef SMAA_MAX_SEARCH_STEPS
	#undef SMAA_MAX_SEARCH_STEPS
#endif
#ifdef SMAA_MAX_SEARCH_STEPS_DIAG
	#undef SMAA_MAX_SEARCH_STEPS_DIAG
#endif
#ifdef SMAA_CORNER_ROUNDING
	#undef SMAA_CORNER_ROUNDING
#endif
#ifdef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
	#undef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
#endif
#ifdef SMAA_RT_METRICS
	#undef SMAA_RT_METRICS
#endif
#ifdef SMAA_CUSTOM_SL
	#undef SMAA_CUSTOM_SL
#endif
#ifdef SMAATexture2D
	#undef SMAATexture2D
#endif
#ifdef SMAATexturePass2D
	#undef SMAATexturePass2D
#endif
#ifdef SMAASampleLevelZero
	#undef SMAASampleLevelZero
#endif
#ifdef SMAASampleLevelZeroPoint
	#undef SMAASampleLevelZeroPoint
#endif
#ifdef SMAASampleLevelZeroOffset
	#undef SMAASampleLevelZeroOffset
#endif
#ifdef SMAASample
	#undef SMAASample
#endif
#ifdef SMAASamplePoint
	#undef SMAASamplePoint
#endif
#ifdef SMAASampleOffset
	#undef SMAASampleOffset
#endif
#ifdef SMAA_BRANCH
	#undef SMAA_BRANCH
#endif
#ifdef SMAA_FLATTEN
	#undef SMAA_FLATTEN
#endif
#ifdef SMAAGather
	#undef SMAAGather
#endif
#ifdef SMAA_DISABLE_DIAG_DETECTION
	#undef SMAA_DISABLE_DIAG_DETECTION
#endif
#ifdef SMAA_PREDICATION
	#undef SMAA_PREDICATION
#endif
#ifdef SMAA_REPROJECTION
	#undef SMAA_REPROJECTION
#endif
/************************************************************/

#define FXAA_GREEN_AS_LUMA 1    // using a color as luma seems to work better with SMAA.
#define SMAA_PRESET_CUSTOM
#define SMAA_THRESHOLD min(EdgeThreshold + 0.05, 1.0)
#define SMAA_MAX_SEARCH_STEPS 112
#define SMAA_CORNER_ROUNDING 0
#define SMAA_MAX_SEARCH_STEPS_DIAG 20
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR (1 + (0.375 * Subpix) + (Overdrive ? SubpixBoost*0.625 : 0))
#define FXAA_QUALITY__PRESET 39
#define FXAA_PC 1
#define FXAA_HLSL_3 1
#define SMAA_RT_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define SMAA_CUSTOM_SL 1
#define SMAATexture2D(tex) sampler tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, coord))
#define SMAASampleLevelZeroPoint(tex, coord) SMAASampleLevelZero(tex, coord)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlodoffset(tex, float4(coord, coord), offset)
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASamplePoint(tex, coord) SMAASample(tex, coord)
#define SMAASampleOffset(tex, coord, offset) tex2Doffset(tex, coord, offset)
#define SMAA_BRANCH [branch]
#define SMAA_FLATTEN [flatten]

#if (__RENDERER__ == 0xb000 || __RENDERER__ == 0xb100)
	#define SMAAGather(tex, coord) tex2Dgather(tex, coord, 0)
	#define FXAA_GATHER4_ALPHA 1
	#define FxaaTexAlpha4(t, p) tex2Dgather(t, p, 3)
	#define FxaaTexOffAlpha4(t, p, o) tex2Dgatheroffset(t, p, o, 3)
	#define FxaaTexGreen4(t, p) tex2Dgather(t, p, 1)
	#define FxaaTexOffGreen4(t, p, o) tex2Dgatheroffset(t, p, o, 1)
#endif

#include "SMAA.fxh"
#include "FXAA.fxh"
// ------------------------------------------ CUSTOM FXAA CODE START ------------------------------------------

#define FxaaTexLuma4(t, p) textureGather(t, p, lumatype)
#define FxaaTexOffLuma4(t, p, o) textureGatherOffset(t, p, o, lumatype)
#define FxaaAdaptiveLuma(t) FxaaAdaptiveLumaSelect(t, lumatype)


// Luma types match variable positions. 0=R 1=G 2=B 3=A
FxaaFloat FxaaAdaptiveLumaSelect (FxaaFloat4 rgba, int lumatype)
{
	if (lumatype == 0)
		return rgba.x;
	else if (lumatype == 2)
		return rgba.z;
	else if (lumatype == 3)
		return rgba.w;
	else
		return rgba.y;
}

FxaaFloat4 FxaaAdaptiveLumaPixelShader(FxaaFloat2 pos, FxaaFloat4 fxaaConsolePosPos, FxaaTex tex, FxaaTex fxaaConsole360TexExpBiasNegOne,
 FxaaTex fxaaConsole360TexExpBiasNegTwo, FxaaFloat2 fxaaQualityRcpFrame, FxaaFloat4 fxaaConsoleRcpFrameOpt,
 FxaaFloat4 fxaaConsoleRcpFrameOpt2, FxaaFloat4 fxaaConsole360RcpFrameOpt2, FxaaFloat fxaaQualitySubpix,
 FxaaFloat fxaaQualityEdgeThreshold, FxaaFloat fxaaQualityEdgeThresholdMin, FxaaFloat fxaaConsoleEdgeSharpness,
 FxaaFloat fxaaConsoleEdgeThreshold, FxaaFloat fxaaConsoleEdgeThresholdMin, FxaaFloat4 fxaaConsole360ConstDir) 
 {
    FxaaFloat2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
	
	int lumatype = 1; // assume green is luma until determined otherwise
    FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
	float lumatest = min(2.0 * rgbyM.y, 1.0);
	if ((rgbyM.x > lumatest) || (rgbyM.z > lumatest)) // if green signal is low and either blue or red has strong signal change luma color
		if (rgbyM.z > lumatest) // use blue if strong
			lumatype = 2;
		else			// otherwise use red as luma
			lumatype = 0;
			
	float lumaMa = (lumatype == 0 ? rgbyM.x : (lumatype == 2 ? rgbyM.z : rgbyM.y));
	
    FxaaFloat lumaS = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2( 0, 1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaE = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 0), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaN = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2( 0,-1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaW = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 0), fxaaQualityRcpFrame.xy));
	
/*--------------------------------------------------------------------------*/
    FxaaFloat maxSM = max(lumaS, lumaMa);
    FxaaFloat minSM = min(lumaS, lumaMa);
    FxaaFloat maxESM = max(lumaE, maxSM);
    FxaaFloat minESM = min(lumaE, minSM);
    FxaaFloat maxWN = max(lumaN, lumaW);
    FxaaFloat minWN = min(lumaN, lumaW);
    FxaaFloat rangeMax = max(maxWN, maxESM);
    FxaaFloat rangeMin = min(minWN, minESM);
    FxaaFloat rangeMaxScaled = rangeMax * fxaaQualityEdgeThreshold;
    FxaaFloat range = rangeMax - rangeMin;
    FxaaFloat rangeMaxClamped = max(fxaaQualityEdgeThresholdMin, rangeMaxScaled);
    FxaaBool earlyExit = range < rangeMaxClamped;
/*--------------------------------------------------------------------------*/
    if(earlyExit)
        #if (FXAA_DISCARD == 1)
            FxaaDiscard;
        #else
            return rgbyM;
        #endif
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNW = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2(-1,-1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaSE = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaNE = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2( 1,-1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaSW = FxaaAdaptiveLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNS = lumaN + lumaS;
    FxaaFloat lumaWE = lumaW + lumaE;
    FxaaFloat subpixRcpRange = 1.0/range;
    FxaaFloat subpixNSWE = lumaNS + lumaWE;
    FxaaFloat edgeHorz1 = (-2.0 * lumaMa) + lumaNS;
    FxaaFloat edgeVert1 = (-2.0 * lumaMa) + lumaWE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNESE = lumaNE + lumaSE;
    FxaaFloat lumaNWNE = lumaNW + lumaNE;
    FxaaFloat edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    FxaaFloat edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNWSW = lumaNW + lumaSW;
    FxaaFloat lumaSWSE = lumaSW + lumaSE;
    FxaaFloat edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    FxaaFloat edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    FxaaFloat edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    FxaaFloat edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    FxaaFloat edgeHorz = abs(edgeHorz3) + edgeHorz4;
    FxaaFloat edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    FxaaFloat subpixNWSWNESE = lumaNWSW + lumaNESE;
    FxaaFloat lengthSign = fxaaQualityRcpFrame.x;
    FxaaBool horzSpan = edgeHorz >= edgeVert;
    FxaaFloat subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
/*--------------------------------------------------------------------------*/
    if(!horzSpan) lumaN = lumaW;
    if(!horzSpan) lumaS = lumaE;
    if(horzSpan) lengthSign = fxaaQualityRcpFrame.y;
    FxaaFloat subpixB = (subpixA * (1.0/12.0)) - lumaMa;
/*--------------------------------------------------------------------------*/
    FxaaFloat gradientN = lumaN - lumaMa;
    FxaaFloat gradientS = lumaS - lumaMa;
    FxaaFloat lumaNN = lumaN + lumaMa;
    FxaaFloat lumaSS = lumaS + lumaMa;
    FxaaBool pairN = abs(gradientN) >= abs(gradientS);
    FxaaFloat gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    FxaaFloat subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    FxaaFloat2 offNP;
    offNP.x = (!horzSpan) ? 0.0 : fxaaQualityRcpFrame.x;
    offNP.y = ( horzSpan) ? 0.0 : fxaaQualityRcpFrame.y;
    if(!horzSpan) posB.x += lengthSign * 0.5;
    if( horzSpan) posB.y += lengthSign * 0.5;
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posN;
    posN.x = posB.x - offNP.x * FXAA_QUALITY__P0;
    posN.y = posB.y - offNP.y * FXAA_QUALITY__P0;
    FxaaFloat2 posP;
    posP.x = posB.x + offNP.x * FXAA_QUALITY__P0;
    posP.y = posB.y + offNP.y * FXAA_QUALITY__P0;
    FxaaFloat subpixD = ((-2.0)*subpixC) + 3.0;
    FxaaFloat lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN));
    FxaaFloat subpixE = subpixC * subpixC;
    FxaaFloat lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP));
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS;
    FxaaFloat gradientScaled = gradient * 1.0/4.0;
    FxaaFloat lumaMM = lumaMa - lumaNN * 0.5;
    FxaaFloat subpixF = subpixD * subpixE;
    FxaaBool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN * 0.5;
    lumaEndP -= lumaNN * 0.5;
    FxaaBool doneN = abs(lumaEndN) >= gradientScaled;
    FxaaBool doneP = abs(lumaEndP) >= gradientScaled;
    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P1;
    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P1;
    FxaaBool doneNP = (!doneN) || (!doneP);
    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P1;
    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P1;
/*--------------------------------------------------------------------------*/
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P2;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P2;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P2;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P2;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 3)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P3;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P3;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P3;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P3;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 4)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P4;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P4;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P4;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P4;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 5)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P5;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P5;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P5;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P5;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 6)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P6;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P6;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P6;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P6;
/*--------------------------------------------------------------------------*/
                        #if (FXAA_QUALITY__PS > 7)
                        if(doneNP) {
                            if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                            if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                            doneN = abs(lumaEndN) >= gradientScaled;
                            doneP = abs(lumaEndP) >= gradientScaled;
                            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P7;
                            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P7;
                            doneNP = (!doneN) || (!doneP);
                            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P7;
                            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P7;
/*--------------------------------------------------------------------------*/
    #if (FXAA_QUALITY__PS > 8)
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P8;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P8;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P8;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P8;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 9)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P9;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P9;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P9;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P9;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 10)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P10;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P10;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P10;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P10;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 11)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P11;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P11;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P11;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P11;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 12)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaAdaptiveLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaAdaptiveLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P12;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P12;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P12;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P12;
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
    #endif
/*--------------------------------------------------------------------------*/
                        }
                        #endif
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
/*--------------------------------------------------------------------------*/
    FxaaFloat dstN = posM.x - posN.x;
    FxaaFloat dstP = posP.x - posM.x;
    if(!horzSpan) dstN = posM.y - posN.y;
    if(!horzSpan) dstP = posP.y - posM.y;
/*--------------------------------------------------------------------------*/
    FxaaBool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    FxaaFloat spanLength = (dstP + dstN);
    FxaaBool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    FxaaFloat spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    FxaaBool directionN = dstN < dstP;
    FxaaFloat dst = min(dstN, dstP);
    FxaaBool goodSpan = directionN ? goodSpanN : goodSpanP;
    FxaaFloat subpixG = subpixF * subpixF;
    FxaaFloat pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
    FxaaFloat subpixH = subpixG * fxaaQualitySubpix;
/*--------------------------------------------------------------------------*/
    FxaaFloat pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    FxaaFloat pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
    if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
    if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;
    #if (FXAA_DISCARD == 1)
        return FxaaTexTop(tex, posM);
    #else
        return FxaaFloat4(FxaaTexTop(tex, posM).xyz, lumaMa);
    #endif
}

// ------------------------------------------ CUSTOM FXAA CODE END --------------------------------------------
#include "ReShade.fxh"

#undef FXAA_QUALITY__PS
#undef FXAA_QUALITY__P0
#undef FXAA_QUALITY__P1
#undef FXAA_QUALITY__P2
#undef FXAA_QUALITY__P3
#undef FXAA_QUALITY__P4
#undef FXAA_QUALITY__P5
#undef FXAA_QUALITY__P6
#undef FXAA_QUALITY__P7
#undef FXAA_QUALITY__P8
#undef FXAA_QUALITY__P9
#undef FXAA_QUALITY__P10
#undef FXAA_QUALITY__P11
#define FXAA_QUALITY__PS 13
#define FXAA_QUALITY__P0 0.25
#define FXAA_QUALITY__P1 0.5
#define FXAA_QUALITY__P2 0.75
#define FXAA_QUALITY__P3 1.0
#define FXAA_QUALITY__P4 1.25
#define FXAA_QUALITY__P5 1.5
#define FXAA_QUALITY__P6 1.75
#define FXAA_QUALITY__P7 2.0
#define FXAA_QUALITY__P8 2.5
#define FXAA_QUALITY__P9 3.0
#define FXAA_QUALITY__P10 3.5
#define FXAA_QUALITY__P11 4.0
#define FXAA_QUALITY__P12 5.0

//------------------------------------- Textures -------------------------------------------

texture edgesTex < pooled = true; >
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
texture blendTex < pooled = true; >
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};

texture areaTex < source = "AreaTex.png"; >
{
	Width = 160;
	Height = 560;
	Format = RG8;
};
texture searchTex < source = "SearchTex.png"; >
{
	Width = 64;
	Height = 16;
	Format = R8;
};

// -------------------------------- Samplers -----------------------------------------------

sampler colorGammaSampler
{
	Texture = ReShade::BackBufferTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Point; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler colorLinearSampler
{
	Texture = ReShade::BackBufferTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Point; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = true;
};
sampler edgesSampler
{
	Texture = edgesTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler blendSampler
{
	Texture = blendTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler areaSampler
{
	Texture = areaTex;
	AddressU = Clamp; AddressV = Clamp; AddressW = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler searchSampler
{
	Texture = searchTex;
	AddressU = Clamp; AddressV = Clamp; AddressW = Clamp;
	MipFilter = Point; MinFilter = Point; MagFilter = Point;
	SRGBTexture = false;
};
sampler FXAATexture
{
	Texture = ReShade::BackBufferTex;
	MinFilter = Linear; MagFilter = Linear;
};

//----------------------------------- Vertex Shaders ---------------------------------------

void SMAAEdgeDetectionWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	SMAAEdgeDetectionVS(texcoord, offset);
}
void SMAABlendingWeightCalculationWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float2 pixcoord : TEXCOORD1,
	out float4 offset[3] : TEXCOORD2)
{
	PostProcessVS(id, position, texcoord);
	SMAABlendingWeightCalculationVS(texcoord, pixcoord, offset);
}
void SMAANeighborhoodBlendingWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	SMAANeighborhoodBlendingVS(texcoord, offset);
}

// -------------------------------- Pixel shaders ------------------------------------------

float2 SMAAEdgeDetectionWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float4 offset[3] : TEXCOORD1) : SV_Target
{
	float2 color = SMAAColorEdgeDetectionPS(texcoord, offset, colorGammaSampler);
	float2 luma = SMAALumaEdgeDetectionPS(texcoord, offset, colorGammaSampler);
	float2 result = float2(sqrt(color.r * luma.r), sqrt(color.g * luma.g));
	return result;
}
float4 SMAABlendingWeightCalculationWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float2 pixcoord : TEXCOORD1,
	float4 offset[3] : TEXCOORD2) : SV_Target
{
	return SMAABlendingWeightCalculationPS(texcoord, pixcoord, offset, edgesSampler, areaSampler, searchSampler, 0.0);
}
float3 SMAANeighborhoodBlendingWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float4 offset : TEXCOORD1) : SV_Target
{
	return SMAANeighborhoodBlendingPS(texcoord, offset, colorLinearSampler, blendSampler).rgb;
}

float4 FXAAPixelShaderAdaptiveCoarse(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float TotalSubpix = Subpix * 0.250;
	if (Overdrive)
		TotalSubpix += SubpixBoost * 0.5;
	float4 output = FxaaAdaptiveLumaPixelShader(texcoord,0,FXAATexture,FXAATexture,FXAATexture,BUFFER_PIXEL_SIZE,0,0,0,TotalSubpix,0.5 + (EdgeThreshold * 0.5),0.012,0,0,0,0);
	return saturate(output);
}

float4 FXAAPixelShaderAdaptiveFine(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float TotalSubpix = Subpix * 0.5;
	if (Overdrive)
		TotalSubpix += SubpixBoost * 0.5;
	float4 output = FxaaAdaptiveLumaPixelShader(texcoord,0,FXAATexture,FXAATexture,FXAATexture,BUFFER_PIXEL_SIZE,0,0,0,TotalSubpix,max(0.03125,EdgeThreshold),0.004,0,0,0,0);
	return saturate(output);
}

// -------------------------------- Rendering passes ----------------------------------------

technique HQLAA <
	ui_tooltip = "\nHybrid high-Quality Luma-adaptive AA combines techniques\n"
				 "of both SMAA and FXAA to produce best possible image quality\n"
				 "from using both. It uses customized FXAA passes designed to\n"
				 "detect aliasing in pure blue or red scenes where normal\n"
				 "green-as-luma FXAA would fail to produce a result.\n";
>
{
	pass SMAAEdgeDetection
	{
		VertexShader = SMAAEdgeDetectionWrapVS;
		PixelShader = SMAAEdgeDetectionWrapPS;
		RenderTarget = edgesTex;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = REPLACE;
		StencilRef = 1;
	}
	pass SMAABlendWeightCalculation
	{
		VertexShader = SMAABlendingWeightCalculationWrapVS;
		PixelShader = SMAABlendingWeightCalculationWrapPS;
		RenderTarget = blendTex;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = KEEP;
		StencilFunc = EQUAL;
		StencilRef = 1;
	}
	pass SMAANeighborhoodBlending
	{
		VertexShader = SMAANeighborhoodBlendingWrapVS;
		PixelShader = SMAANeighborhoodBlendingWrapPS;
		StencilEnable = false;
		SRGBWriteEnable = true;
	}
	pass FXAACoarse
	{
		VertexShader = PostProcessVS;
		PixelShader = FXAAPixelShaderAdaptiveCoarse;
	}
	pass FXAAFine
	{
		VertexShader = PostProcessVS;
		PixelShader = FXAAPixelShaderAdaptiveFine;
	}
}
