//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Common functionality for rendering underwater objects
//////////////////////////////////////////////////////////////////////////////

#ifndef _COMMON_UNDERWATER_FXH_
#define _COMMON_UNDERWATER_FXH_

#include "Common.fxh"
#include "Gamma.fxh"

// ----------------------------------------------------------------------------

static const float WaterLevel = 200;

// ----------------------------------------------------------------------------
// Caustics and Depth LUT
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( DepthLutSampler,
	string UIWidget = "None";
	string SasBindAddress = "Water.DepthLutTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( CausticSampler,
	string UIWidget = "None";
	string SasBindAddress = "Water.CausticsTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
float4 GetDepthLutValue(float3 worldPosition)
{
	float depthLutTexCoord = (1 - worldPosition.z + WaterLevel) / WaterLevel;
	
	float4 depthLut = tex2Dlod(SAMPLER(DepthLutSampler), float4(depthLutTexCoord.xx, 0, 0));

	depthLut.xyz = GammaToLinear(depthLut.xyz);

	return depthLut;
}

// ----------------------------------------------------------------------------
float4 GetDepthLutValue_M(float3 worldPosition)
{
	float depthLutTexCoord = (1 - worldPosition.z + WaterLevel) / WaterLevel;
	
	float4 depthLut = tex2D(SAMPLER(DepthLutSampler), depthLutTexCoord.xx);

	return depthLut;
}

// ----------------------------------------------------------------------------
float3 GetCausticsColor(float3 worldPosition, float3 worldNormal, SasDirectionalLight directionalLight, float time, uniform bool isFullColor)
{
	// Generate Caustic Tex Coords Based on Sunlight Vector
	float2 CausticTexCoord = (worldPosition.xy - worldPosition.z * directionalLight.Direction.xy / directionalLight.Direction.z) * .004;

	// Build Caustic Rotation Matrix using Sunlight Vector
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	float cosAngle = 0;
	float sinAngle = 0;
	sincos (66 * .017453, sinAngle, cosAngle);
	
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];
	
	float2 causticTexCoordsDiverge = mul(CausticTexCoord, uvCoordRotate);
	causticTexCoordsDiverge.x += time * .12;
	float2 causticTexCoordsDivergeInv = mul(CausticTexCoord, transpose(uvCoordRotate));
	causticTexCoordsDivergeInv.x += time * .12;

	// Get Caustic Normal map and normalize
	float2 causticDistort = tex2D( SAMPLER(CausticSampler), causticTexCoordsDiverge);
	causticDistort += tex2D( SAMPLER(CausticSampler), causticTexCoordsDivergeInv);
	causticDistort = causticDistort - 1;
	
	causticDistort *= .3;
	
	// 1st pass Generate a 3 channel caustic for chromatic refraction from 8 bit alpha
	float3 causticSamp = float3(1,1,1);

	causticSamp.y = tex2D( SAMPLER(CausticSampler), causticTexCoordsDiverge + causticDistort).w;
	if (isFullColor)
	{
		causticSamp.x = tex2D( SAMPLER(CausticSampler), causticTexCoordsDiverge + (causticDistort * .9)).w;
		causticSamp.z = tex2D( SAMPLER(CausticSampler), causticTexCoordsDiverge + (causticDistort * 1.1)).w;
	}

	// 2nd pass Generate a 3 channel caustic for chromatic refraction from 8 bit alpha
	causticSamp.y *= tex2D( SAMPLER(CausticSampler), -causticTexCoordsDivergeInv - causticDistort).w;
	if (isFullColor)
	{
		causticSamp.x *= tex2D( SAMPLER(CausticSampler), -causticTexCoordsDivergeInv - (causticDistort * .9)).w;
		causticSamp.z *= tex2D( SAMPLER(CausticSampler), -causticTexCoordsDivergeInv - (causticDistort * 1.1)).w;
	}
	else
	{
		causticSamp.x = causticSamp.y;
		causticSamp.z = causticSamp.y;
	}

	causticSamp = pow(causticSamp,2);

	float4 depthLut = GetDepthLutValue(worldPosition);

	float mainLightFalloff = max(0, dot(worldNormal, directionalLight.Direction));
	
	float3 caustics = causticSamp * depthLut.w * lerp(directionalLight.Color,float3(1,1,1),.75) * mainLightFalloff;

	caustics = GammaToLinear(caustics * 5);
	
	return caustics;
}

#endif // _COMMON_UNDERWATER_FXH_