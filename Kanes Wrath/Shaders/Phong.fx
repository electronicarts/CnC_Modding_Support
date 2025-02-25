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
float4 AmbientLightColor : Ambient = float4(0.3, 0.3, 0.3, 0.0);

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

static const int NumPointLights = 1;

SasPointLight PointLight[NumPointLights]
<
	string SasBindAddress = "Sas.PointLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_POINT_LIGHT_DISABLED
};

// Material parameters
float4 MaterialColorDiffuse <
	string UIName = "Diffuse Material Color";
    string UIWidget = "Color";
> = float4(1.0, 0.5, 0.0, 1.0);


// Transformations
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 World : World;

struct VSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
};

VSOutput VS(float3 Position : POSITION, float3 Normal : NORMAL)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	
	float3 diffuseLight = 0;
	
	// Compute directional lights
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	// Compute point lights
	float3 worldPosition = mul(float4(Position, 1), World);
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
	
	Out.Color = AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1);
	
	return Out;
}

float4 PS(VSOutput In) : COLOR
{
	return In.Color;
}

technique DefaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader  = compile ps_1_1 PS();
	}  
}


#endif //EA_PLATFORM_XENON