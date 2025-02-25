//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// FX Shader for vehicles and structures. 
//////////////////////////////////////////////////////////////////////////////


#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define FIRSTPASS 0
#define SUPPORT_RECOLORING 1
#define SUPPORT_SPECMAP 1
#define SUPPORT_NORMALMAP 1
#define SUPPORT_BURROWING 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "ShadowMap.fxh"
#include "MacroTexture.fxh"
#include "DeferredLighting.fxh"


int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);

	int MaxLocalLights = 8;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;




DECLARE_MAPPING_TEXCOORD(0)
#if defined(SUPPORT_DAMAGETEXTURE)
DECLARE_MAPPING_TEXCOORD(1)
DECLARE_MAPPING_VERTEXCOLOR(2, 3)
#else
DECLARE_MAPPING_VERTEXCOLOR(1, 2)
#endif


// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
//#define NumDirectionalLightsPerPixel	2
//#define NumDirectionalLightsPerPixel_M	1


#if defined(_3DSMAX_)
	float OpacityOverride = 1.0f;
	bool StealthEnabled = false;
#endif



// ----------------------------------------------------------------------------
// Editable parameters
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( DiffuseTexture,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#if defined(SUPPORT_NORMALMAP)
SAMPLER_2D_BEGIN( NormalMap,
	string UIName = "Normal Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif

#if defined(SUPPORT_SPECMAP)
SAMPLER_2D_BEGIN( SpecMap,
	string UIName = "Specular Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif


SAMPLER_2D_BEGIN( FilteredNoise,
	string SasBindAddress = "WW3D.FilteredNoise";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( BurrowGrad,
	string SasBindAddress = "WW3D.burrow_grad";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


// Material parameters defined by UI
float BumpScale
<
	string UIName = "Bump Height"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 10.0;
    float UIStep = 0.1;
> = 1.0;

float3 AmbientColor
<
	string UIName = "Ambient Color"; 
    string UIWidget = "Color";
> = float3(0.4, 0.4, 0.4);

float4 DiffuseColor
<
	string UIName = "Diffuse Color"; 
    string UIWidget = "Color";
> = float4(1.0, 1.0, 1.0, 1.0);

float3 SpecularColor
<
	string UIName = "Specular Color"; 
    string UIWidget = "Color";
> = float3(0.8, 0.8, 0.8);

float SpecularExponent
<
	string UIName = "Specular Exponent"; 
    string UIWidget = "Slider";
	float UIMax = 200.0f;
	float UIMin = 0;
	float UIStep = 1.0f;
> = 50.0;


// For damage texture rendering we always need alpha testing to be enabled. So don't offer it as configuration option.
const bool AlphaTestEnable = true;


// ----------------------------------------------------------------------------
// Transformations (world transformations are in skinning header)
// ----------------------------------------------------------------------------
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

// Time (ie. material is animated)
float Time : Time;


float GetEmissiveMask(float4 specMap, float2 texCoord0)
{
	//Get House Color/Emissive Mask
#if !defined(OBJECTS_INFANTRY)
		float EmissiveMask = specMap.z; 
#else //OBJECTS_INFANTRY
		float4 HouseColorMap = tex2D( SAMPLER(RecolorTexture), texCoord0);
		float EmissiveMask = HouseColorMap.r;
#endif //!defined(OBJECTS_INFANTRY)

		return EmissiveMask;
}

float4 GetSpecMap(float2 texCoord0)
{
#if (defined(SUPPORT_SPECMAP)) // -- only use spec map if SUPPORT_SPECMAP defined || defined(SUPPORT_RECOLORING))
	float4 specMap = tex2D(SAMPLER(SpecMap), texCoord0);
#else
	float4 specMap = float4( 1.0f, 0.0f, 1.0f, 0.0f ); 
#endif
	return specMap;
}



// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float4 Color : COLOR0;
	float3 WorldPosition : TEXCOORD6;
};

// ----------------------------------------------------------------------------
// SHADER: Vertex Shader - High
// ----------------------------------------------------------------------------
VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE)
	USE_TEXCOORD(TexCoord1);
#endif

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	Out.WorldPosition = worldPosition;

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

 	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
 	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	float2 texCoord1 = TexCoord0;
	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - High
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			float2 vPos : PIXELLOC, uniform bool stealthEnabled, uniform int isMultiPass) COLORTARGET
{	
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	float4 specMap = GetSpecMap(texCoord0);
	baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;
	float4 color = float4(baseTexture.xyz, 1.0f);

	//Lighting
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 diffuseLight = SampleDiffuseLight(screenTexCoord); 
	float3 specularLight = SampleSpecularLight(screenTexCoord); 

	color.xyz += (diffuseLight * diffuse) + (specularLight * SpecularColor * specMap.x);


	//light intensity
	float intensity = (0.3f * color.r + 0.59f * color.g + 0.11f * color.b) * 2 + 0.2f;
	//scanline color -- will be pulled from HouseColor
	float3 ScanLineColor = GammaToLinear(float3(0.61f,0.11f,0.08f)) * intensity;

	//Detected version of Burrowing
#if defined(SUPPORT_BURROWING_DETECTED)
	float3 FlashColor = GammaToLinear(float3(0.61f,0.11f,0.08f)) * ((sin(Time * 12) + 1) * 0.5f) * intensity * 20.0f;
	ScanLineColor += FlashColor;
#endif



	////////////////////////////////////////////////////////////////////////////////////
	////
	////		SCANLINES
	////
	float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f - Time * 0.125f)); 
	filtnoise *= 1.5f; //0.2f; //0.0015f;
	//screenTexCoord *= 200.f; // 250
	float MinScreenTexCoordScale = 50.0f;
	float MaxScreenTexCoordScale = 250.0f;
	float3 EyePos = GetEyePosition();
	//hack to test scaling 175, 500
	float lerpval = saturate((EyePos.z * 0.5f - 175.0f)/(500.0f - 175.0f));
	float screenTexScale = lerp(MinScreenTexCoordScale, MaxScreenTexCoordScale, lerpval);
	screenTexCoord *= screenTexScale;
	float coordX = screenTexCoord.x; 
	float coordY = screenTexCoord.y + filtnoise.x - Time * 2.0f; 
	float4 burrowGrad = tex2D(SAMPLER(BurrowGrad), float2(coordX, coordY));
	float3 glowColor = ScanLineColor.xyz + (ScanLineColor * burrowGrad.x * 50); // 100);
	return float4(glowColor.xyz, max(burrowGrad.x, 0.2f));
	// end SCANLINES





	
	////////////////////////////////////////////////////////////////////////////////////////
	////////
	////////		ENERGY HIT EFFECT -- prototype
	////////
	//float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f)); 
	////float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f)); 
	////filtnoise *= 0.2f;
	//float4 burrowGrad = tex2D(SAMPLER(BurrowGrad), float2(screenTexCoord.x, 2.0f * screenTexCoord.y + filtnoise.x - (Time * 0.5f)));
	//float3 glowColor = ScanLineColor.xyz + (ScanLineColor * burrowGrad.x * 100);
	////return float4(ScanLineColor.xyz, burrowGrad.x);
	//return float4(glowColor.xyz, max(burrowGrad.x, 0.25f));
	////end ENERGY HIT


} //end PS_H



// ----------------------------------------------------------------------------
// Arrays: Default_H
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_H_Multiplier_Final = 2 );

#define VS_H_NumJointsPerVertex(isMultiPass) \
	compile VS_3_0 VS_H(0, isMultiPass), \
	compile VS_3_0 VS_H(1, isMultiPass)

#if SUPPORTS_SHADER_ARRAYS
	vertexshader VS_H_Array[VS_H_Multiplier_Final] =
	{
		VS_H_NumJointsPerVertex(FIRSTPASS)
	};
	
#endif // SUPPORTS_SHADER_ARRAYS

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_NumShadows = 1 );


#define PS_H_NumShadows(recolorEnabled, stealthEnabled, isMultiPass) \
	compile PS_3_0 PS_H(0, recolorEnabled, stealthEnabled, isMultiPass), \
	compile PS_3_0 PS_H(1, recolorEnabled, stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_RecolorEnabled = PS_H_Multiplier_NumShadows * 2 );
	
#define PS_H_RecolorEnabled(stealthEnabled, isMultiPass) \
	PS_H_NumShadows(false, stealthEnabled, isMultiPass), \
	PS_H_NumShadows(true,  stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_StealthEnabled = PS_H_Multiplier_RecolorEnabled * 2);

#define PS_H_StealthEnabled(isMultiPass) \
	PS_H_RecolorEnabled(false, isMultiPass), \
	PS_H_RecolorEnabled(true,  isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_StealthEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_H_Array[PS_H_Multiplier_Final] =
	{
		PS_H_StealthEnabled(FIRSTPASS)
	};

#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{

		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			 );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			0 * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled
			+ StealthEnabled * PS_H_Multiplier_StealthEnabled,  
			 );
#if defined(SUPPORT_BURROWING_STRUCTURE)
		//burrowed structures only render parts above ground 
		ZEnable = true;
#else
		//burrowed units must render under terrain
		ZEnable = false;
#endif

		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: Vertex Shader - Low
// ----------------------------------------------------------------------------
VSOutput_H VS_L(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE)
	USE_TEXCOORD(TexCoord1);
#endif

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	Out.WorldPosition = worldPosition;

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

 	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
 	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	float2 texCoord1 = TexCoord0;
	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - Low
// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			/*float2 vPos : PIXELLOC,*/ uniform bool stealthEnabled, uniform int isMultiPass) COLORTARGET
{	
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	float4 specMap = GetSpecMap(texCoord0);
	baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;
	float4 color = float4(baseTexture.xyz, 1.0f);

	//Lighting
//	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
//	float3 diffuseLight = SampleDiffuseLight(screenTexCoord); 
//	float3 specularLight = SampleSpecularLight(screenTexCoord); 

	float3 diffuseLight = 1.0f; 
	float3 specularLight = 1.0f; 
	color.xyz += (diffuseLight * diffuse) + (specularLight * SpecularColor * specMap.x);


	//light intensity
	float intensity = (0.3f * color.r + 0.59f * color.g + 0.11f * color.b) * 2 + 0.2f;
	//scanline color -- will be pulled from HouseColor
	float3 ScanLineColor = GammaToLinear(float3(0.61f,0.11f,0.08f)) * intensity;

// $todo - need to have Matt Davies do the effect for low lod

	return float4(ScanLineColor, 0.5f);
/*
	////////////////////////////////////////////////////////////////////////////////////
	////
	////		SCANLINES
	////
	float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f - Time * 0.125f)); 
	filtnoise *= 1.5f; //0.2f; //0.0015f;
	//screenTexCoord *= 200.f; // 250
	float MinScreenTexCoordScale = 50.0f;
	float MaxScreenTexCoordScale = 250.0f;
	float3 EyePos = GetEyePosition();
	//hack to test scaling 175, 500
	float lerpval = saturate((EyePos.z * 0.5f - 175.0f)/(500.0f - 175.0f));
	float screenTexScale = lerp(MinScreenTexCoordScale, MaxScreenTexCoordScale, lerpval);
	screenTexCoord *= screenTexScale;
	float coordX = screenTexCoord.x; 
	float coordY = screenTexCoord.y + filtnoise.x - Time * 2.0f; 
	float4 burrowGrad = tex2D(SAMPLER(BurrowGrad), float2(coordX, coordY));
	float3 glowColor = ScanLineColor.xyz + (ScanLineColor * burrowGrad.x * 50); // 100);
	return float4(glowColor.xyz, max(burrowGrad.x, 0.2f));
	// end SCANLINES
*/
	
	////////////////////////////////////////////////////////////////////////////////////////
	////////
	////////		ENERGY HIT EFFECT -- prototype
	////////
	//float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f)); 
	////float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(texCoord0.x * 1.0f, texCoord0.y * 1.0f)); 
	////filtnoise *= 0.2f;
	//float4 burrowGrad = tex2D(SAMPLER(BurrowGrad), float2(screenTexCoord.x, 2.0f * screenTexCoord.y + filtnoise.x - (Time * 0.5f)));
	//float3 glowColor = ScanLineColor.xyz + (ScanLineColor * burrowGrad.x * 100);
	////return float4(ScanLineColor.xyz, burrowGrad.x);
	//return float4(glowColor.xyz, max(burrowGrad.x, 0.25f));
	////end ENERGY HIT


} //end PS_L



// ----------------------------------------------------------------------------
// Arrays: Default_L
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );

#define VS_L_NumJointsPerVertex(isMultiPass) \
	compile VS_2_0 VS_L(0, isMultiPass), \
	compile VS_2_0 VS_L(1, isMultiPass)

#if SUPPORTS_SHADER_ARRAYS
	vertexshader VS_L_Array[VS_L_Multiplier_Final] =
	{
		VS_L_NumJointsPerVertex(FIRSTPASS)
	};
	
#endif // SUPPORTS_SHADER_ARRAYS

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_NumShadows = 1 );


#define PS_L_NumShadows(recolorEnabled, stealthEnabled, isMultiPass) \
	compile PS_2_0 PS_L(0, recolorEnabled, stealthEnabled, isMultiPass), \
	compile PS_2_0 PS_L(1, recolorEnabled, stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_RecolorEnabled = PS_L_Multiplier_NumShadows * 2 );
	
#define PS_L_RecolorEnabled(stealthEnabled, isMultiPass) \
	PS_L_NumShadows(false, stealthEnabled, isMultiPass), \
	PS_L_NumShadows(true,  stealthEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_StealthEnabled = PS_L_Multiplier_RecolorEnabled * 2);

#define PS_L_StealthEnabled(isMultiPass) \
	PS_L_RecolorEnabled(false, isMultiPass), \
	PS_L_RecolorEnabled(true,  isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_StealthEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_L_Array[PS_L_Multiplier_Final] =
	{
		PS_L_StealthEnabled(FIRSTPASS)
	};

#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default low lod
// ----------------------------------------------------------------------------
technique Default_L
{
	pass p0
	{

		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
			min(NumJointsPerVertex, 1), 
			 );

		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
			0 * PS_L_Multiplier_NumShadows
			+ HasRecolorColors * PS_L_Multiplier_RecolorEnabled
			+ StealthEnabled * PS_L_Multiplier_StealthEnabled,  
			 );
#if defined(SUPPORT_BURROWING_STRUCTURE)
		//burrowed structures only render parts above ground 
		ZEnable = true;
#else
		//burrowed units must render under terrain
		ZEnable = false;
#endif

		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

#endif // #if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
#if defined(SUPPORT_DAMAGETEXTURE)
	float2 TexCoord1 : TEXCOORD2;
#endif
	float Depth : TEXCOORD1;
	float Opacity : COLOR0;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
	float2 TexCoord1 : TEXCOORD1,
#endif
	float4 VertexColor: COLOR0,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Get the skins opacity value, used later as blend factor for the damage texture
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	// Transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.Depth = Out.Position.z / Out.Position.w;	
	Out.Opacity = OpacityOverride * VertexColor.w;
	Out.TexCoord0 = TexCoord0;	

#if defined(SUPPORT_DAMAGETEXTURE)
	Out.TexCoord1 = TexCoord1;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform bool alphaTestEnable) COLORTARGET
{
	float opacity = tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;
	
#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= damagedTexture * (1 - In.Opacity);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= lerp(damagedTexture, 1.0, In.Opacity);
#else 
	opacity *= In.Opacity;
#endif

	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}

	return In.Depth;
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS_Xenon
// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
		float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
#endif
		float4 VertexColor: COLOR0)
{
	return CreateShadowMapVS( InSkin,
		TexCoord,
#if defined(SUPPORT_DAMAGETEXTURE)
		TexCoord1,
#endif
		VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon(VSOutput_CreateShadowMap In) : COLOR
{
	return CreateShadowMapPS(In, AlphaTestEnable);
}

// ----------------------------------------------------------------------------
// Technique _CreateShadowMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 );

#define VSCreateShadowMap_NumJointsPerVertex \
	compile VS_2_0 CreateShadowMapVS(0), \
	compile VS_2_0 CreateShadowMapVS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif

#define PSCreateShadowMap_AlphaTestEnable \
	compile PS_2_0 CreateShadowMapPS(false), \
	compile PS_2_0 CreateShadowMapPS(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif

// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateShadowMapVS_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			AlphaTestEnable,
			compile PS_VERSION CreateShadowMapPS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}


// ----------------------------------------------------------------------------
// SHADER: CreateDepthNormalMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateDepthNormalMap
{
	float4 Position 				: POSITION;
	float3 TexCoord0_Opacity 		: TEXCOORD0;
	float3 TangentToViewSpace0 		: TEXCOORD1_CENTROID;
	float3 TangentToViewSpace1 		: TEXCOORD2_CENTROID;
	float3 TangentToViewSpace2 		: TEXCOORD3_CENTROID;
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_ALTMAPPING)
	float4 TexCoord1_TexCoord2 		: TEXCOORD4;
#endif
	float4 WorldPosition			: TEXCOORD5;
};

// ----------------------------------------------------------------------------
VSOutput_CreateDepthNormalMap CreateDepthNormalMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
	float2 TexCoord1 : TEXCOORD1,
#endif
	float4 VertexColor: COLOR0,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateDepthNormalMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Get the skins opacity value, used later as blend factor for the damage texture
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif //defined(_3DSMAX_)

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif //defined(SUPPORT_TREAD_SCROLLING)

	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);
	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

	// Transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.WorldPosition = Out.Position;
	Out.TexCoord0_Opacity.z = OpacityOverride * VertexColor.w;
	
	Out.TexCoord0_Opacity.xy = TexCoord0;

#if defined(SUPPORT_DAMAGETEXTURE)
	Out.TexCoord1_TexCoord2.xy = TexCoord1;
	Out.TexCoord1_TexCoord2.zw = 0;
#endif




	return Out;
}

// ----------------------------------------------------------------------------

struct PSOutput_CreateDepthNormalMap
{
	float4 Normal;
#if !defined(EA_PLATFORM_XENON)
	float4 Depth;
#endif
};

// ----------------------------------------------------------------------------
PSOutput_CreateDepthNormalMap CreateDepthNormalMapPS(VSOutput_CreateDepthNormalMap In, uniform bool alphaTestEnable) COLORTARGET
{
	float 	Opacity 	= In.TexCoord0_Opacity.z;
	float 	Depth 		= In.WorldPosition.z/In.WorldPosition.w;
	float2 	TexCoord0 	= In.TexCoord0_Opacity.xy;

#if defined(SUPPORT_DAMAGETEXTURE)
	float2	TexCoord1	= In.TexCoord1_TexCoord2.xy;
	float2	TexCoord2	= In.TexCoord1_TexCoord2.zw;
#endif
	
	float opacity = tex2D(SAMPLER(DiffuseTexture), TexCoord0 ).w;
	
#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), TexCoord1).w;
	opacity *= damagedTexture * (1 - Opacity);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), TexCoord1).w;
	opacity *= lerp(damagedTexture, 1.0, Opacity);
#else
	opacity *= Opacity;
#endif //defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)

	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}


	// Get bump map normal
#if defined(SUPPORT_NORMALMAP)
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), TexCoord0) * 2.0 - 1.0;
#else
	float3 bumpNormal = float3(0,0,1);
#endif //defined(SUPPORT_NORMALMAP)
	

	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	
	// Bring bump normal into world space
	bumpNormal = mul(bumpNormal, float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2));
	bumpNormal = normalize(bumpNormal);

	PSOutput_CreateDepthNormalMap Out;
	
	Out.Normal = float4((bumpNormal+1.0f.xxx)*0.5f.xxx, saturate(SpecularExponent/255.0f));
#if !defined(EA_PLATFORM_XENON)
	Out.Depth = Depth.xxxx;
#endif //!defined(EA_PLATFORM_XENON)

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: CreateDepthNormalMapVS_Xenon
// ----------------------------------------------------------------------------
VSOutput_CreateDepthNormalMap CreateDepthNormalMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
		float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
#endif
		float4 VertexColor: COLOR0)
{
	return CreateDepthNormalMapVS( InSkin,
		TexCoord,
#if defined(SUPPORT_DAMAGETEXTURE)
		TexCoord1,
#endif
		VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
PSOutput_CreateDepthNormalMap CreateDepthNormalMapPS_Xenon(VSOutput_CreateDepthNormalMap In) : COLOR
{
	return CreateDepthNormalMapPS(In, AlphaTestEnable);
}

// ----------------------------------------------------------------------------
// Technique _CreateDepthNormalMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateDepthNormalMap_Multiplier_Final = 2 );

#define VSCreateDepthNormalMap_NumJointsPerVertex \
	compile VS_2_0 CreateDepthNormalMapVS(0), \
	compile VS_2_0 CreateDepthNormalMapVS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateDepthNormalMap_Array[VSCreateDepthNormalMap_Multiplier_Final] =
{
	VSCreateDepthNormalMap_NumJointsPerVertex
};
#endif

#define PSCreateDepthNormalMap_AlphaTestEnable \
	compile PS_2_0 CreateDepthNormalMapPS(false), \
	compile PS_2_0 CreateDepthNormalMapPS(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateDepthNormalMap_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateDepthNormalMap_Array[PSCreateDepthNormalMap_Multiplier_Final] =
{
	PSCreateDepthNormalMap_AlphaTestEnable
};
#endif

// ----------------------------------------------------------------------------
technique _CreateDepthNormalMap
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateDepthNormalMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateDepthNormalMapVS_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateDepthNormalMap_Array,
			AlphaTestEnable,
			compile PS_VERSION CreateDepthNormalMapPS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}

