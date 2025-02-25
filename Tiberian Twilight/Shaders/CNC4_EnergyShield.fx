//////////////////////////////////////////////////////////////////////////////
// 2009 Electronic Arts Inc
//
// FX Shader Stealthed Units
//////////////////////////////////////////////////////////////////////////////



#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define FIRSTPASS 0

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

	string RenderBin = "StaticSort1";

	int MaxLocalLights = 8;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;


#if defined(_3DSMAX_)
	bool StealthEnabled = false;
	float OpacityOverride = 1.0f;
#endif



DECLARE_MAPPING_TEXCOORD(0)
#if defined(SUPPORT_DAMAGETEXTURE)
DECLARE_MAPPING_TEXCOORD(1)
DECLARE_MAPPING_VERTEXCOLOR(2, 3)
#else
DECLARE_MAPPING_VERTEXCOLOR(1, 2)
#endif


#if defined(SUPPORT_DAMAGETEXTURE)
#define EXPRESSION_EVALUATOR_NAME "Buildings"
#else
#define EXPRESSION_EVALUATOR_NAME "Objects"
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1
#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
#define NumDirectionalLightsPerPixel	2
#define NumDirectionalLightsPerPixel_M	1


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

SAMPLER_2D_BEGIN( HexGrid,
	 string SasBindAddress = "WW3D.Buff_HexGrid";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float UVScale
<
	string UIName = "UV Scale"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 100.0;
    float UIStep = 0.1;
> = 10.0;


// ----------------------------------------------------------------------------
// Shroud
// $note (MD) -- used for MED & LOW LOD
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
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
};

VSOutput_H VS_H(
		VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE)
	USE_TEXCOORD(TexCoord1);
#endif

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);


	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	float2 texCoord1 = TexCoord0;

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

	return Out;
}

 


// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - High
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			float2 vPos : PIXELLOC, uniform bool stealthEnabled, uniform int isMultiPass) COLORTARGET
{	

	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	float4 color =  float4(baseTexture.xyz, 0.1f);

	//hex
	float4 hextex = tex2D( SAMPLER(HexGrid), texCoord0 * UVScale);
	color = color + (color * hextex);

	//test anim


	
	return CorrectForFrameBufferGamma(color);

}


// ----------------------------------------------------------------------------
// Arrays: Default_H
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_H_Multiplier_Final = 3 );

#define VS_H_NumJointsPerVertex(isMultiPass) \
	compile VS_3_0 VS_H(0, isMultiPass), \
	compile VS_3_0 VS_H(1, isMultiPass), \
	compile VS_3_0 VS_H(2, isMultiPass)

#if SUPPORTS_SHADER_ARRAYS
	vertexshader VS_H_Array[VS_H_Multiplier_Final] =
	{
		VS_H_NumJointsPerVertex(FIRSTPASS)
	};
	
#endif // SUPPORTS_SHADER_ARRAYS

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_NumShadows = 1 );


#define PS_H_NumShadows(recolorEnabled, stealthEnabled, isMultiPass) \
	compile PS_3_0 PS_H(0, recolorEnabled, stealthEnabled, isMultiPass), \
	compile PS_3_0 PS_H(1, recolorEnabled, stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_RecolorEnabled = PS_H_Multiplier_NumShadows * 2 );
	
#define PS_H_RecolorEnabled(stealthEnabled, isMultiPass) \
	PS_H_NumShadows(false, stealthEnabled, isMultiPass), \
	PS_H_NumShadows(true,  stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_StealthEnabled = PS_H_Multiplier_RecolorEnabled * 2);

#define PS_H_StealthEnabled(isMultiPass) \
	PS_H_RecolorEnabled(false, isMultiPass), \
	PS_H_RecolorEnabled(true,  isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_StealthEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_H_Array[PS_H_Multiplier_Final] =
	{
		PS_H_StealthEnabled(FIRSTPASS)
	};

#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, MaxSkinningBones), 
			compile VS_VERSION VS_Xenon(false) );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled
			+ StealthEnabled * PS_H_Multiplier_StealthEnabled,  
			compile PS_VERSION PS_Xenon(false) );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

