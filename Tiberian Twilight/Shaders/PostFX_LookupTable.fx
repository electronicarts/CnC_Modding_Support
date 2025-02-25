//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Image post processing effect performing a color conversion through a lookup table
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonPostFX.fxh"
#include "Gamma.fxh"

#define BlendOverlayf(base, blend) 	(base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend)))
#define BlendSoftLightf(base, blend) 	((blend < 0.5) ? (2.0 * base * blend + base * base * (1.0 - 2.0 * blend)) : (sqrt(base * 0.8) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend)))
#define BlendLightenf(base, blend) 		max(blend, base)
#define BlendDarkenf(base, blend) 		min(blend, base)
#define BlendPinLightf(base, blend) 	((blend < 0.5) ? BlendDarkenf(base, (2.0 * blend)) : BlendLightenf(base, (2.0 *(blend - 0.5))))


SAMPLER_2D_BEGIN( Overlay,
	string UIWidget = "None";
	string UIName = "None";
	string SasBindAddress = "PostEffect.Overlay.OverlayTexture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( Falloff,
	string UIWidget = "None";
	string UIName = "None";
	string SasBindAddress = "PostEffect.FalloffAndGrain.FalloffTexture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( Grain,
	string UIWidget = "None";
	string UIName = "None";
	string SasBindAddress = "PostEffect.FalloffAndGrain.GrainTexture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( ColorMask,
	string UIWidget = "None";
	string UIName = "None";
	string SasBindAddress = "PostEffect.ColorMask.ColorMaskTexture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_3D_BEGIN( LookupTexture,
	string SasBindAddress = "PostEffect.LookupTable.LookupTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_3D_END

SAMPLER_2D_BEGIN( FilmTonemappingLookupTexture,
	string SasBindAddress = "PostEffect.LookupTable.FilmTonemapping";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4 BlendFactor
<
	string SasBindAddress = "PostEffect.LookupTable.BlendFactor";
> = float4(1.0, 1.0, 1.0, 1.0);

float3 ExposureLevel
<
	string SasBindAddress = "PostEffect.LookupTable.ExposureLevel";
> = float3(1.0, 1.0, 1.0);


float4 ColorMaskParams
<
	string SasBindAddress = "PostEffect.ColorMask.ColorMaskParams";
> = float4(0.15f, 0.0f, 0.0f, 0.0f);


//OverlayFactor 
//OverlayFactor.x is Overlay BlendFactor
//OverlayFactor.y is CenterFillScale
//OverlayFactor.z is VignetteScale
//OverlayFactor.w is VignetteColorShift
float4 OverlayFactor
<
	string SasBindAddress = "PostEffect.Overlay.OverlayFactor";
> = float4(0.0, 0.0, 0.0, 1.0);

//FalloffParams
//FalloffParams.x is Falloff Fill
//FalloffParams.y is FalloffScale
//FalloffParams.z is GrainUVShift
//FalloffParams.w is GrainUVScale
float4 FalloffParams
<
	string SasBindAddress = "PostEffect.FalloffAndGrain.FalloffParams";
> = float4(0.0, 0.0, 0.0, 1.0);

//Falloff and Grain Blend Mode
float4 FalloffAndGrainBlendMode
<
	string SasBindAddress = "PostEffect.FalloffAndGrain.GrainBlendMode";
> = float4(0.0f,0.0f,0.0f,0.0f);

bool ApplyOverlay
<
	string SasBindAddress = "WW3D.IsPostEffectOverlayEnabled";
> = false;

bool ApplyFalloffAndGrain
<
	string SasBindAddress = "WW3D.IsPostEffectFalloffAndGrainEnabled";
> = false;

bool ApplyColorMask
<
	string SasBindAddress = "WW3D.IsPostEffectColorMaskEnabled";
> = false;

bool ApplyLUT
<
	string SasBindAddress = "WW3D.IsPostEffectLUTEnabled";
> = false;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput DefaultVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	return Out;
}

// ----------------------------------------------------------------------------
float4 DefaultPS(float2 TexCoord : TEXCOORD0,
					uniform bool applyGammaCorrection,
					uniform bool bApplyOverlay,
					uniform bool bApplyFalloffAndGrain,
					uniform bool bApplyColorMask,
					uniform bool bApplyLUT) : COLOR
{
	float4 color = tex2D(SAMPLER(FrameBufferSampler), TexCoord);
	
	color.xyz = UncompressRenderTargetColor(color.xyz);

	color.xyz = CorrectForGammaApproximation(color.xyz);

	color.xyz *= ExposureLevel;
	
#if defined(ENABLE_GAMMA_CONVERSION)
	if (applyGammaCorrection)
	{

	#define TONEMAPPER 2

	#if TONEMAPPER == 0
		color.xyz = LinearToGamma(color.xyz);
	#elif TONEMAPPER == 1
		color.xyz /= 1 + color.xyz;
	#elif TONEMAPPER == 2
		float3 white = 6.0;
		color.xyz *= white;
		color.xyz = color.xyz * (1 + color.xyz / (white * white)) / (1 + color.xyz);
	#else
		float3 ld = 0.002;
		float linReference = 0.18;
		float logReference = 444;
		float logGamma = 0.45;
		
		color.xyz = (log10(0.4 * color.xyz / linReference) / ld * logGamma + logReference) / 1023.0;
		//color.xyz = clamp(color.xyz, 0, 1);
		
		float FilmLutWidth = 256;
		float Padding = .5/FilmLutWidth;
		//color.xyz = lerp(Padding,1-Padding,color.xyz);

		//  apply response lookup and color grading for target display
		color.x = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.x, .5)).r;
		color.y = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.y, .5)).r;
		color.z = tex2D(SAMPLER(FilmTonemappingLookupTexture), float2(color.z, .5)).r;
	#endif  
	}
#endif
	

	if (bApplyOverlay)
	{
		//overlay blend factor 0.309
		//Center fill scale 0.1
		// vignette scale 0.827
		// vignette color shift 0.145

		OverlayFactor.x = 0.2; //is Overlay BlendFactor
		OverlayFactor.y = 0.05; //is CenterFillScale
		//OverlayFactor.z is VignetteScale
		//OverlayFactor.w is VignetteColorShift

		//Overlay texture
		//	red channel is vignette
		//	green channel is center fill
		float4 textureSample = tex2D( SAMPLER(Overlay), TexCoord);
		//center fill
		float4 centerFillColor = textureSample.g;
		color = color + (color * (max(centerFillColor, 0.0f) * OverlayFactor.y));
		// vignette 
		float4 vignetteColor = (1.0f - (textureSample.r * OverlayFactor.z)) - OverlayFactor.w;
		float4 blendover = BlendOverlayf(color, vignetteColor);
		color = lerp(color, blendover, OverlayFactor.x);  
	}


	//Apply Falloff and Grain
	//HACK - MD -- turning off until bugs fixed
	if (bApplyFalloffAndGrain) 
	{
		// Adjusting params in game. --> these values must be saved in the map file
		FalloffParams.x = 0.3; 	//Falloff Fill (orig 0.35 in photoshop)
		FalloffParams.y = 0.8;  //FalloffScale
		FalloffParams.z = 0.45; //GrainUVShift
		FalloffParams.w = 1.0;	//GrainUVScale  

		//$todo (MD) --> move these to one texture --> pending Tambo approval of lookdev
		float4 GrainTex = tex2D( SAMPLER(Grain), 1.5f * TexCoord);
		float4 FalloffTex = tex2D( SAMPLER(Falloff), TexCoord);


		//hack test for haze bit
		if (FalloffAndGrainBlendMode.x == 1.0f)
		{
			color.xyz = lerp(color.xyz, FalloffTex.xyz, FalloffTex.w);
		}
		else
		{
			//Falloff
			FalloffTex.w *= FalloffParams.x; //lower opacity...to match layer's fill blend value in photoshop
			float4 softlit = BlendSoftLightf(color, FalloffTex);
			softlit = lerp(color, softlit, FalloffParams.y); //0.8f);
			color.xyz = softlit.xyz;

			//Pin Light
			float ramp = ((1.0f - TexCoord.y) - FalloffParams.z) * FalloffParams.w; //move 0.5 to user param?? GrainUVShift = 0.5, GrainUVScale = 1.0
			float4 pinlight = BlendPinLightf(color, GrainTex);
			pinlight = lerp(color, pinlight, ramp);

			color.xyz = pinlight.xyz; 
		}
	}

	//Capital City Post Effects
	// Note -- these are hard-coded into shader to avoid exposing params to artist.
	if (bApplyColorMask)
	{
		float4 ColorMaskTex = tex2D( SAMPLER(ColorMask), TexCoord );
		color.xyz += ColorMaskTex.xyz * ColorMaskParams.x;
	}



	if (bApplyLUT) 
	{
#if defined (EA_PLATFORM_XENON)
		// TODO: LLatta 2008-09-13
		// This is a workaround for a Xenon pipeline bug.
		// This fix here is a less risky fix at this stage of the project.
		// At the earliest convenience fix the actual issue in CVolumeTexture::SaveImage
		// See the comment in code\AssetCompilers\0.0-dev\Modules\TextureCompiler\Source\xenon\VolumeTexture.cpp
		float4 tableColor = tex3D(SAMPLER(LookupTexture), color.xzy).xzyw;
#else
		float4 tableColor = tex3D(SAMPLER(LookupTexture), color.xyz);
#endif
		color = lerp(color, tableColor, BlendFactor.x);
	}


	return color;
}

// ----------------------------------------------------------------------------
// Stub functions to pass in the various parameters
// ----------------------------------------------------------------------------
float4 DefaultPS_LUT_GammaCorrection(float2 TexCoord : TEXCOORD0) : COLOR
{
	bool bApplyGammaCorrection	= true;
	bool bApplyOverlay			= ApplyOverlay; 
	bool bApplyFalloffAndGrain	= ApplyFalloffAndGrain;
	bool bApplyColorMask		= ApplyColorMask;
	bool bApplyLUT				= ApplyLUT;

    return DefaultPS(TexCoord, bApplyGammaCorrection, bApplyOverlay, bApplyFalloffAndGrain, bApplyColorMask, bApplyLUT);
}

float4 DefaultPS_LUT_NoGammaCorrection(float2 TexCoord : TEXCOORD0) : COLOR
{
	bool bApplyGammaCorrection	= false;
	bool bApplyOverlay			= ApplyOverlay; 
	bool bApplyFalloffAndGrain	= ApplyFalloffAndGrain;
	bool bApplyColorMask		= ApplyColorMask;
	bool bApplyLUT				= ApplyLUT;

    return DefaultPS(TexCoord, bApplyGammaCorrection, bApplyOverlay, bApplyFalloffAndGrain, bApplyColorMask, bApplyLUT);
}

float4 DefaultPS_NoLUT_GammaCorrection(float2 TexCoord : TEXCOORD0) : COLOR
{
	bool bApplyGammaCorrection	= true;
	bool bApplyOverlay			= ApplyOverlay; 
	bool bApplyFalloffAndGrain	= ApplyFalloffAndGrain;
	bool bApplyColorMask		= ApplyColorMask;
	bool bApplyLUT				= false;

    return DefaultPS(TexCoord, bApplyGammaCorrection, bApplyOverlay, bApplyFalloffAndGrain, bApplyColorMask, bApplyLUT);
}

float4 DefaultPS_NoLUT_NoGammaCorrection(float2 TexCoord : TEXCOORD0) : COLOR
{
	bool bApplyGammaCorrection	= false;
	bool bApplyOverlay			= ApplyOverlay; 
	bool bApplyFalloffAndGrain	= ApplyFalloffAndGrain;
	bool bApplyColorMask		= ApplyColorMask;
	bool bApplyLUT				= false;

    return DefaultPS(TexCoord, bApplyGammaCorrection, bApplyOverlay, bApplyFalloffAndGrain, bApplyColorMask, bApplyLUT);
}

// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_LUT = 1 );

#define DefaultPS_LUT(gammaCorrection, overlay, falloffAndGrain, colorMask) \
	compile PS_3_0 DefaultPS(gammaCorrection, overlay, falloffAndGrain, colorMask, false), \
	compile PS_3_0 DefaultPS(gammaCorrection, overlay, falloffAndGrain, colorMask, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_ColorMask = DefaultPS_Multiplier_LUT * 2 );
#define DefaultPS_ColorMask(gammaCorrection, overlay, falloffAndGrain) \
	DefaultPS_LUT(gammaCorrection, overlay, falloffAndGrain, false), \
	DefaultPS_LUT(gammaCorrection, overlay, falloffAndGrain, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_FalloffAndGrain = DefaultPS_Multiplier_ColorMask * 2 );
#define DefaultPS_FalloffAndGrain(gammaCorrection, overlay) \
	DefaultPS_ColorMask(gammaCorrection, overlay, false), \
	DefaultPS_ColorMask(gammaCorrection, overlay, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_Overlay = DefaultPS_Multiplier_FalloffAndGrain * 2 );
#define DefaultPS_Overlay(gammaCorrection) \
	DefaultPS_FalloffAndGrain(gammaCorrection, false), \
	DefaultPS_FalloffAndGrain(gammaCorrection, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_GammaCorrection = DefaultPS_Multiplier_Overlay * 2 );
#define DefaultPS_GammaCorrection \
	DefaultPS_Overlay(false), \
	DefaultPS_Overlay(true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_Multiplier_Final = DefaultPS_Multiplier_GammaCorrection * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[DefaultPS_Multiplier_Final] =
{
	DefaultPS_GammaCorrection
};
#endif

// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_3_0 DefaultVS();

		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			ApplyLUT * DefaultPS_Multiplier_LUT
			+ ApplyColorMask * DefaultPS_Multiplier_ColorMask
			+ ApplyFalloffAndGrain * DefaultPS_Multiplier_FalloffAndGrain
			+ ApplyOverlay * DefaultPS_Multiplier_Overlay
			+ 1 * DefaultPS_Multiplier_GammaCorrection,
			compile PS_VERSION DefaultPS_LUT_GammaCorrection() );

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_LUT = 1 );

#define DefaultPS_M_LUT(gammaCorrection, overlay, falloffAndGrain, colorMask) \
	compile PS_3_0 DefaultPS(gammaCorrection, overlay, falloffAndGrain, colorMask, false), \
	compile PS_3_0 DefaultPS(gammaCorrection, overlay, falloffAndGrain, colorMask, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_ColorMask = DefaultPS_M_Multiplier_LUT * 2 );
#define DefaultPS_M_ColorMask(gammaCorrection, overlay, falloffAndGrain) \
	DefaultPS_M_LUT(gammaCorrection, overlay, falloffAndGrain, false), \
	DefaultPS_M_LUT(gammaCorrection, overlay, falloffAndGrain, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_FalloffAndGrain = DefaultPS_M_Multiplier_ColorMask * 2 );
#define DefaultPS_M_FalloffAndGrain(gammaCorrection, overlay) \
	DefaultPS_M_ColorMask(gammaCorrection, overlay, false), \
	DefaultPS_M_ColorMask(gammaCorrection, overlay, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_Overlay = DefaultPS_M_Multiplier_FalloffAndGrain * 2 );
#define DefaultPS_M_Overlay(gammaCorrection) \
	DefaultPS_M_FalloffAndGrain(gammaCorrection, false), \
	DefaultPS_M_FalloffAndGrain(gammaCorrection, true)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_GammaCorrection = DefaultPS_M_Multiplier_Overlay * 2 );
#define DefaultPS_M_GammaCorrection \
	DefaultPS_M_Overlay(false)

DEFINE_ARRAY_MULTIPLIER( DefaultPS_M_Multiplier_Final = DefaultPS_M_Multiplier_GammaCorrection );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[DefaultPS_M_Multiplier_Final] =
{
	DefaultPS_M_GammaCorrection
};
#endif

// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_3_0 DefaultVS();

		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			ApplyLUT * DefaultPS_M_Multiplier_LUT
			+ ApplyColorMask * DefaultPS_M_Multiplier_ColorMask
			+ ApplyFalloffAndGrain * DefaultPS_M_Multiplier_FalloffAndGrain
			+ ApplyOverlay * DefaultPS_M_Multiplier_Overlay,
			compile PS_VERSION DefaultPS_LUT_NoGammaCorrection() );

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_Multiplier_ColorMask = 1 );

#define ResolveOnly_ColorMask(overlay, falloffAndGrain) \
	compile PS_3_0 DefaultPS(true, overlay, falloffAndGrain, false, false), \
	compile PS_3_0 DefaultPS(true, overlay, falloffAndGrain, true, false)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_Multiplier_FalloffAndGrain = ResolveOnly_Multiplier_ColorMask * 2 );
#define ResolveOnly_FalloffAndGrain(overlay) \
	ResolveOnly_ColorMask(overlay, false), \
	ResolveOnly_ColorMask(overlay, true)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_Multiplier_Overlay = ResolveOnly_Multiplier_FalloffAndGrain * 2 );
#define ResolveOnly_Overlay \
	ResolveOnly_FalloffAndGrain(false), \
	ResolveOnly_FalloffAndGrain(true)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_Multiplier_Final = ResolveOnly_Multiplier_Overlay * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Resolve_Array[ResolveOnly_Multiplier_Final] =
{
	ResolveOnly_Overlay
};
#endif

// ----------------------------------------------------------------------------
technique ResolveOnly
{
	pass P0
	{
		VertexShader = compile VS_3_0 DefaultVS();

		PixelShader = ARRAY_EXPRESSION_PS( PS_Resolve_Array,
			ApplyColorMask * ResolveOnly_Multiplier_ColorMask
			+ ApplyFalloffAndGrain * ResolveOnly_Multiplier_FalloffAndGrain
			+ ApplyOverlay * ResolveOnly_Multiplier_Overlay,
			compile PS_VERSION DefaultPS_NoLUT_GammaCorrection() );

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_M_Multiplier_ColorMask = 1 );

#define ResolveOnly_M_ColorMask(overlay, falloffAndGrain) \
	compile PS_3_0 DefaultPS(false, overlay, falloffAndGrain, false, false), \
	compile PS_3_0 DefaultPS(false, overlay, falloffAndGrain, true, false)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_M_Multiplier_FalloffAndGrain = ResolveOnly_M_Multiplier_ColorMask * 2 );
#define ResolveOnly_M_FalloffAndGrain(overlay) \
	ResolveOnly_M_ColorMask(overlay, false), \
	ResolveOnly_M_ColorMask(overlay, true)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_M_Multiplier_Overlay = ResolveOnly_M_Multiplier_FalloffAndGrain * 2 );
#define ResolveOnly_M_Overlay \
	ResolveOnly_M_FalloffAndGrain(false), \
	ResolveOnly_M_FalloffAndGrain(true)

DEFINE_ARRAY_MULTIPLIER( ResolveOnly_M_Multiplier_Final = ResolveOnly_M_Multiplier_Overlay * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Resolve_M_Array[ResolveOnly_M_Multiplier_Final] =
{
	ResolveOnly_M_Overlay
};
#endif

// ----------------------------------------------------------------------------
technique ResolveOnly_M
{
	pass P0
	{
		VertexShader = compile VS_3_0 DefaultVS();

		PixelShader = ARRAY_EXPRESSION_PS( PS_Resolve_M_Array,
			ApplyColorMask * ResolveOnly_M_Multiplier_ColorMask
			+ ApplyFalloffAndGrain * ResolveOnly_M_Multiplier_FalloffAndGrain
			+ ApplyOverlay * ResolveOnly_M_Multiplier_Overlay,
			compile PS_VERSION DefaultPS_NoLUT_NoGammaCorrection() );

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}
