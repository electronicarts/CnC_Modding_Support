//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple unlit rendering
//////////////////////////////////////////////////////////////////////////////
#define SUPPORT_FOG 1

#include "Common.fxh"

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };
#endif


// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);


SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Base Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
    string UIWidget = "Spinner";
	float UIMin = -100;
	float UIMax = 100;
> = float4(1.0, 1.0, 0.0, 0.0);

bool DepthWriteEnable
<
	string UIName = "Depth Write Enable";
> = true;

bool AlphaBlendingEnable
<
	string UIName = "Alpha Blend Enable";
> = false;

bool FogEnable
<
	string UIName = "Fog Enable";
> = true;


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
float4x3 ViewI                  : ViewInverse;

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float3 DiffuseColor : COLOR0;
	float Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);
	Out.DiffuseColor = ColorEmissive;
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	Out.Fog = FogEnable ? CalculateFog(Fog, worldPosition, GetEyePosition()) : 1;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = float4(In.DiffuseColor.xyz, 1.0);
	color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);
	color.xyz = lerp(Fog.Color.xyz, color.xyz, In.Fog);
	return color;
}

technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;
		AlphaTestEnable = false;
#if !defined(EA_PLATFORM_PS3)
		ZWriteEnable = ( DepthWriteEnable );
		AlphaBlendEnable = ( AlphaBlendingEnable );
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}
