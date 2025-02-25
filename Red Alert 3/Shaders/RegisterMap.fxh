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

// Camera related
#define REGISTER_CAMERA_POSITION                    123
#define REGISTER_VIEWPROJECTION_MATRIX_FIRST        119
#define REGISTER_VIEWPROJECTION_MATRIX_LAST         122

// Color
#define REGISTER_RECOLOR_COLOR                      0
#define REGISTER_OPACITY_OVERRIDE                   1
#define REGISTER_TINT_COLOR                         2

// Cloud related
#define REGISTER_CLOUD_SETUP                        117 // 2 registers used
#define REGISTER_NO_CLOUD_MULTIPLIER                3

// Shadowmap
#define REGISTER_MAT_WORLD_TO_SHADOW                113 // 4 registers

// Lighting
#define REGISTER_AMBIENT_LIGHT_COLOR                4
#define REGISTER_DIRECTIONAL_LIGHTS_FIRST           5 // 6 registers
#define REGISTER_DIRECTIONAL_LIGHTS_LAST            10
#define REGISTER_POINT_LIGHTS_FIRST                 89 // 24 registers
#define REGISTER_POINT_LIGHTS_LAST                  112

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
