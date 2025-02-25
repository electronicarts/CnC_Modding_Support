//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a color conversion through a lookup table
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonPostFX.fxh"
#include "Gamma.fxh"


SAMPLER_2D_BEGIN( FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_3D_BEGIN( LookupTexture,
	string SasBindAddress = "PostEffect.LookupTable.LookupTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_3D_END

SAMPLER_2D_BEGIN( FilmTonemappingLookupTexture,
	string SasBindAddress = "PostEffect.LookupTable.FilmTonemapping";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4 BlendFactor
<
	string SasBindAddress = "PostEffect.LookupTable.BlendFactor";
> = float4(1.0, 1.0, 1.0, 1.0);

float3 ExposureLevel
<
	string SasBindAddress = "PostEffect.LookupTable.ExposureLevel";
> = float3(1.0, 1.0, 1.0);

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput DefaultVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	return Out;
}

// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
float4 DefaultPS(float2 TexCoord : TEXCOORD0, uniform bool applyLUT, uniform bool applyGammaCorrection) 
#else // #if defined(EA_PLATFORM_PS3)
float4 DefaultPS(float2 TexCoord : TEXCOORD0, uniform bool applyLUT, uniform bool applyGammaCorrection) : COLOR
#endif // #if defined(EA_PLATFORM_PS3)
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	
	color.xyz = UncompressRenderTargetColor(color.xyz);
	
	color.xyz *= ExposureLevel;
	
#if defined(ENABLE_GAMMA_CONVERSION)
	if (applyGammaCorrection)
	{

	#define TONEMAPPER 2

	#if TONEMAPPER == 0
		color.xyz = LinearToGamma(color.xyz);
	#elif TONEMAPPER == 1
		color.xyz /= 1 + color.xyz;
	#elif TONEMAPPER == 2
		float3 white = 6.0;
		color.xyz *= white;
		color.xyz = color.xyz * (1 + color.xyz / (white * white)) / (1 + color.xyz);
	#else
		float3 ld = 0.002;
		float linReference = 0.18;
		float logReference = 444;
		float logGamma = 0.45;
		
		color.xyz = (log10(0.4 * color.xyz / linReference) / ld * logGamma + logReference) / 1023.0;
		//color.xyz = clamp(color.xyz, 0, 1);
		
		float FilmLutWidth = 256;
		float Padding = .5/FilmLutWidth;
		//color.xyz = lerp(Padding,1-Padding,color.xyz);

		//  apply response lookup and color grading for target display
		color.x = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.x, .5)).r;
		color.y = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.y, .5)).r;
		color.z = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.z, .5)).r;
	#endif  
	}
#endif
	
	if (applyLUT)
	{
#if defined (EA_PLATFORM_XENON)
		// TODO: LLatta 2008-09-13
		// This is a workaround for a Xenon pipeline bug.
		// This fix here is a less risky fix at this stage of the project.
		// At the earliest convenience fix the actual issue in CVolumeTexture::SaveImage
		// See the comment in code\AssetCompilers\0.0-dev\Modules\TextureCompiler\Source\xenon\VolumeTexture.cpp
		float4 tableColor = tex3D(SAMPLER(LookupTexture), color.xzy).xzyw;
#else
		float4 tableColor = tex3D(SAMPLER(LookupTexture), color.xyz);
#endif
		color = lerp(color, tableColor, BlendFactor.x);
	}

	return color;
}

#if defined(EA_PLATFORM_PS3)

float4 DefaultPS_Default(float2 TexCoord : TEXCOORD0) : COLOR
{
    return DefaultPS(TexCoord, true, true);
}

float4 DefaultPS_Default_M(float2 TexCoord : TEXCOORD0) : COLOR
{
    return DefaultPS(TexCoord, true, false);
}

float4 DefaultPS_ResolveOnly(float2 TexCoord : TEXCOORD0) : COLOR
{
    return DefaultPS(TexCoord, false, true);
}

float4 DefaultPS_ResolveOnly_M(float2 TexCoord : TEXCOORD0) : COLOR
{
    return DefaultPS(TexCoord, false, false);
}

#endif // #if defined(EA_PLATFORM_PS3)


// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
#if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS_Default();
#else // #if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS(true, true);
#endif // #if defined(EA_PLATFORM_PS3)

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
#if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS_Default_M();
#else // #if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS(true, false);
#endif // #if defined(EA_PLATFORM_PS3)

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique ResolveOnly
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
#if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS_ResolveOnly();
#else // #if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS(false, true);
#endif // #if defined(EA_PLATFORM_PS3)

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique ResolveOnly_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
#if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS_ResolveOnly_M();
#else // #if defined(EA_PLATFORM_PS3)
		PixelShader = compile PS_2_0 DefaultPS(false, false);
#endif // #if defined(EA_PLATFORM_PS3)

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}
