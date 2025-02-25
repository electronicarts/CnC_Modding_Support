//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for vehicles and structures. Infantry should use Infantry.fx
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_RECOLORING 1 // Defined only in faction specific versions
//#define SCROLL_HOUSECOLOR 1 // Define for NOD scroll effect
//#define SUPPORT_SPECMAP 1 // Define for objects shader with specularity/envmap/self illumination map
//#define OBJECTS_ALIEN 1 // Define for alien shader variation
//#define SUPPORT_IONHULL 1 // Define for alien shader with ion hull texture
//#define SPECIFY_CUSTOM_ENVMAP 1 // Define to allow environment cube map to be specified in art tool instead of taken from code binding

#define USE_INTERACTIVE_LIGHTS 1
//#define PER_PIXEL_POINT_LIGHT
//#define SUPPORT_POINT_LIGHTS
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
// Skinning
// ----------------------------------------------------------------------------
static const int MaxSkinningBonesPerVertex = 1;

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
static const int NumDirectionalLights = 3;
static const int NumDirectionalLightsPerPixel = 2;
static const int NumPointLights = 1;
float3 AmbientLightColor : Ambient = float3(0.1, 0.1, 0.1);

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

#if defined(SUPPORT_POINT_LIGHTS)
int NumPointLightsUsed
<
	string SasBindAddress = "Sas.NumPointLights";
	string UIWidget = "None";
> = 0;

SasPointLight PointLight[NumPointLights]
<
	string SasBindAddress = "Sas.PointLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_POINT_LIGHT_DISABLED
};
#endif

// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
int NumShadows
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.NumShadows";
> = 0;

ShadowSetup ShadowInfo
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0]";
>;

SAMPLER_2D_SHADOW( ShadowMap )

// ----------------------------------------------------------------------------
// Cloud layer
// ----------------------------------------------------------------------------
CloudSetup Cloud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud";
> = DEFAULT_CLOUD;


SAMPLER_2D_BEGIN( CloudTexture,
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

float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);

// ----------------------------------------------------------------------------
// Environment map
// ----------------------------------------------------------------------------
#if OBJECTS_ALIEN
SAMPLER_2D_BEGIN( EnvironmentTexture,
	string UIName = "Reflection Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#elif defined(SPECIFY_CUSTOM_ENVMAP)
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string UIName = "Reflection Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END
#else
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.EnvironmentTexture";
	string ResourceType = "Cube";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END
#endif

// ----------------------------------------------------------------------------
// Editable parameters
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( DiffuseTexture,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalMap,
	string UIName = "Normal Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#if defined(SUPPORT_BUILDUP)
SAMPLER_2D_BEGIN( BuildUpMap,
	string UIName = "Build-Up Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif

#if defined(SUPPORT_SPECMAP)
SAMPLER_2D_BEGIN( SpecMap,
	string UIName = "Specular Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif

#if defined(SCROLL_HOUSECOLOR)

SAMPLER_2D_BEGIN( ScrollingMaskTexture,
	string UIName = "NOD Scrolling Mask";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

float4 TexCoordTransform_0
<
	string UIName = "NOD Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

//float RecolorMultiplier
static const float RecolorMultiplier
<
	string UIName = "NOD Effect Multiplier"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 10.0;
    float UIStep = 0.1;
> = 3.0;
#endif // defined(SCROLL_HOUSECOLOR)


// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------
#if defined(SUPPORT_RECOLORING) && !defined(SCROLL_HOUSECOLOR)

SAMPLER_2D_BEGIN( RecolorTexture,
	string UIName = "House Color Tex.";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END
	
#endif // if defined(SUPPORT_RECOLORING) && !defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_RECOLORING)


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


#else // defined(SUPPORT_RECOLORING)

static const int NumRecolorColors = 0;
static const float3 RecolorColor = float3(0, 0, 0);

#endif // defined(SUPPORT_RECOLORING)


#if defined(OBJECTS_ALIEN)
// Fixed material parameters for Aliens
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(1.0, 1.0, 1.0);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.788, 0.761, 1.0);
static const float SpecularExponent = 15.0;

#elif defined(MATERIAL_PARAMS_GDI)
// Fixed material parameters for GDI
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(0.996, 0.98, 0.906, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;

#elif defined(MATERIAL_PARAMS_NOD)
// Fixed material parameters for NOD
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(0.584, 0.624, 0.733, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;

#else
// Material parameters defined by UI
float BumpScale
<
	string UIName = "Bump Height"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 10.0;
    float UIStep = 0.1;
> = 1.0;

float3 AmbientColor
<
	string UIName = "Ambient Color"; 
    string UIWidget = "Color";
> = float3(0.4, 0.4, 0.4);

float4 DiffuseColor
<
	string UIName = "Diffuse Color"; 
    string UIWidget = "Color";
> = float4(1.0, 1.0, 1.0, 1.0);

float3 SpecularColor
<
	string UIName = "Specular Color"; 
    string UIWidget = "Color";
> = float3(0.8, 0.8, 0.8);

float SpecularExponent
<
	string UIName = "Specular Exponent"; 
    string UIWidget = "Slider";
	float UIMax = 200.0f;
	float UIMin = 0;
	float UIStep = 1.0f;
> = 50.0;

#endif // Material parameters defined by UI

#if defined(SUPPORT_SPECMAP)

float EnvMult
<
	string UIName = "Reflection Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;
#endif

bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;

// ----------------------------------------------------------------------------
// Ionized Hull Map
// ----------------------------------------------------------------------------

#ifdef SUPPORT_IONHULL
SAMPLER_2D_BEGIN( IonHullTexture,
	string UIName = "Ion Hull Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;

int ObjectShroudStatus
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.ObjectShroudStatus";
> = OBJECTSHROUD_INVALID;

SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Fog
// ----------------------------------------------------------------------------
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

float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
>;


// ----------------------------------------------------------------------------
// Transformations (world transformations are in skinning header)
// ----------------------------------------------------------------------------
float4x4 View : View;
float4x3 ViewI : ViewInverse;
float Time : Time;

#if defined(_WW3D_)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 Projection : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

// ----------------------------------------------------------------------------
// Utility functions
// ----------------------------------------------------------------------------
#if defined(OBJECTS_ALIEN)
#if defined(_WW3D_)
float AlienPulseFactor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.AlienPulseFactor";
> = 1.0;

float CalculateAlienPulseFactor()
{
	return AlienPulseFactor;
}
#else
float CalculateAlienPulseFactor()
{
	return 4 * (sin(Time * 2) + 1.5);
}
#endif

#endif

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput {

	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float4 LightVector[NumDirectionalLightsPerPixel] : TEXCOORD1_centroid;
	float4 HalfEyeLightVector : TEXCOORD4_centroid;
	float4 ReflectVector : TEXCOORD5_centroid;
	float4 WorldNormal_AlienPulse : TEXCOORD6_centroid;
	float4 ShadowMapTexCoord : TEXCOORD7;
	float4 Color : COLOR0;
	float Fog : FOG;

#if defined(SUPPORT_BUILDUP)
	float2 BuildupWarpTexCoord : TEXCOORD3;
#endif

#ifdef PER_PIXEL_POINT_LIGHT
	float3 WorldPosition : TEXCOORD7;
#endif
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_BUILDUP)
		float2 BuildupTexCoord : TEXCOORD1,
#endif
		uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	
	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	for (int i = 0; i < NumDirectionalLightsPerPixel; i++)
	{
		// Compute lighting direction in tangent space
		Out.LightVector[i] = float4(mul(DirectionalLight[i].Direction, worldToTangentSpace), 0);
	}

	// Compute half direction between view and light direction in tangent space
	Out.HalfEyeLightVector.xyz = normalize(mul(DirectionalLight[0].Direction + worldEyeDir, worldToTangentSpace));
	Out.ReflectVector.xyz = worldEyeDir;

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
#if defined(SUPPORT_BUILDUP)
	Out.Color.w = 1; // Buildup abuses OpacityOverride as buildup percentage
#endif


	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 0;
	for (int i = NumDirectionalLightsPerPixel; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

#ifdef PER_PIXEL_POINT_LIGHT
	Out.WorldNormal_AlienPulse.xyz = worldNormal * 0.5 + 0.5;
	Out.WorldPosition = worldPosition;
#else
#if defined(SUPPORT_POINT_LIGHTS)
	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
#endif
	Out.WorldNormal_AlienPulse.xyz = worldNormal;
#endif

	Out.Color.xyz += diffuseLight * DiffuseColor;

	Out.Color /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord.xy;

	// Hack cloud tex coord into final components of light vectors
	float2 cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	Out.LightVector[0].w = cloudTexCoord.x;
	Out.LightVector[1].w = cloudTexCoord.y;

#if defined(SCROLL_HOUSECOLOR)
	float2 texCoord1 = TexCoord * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
#elif defined(SUPPORT_BUILDUP)
	float2 texCoord1 = BuildupTexCoord;
	Out.BuildupWarpTexCoord = TexCoord * 3 + Time * 0.2;
#else
	float2 texCoord1 = TexCoord;
#endif

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	
	float2 shroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.HalfEyeLightVector.w = shroudTexCoord.x;
	Out.ReflectVector.w = shroudTexCoord.y;
	
	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);

	// Alien pulse factor
#if defined(OBJECTS_ALIEN)
	Out.WorldNormal_AlienPulse.w = CalculateAlienPulseFactor();
#else
	Out.WorldNormal_AlienPulse.w = 0;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: VS_Xenon
// ----------------------------------------------------------------------------
VSOutput VS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0
#if defined(SUPPORT_BUILDUP)
		, float2 BuildupTexCoord : TEXCOORD1
#endif
		)
{
	return VS( InSkin,
		TexCoord,
#if defined(SUPPORT_BUILDUP)
		BuildupTexCoord,
#endif
		min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int numShadows, uniform bool applyShroud,
	uniform bool fogEnabled, uniform bool recolorEnabled) : COLOR
{
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
	float2 cloudTexCoord = float2(In.LightVector[0].w, In.LightVector[1].w);
	float3 worldNormal = In.WorldNormal_AlienPulse.xyz;
	float alienPulse = In.WorldNormal_AlienPulse.w;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	float3 diffuse = baseTexture.xyz * DiffuseColor;


#if defined(OBJECTS_ALIEN)
	float time = Time * 0.2;
#endif

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;

	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	
	float4 color = In.Color * baseTexture * 2;

	float3 specularColor = SpecularColor;

#if defined(SUPPORT_SPECMAP)
	// Read spec map
	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	float reflectionStrength = specTexture.y; // Reflection/env map mask
	float selfIlluminationStrength = specTexture.z; 

#if defined(OBJECTS_ALIEN)
	// Envmap calculations
	float3 Nn = normalize(worldNormal + bumpNormal);
	float3 Vn = /*normalize*/(In.ReflectVector);
	float3 reflVect = -reflect(Vn,Nn);
	float3 envcolor = tex2D( SAMPLER(EnvironmentTexture), reflVect.y + time);

#if defined(SUPPORT_IONHULL)
	envcolor *= reflectionStrength * SpecularColor * 12;
#else
	envcolor *= EnvMult * reflectionStrength * SpecularColor * 6;

	specularColor = 3.0 * SpecularColor * specularStrength;
#endif // ION_HULL

#else // !OBJECTS_ALIEN
	// Envmap calculations
	float3 Nn = normalize(worldNormal + bumpNormal * 0.5);
	float3 Vn = /*normalize*/(In.ReflectVector);
	float3 reflVect = -reflect(Vn,Nn);
	float3 envcolor = EnvMult * texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz;
	
	color.xyz += envcolor * reflectionStrength * SpecularColor;

	specularColor = 3.0 * SpecularColor * specularStrength;
#endif // !OBJECTS_ALIEN

#endif // SUPPORT_SPECMAP

	for (int i = 0; i < NumDirectionalLightsPerPixel; i++)
	{
		// Compute lighting
        float3 lightVec = In.LightVector[i].xyz;
        float3 halfVec  = In.HalfEyeLightVector.xyz;

        float4 diffuseTerm = dot( bumpNormal, lightVec );
        float4 specularTerm = dot( bumpNormal, halfVec );

		float4 lighting = lit( diffuseTerm, specularTerm, SpecularExponent );
			
		if (i == 0)
		{
			if (numShadows >= 1)
			{
				lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo);
			}
			
			float3 cloud = float3(1, 1, 1);			
#if defined(_WW3D_) && !defined(_W3DVIEW_)
			cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
#endif

			color.xyz += DirectionalLight[0].Color * cloud
#if defined(OBJECTS_ALIEN)
				* envcolor
#endif
				* (diffuse * lighting.y + specularColor * lighting.z);
		}
		else 
		{
	    	color.xyz += DirectionalLight[i].Color * (diffuse * lighting.y);
		}
	}

#if defined(SUPPORT_IONHULL)
	float3 ionTexture1 = tex2D( SAMPLER(IonHullTexture), texCoord0 + time);
	float3 ionTexture2 = tex2D( SAMPLER(IonHullTexture), (texCoord0 * 2) + time);
	color.xyz += ionTexture1.xyz * ionTexture2.xyz * 3;
#endif
	
#if defined(SCROLL_HOUSECOLOR)
	float4 scrollTexture = tex2D( SAMPLER(ScrollingMaskTexture), texCoord1);
	selfIlluminationStrength *= scrollTexture.x;

	color.xyz += selfIlluminationStrength * RecolorColor * RecolorMultiplier * recolorEnabled;
#else // defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_SPECMAP) && !defined(OBJECTS_ALIEN)
	color.xyz = lerp(color, baseTexture, selfIlluminationStrength);
#endif

#if defined(SUPPORT_RECOLORING)
	if (recolorEnabled)
	{
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), texCoord0);
		recolorColor.xyz *= RecolorColor;
#if defined(OBJECTS_ALIEN)
		color.xyz += recolorColor.xyz * alienPulse;
#else
		color.xyz = lerp(color.xyz, recolorColor.xyz, recolorColor.a);
#endif
	}
#endif //defined(SUPPORT_RECOLORING)
#endif // defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_BUILDUP)
	float3 warpTexture = tex2D( SAMPLER(BuildUpMap), In.BuildupWarpTexCoord);
	float fadeTexture = tex2D( SAMPLER(BuildUpMap), texCoord1).w;
	float alphaThreshold = fadeTexture * OpacityOverride;

	color.xyz += (alphaThreshold <= 0.25) * warpTexture;
	clip(alphaThreshold - 0.21);
#endif

	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}

	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), float2( In.HalfEyeLightVector.w, In.ReflectVector.w ) );
	}

	return color;
}


// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In ) : COLOR
{
	return PS( In, min(NumShadows, 1), (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR), Fog.IsEnabled, (NumRecolorColors > 0) );
}


// ----------------------------------------------------------------------------
// SHADER: VS_1
// ----------------------------------------------------------------------------
struct VSOutput_1 {
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
// SHADER: VS_1
// ----------------------------------------------------------------------------
VSOutput_1 VS_1(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	VSOutput_1 Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,worldPosition, worldNormal, worldTangent, worldBinormal);
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.TexCoord0 = TexCoord;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: VS_1_Xenon
// ----------------------------------------------------------------------------
VSOutput_1 VS_1_Xenon(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0 )
{
	return VS_1( InSkin, TexCoord, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// SHADER: PS_1
// ----------------------------------------------------------------------------
float4 PS_1( VSOutput_1 In, uniform bool applyShroud ) : COLOR
{
	float4 color = 1;
	color.w = OpacityOverride * tex2D( SAMPLER(DiffuseTexture), In.TexCoord0).w;
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

	return color;
}

// ----------------------------------------------------------------------------
// SHADER: PS_1_Xenon
// ----------------------------------------------------------------------------
float4 PS_1_Xenon( VSOutput_1 In ) : COLOR
{
	return PS_1( In, (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) );
}

// ----------------------------------------------------------------------------
// Arrays: Default
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#define VS_NumJointsPerVertex \
	compile vs_2_0 VS(0), \
	compile vs_2_0 VS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = 1 );

#define PS_NumShadows(recolorEnabled) \
	compile ps_2_0 PS(0, false, false, recolorEnabled), \
	compile ps_2_0 PS(1, false, false, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_RecolorEnabled = PS_Multiplier_NumShadows * 2 );
	
#define PS_RecolorEnabled \
	PS_NumShadows(false), \
	PS_NumShadows(true)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_RecolorEnabled
};
#endif

DEFINE_ARRAY_MULTIPLIER( VS1_Multiplier_Final = 2 );

#define VS1_NumJointsPerVertex \
	compile vs_2_0 VS_1(0), \
	compile vs_2_0 VS_1(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS1_Array[VS1_Multiplier_Final] =
{
	VS1_NumJointsPerVertex
};
#endif

#define PS1_ApplyShroud \
	compile ps_2_0 PS_1(false), \
	compile ps_2_0 PS_1(true)

DEFINE_ARRAY_MULTIPLIER( PS1_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS1_Array[PS1_Multiplier_Final] =
{
	PS1_ApplyShroud
};
#endif


// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_P0")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon() );

		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			min(NumShadows, 1) * PS_Multiplier_NumShadows
			+ (NumRecolorColors > 0) * PS_Multiplier_RecolorEnabled,
			compile PS_VERSION PS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = ( Fog.IsEnabled );
		FogColor = ( Fog.Color );
#endif
	}

#if !defined( EA_PLATFORM_XENON )
	pass p1
	<
		USE_EXPRESSION_EVALUATOR("Objects_P1")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS1_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION VS_1_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PS1_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR),
			compile PS_VERSION PS_1_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;

#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaTestEnable = ( AlphaTestEnable );
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}

#endif // #if !defined( EA_PLATFORM_XENON )	
}

#if !defined(_3DSMAX_)

// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_U_Xenon( VSOutput In ) : COLOR
{
	return PS( In, min(NumShadows, 1), (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR), Fog.IsEnabled, (NumRecolorColors > 0) );
}

// ----------------------------------------------------------------------------
// Arrays: Default_U
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_U_Multiplier_Final = 2 );

#define VS_U_NumJointsPerVertex \
	compile VS_VERSION_ULTRAHIGH VS(0), \
	compile VS_VERSION_ULTRAHIGH VS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_U_Array[VS_U_Multiplier_Final] =
{
	VS_U_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_NumShadows = 1 );

#define PS_U_NumShadows(applyShroud, fogEnabled, recolorEnabled) \
	compile PS_VERSION_ULTRAHIGH PS(0, applyShroud, fogEnabled, recolorEnabled), \
	compile PS_VERSION_ULTRAHIGH PS(1, applyShroud, fogEnabled, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_ApplyShroud = PS_U_Multiplier_NumShadows * 2 );

#define PS_U_ApplyShroud(fogEnabled, recolorEnabled) \
	PS_U_NumShadows(false, fogEnabled, recolorEnabled), \
	PS_U_NumShadows(true, fogEnabled, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_FogEnabled = PS_U_Multiplier_ApplyShroud * 2 );

#define PS_U_FogEnabled(recolorEnabled) \
	PS_U_ApplyShroud(false, recolorEnabled), \
	PS_U_ApplyShroud(true, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_RecolorEnabled = PS_U_Multiplier_FogEnabled * 2 );
	
#define PS_U_RecolorEnabled \
	PS_U_FogEnabled(false), \
	PS_U_FogEnabled(true)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_Final = PS_U_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_U_Array[PS_U_Multiplier_Final] =
{
	PS_U_RecolorEnabled
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default_U
// ----------------------------------------------------------------------------
technique Default_U
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_U")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_U_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon() );

		PixelShader = ARRAY_EXPRESSION_PS( PS_U_Array,
			min(NumShadows, 1) * PS_U_Multiplier_NumShadows
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_U_Multiplier_ApplyShroud
			+ Fog.IsEnabled * PS_U_Multiplier_FogEnabled
			+ (NumRecolorColors > 0) * PS_U_Multiplier_RecolorEnabled,
			compile PS_VERSION PS_U_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

#endif // _3DSMAX_

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: VS_M
// ----------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position : POSITION;
	float3 Color : TEXCOORD1; // Allows strong overbrightness
	float2 TexCoord0 : TEXCOORD0;
	float3 LightVector : TEXCOORD2;
	float3 HalfEyeLightVector : TEXCOORD3;
	float2 ShroudTexCoord : TEXCOORD4;
	float2 CloudTexCoord : TEXCOORD5;
	float2 TexCoord1 : TEXCOORD6;
#if defined(OBJECTS_ALIEN)
	float AlienPulse : TEXCOORD7;
#endif
	float Fog : COLOR0;
};

VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin,
		float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_BUILDUP)
		float2 BuildupTexCoord : TEXCOORD1,
#endif
		uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_M Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex, worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	
	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	// Compute lighting direction in tangent space
	Out.LightVector = mul(DirectionalLight[0].Direction, worldToTangentSpace);

	// Compute half angle direction between light and view direction in tangent space
	Out.HalfEyeLightVector = normalize(mul(DirectionalLight[0].Direction + worldEyeDir, worldToTangentSpace));

	float3 diffuseLight = 0;
	// Compute light 1 and up diffuse per vertex, light 0 will be done in pixel shader
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

#if defined(SUPPORT_POINT_LIGHTS)
	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;	
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);	
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
#endif

	Out.Color = AmbientLightColor * AmbientColor + diffuseLight * DiffuseColor;
	Out.TexCoord0 = TexCoord.xy;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	
#if defined(SCROLL_HOUSECOLOR)
	Out.TexCoord1 = TexCoord * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
#elif defined(SUPPORT_BUILDUP)
	Out.TexCoord1 = BuildupTexCoord;
#else
	Out.TexCoord1 = TexCoord;
#endif

	// Alien pulse factor
#if defined(OBJECTS_ALIEN)
	Out.AlienPulse = CalculateAlienPulseFactor();
#endif
		
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	return Out;
}

// ----------------------------------------------------------------------------
// Shader: PS_M
// ----------------------------------------------------------------------------
float4 PS_M(VSOutput_M In, uniform bool applyShroud, uniform bool fogEnabled, uniform bool recolorEnabled) : COLOR
{
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), In.TexCoord0);
	float3 diffuse = baseTexture.xyz;

#if defined(OBJECTS_ALIEN)
	float time = Time * 0.2;
#if defined(SUPPORT_IONHULL)
	float3 ionTexture1 = tex2D( SAMPLER(IonHullTexture), In.TexCoord0 + time);
	//float3 ionTexture2 = tex2D( SAMPLER(IonHullTexture), (In.TexCoord0 * 2) + time);
	//diffuse += ionTexture1.xyz * ionTexture2.xyz * 20;
	diffuse += ionTexture1.xyz * 3;
#endif
#endif

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D(SAMPLER(NormalMap), In.TexCoord0) * 2.0 - 1.0;
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	//bumpNormal = float3(0, 0, 1);

	float3 specularColor = SpecularColor;

#if defined(SUPPORT_SPECMAP)
	float4 specTexture = tex2D(SAMPLER(SpecMap), In.TexCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	float selfIlluminationStrength = specTexture.z;

	specularColor = 3.0 * SpecularColor * specularStrength;
#endif

	// Sample cloud texture
	float3 cloud = float3(1, 1, 1);			
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	cloud = tex2D( SAMPLER(CloudTexture), In.CloudTexCoord);
#endif

	// Compute lighting
	float4 lighting = lit(dot(bumpNormal, In.LightVector), dot(bumpNormal, In.HalfEyeLightVector), SpecularExponent);
	
	float4 color;	
	color.xyz = In.Color * diffuse;
	color.xyz += DirectionalLight[0].Color * cloud * (diffuse * DiffuseColor * lighting.y + specularColor * lighting.z);

#if defined(SCROLL_HOUSECOLOR)
	float4 scrollTexture = tex2D( SAMPLER(ScrollingMaskTexture), In.TexCoord1);
	selfIlluminationStrength *= scrollTexture.x;

	color.xyz += selfIlluminationStrength * RecolorColor * RecolorMultiplier * recolorEnabled;
#else // defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_SPECMAP) && !defined(OBJECTS_ALIEN)
	color.xyz = lerp(color.xyz, baseTexture.xyz, selfIlluminationStrength);
#endif

#if defined(SUPPORT_RECOLORING)
	if (recolorEnabled)
	{
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), In.TexCoord0);
		recolorColor.xyz *= RecolorColor;
#if defined(OBJECTS_ALIEN)
		color.xyz += recolorColor.xyz * In.AlienPulse;
#else
		color.xyz = lerp(color.xyz, recolorColor.xyz, recolorColor.a);
#endif
	}
#endif //defined(SUPPORT_RECOLORING)
#endif // defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_BUILDUP)
	float fadeTexture = tex2D( SAMPLER(BuildUpMap), In.TexCoord1).w;
	float3 warpTexture = tex2D( SAMPLER(BuildUpMap), In.TexCoord0 * 3 + time);
	float alphaThreshold = fadeTexture * OpacityOverride;

	color.xyz += (alphaThreshold <= 0.25) * warpTexture;
	clip(alphaThreshold - 0.21);
#endif

	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}

	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

#if defined(SUPPORT_BUILDUP)
	color.a = baseTexture.w;
#else
	color.a = baseTexture.w * OpacityOverride;
#endif
	
	return color;
}

// ----------------------------------------------------------------------------
// Arrays: Default_M
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );

#define VS_M_NumJointsPerVertex \
	compile VS_VERSION_HIGH VS_M(0), \
	compile VS_VERSION_HIGH VS_M(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};
#endif


DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_ApplyShroud = 1 );

#define PS_M_ApplyShroud(fogEnabled, recolorEnabled) \
	compile PS_VERSION_HIGH PS_M(false, fogEnabled, recolorEnabled), \
	compile PS_VERSION_HIGH PS_M(true, fogEnabled, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_FogEnabled = 2 * PS_M_Multiplier_ApplyShroud );

#define PS_M_FogEnabled(recolorEnabled) \
	PS_M_ApplyShroud(false, recolorEnabled), \
	PS_M_ApplyShroud(true, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_RecolorEnabled = 2 * PS_M_Multiplier_FogEnabled );

#define PS_M_RecolorEnabled \
	PS_M_FogEnabled(false), \
	PS_M_FogEnabled(true)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = 2 * PS_M_Multiplier_RecolorEnabled );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_RecolorEnabled
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default_M
// ----------------------------------------------------------------------------
technique _Default_M
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_M")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
			min(NumJointsPerVertex, 1),
			NO_ARRAY_ALTERNATIVE);
			
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_M_Multiplier_ApplyShroud
			+ Fog.IsEnabled * PS_M_Multiplier_FogEnabled
			+ (NumRecolorColors > 0) * PS_M_Multiplier_RecolorEnabled,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
				
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED				
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

// ----------------------------------------------------------------------------
// SHADER: VS_L
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
	float4 Color_Opacity : COLOR0;
#if defined(OBJECTS_ALIEN)
	float3 AlienPulse : COLOR1; // Scalar value replicated into xyz, due to PS1.1 limitations
#endif
	float2 BaseTexCoord : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float2 RecolorTexCoord : TEXCOORD2;
#if defined(SUPPORT_IONHULL)
	float2 IonHullTexCoord : TEXCOORD3;
#endif
};

VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_L Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame_L(InSkin, numJointsPerVertex, worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute directional lights
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 lightColor = DirectionalLight[i].Color;
		if (i == 0)
		{
			lightColor *= NoCloudMultiplier;
		}

		diffuseLight += lightColor * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

#if defined(SUPPORT_POINT_LIGHTS)
	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
#endif

	Out.Color_Opacity.xyz = AmbientLightColor * AmbientColor + diffuseLight * DiffuseColor;
	Out.Color_Opacity.xyz /= 2; // Allow overbright light through, pixel shader will mulitply by two again
	Out.Color_Opacity.w = OpacityOverride;
	Out.BaseTexCoord.xy = TexCoord.xy;
	Out.RecolorTexCoord.xy = TexCoord.xy;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

#if defined(OBJECTS_ALIEN)
	// Alien pulse factor
	Out.AlienPulse.xyz = CalculateAlienPulseFactor() / 4;
#endif

#if defined(SUPPORT_IONHULL)
	Out.IonHullTexCoord = TexCoord + Time * 0.2;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS_L
// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_L In, uniform bool applyShroud, uniform bool recolorEnabled) : COLOR
{
//	return float4(In.AlienPulse, 1);
	// Get diffuse color
	float4 baseTexture = tex2D(SAMPLER(DiffuseTexture), In.BaseTexCoord);

	float3 color;
	color = baseTexture.xyz * In.Color_Opacity.xyz;

#if defined(SUPPORT_IONHULL)
	float3 ionTexture1 = tex2D( SAMPLER(IonHullTexture), In.IonHullTexCoord);
	color += ionTexture1 * 2;
#endif

	color.xyz += color.xyz;


#if defined(SCROLL_HOUSECOLOR)
	float4 specTexture = tex2D(SAMPLER(SpecMap), In.RecolorTexCoord);
	float selfIlluminationStrength = specTexture.z;

	color.xyz += selfIlluminationStrength * RecolorColor * RecolorMultiplier * recolorEnabled;
#else // defined(SCROLL_HOUSECOLOR)

#if defined(SUPPORT_RECOLORING)
	if (recolorEnabled)
	{
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), In.RecolorTexCoord);
		recolorColor.xyz *= RecolorColor;
#if defined(OBJECTS_ALIEN)
		color.xyz += recolorColor.xyz * In.AlienPulse * 4;
#else
		color.xyz = lerp(color.xyz, recolorColor.xyz, recolorColor.a);
#endif
	}
#endif //defined(SUPPORT_RECOLORING)
#endif // defined(SCROLL_HOUSECOLOR)
	
	if (applyShroud)
	{
		color.xyz *= tex2D(SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}
	return float4(color, baseTexture.w * In.Color_Opacity.w);
}

// ----------------------------------------------------------------------------
// Technique: Default_L
// Low LOD technique. Doesn't do any normal mapping.
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );

#define VS_L_NumJointsPerVertex \
	compile VS_VERSION_LOW VS_L(0), \
	compile VS_VERSION_LOW VS_L(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_ApplyShroud = 1 );

#define PS_L_ApplyShroud(recolorEnabled) \
	compile PS_VERSION_LOW PS_L(false, recolorEnabled), \
	compile PS_VERSION_LOW PS_L(true, recolorEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_RecolorEnabled = 2 * PS_L_Multiplier_ApplyShroud);

#define PS_L_RecolorEnabled \
	PS_L_ApplyShroud(false), \
	PS_L_ApplyShroud(true)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = 2 * PS_L_Multiplier_RecolorEnabled);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_RecolorEnabled
};
#endif


// ----------------------------------------------------------------------------
technique _Default_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_L")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
			min(NumJointsPerVertex, 1),
			NO_ARRAY_ALTERNATIVE );
			
		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_L_Multiplier_ApplyShroud
			+ (NumRecolorColors > 0) * PS_L_Multiplier_RecolorEnabled,
			NO_ARRAY_ALTERNATIVE );
			
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED	
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

#endif // ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
#if defined(SUPPORT_BUILDUP)
	float2 TexCoord1 : TEXCOORD2;
#endif
	float Depth : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_BUILDUP)
	float2 BuildupTexCoord : TEXCOORD1,
#endif
	uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.Depth = Out.Position.z / Out.Position.w;	
	Out.TexCoord0 = TexCoord;	

#if defined(SUPPORT_BUILDUP)
	Out.TexCoord1 = BuildupTexCoord;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform bool alphaTestEnable) : COLOR
{
#if defined(SUPPORT_BUILDUP)
	float fadeTexture = tex2D( SAMPLER(BuildUpMap), In.TexCoord1).w;
	float alphaThreshold = fadeTexture * OpacityOverride;
	clip(alphaThreshold - 0.21);

	OpacityOverride = 1;
#endif

	float opacity = OpacityOverride * tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;	
	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}
	return In.Depth;
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS_Xenon
// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
		float2 TexCoord : TEXCOORD0
#if defined(SUPPORT_BUILDUP)
		, float2 BuildupTexCoord : TEXCOORD1
#endif
		)
{
	return CreateShadowMapVS( InSkin,
		TexCoord,
#if defined(SUPPORT_BUILDUP)
		BuildupTexCoord,
#endif
		min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon(VSOutput_CreateShadowMap In) : COLOR
{
	return CreateShadowMapPS(In, AlphaTestEnable);
}

// ----------------------------------------------------------------------------
// Technique _CreateShadowMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 );

#define VSCreateShadowMap_NumJointsPerVertex \
	compile vs_1_1 CreateShadowMapVS(0), \
	compile vs_1_1 CreateShadowMapVS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif

#define PSCreateShadowMap_AlphaTestEnable \
	compile ps_2_0 CreateShadowMapPS(false), \
	compile ps_2_0 CreateShadowMapPS(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif

// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_CreateShadowMap")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateShadowMapVS_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			AlphaTestEnable,
			compile PS_VERSION CreateShadowMapPS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

// ----------------------------------------------------------------------------
// SHADER: VS_WorldNormShader
// ----------------------------------------------------------------------------
struct VSWorldNormOutput {

	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord : TEXCOORD0;
	float3x3 TangentToViewSpace : TEXCOORD1;
};

VSWorldNormOutput VS_WorldNormShader(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSWorldNormOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex, worldPosition, worldNormal, worldTangent, worldBinormal);
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = (float3x3(-worldBinormal, -worldTangent, worldNormal));
	Out.TangentToViewSpace = mul(tangentToWorldSpace, (float3x3)View);	
	Out.TexCoord = TexCoord;			
	Out.Color.xyz = worldNormal; //transform the normal		
	Out.Color.w = OpacityOverride;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS_WorldNormShader
// ----------------------------------------------------------------------------
float4 PS_WorldNormShader(VSWorldNormOutput In) : COLOR
{
	float opacity = In.Color.w;

	float2 texcoord0 = In.TexCoord.xy;
	opacity *= tex2D(SAMPLER(DiffuseTexture), In.TexCoord.xy).w;
	
	//The normal map is stored [0...1] so we have to map it back into the [-1...1] range
	float3 Normal = (2 * (tex2D(SAMPLER(NormalMap), texcoord0))) - 1.0f;
	float3 colorNormal = mul(Normal, In.TangentToViewSpace);
	colorNormal = (colorNormal / 2) + 0.5f; //shift back to [0...1]
	return float4(colorNormal, opacity);
}

// ----------------------------------------------------------------------------
// SHADER: VS_WorldNormShader_Xenon
// ----------------------------------------------------------------------------
VSWorldNormOutput VS_WorldNormShader_Xenon(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0 )
{
	return VS_WorldNormShader( InSkin, TexCoord, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE : _RenderWorldNormals
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_NumJointsPerVertex = 2 );

#define VS_WorldNormNumJointsPerVertex \
	compile vs_2_0 VS_WorldNormShader(0), \
	compile vs_2_0 VS_WorldNormShader(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_WorldNormArray[2] =
{
	VS_WorldNormNumJointsPerVertex
};
#endif

// ----------------------------------------------------------------------------
technique _RenderWorldNormals
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Objects_WorldNormShader")
	>
	{		
		VertexShader = ARRAY_EXPRESSION_VS( VS_WorldNormArray,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION VS_WorldNormShader_Xenon() );
		
		PixelShader = compile ps_2_0 PS_WorldNormShader();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaBlendEnable = ( OpacityOverride < 0.99);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

// ----------------------------------------------------------------------------
// SHADER: FlatColor
// ----------------------------------------------------------------------------
float4 PS_FlatColor( VSOutput In ) : COLOR
{
	float opacity = OpacityOverride;

	opacity *= tex2D( SAMPLER(DiffuseTexture), In.TexCoord0_TexCoord1.xy).w;
	return float4(FlatColorOverride.xyz, opacity); 
}

// ----------------------------------------------------------------------------
// TECHNIQUE : _DrawFlatColor
// ----------------------------------------------------------------------------
technique _DrawFlatColor
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Objects_DrawFlatColor")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION VS_Xenon() );
			
		PixelShader = compile ps_2_0 PS_FlatColor();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaBlendEnable = ( OpacityOverride < 0.99);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}  
}

