
 // This shader is copyright (c) Derek Brush aka "lordbean" (derekbrush@gmail.com)

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

uniform float frameweight
<
	ui_type = "slider";
	ui_spacing = 6;
	ui_label = "Previous Frame Weight";
	ui_min = 0; ui_max = 0.75; ui_step = 0.001;
	ui_tooltip = "Amount of weight given to previous frame.\n"
				 "Determines the strength of the blur effect.";
> = 0.6;

uniform float effectstrength
<
	ui_type = "slider";
	ui_label = "Falloff Speed";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
	ui_tooltip = "Adjusts how quickly blurred areas\n"
				 "normalize. 0.0 normalizes in one\n"
				 "frame, 1.0 normalizes slowly.";
> = 0.4;

#define __BB ReShade::BackBuffer

/*****************************************************************************************************************************************/
/*********************************************************** UI SETUP END ****************************************************************/
/*****************************************************************************************************************************************/

/***************************************************************************************************************************************/
/*********************************************************** SHADER SETUP START ********************************************************/
/***************************************************************************************************************************************/

#include "ReShade.fxh"

texture oldBBstore
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
sampler oldBB {Texture = oldBBstore;};

texture orgBBstore
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
sampler orgBB {Texture = orgBBstore;};

/*****************************************************************************************************************************************/
/*********************************************************** SHADER SETUP END ************************************************************/
/*****************************************************************************************************************************************/

float4 BlendPreviousFrame(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	float4 current = tex2Dlod(__BB, texcoord.xyxy);
	float4 old = tex2Dlod(oldBB, texcoord.xyxy);
	float4 org = tex2Dlod(orgBB, texcoord.xyxy);
	float4 weighted = lerp(org, old, effectstrength);
	return lerp(current, weighted, frameweight);
}

float4 DumpBuffer(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	return tex2Dlod(__BB, texcoord.xyxy);
}

technique templateshader <
	ui_label = "Basic Motion Blur";
>
{
	pass saveoriginalbuffer
	{
		VertexShader = PostProcessVS;
		PixelShader = DumpBuffer;
		RenderTarget = orgBBstore;
		ClearRenderTargets = true;
	}
	pass motionblur
	{
		VertexShader = PostProcessVS;
		PixelShader = BlendPreviousFrame;
	}
	pass saveblurredbuffer
	{
		VertexShader = PostProcessVS;
		PixelShader = DumpBuffer;
		RenderTarget = oldBBstore;
		ClearRenderTargets = true;
	}
}
