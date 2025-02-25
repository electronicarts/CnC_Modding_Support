//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a glow by selective color blurring
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 ProjectionI : ProjectionInverse;

// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( DepthBufferSampler,
	string SasBindAddress = "PostEffect.DepthBufferTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
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
	return Out;
}

// ----------------------------------------------------------------------------
float4 DefaultPS(float2 TexCoord : TEXCOORD0) : COLOR
{
#if defined(EA_PLATFORM_XENON)
	float depth = 1.0f - tex2D( SAMPLER(DepthBufferSampler), TexCoord).x;
#else
	float depth = tex2D( SAMPLER(DepthBufferSampler), TexCoord).x;
#endif

	float4 clipPos = float4(TexCoord.x * 2 - 1, -TexCoord.y * 2 + 1, depth, 1);
	float4 viewPos = mul(clipPos, ProjectionI);
	viewPos.xyz /= viewPos.w;
	
	return float4( viewPos.zzz, 1.0f );
}

// ----------------------------------------------------------------------------
technique LinearDepth
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