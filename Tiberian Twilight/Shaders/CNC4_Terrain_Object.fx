//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for terrain objects. These are objects that need to use similar shading as terrain so that they blend correctly with it.
// Ex. Cliff walls.
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SSAO 1	// enable SSAO
#define SUPPORT_SPECMAP 1

#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "ShadowMap.fxh"
#include "MacroTexture.fxh"
#include "DeferredLighting.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);

int MaxLocalLights = 8;
int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
string RenderBin = "TerrainLikeGroundObject";
> = 0;

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

#if defined(_3DSMAX_)

#define DECLARE_MAPPING_TEXCOORD(texcoordIndex) \
	int _3DSTexcoordMapping##texcoordIndex : Texcoord \
	< \
	int Texcoord = texcoordIndex; \
	int MapChannel = 1 + texcoordIndex; \
	string UIWidget = "None"; \
	>;

#define DECLARE_VERTEXCOLOR_INPUT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
	float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex, \
	float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex

#define DECLARE_VERTEXCOLOR_INPUT_STRUCT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
	float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex; \
	float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex
#endif

#endif


DECLARE_MAPPING_TEXCOORD(0)
DECLARE_MAPPING_VERTEXCOLOR(1, 2)

#define EXPRESSION_EVALUATOR_NAME "Objects"

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Cloud layer
// ----------------------------------------------------------------------------
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

// Same as the defaults in objects.fxh. They are just hard coded here since it looks good with the terrain.
static const float3 AmbientColor = float3(1.0, 1.0, 1.0);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float HDRColorRange = 2.0f;
static const float3 SpecularColor = float3(0.5, 0.5, 0.5);
static const float SpecularExponent = 40;
static const float BumpScale = .75;
static const float TerrainTopViewColorRange = 4.0f;


// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
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

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

float3 TintColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.TintColor";
> = float3(1, 1, 1);
#endif // #if !defined(USE_INDIRECT_CONSTANT)

// ----------------------------------------------------------------------------
// Transformations (world transformations are in skinning header)
// ----------------------------------------------------------------------------
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
	return EyePosition;
}
#else // #if defined(_WW3D_)
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
	return ViewI[3];
}
#endif // #if defined(_WW3D_)

// Time (ie. material is animated)
float Time : Time;


// ----------------------------------------------------------------------------
// !!!IMPORTANT!!!
//
// These shaders are specifically for the game because the game renderer uses
// deferred lighting.  There is a special shader for Max at the end of the file
//
// !!ANY CHANGES MADE TO THE GAME SHADER MUST BE REFLECTED IN THE MAX SHADERS!!
//
// ----------------------------------------------------------------------------
#if !defined(_3DSMAX_)


// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position					: POSITION;
	float4 TexCoord0_MacroTexCoord	: TEXCOORD0;
	float4 Color					: COLOR0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
				float2 TexCoord0 : TEXCOORD0,
				DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2))
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	Out.Color = float4(VertexColor.xyz, VertexColor.w * OpacityOverride); 

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_MacroTexCoord.xy = TexCoord0.xy;
	
	// calculate the macro texcoord
	Out.TexCoord0_MacroTexCoord.zw = CalculateMacroTexCoord(worldPosition);

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float2 texCoord0 = In.TexCoord0_MacroTexCoord.xy;
	float2 macroTexCoord = In.TexCoord0_MacroTexCoord.zw;
	float4 baseTextureValue = tex2D(SAMPLER(DiffuseTexture), texCoord0);

	baseTextureValue.xyz = GammaToLinear(baseTextureValue.xyz);

	// We have to calculate this in the pixel shader since some of the terrain objects have big triangles and won't needs perspective correction
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 worldPosition = ComputeWorldPosition(screenTexCoord);
	float2 ScorchMarkTexCoord = CalcTerrainTopViewTexCoord(worldPosition.xy);

	float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
            //NOTE - MD applying 4x scaling factor so deploy zone can bloom. 
            //     - need to reduce color by 0.25 in scorchmark shader
	baseTextureValue.xyz = baseTextureValue.xyz * (1.0f - scorchMark.w) + scorchMark.xyz * TerrainTopViewColorRange;

	float3 diffuseLight = SampleDiffuseLight(screenTexCoord) + AmbientLightColor * AmbientColor;
	float3 specularLight = SampleSpecularLight(screenTexCoord);
	
	float3 baseColor = baseTextureValue * DiffuseColor.xyz * In.Color.xyz;
	float opacity = baseTextureValue.w * In.Color.w;
	
	// Add normal mapping lighting with main light source	
	float4 normalmap = tex2D(SAMPLER(NormalMap), texCoord0);

	// We use the alpha channel of the Normal Map for the specular highlights
	float specularIntensity = normalmap.w;

	float3 color = (diffuseLight * baseColor) + (specularLight * SpecularColor * specularIntensity);

#if SUPPORT_SSAO
	color *= ComputeSSAO(vPos);
#endif

	// Apply macro
	float3 macro = GammaToLinear(tex2D( SAMPLER(MacroSampler), macroTexCoord).xyz);
	color *= macro;

	return CorrectForFrameBufferGamma(float4(color, opacity));
}



// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
{
	return PS_H( In, HasShadow, vPos );
}


// ----------------------------------------------------------------------------
// Arrays: Default_H
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_NumShadows = 1 );

#define PS_H_NumShadows \
	compile PS_3_0 PS_H(0), \
	compile PS_3_0 PS_H(1)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_H_Array[PS_H_Multiplier_Final] =
{
	PS_H_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_H();

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: DEFAULT (Medium)
// ----------------------------------------------------------------------------
struct VSOutput_M 
{
	float4 Position : POSITION;
	float4 TexCoord0_MacroTexCoord : TEXCOORD0;
	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD1;
	float4 ShadowMapTexCoord : TEXCOORD2;
	float4 Color : COLOR;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, 
	float2 TexCoord0 : TEXCOORD0,
	DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2))
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);

	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_M Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, the first directional light will be done in pixel shader
	float3 diffuseLight = 0;
	
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}

	Out.Color.xyz += diffuseLight * DiffuseColor;

	Out.Color *= VertexColor;

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_MacroTexCoord.xy = TexCoord0.xy;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);
	Out.ShroudTexCoord_CloudTexCoord.xy = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
	Out.TexCoord0_MacroTexCoord.zw = CalculateMacroTexCoord(worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------

float4 PS_M(VSOutput_M In, uniform bool hasShadow, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float2 texCoord0 = In.TexCoord0_MacroTexCoord.xy;
	float4 baseTextureValue = tex2D( SAMPLER(DiffuseTexture), texCoord0);


	// We have to calculate this in the pixel shader since some of the terrain objects have big triangles and won't needs perspective correction
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 worldPosition = ComputeWorldPosition(screenTexCoord);
	float2 ScorchMarkTexCoord = CalcTerrainTopViewTexCoord(worldPosition.xy);

	float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
            //NOTE - MD applying 4x scaling factor so deploy zone can bloom. 
            //     - need to reduce color by 0.25 in scorchmark shader
	baseTextureValue.xyz = baseTextureValue.xyz * (1.0f - scorchMark.w) + scorchMark.xyz * TerrainTopViewColorRange;





	// Get bump map normal
	// Scale normal to increase/decrease bump effect
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);

	float2 CloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;
	float3 cloud = GammaToLinear(tex2D(SAMPLER(CloudTexture), CloudTexCoord).xyz);
	float3 mainLight = DirectionalLight_0_Color.xyz * max(0, dot(bumpNormal, DirectionalLight_0_Direction.xyz));
	mainLight *= cloud;

	if (hasShadow)
	{
		mainLight *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_DEFAULT );
	}

	float3 color = (In.Color.xyz + mainLight) * baseTextureValue.xyz;

	// Apply reflection or macro
	float2 MacroTexCoord = In.TexCoord0_MacroTexCoord.zw;
	float4 macro = tex2D( SAMPLER(MacroSampler), MacroTexCoord);

	// Apply macro
	color *= macro;

	// Apply shroud
	float2 shroudTexCoord = In.ShroudTexCoord_CloudTexCoord.xy;
	float shroud = tex2D( SAMPLER(ShroudTexture), shroudTexCoord).x;
	color *= shroud;

	// Calculate opacity
	float opacity = In.Color.w * baseTextureValue.w;

	return float4(color, opacity);
}

// We only want to do this for the really expensive part. The rest of the shader can be normal.
#undef float4
#undef float3
#undef float2
#undef float


// ----------------------------------------------------------------------------
// Arrays: Default_M
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_HasShadow = 1 );

#define PS_M_HasShadow \
	compile PS_3_0 PS_M(false), \
	compile PS_3_0 PS_M(true)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_HasShadow * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_HasShadow
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default_M
// ----------------------------------------------------------------------------
technique Default_M
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_M();

		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			HasShadow * PS_M_Multiplier_HasShadow,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}



// ----------------------------------------------------------------------------
// SHADER: Low
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
	float4 TexCoord0_ShroudTexCoord : TEXCOORD0;
	float4 Color : TEXCOORD1;
	float3 WorldPosition : TEXCOORD2;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, 
				float2 TexCoord0 : TEXCOORD0,
				DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2))
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_L Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

 	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, others will be done in pixel shader
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

	Out.Color.xyz += diffuseLight * DiffuseColor;

	Out.Color *= VertexColor;
	Out.Color.rgb *= CalcMapBorderFactor(CalcMapBorderCoefficientX2(), CalcMapBorderCoefficientX(), worldPosition);

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_ShroudTexCoord.xy = TexCoord0.xy;
	Out.TexCoord0_ShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, worldPosition);

	Out.WorldPosition = worldPosition;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------

// This will save us .5ms on the GPU on a 6800 card. Worth it and there is no visual difference.
#define float4 half4
#define float3 half3
#define float2 half2
#define float  half

float4 PS_L(VSOutput_L In) COLORTARGET
{
	// Get diffuse color
	float2 texCoord0 = In.TexCoord0_ShroudTexCoord.xy;
	float4 baseTextureValue = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	float4 color = In.Color * baseTextureValue;

	// This might have a little swimming for large terrain object due to not being perspective correct, but it's a lot cheaper, we could move the calculation to the pixel shader if needed
	float2 ScorchMarkTexCoord =	CalcTerrainTopViewTexCoord(In.WorldPosition.xy);
	float4 scorchMark = IsTerrainTopViewEnabled * tex2D( SAMPLER(TerrainTopViewTexture), ScorchMarkTexCoord);
	color.xyz = color.xyz * (1.0f - scorchMark.w) + scorchMark.xyz;

	// Apply shroud
	float2 shroudTexCoord = In.TexCoord0_ShroudTexCoord.zw;
	float shroud = tex2D( SAMPLER(ShroudTexture), shroudTexCoord).x;
	color.xyz *= shroud;

	return color;
}

// ----------------------------------------------------------------------------
// Technique: Default_L
// ----------------------------------------------------------------------------
technique Default_L
{
	pass p0
	{
		VertexShader = compile VS_2_0 VS_L();
		PixelShader = compile PS_2_0 PS_L();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
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
	float3 PositionZW_Opacity : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
										   float2 TexCoord0 : TEXCOORD0,
										   float4 VertexColor: COLOR0)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	// Transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.PositionZW_Opacity.xy = Out.Position.zw;
	Out.PositionZW_Opacity.z  = saturate(OpacityOverride * VertexColor.w);

	Out.TexCoord0 = TexCoord0;	

	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	float Opacity = In.PositionZW_Opacity.z;
	float opacity = tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;
	opacity *= Opacity;

	// Simulate alpha testing for floating point render target
	clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));

	float Depth = In.PositionZW_Opacity.x / In.PositionZW_Opacity.y;
	return Depth;
}

// ----------------------------------------------------------------------------
// Technique _CreateShadowMap
// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass p0
	{
		VertexShader = compile VS_2_0 CreateShadowMapVS();
		PixelShader = compile PS_2_0 CreateShadowMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}


///---///

// ----------------------------------------------------------------------------
// SHADER: CreateDepthNormalMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateDepthNormalMap
{
	float4 Position 				: POSITION;
	float3 TexCoord0_Opacity 		: TEXCOORD0;
	float3 TangentToViewSpace0 		: TEXCOORD1_CENTROID;
	float3 TangentToViewSpace1 		: TEXCOORD2_CENTROID;
	float3 TangentToViewSpace2 		: TEXCOORD3_CENTROID;
	float4 WorldPosition			: TEXCOORD5;
};

// ----------------------------------------------------------------------------
VSOutput_CreateDepthNormalMap CreateDepthNormalMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
										   float2 TexCoord0 : TEXCOORD0,
										   float4 VertexColor: COLOR0)
{
	VSOutput_CreateDepthNormalMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	// Transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.WorldPosition			= Out.Position;
	Out.TexCoord0_Opacity.z 	= OpacityOverride * VertexColor.w;
	Out.TexCoord0_Opacity.xy 	= TexCoord0;
	
	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

	return Out;
}

struct PSOutput_CreateDepthNormalMap
{
	float4 NormalSpec 	: COLOR0;

#if !defined(EA_PLATFORM_XENON)
	float4 Depth		: COLOR1;
#endif
};


// ----------------------------------------------------------------------------
PSOutput_CreateDepthNormalMap CreateDepthNormalMapPS(VSOutput_CreateDepthNormalMap In) : COLOR
{
	float opacity = tex2D(SAMPLER(DiffuseTexture), In.TexCoord0_Opacity.xy).w;
	opacity *= In.TexCoord0_Opacity.z;

	// Simulate alpha testing for floating point render target
	clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	
	// Add normal mapping lighting with main light source	
	float4 normalmap = tex2D(SAMPLER(NormalMap), In.TexCoord0_Opacity.xy);
	float3 normal = normalmap * 2 - 1;
	normal.xy *= BumpScale;
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	normal = mul(normal, TangentToViewSpace);
	normal = normalize(normal);
	
	PSOutput_CreateDepthNormalMap Out;
#if !defined(EA_PLATFORM_XENON)
	Out.Depth = In.WorldPosition.z/In.WorldPosition.w;
#endif
	Out.NormalSpec = float4((normal+1.0f)*0.5f, saturate(SpecularExponent/255.0f));

	return Out;
}

// ----------------------------------------------------------------------------
// Technique _CreateDepthNormalMap
// ----------------------------------------------------------------------------
technique _CreateDepthNormalMap
{
	pass p0
	{
		VertexShader = compile VS_2_0 CreateDepthNormalMapVS();
		PixelShader = compile PS_2_0 CreateDepthNormalMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}

#else // !defined(_3DSMAX_)

// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float3 TangentToViewSpace0 : TEXCOORD1_CENTROID;
	float3 TangentToViewSpace1 : TEXCOORD2_CENTROID;
	float3 TangentToViewSpace2 : TEXCOORD3_CENTROID;
	float3 WorldPosition : TEXCOORD4;
	float4 ShadowMapTexCoord : TEXCOORD5;
	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD6;
	float3 MainLightHalfEyeVector : TEXCOORD7;
	float4 Color : COLOR0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
				float2 TexCoord0 : TEXCOORD0,
				DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2))
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, 0,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 0;
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}

	Out.Color.xyz += diffuseLight * DiffuseColor.xyz;

	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	Out.Color *= VertexColor;

	Out.WorldPosition = worldPosition;

	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	Out.MainLightHalfEyeVector = normalize(DirectionalLight_0_Direction.xyz + worldEyeDir);

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0 = TexCoord0.xy;

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_SOFT);
	Out.ShroudTexCoord_CloudTexCoord.xy = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float2 texCoord0 = In.TexCoord0.xy;
	float4 baseTextureValue = tex2D(SAMPLER(DiffuseTexture), texCoord0);
	
	float2 shroudTexCoord = In.ShroudTexCoord_CloudTexCoord.xy;
	float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;

	// Note: we need to divide by 2 in VS and restore it in PS since COLOR register is clamped to 1
	float3 baseColor = GammaToLinear(baseTextureValue.xyz);
	float3 color = In.Color.xyz;
	float opacity = baseTextureValue.w * In.Color.w;
	

	// Add normal mapping lighting with main light source	
	float4 normalmap = tex2D(SAMPLER(NormalMap), texCoord0);
	float3 normal = normalmap * 2 - 1;
	normal.xy *= BumpScale;
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	normal = mul(normal, TangentToViewSpace);
	normal = normalize(normal);

	// We use the alpha channel of the Normal Map for the specular highlights
	float specularIntensity = normalmap.w;

	// Note: We need to divide by 2 in VS and restore it in PS since COLOR register is clamped to 1
	color *= baseColor * 2;

	float3 mainLightVector = DirectionalLight_0_Direction.xyz;
	float3 mainLightColor = DirectionalLight_0_Color.rgb;
	float4 lighting = lit(dot(normal, mainLightVector.xyz), dot(normal, In.MainLightHalfEyeVector), SpecularExponent);

	if (hasShadow)
	{
		lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_SOFT );
	}

	float3 cloud = GammaToLinear(tex2D( SAMPLER(CloudTexture), cloudTexCoord).xyz);
	color += mainLightColor * cloud.x * (lighting.y * baseColor + lighting.z * SpecularColor * specularIntensity);

#if SUPPORT_SSAO
	color *= ComputeSSAO(vPos);
#endif

	// Apply macro
	float2 MacroTexCoord = CalculateMacroTexCoord(In.WorldPosition.xyz);
	float3 macro = GammaToLinear(tex2D( SAMPLER(MacroSampler), MacroTexCoord).xyz);
	color *= macro;

	// Apply shroud
	float shroud = tex2D(SAMPLER(ShroudTexture), shroudTexCoord).x;
	color *= shroud;

	return CorrectForFrameBufferGamma(float4(color, opacity));
}

// ----------------------------------------------------------------------------
// Arrays: Default_H
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_NumShadows = 1 );

#define PS_H_NumShadows \
	compile PS_3_0 PS_H(0), \
	compile PS_3_0 PS_H(1)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_H_Array[PS_H_Multiplier_Final] =
{
	PS_H_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_H();

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows,
			NULL );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#endif