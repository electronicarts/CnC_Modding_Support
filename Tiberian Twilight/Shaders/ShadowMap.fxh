//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Shadowmap header
//////////////////////////////////////////////////////////////////////////////

#ifndef _SHADOWMAP_FXH_
#define _SHADOWMAP_FXH_

#include "RegisterMap.fxh"

#if defined(EA_PLATFORM_PS3)
	#define USE_SCREENSPACE_SHADOW 1
	#define USE_HARDWARE_SHADOW 1
#endif // #if defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// Shadow mapping defines
// ----------------------------------------------------------------------------
static const int SHADOWMAP_SAMPLE_DEFAULT	= 0;
static const int SHADOWMAP_SAMPLE_SOFT		= 1;

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

float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

#endif // #if !defined(USE_INDIRECT_CONSTANT)

// Uncomment to enable toggle of softshadow via debug key, require enabling DEBUG_SOFTSHADOW in W3DShadowMapManager.cpp
//#define ENABLE_SOFTSHADOW_TOGGLE

// Constants for adjusting the soft shadow
// x - Kernel size, adjust how soft the shadow
// y - Jitter size, adjust how much noise
// z - Temporarily used for debug, to allow us to toggle between old and new shadows (see ENABLE_SOFTSHADOW_TOGGLE above)
// w - Not used
float4 SoftShadowParms
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.SoftShadowParms";
> = float4(0.0f, 0.0f, 0.0f, 0.0);

#if defined(USE_HARDWARE_SHADOW)
SAMPLER_2D_BEGIN( ShadowMap,
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].ShadowMap";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
	ZFunc = GREATEREQUAL;
SAMPLER_2D_END
#else // #if defined(USE_HARDWARE_SHADOW)
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
#endif // #if defined(USE_HARDWARE_SHADOW)

// ----------------------------------------------------------------------------
// Shadow mapping constants
// ----------------------------------------------------------------------------
static const float shadowZBias = 0.0015; // Can use 0.001 with post processing pass
static const float shadowZBiasForSoftShadow = 0.001; // The more we jitter, the more we need to bias to avoid acne problem

// ----------------------------------------------------------------------------
// Functions declaration, should be implemented in platform specific file
// ----------------------------------------------------------------------------
float shadow(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, uniform int shadowmapSampling);

// ----------------------------------------------------------------------------
// Macro to minimize platform #ifdef among shaders
// ----------------------------------------------------------------------------
#if defined(USE_SCREENSPACE_SHADOW)

SAMPLER_2D_BEGIN( ScreenSpaceShadow,
	string UIWidget = "None";
	string SasBindAddress = "Sas.ScreenSpaceShadow";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Utility functions (Override to call the screen space version)
// ----------------------------------------------------------------------------

float4 CalculateShadowMapTexCoord(float3 worldPosition, uniform int shadowmapSampling)
{
	// For screen space shadowmap, we simply want to get the screen coordinate
	float4 viewPosition = mul(float4(worldPosition, 1), ViewProjection);
	viewPosition.xy = 0.5f * (viewPosition.xy / viewPosition.w + 1.0f);
	viewPosition.y = 1.0 - viewPosition.y;
	return viewPosition;
}

float4 CalculateShadowMapTexCoord_PerspectiveCorrect(float3 worldPosition, uniform int shadowmapSampling)
{
	// For screen space shadowmap, we simply want to get the screen coordinate and we leave the perspective correction in the pixel shader
	float4 viewPosition = mul(float4(worldPosition, 1), ViewProjection);
	return viewPosition;
}

float shadow(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, uniform int shadowmapSampling)
{
	return tex2D( SAMPLER(ScreenSpaceShadow), shadowTexCoord.xy ).x;
}

float shadow_PerspectiveCorrect(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, uniform int shadowmapSampling)
{
	shadowTexCoord.xy = 0.5f * (shadowTexCoord.xy / shadowTexCoord.w + 1.0f);
	shadowTexCoord.y = 1.0 - shadowTexCoord.y;
	return shadow(shadowSampler, shadowTexCoord, vPos, shadowmapSampling);
}

#else // #if defined(USE_SCREENSPACE_SHADOW)

// ----------------------------------------------------------------------------
// Utility functions
// ----------------------------------------------------------------------------
float4 CalculateShadowMapTexCoord(float3 worldPosition, uniform int shadowmapSampling)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), ShadowMapWorldToShadow);

	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

	if(shadowmapSampling == SHADOWMAP_SAMPLE_SOFT
#if defined(ENABLE_SOFTSHADOW_TOGGLE)
	 && SoftShadowParms.z > 0.0f
#endif // #if defined(ENABLE_SOFTSHADOW_TOGGLE)
		)
	{
		float jitterSize = SoftShadowParms.y;
		shadowTexCoord.z -= (jitterSize*shadowZBiasForSoftShadow);
	}

	return shadowTexCoord;
}

float4 CalculateShadowMapTexCoord_PerspectiveCorrect(float3 worldPosition, uniform int shadowmapSampling)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), ShadowMapWorldToShadow);
	return shadowTexCoord;
}

// ----------------------------------------------------------------------------
// Include platform specific implementations
// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_XENON)
    #include "ShadowMap_xenon.fxh"
#elif defined(EA_PLATFORM_WINDOWS)
    #include "ShadowMap_win32.fxh"
#else
	#include "ShadowMap_ps3.fxh"
#endif // #if defined(EA_PLATFORM_XENON)

float shadow_PerspectiveCorrect(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, uniform int shadowmapSampling)
{
	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

	if(shadowmapSampling == SHADOWMAP_SAMPLE_SOFT
#if defined(ENABLE_SOFTSHADOW_TOGGLE)
	 && SoftShadowParms.z > 0.0f
#endif // #if defined(ENABLE_SOFTSHADOW_TOGGLE)
		)
	{
		float jitterSize = SoftShadowParms.y;
		shadowTexCoord.z -= (jitterSize*shadowZBiasForSoftShadow);
	}

    return shadow(shadowSampler, shadowTexCoord, vPos, shadowmapSampling);
}

#endif // #if defined(USE_SCREENSPACE_SHADOW)


#endif // #define _SHADOWMAP_FXH_
