//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Common header for FX files
//////////////////////////////////////////////////////////////////////////////

#ifndef _COMMON_FXH_
#define _COMMON_FXH_


// Include platform specific macros
#if defined( EA_PLATFORM_XENON )
#include "xenon_macros.fxh"
#else
#include "win32_macros.fxh"
#endif

#include "Sas.fxh"

// Set some preprocessor define for 3DSMax.
// Since we can't set it there, define it excluding our other tools.
#if !defined(_WW3D_) && !defined(_FX_COMPOSER_)
#define _3DSMAX_
#endif


// This is used by 3dsmax to load the correct parser
#if defined(_3DSMAX_)
	string ParamID = "0x1";
#endif


//
// Expression evaluator system.
// Allows shaders to hook up to CPU code to assign render states or shader constants
//
// To disable expression evaluators for a file temporarily, define the DISABLE_EXPRESSION_EVALUATORS macro

#if !defined(_WW3D_) || defined(_W3DVIEW_) || defined(DISABLE_EXPRESSION_EVALUATORS)
	#define EXPRESSION_EVALUATOR_ENABLED 0
#else
	#define EXPRESSION_EVALUATOR_ENABLED 1
#endif

#if EXPRESSION_EVALUATOR_ENABLED
	#define USE_EXPRESSION_EVALUATOR(name) string ExpressionEvaluator = name;
#else
	#define USE_EXPRESSION_EVALUATOR(name)
#endif


#if defined(EA_PLATFORM_XENON)
	#define SUPPORTS_SHADER_ARRAYS 0
#else // EA_PLATFORM_WINDOWS
	#define SUPPORTS_SHADER_ARRAYS 1
#endif


#if SUPPORTS_SHADER_ARRAYS

	// Use these macros to define shader arrays.
	// The "direct" version of the macro will never try to use the expression evaluator to evaluate the array index.
	#define ARRAY_EXPRESSION_DIRECT_VS(arrayName, expression, noArraySupportAlternative) ( arrayName[ expression ] )
	#define ARRAY_EXPRESSION_DIRECT_PS(arrayName, expression, noArraySupportAlternative) ( arrayName[ expression ] )

	// The non-"direct" version of the macro use the expression evaluator to evaluate the array index when possible.
	#if EXPRESSION_EVALUATOR_ENABLED
	
		int _ArrayIndexVS = 0;
		int _ArrayIndexPS = 0;
		#define ARRAY_EXPRESSION_VS(arrayName, expression, noArraySupportAlternative) ( arrayName[ _ArrayIndexVS ] )
		#define ARRAY_EXPRESSION_PS(arrayName, expression, noArraySupportAlternative) ( arrayName[ _ArrayIndexPS ] )

		#define DEFINE_ARRAY_MULTIPLIER(initializer) \
			static const int initializer; \
			const int _##initializer
			
	#else // !EXPRESSION_EVALUATOR_ENABLED
	
		#define ARRAY_EXPRESSION_VS(arrayName, expression, noArraySupportAlternative) ( arrayName[ expression ] )
		#define ARRAY_EXPRESSION_PS(arrayName, expression, noArraySupportAlternative) ( arrayName[ expression ] )
	
		#define DEFINE_ARRAY_MULTIPLIER(initializer) \
			static const int initializer
	#endif

#else // !SUPPORT_SHADER_ARRAYS
	#define ARRAY_EXPRESSION_DIRECT_VS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_DIRECT_PS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_VS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_PS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative

	#define DEFINE_ARRAY_MULTIPLIER(initializer)
#endif


//
// Technique LOD
//
#if !defined(ENABLE_LOD)
	#if defined(EA_PLATFORM_WINDOWS)
		#define ENABLE_LOD 1
	#else // EA_PLATFORM_XENON
		#define ENABLE_LOD 0
	#endif
#endif



//
// HI-Z CULLING
//

#if !HIZ_CULLING
	#define ZFUNC_INFRONT LessEqual
#else
	#define ZFUNC_INFRONT GreaterEqual
#endif


//
// COLOR VALUES
//

#define RGB		7
#define RGBA	15



// Shader parameters are associated to a "dynamic set". Each set can be updated independently,
// so that multiple objects that eg. only differ in their world transformation can be rendered
// without updating all the other rendering states.
//
// Keep this in sync with FXShaderParameter.h
//
static const int DS_DEFAULT = 0; // Parameters without WW3DDynamicSet annotation fall into this category
static const int DS_WORLD_TRANSFORMATIONS = 1; // Parameters that change when the world matrix changes (World, WorldView, WorldInverse...)
static const int DS_CUSTOM_FIRST = 2; // These sets can be used for custom shader rendering sequences
static const int DS_CUSTOM_LAST = 5;


// Special render order values, can be used in the SasGlobal parameter "SortLevel" annotation
//
// Keep this in sync with StaticSortLevelEnum
//
static const int SortLevel_Default = 0;
// Values 1-32 are used for static sorting levels through max exporter.
static const int SortLevel_Distorter = 33;


// Threshold for AlphaRef render state when doing alpha testing
#define DEFAULT_ALPHATEST_THRESHOLD 0x60


//
// Common distance fog setup info, can be bound to "WW3D.Fog" binding
//

struct WW3DFog
{
	//bool IsEnabled; // There is a bug in the D3DX Effect framework, this needs to be float to work
	float IsEnabled;
	float4 Color;
	float RangeStart;
	//float RangeEnd;
	float OneOverRangeDelta; // = 1.0 / (RangeEnd - RangeStart)
};

#define DEFAULT_FOG_DISABLED { false, float4(1, 1, 1, 1), 0, /*1000*/ 0.001 }

// Calculate the "distance fog value", appropriate for use with the FOG output semantic of a vertex shader.
// Returns 1.0 for completely un-fogged areas, and 0.0 for completely fogged, between that if partially fogged.
float CalculateFog(WW3DFog Fog, float3 WorldPosition, float3 CameraPosition)
{
	return 1.0 - Fog.IsEnabled * saturate((length(WorldPosition - CameraPosition) - Fog.RangeStart) * Fog.OneOverRangeDelta);
}



//
// Common shroud setup, can be bound to "Terrain.Shroud" binding
//
struct ShroudSetup
{
	float4 ScaleUV_OffsetUV;
};

#define DEFAULT_SHROUD { float4(1, 1, 0, 0) }

// Calculate the texture coordinates for shroud lookup
float2 CalculateShroudTexCoord(ShroudSetup shroud, float3 WorldPosition)
{
	return (WorldPosition.xy + shroud.ScaleUV_OffsetUV.zw) * shroud.ScaleUV_OffsetUV.xy;
}

// Remap the high end of the shroud transition so that effects become invisible in "fog of war"
float BiasShroudValueForEffects( float normalizedShroudValue )
{
    // We'd like to simply do this: return max( 0, ( normalizedShroudValue - 0.75 ) * 4 );
    // However, pixel shader 1.1 doesn't let you use numbers above 2
    // So, we cleverly trick the HLSL compiler into doing it in two steps
    float shroud = normalizedShroudValue - 0.75;
    shroud *= 2;
    shroud = max( 0, shroud );
    shroud *= 2;

    return shroud;
}

// Possible values of the "Terrain.Shroud.ObjectShroudStatus" parameter
static const int OBJECTSHROUD_INVALID = 0;			///< indeterminate state
static const int OBJECTSHROUD_CLEAR = 1;			///< object is not shrouded at all (ie, completely visible)
static const int OBJECTSHROUD_PARTIAL_CLEAR = 2;	///< object is partly clear (rest is shroud or fog)
static const int OBJECTSHROUD_FOGGED = 3;			///< object is completely fogged
static const int OBJECTSHROUD_SHROUDED = 4;			///< object is completely shrouded


//
// Common cloud layer computation
//
struct CloudSetup
{
	float4 WorldPositionMultiplier_XYZZ;
	float2 CurrentOffsetUV;
};

#define DEFAULT_CLOUD { float4(0, 0, 0, 0), float2(0, 0) }

// Calculate the texture coordinates for cloud lookup
float2 CalculateCloudTexCoord(CloudSetup cloudSetup, float3 WorldPosition, float Time)
{
	// This code illustrates how to compute the current CloudSetup members from the previous, more intuitive (but less optimal) values:
	// float2 cloudScale = cloudSetup.ScaleUV_OffsetPerSecondUV.xy / 2;
	// float2 cloudOffsetPerSecond = cloudSetup.ScaleUV_OffsetPerSecondUV.zw;
	// CurrentOffsetUV = frac(Time * cloudOffsetPerSecond);
	// WorldPositionMultiplier_XYZZ = float4(cloudScale.xy, cloudScale.xy * cloudSetup.ProjectionDirection.xy / cloudSetup.ProjectionDirection.z

	float4 multipliedWP = WorldPosition.xyzz * cloudSetup.WorldPositionMultiplier_XYZZ;
	return multipliedWP.xy - multipliedWP.zw + cloudSetup.CurrentOffsetUV;
}

//
// Common shadow mapping setup, can be bound to "Sas.Shadow[?]" binding
//
struct ShadowSetup
{
	float4x4 WorldToShadow;
	float4 Zero_Zero_OneOverMapSize_OneOverMapSize; // The component layout is optimized so that ps_2_0 swizzles can be used
};

static const float shadowZBias = 0.0015; // Can use 0.001 with post processing pass

float4 CalculateShadowMapTexCoord(ShadowSetup shadowSetup, float3 worldPosition)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), shadowSetup.WorldToShadow);

	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

	return shadowTexCoord;
}

float4 CalculateShadowMapTexCoord_PerspectiveCorrect(ShadowSetup shadowSetup, float3 worldPosition)
{
	float4 shadowTexCoord = mul(float4(worldPosition, 1), shadowSetup.WorldToShadow);
	return shadowTexCoord;
}

//
// Shadow mapping look-up function. Similar to DXSAS prototype.
//
#define XENON_USE_PCF_16 // Note (WSK): Comment this out to disable using 16 PCF samples on xenon  
#if defined( EA_PLATFORM_XENON ) 

float g_fShadowSampleScale = 2.0;
float shadow(sampler2D shadowSampler, float4 shadowTexCoord, ShadowSetup shadowSetup)
{
	float2 t = shadowTexCoord.xy;

#if defined( XENON_USE_PCF_16 )

	float scale = shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.z / g_fShadowSampleScale;
	float sum = 0.0;

	float4 samples;
	samples = float4(
		tex2D(shadowSampler, t + scale * float2(-1.5, -1.5)).x,
		tex2D(shadowSampler, t + scale * float2(-1.5, -0.5)).x,
		tex2D(shadowSampler, t + scale * float2(-1.5,  0.5)).x,
		tex2D(shadowSampler, t + scale * float2(-1.5,  1.5)).x);

    sum += dot(1.0, step( shadowTexCoord.z, samples ));

	samples = float4(
		tex2D(shadowSampler, t + scale * float2(-0.5, -1.5)).x,
		tex2D(shadowSampler, t + scale * float2(-0.5, -0.5)).x,
		tex2D(shadowSampler, t + scale * float2(-0.5,  0.5)).x,
		tex2D(shadowSampler, t + scale * float2(-0.5,  1.5)).x);

    sum += dot(1.0, step( shadowTexCoord.z, samples ));

	samples = float4(
		tex2D(shadowSampler, t + scale * float2( 0.5, -1.5)).x,
		tex2D(shadowSampler, t + scale * float2( 0.5, -0.5)).x,
		tex2D(shadowSampler, t + scale * float2( 0.5,  0.5)).x,
		tex2D(shadowSampler, t + scale * float2( 0.5,  1.5)).x);

    sum += dot(1.0, step( shadowTexCoord.z, samples ));

	samples = float4(
		tex2D(shadowSampler, t + scale * float2( 1.5, -1.5)).x,
		tex2D(shadowSampler, t + scale * float2( 1.5, -0.5)).x,
		tex2D(shadowSampler, t + scale * float2( 1.5,  0.5)).x,
		tex2D(shadowSampler, t + scale * float2( 1.5,  1.5)).x);

    sum += dot(1.0, step( shadowTexCoord.z, samples ));

	return (sum / 16.0);

#else
	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.wz).x);
		
	bool4 bits = (samples - shadowTexCoord.z >= 0);

	//if (any(t <= 0.0 || t >= 1.0))
	//	bits = 1;
	
	return dot(1.0, bits) / 4.0;
#endif
}

#else // #if defined( EA_PLATFORM_XENON )

float shadow(sampler2D shadowSampler, float4 shadowTexCoord, ShadowSetup shadowSetup)
{
	float2 t = shadowTexCoord.xy;
		
	float depth = shadowTexCoord.z;
	
	/*
	float ooSize = 1.0 /1024.0;
	
	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + float2(0, ooSize)).x,
		tex2D(shadowSampler, t + float2(ooSize, 0)).x,
		tex2D(shadowSampler, t + float2(ooSize, ooSize)).x);
	*/

	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
		tex2D(shadowSampler, t + shadowSetup.Zero_Zero_OneOverMapSize_OneOverMapSize.wz).x);
		
	bool4 bits = (samples - depth >= 0);

	//if (any(t <= 0.0 || t >= 1.0))
	//	bits = 1;
	
	return dot(1.0, bits) / 4.0;
}

#endif // #if defined( EA_PLATFORM_XENON )

float shadow_PerspectiveCorrect(sampler2D shadowSampler, float4 shadowTexCoord, ShadowSetup shadowSetup)
{
	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

    return shadow(shadowSampler, shadowTexCoord, shadowSetup);
}

float shadowSimple(sampler2D shadowSampler, float4 shadowTexCoord, ShadowSetup shadowSetup)
{
	float2 t = shadowTexCoord.xy;
	float depth = shadowTexCoord.z;
	return tex2D(shadowSampler, t).x - depth >= 0;
}

#define shadow_sampler(ShadowMap) \
	sampler_state \
	{ \
		Texture = <ShadowMap>; \
		MinFilter = Point; \
		MagFilter = Point; \
		MipFilter = None; \
		AddressU = Clamp; \
		AddressV = Clamp; \
	}
	
#define SAMPLER_2D_SHADOW( shadowMapName ) \
	SAMPLER_2D_BEGIN( shadowMapName, \
		string UIWidget = "None"; \
		string SasBindAddress = "Sas.Shadow[0].ShadowMap"; \
		) \
		MinFilter = Point; \
		MagFilter = Point; \
		MipFilter = None; \
		AddressU = Clamp; \
		AddressV = Clamp; \
	SAMPLER_2D_END



//
// Light source definition helpers
//

#define DEFAULT_DIRECTIONAL_LIGHT_1 \
	{ float3(1.247, 1.207, 1.043), float3(0.62914, -0.34874, 0.69465) }
#define DEFAULT_DIRECTIONAL_LIGHT_2 \
	{ float3(0.745, 0.831, 0.894), float3(-0.32877, 0.90329, 0.27563) }
#define DEFAULT_DIRECTIONAL_LIGHT_3 \
	{ float3(0.690, 0.667, 0.690), float3(-0.80704, -0.58635, 0.06975) }

#define DEFAULT_DIRECTIONAL_LIGHT_DISABLED \
	{ float3(0, 0, 0), float3(0, 0, 1) }
	
#define DEFAULT_POINT_LIGHT_DISABLED \
	{ float3(0, 0, 0), float3(0, 0, 0), 0 }


float CalculatePointLightAttenuation(SasPointLight light, float lightDistance)
{
#if 0
	// This is the "old" way lighting attenuation is computed for fixed-function WW3D rendering
	
	float a = 1.0; // "Inner radius"
	float b = light.Range; // "Outer radius"

	float3 attenuationFactors;
	attenuationFactors.x = 1.0;
	if (abs(a - b) < 1e-5)
	{
		// if the attenuation range is too small assume uniform with cutoff
		attenuationFactors.y = 0.0;
	}
	else
	{
		// this will cause the light to drop to half intensity at the first far attenuation
		attenuationFactors.y = 0.1 / a;
	}

	attenuationFactors.z = 8.0 / (b * b);
	
	float attenuation = 1.0 / dot(attenuationFactors, float3(1, lightDistance, lightDistance * lightDistance));
	
	if (lightDistance > b)
		attenuation = 0.0;

	return attenuation;
#else
	// This is the new way.

	// Make a squared fall-off
	float attenuation = max(0, 1.0 - lightDistance / light.Range);
	attenuation *= attenuation;

	return attenuation;
#endif
}
	

#if (defined(_3DSMAX_) || defined(_FX_COMPOSER_)) && defined(USE_INTERACTIVE_LIGHTS)

#define DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex) \
	float3 lightName##lightIndex : Direction < \
    	string Object = "DirectionalLight"; \
    	string Space = "World"; \
		string UIName = "Directional Light " #lightIndex; \
	> = float3(0, 0, -1);

#define USE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex) \
	lightName[lightIndex].Direction = lightName##lightIndex;


#define DECLARE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) \
	float3 lightName##lightIndex : Position < \
    	string Object = "PointLight"; \
    	string Space = "World"; \
		string UIName = "Point Light " #lightIndex; \
	> = float3(0, 0, 0);

#define USE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) \
	lightName[lightIndex].Position = lightName##lightIndex;

#else

#define DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex)
#define USE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex)

#define DECLARE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex)
#define USE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex)

#endif


//
// Declare constants with nice UI, since Max lacks creating spinners for vector variable
// Example usage:
//	DECLARE_FLOAT2(foo, 1.0f, 1.0f);
//	DECLARE_FLOAT2_CUSTOM(bar, 1.0f, 1.0f, float UIMin = 0.5; float UIMax = 1.0; float UIStep = 0.1);
//

#define DECLARE_FLOAT2(varName, defaultX, defaultY) \
	DECLARE_FLOAT2_CUSTOM(varName, defaultX, defaultY, int __unused = 0)
	
#define DECLARE_FLOAT3(varName, defaultX, defaultY, defaultZ) \
	DECLARE_FLOAT3_CUSTOM(varName, defaultX, defaultY, defaultZ, int __unused = 0)
	
#define DECLARE_FLOAT4(varName, defaultX, defaultY, defaultZ, defaultW) \
	DECLARE_FLOAT4_CUSTOM(varName, defaultX, defaultY, defaultZ, defaultW, int __unused = 0)


#if defined(_WW3D_) || defined(_FX_COMPOSER_)


#define DECLARE_FLOAT2_CUSTOM(varName, defaultX, defaultY, additionalAnnotations) \
	float2 varName = float2(defaultX, defaultY)
	
#define DECLARE_FLOAT3_CUSTOM(varName, defaultX, defaultY, defaultZ, additionalAnnotations) \
	float3 varName = float3(defaultX, defaultY, defaultZ)

#define DECLARE_FLOAT4_CUSTOM(varName, defaultX, defaultY, defaultZ, defaultW, additionalAnnotations) \
	float4 varName = float4(defaultX, defaultY, defaultZ, defaultW)

#define USE_FLOAT2(varName)
#define USE_FLOAT3(varName)
#define USE_FLOAT4(varName)


#else // !_WW3D_ i.e. this is when compiling in 3DS Max


#define DECLARE_FLOAT2_CUSTOM(varName, defaultX, defaultY, additionalAnnotations) \
	float varName##__X < \
		string UIName = #varName ".x"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultX); \
	float varName##__Y < \
		string UIName = #varName ".y"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultY)

#define DECLARE_FLOAT3_CUSTOM(varName, defaultX, defaultY, defaultZ, additionalAnnotations) \
	float varName##__X < \
		string UIName = #varName ".x"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultX); \
	float varName##__Y < \
		string UIName = #varName ".y"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultY); \
	float varName##__Z < \
		string UIName = #varName ".z"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultZ)

#define DECLARE_FLOAT4_CUSTOM(varName, defaultX, defaultY, defaultZ, defaultW, additionalAnnotations) \
	float varName##__X < \
		string UIName = #varName ".x"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultX); \
	float varName##__Y < \
		string UIName = #varName ".y"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultY); \
	float varName##__Z < \
		string UIName = #varName ".z"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultZ); \
	float varName##__W < \
		string UIName = #varName ".w"; \
		string UIType = "FloatSpinner"; \
		additionalAnnotations; \
	> = float(defaultW)
	
#define USE_FLOAT2(varName) float2 varName = float2(varName##__X, varName##__Y)
#define USE_FLOAT3(varName) float3 varName = float3(varName##__X, varName##__Y, varName##__Z)
#define USE_FLOAT4(varName) float4 varName = float4(varName##__X, varName##__Y, varName##__Z, varName##__W)

#endif



#endif // Include guard
