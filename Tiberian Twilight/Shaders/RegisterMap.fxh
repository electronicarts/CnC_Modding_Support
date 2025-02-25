//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Register Mapping header
//////////////////////////////////////////////////////////////////////////////

#ifndef _REGISTERMAP_FXH_
#define _REGISTERMAP_FXH_

//////////////////////////////////////////////////////////////////////////////
// Define to indicate whether to use indirect constant or not
//////////////////////////////////////////////////////////////////////////////
#if !defined(EA_PLATFORM_PS3) && !defined(_3DSMAX_)
#define USE_INDIRECT_CONSTANT
#endif // !defined(_3DSMAX_)

//////////////////////////////////////////////////////////////////////////////
// Float constant registers
//////////////////////////////////////////////////////////////////////////////

// Why are these register numbers all over the place? Why not just declare them starting with 0 upwards?
// There is a problem with PS2.0 shaders: They can only support 32 constant registers.
// In total we have much more than that, but our PS2.0 shaders themselves use less than 32 registers.
// By moving all the registers we need in PS2.0 into the range of 0-31 these shaders compile.
// All registers that are not used there then can be put into the range above 32 without problems.
// To leave the largest possible "unmapped" area in the middle, let's assign those registers backwards from 255.


// Skinning
#define MaxSkinningBones 64 // Every bone uses 2 registers each, ie 128 registers total
#define REGISTER_SKINNING_BONE_TRANSFORMS           128 // up to 255
#define REGISTER_NON_SKINNING_WORLD_MATRIX_FIRST    124
#define REGISTER_NON_SKINNING_WORLD_MATRIX_LAST     127

#if defined(EA_PLATFORM_PS3)
// $note (WSK) 2008/11/07 - turn this off since it seems to fill up fifo too much and cause gpu hang
//							could try this back when we fix either 1) uploading of constants in one chunk (vs 4 at a time now) or 2) using indirect constants (this is needed by vertex shader only)
//    #define USE_MATRIX_FOR_SKINNING
#endif // #if defined(EA_PLATFORM_PS3)

#if defined(USE_MATRIX_FOR_SKINNING)
	#define NUM_CONSTANTS_PER_BONE 4
#else // #if defined(USE_MATRIX_FOR_SKINNING)
	#define NUM_CONSTANTS_PER_BONE 2
#endif // #if defined(USE_MATRIX_FOR_SKINNING)

// Camera related
#define REGISTER_CAMERA_POSITION                    123
#define REGISTER_VIEWPROJECTION_MATRIX_LAST         122
#define REGISTER_VIEWPROJECTION_MATRIX_FIRST        119

// Color
#define REGISTER_RECOLOR_COLOR                      0
#define REGISTER_RECOLOR_SECONDARY_COLOR            1
#define REGISTER_OPACITY_OVERRIDE                   2
#define REGISTER_TINT_COLOR                         3

// Cloud related
#define REGISTER_CLOUD_CURRENTOFFSETUV				118
#define REGISTER_CLOUD_WORLDPOSITIONMULTIPLIER_XYZZ 117
#define REGISTER_NO_CLOUD_MULTIPLIER                4

// Shadowmap
#define REGISTER_MAT_WORLD_TO_SHADOW                113 // 4 registers

// Lighting
#define REGISTER_AMBIENT_LIGHT_COLOR                5
#define REGISTER_DIRECTIONAL_LIGHT0_FIRST           6	// 2 registers
#define REGISTER_DIRECTIONAL_LIGHT0_LAST			7	// 2 registers
#define REGISTER_DIRECTIONAL_LIGHT1_FIRST           8	// 2 registers
#define REGISTER_DIRECTIONAL_LIGHT1_LAST			9	// 2 registers
#define REGISTER_DIRECTIONAL_LIGHT2_FIRST           10	// 2 registers
#define REGISTER_DIRECTIONAL_LIGHT2_LAST			11	// 2 registers
#define REGISTER_POINT_LIGHTS_LAST                  105
#define REGISTER_POINT_LIGHTS_FIRST                 89	// 16 registers

// Particle Vertex Corners
#define MAX_VERTICES_PER_PARTICLE 9
#define REGISTER_VERTEXCORNERS_LAST					88
#define REGISTER_VERTEXCORNERS_FIRST				79 // 9 (MAX_VERTICES_PER_PARTICLE) registers



// Particle - For ps3, we use indirect constant to upload the ParticleDraw struct in CommonParticle.fxh.
//            One thing to watch out for is that on ps3, these works now because they are only referenced in the vertex shaders.
//            If we ever need them to access them from the pixel shaders, we need to either 1) fix uploading of the fragment shader constants
//            or 2) pull the variables out of this structure (refer to Draw.ShaderType for example)

// We allow only four keyframes on color and no alpha yet				
static const int PARTICLE_COLOR_ANIMATION_MAX_KEYFRAMES = 4;
static const int PARTICLE_COLOR_ANIMATION_NUM_FUNCTIONS = (PARTICLE_COLOR_ANIMATION_MAX_KEYFRAMES - 1) * 2;

//    struct ParticleDraw
//    {
//	    float4 VideoTex_NumPerRow_LastFrame_SingleRow_isRand;
//	    float4 ColorAnimationFunctions[(PARTICLE_COLOR_ANIMATION_MAX_KEYFRAMES - 1) * 2];
//	    float4 TimeKeys;
//	    float SpeedMultiplier;
//	    float2 ColorScaleRange;  
//    };

#define REGISTER_PARTICLEDRAW_COLORSCALERANGE       78
#define REGISTER_PARTICLEDRAW_SPEEDMULTIPLIER       77
#define REGISTER_PARTICLEDRAW_TIMEKEYS              76
#define REGISTER_PARTICLEDRAW_COLOR_ANIMATION_LAST  75
#define REGISTER_PARTICLEDRAW_COLOR_ANIMATION_FIRST 70
#define REGISTER_PARTICLEDRAW_VIDEOTEX_LAYOUT       69

#define REGISTER_PARTICLEDRAW_FIRST                 REGISTER_PARTICLEDRAW_VIDEOTEX_LAYOUT
#define REGISTER_PARTICLEDRAW_LAST                  REGISTER_PARTICLEDRAW_COLORSCALERANGE
#define PARTICLEDRAW_ARRAY_INDEX_FROM_REGISTER(reg) (reg-REGISTER_PARTICLEDRAW_FIRST)

// Random values
#define MAX_RANDOM_VALUES 16
#define REGISTER_RANDOM_LAST                        68
#define REGISTER_RANDOM_FIRST                       53

// Object Upgrade Flashing 
#define REGISTER_FLASHPCT							52 
// Unit Type House Color Bloom Intensitys
#define REGISTER_HOUSECOLORBLOOMINTENSITY			51
// Render Buff Effects (2 vectors)
#define REGISTER_RENDERBUFFEFFECTA					50
#define REGISTER_RENDERBUFFEFFECTB					49


//////////////////////////////////////////////////////////////////////////////
// Integer constant registers
//////////////////////////////////////////////////////////////////////////////
#define IREGISTER_NUM_POINT_LIGHTS                  0
#define IREGISTER_NUM_SHADOWS                       1

//////////////////////////////////////////////////////////////////////////////
// Boolean constant registers
//////////////////////////////////////////////////////////////////////////////
#define BREGISTER_HAS_RECOLOR_COLORS                0
#define BREGISTER_HAS_SHADOW                        1
#define BREGISTER_STEALTH_ENABLED					2	


//////////////////////////////////////////////////////////////////////////////
// Macros
//////////////////////////////////////////////////////////////////////////////

#define REGISTER_EVAL(x) register(c##x)
#define REGISTER_EVAL_PS(x) register(ps, c##x)
#define REGISTER_EVAL_VS(x) register(vs, c##x)

// This file can be included in both shader and C++ code
#if defined(__cplusplus)
	#if defined(USE_INDIRECT_CONSTANT)
		#define REGISTER_BIND(registerIndex, variableType, variableName, annotations, initializer) REGISTER_INDIRECT_CONSTANT(variableName)
		#define REGISTER_BIND_ARRAY(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) REGISTER_INDIRECT_CONSTANT(variableName)
		#define REGISTER_BIND_ARRAY_VS(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) REGISTER_INDIRECT_CONSTANT(variableName)
		#define REGISTER_BIND_INT(registerIndex, variableType, variableName, annotations, initializer) REGISTER_INDIRECT_CONSTANT(variableName)
		#define REGISTER_BIND_BOOL(registerIndex, variableType, variableName, annotations, initializer) REGISTER_INDIRECT_CONSTANT(variableName)
	#else // #if defined(USE_INDIRECT_CONSTANT)
		#define REGISTER_BIND(registerIndex, variableType, variableName, annotations, initializer)
		#define REGISTER_BIND_ARRAY(registerIndex, variableType, variableName, numArrayElements, annotations, initializer)
		#define REGISTER_BIND_ARRAY_VS(registerIndex, variableType, variableName, numArrayElements, annotations, initializer)
		#define REGISTER_BIND_INT(registerIndex, variableType, variableName, annotations, initializer)
		#define REGISTER_BIND_BOOL(registerIndex, variableType, variableName, annotations, initializer)
	#endif // #if defined(USE_INDIRECT_CONSTANT)
#else
	#if defined(USE_INDIRECT_CONSTANT)
		#define REGISTER_BIND(registerIndex, variableType, variableName, annotations, initializer) shared variableType variableName : register(c##registerIndex) < bool unmanaged = true; > initializer
		#define REGISTER_BIND_ARRAY(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) shared variableType variableName [numArrayElements] : register(c##registerIndex) < bool unmanaged = true; > initializer
		#define REGISTER_BIND_ARRAY_VS(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) shared variableType variableName [numArrayElements] : register(vs, c##registerIndex) < bool unmanaged = true; > initializer
		#define REGISTER_BIND_INT(registerIndex, variableType, variableName, annotations, initializer) shared variableType variableName : register(i##registerIndex) < bool unmanaged = true; > initializer
		#define REGISTER_BIND_BOOL(registerIndex, variableType, variableName, annotations, initializer) shared variableType variableName : register(b##registerIndex) < bool unmanaged = true; > initializer
		#define USE_INITIALIZERS
	#else // #if defined(USE_INDIRECT_CONSTANT)
		#define REGISTER_BIND(registerIndex, variableType, variableName, annotations, initializer) variableType variableName < annotations > initializer
		#define REGISTER_BIND_ARRAY(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) variableType variableName [numArrayElements] < annotations > initializer
		#define REGISTER_BIND_ARRAY_VS(registerIndex, variableType, variableName, numArrayElements, annotations, initializer) variableType variableName [numArrayElements] < annotations > initializer
		#define REGISTER_BIND_INT(registerIndex, variableType, variableName, annotations, initializer) variableType variableName  < annotations > initializer
		#define REGISTER_BIND_BOOL(registerIndex, variableType, variableName, annotations, initializer) variableType variableName  < annotations > initializer
		#define USE_INITIALIZERS
	#endif // #if defined(USE_INDIRECT_CONSTANT)
#endif // if !__cplusplus

// Use this macro as parameter to the macros above, when no initializer is needed
#define NO_INITIALIZER


#endif // #define _REGISTERMAP_FXH_
