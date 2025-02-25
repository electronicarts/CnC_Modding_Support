//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Shadowmap header
//////////////////////////////////////////////////////////////////////////////

#ifndef _SHADOWMAP_FXH_
#define _SHADOWMAP_FXH_

#include "RegisterMap.fxh"

// ----------------------------------------------------------------------------
// Shadow mapping variables
// ----------------------------------------------------------------------------
// If we use indirect constant, this should be declared in GlobalParamaters.fxh already
#if !defined(USE_INDIRECT_CONSTANT) || defined(EA_PLATFORM_WINDOWS)
bool HasShadow
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.HasShadow";
> = false;
#endif

#if !defined(USE_INDIRECT_CONSTANT)

float4x4 ShadowMapWorldToShadow
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].WorldToShadow";
>;

#endif // #if !defined(USE_INDIRECT_CONSTANT)

SAMPLER_2D_BEGIN( ShadowMap,
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].ShadowMap";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Shadow mapping constants
// ----------------------------------------------------------------------------
static const float shadowZBias = 0.0015; // Can use 0.001 with post processing pass

// ----------------------------------------------------------------------------
// Functions declaration, should be implemented in platform specific file
// ----------------------------------------------------------------------------
float shadow(sampler2D shadowSampler, float4 shadowTexCoord);

// ----------------------------------------------------------------------------
// Utility functions
// ----------------------------------------------------------------------------
float4 CalculateShadowMapTexCoord(float3 worldPosition)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), ShadowMapWorldToShadow);

	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

	return shadowTexCoord;
}

float4 CalculateShadowMapTexCoord_PerspectiveCorrect(float3 worldPosition)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), ShadowMapWorldToShadow);
	return shadowTexCoord;
}

// ----------------------------------------------------------------------------
// Include platform specific implementations
// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_XENON)
    #include "ShadowMap_xenon.fxh"
#else // #if defined(EA_PLATFORM_XENON)
    #include "ShadowMap_win32.fxh"
#endif // #if defined(EA_PLATFORM_XENON)

float shadow_PerspectiveCorrect(sampler2D shadowSampler, float4 shadowTexCoord)
{
	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

    return shadow(shadowSampler, shadowTexCoord);
}

#endif // #define _SHADOWMAP_FXH_
