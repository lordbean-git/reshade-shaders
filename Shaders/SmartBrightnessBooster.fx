/*               Smart Brightness Booster
 *
 *          		  by lordbean
 *
 *          (c) 2022 Derek Brush aka lordbean
 *				  derekbrush@gmail.com
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

uniform int BrightnessIntro <
	ui_spacing = 3;
	ui_type = "radio";
	ui_label = "Version: 1.0.281";
	ui_text = "--------------------------------------------------------------------------------\n"
			"                Smart Brightness Booster, a shader by lordbean\n"
			"               https://github.com/lordbean-git/reshade-shaders/\n"
			"--------------------------------------------------------------------------------\n\n"
			"Logarithmically adjusts the brightness of the scene, then normalizes the\n"
			"contrast ratio by computing the delta in the 'black' signal floor.\n\n"
			
			"Note: This shader is only designed for SDR color format. It will not produce\n"
			"useful output in any HDR mode.\n\n"
			
			"--------------------------------------------------------------------------------";
	ui_category = "About";
	ui_category_closed = true;
>;

uniform int BrightnessIntroEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

uniform float BrightnessGainStrength <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 0.75; ui_step = 0.001;
	ui_label = "Boost";
> = 0.333333;

uniform int BrightnessOptionsEOF <
	ui_type = "radio";
	ui_label = " ";
	ui_text = "\n--------------------------------------------------------------------------------";
>;

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP END ****************************************************************/
/*****************************************************************************************************************************************/

/*****************************************************************************************************************************************/
/******************************************************** SUPPORT CODE START *************************************************************/
/*****************************************************************************************************************************************/

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

float intpow(float x, float y)
{
	float result = x;
	uint basepower = 1;
	uint raisepower = round(abs(y));
	// power of zero override
	if (raisepower == 0) return 1.0;
	// compiler warning dodge
	else if (raisepower == 2) return x * x;
	while (basepower < raisepower)
	{
		result *= x;
		basepower++;
	}
	return result;
}
float2 intpow(float2 x, float y)
{
	float2 result = x;
	uint basepower = 1;
	uint raisepower = round(abs(y));
	// power of zero override
	if (raisepower == 0) return 1.0.xx;
	// compiler warning dodge
	else if (raisepower == 2) return x * x;
	while (basepower < raisepower)
	{
		result *= x;
		basepower++;
	}
	return result;
}
float3 intpow(float3 x, float y)
{
	float3 result = x;
	uint basepower = 1;
	uint raisepower = round(abs(y));
	// power of zero override
	if (raisepower == 0) return 1.0.xxx;
	// compiler warning dodge
	else if (raisepower == 2) return x * x;
	while (basepower < raisepower)
	{
		result *= x;
		basepower++;
	}
	return result;
}
float4 intpow(float4 x, float y)
{
	float4 result = x;
	uint basepower = 1;
	uint raisepower = round(abs(y));
	// power of zero override
	if (raisepower == 0) return 1.0.xxxx;
	// compiler warning dodge
	else if (raisepower == 2) return x * x;
	while (basepower < raisepower)
	{
		result *= x;
		basepower++;
	}
	return result;
}

float dotsat(float3 x)
{
	// trunc(xl) only = 1 when x = float3(1,1,1)
	// float3(1,1,1) produces 0/0 in the original calculation
	// this should change it to 0/1 to avoid the possible NaN out
	float xl = dot(x, float3(0.2126, 0.7152, 0.0722));
	return ((max(max(x.r, x.g), x.b) - min(min(x.r, x.g), x.b)) / (1.0 - (2.0 * xl - 1.0) + trunc(xl)));
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
		float maxboost = rcp(max(abs(yuv.y), abs(yuv.z)) / 0.5);
		if (adjustment > maxboost) adjustment = maxboost;
	}
	
	// compute delta Cr,Cb
	yuv.y = yuv.y > 0.0 ? clamp(yuv.y + (adjustment * yuv.y), 0.0, 0.5) : clamp(yuv.y - (adjustment * abs(yuv.y)), -0.5, 0.0);
	yuv.z = yuv.z > 0.0 ? clamp(yuv.z + (adjustment * yuv.z), 0.0, 0.5) : clamp(yuv.z - (adjustment * abs(yuv.z)), -0.5, 0.0);
	
	// change back to ARGB color space
	return YUVtoRGB(yuv);
}

/***************************************************************************************************************************************/
/******************************************************** SUPPORT CODE END *************************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

/***************************************************************************************************************************************/
/********************************************************** SHADER SETUP END ***********************************************************/
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/********************************************************* PIXEL SHADER CODE START *****************************************************/
/***************************************************************************************************************************************/

float3 BrightnessBoosterPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	if (BrightnessGainStrength > 0.0)
	{
		float3 outdot = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy).rgb;
		float presaturation = dotsat(outdot);
		float preluma = dot(outdot, float3(0.2126, 0.7152, 0.0722));
		float colorgain = 2.0 - log2(BrightnessGainStrength + 1.0);
		float channelfloor = rcp(intpow(2, BUFFER_COLOR_BIT_DEPTH));
		outdot = log2(clamp(outdot, channelfloor, 1.0 - channelfloor));
		outdot = pow(abs(colorgain), outdot);
		// calculate new black level
		channelfloor = pow(abs(colorgain), log2(channelfloor));
		// calculate reduction strength to apply
		float contrastgain = log(rcp(dot(outdot, float3(0.2126, 0.7152, 0.0722)) - channelfloor)) * pow(2.718282, (1.0 + channelfloor) * 2.718282) * BrightnessGainStrength * BrightnessGainStrength;
		outdot = pow(abs(2.0 + contrastgain) * 5.0, log10(outdot));
		float lumadelta = dot(outdot, float3(0.2126, 0.7152, 0.0722)) - preluma;
		outdot = RGBtoYUV(outdot);
		outdot.x = saturate(outdot.x - lumadelta * channelfloor);
		outdot = YUVtoRGB(outdot);
		float newsat = dotsat(outdot);
		float satadjust = abs(((newsat - presaturation) / 2.0) * (1.0 + BrightnessGainStrength)); // compute difference in before/after saturation
		if (satadjust != 0.0) outdot = AdjustSaturation(outdot, 0.5 + satadjust);
		return outdot;
	}
	else discard;
}
	
/***************************************************************************************************************************************/
/********************************************************** PIXEL SHADER CODE END ******************************************************/
/***************************************************************************************************************************************/

technique SmartBrightnessBooster <
	ui_label = "Smart Brightness Booster";
	ui_tooltip = "Increases the brightness and normalizes contrast ratio\n"
				 "to preserve detail. Intended as a quick fix for dark\n"
				 "games or monitors.";
>
{
	pass OptionalEffects
	{
		VertexShader = PostProcessVS;
		PixelShader = BrightnessBoosterPS;
	}
}
