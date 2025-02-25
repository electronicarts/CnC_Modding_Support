//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Image post processing effect performing a glow by selective color blurring
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonPostFX.fxh"
#include "Gamma.fxh"

SAMPLER_2D_BEGIN(FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(SourceTexture,
	string SasBindAddress = "PostEffect.Bloom.SourceTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float2 SourceTextureSize
<
	string SasBindAddress = "PostEffect.Bloom.SourceTextureSize";
> = float2(1024, 768);

float2 TargetTextureSize
<
	string SasBindAddress = "PostEffect.Bloom.TargetTextureSize";
> = float2(1024, 768);

float BloomIntensity
<
	string SasBindAddress = "PostEffect.Bloom.Intensity";
> = 0.5;

float3 ExposureLevel
<
	string SasBindAddress = "PostEffect.LookupTable.ExposureLevel";
> = float3(1.0, 1.0, 1.0);

// Note: The following variables aren't used in the shader, but declaring it "primes" the scope parameter used in the scrape script for it.
// Since Scrape's ResolveConstant function does not know the type/dimensions of a parameter, they need to be declared somewhere before the script is loaded
float2 TextureSizeHigh
<
	string SasBindAddress = "PostEffect.Bloom.TextureSizeHigh";
> = float2(0, 0);

float2 TextureSizeMedium
<
	string SasBindAddress = "PostEffect.Bloom.TextureSizeMedium";
> = float2(0, 0);

float2 TextureSizeLow
<
	string SasBindAddress = "PostEffect.Bloom.TextureSizeLow";
> = float2(0, 0);

int SurfaceFormat
<
	string SasBindAddress = "PostEffect.Bloom.SurfaceFormat";
> = 1; // SURFACE_FORMAT_A8R8G8B8

int TextureFormat
<
	string SasBindAddress = "PostEffect.Bloom.TextureFormat";
> = 1; // SURFACE_FORMAT_A8R8G8B8

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput DefaultVS(float2 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 0, 1);
	Out.TexCoord = TexCoord;
	return Out;
}

// ----------------------------------------------------------------------------
float4 DefaultPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord);
	color.xyz = UncompressRenderTargetColor(color.xyz);
	return color;
}

// ----------------------------------------------------------------------------
float4 DoBoxFilter(float2 texCoord, int halfKernelSize)
{
	float4 color = 0;
	const int kernelSize = halfKernelSize * 2;
	for (int j = -(halfKernelSize - 1); j <= halfKernelSize - 1; j += 2)
	{
		for (int i = -(halfKernelSize - 1); i <= halfKernelSize - 1; i += 2)
		{
			color += tex2D(SAMPLER(SourceTexture), texCoord + float2(i, j) / SourceTextureSize);
		}
	}
	color /= pow(halfKernelSize, 2);
	return color;
}

// ----------------------------------------------------------------------------
float ApplyBloomCurve(float intensity)
{
#define SQUARED_BLOOM_CURVE

#if defined(SQUARED_BLOOM_CURVE)
	const float threshold = .11;
	
//	return intensity * intensity;	
	
	if (intensity > threshold)
		return (intensity-threshold) * (intensity - threshold);
	else
		return 0;
#else
	const float threshold = .66;
	const float steepness0 = 1.0 / 8.0;
	const float steepness1 = 2.75;

	if (intensity < threshold)
		return intensity * steepness0;
	else
		return intensity * steepness1 + threshold * (steepness0 - steepness1);
#endif
}

// ----------------------------------------------------------------------------
float4 Downsample4x4PS(VSOutput In) : COLOR
{
	// Why does this say 4x4, when it only does 2x2?
	// Because it samples with bilinear filtering at the in-between points of 4 2x2 pixel areas
	float4 color = DoBoxFilter(In.TexCoord, 2);
	return color;
}

// ----------------------------------------------------------------------------
float4 DownsampleInitialPS(VSOutput In, uniform int halfKernelSize) : COLOR
{
	// We want to do downsampling like the 4x4 downsampler above,
	// just on the PC we have varying screen resolutions to deal with, so the kernel size adapts to this.
	float4 color = DoBoxFilter(In.TexCoord, halfKernelSize);

	color.xyz = UncompressRenderTargetColor(color.xyz);

	float intensity = dot(color.xyz, float3(0.3f, 0.3f, 0.3f));
	float bloomedIntensity = ApplyBloomCurve(intensity);
	color.xyz *= bloomedIntensity / (intensity + 0.0001); // Avoid division by 0, caused issue esp on Geforce7800 cards

	color.xyz *= ExposureLevel; // HDR exposure doesn't get applied until the end in the lookup table post effect,
								// but we want it to affect the bloom as well, because the bloom is basically
								// happening inside the "film camera" depending on the amount of light coming in.

	return color;
}

// ----------------------------------------------------------------------------
float4 BlurGaussian11x11PS(VSOutput In, uniform float2 direction) : COLOR
{
#define OPTIMIZE_SAMPLES
#if defined(OPTIMIZE_SAMPLES)
	// Wow, there are lots of magic numbers in the following lines. How do you compute those?
	// This is a good question.
	// The short answer is, that they are directly taken from the presentation "HDR The Bungie Way".
	// The are supposed to approximate an 11 tap Gaussian distribution
	// by just sampling 5 (bi-)linearly interpolated taps.
	// This works by sampling at varying in-between points between the pixels 
	// so that eg at the 90% mark, the contribution will be 90% from one pixel and 10% from its neighbor.
	// The combined weight of this pixel pair is then scaled with the ratio that this pair
	// contributes to the whole distribution.
	In.TexCoord += (0.5 - direction) / SourceTextureSize;
	float4 color = 0;
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord - (4.0 - 9.0 / (9.0 + 1.0) * 0.5) * direction / SourceTextureSize) * (1 + 9);
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord - (2.0 - 84.0 / (84.0 + 36.0) * 0.5) * direction / SourceTextureSize) * (36 + 84);
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord + 0 * direction / SourceTextureSize) * (126 + 126);
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord + (2.0 - 84.0 / (84.0 + 36.0) * 0.5) * direction / SourceTextureSize) * (36 + 84);
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord + (4.0 - 9.0 / (9.0 + 1.0) * 0.5) * direction / SourceTextureSize) * (1 + 9);
	return color / float(1 + 9 + 36 + 84 + 126) / 2.0;
#else
	// The following is doing the original 11 tap Gaussian sampling.
	// Useful as a reference, if we need to derive other filter kernels in the future.
	In.TexCoord.y += 0.5 / SourceTextureSize.y;
	float4 color = 0;
	float samples[5] = { 210, 120, 45, 10, 1 };
	float weight = 252;
	color += tex2D(SAMPLER(SourceTexture), In.TexCoord + 0 * direction / SourceTextureSize) * 252;
	for (int i = 0; i < 5; i++)
	{
		color += tex2D(SAMPLER(SourceTexture), In.TexCoord + (i + 1) * direction / SourceTextureSize) * samples[i];
		color += tex2D(SAMPLER(SourceTexture), In.TexCoord - (i + 1) * direction / SourceTextureSize) * samples[i];
		weight += 2 * samples[i];
	}
	return color / weight;
#endif
}

// ----------------------------------------------------------------------------
float4 AccumulatePS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	float4 bloomColor = tex2D(SAMPLER(SourceTexture), TexCoord);

	color += bloomColor;

	return color;
}

// ----------------------------------------------------------------------------
float4 AccumulatePS_M(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	color.xyz = GammaToLinear(color.xyz);

	float4 bloomColor = tex2D(SAMPLER(SourceTexture), TexCoord);
	bloomColor.xyz = GammaToLinear(bloomColor.xyz);

	color += bloomColor;

	color.xyz = LinearToGamma(color.xyz);

	return color;
}

// ----------------------------------------------------------------------------
float4 AccumulateFinalPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	color.xyz = UncompressRenderTargetColor(color.xyz);

	float4 bloomColor = tex2D(SAMPLER(SourceTexture), TexCoord);

	color += bloomColor * BloomIntensity;

	return color;
}

// ----------------------------------------------------------------------------
float4 AccumulateFinalPS_M(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	color.xyz = UncompressRenderTargetColor(color.xyz);
	color.xyz = GammaToLinear(color.xyz);

	float4 bloomColor = tex2D(SAMPLER(SourceTexture), TexCoord);
	bloomColor.xyz = GammaToLinear(bloomColor.xyz);

	color += bloomColor * BloomIntensity;

	color.xyz = LinearToGamma(color.xyz);
	return color;
}
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER(DownsampleInitialPS_Multiplier_HalfKernelSize = 1);

#define DownsampleInitialPS_HalfKernelSize \
	compile PS_3_0 DownsampleInitialPS(1), \
	compile PS_3_0 DownsampleInitialPS(2), \
	compile PS_3_0 DownsampleInitialPS(3), \
	compile PS_3_0 DownsampleInitialPS(4), \
	compile PS_3_0 DownsampleInitialPS(5)

DEFINE_ARRAY_MULTIPLIER(DownsampleInitialPS_Multiplier_Final = DownsampleInitialPS_Multiplier_HalfKernelSize * 5);

#if SUPPORTS_SHADER_ARRAYS
pixelshader DownsampleInitialPS_Array[DownsampleInitialPS_Multiplier_Final] = { DownsampleInitialPS_HalfKernelSize };
#endif

technique DownsampleInitial
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		
		PixelShader = ARRAY_EXPRESSION_PS(DownsampleInitialPS_Array,
			// Following is the magic formula to determine how big the filter kernel needs to be based on the screen resolution of the user:
			// The idea is to not ignore any pixels when downsampling, as this leads to flickering of thin lines.
			// eg when going from 1024->256 you want 4x4 kernels, for 1920->256 8x8 is neccessary, max supported right now would be 2560->256 ie a 10x10 kernel
			// The formula computes the array index, which is 1 less than the halfKernelSize (since 0 does not make sense)
			clamp((int)(SourceTextureSize.x / TargetTextureSize.x / 2 - 0.5), 0, 4) * DownsampleInitialPS_Multiplier_HalfKernelSize,
			// Non-array alternative:
			// Xenon always has a fixed screen size, so the downsample ratio can be hardcoded here to be 4x4 (= half kernel size 2)
			compile PS_3_0 DownsampleInitialPS(2)
		);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
// PS2.0 fallback version (marked Low LOD, even though bloom is off by default on Low)
// It does the same as the PS3.0 functions, but those are running out of pixel shader registers
// when the kernel size reaches 10x10. So for PS2.0, we limit the kernel size to 8x8.
// In the very unlikely case that someone runs this shader on a PS2.0-only card,
// with a 2560x1600 monitor the bloom will be not as smooth as it ought to be...
DEFINE_ARRAY_MULTIPLIER(DownsampleInitialPS_L_Multiplier_HalfKernelSize = 1);

#define DownsampleInitialPS_L_HalfKernelSize \
	compile PS_2_0 DownsampleInitialPS(1), \
	compile PS_2_0 DownsampleInitialPS(2), \
	compile PS_2_0 DownsampleInitialPS(3), \
	compile PS_2_0 DownsampleInitialPS(4)

DEFINE_ARRAY_MULTIPLIER(DownsampleInitialPS_L_Multiplier_Final = DownsampleInitialPS_L_Multiplier_HalfKernelSize * 4);

#if SUPPORTS_SHADER_ARRAYS
pixelshader DownsampleInitialPS_L_Array[DownsampleInitialPS_L_Multiplier_Final] = { DownsampleInitialPS_L_HalfKernelSize };
#endif

technique DownsampleInitial_L
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		
		PixelShader = ARRAY_EXPRESSION_PS(DownsampleInitialPS_L_Array,
			// Following is the magic formula to determine how big the filter kernel needs to be based on the screen resolution of the user:
			// The idea is to not ignore any pixels when downsampling, as this leads to flickering of thin lines.
			// eg when going from 1024->256 you want 4x4 kernels, for 1920->256 8x8 is neccessary, max supported right now would be 2560->256 ie a 10x10 kernel
			// The formula computes the array index, which is 1 less than the halfKernelSize (since 0 does not make sense)
			clamp((int)(SourceTextureSize.x / TargetTextureSize.x / 2 - 0.5), 0, 3) * DownsampleInitialPS_L_Multiplier_HalfKernelSize,
			// Non-array alternative:
			// Xenon always has a fixed screen size, so the downsample ratio can be hardcoded here to be 4x4 (= half kernel size 2)
			compile PS_2_0 DownsampleInitialPS(2)
		);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique Downsample4x4
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 Downsample4x4PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}
// ----------------------------------------------------------------------------
technique BlurGaussian11x11U
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 BlurGaussian11x11PS(float2(1, 0));

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique BlurGaussian11x11V
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 BlurGaussian11x11PS(float2(0, 1));

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique Accumulate
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 AccumulatePS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique Accumulate_M
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 AccumulatePS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique AccumulateFinal
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 AccumulateFinalPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
technique AccumulateFinal_M
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 AccumulateFinalPS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}
technique Copy
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 DefaultPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
// Debug display

SAMPLER_2D_BEGIN(DebugTextureSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
VSOutput DebugDisplayVS(float2 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position * float2(0.5, 1) + float2(-0.5, 0), 0, 1);
	Out.TexCoord = TexCoord * float2(0.5, 1);
	return Out;
}

// ----------------------------------------------------------------------------
float4 DebugDisplayPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D(SAMPLER(DebugTextureSampler), TexCoord);
	// Tip: To debug for NAN values, use the following: 
	//color = abs(color) + 10;
	return color;
}

technique DebugDisplay
{
	pass p0
	{
		VertexShader = compile VS_2_0 DebugDisplayVS();
		PixelShader = compile PS_2_0 DebugDisplayPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
// Debug pattern

VSOutput DebugPatternVS(float2 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position * float2(1, 0.25) + float2(0, 0.75), 0, 1);
	Out.TexCoord = TexCoord * float2(1, 0.25);
	return Out;
}

// ----------------------------------------------------------------------------
float4 DebugPatternPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	// Write out a color ramp from black to white
	return GammaToLinear(TexCoord.x).xxxx;

	// This formula generates a pattern where every n-th pixel is white or black.
	// Useful for testing filter kernels for doing the expected behavior.
	float4 color = frac((TexCoord.x * SourceTextureSize.x + 0.5) / 2) + frac((TexCoord.y * SourceTextureSize.y + 0.5) / 2) > .75;
	return color;
}

technique DebugPattern
{
	pass p0
	{
		VertexShader = compile VS_2_0 DebugPatternVS();
		PixelShader = compile PS_2_0 DebugPatternPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}
