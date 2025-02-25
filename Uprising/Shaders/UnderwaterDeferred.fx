//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Deferred shader for rendering over underwater objects
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_GLOBAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "CommonUnderwater.fxh"

// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transforms
// ----------------------------------------------------------------------------
float4x4 ViewI : ViewInverse;
float4x4 ProjectionI : ProjectionInverse;
float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 WorldEyeDir : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput DefaultVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	
	
	// We need to convert the view space depth values from the depth texture to world space positions.
	// First build a ray "through" the pixel in question
	float4 screenFarPlanePosition = float4(Position.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	float3 viewEyeDir = viewFarPlanePosition / viewFarPlanePosition.z;

	float3 worldEyeDir = mul(viewEyeDir, ViewI);
	
	Out.WorldEyeDir = worldEyeDir;
	
	return Out;
}

// ----------------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------------
float3 ComputeWorldPosition(VSOutput In)
{
	float depth = tex2D(SAMPLER(DepthTexture), In.TexCoord).x;
	
	float3 eyePosition = ViewI[3];
	float3 worldPosition = eyePosition + depth * In.WorldEyeDir;
	
	return worldPosition;
}

// ----------------------------------------------------------------------------
float4 TintPS(VSOutput In) : COLOR
{
	float3 worldPosition = ComputeWorldPosition(In);
	
	// Save a bit fill rate by not modifying pixels above the water surface
	clip(WaterLevel - worldPosition.z);

	return GetDepthLutValue(worldPosition);
}

// ----------------------------------------------------------------------------
float4 TintPS_M(VSOutput In) : COLOR
{
	float3 worldPosition = ComputeWorldPosition(In);
	
	// Save a bit fill rate by not modifying pixels above the water surface
	clip(WaterLevel - worldPosition.z);

	return GetDepthLutValue_M(worldPosition);
}

// ----------------------------------------------------------------------------
float4 CausticsPS(VSOutput In, uniform bool isFullColor) : COLOR
{
	float3 worldPosition = ComputeWorldPosition(In);

	// Save a bit fill rate by not modifying pixels above the water surface
	clip(WaterLevel - worldPosition.z);

	// Calculate the normal through derivatives of the world position.
	// Note that these vectors are "faceted" like flat shading.
	// The depth based vectors cannot provide a smoothed normal like a interpolated per-vertex normal.
	float3 worldTangent = ddy(worldPosition);
	float3 worldBinormal = ddx(worldPosition);
	float3 worldNormal = normalize(cross(worldTangent, worldBinormal));

	float3 caustics = GetCausticsColor(worldPosition, worldNormal, DirectionalLight[0], Time, isFullColor);
	
	return float4(caustics, 1);
}

// ----------------------------------------------------------------------------
struct VSOutputNothing
{
	float4 Position : POSITION;
};

// ----------------------------------------------------------------------------
VSOutputNothing NothingVS()
{
	VSOutputNothing Out;
	Out.Position = float4(0, 0, 0, 1);
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 NothingPS(VSOutputNothing In) : COLOR
{
	return float4(0, 0, 0, 0);
}

// ----------------------------------------------------------------------------
technique Tint
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		PixelShader = compile PS_3_0 TintPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
	}
}

technique Caustics
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		PixelShader = compile PS_3_0 CausticsPS(false);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}
}

#if ENABLE_LOD

technique Caustics_U
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		PixelShader = compile PS_3_0 CausticsPS(true);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}
}

technique _Tint_M
{
	pass p0
	{
		VertexShader = compile VS_2_0 DefaultVS();
		PixelShader = compile PS_2_0 TintPS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
	}
}

// No underwater caustics rendering in Medium LOD or lower
technique _Caustics_M
{
	// Normally to just not render something, an empty technique without passes would be enough.
	// This shader is used by a scrape renderquad command though, and that only supports one-pass shaders.
	// So just use a shader that doesn't generate any pixels, and it should be fine.
	pass p0
	{
		VertexShader = compile VS_2_0 NothingVS();
		PixelShader = compile PS_2_0 NothingPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = false;
	}
}

#endif