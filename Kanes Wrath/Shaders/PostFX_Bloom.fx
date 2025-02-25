//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a glow by selective color blurring
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

SAMPLER_2D_BEGIN( FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float3 HighlightFilterThreshold = float3(0.5, 0.5, 0.5);
float BloomIntensity = 1.3;
static const int BLUR_TAPS_PER_PASS = 4;

float BlurTaps_TexCoordOffsets[BLUR_TAPS_PER_PASS]
<
	string SasBindAddress = "PostEffect.Bloom.BlurTaps_TexCoordOffsets";
	int WW3DDynamicSet = DS_CUSTOM_FIRST + 1;
> = { 0, 0, 0, 0 };

float BlurTaps_Coefficients[BLUR_TAPS_PER_PASS]
<
	string SasBindAddress = "PostEffect.Bloom.BlurTaps_Coefficients";
	int WW3DDynamicSet = DS_CUSTOM_FIRST + 1;
> = { 0, 0, 0, 0 };

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
	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord);
	return color;
}

// ----------------------------------------------------------------------------
float4 HighlightFilterPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord);
	color.xyz += HighlightFilterThreshold - float3(1, 1, 1);
	color.xyz *= 2;
	return color;
}

// ----------------------------------------------------------------------------
struct VSOutput_Blur
{
	float4 Position : POSITION;
	float2 TexCoord[BLUR_TAPS_PER_PASS] : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_Blur BlurVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0, uniform bool swapDirection)
{
	VSOutput_Blur Out;	
	Out.Position = float4(Position, 1);
	for (int i = 0; i < BLUR_TAPS_PER_PASS; i++)
	{
/*		if (swapDirection)
		{
			Out.TexCoord[i] = TexCoord + float2(0, BlurTaps_TexCoordOffsets[i]);
		}
		else
		{
*/			Out.TexCoord[i] = TexCoord + float2(BlurTaps_TexCoordOffsets[i]*3, 0);
//		}
	}
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 BlurPS(VSOutput_Blur In) : COLOR
{
//return float4(0.5, 0, 0, 0);
	float4 color = 0;
	for (int i = 0; i < BLUR_TAPS_PER_PASS; i++)
	{
		color.xyz += tex2D( SAMPLER(FrameBufferSampler), In.TexCoord[i]) * BlurTaps_Coefficients[i];
	}
	color.xyz *= BloomIntensity;
	return color;
}

// ----------------------------------------------------------------------------
technique Default
{
	pass HighlightFilter
	{
		VertexShader = compile VS_VERSION_HIGH DefaultVS();
		PixelShader = compile PS_VERSION_HIGH HighlightFilterPS();

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

	pass BlurU_FirstPass
	{
		VertexShader = compile VS_VERSION_LOW BlurVS(false);
		PixelShader = compile PS_VERSION_HIGH BlurPS();

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

	pass BlurU_LaterPass
	{
		VertexShader = compile VS_VERSION_LOW BlurVS(false);
		PixelShader = compile PS_VERSION_HIGH BlurPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		//ColorWriteEnable = 0;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = InvSrcColor;		
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}

	pass BlurV_FirstPass
	{
		VertexShader = compile VS_VERSION_LOW BlurVS(true);
		PixelShader = compile PS_VERSION_HIGH BlurPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		//ColorWriteEnable = 15;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}

	pass BlurV_LaterPass
	{
		VertexShader = compile VS_VERSION_LOW BlurVS(true);
		PixelShader = compile PS_VERSION_HIGH BlurPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		//ColorWriteEnable = 0;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = InvSrcColor;
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}

	pass FinalOverlay
	{
		VertexShader = compile VS_VERSION_LOW DefaultVS();
		PixelShader = compile PS_VERSION_LOW DefaultPS();
		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		//ColorWriteEnable = 15;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = InvSrcColor;
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}
