//////////////////////////////////////////////////////////////////////////////
// ©2007 Electronic Arts Inc
//
// FX Shader for Fields of Grass Red Alert 3
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "ShadowMap.fxh"
#include "DeferredLighting.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int MaxLocalLights = 3;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

#include "Skinning.fxh"


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

bool SwayEnable
<
	string UIName = "Sway Enable";
> = false;

// --------------------------------------------------
// Editable controls for the 1st Gerstner Wave
// --------------------------------------------------

float Amp1
<
	string UIName = "Sway Amplitude"; 
    string UIWidget = "Slider";
	float UIMax = 100.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = float (1.0);

float Freq1
<
	string UIName = "Sway Frequency"; 
    string UIWidget = "Slider";
	float UIMax = 100.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = float (10.0);

float Phase1
<
	string UIName = "Sway Phase"; 
    string UIWidget = "Slider";
	float UIMax = 100.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = float (1.0);

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

// ----------------------------------------------------------------------------
// WW3D defaults
// ----------------------------------------------------------------------------

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
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

float Time : Time;


// Helper function to modify the world position of a vertex with the tree swaying
void ApplyTreeSway(inout float3 worldPosition, float swayStrength)
{
	if (SwayEnable)
	{
		// add sin wave
		float Pos = frac(worldPosition.x);
		float Amp = Amp1;
		float Phase = Phase1 * Time;
		float Freq = Freq1;

		float vDisp = sin(Pos * Freq + Phase) * Amp;

		worldPosition += vDisp * swayStrength;
	}
}

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
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position		: POSITION;
	float2 TexCoord0	: TEXCOORD0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0,
		uniform int numJointsPerVertex)
{
	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

#if defined(_3DSMAX_)
	VertexColor.w = 1; //MAX cares nothing for vertex colors, allows basic displacement previewing in MAX
#endif

	ApplyTreeSway(worldPosition, VertexColor.w);
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// pass texture coordinates for fetching the diffuse and agitator maps
	Out.TexCoord0 = TexCoord;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool hasShadow, uniform bool applyGammaCorrection, uniform int shadowmapSampling, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), In.TexCoord0);
	if (applyGammaCorrection)
	{
		baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	}
	
	// sample the lighting
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 diffuseLight = SampleDiffuseLight(screenTexCoord);

	// combine the color
	float4 color = float4( (AmbientLightColor * AmbientColor) + (diffuseLight * DiffuseColor.xyz * baseTexture), baseTexture.w);

	return CorrectForFrameBufferGamma(color);
}

// ----------------------------------------------------------------------------
VSOutput VS_Xenon( VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0)
{
	return VS( InSkin, TexCoord, VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In, float2 vPos : PIXELLOC ) : COLOR
{
	return PS(In, HasShadow, true, SHADOWMAP_SAMPLE_DEFAULT, vPos);
}

// ----------------------------------------------------------------------------
// Arrays: Default
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#define VS_NumJointsPerVertex \
	compile VS_3_0 VS(0), \
	compile VS_3_0 VS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = 1 );

#define PS_NumShadows \
	compile PS_3_0 PS(0, true, SHADOWMAP_SAMPLE_SOFT), \
	compile PS_3_0 PS(1, true, SHADOWMAP_SAMPLE_SOFT)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon() );

		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			HasShadow * PS_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;

		AlphaBlendEnable = false;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position		: POSITION;
	float4 Color		: COLOR0;
	float2 TexCoord0	: TEXCOORD0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0,
		uniform int numJointsPerVertex)
{
	VSOutput_M Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

#if defined(_3DSMAX_)
	VertexColor.w = 1; //MAX cares nothing for vertex colors, allows basic displacement previewing in MAX
#endif

	ApplyTreeSway(worldPosition, VertexColor.w);

	float3 diffuseLight = 0;
	if (NumDirectionalLights > 0)
	{
		diffuseLight += DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, normalize(DirectionalLight_0_Direction.xyz)));
	}
	
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, normalize(DirectionalLight_1_Direction.xyz)));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, normalize(DirectionalLight_2_Direction.xyz)));
	}
	Out.Color = float4(diffuseLight, 1);
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// pass texture coordinates for fetching the diffuse and agitator maps
	Out.TexCoord0 = TexCoord;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS_M(VSOutput_M In, uniform bool hasShadow, uniform int shadowmapSampling, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), In.TexCoord0);

	// sample the lighting
	float3 diffuseLight = In.Color.xyz;

	// combine the color
	float4 color = float4( (AmbientLightColor * AmbientColor) + (diffuseLight * DiffuseColor.xyz * baseTexture), baseTexture.w);

	return CorrectForFrameBufferGamma(color);
}


// ----------------------------------------------------------------------------
// Arrays: Default (Medium LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );

#define VS_M_NumJointsPerVertex \
	compile VS_3_0 VS_M(0), \
	compile VS_3_0 VS_M(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_NumShadows = 1 );

#define PS_M_NumShadows \
	compile PS_3_0 PS_M(0, SHADOWMAP_SAMPLE_DEFAULT), \
	compile PS_3_0 PS_M(1, SHADOWMAP_SAMPLE_DEFAULT)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default (Medium LOD)
// ----------------------------------------------------------------------------
technique Default_M
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
			min(NumJointsPerVertex, 1), 
			NO_ARRAY_ALTERNATIVE);

		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			HasShadow * PS_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;

		AlphaBlendEnable = false;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

// ----------------------------------------------------------------------------
// Arrays: Default (Low LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );

#define VS_L_NumJointsPerVertex \
	compile VS_2_0 VS_M(0), \
	compile VS_2_0 VS_M(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_NumShadows = 1 );

#define PS_L_NumShadows \
	compile PS_2_0 PS_M(0, SHADOWMAP_SAMPLE_DEFAULT), \
	compile PS_2_0 PS_M(1, SHADOWMAP_SAMPLE_DEFAULT)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default (Low LOD)
// ----------------------------------------------------------------------------
technique Default_L
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
			min(NumJointsPerVertex, 1), 
			NO_ARRAY_ALTERNATIVE);

		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
			HasShadow * PS_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;

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
	float Depth : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord : TEXCOORD0,
	float4 VertexColor : COLOR0,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	ApplyTreeSway(worldPosition, VertexColor.w);

	// Transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.Depth = Out.Position.z / Out.Position.w;	
	Out.TexCoord0 = TexCoord;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	float opacity = OpacityOverride * tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;	
	// Simulate alpha testing for floating point render target
	clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	return In.Depth;
}

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord : TEXCOORD0,
	float4 VertexColor : COLOR0)
{
	return CreateShadowMapVS( InSkin, TexCoord, VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// Technique _CreateShadowMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 );

#define VSCreateShadowMap_NumJointsPerVertex \
	compile VS_2_0 CreateShadowMapVS(0), \
	compile VS_2_0 CreateShadowMapVS(1)

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
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateShadowMapVS_Xenon() );
			
		PixelShader = compile PS_2_0 CreateShadowMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}

// ----------------------------------------------------------------------------
// SHADER: CreateDepthNormalMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateDepthNormalMap
{
	float4 Position 		: POSITION;
	float3 TexCoord0_Depth 	: TEXCOORD0;
	float3 Normal 			: TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateDepthNormalMap CreateDepthNormalMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord : TEXCOORD0,
	float4 VertexColor : COLOR0,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateDepthNormalMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	ApplyTreeSway(worldPosition, VertexColor.w);

	// Transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.TexCoord0_Depth.z = Out.Position.z / Out.Position.w;	
	Out.TexCoord0_Depth.xy = TexCoord;
	Out.Normal = worldNormal;
	
	return Out;
}

// ---------------------------------------------------------------------------

struct PSOutput_CreateDepthNormalMap
{
	float4	NormalSpec	: COLOR0;

#if !defined(EA_PLATFORM_XENON)
	float4	Depth		: COLOR1;
#endif
};


// ----------------------------------------------------------------------------
PSOutput_CreateDepthNormalMap CreateDepthNormalMapPS(VSOutput_CreateDepthNormalMap In) : COLOR
{
	float opacity = OpacityOverride * tex2D(SAMPLER(DiffuseTexture), In.TexCoord0_Depth.xy).w;	
	// Simulate alpha testing for floating point render target
	clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	
	PSOutput_CreateDepthNormalMap Out;
	Out.NormalSpec = float4((In.Normal+1.0f)*0.5f, 128.0f/255.0f);
#if !defined(EA_PLATFORM_XENON)
	Out.Depth = In.TexCoord0_Depth.zzzz;
#endif
	
	return Out;
}

// ----------------------------------------------------------------------------
VSOutput_CreateDepthNormalMap CreateDepthNormalMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord : TEXCOORD0,
	float4 VertexColor : COLOR0)
{
	return CreateDepthNormalMapVS( InSkin, TexCoord, VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// Technique _CreateDepthNormalMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateDepthNormalMap_Multiplier_Final = 2 );

#define VSCreateDepthNormalMap_NumJointsPerVertex \
	compile VS_2_0 CreateDepthNormalMapVS(0), \
	compile VS_2_0 CreateDepthNormalMapVS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateDepthNormalMap_Array[VSCreateDepthNormalMap_Multiplier_Final] =
{
	VSCreateDepthNormalMap_NumJointsPerVertex
};
#endif

// ----------------------------------------------------------------------------
technique _CreateDepthNormalMap
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateDepthNormalMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateDepthNormalMapVS_Xenon() );
			
		PixelShader = compile PS_2_0 CreateDepthNormalMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}

#else // !defined(_3DSMAX_)

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float4 ShadowMapTexCoord : TEXCOORD2;
	float3 MainLightDiffuseColor : TEXCOORD3;
	float4 Color : COLOR0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0,
		uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

#if defined(_3DSMAX_)
	VertexColor.w = 1; //MAX cares nothing for vertex colors, allows basic displacement previewing in MAX
#endif

	ApplyTreeSway(worldPosition, VertexColor.w);
	
	// Compute half direction between view and light direction in tangent space
	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute all directional lights per vertex
	float3 diffuseLight = 0;
	diffuseLight = DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, DirectionalLight_0_Direction.xyz));
	Out.MainLightDiffuseColor = diffuseLight * DiffuseColor.xyz;

	diffuseLight = 0;
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}

	Out.Color.xyz += diffuseLight * DiffuseColor.xyz;

	Out.Color /= 2; // Prevent clamping in interpolator
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// pass texture coordinates for fetching the diffuse and agitator maps
	Out.TexCoord0 = TexCoord;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_SOFT);
	
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool hasShadow, uniform bool applyGammaCorrection, uniform int shadowmapSampling, float2 vPos : PIXELLOC) COLORTARGET
{
	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), In.TexCoord0);
	if (applyGammaCorrection)
	{
		baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	}

	float4 color = In.Color * 2;

	float shadowAmount = 1.0;
	if (hasShadow)
	{
		shadowAmount = shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, shadowmapSampling );
	}
	color.xyz += In.MainLightDiffuseColor * shadowAmount;

	color *= baseTexture;

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D(SAMPLER(ShroudTexture), In.ShroudTexCoord).x;
#endif

	return CorrectForFrameBufferGamma(color);
}

// ----------------------------------------------------------------------------
// Arrays: Default
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#define VS_NumJointsPerVertex \
	compile VS_3_0 VS(0), \
	compile VS_3_0 VS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = 1 );

#define PS_NumShadows \
	compile PS_3_0 PS(0, true, SHADOWMAP_SAMPLE_SOFT), \
	compile PS_3_0 PS(1, true, SHADOWMAP_SAMPLE_SOFT)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array,
			min(NumJointsPerVertex, 1), 
			NULL );

		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			HasShadow * PS_Multiplier_NumShadows,
			NULL );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = none;

		AlphaBlendEnable = false;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#endif // !defined(_3DSMAX_)