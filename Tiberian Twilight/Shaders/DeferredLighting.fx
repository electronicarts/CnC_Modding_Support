
// ©2005 Electronic Arts Inc
//
// FX Shader for rendering deferred lights
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_CLOUDS 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "ShadowMap.fxh"
#include "DeferredLighting.fxh"

#if !defined(_3DSMAX_)

SAMPLER_2D_BEGIN( NormalSpecTexture,
	string SasBindAddress = "WW3D.DeferredLighting.NormalSpec";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( GoboTexture,
	string SasBindAddress = "WW3D.DeferredLighting.GoboTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_CUBE_BEGIN( GoboCubeTexture,
	string SasBindAddress = "WW3D.DeferredLighting.GoboTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END

SAMPLER_2D_BEGIN( CloudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.Texture";
	string ResourceName = "ShaderPreviewCloud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

bool IsShadowMapEnabled
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.ShadowMappingEnabled";
> = true;

float4 PointLightPosition
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.PointLightPosition";
> = float4(0.0f, 0.0f, 0.0f, 0.0f);	// position (xyz), innerRadius*innerRadius

float4 PointLightColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.PointLightColor";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // color (rgb), outerRadius*outerRadius

float4 SpotLightPosition
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.SpotLightPosition";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // position (xyz)

float4 SpotLightColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.SpotLightColor";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // color (rgb)

float4 SpotLightDirection
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.SpotLightDirection";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // normal (xyz)

float4 SpotLightParameters
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.SpotLightParameters";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // cos(innerAngle), cos(outerAngle), innerRadius*innerRadius, outerRadius*outerRadius

float4 CylindricalLightPosition
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.CylindricalLightPosition";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // position (xyz), innerRadius*innerRadius

float4 CylindricalLightDirection
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.CylindricalLightDirection";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // normal (xyz), outerRadius*outerRadius

float4 CylindricalLightColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.CylindricalLightColor";
> = float4(0.0f, 0.0f, 0.0f, 0.0f); // color (rgb), length

float4x4 GoboMatrix
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeferredLighting.GoboMatrix";
> = float4x4(1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);

// ----------------------------------------------------------------------------
// Transforms
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x4 WorldView : WorldView;
float Time : Time;

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

#else

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif

// ----------------------------------------------------------------------------

struct VSOutput
{
	float4 Position						: POSITION;
	
#if defined(EA_PLATFORM_PS3)
	// On PS3, to save memory, we use the depth buffer as is, so we need to do more math
	float4 WorldFarPosition				: TEXCOORD0;
	float4 WorldNearPosition			: TEXCOORD1;
#else // #if defined(EA_PLATFORM_PS3)
	// For PC and PS3, the depth texture already has the depth in world position, so we could get by using simple math
	//float3 PixelRay						: TEXCOORD0;
#endif // #if defined(EA_PLATFORM_PS3)
};

// ----------------------------------------------------------------------------

struct PSOutput
{
	float4 Diffuse	: COLOR0;
	float4 Specular : COLOR1;
};

// ----------------------------------------------------------------------------

struct SurfaceData
{
	float3 WorldPosition;
	float3 WorldNormal;
	float3 WorldEyeDir;
	float  SpecularPower;
};

// ----------------------------------------------------------------------------

SurfaceData ComputeSurfaceData( VSOutput In, float2 vPos )
{
	SurfaceData Out;
	
	// compute tex coord
	float2 texCoord = GetScreenTexcoordCoord(vPos);
	
	// sample the normal and depth
	float4 normalSpec = tex2D(SAMPLER(NormalSpecTexture), texCoord);
	Out.WorldPosition = ComputeWorldPosition(texCoord);
	Out.WorldNormal = normalize(normalSpec.xyz * 2.0f - 1.0f);
	Out.SpecularPower = normalSpec.w * 255.0f;
	
	// Compute view direction in world space
	Out.WorldEyeDir = normalize(GetEyePosition() - Out.WorldPosition);
	
	return Out;
}

// ----------------------------------------------------------------------------

void ComputeEyeRayVS(inout VSOutput In, float2 pos )
{
#if defined(EA_PLATFORM_PS3)
	// Calculate the transformation matrix from screen to world
	float4x4 projectionToWorld = mul(ProjectionI, ViewI);

	In.WorldNearPosition	= mul(float4(pos.xy, 0, 1), projectionToWorld);
	In.WorldFarPosition	= mul(float4(pos.xy, 1, 1), projectionToWorld);
#else // #if defined(EA_PLATFORM_PS3)
// 	// We need to convert the view space depth values from the depth texture to world space positions.
// 	// First build a ray "through" the pixel in question
// 	float4 screenFarPlanePosition = float4(pos.xy, 1, 1);
// 	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
// 	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
// 	
// 	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
// 	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
// 	float3 viewEyeDir = viewFarPlanePosition / viewFarPlanePosition.z;
// 
// 	In.PixelRay = mul(viewEyeDir, ViewI);
#endif // #if defined(EA_PLATFORM_PS3)
}

// ----------------------------------------------------------------------------
// Directional Shader
// ----------------------------------------------------------------------------
VSOutput VS_Directional(float3 Position : POSITION)
{
	VSOutput Out;

	Out.Position = float4(Position, 1);
	ComputeEyeRayVS(Out, Out.Position.xy);

	return Out;
}

// ----------------------------------------------------------------------------

PSOutput PS_Directional(VSOutput In, uniform bool shadowEnabled, float2 vPos : PIXELLOC) : COLOR
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
//	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_1);
//	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_2);

	// get the surface data	
	SurfaceData surface = ComputeSurfaceData( In, vPos );
	
	PSOutput Out;
	
	// compute the first directional light
	{
		float3 halfEyeLightVector = normalize(DirectionalLight_0_Direction.xyz + surface.WorldEyeDir);

		float4 lighting = lit(dot(surface.WorldNormal, DirectionalLight_0_Direction.xyz),
			dot(surface.WorldNormal, halfEyeLightVector), surface.SpecularPower);
			
		// sample the shadow map
		float shadowVal = 1.0f;
		if(shadowEnabled)
		{
	 		float4 shadowMapTexCoord = CalculateShadowMapTexCoord(surface.WorldPosition, SHADOWMAP_SAMPLE_SOFT);
	 		shadowVal = shadow( SAMPLER(ShadowMap), shadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_SOFT );
		}
 		
 		// sample the cloud texture
 		float2 CloudTexCoord = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, surface.WorldPosition, Time);
 		float3 cloud = GammaToLinear(tex2D( SAMPLER(CloudSampler), CloudTexCoord).xyz);
 		shadowVal *= cloud;
		
		Out.Diffuse = float4( DirectionalLight_0_Color.rgb * lighting.y * shadowVal, 0.0f );
		Out.Specular = float4( DirectionalLight_0_Color.rgb * lighting.z * shadowVal, 0.0f );
	}
	
	// compute the second directional light
	{
		float3 halfEyeLightVector = normalize(DirectionalLight_1_Direction.xyz + surface.WorldEyeDir);

		float4 lighting = lit(dot(surface.WorldNormal, DirectionalLight_1_Direction.xyz),
			dot(surface.WorldNormal, halfEyeLightVector), surface.SpecularPower);

		Out.Diffuse += float4( DirectionalLight_1_Color.rgb * lighting.y, 0.0f );
		Out.Specular += float4( DirectionalLight_1_Color.rgb * lighting.z, 0.0f );
	}
	
	// third directional light
	{
		float3 halfEyeLightVector = normalize(DirectionalLight_2_Direction.xyz + surface.WorldEyeDir);

		float4 lighting = lit(dot(surface.WorldNormal, DirectionalLight_2_Direction.xyz),
			dot(surface.WorldNormal, halfEyeLightVector), surface.SpecularPower);

		Out.Diffuse += float4( DirectionalLight_2_Color.rgb * lighting.y, 0.0f );
		Out.Specular += float4( DirectionalLight_2_Color.rgb * lighting.z, 0.0f );
	}
	
	return Out;
}

// ----------------------------------------------------------------------------
// Point Spot and Cylindrical Shaders
// ----------------------------------------------------------------------------

VSOutput VS(float3 Position : POSITION)
{
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	ComputeEyeRayVS(Out, Out.Position.xy / Out.Position.w);

	return Out;
}

// ----------------------------------------------------------------------------

PSOutput PS_PointLight(VSOutput In, float2 vPos : PIXELLOC) : COLOR
{
	// get the surface data	
	SurfaceData surface		= ComputeSurfaceData( In, vPos );

	// read the light values	
	float3	LightPos		= PointLightPosition.xyz;
	float3	LightColor		= PointLightColor.rgb;
	float	InnerRadiusSqr	= PointLightPosition.w;
	float	OuterRadiusSqr	= PointLightColor.a;
	
	// compute the attenuation
	float3	LightToPoint	= LightPos - surface.WorldPosition;
	float3	LightToPointNrm	= normalize(LightToPoint);
	float	DistanceSqr		= dot(LightToPoint, LightToPoint);
	float	Attenuation		= smoothstep(OuterRadiusSqr, InnerRadiusSqr, DistanceSqr);
	
	// compute the diffuse term
	float	DiffuseTerm		= saturate(dot(surface.WorldNormal, LightToPointNrm));

	// compute the specular term
	float3	H				= normalize(LightToPointNrm + surface.WorldEyeDir);
	float	SpecularTerm	= pow(saturate(dot(surface.WorldNormal, H)), surface.SpecularPower);

	// combine
	PSOutput Out;
	Out.Diffuse				= float4( LightColor * DiffuseTerm * Attenuation, 1.0f );
	Out.Specular			= float4( LightColor * SpecularTerm * Attenuation, 1.0f );
	
	return Out;
}

// ----------------------------------------------------------------------------

PSOutput PS_PointLightGobo(VSOutput In, float2 vPos : PIXELLOC) : COLOR
{
	// get the surface data	
	SurfaceData surface		= ComputeSurfaceData( In, vPos );

	// read the light values	
	float3	LightPos		= PointLightPosition.xyz;
	float3	LightConstColor	= PointLightColor.rgb;
	float	InnerRadiusSqr	= PointLightPosition.w;
	float	OuterRadiusSqr	= PointLightColor.a;
	
	// compute the attenuation
	float3	LightToPoint	= LightPos - surface.WorldPosition;
	float3	LightToPointNrm	= normalize(LightToPoint);
	float	DistanceSqr		= dot(LightToPoint, LightToPoint);
	float	Attenuation		= smoothstep(OuterRadiusSqr, InnerRadiusSqr, DistanceSqr);
	
	// compute the diffuse term
	float	DiffuseTerm		= saturate(dot(surface.WorldNormal, LightToPointNrm));

	// compute the specular term
	float3	H				= normalize(LightToPointNrm + surface.WorldEyeDir);
	float	SpecularTerm	= pow(saturate(dot(surface.WorldNormal, H)), surface.SpecularPower);
	
	// compute the gobo color
	float3	GoboColor		= texCUBE( SAMPLER(GoboCubeTexture), LightToPointNrm ).rgb;
	float3	LightColor		= LightConstColor * GoboColor;

	// combine
	PSOutput Out;
	Out.Diffuse				= float4( LightColor * DiffuseTerm * Attenuation, 1.0f );
	Out.Specular			= float4( LightColor * SpecularTerm * Attenuation, 1.0f );
	
	return Out;
}

// ----------------------------------------------------------------------------

PSOutput PS_SpotLight(VSOutput In, float2 vPos : PIXELLOC) : COLOR
{
	// get the surface data	
	SurfaceData surface			= ComputeSurfaceData( In, vPos );

	// read the light values	
	float3	LightPos			= SpotLightPosition.xyz;
	float3	LightColor			= SpotLightColor.rgb;
	float3	LightDir			= SpotLightDirection.xyz;
	float	CosInnerAngle		= SpotLightParameters.x;
	float	CosOuterAngle		= SpotLightParameters.y;
	float	InnerRadiusSqr		= SpotLightParameters.z;
	float	OuterRadiusSqr		= SpotLightParameters.w;
	
	// compute the distance attenuation
	float3	LightToPoint		= LightPos - surface.WorldPosition;
	float3	LightToPointNrm		= normalize(LightToPoint);
	float	DistanceSqr			= dot(LightToPoint, LightToPoint);
	float	DistAttenuation		= smoothstep(OuterRadiusSqr, InnerRadiusSqr, DistanceSqr);
	
	// compute the spot attenuation
	float	CosDirection		= dot(-LightToPointNrm, LightDir);
	float	AngleAttenuation	= smoothstep(CosOuterAngle, CosInnerAngle, CosDirection);
	float	Attenuation			= AngleAttenuation * DistAttenuation;
	
	// compute the diffuse term
	float	DiffuseTerm			= saturate(dot(surface.WorldNormal, LightToPointNrm));

	// compute the specular term
	float3	H					= normalize(LightToPointNrm + surface.WorldEyeDir);
	float	SpecularTerm		= pow(saturate(dot(surface.WorldNormal, H)), surface.SpecularPower);

	// combine
	PSOutput Out;
	Out.Diffuse					= float4( LightColor * DiffuseTerm * Attenuation, 1.0f );
	Out.Specular				= float4( LightColor * SpecularTerm * Attenuation, 1.0f );

	return Out;
}

// ----------------------------------------------------------------------------

PSOutput PS_SpotLightGobo(VSOutput In, float2 vPos : PIXELLOC) : COLOR
{
	// get the surface data	
	SurfaceData surface			= ComputeSurfaceData( In, vPos );

	// read the light values	
	float3	LightPos			= SpotLightPosition.xyz;
	float3	LightConstColor		= SpotLightColor.rgb;
	float3	LightDir			= SpotLightDirection.xyz;
	float	CosInnerAngle		= SpotLightParameters.x;
	float	CosOuterAngle		= SpotLightParameters.y;
	float	InnerRadiusSqr		= SpotLightParameters.z;
	float	OuterRadiusSqr		= SpotLightParameters.w;
	
	// compute the distance attenuation
	float3	LightToPoint		= LightPos - surface.WorldPosition;
	float3	LightToPointNrm		= normalize(LightToPoint);
	float	DistanceSqr			= dot(LightToPoint, LightToPoint);
	float	DistAttenuation		= smoothstep(OuterRadiusSqr, InnerRadiusSqr, DistanceSqr);
	
	// compute the spot attenuation
	float	CosDirection		= dot(-LightToPointNrm, LightDir);
	float	AngleAttenuation	= smoothstep(CosOuterAngle, CosInnerAngle, CosDirection);
	float	Attenuation			= AngleAttenuation * DistAttenuation;
	
	// compute the diffuse term
	float	DiffuseTerm			= saturate(dot(surface.WorldNormal, LightToPointNrm));

	// compute the specular term
	float3	H					= normalize(LightToPointNrm + surface.WorldEyeDir);
	float	SpecularTerm		= pow(saturate(dot(surface.WorldNormal, H)), surface.SpecularPower);
	
	// compute the light color using the gobo texture
	float4	GoboTexCoord		= mul(float4(surface.WorldPosition, 1.0f), GoboMatrix);
	float3	GoboColor			= tex2Dproj(SAMPLER(GoboTexture), GoboTexCoord).rgb;
	float3	LightColor			= LightConstColor * GoboColor;

	// combine
	PSOutput Out;
	Out.Diffuse					= float4( LightColor * DiffuseTerm * Attenuation, 1.0f );
	Out.Specular				= float4( LightColor * SpecularTerm * Attenuation, 1.0f );

	return Out;
}

// ----------------------------------------------------------------------------

float3 ClosestPointOnSegment(float3 p, float3 origin, float3 dir, float length)
{
    float3 pointToOrigin	= p-origin;
    float3 end				= origin + dir * length;
    float3 originToEnd		= end-origin;
    float t = dot(pointToOrigin,originToEnd)/dot(originToEnd,originToEnd);
    
    return origin + (saturate(t) * originToEnd);
}

// ----------------------------------------------------------------------------

PSOutput PS_CylindricalLight(VSOutput In, float2 vPos : PIXELLOC) : COLOR
{
	// get the surface data	
	SurfaceData surface			= ComputeSurfaceData( In, vPos );

	// read the light values	
	float3	LightPos			= CylindricalLightPosition.xyz;
	float3	LightColor			= CylindricalLightColor.rgb;
	float3	LightDir			= CylindricalLightDirection.xyz;
	float	LightLength			= CylindricalLightColor.a;
	float	InnerRadiusSqr		= CylindricalLightPosition.w;
	float	OuterRadiusSqr		= CylindricalLightDirection.w;
	
	// compute the point on the light souce the world pos position is
	// closest to, then just treat it as a point light
	float3	PointLightPos		= ClosestPointOnSegment( surface.WorldPosition, LightPos, LightDir, LightLength );
	
	// compute the attenuation
	float3	LightToPoint		= PointLightPos - surface.WorldPosition;
	float3	LightToPointNrm		= normalize(LightToPoint);
	float	DistanceSqr			= dot(LightToPoint, LightToPoint);
	float	Attenuation			= smoothstep(OuterRadiusSqr, InnerRadiusSqr, DistanceSqr);
	
	// compute the diffuse term
	float	DiffuseTerm			= saturate(dot(surface.WorldNormal, LightToPointNrm));

	// compute the specular term
	float3	H					= normalize(LightToPointNrm + surface.WorldEyeDir);
	float	SpecularTerm		= pow(saturate(dot(surface.WorldNormal, H)), surface.SpecularPower);

	// combine
	PSOutput Out;
	Out.Diffuse					= float4( LightColor * DiffuseTerm * Attenuation, 1.0f );
	Out.Specular				= float4( LightColor * SpecularTerm * Attenuation, 1.0f );
	
	return Out;
}

// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Directional_Multiplier_IsShadowMapEnabled = 1);

#define PS_Directional_IsShadowMapEnabled \
 	compile PS_3_0 PS_Directional(false), \
	compile PS_3_0 PS_Directional(true)

DEFINE_ARRAY_MULTIPLIER(PS_Directional_Multiplier_Final = PS_Directional_Multiplier_IsShadowMapEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Directional_Array[PS_Directional_Multiplier_Final] =
{
	PS_Directional_IsShadowMapEnabled
};
#endif

// ----------------------------------------------------------------------------

technique Directional
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Directional();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Directional_Array,
			IsShadowMapEnabled * PS_Directional_Multiplier_IsShadowMapEnabled,
			// Non-array alternative:
			compile PS_VERSION PS_Directional(true)
		);
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = false;
	}
}

technique PointLight
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS();
		PixelShader = compile PS_3_0 PS_PointLight();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}
}

technique PointLightGobo
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS();
		PixelShader = compile PS_3_0 PS_PointLightGobo();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}
}

technique SpotLight
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS();
		PixelShader = compile PS_3_0 PS_SpotLight();

		ZEnable = false;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}
}

technique SpotLightGobo
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS();
		PixelShader = compile PS_3_0 PS_SpotLightGobo();

		ZEnable = false;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}
}

technique CylindricalLight
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS();
		PixelShader = compile PS_3_0 PS_CylindricalLight();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}	
}

#else // #if !defined(_3DSMAX_)

// This is needed to get this to compile for 3DSMax

float4 VS_Dummy() : POSITION
{
	return 0;
}

float4 PS_Dummy() : COLOR
{
	return 0;
}

technique Dummy
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Dummy();
		PixelShader = compile PS_3_0 PS_Dummy();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}	
}

#endif // #if !defined(_3DSMAX_)
