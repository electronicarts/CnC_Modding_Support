#ifndef _WIN32_MACROS_FXH_
#define _WIN32_MACROS_FXH_

// ----------------------------------------------------------------------------
// DEFINE PLATFORM HERE
// ----------------------------------------------------------------------------
#if !defined(EA_PLATFORM_WINDOWS)
#define EA_PLATFORM_WINDOWS
#endif

// Disable "warning X3557: Loop only executes for 1 iteration(s), forcing loop to unroll"
#pragma warning(disable : 3557)

// ----------------------------------------------------------------------------
// SAMPLER MACROS
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler  \
	< \
		string Texture=#samplerName; \
		annotations \
	> = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler \
	< \
		string Texture=#samplerName; \
		annotations \
	> = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };

#define SAMPLER_3D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler3D samplerName##Sampler \
	< \
		string Texture=#samplerName; \
		annotations \
	> = sampler_state \
	{ \
		Texture = < samplerName >;

#define SAMPLER_3D_END };

// ----------------------------------------------------------------------------
// SHADER VERSIONS
// ----------------------------------------------------------------------------
#define VS_3_0	vs_3_0
#define VS_2_0	vs_2_0

#define PS_3_0	ps_3_0
#define PS_2_0	ps_2_0

// ----------------------------------------------------------------------------
// FILTERS
// ----------------------------------------------------------------------------
#define MinFilterBest 3 /*Anisotropic*/
#define MagFilterBest 2 /*Linear*/
#define MipFilterBest 2 /*Linear*/

// ----------------------------------------------------------------------------
// PIXEL LOCATION ATTRIBUTE
// ----------------------------------------------------------------------------
#define PIXELLOC VPOS

// ----------------------------------------------------------------------------
// TEXCOORD CENTROID
// ----------------------------------------------------------------------------
#define TEXCOORD0_CENTROID	TEXCOORD0_centroid
#define TEXCOORD1_CENTROID	TEXCOORD1_centroid
#define TEXCOORD2_CENTROID	TEXCOORD2_centroid
#define TEXCOORD3_CENTROID	TEXCOORD3_centroid
#define TEXCOORD4_CENTROID	TEXCOORD4_centroid
#define TEXCOORD5_CENTROID	TEXCOORD5_centroid
#define TEXCOORD6_CENTROID	TEXCOORD6_centroid
#define TEXCOORD7_CENTROID	TEXCOORD7_centroid

// ----------------------------------------------------------------------------
// RENDERSTATE ENUMS
// ----------------------------------------------------------------------------

// Taken from d3d9types.h D3DBLEND enum
#define D3DBLEND_ZERO               1
#define D3DBLEND_ONE                2
#define D3DBLEND_SRCCOLOR           3
#define D3DBLEND_INVSRCCOLOR        4
#define D3DBLEND_SRCALPHA           5
#define D3DBLEND_INVSRCALPHA        6
#define D3DBLEND_DESTALPHA          7
#define D3DBLEND_INVDESTALPHA       8
#define D3DBLEND_DESTCOLOR          9
#define D3DBLEND_INVDESTCOLOR       10
#define D3DBLEND_SRCALPHASAT        11
#define D3DBLEND_BOTHSRCALPHA       12
#define D3DBLEND_BOTHINVSRCALPHA    13
#define D3DBLEND_BLENDFACTOR        14 /* Only supported if D3DPBLENDCAPS_BLENDFACTOR is on */
#define D3DBLEND_INVBLENDFACTOR     15 /* Only supported if D3DPBLENDCAPS_BLENDFACTOR is on */

// Taken from d3d9types.h D3DCULL enum
#define D3DCULL_NONE                1
#define D3DCULL_CW                  2
#define D3DCULL_CCW                 3

// Taken from d3d9types.h D3DCMPFUNC enum
#define D3DCMP_NEVER                1
#define D3DCMP_LESS                 2
#define D3DCMP_EQUAL                3
#define D3DCMP_LESSEQUAL            4
#define D3DCMP_GREATER              5
#define D3DCMP_NOTEQUAL             6
#define D3DCMP_GREATEREQUAL         7
#define D3DCMP_ALWAYS               8

// Taken from d3d9types.h. Flags to construct D3DRS_COLORWRITEENABLE
#define D3DCOLORWRITEENABLE_RED     1 //(1L<<0)
#define D3DCOLORWRITEENABLE_GREEN   2 //(1L<<1)
#define D3DCOLORWRITEENABLE_BLUE    4 //(1L<<2)
#define D3DCOLORWRITEENABLE_ALPHA   8 //(1L<<3)
#define D3DCOLORWRITEENABLE_ALL     0xf     // Xbox 360 extension [LLatta 2006-09-06: Copied to Windows version too]

#endif // include guard