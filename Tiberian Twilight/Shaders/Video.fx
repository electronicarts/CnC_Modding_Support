//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for video decoding
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// ----------------------------------------------------------------------------
// Textures declaration
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN(FrameY,
	string SasBindAddress = "Video.FrameY";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(FrameU,
	string SasBindAddress = "Video.FrameU";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(FrameV,
	string SasBindAddress = "Video.FrameV";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(FrameA,
	string SasBindAddress = "Video.FrameA";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

static const float3   ColorBias = {-0.062745, -0.50196, -0.50196};

static const float3x3 ColorTransform = { 1.1641444,  1.1641444,  1.1641444, 
                                         -0.0017889, -0.3914428,  2.0178255, 
                                         1.5957862, -0.8134821, -0.0012458};

// ---------------------------------------------------------------------------

struct VSOutput
{
	float4 Position   : POSITION;
	float2 TexCoords  : TEXCOORD0;
	float4 Color      : COLOR0;
};

// ---------------------------------------------------------------------------
VSOutput VS(float4 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	
	Out.Position = float4((Position.xy * 2 - 1) * float2(1, -1), 0, 1);
	Out.Color = color;
	Out.TexCoords = TexCoord0;
	
	return Out;
}

// ---------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float3 color;
	color.r = tex2D(SAMPLER(FrameY), In.TexCoords).r;
	color.g = tex2D(SAMPLER(FrameU), In.TexCoords).r;
	color.b = tex2D(SAMPLER(FrameV), In.TexCoords).r;

	color += ColorBias;
	
	float4 res;
	res.rgb = color;
	res.rgb = mul(color, ColorTransform);
	res.a = tex2D(SAMPLER(FrameA), In.TexCoords).r;

	// 2009/05/01 (wkan) - temp hack to get talking head alpha be 0, basically strech alpha from range 0-1 to -0.1 to 1.1
	//								this is better than blindly do -0.1 because it ensure the full screen movie still have alpha of 1
	res.a = saturate( 1.2*(res.a - 0.5)+0.5 );
	
	return res * In.Color;
}

// ---------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		CullMode = None;
		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
	
#if defined(EA_PLATFORM_PS3)	
		AlphaBlendEnable = false;
#else
		AlphaBlendEnable = true;
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
        
	}
}
