/*                     256 Color Converter for ReShade
 *
 *   (Snaps sampled sRGB colors to values representing 8-bit 256 color mode)
 *
 *                             by lordbean
 *
 *                (c) 2022 Derek Brush aka lordbean
 *				         derekbrush@gmail.com
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
 
#include "ReShade.fxh"

float3 EightBitEmulationPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 original = tex2Dlod(ReShade::BackBuffer, texcoord.xyxy).rgb;
	float3 output;
	output.b = 0.333333 * round(original.b / 0.333333);
	output.rg = 0.142857 * round(original.rg / 0.142857);
	return output;
}

technique EightBitEmulation
{
	pass Emulate256Color
	{
		VertexShader = PostProcessVS;
		PixelShader = EightBitEmulationPS;
	}
}