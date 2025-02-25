//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for Alien Shield
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
float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);


SAMPLER_2D_BEGIN( DiffuseTexture,
	string UIName = "Diffuse";
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

SAMPLER_2D_BEGIN( FalloffTexture,
	string UIName = "Falloff";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float FallOff <
    string UIWidget = "slider";
    float UIMin = -10.0;
    float UIMax = 10.0;
    float UIStep = 0.05;
	string UIName = "Edge Falloff";
> = 1.0;

bool UseRecolorColors
<
	string UIName = "Allow House Color";
> = false;

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

bool HouseColorPulse
<
	string UIName = "House Color Pulse Enable";
> = false;

bool FogEnable
<
	string UIName = "Fog Enable";
> = true;

WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x4 View : View;
float4x3 World : World;
float4x3 ViewI : ViewInverse;
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
	float2 BaseInvTexCoord : TEXCOORD1;	
	float2 FalloffTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------

VSOutput VS(float3 Position  : POSITION,
			float3 Normal    : NORMAL, 
			float2 TexCoord0 : TEXCOORD0)
{
	VSOutput Out;
	
	float3 VertexColor = lerp(RecolorColor, float3(1.0,1.0,1.0),.25);

	if (HouseColorPulse)
	{
		VertexColor *= (sin(Time * 2) + 1.2);
	}

	float3 worldNormal = normalize(mul(Normal, (float3x3)World));

	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);
	
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	Out.BaseInvTexCoord = (TexCoord0 * TexCoordTransform_0.xy - Time * TexCoordTransform_0.zw) * 2;
	Fog.IsEnabled = Fog.IsEnabled && FogEnable;
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	// Compute view direction in world space
	float3 viewNormal = mul(worldNormal, (float3x3)View);
	
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);

	Out.DiffuseColor = VertexColor * OpacityOverride; 

	float falloff = pow(1 - dot(worldNormal, worldEyeDir), FallOff);
	Out.FalloffTexCoord = float2( falloff, 0 );

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool fogEnable) : COLOR
{
	float4 color = float4(In.DiffuseColor, 1.0);

	float4 falloffColor = tex2D( SAMPLER(FalloffTexture), In.FalloffTexCoord);
	color *= falloffColor;

	color *= tex2D( SAMPLER(DiffuseTexture), In.BaseTexCoord);
	color *= tex2D( SAMPLER(DiffuseTexture), In.BaseInvTexCoord) * 4;
	
	if (fogEnable)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}

	return color;
}

technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_HIGH PS(true);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = NONE;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}  
}

#if ENABLE_LOD

technique _Default_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS(false);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = NONE;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}  
}

#endif // #if ENABLE_LOD

