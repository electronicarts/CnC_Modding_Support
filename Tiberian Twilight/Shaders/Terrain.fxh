//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain FX Shader
//////////////////////////////////////////////////////////////////////////////

// techniques, these defines are mutually exclusive
// #define TERRAIN_TILE
// #define TERRAIN_CLIFF
// #define TERRAIN_ROAD
// #define TERRAIN_SCORCH

#ifndef TERRAIN_FXH
#define TERRAIN_FXH

#define SUPPORT_SSAO 1	// enable SSAO
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1

#include "Common.fxh"
#include "SSAO.fxh"
#include "Gamma.fxh"
#include "MacroTexture.fxh"
#include "DeferredLighting.fxh"

#if (defined(TERRAIN_TILE) && (defined(TERRAIN_CLIFF) || defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH))) || \
	(defined(TERRAIN_CLIFF) && (defined(TERRAIN_TILE) || defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH))) || \
	(defined(TERRAIN_ROAD) && (defined(TERRAIN_TILE) || defined(TERRAIN_CLIFF) || defined(TERRAIN_SCORCH))) || \
	(defined(TERRAIN_SCORCH) && (defined(TERRAIN_TILE) || defined(TERRAIN_ROAD) || defined(TERRAIN_CLIFF)))
#error "Only one technique may be specified."
#elif (!defined(TERRAIN_TILE) && !defined(TERRAIN_CLIFF) && !defined(TERRAIN_ROAD) && !defined(TERRAIN_SCORCH))
#error "At least one technique must be specified."
#endif

static const float SpecularExponent = 40;
#if defined(TERRAIN_ROAD)
	static const float BumpScale = .35;
#else // #if defined(TERRAIN_ROAD)
	static const float BumpScale = .75;
#endif // #if defined(TERRAIN_ROAD)
static const bool EnableNormalMap = true;
static const float HDRColorRange = 2.0f;
static const float3 SpecularColor = float3(0.5, 0.5, 0.5);

// ----------------------------------------------------------------------------
// Defines to make code easier to read
// ----------------------------------------------------------------------------
#define SCORCHMARK_TEXTURE_ENABLED true
#define SCORCHMARK_TEXTURE_DISABLED false
static const float TerrainTopViewColorRange = 4.0f;

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int MaxLocalLights = 6;
> = 0;

// ----------------------------------------------------------------------------
// Terrain specific textures
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( BaseSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;	
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerClamped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	MaxAnisotropy = 1;
    AddressU = Clamp;
    AddressV = Clamp;	
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	MaxAnisotropy = 1;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudSampler,
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
// Cloud textures
// ----------------------------------------------------------------------------
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


// ----------------------------------------------------------------------------
// ScorchMark Texture
// ----------------------------------------------------------------------------

// We need the top view pass in all LOD, see GameLOD.cpp for more info
static const bool IsTerrainTopViewEnabled = true;
//bool IsTerrainTopViewEnabled
//<
//	string UIWidget = "None";
//	string SasBindAddress = "WW3D.IsTerrainTopViewEnabled";
//> = false;

SAMPLER_2D_BEGIN( TerrainTopViewTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.TopViewTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Using Terrain Atlas for rendering
// ----------------------------------------------------------------------------

#if defined(EA_PLATFORM_WINDOWS)
bool IsTerrainAtlasEnabled
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.IsTerrainAtlasEnabled";
> = false;
#endif // #if defined(EA_PLATFORM_WINDOWS)

float2 TileOrigin
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.MapTileOrigin";
> = float2(0.0f, 0.0f);

// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
// Note (WSK) 2008/05/28 - leaving this here since if we move this up, the registers are shifted and 
//							some register seems to get stomped on if we don't define these here on Xenon.
#include "ShadowMap.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------

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

// Time (ie. material is animated)
float Time : Time;

// ---------------------------------------------------------------------------
struct VSOutputDefault
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float4 MacroTexCoord_ScorchMarkTexCoord : TEXCOORD2;
#if defined(TERRAIN_ROAD)
	float3 WorldPosition : TEXCOORD4;
#endif // #if defined(TERRAIN_ROAD)
};
	
// ---------------------------------------------------------------------------
VSOutputDefault VS_Default(
	float3 Position : POSITION, 
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
	
	ISOLATE Out.Position = mul(float4(Position, 1), ViewProjection);

	float3 worldPosition = Position;

	float3 diffuseColor = Color.xyz;
	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);
	Out.MacroTexCoord_ScorchMarkTexCoord.xy = MacroTexCoord;

	float2 ScorchMarkTexCoord = float2(0, 0);
	Out.MacroTexCoord_ScorchMarkTexCoord.zw = ScorchMarkTexCoord;
	
	return Out;
}


float4 PS_Default(VSOutputDefault In, uniform sampler2D baseSampler, uniform sampler2D normalSampler,
	uniform bool isTextureAtlasEnabled,	uniform bool isScorchMarkEnabled, float2 vPos : PIXELLOC ) COLORTARGET
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);
	float2 MacroTexCoord = In.MacroTexCoord_ScorchMarkTexCoord.xy;

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(isTextureAtlasEnabled)
    {
        float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
        float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

        baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }

	float3 baseColor = GammaToLinear(baseTextureValue.xyz) * In.Color.xyz;
	float opacity = In.Color.w;

#if defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)
	opacity *= baseTextureValue.w;
#endif // defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)

	// Note (wkan) - With scorchmark, we don't want the spec light on the scorchmark, since the normal pass are using the terrain normal
	float specFactor = 1.0f;
	if(isScorchMarkEnabled)
	{
#if defined(TERRAIN_ROAD)
		float2 ScorchMarkTexCoord = CalcTerrainTopViewTexCoord(In.WorldPosition.xy);
#else // #if defined(TERRAIN_ROAD)
		float2 ScorchMarkTexCoord = In.MacroTexCoord_ScorchMarkTexCoord.zw;
#endif // #if defined(TERRAIN_ROAD)
		float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
                //NOTE - MD applying 4x scaling factor so deploy zone can bloom. 
                //     - need to reduce color by 0.25 in scorchmark shader
		baseColor.xyz = baseColor.xyz * (1.0f - scorchMark.w) + scorchMark.xyz * TerrainTopViewColorRange;
		specFactor = 1.0f - scorchMark.w;
	}

	// Compute Deferred Lighting
	float specularIntensity;
#if defined(TERRAIN_SCORCH)
	specularIntensity = 0;
	// The scorch mark is moved to a seperate pass so we don't have to do the lighting here
	return float4(baseColor, opacity);
#elif defined(TERRAIN_ROAD)
	specularIntensity = tex2D(normalSampler, BaseTexCoord).w;
#elif defined(TERRAIN_TILE)
	specularIntensity = baseTextureValue.w;
#elif defined(TERRAIN_CLIFF)
	specularIntensity = tex2D(normalSampler, BaseTexCoord).z;
#endif
		
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 color = ((SampleDiffuseLight(screenTexCoord)+AmbientLightColor) * baseColor) + specFactor * (SampleSpecularLight(screenTexCoord) * SpecularColor * specularIntensity);

#if SUPPORT_SSAO
	color *= ComputeSSAO(vPos);
#endif

    // Apply macro
	float3 macro = GammaToLinear(tex2D( SAMPLER(MacroSampler), MacroTexCoord).xyz);
	color *= macro;

	return float4(color, opacity);
}

// LOD techniques follow
#if ENABLE_LOD

// ============================================================================
// Default technique, medium quality
// ============================================================================
// ---------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float4 MainLightContribution_Fog : COLOR1;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float4 CloudTexCoord_MacroTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD5;
#if defined(TERRAIN_ROAD)
	float3 WorldPosition : TEXCOORD4;
#else // #if defined(TERRAIN_ROAD)
	float2 ScorchMarkTexCoord : TEXCOORD4;
#endif // #if defined(TERRAIN_ROAD)
};
	
// ---------------------------------------------------------------------------
VSOutput_M VS_Default_M(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_M Out;
	
	Out.Position = mul(float4(Position, 1), ViewProjection);
	float3 worldPosition = Position;

	Out.MainLightContribution_Fog.w = CalculateFog(Fog, worldPosition, GetEyePosition());

	float3 worldNormal = Normal;
	
	float3 mainLight = DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, DirectionalLight_0_Direction.xyz));
	mainLight /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.
	Out.MainLightContribution_Fog.xyz = mainLight;

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;
	diffuseColor /= HDRColorRange; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);

    Out.CloudTexCoord_MacroTexCoord.xy = CloudTexCoord.xy;
    Out.CloudTexCoord_MacroTexCoord.zw = MacroTexCoord.yx;

#if defined(TERRAIN_ROAD)
	Out.WorldPosition = float3(0, 0, 0);
#else // #if defined(TERRAIN_ROAD)
	Out.ScorchMarkTexCoord.xy = float2(0, 0);
#endif // #if defined(TERRAIN_ROAD)
    
#if defined(TERRAIN_ROAD) || defined(TERRAIN_TILE)
	if(!isTextureAtlasEnabled)
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord_PerspectiveCorrect(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);
	}
	else
#endif
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);
	}

	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_Default_M(VSOutput_M In, uniform sampler2D baseSampler, uniform bool hasShadow,
	uniform bool isTextureAtlasEnabled,	uniform bool isScorchMarkEnabled, float2 vPos : PIXELLOC ) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

#if defined(TERRAIN_TILE)
    if(isTextureAtlasEnabled)
    {
		float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
		float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);
		
		baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }
#endif

	float3 baseColor = baseTextureValue.xyz;


	if(isScorchMarkEnabled)
	{
#if defined(TERRAIN_ROAD)
		float2 ScorchMarkTexCoord = CalcTerrainTopViewTexCoord(In.WorldPosition.xy);
#else // #if defined(TERRAIN_ROAD)
		float2 ScorchMarkTexCoord = In.ScorchMarkTexCoord.xy;
#endif // #if defined(TERRAIN_ROAD)
		float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
		baseColor.xyz = baseColor.xyz * (1.0f - scorchMark.w) + scorchMark.xyz * TerrainTopViewColorRange;
	}

#if defined(TERRAIN_SCORCH)
	return float4(baseColor, baseTextureValue.w);
#endif // #if defined(TERRAIN_SCORCH)

	float2 CloudTexCoord = In.CloudTexCoord_MacroTexCoord.xy;
	float3 cloud = GammaToLinear(tex2D(SAMPLER(CloudSampler), CloudTexCoord).xyz);
	float3 mainLight = In.MainLightContribution_Fog.xyz * cloud.x;

	if (hasShadow)
	{
#if defined(TERRAIN_ROAD) || defined(TERRAIN_TILE)
		if(!isTextureAtlasEnabled)
		{
			mainLight *= shadow_PerspectiveCorrect( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_DEFAULT );
		}
		else
#endif
		{
			mainLight *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_DEFAULT );
		}
	}

	float3 color = (In.Color.xyz + mainLight) * baseColor;
	color *= 2; // Overbrightening

    // Apply reflection or macro
	float2 MacroTexCoord = In.CloudTexCoord_MacroTexCoord.wz;
	float4 macro = tex2D( SAMPLER(MacroSampler), MacroTexCoord);

    // Apply macro
    color *= macro;

    // Apply fog
	color = lerp(Fog.Color, color, In.MainLightContribution_Fog.w);

	// Calculate opacity
	float opacity = In.Color.w;
#if defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)
	opacity *= baseTextureValue.w;
#endif

	return float4(color, opacity);
}

// ============================================================================
// Default technique, low quality
// ============================================================================
// ---------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float4 ShroudTexCoord_ScorchMarkTexCoord : TEXCOORD2;
	float4 Color : TEXCOORD3;
};
	
// ---------------------------------------------------------------------------
VSOutput_L VS_Default_L(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_L Out;
	
	Out.Position = mul(float4(Position, 1), ViewProjection);
	float3 worldPosition = Position;
	float3 worldNormal = Normal;

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	if (NumDirectionalLights > 0)
	{
		diffuseLight += DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, DirectionalLight_0_Direction.xyz));
	}
	
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_ScorchMarkTexCoord.xy = ShroudTexCoord;
	Out.ShroudTexCoord_ScorchMarkTexCoord.zw = float2(0, 0);

	Out.Color.xyz *= CalcMapBorderFactor(CalcMapBorderCoefficientX2(), CalcMapBorderCoefficientX(), worldPosition);

	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_Default_L(VSOutput_L In, uniform sampler2D baseSampler, uniform bool isTextureAtlasEnabled, uniform bool isScorchMarkEnabled) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

#if defined(TERRAIN_TILE)
    if(isTextureAtlasEnabled)
    {
		float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
		float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

		// Doing first and second blend
	    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);
		
		// This double lerp is expensive on low lod.
		baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }
#endif

	float4 color = In.Color;

#if defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)
	color *= baseTextureValue;
#else
	color.xyz *= baseTextureValue.xyz;
#endif

	if(isScorchMarkEnabled)
	{
		float2 ScorchMarkTexCoord = In.ShroudTexCoord_ScorchMarkTexCoord.zw;
		float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
		color.xyz = color.xyz * (1.0f - scorchMark.w) + scorchMark.xyz;
	}

    // Apply shroud
    float2 shroudTexCoord = In.ShroudTexCoord_ScorchMarkTexCoord.xy;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color.xyz *= shroud;

	return color;
}







#endif // #if ENABLE_LOD


// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
#if defined(TERRAIN_ROAD)
	float4 NDCPosition : TEXCOORD0;
#else // #if defined(TERRAIN_ROAD)
	float Depth : TEXCOORD0;
#endif // #if defined(TERRAIN_ROAD)
};

// ---------------------------------------------------------------------------
VSOutput_CreateShadowMap VS_CreateShadowMap(float3 Position : POSITION)
{
	VSOutput_CreateShadowMap Out;
	
	Out.Position = mul(float4(Position, 1), ViewProjection);
#if defined(TERRAIN_ROAD)
	Out.NDCPosition = Out.Position;
#else // #if defined(TERRAIN_ROAD)
	Out.Depth = Out.Position.z / Out.Position.w;
#endif // #if defined(TERRAIN_ROAD)
	
	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_CreateShadowMap(VSOutput_CreateShadowMap In) : COLOR
{
#if defined(TERRAIN_ROAD)
	return In.NDCPosition.z / In.NDCPosition.w;
#else // #if defined(TERRAIN_ROAD)
	return In.Depth;
#endif // #if defined(TERRAIN_ROAD)
}

#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
VSOutput_CreateShadowMap VS_CreateShadowMapVFetch(int Index: INDEX);
#endif

// ---------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ---------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_2_0 VS_CreateShadowMapVFetch();
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_2_0 VS_CreateShadowMap();
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		PixelShader = compile PS_2_0 PS_CreateShadowMap();
	
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}


// ---------------------------------------------------------------------------
// TECHNIQUE: CreateDepthMap
// ---------------------------------------------------------------------------
technique _CreateDepthMap
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_2_0 VS_CreateShadowMapVFetch();
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_2_0 VS_CreateShadowMap();
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)

#if defined(EA_PLATFORM_XENON)
		PixelShader = NULL;
#else
		PixelShader = compile PS_2_0 PS_CreateShadowMap();
#endif

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;
		
	}
}

// ---------------------------------------------------------------------------

struct VSOutput_CreateDepthNormalMap
{
	float4 Position : POSITION;

	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
	
	float3 Normal	: NORMAL;
	float3 Binormal : BINORMAL;
	float3 Tangent  : TANGENT;
	
#if defined(TERRAIN_TILE)
	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
#endif

#if defined(TERRAIN_ROAD)
	float4 NDCPosition : TEXCOORD2;
#else // #if defined(TERRAIN_ROAD)
#if !defined(EA_PLATFORM_XENON)
	float Depth : TEXCOORD2;
#endif
#endif // #if defined(TERRAIN_ROAD)

};

// ---------------------------------------------------------------------------

struct PSOutput_CreateDepthNormalMap
{
	float4	NormalSpec	: COLOR0;

#if !defined(EA_PLATFORM_XENON)
	float4	Depth		: COLOR1;
#endif
};

// ---------------------------------------------------------------------------

PSOutput_CreateDepthNormalMap PS_CreateDepthNormalMap(VSOutput_CreateDepthNormalMap In) : COLOR
{
	float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	
	// Add normal mapping lighting with main light source
	float3 normal;
	float specularIntensity;
	
#if defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)
	float4 normal_specular;
	
#if defined(TERRAIN_ROAD)
	normal_specular = tex2D(SAMPLER(NormalSamplerWrapped), BaseTexCoord);
#elif defined(TERRAIN_SCORCH)
	normal_specular = tex2D(SAMPLER(NormalSamplerClamped), BaseTexCoord);
#endif
	
	normal = normal_specular.xyz * 2 - 1;

#else // defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)
	float3 normal_specular = tex2D(SAMPLER(NormalSamplerWrapped), BaseTexCoord).xyz;

#if defined(TERRAIN_TILE)
	// Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);
    
    float3 normal_specular1 = tex2D(SAMPLER(NormalSamplerClamped), In.BlendTex1Coord_BlendTex2Coord.xy).xyz;
    float3 normal_specular2 = tex2D(SAMPLER(NormalSamplerClamped), In.BlendTex1Coord_BlendTex2Coord.wz).xyz;

    normal = lerp(lerp(normal_specular, normal_specular1, blendWeight[0]), normal_specular2, blendWeight[1]) * 2 - 1;

#else // defined(TERRAIN_TILE)
	
	// CLIFF
	normal.xy = normal_specular.xy * 2 - 1;
	normal.z = sqrt(1 - normal.x * normal.x - normal.y * normal.y);

#endif
#endif // defined(TERRAIN_ROAD) || defined(TERRAIN_SCORCH)

	normal.xy *= BumpScale;
	
	// Build 3x3 tranform from object to tangent space
 	normal.xyz = mul(normal.xyz, float3x3(-In.Binormal, -In.Tangent, In.Normal));
	
	normal = normalize(normal);
	
	PSOutput_CreateDepthNormalMap Out;
	
	Out.NormalSpec = float4((normal+1.0f)*0.5f, saturate(SpecularExponent/255.0f));
	
#if defined(TERRAIN_ROAD)
	Out.Depth = In.NDCPosition.z / In.NDCPosition.w;
#else // #if defined(TERRAIN_ROAD)
#if !defined(EA_PLATFORM_XENON)
	Out.Depth = In.Depth;
#endif
#endif // #if defined(TERRAIN_ROAD)
	
	return Out;
}

#endif // TERRAIN_FXH