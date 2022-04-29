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
	ui_label = "Version: 1.1.282";
	ui_text = "--------------------------------------------------------------------------------\n"
			"                Smart Brightness Booster, a shader by lordbean\n"
			"               https://github.com/lordbean-git/reshade-shaders/\n"
			"--------------------------------------------------------------------------------\n\n"
			"Logarithmically adjusts the brightness of the scene, then normalizes the\n"
			"contrast ratio by computing the delta in the 'black' signal floor. Can also\n"
			"optionally adjust the vibrance and/or saturation of the scene.\n\n"
			
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

uniform float VibranceStrength <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Vibrance";
	ui_spacing = 3;
> = 0.5;

uniform float SaturationStrength <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
	ui_label = "Saturation";
> = 0.5;

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
	if (raisepower == 0) return 1.0;
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
	if (raisepower == 0) return 1.0.xx;
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
	if (raisepower == 0) return 1.0.xxx;
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
	if (raisepower == 0) return 1.0.xxxx;
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
	float xl = dot(x, float3(0.2126, 0.7152, 0.0722));
	return ((max(max(x.r, x.g), x.b) - min(min(x.r, x.g), x.b)) / (1.0 - (2.0 * xl - 1.0) + trunc(xl)));
}
float dotsat(float4 x)
{
	return dotsat(x.rgb);
}


float3 AdjustSaturation(float3 input, float requestedadjustment)
{
	float3 yuv = RGBtoYUV(input);
	float adjustment = 2.0 * (saturate(requestedadjustment) - 0.5);
	if (adjustment > 0.0)
	{
		float maxboost = rcp(max(abs(yuv.y), abs(yuv.z)) / 0.5);
		if (adjustment > maxboost) adjustment = maxboost;
	}
	yuv.y = yuv.y > 0.0 ? clamp(yuv.y + (adjustment * yuv.y), 0.0, 0.5) : clamp(yuv.y - (adjustment * abs(yuv.y)), -0.5, 0.0);
	yuv.z = yuv.z > 0.0 ? clamp(yuv.z + (adjustment * yuv.z), 0.0, 0.5) : clamp(yuv.z - (adjustment * abs(yuv.z)), -0.5, 0.0);
	return YUVtoRGB(yuv);
}


float3 AdjustVibrance(float3 pixel, float satadjust)
{
	float3 outdot = pixel;
	float refsat = dotsat(pixel);
	float realadjustment = saturate(refsat + satadjust) - refsat;
	float2 highlow = float2(max(max(pixel.r, pixel.g), pixel.b), min(min(pixel.r, pixel.g), pixel.b));
	float maxpositive = 1.0 - highlow.x;
	float maxnegative = -highlow.y;
	[branch] if (abs(realadjustment) > 0.0)
	{
		float mid = -1.0;
		float lowadjust = clamp(((highlow.y - highlow.x / 2.0) / highlow.x) * realadjustment, maxnegative, maxpositive);
		float highadjust = clamp(0.5 * realadjustment, maxnegative, maxpositive);
		if (pixel.r == highlow.x) outdot.r = pow(abs(1.0 + highadjust) * 2.0, log2(pixel.r));
		else if (pixel.r == highlow.y) outdot.r = pow(abs(1.0 + lowadjust) * 2.0, log2(pixel.r));
		else mid = pixel.r;
		if (pixel.g == highlow.x) outdot.g = pow(abs(1.0 + highadjust) * 2.0, log2(pixel.g));
		else if (pixel.g == highlow.y) outdot.g = pow(abs(1.0 + lowadjust) * 2.0, log2(pixel.g));
		else mid = pixel.g;
		if (pixel.b == highlow.x) outdot.b = pow(abs(1.0 + highadjust) * 2.0, log2(pixel.b));
		else if (pixel.b == highlow.y) outdot.b = pow(abs(1.0 + lowadjust) * 2.0, log2(pixel.b));
		else mid = pixel.b;
		if (mid > 0.0)
		{
			float midadjust = clamp(((mid - highlow.x / 2.0) / highlow.x) * realadjustment, maxnegative, maxpositive);
			if (pixel.r == mid) outdot.r = pow(abs(1.0 + midadjust) * 2.0, log2(pixel.r));
			else if (pixel.g == mid) outdot.g = pow(abs(1.0 + midadjust) * 2.0, log2(pixel.g));
			else if (pixel.b == mid) outdot.b = pow(abs(1.0 + midadjust) * 2.0, log2(pixel.b));
		}
	}
	
	return outdot;
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
	float3 pixel = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy).rgb;
	float3 outdot = pixel;
	if (BrightnessGainStrength > 0.0)
	{
		float presaturation = dotsat(outdot);
		float preluma = dot(outdot, float3(0.2126, 0.7152, 0.0722));
		float colorgain = 2.0 - log2(BrightnessGainStrength + 1.0);
		float channelfloor = rcp(intpow(2, BUFFER_COLOR_BIT_DEPTH));
		outdot = log2(clamp(outdot, channelfloor, 1.0 - channelfloor));
		outdot = pow(abs(colorgain), outdot);
		channelfloor = pow(abs(colorgain), log2(channelfloor));
		float contrastgain = log(rcp(dot(outdot, float3(0.2126, 0.7152, 0.0722)) - channelfloor)) * pow(2.718282, (1.0 + channelfloor) * 2.718282) * BrightnessGainStrength * BrightnessGainStrength;
		outdot = pow(abs(2.0 + contrastgain) * 5.0, log10(outdot));
		float lumadelta = dot(outdot, float3(0.2126, 0.7152, 0.0722)) - preluma;
		outdot = RGBtoYUV(outdot);
		outdot.x = saturate(outdot.x - lumadelta * channelfloor);
		outdot = YUVtoRGB(outdot);
		float newsat = dotsat(outdot);
		float satadjust = abs(((newsat - presaturation) / 2.0) * (1.0 + BrightnessGainStrength)); // compute difference in before/after saturation
		if (satadjust != 0.0) outdot = AdjustSaturation(outdot, 0.5 + satadjust);
	}
	if (VibranceStrength != 0.5)
	{
		outdot = AdjustVibrance(outdot, -(VibranceStrength - 0.5));
	}
	if (SaturationStrength != 0.5)
	{
		outdot = AdjustSaturation(outdot, SaturationStrength);
	}
	
	if (!any(outdot - pixel)) discard;
	else return outdot;
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
