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

// The following macro is used to control the boolean-based shader permutations
// The STATICBOOL macro can be wrapped around global bool's that you want the RNAFX compiler to
// automatically create true/false shader permutations for (removing static/dynamic/predicated code).
#ifndef STATICBOOL
#define STATICBOOL(exprn) exprn
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

#if defined(EA_PLATFORM_PS3)
#if SUPPORT_LOCAL_LIGHTS
	// Use the pointlight attenutation
	#define USE_POINTLIGHT_ATTENUATION_INFO
	#define PERMUTE_LIGHTS
	// Enabling 3 bit permutation takes a lot more time and memory
	//#define PERMUTE_LIGHTS_3BIT
#endif
#endif // #if defined(EA_PLATFORM_PS3)


#if defined(PERMUTE_LIGHTS)
STATICBOOL(bool sPointLightsBit0
<
	string UIWidget = "None";
> = false;)
STATICBOOL(bool sPointLightsBit1
<
	string UIWidget = "None";
> = false;)
#if PERMUTE_LIGHTS_3BIT
STATICBOOL(bool sPointLightsBit2
<
	string UIWidget = "None";
> = false;)
#endif // if PERMUTE_LIGHTS_3BIT
#endif // if defined(PERMUTE_LIGHTS)

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
	#define ZFUNC_BEHIND  GreaterEqual
#else
	#define ZFUNC_INFRONT GreaterEqual
	#define ZFUNC_BEHIND  LessEqual
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
#define DEFAULT_CLOUD float4(0, 0, 0, 0)

// Calculate the texture coordinates for cloud lookup
float2 CalculateCloudTexCoord(float4 worldPositionMultiplier_XYZZ, float4 currentOffsetUV, float3 worldPosition, float Time)
{
	float4 multipliedWP = worldPosition.xyzz * worldPositionMultiplier_XYZZ;
	return multipliedWP.xy - multipliedWP.zw + currentOffsetUV.xy;
}

//
// Light source definition helpers
//

// the maximum number of directional and point
// lights supported in the shaders
#define NumDirectionalLights	3
#define MaxNumPointLights		8
// Maximum number of Point Lights Groups, should be ceil(MaxNumPointLights/4)
#define MaxPointLightGroups		2

// allow the pow instruction to be used with the HLSL compiler only, with
// sce-cgc it will only allow constant expressions in initializer lists.
#if !defined(EA_PLATFORM_PS3)
	#define DEFAULT_DIRECTIONAL_LIGHT_1 \
		{ pow(float4(1.247, 1.207, 1.043, 0.0f), 2.2), float4(0.62914, -0.34874, 0.69465, 0.0f) }
	#define DEFAULT_DIRECTIONAL_LIGHT_2 \
		{ pow(float4(0.745, 0.831, 0.894, 0.0f), 2.2), float4(-0.32877, 0.90329, 0.27563, 0.0f) }
	#define DEFAULT_DIRECTIONAL_LIGHT_3 \
		{ pow(float4(0.690, 0.667, 0.690, 0.0f), 2.2), float4(-0.80704, -0.58635, 0.06975, 0.0f) }
#else
	#define DEFAULT_DIRECTIONAL_LIGHT_1 \
		{ float4(1.625, 1.513, 1.097, 0.0f), float4(0.62914, -0.34874, 0.69465, 0.0f) }
	#define DEFAULT_DIRECTIONAL_LIGHT_2 \
		{ float4(0.5233, 0.6655, 0.7816, 0.0f), float4(-0.32877, 0.90329, 0.27563, 0.0f) }
	#define DEFAULT_DIRECTIONAL_LIGHT_3 \
		{ float4(0.4420, 0.4103, 0.4420, 0.0f), float4(-0.80704, -0.58635, 0.06975, 0.0f) }
#endif

#define DEFAULT_DIRECTIONAL_LIGHT_DISABLED \
	{ float4(0, 0, 0, 0), float4(0, 0, 1, 0) }
	
#define DEFAULT_POINT_LIGHT_DISABLED \
	{ float4(0, 0, 0, 0), float4(0, 0, 0, 0) }
	
float CalculatePointLightAttenuation(SasPointLight light, float lightDistance)
{
	float innerRange = light.Color.w;
	float outerRange = light.Position.w;
	
	// Make a squared fall-off
	float attenuation = saturate(1.0 - (lightDistance - innerRange) / (outerRange - innerRange));
	attenuation *= attenuation;

	return attenuation;
}

float3 CalculatePointLightDiffuse(SasPointLight light, float3 worldPosition, float3 worldNormal)
{
	float3 direction = light.Position.xyz - worldPosition;
	float lightDistance = length(direction);
	direction /= lightDistance;

	float attenuation = CalculatePointLightAttenuation(light, lightDistance);
	
	return light.Color.xyz * attenuation * max(dot(worldNormal, direction), 0);
}

float3 CalculatePointLightDiffuse1 ( SasPointLight light[1], float innerRange, float oneOverFalloffDistance, float3 worldPosition, float3 worldNormal)
{
	float3 direction0 = light[0].Position.xyz - worldPosition;
	float  lightDistance = length(direction0);
	
	direction0 /= lightDistance;

	// Make a squared fall-off
	float attenuation = saturate(1.0 - (lightDistance - innerRange) * oneOverFalloffDistance);
	attenuation *= attenuation;

	return light[0].Color.xyz * attenuation * saturate(dot(worldNormal, direction0));
}

float3 CalculatePointLightDiffuse2 ( SasPointLight light[2], float2 innerRange, float2 oneOverFalloffDistance, float3 worldPosition, float3 worldNormal)
{
	float3 direction0 = light[0].Position.xyz - worldPosition;
	float3 direction1 = light[1].Position.xyz - worldPosition;
	
	float2 lightDistance;
	lightDistance.x = length(direction0);
	lightDistance.y = length(direction1);
	
	direction0 /= lightDistance.x;
	direction1 /= lightDistance.y;

	// Make a squared fall-off
	float2 attenuation = saturate(1.0 - (lightDistance - innerRange) * oneOverFalloffDistance);
	attenuation *= attenuation;

	return 
		light[0].Color.xyz * attenuation.x * saturate(dot(worldNormal, direction0))
	+	light[1].Color.xyz * attenuation.y * saturate(dot(worldNormal, direction1));
}

float3 CalculatePointLightDiffuse3 ( SasPointLight light[3], float3 innerRange, float3 oneOverFalloffDistance, float3 worldPosition, float3 worldNormal)
{
	float3 direction0 = light[0].Position.xyz - worldPosition;
	float3 direction1 = light[1].Position.xyz - worldPosition;
	float3 direction2 = light[2].Position.xyz - worldPosition;
	
	float3 lightDistance;
	lightDistance.x = length(direction0);
	lightDistance.y = length(direction1);
	lightDistance.z = length(direction2);
	
	direction0 /= lightDistance.x;
	direction1 /= lightDistance.y;
	direction2 /= lightDistance.z;

	// Make a squared fall-off
	float3 attenuation = saturate(1.0 - (lightDistance - innerRange) * oneOverFalloffDistance);
	attenuation *= attenuation;

	return 
		light[0].Color.xyz * attenuation.x * saturate(dot(worldNormal, direction0))
	+	light[1].Color.xyz * attenuation.y * saturate(dot(worldNormal, direction1))
	+	light[2].Color.xyz * attenuation.z * saturate(dot(worldNormal, direction2));
}


float3 CalculatePointLightDiffuse4 ( SasPointLight light[4], float4 innerRange, float4 oneOverFalloffDistance, float3 worldPosition, float3 worldNormal)
{
	float3 direction0 = light[0].Position.xyz - worldPosition;
	float3 direction1 = light[1].Position.xyz - worldPosition;
	float3 direction2 = light[2].Position.xyz - worldPosition;
	float3 direction3 = light[3].Position.xyz - worldPosition;
	
	float4 lightDistance;
	lightDistance.x = length(direction0);
	lightDistance.y = length(direction1);
	lightDistance.z = length(direction2);
	lightDistance.w = length(direction3);
	
	direction0 /= lightDistance.x;
	direction1 /= lightDistance.y;
	direction2 /= lightDistance.z;
	direction3 /= lightDistance.w;

	// Make a squared fall-off
	float4 attenuation = saturate(1.0 - (lightDistance - innerRange) * oneOverFalloffDistance);
	attenuation *= attenuation;

	return 
		light[0].Color.xyz * attenuation.x * saturate(dot(worldNormal, direction0))
	+	light[1].Color.xyz * attenuation.y * saturate(dot(worldNormal, direction1))
	+	light[2].Color.xyz * attenuation.z * saturate(dot(worldNormal, direction2))
	+	light[3].Color.xyz * attenuation.w * saturate(dot(worldNormal, direction3));
}
	
#if (defined(_3DSMAX_) || defined(_FX_COMPOSER_)) && defined(USE_INTERACTIVE_LIGHTS)

#define DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName) \
	float3 lightName : Direction < \
    	string Object = "DirectionalLight"; \
    	string Space = "World"; \
		string UIName = "Directional Light " #lightIndex; \
	> = float3(0, 0, -1);

// $note (WSK) 2009/03/18 - The interactive light seems to be broken when we change the lights from DirectionLight[0] to DirectionLight_0
//							So we are hard coding the light to white so artist can keep on working, but we should fix this.
#define USE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName) \
	lightName##_Direction.xyz = lightName; \
	lightName##_Color = 1.0;

#define DECLARE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) \
	float3 lightName##lightIndex : Position < \
    	string Object = "PointLight"; \
    	string Space = "World"; \
		string UIName = "Point Light " #lightIndex; \
	> = float3(0, 0, 0);

#define USE_POINT_LIGHT_INTERACTIVE(lightName, lightIndex) \
	lightName[lightIndex].Position = lightName##lightIndex;

#else

#define DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName) static const int dummyDeclareDirectionalLight = 0
#define USE_DIRECTIONAL_LIGHT_INTERACTIVE(lightName) static const int dummyUseDirectionalLight = 0

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
// Depth sections
//

#if defined(EA_PLATFORM_PS3)
   #define TexDepth2D         texDepth2D
#else // #if defined(EA_PLATFORM_PS3)
   #define TexDepth2D         tex2D
#endif // #if defined(EA_PLATFORM_PS3)

//
// Global Parameters sections
//
// We need to include this with all shaders ssince with the USE_INDIRECT_CONSTANT, we need to reserved the registers even 
//  for the shaders that don't use those constants to avoid stomping of those registers.

#include "GlobalParameters.fxh"

float3 CalculatePointLights(int count, float3 pos, float3 normal)
{
	float3 diffuseLight = 0;
	
#if defined(SUPPORT_LOCAL_LIGHTS)

	#if defined(USE_POINTLIGHT_ATTENUATION_INFO)
	
	#if defined(PERMUTE_LIGHTS)
	// This uses static bools to statically permute 0-8 lights 
	// this takes ages to compile however... Disable it in local builds.
	int NumLights = 0;
#if defined(PERMUTE_LIGHTS_3BIT)
	#define DOSETUPLIGHT( b2, b1, b0, value) if(sPointLightsBit0 == b0 && sPointLightsBit1 == b1 && sPointLightsBit2 == b2){NumLights = value;}
	DOSETUPLIGHT(false, false, false, 0);
	DOSETUPLIGHT(false, false, true , 1);
	DOSETUPLIGHT(false, true , false, 2);
	DOSETUPLIGHT(false, true , true , 3);
	DOSETUPLIGHT(true , false, false, 4);
	DOSETUPLIGHT(true , false, true , 5);
	DOSETUPLIGHT(true , true , false, 6);
	DOSETUPLIGHT(true , true , true , 8);
#else // defined(PERMUTE_LIGHTS_3BIT)
	#define DOSETUPLIGHT( b1, b0, value) if(sPointLightsBit0 == b0 && sPointLightsBit1 == b1){NumLights = value;}
	DOSETUPLIGHT(false, false, 0);
	DOSETUPLIGHT(false, true , 1);
	DOSETUPLIGHT(true , false, 2);
	DOSETUPLIGHT(true , true , 8); // Fall Back to 8 in rare cases.
#endif // PERMUTE_LIGHTS_3BIT

	if(NumLights > 0)
	{
		if(NumLights == 1)
		{
			SasPointLight lights[1];
			lights[0] = PointLight[0];
			diffuseLight += CalculatePointLightDiffuse1(lights, PointLightsAttenuationInfo[0].InnerRanges.x, PointLightsAttenuationInfo[0].OneOverFalloffDistance.x, pos, normal);
		}
		else if(NumLights == 2)
		{
			SasPointLight lights[2];
			lights[0] = PointLight[0];
			lights[1] = PointLight[1];
			diffuseLight += CalculatePointLightDiffuse2(lights, PointLightsAttenuationInfo[0].InnerRanges.xy, PointLightsAttenuationInfo[0].OneOverFalloffDistance.xy, pos, normal);
		}
		else if(NumLights == 3)
		{
			SasPointLight lights[3];
			lights[0] = PointLight[0];
			lights[1] = PointLight[1];
			lights[2] = PointLight[2];
			diffuseLight += CalculatePointLightDiffuse3(lights, PointLightsAttenuationInfo[0].InnerRanges.xyz, PointLightsAttenuationInfo[0].OneOverFalloffDistance.xyz, pos, normal);
		}
		else if(NumLights >= 4)
		{
			SasPointLight lights[4];
			lights[0] = PointLight[0];
			lights[1] = PointLight[1];
			lights[2] = PointLight[2];
			lights[3] = PointLight[3];
			diffuseLight += CalculatePointLightDiffuse4(lights, PointLightsAttenuationInfo[0].InnerRanges, PointLightsAttenuationInfo[0].OneOverFalloffDistance, pos, normal);
		}
		if(NumLights == 5)
		{
			SasPointLight lights[1];
			lights[0] = PointLight[4+0];
			diffuseLight += CalculatePointLightDiffuse1(lights, PointLightsAttenuationInfo[1].InnerRanges.x, PointLightsAttenuationInfo[1].OneOverFalloffDistance.x, pos, normal);
		}
		else if(NumLights == 6)
		{
			SasPointLight lights[2];
			lights[0] = PointLight[4+0];
			lights[1] = PointLight[4+1];
			diffuseLight += CalculatePointLightDiffuse2(lights, PointLightsAttenuationInfo[1].InnerRanges.xy, PointLightsAttenuationInfo[1].OneOverFalloffDistance.xy, pos, normal);
		}
		else if(NumLights == 7)
		{
			SasPointLight lights[3];
			lights[0] = PointLight[4+0];
			lights[1] = PointLight[4+1];
			lights[2] = PointLight[4+2];
			diffuseLight += CalculatePointLightDiffuse3(lights, PointLightsAttenuationInfo[1].InnerRanges.xyz, PointLightsAttenuationInfo[1].OneOverFalloffDistance.xyz, pos, normal);
		}
		else if(NumLights == 8)
		{
			SasPointLight lights[4];
			lights[0] = PointLight[4+0];
			lights[1] = PointLight[4+1];
			lights[2] = PointLight[4+2];
			lights[3] = PointLight[4+3];
			diffuseLight += CalculatePointLightDiffuse4(lights, PointLightsAttenuationInfo[1].InnerRanges.xyzw, PointLightsAttenuationInfo[1].OneOverFalloffDistance.xyzw, pos, normal);
		}
	}
	#else // defined(PERMUTE_LIGHTS)
	// This is non-permuted lights for ps3
	SasPointLight lights[4];
	for(int i=0; i<MaxPointLightGroups; ++i)
	{
		lights[0] = PointLight[i*4];
				lights[1] = PointLight[i*4+1];
				lights[2] = PointLight[i*4+2];
				lights[3] = PointLight[i*4+3];
				diffuseLight += CalculatePointLightDiffuse4(lights, PointLightsAttenuationInfo[i].InnerRanges, PointLightsAttenuationInfo[i].OneOverFalloffDistance, pos, normal);
	}
	#endif // defined(PERMUTE_LIGHTS)
	
	#else // #if defined(USE_POINTLIGHT_ATTENUATION_INFO)
		for (int i = 0; i < count; i++)
		{
			diffuseLight += CalculatePointLightDiffuse(PointLight[i], pos, normal);
		}
	#endif // #if defined(USE_POINTLIGHT_ATTENUATION_INFO)

#endif // #if defined(SUPPORT_LOCAL_LIGHTS)

	return diffuseLight;
}

//
// Helper functions
// Utility function for converting vPos (like 1280x720 etc) to texture coord (0-1 range)
//

float2 OneOverFrameBufferSize
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OneOverFrameBufferSize";
> = float2(0.0f, 0.0f);

float2 GetScreenTexcoordCoord(float2 vPos)
{
	return (vPos + float2(0.5f,0.5f)) * OneOverFrameBufferSize;
}

//
// Common map border computation
//

float4 MapBorderOctBoundary
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.OctBoundary";
> = float4(1000.0f, 1000.0f, 1000.0f, 1000.0f);

float MapBorderWidth
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.BorderWidth";
> = 0.0f;

float4x4 OctAltCoordTransform
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.OctAltCoodTransform";
>;

// This is the value of the map border alpha at the edge of the visible area, needed to be < 1.0 or else the whole alpha get inverted.
static const float MAP_BORDER_INNER_EDGE_ALPHA = 0.4;

float4 CalcMapBorderCoefficientX2()
{
	// Calculate the map border coefficient, this is basically a parabola y=ax^2+bx+c, which pass through (-m, 1), (0,h), and (s,h)
	// MapSize actually included the MapBorderWidth on both size.
	// float2 s = MapSize-2*MapBorderWidth;
	// float  h = MAP_BORDER_INNER_EDGE_ALPHA;
	float m = MapBorderWidth;
	float edgeOpacity = 1-MAP_BORDER_INNER_EDGE_ALPHA; // this is (1-h)
	float4 MapBorderCoefficientX2	= float4(edgeOpacity,edgeOpacity,edgeOpacity,edgeOpacity) / (m.xxxx * MapBorderOctBoundary - m.xxxx * m.xxxx);
	return MapBorderCoefficientX2;
}

float4 CalcMapBorderCoefficientX()
{
	// Calculate the map border coefficient, this is basically a parabola y=ax^2+bx+c, which pass through (-m, 1), (0,h), and (s,h)
	// MapSize actually included the MapBorderWidth on both size.
	// float2 s = MapSize-2*MapBorderWidth;
	// float  h = MAP_BORDER_INNER_EDGE_ALPHA;
	float m = MapBorderWidth;
	float edgeOpacity = 1-MAP_BORDER_INNER_EDGE_ALPHA; // this is (1-h)
	float4 MapBorderCoefficientX	= edgeOpacity * (-MapBorderOctBoundary) / (m.xxxx * MapBorderOctBoundary - m.xxxx * m.xxxx);
	return MapBorderCoefficientX;
}

float CalcMapBorderFactor(float4 MapBorderCoefficientX2, float4 MapBorderCoefficientX, float3 WorldPosition)
{
	// Calculate the world position in the 45 degree rotated coordinate
	float4 altWorldPosition = mul(float4(WorldPosition, 1.0), OctAltCoordTransform);

	// Combining the 2d position (x and y) since the map border only care about 2d
	float4 pos_World_AltWorld = float4(WorldPosition.xy, altWorldPosition.xy);

	// Calculating the map border factor where 1 will be at the very edge and 0 be inside
	float4 fadeMapBorder = MapBorderCoefficientX2 * pos_World_AltWorld * pos_World_AltWorld + MapBorderCoefficientX * pos_World_AltWorld + MAP_BORDER_INNER_EDGE_ALPHA;
	float2 fadeMapBorderMax = max(fadeMapBorder.xy, fadeMapBorder.zw);
	float mapBorderFactor = saturate(max(fadeMapBorderMax.x, fadeMapBorderMax.y));

	// Clear the alpha inside the playable area so there is a pretty clear seperation for the border
	if(mapBorderFactor <= MAP_BORDER_INNER_EDGE_ALPHA)
	{
		mapBorderFactor = 0.0;
	}
	return (1.0-mapBorderFactor);
}

//
// Common Terrain Top View tex coord computation
//

float4 ScorchMarkUVOffsetMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.ScorchMarkUVOffsetMultiplier";
> = float4(0,0,1,1);

float2 CalcTerrainTopViewTexCoord(float2 WorldPositionXY)
{
	float2 TerrainTopViewTexCoord = saturate((WorldPositionXY - ScorchMarkUVOffsetMultiplier.xy)*ScorchMarkUVOffsetMultiplier.zw);
	TerrainTopViewTexCoord.y = 1.0f - TerrainTopViewTexCoord.y;
	return TerrainTopViewTexCoord;
}

#endif // Include guard
