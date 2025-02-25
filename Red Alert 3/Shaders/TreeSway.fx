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
#define MaxNumPointLights 3

#include "Common.fxh"
#include "Gamma.fxh"
#include "ShadowMap.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int MaxLocalLights = MaxNumPointLights;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendrickss : had to pull these in here for MAX to compile
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
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

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
		float2 Pos = frac(worldPosition.xy);
		float Amp = Amp1;
		float Phase = Phase1 * Time;
		float Freq = Freq1;

		float vDisp = sin(Pos * Freq + Phase) * Amp;

		worldPosition += vDisp * swayStrength;
	}
}

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
	float Fog : COLOR1;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0,
		uniform int numJointsPerVertex,
		uniform bool usePointLights)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

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
	diffuseLight = DirectionalLight[0].Color * max(0, dot(worldNormal, DirectionalLight[0].Direction));
	Out.MainLightDiffuseColor = diffuseLight * DiffuseColor;

	diffuseLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	// Compute point lights
	if (usePointLights)
	{
		for (int i = 0; i < NumPointLights; i++)
		{
			diffuseLight += CalculatePointLightDiffuse(PointLight[i], worldPosition, worldNormal);
		}
	}

	Out.Color.xyz += diffuseLight * DiffuseColor;

	Out.Color /= 2; // Prevent clamping in interpolator
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// pass texture coordinates for fetching the diffuse and agitator maps
	Out.TexCoord0 = TexCoord;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
	
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	
	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, GetEyePosition());

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool hasShadow, uniform bool applyGammaCorrection) COLORTARGET
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
		shadowAmount = shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord);
	}
	color.xyz += In.MainLightDiffuseColor * shadowAmount;

	color *= baseTexture;

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D(SAMPLER(ShroudTexture), In.ShroudTexCoord);
#endif

	return CorrectForFrameBufferGamma(color);
}

// ----------------------------------------------------------------------------
VSOutput VS_Xenon( VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord : TEXCOORD0,
		float4 VertexColor : COLOR0)
{
	return VS( InSkin, TexCoord, VertexColor, min(NumJointsPerVertex, 1), true );
}

// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In ) : COLOR
{
	return PS(In, HasShadow, true);
}

#if defined(EA_PLATFORM_PS3)
// ----------------------------------------------------------------------------
float4 PS_PS3( VSOutput In ) : COLOR
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

   	// Get diffuse color
   	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), In.TexCoord0);

	baseTexture *= tex2D(SAMPLER(ShroudTexture), In.ShroudTexCoord).x;
 
 	return(baseTexture);
}
#endif // #if defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// Arrays: Default
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#define VS_NumJointsPerVertex \
	compile VS_2_0 VS(0, true), \
	compile VS_2_0 VS(1, true)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = 1 );

#define PS_NumShadows \
	compile PS_2_0 PS(0, true), \
	compile PS_2_0 PS(1, true)

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

#if defined(EA_PLATFORM_PS3)
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			HasShadow * PS_Multiplier_NumShadows,
			compile PS_VERSION PS_PS3() );
#else // #if defined(EA_PLATFORM_PS3)
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			HasShadow * PS_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon() );
#endif // #if defined(EA_PLATFORM_PS3)

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
// Arrays: Default (Medium LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );

#define VS_M_NumJointsPerVertex \
	compile VS_2_0 VS(0, false), \
	compile VS_2_0 VS(1, false)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_NumShadows = 1 );

#define PS_M_NumShadows \
	compile PS_2_0 PS(0, false), \
	compile PS_2_0 PS(1, false)

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
	}
}
