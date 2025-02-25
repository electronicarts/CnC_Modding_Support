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
#elif defined( EA_PLATFORM_PS3 )
#include "ps3_macros.fxh"
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

// Tell RNA to assume everything that isn't marked by a semantic/annotation is a material parameter.
string DefaultParameterScopeBlock = "material";

//
// Expression evaluator system.
// Allows shaders to hook up to CPU code to assign render states or shader constants
//
// To disable expression evaluators for a file temporarily, define the DISABLE_EXPRESSION_EVALUATORS macro

#if !defined(_WW3D_) || defined(DISABLE_EXPRESSION_EVALUATORS)
	#define EXPRESSION_EVALUATOR_ENABLED 0
#else
	#define EXPRESSION_EVALUATOR_ENABLED 1
#endif

#if EXPRESSION_EVALUATOR_ENABLED
	#define USE_EXPRESSION_EVALUATOR(name) string ExpressionEvaluator = name;
#else
	#define USE_EXPRESSION_EVALUATOR(name)
#endif


#if defined(EA_PLATFORM_XENON) || defined(EA_PLATFORM_PS3)
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
	// [LLatta 2007-09-13] Let's not use expression evaluators for arrays at the moment, reevaluate the overhead this can have later.
	#if 0 // EXPRESSION_EVALUATOR_ENABLED

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

	#define COLORTARGET : COLOR
	
#else // !SUPPORT_SHADER_ARRAYS
	#define ARRAY_EXPRESSION_DIRECT_VS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_DIRECT_PS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_VS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative
	#define ARRAY_EXPRESSION_PS(arrayName, expression, noArraySupportAlternative) noArraySupportAlternative

	#define DEFINE_ARRAY_MULTIPLIER(initializer) static const int initializer
	
	#define COLORTARGET
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


// Isolate 
#if defined(EA_PLATFORM_XENON)
#define ISOLATE [isolate]
#else
#define ISOLATE
#endif


// Static
// 'sce-cgc' does not like 'static const' on arrays.
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
#define STATICARRAY static
#else
#define STATICARRAY
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
// InstancingMode values
// Use in SasGlobal annotation for MaxSupportedInstancingMode
//
#define INSTANCING_MODE_NONE 0
#define INSTANCING_MODE_ONE_PER_DRAW_CALL 1
#define INSTANCING_MODE_MATRIX_STREAM 2


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

// Fog has been globally disabled now. By making it static const it will compile out for the most part now.
#if SUPPORT_FOG
static const WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;
#endif

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
// Light source definition helpers
//

#define DEFAULT_DIRECTIONAL_LIGHT_1 \
	{ pow(float3(1.247, 1.207, 1.043), 2.2), float3(0.62914, -0.34874, 0.69465) }
#define DEFAULT_DIRECTIONAL_LIGHT_2 \
	{ pow(float3(0.745, 0.831, 0.894), 2.2), float3(-0.32877, 0.90329, 0.27563) }
#define DEFAULT_DIRECTIONAL_LIGHT_3 \
	{ pow(float3(0.690, 0.667, 0.690), 2.2), float3(-0.80704, -0.58635, 0.06975) }

#define DEFAULT_DIRECTIONAL_LIGHT_DISABLED \
	{ float3(0, 0, 0), float3(0, 0, 1) }
	
#define DEFAULT_POINT_LIGHT_DISABLED \
	{ float3(0, 0, 0), float3(0, 0, 0), float2(0, 0) }


float CalculatePointLightAttenuation(SasPointLight light, float lightDistance)
{
	float innerRange = light.Range_Inner_Outer.x;
	float outerRange = light.Range_Inner_Outer.y;
	
	// Make a squared fall-off
	float attenuation = saturate(1.0 - (lightDistance - innerRange) / (outerRange - innerRange));
	attenuation *= attenuation;

	return attenuation;
}

float3 CalculatePointLightDiffuse(SasPointLight light, float3 worldPosition, float3 worldNormal)
{
	float3 direction = light.Position - worldPosition;
	float lightDistance = length(direction);
	direction /= lightDistance;

	float attenuation = CalculatePointLightAttenuation(light, lightDistance);
	
	return light.Color * attenuation * max(dot(worldNormal, direction), 0);
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

#define DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex) static const int dummyDeclareDirectionalLight = 0
#define USE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName, lightIndex) static const int dummyUseDirectionalLight = 0

#define DECLARE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) static const int dummyDeclarePointLight = 0
#define USE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) static const int dummyUsePointLight = 0

#endif


//
// Macros to add support for multiple texture coordinates and vertex colors/alpah in 3DSMax
//

#if defined(_3DSMAX_)

	#define DECLARE_MAPPING_TEXCOORD(texcoordIndex) \
		int _3DSTexcoordMapping##texcoordIndex : Texcoord \
		< \
			int Texcoord = texcoordIndex; \
			int MapChannel = 1 + texcoordIndex; \
			string UIWidget = "None"; \
		>;
		
	#define DECLARE_MAPPING_VERTEXCOLOR(firstTexcoordIndex, secondTexCoordIndex) \
		int _3DSTexcoordMappingVertexColor : Texcoord \
		< \
			int Texcoord = firstTexcoordIndex; \
			int MapChannel = 0; \
			string UIWidget = "None"; \
		>; \
		int _3DSTexcoordMappingVertexAlpha : Texcoord \
		< \
			int Texcoord = secondTexCoordIndex; \
			int MapChannel = -2; \
			string UIWidget = "None"; \
		>;

	#define DECLARE_VERTEXCOLOR_INPUT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
		float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex, \
		float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex

	#define DECLARE_VERTEXCOLOR_INPUT_STRUCT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
		float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex; \
		float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex
		
	#define PASS_THROUGH_VERTEXCOLOR(variableName) _3DSVertexColor, _3DSVertexAlpha

	#define USE_VERTEXCOLOR(variableName) \
		float4 variableName = float4(_3DSVertexColor, _3DSVertexAlpha)

	// Seems 3DSMax subtracts 1 from the v coordinate. Go figure.
	#define USE_TEXCOORD(variableName) \
		variableName.y = 1 + variableName.y
		
#else // !defined _3DSMAX_

	#define DECLARE_MAPPING_TEXCOORD(texcoordIndex)
	#define DECLARE_MAPPING_VERTEXCOLOR(firstTexcoordIndex, secondTexCoordIndex)

	#define DECLARE_VERTEXCOLOR_INPUT(variableName, firstTexCoord, secondTexCoordIndex) \
		float4 variableName : COLOR0
	#define DECLARE_VERTEXCOLOR_INPUT_STRUCT(variableName, firstTexCoord, secondTexCoordIndex) \
		float4 variableName : COLOR0

	#define PASS_THROUGH_VERTEXCOLOR(variableName) variableName

	// Dummy definitions. Could be defined as nothing, this way they ensure a minimal syntax correctness.
	#define USE_VERTEXCOLOR(variableName) variableName
	#define USE_TEXCOORD(variableName) variableName
	
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

//
// Global Parameters sections
//
// We need to include this with all shaders ssince with the USE_INDIRECT_CONSTANT, we need to reserved the registers even 
//  for the shaders that don't use those constants to avoid stomping of those registers.

#include "GlobalParameters.fxh"

#endif // Include guard
