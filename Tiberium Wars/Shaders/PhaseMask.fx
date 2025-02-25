//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for creating the mask for phase rendering
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

#if defined(EA_PLATFORM_WINDOWS)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
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
#endif


// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------

// Bit in the stencil buffer to use. We are using the a bit that the behind buildings occlusion used,
// but since occlusion is processed before phase and we clear/fill the whole screen with it, we can reuse it.
// Just need to place nice with volume shadows.
#define PHASE_STENCIL_MASK 0x80

float Opacity
<
	string UIName = "Opacity";
    string UIWidget = "Slider";
> = 1.0;

float AlphaTestThreshold
<
	string UIName = "Alpha Test Threshold";
    string UIWidget = "Slider";
> = 0.7;

SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Base Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( Texture_1,
	string UIName = "Secondary Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float4 TexCoordTransform_1
<
	string UIName = "UV1 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 World : World;
float4x4 View : View;
float4x4 Projection : Projection;
float Time : Time;


// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
//	float Opacity : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondaryTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0)
{
	VSOutput Out;
	
	// Ignore camera/projection transforms, just treat the quad as being in [-1..1] screen coordinates
	Out.Position = float4(Position.xy, 0.5, 1);
	// If this annoys you eg in Max, you can use this instead:
//	float3 worldPosition = mul(float4(Position, 1), World);
//	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

//	Out.Opacity = OpacityOverride * VertexColor.w;

	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;

	// Scale with animated offset on texture coordinates 0
	Out.SecondaryTexCoord = TexCoord0 * TexCoordTransform_1.xy + Time * TexCoordTransform_1.zw;

	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = Opacity;

	color *= tex2D(SAMPLER(Texture_0), In.BaseTexCoord);

	color *= tex2D(SAMPLER(Texture_1), In.SecondaryTexCoord);

#if defined(EA_PLATFORM_XENON)
	color.a /= AlphaTestThreshold;
#endif

	return color;
}

// ----------------------------------------------------------------------------
float4 PSFlat(VSOutput In, uniform float4 color) : COLOR
{
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE : DEFAULT
// ----------------------------------------------------------------------------
technique Default
{
	pass ClearStencil
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;

		ColorWriteEnable = 0;

		StencilEnable = true;
		StencilMask = 0;
		StencilWriteMask = PHASE_STENCIL_MASK;
		StencilRef = 0;

		StencilFunc = Always;
		StencilPass = Replace;
		StencilFail = Keep;
		StencilZFail = Keep;
	}

	pass FillStencilLines
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = true;

		AlphaFunc = GreaterEqual;
#if defined(EA_PLATFORM_XENON)
		// Xenon doesn't like expressions like this. Therefore the shader divides by the threshold and we test against (almost) 1.0
		AlphaRef = 250;
#else
		AlphaRef = ( AlphaTestThreshold * 255 );
#endif

		CullMode = None;
		AlphaBlendEnable = false;

		ColorWriteEnable = 0;

		StencilEnable = true;
		StencilMask = 0;
		StencilWriteMask = PHASE_STENCIL_MASK;
		StencilRef = 0xFFFFFFFF;

		StencilFunc = Always;
		StencilPass = Replace;
		StencilFail = Keep;
		StencilZFail = Keep;
	}

#if defined(_3DSMAX_) || defined(_W3DVIEW_)
	// Visualization pass for previewing the mask
	pass P1
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PSFlat(float4(1, 1, 1, 1));

		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;

		ColorWriteEnable = ( D3DCOLORWRITEENABLE_ALL );

		StencilEnable = true;
		StencilMask = PHASE_STENCIL_MASK;
		StencilWriteMask = 0;
		StencilRef = 0xFFFFFFFF;

		StencilFunc = Equal;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Keep;
	}
	pass P2
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PSFlat(float4(0, 0, 0, 1));

		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;

		ColorWriteEnable = ( D3DCOLORWRITEENABLE_ALL );

		StencilEnable = true;
		StencilMask = PHASE_STENCIL_MASK;
		StencilWriteMask = 0;
		StencilRef = 0xFFFFFFFF;

		StencilFunc = NotEqual;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Keep;
	}
#endif
}

// ----------------------------------------------------------------------------
// TECHNIQUE : Render objects in phase
// ----------------------------------------------------------------------------
technique _RenderObjectPhase
{
	pass P0
	{
		StencilEnable = true;
		StencilMask = PHASE_STENCIL_MASK;
		StencilWriteMask = 0;
		StencilRef = 0xFFFFFFFF;

		StencilFunc = Equal;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Keep;
	}

	pass P1
	{
		StencilEnable = true;
		StencilMask = PHASE_STENCIL_MASK;
		StencilWriteMask = 0;
		StencilRef = 0xFFFFFFFF;

		StencilFunc = NotEqual;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Keep;
	}
}
