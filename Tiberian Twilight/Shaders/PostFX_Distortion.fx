//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a color conversion through a lookup table
//////////////////////////////////////////////////////////////////////////////

//#define DEBUG_DISTORTION_TEXTURE 1

#include "Common.fxh"
#include "CommonPostFX.fxh"


SAMPLER_2D_BEGIN( FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( DistortionOffsetSampler,
	string SasBindAddress = "PostEffect.Distortion.DistortionOffsetTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_2D_END


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
#if defined(DEBUG_DISTORTION_TEXTURE)
	float scale = 0.4;
	Out.Position = float4(Position * scale + float3(1 - scale, 1 - scale, 0), 1);
#endif
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 DefaultPS_H(float2 TexCoord : TEXCOORD0) : COLOR
{
#if defined(DEBUG_DISTORTION_TEXTURE)
	return tex2D( SAMPLER(DistortionOffsetSampler), TexCoord);
#endif
	float2 offset = tex2D( SAMPLER(DistortionOffsetSampler), TexCoord).xy * 2 - 1;
	// The neutral color (127, 127) comes out one step below 0. Correct for that.
	offset += 1.0 / 255.0;	
	static const float maxOffset = 0.08;

	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord + offset * maxOffset);

	color.xyz = UncompressRenderTargetColor(color.xyz);

	return color;
}

// ----------------------------------------------------------------------------
float4 DefaultPS_M(float2 TexCoord : TEXCOORD0) : COLOR
{
#if defined(DEBUG_DISTORTION_TEXTURE)
	return tex2D( SAMPLER(DistortionOffsetSampler), TexCoord);
#endif
	float2 offset = tex2D( SAMPLER(DistortionOffsetSampler), TexCoord).xy * 2 - 1;
	// The neutral color (127, 127) comes out one step below 0. Correct for that.
	offset += 1.0 / 255.0;	
	static const float maxOffset = 0.08;

	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord + offset * maxOffset);
	return color;
}

// ----------------------------------------------------------------------------
// Technique: Default (High and up)
// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 DefaultPS_H();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif
	}  
}

// ----------------------------------------------------------------------------
// Technique: Default (Medium)
// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 DefaultPS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif
	}  
}

// ----------------------------------------------------------------------------
// Technique: Default (Low)
// ----------------------------------------------------------------------------
technique Default_L
{
	// No passes. Indicates technique disabled.
}
