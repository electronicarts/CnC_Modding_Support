//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// TIBERIUM FX Shader for Command and Conquer 3: Tiberium Wars
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#include "Common.fxh"
#include "Random.fxh"

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
float3 AmbientLightColor : Ambient = float3(0.1, 0.1, 0.1);
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
// Clouds
// ----------------------------------------------------------------------------
CloudSetup Cloud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Cloud";
#endif
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
// MATERIAL PARAMATERS
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( DiffuseMap,
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

float TexCoordTransform_Normal
<
	string UIName = "Normal Map Scale";
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 100;
    float UIStep = 0.1;
> = float(10.0);

//SpecMap really means : R = Specular Mask; G = Environment Mask; B = Additive Mask
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

float TexCoordTransform_Spec
<
	string UIName = "Specular Map Scale";
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 100;
    float UIStep = 0.1;
> = float(10.0);

SAMPLER_CUBE_BEGIN( EnvMap,
	string UIName = "Reflection Map";
    string ResourceType = "Cube"; 
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = clamp;
	AddressV = clamp;
	AddressW = clamp;
SAMPLER_CUBE_END

// Editable parameters
float BumpScale
<
	string UIName = "Bump Height"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 6.0;
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

float SpecMult
<
	string UIName = "Specular Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 10.0f;
	float UIMin = 0.0f;
	float UIStep = 0.1f;
> = 3.0;

float EnvMult
<
	string UIName = "Reflection Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;

SAMPLER_2D_BEGIN( TimeGlowTexture,
	string UIName = "Time Glow Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

float3 TimeGlowStrength
<
	string UIName = "Time Glow Color"; 
    string UIWidget = "Slider";
> = float3(1.0, 1.0, 1.0);

float2 TimeGlowSpeedRange
<
	string UIName = "TGSpd MinRng"; 
    string UIWidget = "Spinner";
> = float2(1, 0.2);

float TimeGlowActiveRatio
<
	string UIName = "Time Glow Active Ratio"; 
    string UIWidget = "Slider";
> = 0.25;

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud";
#endif
> = DEFAULT_SHROUD;


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

int ObjectShroudStatus
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud.ObjectShroudStatus";
#endif
> = OBJECTSHROUD_INVALID;


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

// ----------------------------------------------------------------------------
// Transformations (world transformations are in skinning header)
// ----------------------------------------------------------------------------
float4x4 WorldIT : WorldInverseTranspose < string UIWidget="None"; >;
float4x4 View : View;
float4x3 ViewI : ViewInverse;
float4x4 Projection : Projection;
float Time : Time;


// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
#define VS_OUTPUT \
    float4 Color : COLOR0; \
	float4 ReflectVector_Fog : COLOR1; \
	float4 TexCoord0_CloudTexCoord : TEXCOORD0; \
	float4 LightVector[NumDirectionalLights] : TEXCOORD1; \
	float3 HalfEyeLightVector : TEXCOORD4; \
	float3 WorldNormal : TEXCOORD5; \
	float2 ShroudTexCoord : TEXCOORD6; \
    float4 ShadowMapTexCoord : TEXCOORD7;

struct VSOutput_U
{
	float4 Position : POSITION;
    VS_OUTPUT
};

struct PSInput_U
{
	// For whatever reason in this shader the compiler complains if the POSITION VS ouput semantic is declared even though it is unused in the pixel shader
    VS_OUTPUT
};

// ----------------------------------------------------------------------------
VSOutput_U VS_U(VSInputSkinningOneBoneTangentFrame InSkin, 
	float4 Color : COLOR0,
	float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_U Out;

	float4 VertexColor = Color;
	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	Out.ReflectVector_Fog.xyz = worldEyeDir * 0.5 + 0.5; // To put into color output register, bring into range 0..1

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	for (int i = 0; i < NumDirectionalLights; i++)
	{
		// Compute lighting direction in tangent space
		Out.LightVector[i] = float4(mul(DirectionalLight[i].Direction, worldToTangentSpace), 0);

		// Compute half direction between view and light direction in tangent space
		Out.HalfEyeLightVector = normalize(mul(DirectionalLight[0].Direction + worldEyeDir, worldToTangentSpace));
	}

	Out.Color = float4((AmbientLightColor + AmbientColor) * VertexColor, VertexColor.w);
	
	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		Out.Color.xyz += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
	Out.WorldNormal = worldNormal;

	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_CloudTexCoord.xy = TexCoord.xy;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	
	// Hack cloud tex coord into final components of light vectors
	float2 cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	Out.TexCoord0_CloudTexCoord.zw = cloudTexCoord.yx;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	
	// Calculate fog
	Out.ReflectVector_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);


	// Random glow for tiberium crystals
	float3 objectCenterWorld = GetFirstBonePosition(InSkin.BlendIndices, numJointsPerVertex);
	float randomOffset = GetRandomFloatValue(float2(0, 20), 3, VertexColor.w * 255 + (objectCenterWorld.x + objectCenterWorld.y) * 100);
	float speed = GetRandomFloatValue(TimeGlowSpeedRange, 7, VertexColor.w * 300 + (objectCenterWorld.x + objectCenterWorld.y) * 30);
	float strength = saturate(sin(Time * speed + randomOffset) * 0.5 - 0.5 + TimeGlowActiveRatio) / max(TimeGlowActiveRatio, 0.001);
	Out.Color.w = strength * strength;

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_U(PSInput_U In, uniform int numShadows, uniform bool applyShroud, uniform bool fogEnabled) : COLOR
{
	float2 texCoord0 = In.TexCoord0_CloudTexCoord.xy;

	float2 texCoordNorm = In.TexCoord0_CloudTexCoord.xy * TexCoordTransform_Normal;
	float2 texCoordSpec = In.TexCoord0_CloudTexCoord.xy * TexCoordTransform_Spec;
	
	float2 cloudTexCoord = In.TexCoord0_CloudTexCoord.wz;
	
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseMap), texCoord0);
	float3 diffuse = baseTexture.xyz * DiffuseColor;

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoordNorm) * 2.0 - 1.0;

	float3 VertexColor = In.Color.xyz;	

	
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
 	
    //envmap calculations
    float3 EnvBumpScale = 0.6f;   
	half3 Nn = normalize(In.WorldNormal) + (bumpNormal * EnvBumpScale);
    half3 Vn = normalize(In.ReflectVector_Fog.xyz - float3(0.5, 0.5, 0.5)); // Unpack from range [0..1] to [-1..1] and normalize
	half3 reflVect = -reflect(Vn,Nn);
	float3 envcolor = EnvMult * texCUBE( SAMPLER(EnvMap),reflVect).xyz;
	
	//setup specmap passes
	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoordSpec);
	float specularStrength = specTexture.x;  // Specular lighting mask
	float reflectionStrength = specTexture.y; // Reflection/env map mask

	envcolor = (envcolor * reflectionStrength * SpecularColor);  // this uses the reflection mask

	SpecularColor = SpecMult * SpecularColor * specularStrength;
	
	float3 cumulativeLighting = 0;
	float4 color = In.Color * baseTexture;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		// Compute lighting
		float4 lighting = lit(dot(bumpNormal,(In.LightVector[i].xyz)),dot(bumpNormal, In.HalfEyeLightVector), SpecularExponent);

		float3 cloud = float3(1, 1, 1);
		if (i == 0)
		{
#if defined(_WW3D_) && !defined(_W3DVIEW_)
			cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
#endif

			if (numShadows >= 1)
			{
				lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo);
			}
		}

		cumulativeLighting += DirectionalLight[0].Color * cloud * (diffuse * lighting.y + SpecularColor * lighting.z);
	}
	
	color.xyz += (cumulativeLighting * .4) * (envcolor * 6 + .75);

	color.xyz += TimeGlowStrength * In.Color.w * tex2D( SAMPLER(TimeGlowTexture), texCoord0);

	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.ReflectVector_Fog.w);
	}
	
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}
	
	return color;
}

// ----------------------------------------------------------------------------
VSOutput_U VS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
	float4 Color : COLOR0,
	float2 TexCoord : TEXCOORD0)
{
	return VS_U( InSkin, Color, TexCoord, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 PS_Xenon( PSInput_U In ) : COLOR
{
	return PS_U( In, min( NumShadows, 1 ), (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR), Fog.IsEnabled );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (Ultra High)
// ----------------------------------------------------------------------------
#define VS_U_NumJointsPerVertex \
	compile VS_VERSION_ULTRAHIGH VS_U(0), \
	compile VS_VERSION_ULTRAHIGH VS_U(1)

DEFINE_ARRAY_MULTIPLIER( VS_U_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_U_Array[VS_U_Multiplier_Final] =
{
	VS_U_NumJointsPerVertex
};
#endif

#define PS_U_NumShadows(applyShroud, fogEnabled) \
	compile PS_VERSION_ULTRAHIGH PS_U(0, applyShroud, fogEnabled), \
	compile PS_VERSION_ULTRAHIGH PS_U(1, applyShroud, fogEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_ApplyShroud = 2 );

#define PS_U_ApplyShroud(fogEnabled) \
	PS_U_NumShadows(false, fogEnabled), \
	PS_U_NumShadows(true, fogEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_FogEnabled = PS_U_Multiplier_ApplyShroud * 2 );

#define PS_U_FogEnabled \
	PS_U_ApplyShroud(false), \
	PS_U_ApplyShroud(true)

DEFINE_ARRAY_MULTIPLIER( PS_U_Multiplier_Final = PS_U_Multiplier_FogEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_U_Array[PS_U_Multiplier_Final] =
{
	PS_U_FogEnabled
};
#endif

// ----------------------------------------------------------------------------
// Technique definition
technique Default_U
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Tiberium_U")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_U_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS( PS_U_Array,
			min(NumShadows, 1)
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_U_Multiplier_ApplyShroud
			+ Fog.IsEnabled * PS_U_Multiplier_FogEnabled,
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}

}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADERS: Default (High and Medium)
// ----------------------------------------------------------------------------

struct VSOutput_M
{
	float4 Position : POSITION;
    float4 Color : COLOR0;
	float4 ReflectVector_Fog : COLOR1;
	float4 TexCoord0_CloudTexCoord : TEXCOORD0;
	float3 LightVector : TEXCOORD1;
	float3 HalfEyeLightVector : TEXCOORD4;
	float3 WorldNormal : TEXCOORD5;
	float2 ShroudTexCoord : TEXCOORD6;
    float4 ShadowMapTexCoord : TEXCOORD7;
};

// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, 
	float4 Color : COLOR0,
	float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_M Out;

	float4 VertexColor = Color;
	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	Out.ReflectVector_Fog.xyz = worldEyeDir * 0.5 + 0.5; // To put into color output register, bring into range 0..1

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	// Compute lighting direction in tangent space
	Out.LightVector = mul(DirectionalLight[0].Direction, worldToTangentSpace);

	// Compute half angle direction between light and view direction in tangent space
	Out.HalfEyeLightVector = normalize(mul(DirectionalLight[0].Direction + worldEyeDir, worldToTangentSpace));

	float3 diffuseLight = 0;
	// Compute light 1 to n per vertex, light 0 will be done in pixel shader
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}

	Out.Color.xyz = AmbientLightColor + AmbientColor + diffuseLight * DiffuseColor;

	Out.Color = float4(Out.Color.xyz * VertexColor, VertexColor.w);
	
	Out.WorldNormal = worldNormal;

	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_CloudTexCoord.xy = TexCoord.xy;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	
	// Hack cloud tex coord into final components of light vectors
	float2 cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	Out.TexCoord0_CloudTexCoord.zw = cloudTexCoord.yx;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	
	// Calculate fog
	Out.ReflectVector_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);

	// Random glow for tiberium crystals
	float3 objectCenterWorld = GetFirstBonePosition(InSkin.BlendIndices, numJointsPerVertex);
	float randomOffset = GetRandomFloatValue(float2(0, 20), 3, VertexColor.w * 255 + (objectCenterWorld.x + objectCenterWorld.y) * 100);
	float speed = GetRandomFloatValue(TimeGlowSpeedRange, 7, VertexColor.w * 300 + (objectCenterWorld.x + objectCenterWorld.y) * 30);
	float strength = saturate(sin(Time * speed + randomOffset) * 0.5 - 0.5 + TimeGlowActiveRatio) / max(TimeGlowActiveRatio, 0.001);
	Out.Color.w = strength * strength;

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_M(VSOutput_M In, uniform int numShadows, uniform bool applyShroud, uniform bool fogEnabled) : COLOR
{
	float2 texCoord0 = In.TexCoord0_CloudTexCoord.xy;

	float2 texCoordNorm = In.TexCoord0_CloudTexCoord.xy * TexCoordTransform_Normal;
	float2 texCoordSpec = In.TexCoord0_CloudTexCoord.xy * TexCoordTransform_Spec;
	
	float2 cloudTexCoord = In.TexCoord0_CloudTexCoord.wz;
	
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseMap), texCoord0);
	float3 diffuse = baseTexture.xyz * DiffuseColor;

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoordNorm) * 2.0 - 1.0;

	float3 VertexColor = In.Color.xyz;	

	
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
 	
    //envmap calculations
    float3 EnvBumpScale = 0.6f;   
	half3 Nn = normalize(In.WorldNormal) + (bumpNormal * EnvBumpScale);
    half3 Vn = normalize(In.ReflectVector_Fog.xyz - float3(0.5, 0.5, 0.5)); // Unpack from range [0..1] to [-1..1] and normalize
	half3 reflVect = -reflect(Vn,Nn);
	float3 envcolor = EnvMult * texCUBE( SAMPLER(EnvMap),reflVect).xyz;
	
	//setup specmap passes
	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoordSpec);
	float specularStrength = specTexture.x;  // Specular lighting mask
	float reflectionStrength = specTexture.y; // Reflection/env map mask

	envcolor = (envcolor * reflectionStrength * SpecularColor);  // this uses the reflection mask

	SpecularColor = SpecMult * SpecularColor * specularStrength;
	
	float3 cumulativeLighting = 0;
	float4 color = In.Color * baseTexture;

	// Compute lighting
	float4 lighting = lit(dot(bumpNormal,(In.LightVector)),dot(bumpNormal, In.HalfEyeLightVector), SpecularExponent);

	float3 cloud = float3(1, 1, 1);
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
#endif

	if (numShadows >= 1)
	{
		lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo);
	}

	lighting.yz *= cloud.x;
	lighting.yz = max(lighting.yz, 0.05);

	cumulativeLighting += DirectionalLight[0].Color * (diffuse * lighting.y + SpecularColor * lighting.z);

	color.xyz += (cumulativeLighting * .4) * (envcolor * 6 + .75);

	color.xyz += TimeGlowStrength * In.Color.w * tex2D( SAMPLER(TimeGlowTexture), texCoord0);

	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.ReflectVector_Fog.w);
	}
	
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (High and Medium)
// ----------------------------------------------------------------------------
#define VS_M_NumJointsPerVertex \
	compile VS_VERSION_HIGH VS_M(0), \
	compile VS_VERSION_HIGH VS_M(1)

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};
#endif

#define PS_M_NumShadows(applyShroud, fogEnabled) \
	compile PS_VERSION_HIGH PS_M(0, applyShroud, fogEnabled), \
	compile PS_VERSION_HIGH PS_M(1, applyShroud, fogEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_ApplyShroud = 2 );

#define PS_M_ApplyShroud(fogEnabled) \
	PS_M_NumShadows(false, fogEnabled), \
	PS_M_NumShadows(true, fogEnabled)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_FogEnabled = PS_M_Multiplier_ApplyShroud * 2 );

#define PS_M_FogEnabled \
	PS_M_ApplyShroud(false), \
	PS_M_ApplyShroud(true)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_FogEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_FogEnabled
};
#endif

// ----------------------------------------------------------------------------
// Technique definition
technique _Default_M // Since there is no High technique, this one will be used on High and Medium
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Tiberium_M")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
			min(NumJointsPerVertex, 1),
			NO_ARRAY_ALTERNATIVE
		);
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			min(NumShadows, 1)
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_M_Multiplier_ApplyShroud
			+ Fog.IsEnabled * PS_M_Multiplier_FogEnabled,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}

}



// ----------------------------------------------------------------------------
// SHADERS: Default (Low)
// ----------------------------------------------------------------------------

struct VSOutput_L
{
	float4 Position : POSITION;
    float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float2 TimeGlowTexCoord : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, 
	float4 Color : COLOR0,
	float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_L Out;

	float4 VertexColor = Color;
	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame_L(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	float3 diffuseLight = 0;
	// Compute directional lights
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 lightColor = DirectionalLight[i].Color;
		if (i == 0)
		{
			lightColor *= NoCloudMultiplier;
		}
		
		diffuseLight += lightColor * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}

	Out.Color.xyz = AmbientLightColor + AmbientColor + diffuseLight * DiffuseColor;

	Out.Color = float4(Out.Color.xyz * VertexColor, VertexColor.w);
	
	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0 = TexCoord.xy;
	Out.TimeGlowTexCoord = TexCoord.xy;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_L In, uniform bool applyShroud) : COLOR
{
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseMap), In.TexCoord0);

	float4 color = In.Color * baseTexture;

	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (Low)
// ----------------------------------------------------------------------------
#define VS_L_NumJointsPerVertex \
	compile VS_VERSION_LOW VS_L(0), \
	compile VS_VERSION_LOW VS_L(1)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};
#endif


DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_ApplyShroud = 1 );

#define PS_L_ApplyShroud \
	compile PS_VERSION_LOW PS_L(false), \
	compile PS_VERSION_LOW PS_L(true)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_ApplyShroud * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_ApplyShroud
};
#endif

// ----------------------------------------------------------------------------
// Technique definition
technique _Default_L // Since there is no High technique, this one will be used on High and Medium
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Tiberium_L")
	>
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS( VS_L_Array,
			min(NumJointsPerVertex, 1),
			NO_ARRAY_ALTERNATIVE
		);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS( PS_L_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_L_Multiplier_ApplyShroud,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}

}



#endif // ENABLE_LOD


// ----------------------------------------------------------------------------
// SHADER: CreateShadowMap
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Depth : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
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
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));
	
	Out.Depth = Out.Position.z / Out.Position.w;
	
	return Out;
}

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon( VSInputSkinningOneBoneTangentFrame InSkin )
{
	return CreateShadowMapVS( InSkin, min( NumJointsPerVertex, 1 ) );
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	return In.Depth;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ----------------------------------------------------------------------------
#define VSCreateShadowMap_NumJointsPerVertex \
	compile VS_VERSION_LOW CreateShadowMapVS(0), \
	compile VS_VERSION_LOW CreateShadowMapVS(1)

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif

// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("Tiberium_CreateShadowMap")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min( NumJointsPerVertex, 1 ),
			compile VS_VERSION CreateShadowMapVS_Xenon()
		);
		
		PixelShader = compile PS_VERSION_HIGH CreateShadowMapPS();

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