//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for rendering objects into the distortion buffer
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	string RenderBin = "Distorter";
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
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

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

bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;

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
float4x4 View : View;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

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

float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput {

	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float3 TangentToViewSpace0 : TEXCOORD2;
	float3 TangentToViewSpace1 : TEXCOORD3;
	float3 TangentToViewSpace2 : TEXCOORD4;
};


// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, 
			float2 TexCoord : TEXCOORD0,
			float4 VertexColor	: COLOR0,
			uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	#if defined(_3DSMAX_)
		Time = Time * .2;
		VertexColor = float4(1,1,1,1);
	#endif

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	float3 viewPosition = mul(float4(worldPosition, 1), View).xyz;

	// Build 3x3 tranform from tangent to world space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);
	tangentToWorldSpace = mul(tangentToWorldSpace, (float3x3)View);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

	Out.Color = float4(mul(worldNormal, (float3x3)View) * 0.5 + 0.5, OpacityOverride);
	Out.Color = float4(float(500 / (200 -viewPosition.z)).xxx, OpacityOverride) * VertexColor;
//	Out.Color = float4(1..xxx, OpacityOverride) * VertexColor;

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0.xy = TexCoord.xy * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float2 texCoord0 = In.TexCoord0;	
	float4 normalMapSample = tex2D( SAMPLER(NormalMap), texCoord0);
	float3 bumpNormal = normalMapSample.xyz * 2.0 - 1.0;

	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	float3 normal = mul(bumpNormal, TangentToViewSpace);
	float4 color = float4(In.Color.xyz * normal * 0.5 + 0.5, In.Color.w * normalMapSample.w);

	color.w *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord).w;
	
	return color;
}

// ----------------------------------------------------------------------------
VSOutput VS_Xenon( 
					VSInputSkinningOneBoneTangentFrame InSkin, 
					float2 TexCoord : TEXCOORD0,
					float4 VertexColor	: COLOR0 )
{
	return VS( InSkin, TexCoord, VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default
// ----------------------------------------------------------------------------
#define VS_NumJointsPerVertex \
	compile VS_2_0 VS(0), \
	compile VS_2_0 VS(1)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif


// ----------------------------------------------------------------------------
// Technique: Default (Medium and up)
// ----------------------------------------------------------------------------
technique Default_M
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
		
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;//true;
		CullMode = CW;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		// As an optimization some objects specify the alpha test enable flag to throw away pixels.
		// This doesn't work on Xenon unless we implement a ShaderExpressionEvaluator for it,
		// and since it's only an optimization, leave it out for now.
#if defined(EA_PLATFORM_XENON) || defined(EA_PLATFORM_PS3)
		AlphaTestEnable = false;
#else
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
#endif
	}
}

// ----------------------------------------------------------------------------
// Technique: Default (Low)
// ----------------------------------------------------------------------------
#if !defined(_3DSMAX_) // 3DS Max crashes when a technique is empty

technique Default_L
{
	// No passes. Indicates technique disabled.
}

#endif // !defined(_3DSMAX_)
