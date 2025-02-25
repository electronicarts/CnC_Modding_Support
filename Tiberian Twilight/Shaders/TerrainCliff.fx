//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain Cliff FX Shader
//////////////////////////////////////////////////////////////////////////////

#define TERRAIN_CLIFF

#include "Terrain.fxh"

// ---------------------------------------------------------------------------
VSOutputDefault VS_Default_Cliff(
	float3 Position : POSITION, 
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0)
{
	return VS_Default(Position, Color, BaseTexCoord, false);
}

// ---------------------------------------------------------------------------
float4 PS_Default_Cliff(VSOutputDefault In, float2 vPos : PIXELLOC ) : COLOR
{
    return PS_Default(In, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), false, SCORCHMARK_TEXTURE_DISABLED, vPos);
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff ( HIGH QUALITY )
// ---------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default_Cliff();
		PixelShader = compile PS_3_0 PS_Default_Cliff();

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
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
	
	Out.BaseTexCoord_BlendWeight = float4(BaseTexCoord.xy, 0, 0);
	Out.Position = mul(float4(Position_BlendWeight1.xyz, 1), ViewProjection);
	Out.Normal = Normal_BlendWeight2.xyz;
	Out.Tangent = cross(Out.Normal, float3(-1, 0, 0));
	Out.Binormal = cross(Out.Normal, float3(0, 1, 0));

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
// TECHNIQUE : Cliff (Medium Quality)
// ---------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_NumShadows = 1);

#define PS_Cliff_M_NumShadows \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerWrapped), 0, false, SCORCHMARK_TEXTURE_DISABLED), \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerWrapped), 1, false, SCORCHMARK_TEXTURE_DISABLED)

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_Final = PS_Cliff_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Cliff_M_Array[PS_Cliff_M_Multiplier_Final] =
{
	PS_Cliff_M_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default_M(false);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_M_Array,
			HasShadow * PS_Cliff_M_Multiplier_NumShadows,
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
	}
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff (Low Quality)
// ---------------------------------------------------------------------------
technique Default_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_L(false);
		PixelShader = compile PS_2_0 PS_Default_L(SAMPLER(BaseSamplerWrapped_L), false, SCORCHMARK_TEXTURE_DISABLED);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}

#endif // #if ENABLE_LOD
