//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for decal rendering
//////////////////////////////////////////////////////////////////////////////
#include "Common.fxh"

#if defined(EA_PLATFORM_PS3)
// This value is calculated from (-0.0001) / (1/16777216)
#define DECAL_Z_BIAS -1677.7216
#elif !HIZ_CULLING
#define DECAL_Z_BIAS -0.0001
#else
#define DECAL_Z_BIAS 0.0001
#endif

SAMPLER_2D_BEGIN( BaseSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.BaseTexture";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( MaskSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.MaskTexture";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x3 ViewI          : ViewInverse;

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = color;
	Out.BaseTexCoord = TexCoord0;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
	color *= tex2D( SAMPLER(BaseSampler), In.BaseTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
float4 MaskPS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
	color *= tex2D( SAMPLER(MaskSampler), In.BaseTexCoord);

	return color;
}

// ----------------------------------------------------------------------------
technique Alpha
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;

		DepthBias = DECAL_Z_BIAS;
	}  
}

// ----------------------------------------------------------------------------
technique Add
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		AlphaTestEnable = false;

		DepthBias = DECAL_Z_BIAS;
	}  
}

// ----------------------------------------------------------------------------
technique Multiply
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		AlphaBlendEnable = true;
		SrcBlend = Zero;
		DestBlend = SrcColor;
		AlphaTestEnable = false;

		DepthBias = DECAL_Z_BIAS;
	}  
}

// ----------------------------------------------------------------------------
technique MergeStencilPass
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 MaskPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		ColorWriteEnable = 0;
		AlphaBlendEnable = true;
		SrcBlend = Zero;
		DestBlend = One;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60;
		StencilFunc = Always;
		StencilPass = Replace;
		StencilEnable = true;
		StencilRef = 0xff;
		StencilMask = 0x4;
		StencilWriteMask = 0x4;
		StencilZFail = Keep;
		StencilFail = Keep;

		DepthBias = DECAL_Z_BIAS;
	}  
}

technique MergeCombinePass
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;	//One;
		DestBlend = InvSrcAlpha;
		ColorWriteEnable = RGBA;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60;
		StencilFunc = NotEqual;
		StencilPass = Keep;
		StencilEnable = true;
		StencilRef = 0xff;
		StencilMask = 0x4;
		StencilWriteMask = 0x4;
		StencilZFail = Keep;
		StencilFail = Keep;

		DepthBias = DECAL_Z_BIAS;
	}  
}
