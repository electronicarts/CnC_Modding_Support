//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for rendering objects into the distortion buffer
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

int _GlobalInfo : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int SortLevel = SortLevel_Distorter;
> = 0;


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


float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float BumpScale
<
	string UIName = "Bump Height"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 10.0;
    float UIStep = 0.1;
> = 1.0;

/*bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;*/



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
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput {

	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float3x3 TangentToViewSpace : TEXCOORD2;
};


// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
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
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	float3 viewPosition = mul(float4(worldPosition, 1), View);

	// Build 3x3 tranform from tangent to world space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace = mul(tangentToWorldSpace, (float3x3)View);

	//Out.Color = float4(mul(worldNormal, (float3x3)View) * 0.5 + 0.5, OpacityOverride);
	//Out.Color = float4(float(500 / (300 -viewPosition.z)).xxx, OpacityOverride);
	Out.Color = float4(1..xxx, OpacityOverride);

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0.xy = TexCoord.xy * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool applyShroud) : COLOR
{
	float2 texCoord0 = In.TexCoord0;	
	float4 normalMapSample = tex2D( SAMPLER(NormalMap), texCoord0);
	float3 bumpNormal = normalMapSample.xyz * 2.0 - 1.0;

	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	
	float3 normal = mul(bumpNormal, In.TangentToViewSpace);
	float4 color = float4(In.Color.xyz * normal * 0.5 + 0.5, In.Color.w * normalMapSample.w);
	if (applyShroud)
	{
		color.w *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord).w;
	}
	
	return color;
}

// ----------------------------------------------------------------------------
VSOutput VS_Xenon( VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0 )
{
	return VS( InSkin, TexCoord, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In ) : COLOR
{
	return PS( In, (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default
// ----------------------------------------------------------------------------
#define VS_NumJointsPerVertex \
	compile vs_2_0 VS(0), \
	compile vs_2_0 VS(1)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_ApplyShroud = 1 );

#define PS_ApplyShroud \
	compile ps_2_0 PS(false), \
	compile ps_2_0 PS(true)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_ApplyShroud * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_ApplyShroud
};
#endif


// ----------------------------------------------------------------------------
// Technique: Default (Medium and up)
// ----------------------------------------------------------------------------
technique Default_M
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	<
		USE_EXPRESSION_EVALUATOR("DistortingObject")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION VS_Xenon()
		);
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_Multiplier_ApplyShroud,
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

// ----------------------------------------------------------------------------
// Technique: Default (Low)
// ----------------------------------------------------------------------------
#if !defined(_3DSMAX_) // 3DS Max crashes when a technique is empty

technique Default_L
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	// No passes. Indicates technique disabled.
}

#endif // !defined(_3DSMAX_)
