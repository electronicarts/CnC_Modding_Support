//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader helper for shadow map
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"


// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;

SAMPLER_2D_BEGIN( Sampler_PostProcess,
	string UIName = "None";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
// SHADER: WriteColor
// ----------------------------------------------------------------------------
float4 ColorToWrite = float4(0, 0, 0, 0);
float4 VSWriteColor(float3 Position : POSITION) : POSITION
{
	return float4(Position, 1);
}

// ----------------------------------------------------------------------------
float4 PSWriteColor(void) : COLOR
{
	return ColorToWrite;
}


// ----------------------------------------------------------------------------
// SHADER: VSShadowMapPostProcess
// ----------------------------------------------------------------------------
struct VSOutput_ShadowMapPostProcess
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_ShadowMapPostProcess VSShadowMapPostProcess(float3 Position : POSITION,
		float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_ShadowMapPostProcess Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord0 = TexCoord0;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PSShadowMapPostProcess(VSOutput_ShadowMapPostProcess In) : COLOR
{
	//return tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0).x;
	
	float4 Zero_Zero_OneOverMapSize_OneOverMapSize = float4(0, 0, 1, 1) / 1024;
	
	float surroundingCross = 
		max(
			max(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 + Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
				tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 - Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x),
			max(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 + Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
				tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 - Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x));

	return lerp(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0).x, surroundingCross, 0.5);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: WriteColor
// ----------------------------------------------------------------------------
technique _WriteColor
{
	pass P0
	{
		VertexShader = compile VS_VERSION_HIGH VSWriteColor();
		PixelShader = compile PS_VERSION_HIGH PSWriteColor();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _ShadowMapPostProcess
// ----------------------------------------------------------------------------
technique _ShadowMapPostProcess
{
	pass P0
	{
		VertexShader = compile VS_VERSION_HIGH VSShadowMapPostProcess();
		PixelShader = compile PS_VERSION_HIGH PSShadowMapPostProcess();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}
