//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a color conversion through a lookup table
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"


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
	string UIWidget = "None";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_3D_END

float BlendFactor = 1.0f;

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
float4 DefaultPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 frame = tex2D( SAMPLER(FrameBufferSampler), TexCoord);
	float4 tableColor = tex3D( SAMPLER(LookupTexture), frame.xyz);
	float4 color = lerp(frame, tableColor, BlendFactor);
	return color;
}

// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW DefaultVS();
		PixelShader = compile PS_VERSION_HIGH DefaultPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}  
}
