//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Water FX Shader
//
// Vishwa Ranjan 02/28/05
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
// Light sources
// ----------------------------------------------------------------------------
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

float DimmingFactor 
< 
	string UIName = "DimmingFactor";
> = 0.8;

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

float ShadowLightness
< 
	string UIName = "Shadow Lightness";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
> = 0.8f;

// ----------------------------------------------------------------------------
// MATERIAL PARAMATERS
// ----------------------------------------------------------------------------
float4 MaterialColorDiffuse 
<
	string UIName = "Diffuse Color";
	string UIWidget = "Color";
> = float4(0.15, 0.3, 0.35, 0.5);

float3 SpecularColor
<
	string UIName = "Specular Color"; 
    string UIWidget = "Color";
> = float3(0.8, 0.8, 0.8);
	
float SpecularExponent
<
	string UIName = "Specular Exponent"; 
    string UIWidget = "Slider";
	float UIMax = 1000.0f;
	float UIMin = 0;
	float UIStep = 5.0f;
> = 50.0;

bool UseMySpecularDirection
<
	string UIName = "Use My Specular Direction"; 
> = false;

float2 MySpecularDirection
<
	string UIName = "SpecDir.xy"; 
    string UIWidget = "Spinner";
> = float2(30.0f, 60.0f);


float WindAngle 
< 
	string UIName = "Wind Angle";
> = 0.0f;

float WindSpeed 
< 
	string UIName = "Wind Speed";
> = 0.02f;

//--------------------------------- BUMP MAP STUFF --------------------------------------
SAMPLER_2D_BEGIN( WaterBumpTexture,
	string UIName = "Bump Texture";
	string ResourceName = "WtrBump_01.tga";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

float BumpScale
< 
	string UIName = "Bump Scale";
//	string UIWidget = "None";
> = 0.2;
	
float BumpRotation
< 
	string UIName = "Bump Rotation";
//	string UIWidget = "None";
> = 0.2;

float2 BumpUVScale
< 
	string UIName = "xyBumpUVScale";
	string UIWidget = "Spinner";
> = float2(7.0f, 7.0f);

float BumpSpeed 
< 
	string UIName = "Bump Speed";
> = 0.0f;

//---------------------------------- ENV MAP STUFF --------------------------------------
SAMPLER_2D_BEGIN( WaterEnvTexture,
	string UIName = "Env Texture";
	string ResourceName = "WtrEnv_Default.tga";
	)
    MipFilter = Point;
    MinFilter = Linear;
    MagFilter = Linear;
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

float2 EnvUVScale 
<
	string UIName = "xyEnvUVScale";
	string UIWidget = "Spinner";
> = float2(0.2f, 0.2f);

// ----------------------------------------------------------------------------
// Environment map (to replace reflection on Medium)
// ----------------------------------------------------------------------------
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

//---------------------------------- REFLECTION STUFF --------------------------------------
SAMPLER_2D_BEGIN( WaterReflectionTexture,
	string UIName = "Water Reflection Texture";
	string UIWidget = "None";
	string ResourceName = "WaterReflection.dds";
	string SasBindAddress = "WaterDraw.ReflectionTexture";
	)
    MipFilter = Point;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = CLAMP;
    AddressV = CLAMP;
SAMPLER_2D_END

float ReflectionStrength 
< 
	string UIName = "Reflection Strength";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
> = 0.2f;

float ReflectionPerturbation
< 
	string UIName = "Reflection Perturbation";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
> = 0.005f;

//---------------------------------- SHROUD STUFF --------------------------------------
SAMPLER_2D_BEGIN( ShroudTexture,
	string UIName = "Shroud Texture";
	string UIWidget = "None";
	string ResourceName = "Shroud.dds";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
    MipFilter = Point;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = CLAMP;
    AddressV = CLAMP;
SAMPLER_2D_END

ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;

//----------------------------------- WAVE STUFF --------------------------------------
SAMPLER_2D_BEGIN( WaveTexture1,
	string UIName = "Wave Texture1";
	string ResourceName = "WtrWhitecap_01.tga";
	)
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaveTexture2,
	string UIName = "Wave Texture2";
	string ResourceName = "WtrWhitecap_01.tga";
	)
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

float2 WaveUVScale
<
	string UIName = "xyWaveUVScale";
	string UIWidget = "Spinner";
> = float2(7.0f, 7.0f);
	
float WaveAngle 
< 
	string UIName = "Wave Angle";
> = 0.2f;

float WaveSpeed
< 
	string UIName = "Wave Speed";
> = 0.0f;

// ----------------------------------------------------------------------------
// Gerstner waves: allows up to four
// ----------------------------------------------------------------------------
float4 GWAmpFreqPhaseSteepness1
<
	string UIName = "GW Parameters 1"; 
    string UIWidget = "Spinner";
> = float4(100.0f, 1.0f, 1.1f, 5.5f);
	
float4 GWAmpFreqPhaseSteepness2
<
	string UIName = "GW Parameters 2"; 
    string UIWidget = "Spinner";
> = float4(0.00001f, 0.00001f, 0.00001f, 0.00001f);
	
float4 GWAmpFreqPhaseSteepness3
<
	string UIName = "GW Parameters 3"; 
    string UIWidget = "Spinner";
> = float4(0.00001f, 0.00001f, 0.00001f, 0.00001f);

//----------------------------------- begin pca ultra  ---------------------
SAMPLER_2D_BEGIN( WaterPCATexture1,
	string UIName = "PCA Froth Texture";
	string ResourceName = "WaterFroth.tga";
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4;
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaterPCATexture2,
	string UIName = "PCA Froth Texture";
	string ResourceName = "WaterFroth.tga";
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaterPCATexture3,
	string UIName = "PCA Froth Texture";
	string ResourceName = "WaterFroth.tga";
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( PCANoiseTexture,
	string UIName = "PCA Froth Texture";
	string ResourceName = "WaterFroth.tga";
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( PCAFrothTexture,
	string UIName = "PCA Froth Texture";
	string ResourceName = "WaterFroth.tga";
	)
    MipFilter = MipFilterBest;
    MinFilter = MinFilterBest;
    MagFilter = MagFilterBest; 
    MaxAnisotropy = 4; 
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END


struct PCAWater
{
	float3 Mean;
	float4 Bases03X;
	float4 Bases03Y;
	float4 Bases03Z;
	float4 Bases47X;
	float4 Bases47Y;
	float4 Bases47Z;
	float4 Bases811X;
	float4 Bases811Y;
	float4 Bases811Z;
};

PCAWater PCA
<
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.PCAWater";
> =
{
	float3(0.0f, 0.0f, 1.0f), float4(0.0f, 0.0f, 0.0f, 0.0f), 
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f),
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f), 
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f),
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f)
};

PCAWater PCASetup_M
<
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.PCAWater_M";
> =
{
	float3(0.0f, 0.0f, 1.0f), float4(0.0f, 0.0f, 0.0f, 0.0f), 
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f),
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f), 
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f),
	float4(0.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 0.0f)
};

float2 PCABumpUVScale
< 
	string UIName = "PCABumpUVScale";
	string UIWidget = "Spinner";
> = float2(1.5f, 3.0f);

float2 PCAWaveUVScale
< 
	string UIName = "PCAWaveUVScale";
	string UIWidget = "Spinner";
> = float2(0.01f, 0.0075f);


// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x4 WorldView : WorldView;
float4x4 World : World;
float4x4 ViewI : ViewInverse;
float4x4 View : View;
float4x4 Projection : Projection;
float Time : Time;

// Fog
WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

bool BlendUsingTerrainAlpha
<
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.BlendUsingTerrainAlpha";
> = false;

float MaxAlphaDepth
<
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.TransparentWaterDepth";
> = 0.0;

float DeepWaterAlpha
<
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.MinWaterOpacity";
> = 1.0;

float ComputeWaterTransparency(float WaterDepth)
{
	float waterTransparency = MaterialColorDiffuse.a;
	if (BlendUsingTerrainAlpha)
	{
		float realMaxAlphaDepth = MaxAlphaDepth * DeepWaterAlpha * DeepWaterAlpha;
		waterTransparency = saturate(WaterDepth / realMaxAlphaDepth) * DeepWaterAlpha;
	}
	
	return waterTransparency;
}

//----------------------------------- LOCAL STUFF --------------------------------------

static float2 Wave1Direction = {1.0f, 1.0f};
static float2 Wave2Direction = {1.0f, 1.0f};
static float BumpAngle = 0.0f;
static float2x2 BumpMatrix = {1.0, 0.0, 0.0, 1.0};
static float2x2 Wave1Matrix = {1.0, 0.0, 0.0, 1.0};
static float2x2 Wave2Matrix = {1.0, 0.0, 0.0, 1.0};

static float4x4 ClassicEnvMatrix = {0.5f, 0.0f, 0.0f, 0.5f,
							 0.0f, 1.0f, 0.0f, 0.0f,
							 0.0f, 0.0f, 0.5f, 0.5f,
							 0.0f, 0.0f, 0.0f, 1.0f};
static float DegreeToRadian = 3.141592f/180.0f;						 



#include "WaterDefault.fxh"
#include "WaterBumpSpecular.fxh"
#include "WaterPCA.fxh"
