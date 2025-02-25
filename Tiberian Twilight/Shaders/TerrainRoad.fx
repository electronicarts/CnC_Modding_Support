//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain Road FX Shader
//////////////////////////////////////////////////////////////////////////////

#define TERRAIN_ROAD

#include "Terrain.fxh"

#if defined(EA_PLATFORM_PS3)
// This value is calculated from (-0.0004) / (1/16777216)
#define ROAD_Z_BIAS -6710.8864

#else // #if defined(EA_PLATFORM_PS3)

#if !HIZ_CULLING
#define ROAD_Z_BIAS -0.0004
#else
#define ROAD_Z_BIAS 0.0004
#endif

#endif // #if defined(EA_PLATFORM_PS3)

// ---------------------------------------------------------------------------
VSOutputDefault VS_Default_Road(
	float3 Position : POSITION, 
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0)
{
	VSOutputDefault Out;

	Out = VS_Default(Position, Color, BaseTexCoord, false);

	Out.WorldPosition = Position;

	return Out;
}

// ---------------------------------------------------------------------------
float4 PS_Default_Road(VSOutputDefault In, float2 vPos : PIXELLOC ) : COLOR
{
    return PS_Default(In, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), false, SCORCHMARK_TEXTURE_ENABLED, vPos);
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Road ( HIGH QUALITY )
// ---------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default_Road();
		PixelShader = compile PS_3_0 PS_Default_Road();

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
		
		DepthBias = ROAD_Z_BIAS;
	}
}

// ---------------------------------------------------------------------------

VSOutput_CreateDepthNormalMap VS_CreateDepthNormalMap(
	float4 Position_BlendWeight1 : POSITION, 
    float2 BaseTexCoord : TEXCOORD0,
	float4 Normal_BlendWeight2 : NORMAL0
	)
{
	VSOutput_CreateDepthNormalMap Out;
	
	Out.BaseTexCoord_BlendWeight = float4(BaseTexCoord.xy, 0, 0);
	Out.Position = mul(float4(Position_BlendWeight1.xyz, 1), ViewProjection);
	Out.Normal = Normal_BlendWeight2.xyz;
	Out.Tangent = cross(Out.Normal, float3(-1, 0, 0));
	Out.Binormal = cross(Out.Normal, float3(0, 1, 0));
	Out.NDCPosition = Out.Position;

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
// TECHNIQUE : Road (Medium Quality)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

VSOutput_M VS_Default_Road_M(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0)
{
	VSOutput_M Out;

	Out = VS_Default_M(Position, Normal, Color, BaseTexCoord, false);

	Out.WorldPosition = Position;

	return Out;
}

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_NumShadows = 1);

#define PS_Road_M_NumShadows \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerWrapped), 0, false, SCORCHMARK_TEXTURE_ENABLED), \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerWrapped), 1, false, SCORCHMARK_TEXTURE_ENABLED)

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_Final = PS_Road_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Road_M_Array[PS_Road_M_Multiplier_Final] =
{
	PS_Road_M_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default_Road_M();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_M_Array,
			HasShadow * PS_Road_M_Multiplier_NumShadows,
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
		
		DepthBias = ROAD_Z_BIAS;
	}
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Road (Low Quality)
// ---------------------------------------------------------------------------

VSOutput_L VS_Default_Road_L(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0)
{
	VSOutput_L Out;

	Out = VS_Default_L(Position, Normal, Color, BaseTexCoord, false);

	Out.ShroudTexCoord_ScorchMarkTexCoord.zw = CalcTerrainTopViewTexCoord(Position.xy);

	return Out;
}

// ---------------------------------------------------------------------------
technique Default_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_Road_L();
		PixelShader = compile PS_2_0 PS_Default_L(SAMPLER(BaseSamplerWrapped_L), false, SCORCHMARK_TEXTURE_ENABLED);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
		
		DepthBias = ROAD_Z_BIAS;
	}
}

#endif // #if ENABLE_LOD
