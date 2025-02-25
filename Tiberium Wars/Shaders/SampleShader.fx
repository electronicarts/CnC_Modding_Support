//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// DEPRECATED SHADER
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
//#define PER_PIXEL_POINT_LIGHT
#include "Common.fxh"

//
//
// DEPRECATED SHADER
//
//
#if !defined ( _3DSMAX_ )
#include "Simple.fx"
#else


// Light sources
float4 AmbientLightColor : Ambient = float4(0.1, 0.1, 0.1, 0.0);

static const int NumDirectionalLights = 3;

SasDirectionalLight DirectionalLight[NumDirectionalLights]
<
	string SasBindAddress = "Sas.DirectionalLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_DIRECTIONAL_LIGHT_1,
	DEFAULT_DIRECTIONAL_LIGHT_2,
	DEFAULT_DIRECTIONAL_LIGHT_3
};

DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);


// Material parameters
float4 MaterialColorDiffuse
<
	string UIName = "Diffuse Material Color";
	string UIWidget = "Color";
> = float4(1.0, 0.5, 0.0, 1.0);

float InternationallyAcceptedDimmingFactor
<
	string UIName = "InternationallyAcceptedDimmingFactor";
	string UIWidget = "Slider";
> = 0.8;

float2 ShiftForDiffuseTextureCoords
<
	string UIName = "(xy)ShiftForDiffuseTextureCoords"; // Since 3DSMax displays float2 and float3 
		// vectors with four UI elements, the name should be used to indicate the number of used elements.

	string UIWidget = "Spinner";
> = float2(0.0f, 2.0f);

float3 VectorBetween1And2
<
	string UIName = "(xyz)VectorBetween1And2";
	string UIWidget = "Spinner";
	float UIMin = 1.0;
	float UIMax = 2.0;
	float UIStep = 0.1;
> = float3(1.5f, 1.0f, 1.0f);

// Textures
texture DiffuseTexture 
< 
	string UIName = "Diffuse Texture";
>;

sampler DiffuseSampler = sampler_state
{
    Texture   = (DiffuseTexture);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
	
texture LightTexture
<
	string UIName = "Lightmap Texture";
>;

sampler LightSampler = sampler_state
{
    Texture   = (LightTexture);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};


// Transformations
float4x4 WorldViewProjection : WorldViewProjection;
float4x4 World : World;

// Time (ie. material is animated)
float Time : Time;

struct VSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

VSOutput VS(float3 Position : POSITION, float3 Normal : NORMAL,
	float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1)
{
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	float3 N = normalize(mul(Normal, (float3x3)World));
	
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(N, DirectionalLight[i].Direction));
	}
	Out.Color = AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1);
	
	Out.Color *= InternationallyAcceptedDimmingFactor;
	
	Out.TexCoord0 = TexCoord0 + ShiftForDiffuseTextureCoords;
	Out.TexCoord1 = TexCoord0 + VectorBetween1And2.xy * sin(Time);
	
	return Out;
}

float4 PS(VSOutput In) : COLOR
{
	float4 diffuse = tex2D(DiffuseSampler, In.TexCoord0);
	float4 light = tex2D(LightSampler, In.TexCoord1);
	return In.Color * diffuse + light;
}

technique DefaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader  = compile ps_2_0 PS();
	}  
}

#endif //EA_PLATFORM_XENON