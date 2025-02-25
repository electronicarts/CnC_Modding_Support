//////////////////////////////////////////////////////////////////////////////
// ©2007 Electronic Arts Inc
//
// FX Shader for simple unlit Globe FX
//////////////////////////////////////////////////////////////////////////////
#include "Common.fxh"

#if defined(EA_PLATFORM_WINDOWS)
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
SAMPLER_2D_BEGIN( Texture_Diffuse,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( Texture_Scan,
	string UIName = "Scanning Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float4 ScanCoordTransform
<
	string UIName = "Scanning Coords Scale/Move";
    string UIWidget = "Spinner";
	float UIMin = -100;
	float UIMax = 100;
> = float4(1.0, 1.0, 0.0, 0.0);

#if defined(_3DSMAX_)

bool NumRecolorColors
<
	string UIName = "Preview House Color Enable";
	bool ExportValue = false;
> = false;

float3 RecolorColor
<
	string UIName = "Preview House Color";
	string UIWidget = "Color";
	bool ExportValue = false;
> = float3(.7, .05, .05);

#else

int NumRecolorColors
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.NumRecolorColors";
	bool ExportValue = false;
> = 0;

float3 RecolorColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.RecolorColor[0]";
	bool ExportValue = false;
> = float3(0, 0, 0);
#endif

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 World : World;
float4x3 ViewI : ViewInverse;
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 DiffuseTexCoord : TEXCOORD0;
	float2 ScanTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);
	Out.DiffuseTexCoord = TexCoord0.xy;
	Out.ScanTexCoord = TexCoord0.xy * ScanCoordTransform.xy + Time * ScanCoordTransform.zw;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = tex2D( SAMPLER(Texture_Diffuse), In.DiffuseTexCoord);
	//House color define
	color.xyz = lerp(color.xyz,	RecolorColor * 2, color.w);
	
	color *= tex2D( SAMPLER(Texture_Scan), In.ScanTexCoord);
	return color;
}

technique Default
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}
