//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// FX Shader for vehicles and structures. 
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_RECOLORING 1 // Defined only in faction specific versions
//#define SUPPORT_SPECMAP 1 // Define for objects shader with specularity/envmap/self illumination map
//#define SUPPORT_LIGHTMAP 1 // Define for objects that use a lightmap (supports HDR)
//#define SPECIFY_CUSTOM_ENVMAP 1 // Define to allow environment cube map to be specified in art tool instead of taken from code binding
//#define SUPPORT_DAMAGETEXTURE 1 // Define to allow blending between a damage texture and pristine texture based on vertex or bone based alpha values
//#define SUPPORT_FILLDAMAGETEXTURE 1 // Define to allow blending between a damage texture and pristine texture based on vertex or bone based alpha values
//#define SUPPORT_JAPANBUILDUP 1 // Defined for Japanese Building Construction Shader
//#define SUPPORT_FROZEN 1 // Defined to change appearance of object to ice
//#define SUPPORT_TESLA 1
//#define SUPPORT_ALTMAPPING 1 // Defined to change mapping coords if using Iron Curtain or Chrono Rift
//#define SUPPORT_IRONCURTAIN 1 // Defined to change appearance of object to invulnerable
//#define SUPPORT_CHRONORIFT 1 // Defined to change appearance of object to phased
//#define SUPPORT_FORMATIONPREVIEW 1 // Defined to change appearance of object for formation preview
//#define SUPPORT_TREAD_SCROLLING 1 // Defined for animating the texcoord 0 based on the bone opacity, used for tank tread animation
//#define SUPPORT_SSAO

#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define FIRSTPASS 0

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


#if defined(_3DSMAX_)
	bool StealthEnabled = false;
	float4 RenderBuffEffectA = float4(0.0f,0.0f,0.0f,0.0f);
	float4 RenderBuffEffectB = float4(0.0f,0.0f,0.0f,0.0f);
#endif


DECLARE_MAPPING_TEXCOORD(0)
#if defined(SUPPORT_DAMAGETEXTURE)
DECLARE_MAPPING_TEXCOORD(1)
DECLARE_MAPPING_VERTEXCOLOR(2, 3)
#else
DECLARE_MAPPING_VERTEXCOLOR(1, 2)
#endif


#if defined(SUPPORT_DAMAGETEXTURE)
#define EXPRESSION_EVALUATOR_NAME "Buildings"
#else
#define EXPRESSION_EVALUATOR_NAME "Objects"
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
#define NumDirectionalLightsPerPixel	2
#define NumDirectionalLightsPerPixel_M	1

// ----------------------------------------------------------------------------
// Cloud layer
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( CloudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.Texture";
	string ResourceName = "ShaderPreviewCloud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Environment map
// ----------------------------------------------------------------------------
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string UIWidget = "None";
	string SasBindAddress = "Objects.LightSpaceEnvironmentMap";
	string ResourceType = "Cube";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END


#if defined(MATERIAL_PARAMS_ALIEN)
SAMPLER_2D_BEGIN( AlienEnvScrollTexture,
	string UIName = "Alien Env Scroll Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
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


//used for env map lookup
//#if defined(MATERIAL_PARAMS_GDI) || defined(MATERIAL_PARAMS_NOD) || defined(SUPPORT_BUFF_MIRRORPLATING)
SAMPLER_2D_BEGIN( NormalSpecTexture,
	string SasBindAddress = "WW3D.DeferredLighting.NormalSpec";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END
//#endif


//For Buffs
SAMPLER_2D_BEGIN( FilteredNoise,
	string SasBindAddress = "WW3D.FilteredNoise";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


//grid texture for shield buff
//#if defined(SUPPORT_BUFF_MIRRORPLATING)
SAMPLER_2D_BEGIN( Buff_HexGrid,
	 string SasBindAddress = "WW3D.Buff_HexGrid";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END
//#endif

//ifdef this out
SAMPLER_2D_BEGIN( Buff_ShieldRamp,
	 string SasBindAddress = "WW3D.Buff_ShieldRamp";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END




// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------
#if defined(SUPPORT_RECOLORING)
float RecolorBloomScale
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.RecolorBloomScale";
> = 1.0;
#endif

#if defined(SUPPORT_RECOLORING)
int HouseColorUnitType
<
string UIName = "Type-0:GDILarge,1:GDISml,2:NODLrg,3:NODSml";
	int UIMin = 0;
	int UIMax = 3;
> = 0;
#endif 



//Faction Specific Scrolling textures for House Color
#if defined(SUPPORT_RECOLORING)
	#if defined(MATERIAL_PARAMS_NOD)
		SAMPLER_2D_BEGIN( RecolorScrollTexture,
			string UIWidget = "None";
			string SasBindAddress = "WW3D.NOD_Scroll";
			)
			MinFilter = MinFilterBest;
			MagFilter = MagFilterBest;
			MipFilter = MipFilterBest;
			AddressU = Wrap;
			AddressV = Wrap;
		SAMPLER_2D_END		
	#else //defined(MATERIAL_PARAMS_GDI) default is GDI 
		SAMPLER_2D_BEGIN( RecolorScrollTexture,
			string UIWidget = "None";
			string SasBindAddress = "WW3D.GDI_Scroll";
			)
			MinFilter = MinFilterBest;
			MagFilter = MagFilterBest;
			MipFilter = MipFilterBest;
			 AddressU = Wrap;
			 AddressV = Wrap;
		SAMPLER_2D_END
	#endif // Sampler for RecolorScrollTexture
#endif // defined(SUPPORT_RECOLORING)

#if !defined(USE_INDIRECT_CONSTANT)
#if defined(SUPPORT_RECOLORING)
float4 HouseColorBloomIntensity
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.HouseColorBloomIntensity";
> = float4(1.0f, 1.0f, 1.0f, 1.0f);
#endif
#endif


#if defined(SUPPORT_DAMAGETEXTURE)
SAMPLER_2D_BEGIN( DamagedTexture,
	string UIName = "Damaged Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#if defined(_3DSMAX_)
bool PreviewFullyDamaged
<
	string UIName = "Preview Fully Damaged";
	bool ExportValue = false;
> = false;
#endif // defined(_3DSMAX_)
#endif // defined(SUPPORT_DAMAGETEXTURE)

//Buff Statics
static const float4 BuffTibColor = float4(0.0f, 0.5f, 0.0f, 1.0f);
static const float4 BuffIncineratorBurnColor = float4(1.0f, 0.4f, 0.0f, 1.0);
static const float BuffBurnScale = 10.0f; 

#if defined(MATERIAL_PARAMS_DEFAULT)
// Fixed material parameters for ALLIED
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.1, 0.1, 0.1);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.8, 0.8, 0.8);
static const float3 FactionTintColor = float3(1.0,1.0,1.0);
static const float SpecularExponent = 50.0;

#elif defined(MATERIAL_PARAMS_ALIEN) 
// Fixed material parameters for Alien structures
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(1.0, 1.0, 1.0);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.788, 0.761, 1.0);
static const float3 FactionTintColor = float3(1.0,1.0,1.0);
static const float SpecularExponent = 30.0;
static const float RecolorScrollTextureSpeed = 0.08f;

#elif defined(MATERIAL_PARAMS_TIBERIUM) 
// Fixed material parameters for Alien structures
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(1.0, 1.0, 1.0);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float3 FactionTintColor = float3(1.0,1.0,1.0);
static const float SpecularExponent = 100.0;
static const float RecolorScrollTextureSpeed = 0.08f;

#elif defined(MATERIAL_PARAMS_INFANTRY)
// Fixed material parameters for INFANTRY
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float3 FactionTintColor = float3(1.0,1.0,1.0);
static const float SpecularExponent = 50.0;

#elif defined(MATERIAL_PARAMS_GDI)
// Fixed material parameters for GDI
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;
static const float3 FactionTintColor = float3(1.0,0.956,0.752);
//scroll speed for GDI texture
static const float RecolorScrollTextureSpeed = 0.08f;

#elif defined(MATERIAL_PARAMS_NOD)
// Fixed material parameters for NOD
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;
static const float3 FactionTintColor = float3(0.725,0.725,0.913);
//scroll speed for NOD texture
static const float RecolorScrollTextureSpeed = 0.08f;

#elif defined(MATERIAL_PARAMS_KANE)
// Fixed material parameters for NOD
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;
static const float3 FactionTintColor = float3(0.725,0.725,0.913);

#else
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

float3 FactionTintColor
<
	string UIName = "Color";
	string UIWidget = "Slider";
> = float3(1.0, 1.0, 1.0);

float RecolorScrollTextureSpeed
<
	string UIName = "RecolorScrollSpeed";
	float UIMin = 0.0f;
	float UIMax = 2.0f;
	float UIStep = 0.01f;
> = 0.0f;

#endif // Material parameters defined by UI


#if defined(SUPPORT_SPECMAP)
float EnvMult
<
	string UIName = "Reflection Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;
#endif //defined(SUPPORT_SPECMAP)

#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_ALPHATESTING)
// For damage texture rendering we always need alpha testing to be enabled. So don't offer it as configuration option.
const bool AlphaTestEnable = true;
//Force Alpha Test off unless using SUPPORT_DAMAGETEXTURE
#else
const bool AlphaTestEnable = false;
#endif



// ----------------------------------------------------------------------------
// Shroud
// $note (MD) -- used for MED & LOW LOD
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;

SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

#if !defined(USE_INDIRECT_CONSTANT) || defined(_3DSMAX_)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

float3 TintColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.TintColor";
> = float3(1, 1, 1);
#endif // #if !defined(USE_INDIRECT_CONSTANT)


// ----------------------------------------------------------------------------
// Upgrade Flash code -- TODO -- move to another shader
// ----------------------------------------------------------------------------
#if !defined(USE_INDIRECT_CONSTANT)
float FlashPct
<
	string UIWidget = "None";
	string SasBindAdress = "WW3D.FlashPct";
> = 1.0;
#endif

// ----------------------------------------------------------------------------
// UpgradeCrate shader needs these -- TODO -- move to another shader
//		-- how include? #include "Common.fxh" in CNC_UpgradeCrate.fx causes 3DSMax compile error w/ AmbientLights & DirectionalLights
// ----------------------------------------------------------------------------
#if defined(SUPPORT_SHADER_UPGRADECRATE)
SAMPLER_2D_BEGIN( CrateTiberiumA,
	string UIName = "Crate Tiberium A";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( CrateTiberiumB,
	string UIName = "Crate Tiberium B";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

float3 CrateEmissiveColor
<
	string UIName = "CrateEmissiveColor"; 
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);


#endif //defined(SUPPORT_SHADER_UPGRADECRATE)


// ----------------------------------------------------------------------------
// Energia Shader -- TODO -- move to another shader ?
// ----------------------------------------------------------------------------
#if defined(SUPPORT_SHADER_DEPLOYZONE)
float3 EnergiaColor
<
	string UIName = "Energia Color";
	string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);
#endif


// ----------------------------------------------------------------------------
// Environment texture for window/canopies. Faction Specific
// ----------------------------------------------------------------------------
#if defined(MATERIAL_PARAMS_NOD) || defined(OBJECT_TIBERIUM) //tiberium uses nod env cube
SAMPLER_CUBE_BEGIN( FactionEnvCube,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.NOD_Env_cube";
	string ResourceType = "Cube";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END
#else //defined(MATERIAL_PARAMS_GDI) 
//NOTE-MD even if MATERIAL_PARAMS_GDI is not defined, this env map is needed for the mirror plating buff effect
SAMPLER_CUBE_BEGIN( FactionEnvCube,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.GDI_Env_cube";
	string ResourceType = "Cube";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Mirror; //maybe use mirror ???
	AddressV = Mirror;
	AddressW = Mirror;
SAMPLER_CUBE_END
#endif //


//Tiberium test w/ specific cube map
#if defined(OBJECT_TIBERIUM)
SAMPLER_CUBE_BEGIN( TibEnvTexture,
	string UIName = "Tiberium Env Map";
	string ResourceType = "Cube";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END
#endif




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

//-----------------------------------------------------------------------------
// General functions that will be used by all or most meshes 

// House Color 
#if defined(SUPPORT_RECOLORING) && !defined(_3DSMAX_)
float4 CalculateHouseColor(float4 color, float EmissiveMask, bool recolorEnabled, float2 TexCoordScroll)
{
	float3 HouseColor = RecolorColor;
	if(recolorEnabled)
	{
		// $note (MD) -- HouseColorBloomIntensity is a scale factor for the House Color bloom
		//               Four Scale different scale factors are available:
		//					  HouseColorBloomIntensity.x for GDI Large Units
		//					  HouseColorBloomIntensity.y for GDI Small Units
		//					  HouseColorBloomIntensity.z for NOD Large Units
		//					  HouseColorBloomIntensity.w for NOD Small Units
		HouseColor.xyz *= HouseColorBloomIntensity[HouseColorUnitType];

		//get faction specific Scroll Texture if available
#if defined(MATERIAL_PARAMS_GDI) || defined(MATERIAL_PARAMS_NOD)
		float4 ScrollTexture = tex2D( SAMPLER(RecolorScrollTexture), TexCoordScroll + (RecolorScrollTextureSpeed * Time));
		HouseColor.xyz *= ScrollTexture.xyz;
#endif //MATERIAL_PARAMS_GDI/NOD

    	color.xyz = lerp(color.xyz, HouseColor.xyz, EmissiveMask);
	}

        //keep house color full alpha
#if !defined(SUPPORT_DAMAGETEXTURE)
	color.w = saturate(color.w + EmissiveMask);
#endif

	return color;
}
#endif

float GetEmissiveMask(float4 specMap, float2 texCoord0)
{
	float EmissiveMask = specMap.z; 
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

//-----------------------------------------------------------------------------
// Feature specific functions.
// $todo (MD) -- maybe move to a different .fx file?

// Upgrade/Veterancy Crate glow
#if defined(SUPPORT_SHADER_UPGRADECRATE)
float4 UpgradeCrate(float4 color, float EmissiveMask, float3 baseColor, float Time, float2 texCoord0, float2 Pos)
{
	float3 EmissiveColor = (CrateEmissiveColor.xyz * baseColor.xyz) * (20 * sin(Time * 6.0f) + 25.0f); 
	float4 TibCrateFill01 = tex2D( SAMPLER(CrateTiberiumA), float2(texCoord0.x + (Time * 0.06f) + Pos.x, texCoord0.y + (Time * 0.025f) + Pos.y));
	float4 TibCrateFill02 = tex2D( SAMPLER(CrateTiberiumB), float2(texCoord0.x - (Time * 0.075f) + Pos.x, texCoord0.y - (Time * 0.04f) + Pos.y));

	float4 fillcolor = TibCrateFill01 * TibCrateFill02; 
	color.xyz = lerp(color.xyz, EmissiveColor.xyz * fillcolor.xyz, EmissiveMask);

	return color;
}
#endif

#if defined(SUPPORT_SHADER_UPGRADEFLASH)
float4 CalculateUpgradeFlash(float4 color)
{
	float FlashMaxScale = 5.0f;	
	float FlashAmt = smoothstep(0.0f, 0.3f, FlashPct) * (1 - smoothstep(0.4f, 1.0f, FlashPct)) * FlashMaxScale;
#if defined(SUPPORT_RECOLORING) && !defined(_3DSMAX_)
	float3 FlashColor = RecolorColor.xyz;
#else
	float3 FlashColor = float3(0.0f, 0.2f, 1.0f);
#endif
	color.xyz = color.xyz + (color.xyz * FlashAmt) + (FlashAmt * FlashColor.xyz);
	return color;
}
#endif 


// Energia Effect
#if defined(SUPPORT_SHADER_DEPLOYZONE)
float4 CalculateEnergia(float4 BaseTexture, float2 TexCoord0, float Time)
{
	
	////Grid + minimal amount not on Grid
	float3 GridColor = (BaseTexture.xxx + 0.2f) * EnergiaColor;
	////add some white
	//GridColor += EnergiaColor * BaseTexture.w * 0.1f;

	
	//Right Edge
	//GridColor += step(5.75f, TexCoord0.x) * smoothstep(0,1,TexCoord0.x/5.75f);
	GridColor += smoothstep(0,1,TexCoord0.x - 5.6f) * EnergiaColor;
	//white out grid in this area
	GridColor += smoothstep(0,1,TexCoord0.x - 5.6f) * EnergiaColor* BaseTexture.w;
	
	//Left Edge
	GridColor += smoothstep(0,1, max(0, 1.0f - (TexCoord0.x + 0.5f))) * EnergiaColor;
	//white out grid in this area
	GridColor += smoothstep(0,1, max(0, 1.0f - (TexCoord0.x + 0.5f))) * EnergiaColor* BaseTexture.w;

	//Front Edge
	GridColor += smoothstep(0,1,TexCoord0.y - 0.5f) * EnergiaColor;
	//white out grid in this area
	GridColor += smoothstep(0,1, TexCoord0.y - 0.5f) * EnergiaColor* BaseTexture.w;

	//Back Edge
	GridColor += smoothstep(0,1, max(0, 1.0f - (TexCoord0.y + 2.0f))) * EnergiaColor;
	//white out grid in this area
	GridColor += smoothstep(0,1, max(0, 1.0f - (TexCoord0.y + 2.0f))) * EnergiaColor* BaseTexture.w; 



	//add animation of color through area
	//GridColor += abs(sin((1.0f - (TexCoord0.x / 5.6f) - 0.8f)));

	//urg fix this w/ correct pulsing anim
	//float pulse = (smoothstep(0,1,TexCoord0.x + fmod(Time, 5.6f))) - (smoothstep(0,1,TexCoord0.x - 0.5f + fmod(Time, 5.6f)));
	//float offset = fmod(Time * 2.0f, 5.6f);
	//float pulseMin = 0.0f + offset;
	//float pulseMax = 0.5f + offset;
	//float pulseSubMax = 1.0f + offset;
	//float pulse = smoothstep(pulseMin, pulseMax, TexCoord0.x) - smoothstep(pulseMax, pulseSubMax, TexCoord0.x);
	
	float offset = fmod(Time * 2.0f, 7.6f);
	float pulseMin = -1.0f + offset;
	float pulseMax = -0.5f + offset;
	float pulseSubMax = 0.0f + offset;
	float pulse = smoothstep(pulseMin, pulseMax, TexCoord0.x) - smoothstep(pulseMax, pulseSubMax, TexCoord0.x);

	
	GridColor += pulse * EnergiaColor * 0.2f;

	//white up the grid in the pulse area
	GridColor += pulse * BaseTexture.w * 0.5f;


	//TODO-MD TURN ON ALPHA TESTING
	float alpha = clamp(BaseTexture.w + (GridColor.x + GridColor.y + GridColor.z), 0.0f, 0.6f);


	//add white edgeing
	GridColor += step(TexCoord0.x, 0.01f) * 3.0f;
	GridColor += step(5.99f, TexCoord0.x) * 3.0f;
	GridColor += step(TexCoord0.y, -1.49f) * 3.0f; 
	GridColor += step(0.99f, TexCoord0.y) * 3.0f;


	return float4(GridColor.xyz, alpha);
}
#endif

// -----------------------------------------------------------------------------------------------------------------
// BUFFS: Following are all the unit specific RenderBuffEffects
// -----------------------------------------------------------------------------------------------------------------

float CalculateIntensity(float4 color)
{
	float3 greyscale = float3(0.3f, 0.59f, 0.11f);
	float intensity = color.x * greyscale.x + color.y * greyscale.y + color.z * greyscale.z;
	return intensity;
}



/////////////////////////////////////////////////////
// Tiberium Corrosion
float4 CalculateBuff_TibCorrosion(float4 color, float intensity, float emissiveMask, bool recolorEnabled, float2 texCoord0)
{
	float4 tibcolor = color;
	tibcolor.xyz = intensity * BuffTibColor;
	return lerp(color, tibcolor, RenderBuffEffectA.y);
}
// END Tiberium Corrosion
////////////////////////////////////////////////////


//////////////////////////////////////////////////////////
// Incinerator Prototype
//
float4 CalculateBuff_Incinerator(float4 color, float intensity)
{
	float4 burnColor = float4(1.0f, 0.4f, 0.0f, 1.0);
	float burnScale = 10.0f; 
	float incineratorlerpscale = 1.0f;
	return lerp(color, intensity * burnColor * burnScale * RenderBuffEffectA.z, incineratorlerpscale * RenderBuffEffectA.z); //replace 1.0fs w/ pct amount from game side
}
// END Incinerator
//////////////////////////////////////////////////////////



////////////////////////////////////////////////////
// Mirror Plating
float4 CalculateBuff_MirrorPlating(float4 color, float4 housecolor, float2 texCoord0, float2 screenTexCoord, float3 worldEyeDir)
{
	
	float4 BWorldNormalSpec = tex2D(SAMPLER(NormalSpecTexture), screenTexCoord) * 2.0 - 1.0;
	float3 BWorldNormal = BWorldNormalSpec.xyz;
	float3 BworldEyeDir = worldEyeDir;
	//TODO-MD test with no normalizing
	BworldEyeDir = normalize(BworldEyeDir);
	BWorldNormal = normalize(BWorldNormal);
	float3 BreflVect = -reflect(BworldEyeDir,BWorldNormal);
	
	//noise up lookup vec
	float2 reflTexCoord = texCoord0 * 0.5f;
	reflTexCoord.y *= 0.5f;
	reflTexCoord.x += Time * 0.03f;
	reflTexCoord.y += Time * 0.1f;
	float4 filtnoise = (tex2D(SAMPLER(FilteredNoise), reflTexCoord) - 0.5f) * 2.0f;

	BreflVect.xy += filtnoise.xy;

	//rotate
	float theta = 0.0f + (Time * 1.0f);
	//note 3rd column sin & cos used to add variation to rotation.
	//This vector is for env map lookup only, so doesn't need to use a correct rotation matrix
	matrix <float, 3,3> rotMat = {cos(theta), -sin(theta), cos(theta),  
								  sin(theta), cos(theta), sin(theta),
								  0, 0, 1};
	BreflVect = mul(rotMat,BreflVect);
	
	float3 Benvcolor = texCUBE( SAMPLER(FactionEnvCube), BreflVect);
	float3 basecolor =  float3(0.1f, 0.7f, 1.0f) * 0.2f;

	float4 mirrorcolor = color;
	mirrorcolor.xyz += ((mirrorcolor.xyz * Benvcolor.xyx) + (0.3f * Benvcolor.xyz)) * 2.0f; 
	mirrorcolor.xyz = mirrorcolor.xyz + basecolor.xyz;
	float mirrorlerpscale = 0.9f;
	float lerpamt = 0.0f;
#if defined(SUPPORT_MIRRORPLATING)
	lerpamt = 1.0f;
#else
	lerpamt = mirrorlerpscale * RenderBuffEffectB.x;
#endif

	//HACK-MD - recycled/emp'd units never got set to use the buff system...so need to handle mirrorshield with
	//			a buff that is being forced on through a shader override.
	//TODO-whoever -- remove all use of the EMP ShaderOverride & use the buff system.	
	color = lerp(color, mirrorcolor, lerpamt);

#if defined(SUPPORT_MIRRORPLATING_DISABLED)
	static const float DisabledColorScale = 0.1f;
	color.xyz *= DisabledColorScale;
#endif

	return color;

}
// END MIRROR PLATE
//////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////
// Personal shield 
//
float4 CalculateBuff_PersonalShield(float4 color, float WorldPosZ)
{
	float2 wldspcTexCoord = float2(0.5f, WorldPosZ); //texCoord0.x);
	float4 shieldramp = tex2D(SAMPLER(Buff_ShieldRamp), (wldspcTexCoord * 0.01f) + Time);

	float4 shieldhousecolor = float4(0.4f,0.6f,1.0f,1.0f);
#if defined(SUPPORT_RECOLORING) && !defined(_3DSMAX_)
	shieldhousecolor.xyz = RecolorColor.xyz;
#endif

	float shieldblendscale = 0.6f; //visually set max blend amount
	color.xyz = lerp(color.xyz, shieldramp * shieldhousecolor.xyz * 2.0f, shieldramp.x * shieldblendscale * RenderBuffEffectB.y);
	return color;
}
// END PERSONAL SHIELD -- version 2 ... Colonese Ramp
//////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////
// New Stealth Prototype
//
float4 CalculateBuff_Stealth(float4 color, float2 texCoord0, float objectPosX)
{
	//static const float3 glowColor = float3(0.05f, 0.0f, 0.5f);
	static const float3 glowColor = float3(0.5f, 0.0f, 0.0f);

	static const float stealthTexCoordScale = 0.004f;
	static const float timeScale = 1.0f;
	float2 stlthTexCoord = float2(0.5f, objectPosX); 
	float4 stlthramp = tex2D(SAMPLER(Buff_ShieldRamp), (stlthTexCoord * stealthTexCoordScale) + (Time * timeScale));         //0.002
	color.xyz += glowColor.xyz * 0.1 + glowColor.xyz * stlthramp * 2;
	//color.xyz += glowColor.xyz * stlthramp * 2;
	color.w = max(stlthramp.r, 0.5f);

	return color;
}
// END New Stealth
//////////////////////////////////////////////////////////



//////////////////////////////////////////////////////////
// EMP & UPGRADE PROTOTYPE
//	Needs Gameplay param to drive on/off or ramp value
//
float4 CalculateBuff_EMP(float4 color, float intensity, float2 texCoord0, float EmissiveMask, bool recolorEnabled)
{
	float4 empcolor = color;
	float adjustedintensity = smoothstep(0.0f, 1.5f, intensity);
	empcolor.xyz = adjustedintensity.xxx;
	color = color * 1.0; // eh? compile issue hack. Without this, color is always returned as full empcolor, even when lerp is 0.0
	return lerp(color, empcolor, RenderBuffEffectA.x); //need weighted version of this attached to scope param
}
// END EMP & UPGRADE
//////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////
// ColorShift
//	Tib Corrosion, incinerator, EMP combined
float4 CalculateBuff_ColorShift(float4 color, float intensity, float2 texCoord0, float EmissiveMask, bool recolorEnabled)
{
	//Color shifts list in order of increasing importance. Only most significant one will effect final color
	color = CalculateBuff_TibCorrosion(color, intensity, EmissiveMask, recolorEnabled, texCoord0);
	color = CalculateBuff_Incinerator(color, intensity);
	return color;
}
// END ColorShift
//////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////
// Low LOD version of buffs.
// 



float4 CalculateBuff_LowLOD(float4 color, float3 worldPos, float3 worldNormal, bool ShieldOn, bool MirrorOn, bool ColorShiftOn)
{
	//Low LOD Buffs.

if (ColorShiftOn)
{
	float intensity = CalculateIntensity(color);
	//Tiberium Corrosion
	color.xyz = lerp(color.xyz, (BuffTibColor * intensity).xyz, RenderBuffEffectA.y);
	//EMP/Upgrade
	color.xyz = lerp(color.xyz, intensity.xxx, RenderBuffEffectA.x);
	//Incinerator
	color.xyz = lerp(color.xyz, intensity.xxx * BuffIncineratorBurnColor.xyz * BuffBurnScale.xxx * RenderBuffEffectA.zzz, RenderBuffEffectA.z);
}

if (MirrorOn)
{
	//Mirror Shield -- will be a single texture instead of env map. That will scroll
	float3 Benvcolor = texCUBE( SAMPLER(FactionEnvCube), worldNormal);
	static const float MirrorScale = 0.5f;
	color.xyz = lerp(color.xyz, Benvcolor * 2.5, MirrorScale * RenderBuffEffectB.x); 
}

if (ShieldOn)
{
	//Personal Shield -- same as reg personal shield as it is pretty cheap.
	// note...try calc'ing in object space z
	color = CalculateBuff_PersonalShield(color, worldPos.z);
}

	return color;
}






// -----------------------------------------------------------------------------------------------------------------
// END BUFFS
// -----------------------------------------------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// !!!IMPORTANT!!!
//
// These shaders are specifically for the game because the game renderer uses
// deferred lighting.  There is a special shader for Max at the end of the file
//
// !!ANY CHANGES MADE TO THE GAME SHADER MUST BE REFLECTED IN THE MAX SHADERS!!
//
// ----------------------------------------------------------------------------
#if !defined(_3DSMAX_)

// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float4 Color : COLOR0;
//#if defined(MATERIAL_PARAMS_GDI) || defined(MATERIAL_PARAMS_NOD) || defined(SUPPORT_BUFF_MIRRORPLATING)
	float3 WorldEyeDir : TEXCOORD4;
//#endif
	float3 ObjectPosition : TEXCOORD2;
	float3 WorldPosition : TEXCOORD3;
};

VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
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

#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
	if (PreviewFullyDamaged)
	{
		VertexColor.w = 0.0;
	}
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

//#if defined(MATERIAL_PARAMS_GDI) || defined(MATERIAL_PARAMS_NOD) || defined(SUPPORT_BUFF_MIRRORPLATING)
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	Out.WorldEyeDir = worldEyeDir;
//#endif

 	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
 	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	//Note (md) -- was getting inconsistent data in VertexColor. So only using alpha
 	//Out.Color *= VertexColor; //
#if defined(SUPPORT_DAMAGETEXTURE)
	Out.Color.w = VertexColor.w;
#endif

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

	Out.ObjectPosition = InSkin.Position;

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

#if defined(SUPPORT_DAMAGETEXTURE)
	float2 texCoord1 = TexCoord1;
#else
	float2 texCoord1 = TexCoord0;
#endif

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

	return Out;
}


#if !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: VS_Xenon
// ----------------------------------------------------------------------------
VSOutput_H VS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int isMultiPass)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), isMultiPass);
}

#else // !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: VS_PS3_NoMultiPass
// ----------------------------------------------------------------------------
VSOutput_H VS_PS3_NoMultiPass(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3)
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2)
#endif
)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), false);
}


#endif // !defined(EA_PLATFORM_PS3)


// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - High
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			float2 vPos : PIXELLOC, uniform bool stealthEnabled, uniform bool ShieldOn, uniform bool MirrorOn,
								    uniform bool ColorShiftOn, uniform int isMultiPass) COLORTARGET
{	
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);

#if defined(_W3DVIEW_)
	// $todo (wkan) 2009/05/21 - Fix this when we are fixing directional light for w3xviewer
	return baseTexture;
#endif // #if defined(_W3DVIEW_)


// Energia Effect
#if defined(SUPPORT_SHADER_DEPLOYZONE)
	return CalculateEnergia(baseTexture, texCoord0, Time);
#endif

	float4 specMap = GetSpecMap(texCoord0);
	float EmissiveMask = GetEmissiveMask(specMap, texCoord0);

	baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;

#if defined (IGNORE_DIFFUSE_ALPHA)
	float4 color = float4(baseTexture.xyz, 1.0f);
#else
	float4 color = baseTexture;
#endif

//#if !defined(SUPPORT_ALPHATESTING)
	color.xyz *= In.Color.xyz; 
//#endif

	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 diffuseLight = SampleDiffuseLight(screenTexCoord); 
	float3 specularLight = SampleSpecularLight(screenTexCoord); 

	//Spec needs to be suppressed during stealth
#if defined(SUPPORT_STEALTH)
	specularLight *= 0.0f;
#endif

	color.xyz += (diffuseLight * diffuse) + (specularLight * SpecularColor * specMap.x);


#if defined(MATERIAL_PARAMS_ALIEN) 
	//Alien Scrolling texture
	float alienScrollTime = Time * 0.2f;

	//need WorldNormal & WorldEyeDir
	float4 WorldNormalSpec = tex2D(SAMPLER(NormalSpecTexture), screenTexCoord) * 2.0 - 1.0;
	float3 worldNormal = WorldNormalSpec.xyz; //note -- CNC3 added bump to spec...but that is already accomplished by this point
	float3 worldEyeDir = In.WorldEyeDir;
	//test w/ no normalizing
	float3 reflVect = -reflect(worldEyeDir, worldNormal);
	float2 envTexCoord = ((reflVect.y + reflVect.x + (alienScrollTime * 1.0f)) * 0.53f); //0.33f);
	float3 envcolor = tex2D( SAMPLER(AlienEnvScrollTexture), envTexCoord);

	color.xyz *= envcolor.xyz;
	color.xyz += envcolor.xyz * 0.01f;

#elif defined(OBJECT_TIBERIUM)

	// Tiberium specific lighting
	float4 tibcolor = float4(baseTexture.xyz, 1.0f) * 0.3f;
	float tibintensity = clamp(0.5f, 1.0f, CalculateIntensity(baseTexture));
	tibcolor.xyz += (diffuseLight * diffuse) + (specularLight * SpecularColor * specMap.x * tibintensity);

	// Tiberium reflection/refraction
	//Faction Specific Environment Maps (masked by spec map green channel)
	float4 WorldNormalSpec = tex2D(SAMPLER(NormalSpecTexture), screenTexCoord) * 2.0 - 1.0;
	float3 WorldNormal = WorldNormalSpec.xyz;
	float3 worldEyeDir = In.WorldEyeDir;
	//test with no normalizing
	worldEyeDir = normalize(worldEyeDir);
	WorldNormal = normalize(WorldNormal);

	float3 reflVect = -reflect(worldEyeDir,WorldNormal);


	//rotate
	float theta = 0.0f + (Time * 0.0725f);
	//note 3rd column sin & cos used to add variation to rotation.
	//This vector is for env map lookup only, so doesn't need to use a correct rotation matrix
	matrix <float, 3,3> rotMat = {cos(theta), -sin(theta), cos(theta),  
								  sin(theta), cos(theta), sin(0.5 * theta),
								  0, 0, 1};
	reflVect = mul(rotMat,reflVect);
	float3 envcolor = texCUBE( SAMPLER(TibEnvTexture), reflVect) * 0.5f;	
	tibcolor.xyz *= envcolor.xyz;
	color = tibcolor;

#elif defined(MATERIAL_PARAMS_GDI) || defined(MATERIAL_PARAMS_NOD)
	//Faction Specific Environment Maps (masked by spec map green channel)
	float4 WorldNormalSpec = tex2D(SAMPLER(NormalSpecTexture), screenTexCoord) * 2.0 - 1.0;
	float3 WorldNormal = WorldNormalSpec.xyz;
	float3 worldEyeDir = In.WorldEyeDir;
	//test with no normalizing
	worldEyeDir = normalize(worldEyeDir);
	WorldNormal = normalize(WorldNormal);
	float3 reflVect = -reflect(worldEyeDir,WorldNormal);
	float3 envcolor = texCUBE( SAMPLER(FactionEnvCube), reflVect);
	color.xyz += (color.xyz * envcolor.xyx * specMap.g) + (0.1f * envcolor.xyz * specMap.g); 
#endif


#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= damagedTexture * (1 - In.Color.w);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
#else 
	color.w *= In.Color.w;
#endif
	
	color.xyz *= TintColor * FactionTintColor;


	// $TODO - (MD)
	// BETTER WAY TO HANDLE ONE OFF FUNCTIONS -- particularly w/ samplers
// UpgradeCrate specific function
#if defined(SUPPORT_SHADER_UPGRADECRATE)
	color = UpgradeCrate(color, EmissiveMask, baseTexture.xyz, Time, texCoord0, screenTexCoord);
#endif

// Pending adding Shader override in code for upgrade flash
#if defined(SUPPORT_SHADER_UPGRADEFLASH)
// Flash for upgrades
	color = CalculateUpgradeFlash(color);
#endif
//Emissive Coloring -- overwrites any color value w/ emissive
#if defined(SUPPORT_EMISSIVE)
	color.xyz = lerp(color.xyz, baseTexture.xyz, EmissiveMask); 
#endif

	//TODO-MD - should be moved up as high as possible
#if defined(SUPPORT_STEALTH)
	//TODO-MD -- IMPORTANT....CHANGE THIS TO OBJECT SPACE X
	float objectX = In.ObjectPosition.x; 
	color.w = 1.0f;
	color = CalculateBuff_Stealth(color, texCoord0, objectX); 
	#if defined(SUPPORT_RECOLORING)
		color = CalculateHouseColor(color, EmissiveMask, recolorEnabled, texCoord0);
	#endif

	return color;
#endif

////////////////////////////////////////////////////////////////////////////////////////
// BUFFS
////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////
	// Buffs Shared
	//#if def out this.
	
	float intensity = CalculateIntensity(color);
	float4 housecolor = float4(0.0f, 0.0f, 0.0f, 0.0f);

	if (ColorShiftOn)
	{
		color = CalculateBuff_ColorShift(color, intensity, texCoord0, EmissiveMask, recolorEnabled);
	}

#if defined(SUPPORT_MIRRORPLATING)
	color = CalculateBuff_MirrorPlating(color, housecolor, texCoord0, screenTexCoord, In.WorldEyeDir);
#else
	if (MirrorOn)
	{
		color = CalculateBuff_MirrorPlating(color, housecolor, texCoord0, screenTexCoord, In.WorldEyeDir);
	}
#endif

	if (ShieldOn)
	{
		color = CalculateBuff_PersonalShield(color, In.WorldPosition.z);
	}
 
	//NOTE -- EMP/Upgrade must be last	
	if (ColorShiftOn)
	{
		color = CalculateBuff_EMP(color, intensity, texCoord0, EmissiveMask, recolorEnabled);
	}
////////////////////////////////////////////////////////////////////////////////////////
// end BUFFS
////////////////////////////////////////////////////////////////////////////////////////


//NOTE - MD -- apply House Color after Buffs, since HouseColor needs to be visible even during buff effects
// House Color
#if defined(SUPPORT_RECOLORING)
	color = CalculateHouseColor(color, EmissiveMask, recolorEnabled, texCoord0);
#endif

	//return color;



#if SUPPORT_SSAO
	color.xyz *= ComputeSSAO(vPos);
#endif

	return CorrectForFrameBufferGamma(color);
}


//#if !defined(EA_PLATFORM_PS3)
//
//// ----------------------------------------------------------------------------
//// SHADER: PS_Xenon
//// ----------------------------------------------------------------------------
//float4 PS_Xenon( VSOutput_H In, float2 vPos : PIXELLOC, uniform int isMultiPass) : COLOR
//{
//	return PS_H( In, HasShadow, HasRecolorColors, vPos, StealthEnabled, isMultiPass);
//}
//
//#else // !defined(EA_PLATFORM_PS3)
//
//// ----------------------------------------------------------------------------
//// SHADER: PS_PS3_NoMultiPass
//// ----------------------------------------------------------------------------
//float4 PS_PS3_NoMultiPass( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
//{
//	return PS_H( In, HasShadow, HasRecolorColors, vPos, true, false);
//}
//
//#endif // !defined(EA_PLATFORM_PS3)

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


#define PS_H_NumShadows(recolorEnabled, stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass) \
	compile PS_3_0 PS_H(0, recolorEnabled, stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass), \
	compile PS_3_0 PS_H(1, recolorEnabled, stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_RecolorEnabled = PS_H_Multiplier_NumShadows * 2 );
	
#define PS_H_RecolorEnabled(stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass) \
	PS_H_NumShadows(false, stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass), \
	PS_H_NumShadows(true,  stealthEnabled, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_StealthEnabled = PS_H_Multiplier_RecolorEnabled * 2);

#define PS_H_StealthEnabled(ShieldOn, MirrorOn, ColorShiftOn, isMultiPass) \
	PS_H_RecolorEnabled(false, ShieldOn, MirrorOn, ColorShiftOn, isMultiPass), \
	PS_H_RecolorEnabled(true,  ShieldOn, MirrorOn, ColorShiftOn, isMultiPass)

//DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_StealthEnabled * 2 );





//stealth -- reuse stealthEnabled -- but test w/ buff vector version of stealth

//personal shield
DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_BuffShield = PS_H_Multiplier_StealthEnabled * 2 );
#define PS_H_BuffShield(MirrorOn, ColorShiftOn, isMultiPass) \
	PS_H_StealthEnabled(false, MirrorOn, ColorShiftOn, isMultiPass), \
	PS_H_StealthEnabled(true,  MirrorOn, ColorShiftOn, isMultiPass)


//mirror plate
DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_BuffMirror = PS_H_Multiplier_BuffShield * 2 );
#define PS_H_BuffMirror(ColorShiftOn, isMultiPass) \
	PS_H_BuffShield(false, ColorShiftOn, isMultiPass), \
	PS_H_BuffShield(true, ColorShiftOn, isMultiPass)

//color shift for corrosion, incinerator, emp/upgrade
DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_BuffColorShift = PS_H_Multiplier_BuffMirror * 2 );
#define PS_H_BuffColorShift(isMultiPass) \
	PS_H_BuffMirror(false, isMultiPass), \
	PS_H_BuffMirror(true, isMultiPass)




DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_BuffColorShift * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_H_Array[PS_H_Multiplier_Final] =
	{
		PS_H_BuffColorShift(FIRSTPASS)
	};

//color shift arrays


#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
#if !defined(SUPPORT_DAMAGETEXTURE) && !defined(SUPPORT_ALPHATESTING) && !defined(SUPPORT_SHADER_DEPLOYZONE) && !defined(SUPPORT_STEALTH)
	<
		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
	>
#endif
	{

#if !defined(EA_PLATFORM_PS3)
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon(false) );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled
			+ 0 * PS_H_Multiplier_StealthEnabled  //todo -- remove stealth if using 
			+ (RenderBuffEffectB.y > 0.0f) * PS_H_Multiplier_BuffShield
			+ (RenderBuffEffectB.x > 0.0f) * PS_H_Multiplier_BuffMirror
			+ ((RenderBuffEffectA.x + RenderBuffEffectA.y + RenderBuffEffectA.z) > 0.0f) * PS_H_Multiplier_BuffColorShift,
			compile PS_VERSION PS_Xenon(false) );
#else // !defined(EA_PLATFORM_PS3)
		VertexShader = compile VS_VERSION VS_PS3_NoMultiPass();
		PixelShader = compile PS_VERSION PS_PS3_NoMultiPass();
#endif // !defined(EA_PLATFORM_PS3)

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
#if (defined(SUPPORT_STEALTH) && defined(SUPPORT_DAMAGETEXTURE)) || defined(SUPPORT_PREVIEW_AND_DAMAGE)
		ColorWriteEnable = 0;
#endif
		
#if defined(SUPPORT_STEALTH)
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#elif defined(SUPPORT_ALPHATESTING)
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
#elif defined(SUPPORT_DAMAGETEXTURE)
		AlphaBlendEnable = false; //(StealthEnabled);
		AlphaTestEnable = true; //(StealthEnabled != 1); //!StealthEnabled in a xenon compiling form
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#elif defined(SUPPORT_SHADER_DEPLOYZONE)
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#else
		#if !EXPRESSION_EVALUATOR_ENABLED		
			AlphaBlendEnable = ( OpacityOverride < 0.99 );
		#endif
		#if !EXPRESSION_EVALUATOR_ENABLED		
			AlphaTestEnable = ( AlphaTestEnable );
		#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}


#if (defined(SUPPORT_STEALTH) && defined(SUPPORT_DAMAGETEXTURE)) || defined(SUPPORT_PREVIEW_AND_DAMAGE)
	pass p1
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon(false) );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled
			+ 0 * PS_H_Multiplier_StealthEnabled  //todo -- remove stealth if using 
			+ (RenderBuffEffectB.y > 0.0f) * PS_H_Multiplier_BuffShield
			+ (RenderBuffEffectB.x > 0.0f) * PS_H_Multiplier_BuffMirror
			+ ((RenderBuffEffectA.x + RenderBuffEffectA.y + RenderBuffEffectA.z) > 0.0f) * PS_H_Multiplier_BuffColorShift,
			compile PS_VERSION PS_Xenon(false) );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;


		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
#endif // SUPPORT_STEALTH



}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: DEFAULT (Medium)
// ----------------------------------------------------------------------------
struct VSOutput_M {

	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float4 LightVector[NumDirectionalLightsPerPixel_M] : TEXCOORD1_CENTROID;
	float3 HalfEyeLightVector : TEXCOORD2_CENTROID;
	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD4;
	float3 MacroTexCoord : TEXCOORD5; //xy is MacroTexCoord, z is ObjectSpace Position.x -- hack since out of registers
	float3 WorldTangentEyeDir : TEXCOORD6;
	float3 WorldPosition : TEXCOORD7;
	float3 WorldNormal : TEXCOORD8;
	float4 Color : COLOR0;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
	USE_TEXCOORD(TexCoord1);
#endif

	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_M Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	Out.WorldPosition = worldPosition;
	Out.WorldNormal = worldNormal;

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
	if (PreviewFullyDamaged)
	{
		VertexColor.w = 0.0;
	}
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	
	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));
	Out.LightVector[0] = float4(mul(DirectionalLight_0_Direction.xyz, worldToTangentSpace), 0);

	// Compute half direction between view and light direction in tangent space
	Out.HalfEyeLightVector.xyz = normalize(mul(DirectionalLight_0_Direction.xyz + worldEyeDir, worldToTangentSpace));

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 0;
	diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	
	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;
	Out.Color *= VertexColor;

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;


#if defined(SUPPORT_DAMAGETEXTURE)
	float2 texCoord1 = TexCoord1;
#else
	float2 texCoord1 = TexCoord0;
#endif

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);

	Out.WorldTangentEyeDir = mul(worldEyeDir, worldToTangentSpace);
	
	// $todo (MD) -- don't need shroud tex coords ... see if we can compact another var here
	Out.ShroudTexCoord_CloudTexCoord.xy = 0; //CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
	Out.MacroTexCoord.xy = CalculateMacroTexCoord(worldPosition);

	//Out of output registers...using unused z slot in MacroTexCoord to pass object space position x which is used for stealth
	Out.MacroTexCoord.z = InSkin.Position.x;
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------

float4 PS_M(VSOutput_M In, uniform bool hasShadow, 
						uniform bool ColorShiftOn, uniform bool ShieldOn, uniform bool MirrorOn, 
						uniform bool recolorEnabled, uniform int isMultiPass, float2 vPos : PIXELLOC) COLORTARGET
{
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;

	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
	float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	
	float3 specularColor = SpecularColor;

	// ngavalas
	// Yes there is duplicate code here, but duplicating it makes it slightly more understandable
	// as to what is going on. Basically, if we are support recoloring and specular mapping, 
	// we can save a texture read since they use the same texture.
	// If we are using one or the other then we just do the texture read and calculate
	// the values normally.
#if defined(SUPPORT_RECOLORING) && defined(SUPPORT_SPECMAP)
	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	specularColor = SpecularColor * specularStrength;

	if (recolorEnabled)
	{
		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, specTexture.z);
	}
#elif defined(SUPPORT_SPECMAP)
	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	specularColor = SpecularColor * specularStrength;
#elif defined(SUPPORT_RECOLORING)
	float4 HouseColorMap = tex2D( SAMPLER(RecolorScrollTexture), texCoord0);
	if (recolorEnabled)
	{
		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, HouseColorMap.r);
	}
#endif

	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;

	// Get bump map normal
#if defined(SUPPORT_NORMALMAP)
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
#else
	float3 bumpNormal = float3(0,0,1);
#endif
	
	float4 color = baseTexture;
	color.xyz *= In.Color.xyz;

		// Compute lighting
        float3 lightVec = In.LightVector[0].xyz;
        float3 halfVec  = In.HalfEyeLightVector.xyz;

        float4 diffuseTerm = dot( bumpNormal, lightVec );
        float4 specularTerm = dot( bumpNormal, halfVec );

		float4 lighting = lit( diffuseTerm, specularTerm, SpecularExponent );

		if (hasShadow)
		{
			lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_DEFAULT );
		}
		
		float3 cloud = float3(1, 1, 1);			
#if defined(_WW3D_) && !defined(_W3DVIEW_)
		cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
#endif
		color.xyz += DirectionalLight_0_Color.xyz * cloud * (diffuse * lighting.y + specularColor * lighting.z);

// this is ugly but I couldn't think of a better way to do it. -Sean

#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
//	color *= lerp(damagedTexture,  float4(1.0, 1.0, 1.0, 0.0) , ( In.Color.w));
	color *= damagedTexture * (1 - In.Color.w);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
#else  
	color.w *= In.Color.w;
#endif	

	//$todo (MD) -- do we need to support TintColor??
	color.xyz *= TintColor * FactionTintColor;

	//Stealth
#if defined(SUPPORT_STEALTH)
	//MacroTexCoord.z holds Object space position x
	color = CalculateBuff_Stealth(color, texCoord0, In.MacroTexCoord.z);
#endif

	//Bufs
	color = CalculateBuff_LowLOD(color, In.WorldPosition, In.WorldNormal, ShieldOn, MirrorOn, ColorShiftOn );

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord_CloudTexCoord.xy ).x;
#endif

	return color;
}

// We only want to do this for the really expensive part. The rest of the shader can be normal.
//#undef float4
//#undef float3
//#undef float2
//#undef float


// ----------------------------------------------------------------------------
// Arrays: Default_M
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );

#define VS_M_NumJointsPerVertex(isMultiPass) \
	compile VS_3_0 VS_M(0, isMultiPass), \
	compile VS_3_0 VS_M(1, isMultiPass)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex(FIRSTPASS)
};

	
#endif

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_HasShadow = 1 );

#define PS_M_HasShadow(ColorShiftOn, ShieldOn, MirrorOn, recolorEnabled, isMultiPass) \
	compile PS_3_0 PS_M(false, ColorShiftOn, ShieldOn, MirrorOn, recolorEnabled, isMultiPass), \
	compile PS_3_0 PS_M(true, ColorShiftOn, ShieldOn, MirrorOn, recolorEnabled, isMultiPass)



DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_BuffColorShift = PS_M_Multiplier_HasShadow * 2 );
#define PS_M_BuffColorShift(ShieldOn, MirrorOn, recolorEnabled, isMultiPass) \
	PS_M_HasShadow(false, ShieldOn, MirrorOn, recolorEnabled, isMultiPass), \
	PS_M_HasShadow(true, ShieldOn, MirrorOn, recolorEnabled, isMultiPass)



DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_BuffShield = PS_M_Multiplier_BuffColorShift * 2 );
#define PS_M_BuffShield(MirrorOn, recolorEnabled, isMultiPass) \
	PS_M_BuffColorShift(false, MirrorOn, recolorEnabled, isMultiPass), \
	PS_M_BuffColorShift(true, MirrorOn, recolorEnabled, isMultiPass)


DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_BuffMirror = PS_M_Multiplier_BuffShield * 2 );
#define PS_M_BuffMirror(recolorEnabled, isMultiPass) \
	PS_M_BuffShield(false, recolorEnabled, isMultiPass), \
	PS_M_BuffShield(true, recolorEnabled, isMultiPass)


DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_RecolorEnabled = PS_M_Multiplier_BuffMirror * 2 );
#define PS_M_RecolorEnabled(isMultiPass) \
	PS_M_BuffMirror(false, isMultiPass), \
	PS_M_BuffMirror(true, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_RecolorEnabled(FIRSTPASS)
};

#endif

// ----------------------------------------------------------------------------
// Technique: Default_M
// ----------------------------------------------------------------------------
technique Default_M
{
	pass p0
#if !defined(SUPPORT_DAMAGETEXTURE)
	<
		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
	>
#endif
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
			min(NumJointsPerVertex, 1), 
			NO_ARRAY_ALTERNATIVE);

		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			HasShadow * PS_M_Multiplier_HasShadow
			+ HasRecolorColors * PS_M_Multiplier_RecolorEnabled
			+ (RenderBuffEffectB.y > 0.0f) * PS_M_Multiplier_BuffShield
			+ (RenderBuffEffectB.x > 0.0f) * PS_M_Multiplier_BuffMirror
			+ ((RenderBuffEffectA.x + RenderBuffEffectA.y + RenderBuffEffectA.z) > 0.0f) * PS_M_Multiplier_BuffColorShift,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaBlendEnable = false;
		
#else
		#if !EXPRESSION_EVALUATOR_ENABLED		
			AlphaBlendEnable = ( OpacityOverride < 0.99);
		#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaTestEnable = true;


#else
	#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaTestEnable = ( AlphaTestEnable );
	#endif
#endif
	}

}



// ----------------------------------------------------------------------------
// SHADER: Low
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float3 FallOffColor : TEXCOORD2;
	float3 WorldPosition : TEXCOORD3;
	float3 WorldNormal : TEXCOORD4;
	float3 ObjectPosition : TEXCOORD5;
};

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int numJointsPerVertex)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE)
	USE_TEXCOORD(TexCoord1);
#endif

	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_L Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	Out.WorldPosition = worldPosition;
	Out.WorldNormal = worldNormal;

	Out.ObjectPosition = InSkin.Position;

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
	if (PreviewFullyDamaged)
	{
		VertexColor.w = 0.0;
	}
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
	
	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 0;
	diffuseLight += DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, DirectionalLight_0_Direction.xyz));
	diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
	diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	
	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;
	
	Out.Color *= VertexColor;

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

#if defined(SUPPORT_DAMAGETEXTURE)
	float2 texCoord1 = TexCoord1;
#else
	float2 texCoord1 = TexCoord0;
#endif //defined(SUPPORT_DAMAGETEXTURE)

	Out.FallOffColor = float3(1,1,1);

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_L In, uniform bool recolorEnabled,
						uniform bool ShieldOn, uniform bool MirrorOn,
						uniform bool ColorShiftOn) COLORTARGET
{
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	
	float4 color = baseTexture;
	//$todo (MD) -- do we need to mult by vertex color?
	color.xyz *= In.Color.xyz;

// this is ugly but I couldn't think of a better way to do it. -Sean

#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= damagedTexture * (1 - In.Color.w);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
#else 
	color.w *= In.Color.w;
#endif //defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)


	//$todo (MD) -- do we need to support TintColor
	color.xyz *= TintColor * FactionTintColor;


	//Bufs
	color = CalculateBuff_LowLOD(color, In.WorldPosition, In.WorldNormal, ShieldOn, MirrorOn, ColorShiftOn );
	//end Buffs

//Stealth
#if defined(SUPPORT_STEALTH)
	color = CalculateBuff_Stealth(color, texCoord0, In.ObjectPosition.x);
#endif

	//House Color
	//NOTE - MD -- apply House Color after Buffs, since HouseColor needs to be visible even during buff effects
#if defined(SUPPORT_RECOLORING)
	float4 specMap = GetSpecMap(texCoord0);
	color.xyz = lerp(color.xyz, RecolorColor, specMap.b);
#endif



#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).x;
#endif

	return color;
}

// ----------------------------------------------------------------------------
// Arrays: Default_L
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );

#define VS_L_NumJointsPerVertex \
	compile VS_2_0 VS_L(0), \
	compile VS_2_0 VS_L(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};
#endif


DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_BuffColorShift = 1 );
#define PS_L_BuffColorShift(ShieldOn, MirrorOn, RecolorEnabled) \
	compile PS_2_0 PS_L(false, ShieldOn, MirrorOn, RecolorEnabled), \
	compile PS_2_0 PS_L(true, ShieldOn, MirrorOn, RecolorEnabled)



DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_BuffShield = PS_L_Multiplier_BuffColorShift * 2 );
#define PS_L_BuffShield(RecolorEnabled, MirrorOn) \
	PS_L_BuffColorShift(false, MirrorOn, RecolorEnabled), \
	PS_L_BuffColorShift(true, MirrorOn, RecolorEnabled)


DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_BuffMirror = PS_L_Multiplier_BuffShield * 2 );
#define PS_L_BuffMirror(RecolorEnabled) \
	PS_L_BuffShield(false, RecolorEnabled), \
	PS_L_BuffShield(true, RecolorEnabled)


DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_RecolorEnabled = PS_L_Multiplier_BuffMirror * 2);
#define PS_L_RecolorEnabled \
	PS_L_BuffMirror(false), \
	PS_L_BuffMirror(true)


DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_RecolorEnabled
};
#endif

// ----------------------------------------------------------------------------
// Technique: Default_L
// ----------------------------------------------------------------------------
technique Default_L
{
	pass p0
#if !defined(SUPPORT_DAMAGETEXTURE)
	<
		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
	>
#endif
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
			min(NumJointsPerVertex, 1), 
			NO_ARRAY_ALTERNATIVE);

		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
			HasRecolorColors * PS_L_Multiplier_RecolorEnabled
			+ (RenderBuffEffectB.y > 0.0f) * PS_L_Multiplier_BuffShield
			+ (RenderBuffEffectB.x > 0.0f) * PS_L_Multiplier_BuffMirror
			+ ((RenderBuffEffectA.x + RenderBuffEffectA.y + RenderBuffEffectA.z) > 0.0f) * PS_L_Multiplier_BuffColorShift,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaBlendEnable = false;
#else
		#if !EXPRESSION_EVALUATOR_ENABLED		
			AlphaBlendEnable = ( OpacityOverride < 0.99);
		#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#endif //defined(SUPPORT_DAMAGETEXTURE)

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaTestEnable = true;

#else
	#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaTestEnable = ( AlphaTestEnable );
	#endif //!EXPRESSION_EVALUATOR_ENABLED
#endif
	} //defined(SUPPORT_DAMAGETEXTURE)
}


#endif // ENABLE_LOD

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
	float4	Normal	: COLOR0;

#if !defined(EA_PLATFORM_XENON)
	float4	Depth		: COLOR1;
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

#else // !defined(_3DSMAX_)

// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float3 TangentToViewSpace0 : TEXCOORD1_CENTROID;
	float3 TangentToViewSpace1 : TEXCOORD2_CENTROID;
	float3 TangentToViewSpace2 : TEXCOORD3_CENTROID;
	float3 WorldPosition : TEXCOORD4;
	float4 ShadowMapTexCoord : TEXCOORD5;
	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD6;
	float4 Color : COLOR0;
};

VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
	USE_TEXCOORD(TexCoord1);
#endif

	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
	if (PreviewFullyDamaged)
	{
		VertexColor.w = 0.0;
	}
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	
	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];


	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 1.0.xxx;
	if (NumDirectionalLights > 2)
	{
		diffuseLight = DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}
	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;

	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	Out.Color *= VertexColor;

	Out.WorldPosition = worldPosition;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_SOFT);

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;


	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

#if defined(SUPPORT_DAMAGETEXTURE)
	float2 texCoord1 = TexCoord1;
#else
	float2 texCoord1 = TexCoord0;
#endif

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

	// $todo (MD) -- don't need shroud tex coords...try & pack another var here instead
	Out.ShroudTexCoord_CloudTexCoord.xy = 0; //CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - 3DSMAX ONLY
//								- The lighting does not match game lighting. This 
//								  pixel shader provides basic lighting so the artists
//								  can preview textures in max.
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			float2 vPos : PIXELLOC, uniform int isMultiPass) COLORTARGET
{	
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
	float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;
	float3 worldEyeDir = normalize(GetEyePosition() - In.WorldPosition);

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	

	baseTexture.xyz = GammaToLinear(baseTexture.xyz);

	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;

	// Get bump map normal
#if defined(SUPPORT_NORMALMAP)
	float3 bumpNormal = (float3)tex2D(SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;	
#else
	float3 bumpNormal = float3(0,0,1);
#endif

	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	
	// Bring bump normal into world space
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	bumpNormal = mul(bumpNormal, TangentToViewSpace);
	bumpNormal = normalize(bumpNormal);

	float4 color = baseTexture;
	//$todo (MD) -- need to mult by vertex color?
	color.xyz *= In.Color.xyz;

	float3 specularColor = SpecularColor;
	
	float shadowSampler = 1;
	if (hasShadow)
	{
		shadowSampler = shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_SOFT );
	}

// RR 1/8/09: Since we commented out the setting of LightSpaceEnvironmentMap in file RotateEnvironmentMap.scrapeh we don't do any of the environment mapping calculation.
// floating point texture is not workineg yet. The envcolor would be set to random color flashes in xenon if we don't do this check.
#if defined(SUPPORT_SPECMAP) 
	// Read spec map
	float4 specTexture = tex2D(SAMPLER(SpecMap), texCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	
	
	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	
	// Compute view direction in world space
	float3 reflVect = -reflect(worldEyeDir,bumpNormal);

	// Although not technically correct, since we use the Cubemap to fake specular, multiply against the shadow map and add to color
	float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz;
	

	specularColor = 3 * specularStrength * specularColor;

	//$TODO (MD)	-- envcolor was zero, so was wiping out all color info up to this point. Changed it to additive.
	//					-- need to correct calculation for env map info
	color.xyz += envcolor;
#endif // SUPPORT_SPECMAP

		float3 cloud = float3(1, 1, 1);
#if defined(_WW3D_) && !defined(_W3DVIEW_)
		cloud = GammaToLinear(tex2D( SAMPLER(CloudTexture), cloudTexCoord).xyz);
#endif
		cloud *= shadowSampler;		
		
		float3 diffuseLight = 0.0.xxx;
		if (NumDirectionalLights > 0)
		{
			diffuseLight += DirectionalLight_0_Color.rgb * cloud * (max(0, dot(bumpNormal, DirectionalLight_0_Direction.xyz)));
		}
		
		if (NumDirectionalLights > 1)
		{
			diffuseLight += DirectionalLight_1_Color.rgb * (max(0, dot(bumpNormal, DirectionalLight_1_Direction.xyz)));
		}

		//lighting
		float3 lightVec = DirectionalLight_0_Direction.xyz;
		float3 halfVec = normalize(worldEyeDir + DirectionalLight_0_Direction.xyz);
		float4 diffuseTerm = max(0, dot(bumpNormal, lightVec));
		float4 specularTerm = max(0, dot(bumpNormal, halfVec));
		float4 lighting = lit(diffuseTerm, specularTerm, SpecularExponent);

		color.xyz += diffuseLight * diffuse * lighting.y + specularColor * lighting.z;

#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= damagedTexture * (1 - In.Color.w);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
#else 
	color.w *= In.Color.w;
#endif

	//$todo (MD) -- support TintColor??
		color.xyz *= TintColor * FactionTintColor;


#if defined(SUPPORT_RECOLORING)
	// $todo (MD) -- Need to clean up House Color system so only one color & one bool are defined and used
	if (HasRecolorColors)
	{
		float4 specMap = GetSpecMap(texCoord0);
		float EmissiveMask = GetEmissiveMask(specMap, texCoord0);
		color.xyz = lerp(color.xyz, RecolorSecondaryColor, EmissiveMask);
	}
#endif
	

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D(SAMPLER(ShroudTexture), shroudTexCoord).x;
#endif

#if SUPPORT_SSAO
	color.xyz *= ComputeSSAO(vPos);
#endif

	return CorrectForFrameBufferGamma(color);
}

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

#define PS_H_NumShadows(recolorEnabled, isMultiPass) \
	compile PS_3_0 PS_H(0, recolorEnabled, isMultiPass), \
	compile PS_3_0 PS_H(1, recolorEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_RecolorEnabled = PS_H_Multiplier_NumShadows * 2 );
	
#define PS_H_RecolorEnabled(isMultiPass) \
	PS_H_NumShadows(false, isMultiPass), \
	PS_H_NumShadows(true, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_H_Array[PS_H_Multiplier_Final] =
	{
		PS_H_RecolorEnabled(FIRSTPASS)
	};
	
		
#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
#if !defined(SUPPORT_DAMAGETEXTURE) && !defined(SUPPORT_CHRONORIFT)
	<
		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
	>
#endif
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			NULL );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled,
			NULL );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaBlendEnable = false;
		
		#if !EXPRESSION_EVALUATOR_ENABLED		
			AlphaBlendEnable = ( OpacityOverride < 0.99);
		#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if defined(SUPPORT_DAMAGETEXTURE)
		AlphaTestEnable = true;


#else
	#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaTestEnable = ( AlphaTestEnable );
	#endif
#endif
	}

}

#endif // !defined(_3DSMAX_)

