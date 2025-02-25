//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain Scorch FX Shader
//////////////////////////////////////////////////////////////////////////////

#define TERRAIN_SCORCH

#include "Terrain.fxh"

#if defined(EA_PLATFORM_PS3)
// This value is calculated from (-0.0002) / (1/16777216)
#define SCORCHMARK_Z_BIAS -3355.4432

#else // #if defined(EA_PLATFORM_PS3)

#if !HIZ_CULLING
#define SCORCHMARK_Z_BIAS -0.0002
#else
#define SCORCHMARK_Z_BIAS 0.0002
#endif

#endif // #if defined(EA_PLATFORM_PS3)

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainScorch(
    float4 Position_BlendWeight1 : POSITION, 
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

	// Unpack vertex data
    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to VS_Default
    Out = VS_Default(Position, 1.0, BaseTexCoord, false);

	// The scorchmark are now render in seperate pass in a top down camera, so flatten the z position
	Out.Position.z = 0.0;

	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_Default_Scorch(VSOutputDefault In, float2 vPos : PIXELLOC ) : COLOR
{
    float4 color = PS_Default(In, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), false, SCORCHMARK_TEXTURE_DISABLED, vPos);
    color.xyz *= (1.0f/TerrainTopViewColorRange);
    return color;
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch ( HIGH QUALITY )
// ---------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_TerrainScorch();
		PixelShader = compile PS_3_0 PS_Default_Scorch();

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
		
		DepthBias = SCORCHMARK_Z_BIAS;
	}
}

// ---------------------------------------------------------------------------

VSOutput_CreateDepthNormalMap VS_CreateDepthNormalMap(
	float4 Position_BlendWeight1	: POSITION, 
    float2 BaseTexCoord				: TEXCOORD0,
	float4 Normal_BlendWeight2		: NORMAL0,
	float3 Tangent					: TANGENT,
	float3 Binormal					: BINORMAL
	)
{
	VSOutput_CreateDepthNormalMap Out;
	
	BaseTexCoord   = (BaseTexCoord   / 30000.0);
	Out.BaseTexCoord_BlendWeight = float4(BaseTexCoord.xy, 0, 0);
	Out.Position = mul(float4(Position_BlendWeight1.xyz, 1), ViewProjection);
	Out.Normal.xyz = (Normal_BlendWeight2.xyz * 255 / 100.0) - 1.0;
	Out.Tangent.xyz = (Tangent.xyz * 255 / 100.0) - 1.0;
	Out.Binormal.xyz = (Binormal.xyz * 255 / 100.0) - 1.0;

#if !defined(EA_PLATFORM_XENON)
	Out.Depth = Out.Position.z / Out.Position.w;
#endif	

	return Out;
}

// ---------------------------------------------------------------------------
// TECHNIQUE: CreateDepthNormalMap
// ---------------------------------------------------------------------------
technique _CreateDepthNormalMap
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_CreateDepthNormalMap();
		PixelShader = compile PS_3_0 PS_CreateDepthNormalMap();

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// LOD techniques follow
#if ENABLE_LOD

// ---------------------------------------------------------------------------
VSOutput_M VS_TerrainScorch_M(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_unpack : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutput_M Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float3 Normal = (Normal_unpack.xyz * 255 / 100.0) - 1.0;

	// Unpack vertex data
    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to VS_Default
    Out = VS_Default_M(Position, Normal, 1.0, BaseTexCoord, false);

	// The scorchmark are now render in seperate pass in a top down camera, so flatten the z position
	Out.Position.z = 0.0;

	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_Default_Scorch_M(VSOutput_M In, uniform bool hasShadow, float2 vPos : PIXELLOC ) : COLOR
{
    float4 color = PS_Default_M(In, SAMPLER(BaseSamplerClamped), hasShadow, false, SCORCHMARK_TEXTURE_DISABLED, vPos);
    color.xyz *= (1.0f/TerrainTopViewColorRange);
    return color;
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Medium Quality)
// ---------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_NumShadows = 1);

#define PS_Scorch_M_NumShadows \
	compile PS_3_0 PS_Default_Scorch_M(0), \
	compile PS_3_0 PS_Default_Scorch_M(1)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_Final = PS_Scorch_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Scorch_M_Array[PS_Scorch_M_Multiplier_Final] =
{
	PS_Scorch_M_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
        VertexShader = compile VS_3_0 VS_TerrainScorch_M();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_M_Array,
			HasShadow * PS_Scorch_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;

		DepthBias = SCORCHMARK_Z_BIAS;
	}
}

// ---------------------------------------------------------------------------
VSOutput_L VS_TerrainScorch_L(
    float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_unpack : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float3 Normal = (Normal_unpack.xyz * 255 / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to DefaultVertexShader_L
    return VS_Default_L(Position, Normal, 1.0f, BaseTexCoord, false);
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Low Quality)
// ---------------------------------------------------------------------------
technique Default_L
{
	pass P0
	{
        VertexShader = compile VS_2_0 VS_TerrainScorch_L();
		PixelShader = compile PS_2_0 PS_Default_L(SAMPLER(BaseSamplerClamped_L), false, SCORCHMARK_TEXTURE_DISABLED);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;

		DepthBias = SCORCHMARK_Z_BIAS;
	}
}

#endif // #if ENABLE_LOD
