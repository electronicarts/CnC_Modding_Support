#ifndef _WIN32_MACROS_FXH_
#define _WIN32_MACROS_FXH_

// ----------------------------------------------------------------------------
// DEFINE PLATFORM HERE
// ----------------------------------------------------------------------------
#define EA_PLATFORM_WINDOWS

// ----------------------------------------------------------------------------
// SAMPLER 
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };

#define SAMPLER_3D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler3D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;

#define SAMPLER_3D_END };

// ----------------------------------------------------------------------------
// SHADER VERSIONS
// ----------------------------------------------------------------------------
#define VS_VERSION_ULTRAHIGH	vs_3_0
#define VS_VERSION_HIGH			vs_2_0
#define VS_VERSION_LOW			vs_1_1

#define PS_VERSION_ULTRAHIGH	ps_3_0
#define PS_VERSION_HIGH			ps_2_0
#define PS_VERSION_LOW			ps_1_1

// ----------------------------------------------------------------------------
// FILTERS
// ----------------------------------------------------------------------------
#define MinFilterBest 3 /*Anisotropic*/
#define MagFilterBest 2 /*Linear*/
#define MipFilterBest 2 /*Linear*/


// ----------------------------------------------------------------------------
// RENDERSTATE ENUMS
// ----------------------------------------------------------------------------

// Taken from d3d9types.h D3DBLEND enum
static const int D3DBLEND_ZERO               = 1;
static const int D3DBLEND_ONE                = 2;
static const int D3DBLEND_SRCCOLOR           = 3;
static const int D3DBLEND_INVSRCCOLOR        = 4;
static const int D3DBLEND_SRCALPHA           = 5;
static const int D3DBLEND_INVSRCALPHA        = 6;
static const int D3DBLEND_DESTALPHA          = 7;
static const int D3DBLEND_INVDESTALPHA       = 8;
static const int D3DBLEND_DESTCOLOR          = 9;
static const int D3DBLEND_INVDESTCOLOR       = 10;
static const int D3DBLEND_SRCALPHASAT        = 11;
static const int D3DBLEND_BOTHSRCALPHA       = 12;
static const int D3DBLEND_BOTHINVSRCALPHA    = 13;
static const int D3DBLEND_BLENDFACTOR        = 14; /* Only supported if D3DPBLENDCAPS_BLENDFACTOR is on */
static const int D3DBLEND_INVBLENDFACTOR     = 15; /* Only supported if D3DPBLENDCAPS_BLENDFACTOR is on */

// Taken from d3d9types.h D3DCULL enum
static const int D3DCULL_NONE                = 1;
static const int D3DCULL_CW                  = 2;
static const int D3DCULL_CCW                 = 3;

// Taken from d3d9types.h D3DCMPFUNC enum
static const int D3DCMP_NEVER                = 1;
static const int D3DCMP_LESS                 = 2;
static const int D3DCMP_EQUAL                = 3;
static const int D3DCMP_LESSEQUAL            = 4;
static const int D3DCMP_GREATER              = 5;
static const int D3DCMP_NOTEQUAL             = 6;
static const int D3DCMP_GREATEREQUAL         = 7;
static const int D3DCMP_ALWAYS               = 8;

// Taken from d3d9types.h. Flags to construct D3DRS_COLORWRITEENABLE
static const int D3DCOLORWRITEENABLE_RED     = 1; //(1L<<0)
static const int D3DCOLORWRITEENABLE_GREEN   = 2; //(1L<<1)
static const int D3DCOLORWRITEENABLE_BLUE    = 4; //(1L<<2)
static const int D3DCOLORWRITEENABLE_ALPHA   = 8; //(1L<<3)
static const int D3DCOLORWRITEENABLE_ALL     = 0xf;     // Xbox 360 extension [LLatta 2006-09-06: Copied to Windows version too]

#endif // include guard