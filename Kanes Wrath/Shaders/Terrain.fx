//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain FX Shader
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

static const float SpecularExponent = 1200;
static const float3 SpecularColor = float3(1.0, 1.0, 1.0) * 0.9;
static const float BumpScale = 1.0;
static const bool EnableNormalMap = true;


// ----------------------------------------------------------------------------
// Terrain specific textures
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( BaseSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;	
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerClamped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Reflection
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( WaterReflectionTexture,
	string UIWidget = "None";
	string SasBindAddress = "WaterDraw.ReflectionTexture";
	)
    MipFilter = Point;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = CLAMP;
    AddressV = CLAMP;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Environment map
// ----------------------------------------------------------------------------
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.EnvironmentTexture";
    string ResourceType = "Cube"; 
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END




// ----------------------------------------------------------------------------
// Taint
// ----------------------------------------------------------------------------

struct TaintSetup
{
	//bool IsEnabled; // There is a bug in the D3DX Effect framework, this needs to be float to work
	float IsEnabled;
	float2 Offset;
	float2 Scale;
};

TaintSetup Taint
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Taint";
> = { true, float2(0.0f, 0.0f), float2(1.0f, 1.0f) };


SAMPLER_2D_BEGIN( TaintMaskSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Taint.MaskTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( TaintLowSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Taint.LowTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( TaintHighSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Taint.HighTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END




// ----------------------------------------------------------------------------
// Weather
// ----------------------------------------------------------------------------

int WeatherMode
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Weather.Mode";
> = 0;

// Weather mode enum values
// Update these if the enum changes in the game!!
static const int WEATHER_NORMAL      = 0;
static const int WEATHER_CLOUDY      = 1;
static const int WEATHER_RAINY       = 2;
static const int WEATHER_CLOUDYRAINY = 3;
static const int WEATHER_SUNNY       = 4;
static const int WEATHER_SNOWY       = 5;

// ----------------------------------------------------------------------------
// Macro/Cloud textures
// ----------------------------------------------------------------------------

CloudSetup Cloud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud";
> = DEFAULT_CLOUD;


SAMPLER_2D_BEGIN( CloudSampler,
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

float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);

SAMPLER_2D_BEGIN( MacroSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.MacroTexture";
	string ResourceName = "ShaderPreviewMacro.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

bool IsMacroTextureStrechedToMapSize
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.IsMacroTextureStrechedToMapSize";
> = true;

float2 MapSize
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.Size";
> = float2(1000.0f, 1000.0f);

float2 MapCellSize
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.CellSize";
> = float2(10.0f, 10.0f);

float MapBorderWidth
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.BorderWidth";
> = 0.0f;

static const int RenderingMode_TerrainTile = 0;
static const int RenderingMode_Cliff = 1;
static const int RenderingMode_Road = 2;
static const int RenderingMode_Floor = 3;
static const int RenderingMode_Scorch = 4;
static const int RenderingMode_NumOf = 5;



// ----------------------------------------------------------------------------
// Using Terrain Atlas for rendering
// ----------------------------------------------------------------------------

bool IsTerrainAtlasEnabled
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.IsTerrainAtlasEnabled";
> = false;

// ----------------------------------------------------------------------------
// Lighting
// ----------------------------------------------------------------------------
float3 AmbientLightColor : Ambient = float3(0.3, 0.3, 0.3);

static const int NumDirectionalLights = 3;

SasDirectionalLight DirectionalLight[NumDirectionalLights]
<
	string SasBindAddress = "Sas.DirectionalLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_DIRECTIONAL_LIGHT_1,
	DEFAULT_DIRECTIONAL_LIGHT_2,
	DEFAULT_DIRECTIONAL_LIGHT_3
};

bool IsRenderingOverbright
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.IsRenderingOverbright";
> = true;


// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
int NumShadows
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.NumShadows";
> = 0;

SAMPLER_2D_SHADOW( ShadowMapSampler )

ShadowSetup ShadowInfo
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0]";
>;

// ----------------------------------------------------------------------------
// Fog
// ----------------------------------------------------------------------------
WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 World : World;
float4x3 WorldI : WorldInverse;
float4x3 WorldViewI : WorldViewInverse;
float4x3 ViewI : ViewInverse;
float4x3 View : View;

// Time (ie. material is animated)
float Time : Time;


// ----------------------------------------------------------------------------
float2 CalculateMacroTexCoord(float3 WorldPosition)
{
	if (IsMacroTextureStrechedToMapSize)
	{
		return (WorldPosition.xy + MapBorderWidth) / float2(MapSize.x, -MapSize.y);
	}
	else
	{
		float cloudAndMacroScale = 1.0 / (66.0 * MapCellSize.x);
		return WorldPosition.xy * float2(cloudAndMacroScale, -cloudAndMacroScale);
	}
}

// ----------------------------------------------------------------------------
bool IsTaintable(int renderingMode)
{
	return renderingMode == RenderingMode_TerrainTile || renderingMode == RenderingMode_Cliff;
}

// ---------------------------------------------------------------------------

float3 ApplyTaint( float3 baseColor, bool isTaintOn, int renderingMode, float2 taintMaskTexCoord, float2 taintHighTexCoord, float2 taintLowTexCoord )
{
/*	if (isTaintOn && IsTaintable(renderingMode))
	{
		float4 taint = tex2D( SAMPLER(TaintMaskSampler), taintMaskTexCoord );
	
		float3 taintDetail;
		taint.a -= 0.5;
		if (taint.a >= 0)
		{
			taintDetail = tex2D( SAMPLER(TaintHighSampler), taintHighTexCoord );
        }
		else
		{
			taintDetail = tex2D( SAMPLER(TaintLowSampler), taintLowTexCoord );
        }

		float taintStrength = abs(taint.a) * 2.0;
	
		baseColor = lerp(baseColor, taintDetail, taintStrength);
		baseColor.rgb *= taint.rgb;
	}
*/	
	return baseColor;
}

// ---------------------------------------------------------------------------
struct VSOutputDefault
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float  Fog : COLOR1;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float4 TaintMaskTexCoord_ShroudTexCoord : TEXCOORD2;
    float4 CloudTexCoord_MacroTexCoord : TEXCOORD3;
	float3 ReflectionTexCoord : TEXCOORD4;
	float3 MainLightDirection : TEXCOORD5;
	float3 MainHalfEyeLightDirection : TEXCOORD6;
	float4 ShadowMapTexCoord : TEXCOORD7;
};
	
// ---------------------------------------------------------------------------
VSOutputDefault VS_Default(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	float3 Tangent : TANGENT,
	float3 Binormal : BINORMAL,
	uniform int renderingMode,
	uniform bool isTextureAtlasEnabled,
	uniform bool useMirrorReflection
)
{
	VSOutputDefault Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));

	float3 tangent;
	float3 binormal;
	if(renderingMode == RenderingMode_Scorch)
	{
		tangent = Tangent;
		binormal = Binormal;
	}
	else
	{
		tangent = cross(worldNormal, float3(-1, 0, 0));
		binormal = cross(worldNormal, float3(0, 1, 0));
	}
	
	// Build 3x3 tranform from object to tangent space
	float3x3 objectToTangentSpace = transpose(float3x3(-binormal, -tangent, Normal));

	// Compute lighting direction in tangent space
	float3 objectLightDir = normalize(mul(DirectionalLight[0].Direction, WorldI));
	Out.MainLightDirection = mul(objectLightDir, objectToTangentSpace);

	// Compute view direction in tangent space
	float3 objectEyeDir = normalize(WorldViewI[3] - Position);
	Out.MainHalfEyeLightDirection = normalize(mul(objectLightDir + objectEyeDir, objectToTangentSpace));

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	if (IsRenderingOverbright)
		diffuseColor /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 TaintMaskTexCoord = (worldPosition.xy + Taint.Offset) * Taint.Scale;
	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);

	Out.TaintMaskTexCoord_ShroudTexCoord.xy = TaintMaskTexCoord;
	Out.TaintMaskTexCoord_ShroudTexCoord.zw = ShroudTexCoord.yx;
    Out.CloudTexCoord_MacroTexCoord.xy = CloudTexCoord.xy;
    Out.CloudTexCoord_MacroTexCoord.zw = MacroTexCoord.yx;

	if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord_PerspectiveCorrect(ShadowInfo, worldPosition);
	}
	else
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	}

	if (useMirrorReflection)
	{
		// reflection texture
		float4 hPosition = Out.Position;
   		Out.ReflectionTexCoord.xy = 0.5 * ( hPosition.xy + ( hPosition.w * float2(1.0, 1.0) ) );
   		Out.ReflectionTexCoord.z = hPosition.w;
	}
	else
	{
   		// Compute view direction in world space
		float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
		// Compute env map reflection direction
		// In theory this should use the normal to compute the reflection vector:
		//Out.ReflectionTexCoord = -reflect(worldEyeDir, worldNormal);
		// but since rain puddles don't bend over hills, lets pretent they reflect upwards:
		Out.ReflectionTexCoord = -reflect(worldEyeDir, float3(0, 0, 1));
	}

	return Out;
}

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainTile(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2_swizzle : NORMAL0,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	float3 Tangent : TANGENT,
	float3 Binormal : BINORMAL,
	uniform bool isTextureAtlasEnabled,
	uniform bool useMirrorReflection
)
{
	VSOutputDefault Out;
	float3 Position	= Position_BlendWeight1.xyz;
	float3 Normal	= Normal_BlendWeight2_swizzle.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

	if (isTextureAtlasEnabled)
	{
		// Unpack vertex data
		float4 Normal_BlendWeight2 = D3DCOLORtoUBYTE4(Normal_BlendWeight2_swizzle);
		Normal = (Normal_BlendWeight2.xyz / 100.0) - 1.0;

		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default(Position, Normal, Color, BaseTexCoord, Tangent, Binormal, RenderingMode_TerrainTile, isTextureAtlasEnabled, useMirrorReflection);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	return Out;
}

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainScorch(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_swizzle : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
    float4 Tangent_swizzle : TANGENT,
    float4 Binormal_swizzle : BINORMAL,
	uniform bool useMirrorReflection
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float4 Normal_unpack = D3DCOLORtoUBYTE4(Normal_swizzle);
    float3 Normal = (Normal_unpack.xyz / 100.0) - 1.0;

    float4 Tangent_unpack = D3DCOLORtoUBYTE4(Tangent_swizzle);
    float3 Tangent = (Tangent_unpack.xyz / 100.0) - 1.0;

    float4 Binormal_unpack = D3DCOLORtoUBYTE4(Binormal_swizzle);
    float3 Binormal = (Tangent_unpack.xyz / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to VS_Default
    return VS_Default(Position, Normal, Color, BaseTexCoord, Tangent, Binormal, RenderingMode_Scorch, false, useMirrorReflection);
}

// ---------------------------------------------------------------------------
float4 PS_Default(VSOutputDefault In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform sampler2D normalSampler,
	uniform int numShadows, uniform bool isTextureAtlasEnabled,
	uniform bool isRainy, uniform bool useMirrorReflection) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
        float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
        float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

        baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }

	float3 baseColor = baseTextureValue.xyz;

    // Apply taint
    float2 taintMaskTexCoord = In.TaintMaskTexCoord_ShroudTexCoord.xy;
    baseColor = ApplyTaint( baseColor, Taint.IsEnabled, renderingMode, taintMaskTexCoord, BaseTexCoord, BaseTexCoord );

	float3 color = In.Color.xyz * baseColor;
	float opacity = In.Color.w;
	
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Floor || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	// Add normal mapping lighting with main light source
	float3 normal;
	float specularIntensity;
	
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Floor || renderingMode == RenderingMode_Scorch)
	{
		float4 normal_specular = tex2D(normalSampler, BaseTexCoord);
		
		normal = normal_specular * 2 - 1;
		specularIntensity = normal_specular.w;
	}
	else
	{
		float3 normal_specular = tex2D(normalSampler, BaseTexCoord);

        if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
        {
            float3 normal_specular1 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
            float3 normal_specular2 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

			specularIntensity = baseTextureValue.w;
            normal = lerp(lerp(normal_specular, normal_specular1, blendWeight[0]), normal_specular2, blendWeight[1]) * 2 - 1;
        }
		else
		{
			specularIntensity = normal_specular.z;
			normal.xy = normal_specular.xy * 2 - 1;
			normal.z = sqrt(1 - normal.x * normal.x - normal.y * normal.y);
		}
	}
	
	normal.xy *= BumpScale;
	normal = normalize(normal);
	
	if (!EnableNormalMap)
		normal = float3(0, 0, 1);

	float3 mainLightColor = DirectionalLight[0].Color;
	if (IsRenderingOverbright)
		mainLightColor /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	float4 lighting = lit(dot(normal, normalize(In.MainLightDirection)),
		dot(normal, normalize(In.MainHalfEyeLightDirection)), SpecularExponent);

	if (numShadows > 0)
	{
		if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
		{
			lighting.yz *= shadow_PerspectiveCorrect( SAMPLER(ShadowMapSampler), In.ShadowMapTexCoord, ShadowInfo);
		}
		else
		{
			lighting.yz *= shadow( SAMPLER(ShadowMapSampler), In.ShadowMapTexCoord, ShadowInfo);
		}
	}

	float2 CloudTexCoord = In.CloudTexCoord_MacroTexCoord.xy;
	float4 cloud = tex2D( SAMPLER(CloudSampler), CloudTexCoord);

	color += mainLightColor * cloud * (lighting.y * baseColor + lighting.z * SpecularColor * specularIntensity);

	if (IsRenderingOverbright)
		color *= 2;

    // Apply reflection or macro
	float2 MacroTexCoord = In.CloudTexCoord_MacroTexCoord.wz;
	float4 macro = tex2D( SAMPLER(MacroSampler), MacroTexCoord);

	if (isRainy)
	{
		// Apply reflection 
		if (useMirrorReflection)
		{
			float2 reflectionTexCoord = In.ReflectionTexCoord.xy / In.ReflectionTexCoord.z;
    		float3 reflectionColor = tex2D( SAMPLER(WaterReflectionTexture), reflectionTexCoord );
	    
    		color = lerp(color, reflectionColor, macro);
		}
		else
		{
			float3 reflectionColor = texCUBE(SAMPLER(EnvironmentTexture), In.ReflectionTexCoord);
			color = lerp(color, reflectionColor, macro);
		}
	}
	else
	{
	    // Apply macro
	    color *= macro;
	}

    // Apply fog
	color = lerp(Fog.Color, color, In.Fog);

    // Apply shroud
    float2 shroudTexCoord = In.TaintMaskTexCoord_ShroudTexCoord.wz;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color *= shroud;

	return float4(color, opacity);
}

float4 PS_Default_Xenon(VSOutputDefault In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform sampler2D normalSampler) : COLOR
{
	return PS_Default(In, renderingMode, baseSampler, normalSampler, 1, true, WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY, false);
}

// ---------------------------------------------------------------------------
// TECHNIQUE : TerrainTile ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_Multiplier_IsTextureAtlasEnabled = 1);

#define VS_TerrainTile_IsTextureAtlasEnabled(useMirrorReflection) \
 	compile VS_VERSION_LOW VS_TerrainTile(false, useMirrorReflection), \
	compile VS_VERSION_LOW VS_TerrainTile(true, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_Multiplier_Final = VS_TerrainTile_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_TerrainTile_Array[VS_TerrainTile_Multiplier_Final] =
{
	VS_TerrainTile_IsTextureAtlasEnabled(false)
};

vertexshader VS_TerrainTile_U_Array[VS_TerrainTile_Multiplier_Final] =
{
	VS_TerrainTile_IsTextureAtlasEnabled(true)
};
#endif


DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_NumShadows = 1);

#define PS_TerrainTile_NumShadows(isTextureAtlasEnabled, isRainy, useMirrorReflection) \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 0, isTextureAtlasEnabled, isRainy, useMirrorReflection), \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 1, isTextureAtlasEnabled, isRainy, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_IsTextureAtlasEnabled = PS_TerrainTile_Multiplier_NumShadows * 2);

#define PS_TerrainTile_IsTextureAtlasEnabled(isRainy, useMirrorReflection) \
	PS_TerrainTile_NumShadows(false, isRainy, useMirrorReflection), \
	PS_TerrainTile_NumShadows(true, isRainy, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_IsRainy = PS_TerrainTile_Multiplier_IsTextureAtlasEnabled * 2);

#define PS_TerrainTile_IsRainy(useMirrorReflection) \
	PS_TerrainTile_IsTextureAtlasEnabled(false, useMirrorReflection), \
	PS_TerrainTile_IsTextureAtlasEnabled(true, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_Final = PS_TerrainTile_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_TerrainTile_Array[PS_TerrainTile_Multiplier_Final] =
{
	PS_TerrainTile_IsRainy(false)
};

pixelshader PS_TerrainTile_U_Array[PS_TerrainTile_Multiplier_Final] =
{
	PS_TerrainTile_IsRainy(true)
};
#endif


// ---------------------------------------------------------------------------
technique TerrainTile
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
			compile VS_VERSION VS_TerrainTile(true, false)
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_Array,
			min(NumShadows, 1) * PS_TerrainTile_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_Multiplier_IsTextureAtlasEnabled
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_TerrainTile_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}
// ---------------------------------------------------------------------------
technique TerrainTile_U
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_U_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
			compile VS_VERSION VS_TerrainTile(true, false)
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_U_Array,
			min(NumShadows, 1) * PS_TerrainTile_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_Multiplier_IsTextureAtlasEnabled
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_TerrainTile_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_Multiplier_NumShadows = 1);

#define PS_Cliff_NumShadows(isRainy, useMirrorReflection) \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 0, false, isRainy, useMirrorReflection), \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 1, false, isRainy, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_Multiplier_IsRainy = PS_Cliff_Multiplier_NumShadows * 2);

#define PS_Cliff_IsRainy(useMirrorReflection) \
	PS_Cliff_NumShadows(false, useMirrorReflection), \
	PS_Cliff_NumShadows(true, useMirrorReflection)
	
DEFINE_ARRAY_MULTIPLIER(PS_Cliff_Multiplier_Final = PS_Cliff_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Cliff_Array[PS_Cliff_Multiplier_Final] =
{
	PS_Cliff_IsRainy(false)
};

pixelshader PS_Cliff_U_Array[PS_Cliff_Multiplier_Final] =
{
	PS_Cliff_IsRainy(true)
};
#endif

// ---------------------------------------------------------------------------
technique Cliff
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default(RenderingMode_Cliff, false, false);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_Array,
			min(NumShadows, 1) * PS_Cliff_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Cliff_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}

// ---------------------------------------------------------------------------
technique Cliff_U
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default(RenderingMode_Cliff, false, true);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_U_Array,
			min(NumShadows, 1) * PS_Cliff_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Cliff_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}


// ---------------------------------------------------------------------------
// TECHNIQUE : Road ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Road_Multiplier_NumShadows = 1);

#define PS_Road_NumShadows(isRainy, useMirrorReflection) \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 0, false, isRainy, useMirrorReflection), \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 1, false, isRainy, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_Road_Multiplier_IsRainy = PS_Road_Multiplier_NumShadows * 2);

#define PS_Road_IsRainy(useMirrorReflection) \
	PS_Road_NumShadows(false, useMirrorReflection), \
	PS_Road_NumShadows(true, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_Road_Multiplier_Final = PS_Road_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Road_Array[PS_Road_Multiplier_Final] =
{
	PS_Road_IsRainy(false)
};

pixelshader PS_Road_U_Array[PS_Road_Multiplier_Final] =
{
	PS_Road_IsRainy(true)
};
#endif

// ---------------------------------------------------------------------------
technique Road
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default(RenderingMode_Road, false, false);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_Array,
			min(NumShadows, 1) * PS_Road_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Road_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}

// ---------------------------------------------------------------------------
technique Road_U
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default(RenderingMode_Road, false, true);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_U_Array,
			min(NumShadows, 1) * PS_Road_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Road_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_Multiplier_NumShadows = 1);

#define PS_Scorch_NumShadows(isRainy, useMirrorReflection) \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 0, false, isRainy, useMirrorReflection), \
	compile PS_VERSION_HIGH PS_Default(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 1, false, isRainy, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_Multiplier_IsRainy = PS_Scorch_Multiplier_NumShadows * 2);

#define PS_Scorch_IsRainy(useMirrorReflection) \
	PS_Scorch_NumShadows(false, useMirrorReflection), \
	PS_Scorch_NumShadows(true, useMirrorReflection)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_Multiplier_Final = PS_Scorch_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Scorch_Array[PS_Scorch_Multiplier_Final] =
{
	PS_Scorch_IsRainy(false)
};

pixelshader PS_Scorch_U_Array[PS_Scorch_Multiplier_Final] =
{
	PS_Scorch_IsRainy(true)
};
#endif

// ---------------------------------------------------------------------------
technique Scorch
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_TerrainScorch(false);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_Array,
			min(NumShadows, 1) * PS_Scorch_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Scorch_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}

// ---------------------------------------------------------------------------
technique Scorch_U
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_TerrainScorch(true);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_U_Array,
			min(NumShadows, 1) * PS_Scorch_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Scorch_Multiplier_IsRainy,
			// Non-array alternative:
			compile PS_VERSION_HIGH PS_Default_Xenon(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}


// ---------------------------------------------------------------------------
// TECHNIQUE : Floor ( HIGH QUALITY )
// ---------------------------------------------------------------------------

// Floor technique currently unused. To create it, copy scorch technique above and rename all Scorch to Floor.
// [LLatta 2006-09-26]



// LOD techniques follow
#if ENABLE_LOD

// ============================================================================
// Default technique, medium quality
// ============================================================================
// ---------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float4 MainLightContribution_Fog : COLOR1;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float4 TaintMaskTexCoord_ShroudTexCoord : TEXCOORD2;
    float4 CloudTexCoord_MacroTexCoord : TEXCOORD3;
	float3 ReflectionTexCoord : TEXCOORD4;
	float4 ShadowMapTexCoord : TEXCOORD5;
};
	
// ---------------------------------------------------------------------------
VSOutput_M VS_Default_M(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform int renderingMode,
	uniform bool isTextureAtlasEnabled = false
)
{
	VSOutput_M Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);

	Out.MainLightContribution_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);

	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	
	float3 mainLight = DirectionalLight[0].Color * max(0, dot(worldNormal, DirectionalLight[0].Direction));
	if (IsRenderingOverbright)
		mainLight /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.
	Out.MainLightContribution_Fog.xyz = mainLight;

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	if (IsRenderingOverbright)
		diffuseColor /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 TaintMaskTexCoord = (worldPosition.xy + Taint.Offset) * Taint.Scale;
	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);

	Out.TaintMaskTexCoord_ShroudTexCoord.xy = TaintMaskTexCoord;
	Out.TaintMaskTexCoord_ShroudTexCoord.zw = ShroudTexCoord.yx;
    Out.CloudTexCoord_MacroTexCoord.xy = CloudTexCoord.xy;
    Out.CloudTexCoord_MacroTexCoord.zw = MacroTexCoord.yx;
    
   	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	// Compute env map reflection direction
	// In theory this should use the normal to compute the reflection vector:
	//Out.ReflectionTexCoord = -reflect(worldEyeDir, worldNormal);
	// but since rain puddles don't bend over hills, lets pretent they reflect upwards:
	Out.ReflectionTexCoord = -reflect(worldEyeDir, float3(0, 0, 1));

	if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord_PerspectiveCorrect(ShadowInfo, worldPosition);
	}
	else
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	}

	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_M VS_TerrainTile_M(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2_swizzle : NORMAL0,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_M Out;
	float3 Position	= Position_BlendWeight1.xyz;
	float3 Normal	= Normal_BlendWeight2_swizzle.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

	if (isTextureAtlasEnabled)
	{
		// Unpack vertex data
		float4 Normal_BlendWeight2 = D3DCOLORtoUBYTE4(Normal_BlendWeight2_swizzle);
		Normal = (Normal_BlendWeight2.xyz / 100.0) - 1.0;

		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default_M(Position, Normal, Color, BaseTexCoord, RenderingMode_TerrainTile, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_M VS_TerrainScorch_M(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_swizzle : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float4 Normal_unpack = D3DCOLORtoUBYTE4(Normal_swizzle);
    float3 Normal = (Normal_unpack.xyz / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to DefaultVertexShader_M
    return VS_Default_M(Position, Normal, Color, BaseTexCoord, RenderingMode_Scorch);
}

// ---------------------------------------------------------------------------
float4 PS_Default_M(VSOutput_M In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform int numShadows,
	uniform bool isTextureAtlasEnabled, uniform bool isRainy) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
		float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
		float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);
		
		baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }

	float3 baseColor = baseTextureValue.xyz;

    // Apply taint
    float2 taintMaskTexCoord = In.TaintMaskTexCoord_ShroudTexCoord.xy;
    baseColor = ApplyTaint( baseColor, Taint.IsEnabled, renderingMode, taintMaskTexCoord, BaseTexCoord, BaseTexCoord );

	float2 CloudTexCoord = In.CloudTexCoord_MacroTexCoord.xy;
	float3 cloud = tex2D(SAMPLER(CloudSampler), CloudTexCoord);
	float3 mainLight = In.MainLightContribution_Fog.xyz * cloud;

	if (numShadows > 0)
	{
		if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
		{
			mainLight *= shadow_PerspectiveCorrect( SAMPLER(ShadowMapSampler), In.ShadowMapTexCoord, ShadowInfo);
		}
		else
		{
			mainLight *= shadow( SAMPLER(ShadowMapSampler), In.ShadowMapTexCoord, ShadowInfo);
		}
	}

	float3 color = (In.Color.xyz + mainLight) * baseColor;

	if (IsRenderingOverbright)
		color *= 2;

    // Apply reflection or macro
	float2 MacroTexCoord = In.CloudTexCoord_MacroTexCoord.wz;
	float4 macro = tex2D( SAMPLER(MacroSampler), MacroTexCoord);

	if (isRainy)
	{
    	// Apply reflection
		float3 reflectionColor = texCUBE(SAMPLER(EnvironmentTexture), In.ReflectionTexCoord);
		color = lerp(color, reflectionColor, macro);
	}
	else
	{
	    // Apply macro
	    color *= macro;
	}

    // Apply fog
	color = lerp(Fog.Color, color, In.MainLightContribution_Fog.w);

    // Apply shroud
    float2 shroudTexCoord = In.TaintMaskTexCoord_ShroudTexCoord.wz;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color *= shroud;

	// Calculate opacity
	float opacity = In.Color.w;
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Floor || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	return float4(color, opacity);
}


// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain Tile (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled = 1);

#define VS_TerrainTile_M_IsTextureAtlasEnabled \
 	compile VS_VERSION_LOW VS_TerrainTile_M(false), \
	compile VS_VERSION_LOW VS_TerrainTile_M(true)

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_Final = VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_TerrainTile_M_Array[VS_TerrainTile_M_Multiplier_Final] =
{
	VS_TerrainTile_M_IsTextureAtlasEnabled
};
#endif

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_NumShadows = 1);

#define PS_TerrainTile_M_NumShadows(isTextureAtlasEnabled, isRainy) \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), 0, isTextureAtlasEnabled, isRainy), \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), 1, isTextureAtlasEnabled, isRainy)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled = PS_TerrainTile_M_Multiplier_NumShadows * 2);

#define PS_TerrainTile_M_IsTextureAtlasEnabled(isRainy) \
	PS_TerrainTile_M_NumShadows(false, isRainy), \
	PS_TerrainTile_M_NumShadows(true, isRainy)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_IsRainy = PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled * 2);

#define PS_TerrainTile_M_IsRainy \
	PS_TerrainTile_M_IsTextureAtlasEnabled(false), \
	PS_TerrainTile_M_IsTextureAtlasEnabled(true)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_Final = PS_TerrainTile_M_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_TerrainTile_M_Array[PS_TerrainTile_M_Multiplier_Final] =
{
	PS_TerrainTile_M_IsRainy
};
#endif

technique TerrainTile_M
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_M_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled,
			NO_ARRAY_ALTERNATIVE
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_M_Array,
			min(NumShadows, 1) * PS_TerrainTile_M_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_TerrainTile_M_Multiplier_IsRainy,
			NO_ARRAY_ALTERNATIVE
		);
		
		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_NumShadows = 1);

#define PS_Cliff_M_NumShadows(isRainy) \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), 0, false, isRainy), \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), 1, false, isRainy)

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_IsRainy = PS_Cliff_M_Multiplier_NumShadows * 2);

#define PS_Cliff_M_IsRainy \
	PS_Cliff_M_NumShadows(false), \
	PS_Cliff_M_NumShadows(true)
	
DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_Final = PS_Cliff_M_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Cliff_M_Array[PS_Cliff_M_Multiplier_Final] =
{
	PS_Cliff_M_IsRainy
};
#endif

technique Cliff_M
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default_M(RenderingMode_Cliff);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_M_Array,
			min(NumShadows, 1) * PS_Cliff_M_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Cliff_M_Multiplier_IsRainy,
			NO_ARRAY_ALTERNATIVE
		);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Road (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_NumShadows = 1);

#define PS_Road_M_NumShadows(isRainy) \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), 0, false, isRainy), \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), 1, false, isRainy)

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_IsRainy = PS_Road_M_Multiplier_NumShadows * 2);

#define PS_Road_M_IsRainy \
	PS_Road_M_NumShadows(false), \
	PS_Road_M_NumShadows(true)
	
DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_Final = PS_Road_M_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Road_M_Array[PS_Road_M_Multiplier_Final] =
{
	PS_Road_M_IsRainy
};
#endif

technique Road_M
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Default_M(RenderingMode_Road);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_M_Array,
			min(NumShadows, 1) * PS_Road_M_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Road_M_Multiplier_IsRainy,
			NO_ARRAY_ALTERNATIVE
		);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_NumShadows = 1);

#define PS_Scorch_M_NumShadows(isRainy) \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), 0, false, isRainy), \
	compile PS_VERSION_HIGH PS_Default_M(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), 1, false, isRainy)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_IsRainy = PS_Scorch_M_Multiplier_NumShadows * 2);

#define PS_Scorch_M_IsRainy \
	PS_Scorch_M_NumShadows(false), \
	PS_Scorch_M_NumShadows(true)
	
DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_Final = PS_Scorch_M_Multiplier_IsRainy * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Scorch_M_Array[PS_Scorch_M_Multiplier_Final] =
{
	PS_Scorch_M_IsRainy
};
#endif

technique Scorch_M
{
	pass P0
	{
        VertexShader = compile VS_VERSION_LOW VS_TerrainScorch_M();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_M_Array,
			min(NumShadows, 1) * PS_Scorch_M_Multiplier_NumShadows
			+ (WeatherMode == WEATHER_RAINY || WeatherMode == WEATHER_CLOUDYRAINY) * PS_Scorch_M_Multiplier_IsRainy,
			NO_ARRAY_ALTERNATIVE
		);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Floor (Medium Quality)
// ---------------------------------------------------------------------------

// Floor technique currently unused. To create it, copy scorch technique above and rename all Scorch to Floor.
// [LLatta 2006-09-26]



// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float2 TaintShroudTexCoord : TEXCOORD1;
};

// ---------------------------------------------------------------------------
VSOutput_L DefaultVertexShader_L(float3 Position : POSITION, 
	float3 Normal : NORMAL, float4 Color: COLOR0,
	float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_L Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	float3 worldPosition = mul(float4(Position, 1), World);

	float3 worldNormal = normalize(mul(Normal, (float3x3)World));

	// Do vertex lighting for all lights
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 lightColor = DirectionalLight[i].Color;
		if (i == 0)
		{
			lightColor *= NoCloudMultiplier;
		}

		diffuseLight += lightColor * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	if (IsRenderingOverbright)
		diffuseColor /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);
		
	Out.BaseTexCoord = TexCoord0;
	
	Out.TaintShroudTexCoord = (worldPosition.xy + Taint.Offset) * Taint.Scale;

	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_L VS_TerrainScorch_L(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_swizzle : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float4 Normal_unpack = D3DCOLORtoUBYTE4(Normal_swizzle);
    float3 Normal = (Normal_unpack.xyz / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to DefaultVertexShader_L
    return DefaultVertexShader_L(Position, Normal, Color, BaseTexCoord);
}

// ---------------------------------------------------------------------------
float4 DefaultPixelShader_L(VSOutput_L In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform bool isRenderingOverbright) : COLOR
{
	float4 baseTextureValue = tex2D(baseSampler, In.BaseTexCoord);
	float3 baseColor = baseTextureValue.xyz;

	float4 taintShroud = tex2D( SAMPLER(TaintMaskSampler), In.TaintShroudTexCoord);
	
	float3 color = In.Color.xyz * baseColor * taintShroud;

	if (isRenderingOverbright)
		color *= 2;
		
	float opacity = In.Color.w;
	
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Floor || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	return float4(color, opacity);
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain tile (Low Quality)
// ---------------------------------------------------------------------------

technique TerrainTile_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW DefaultVertexShader_L();
		PixelShader  = compile PS_VERSION_LOW DefaultPixelShader_L(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped_L), true);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff (Low Quality)
// ---------------------------------------------------------------------------

technique Cliff_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW DefaultVertexShader_L();
		PixelShader  = compile PS_VERSION_LOW DefaultPixelShader_L(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped_L), true);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Road (Low Quality)
// ---------------------------------------------------------------------------

technique Road_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW DefaultVertexShader_L();
		PixelShader  = compile PS_VERSION_LOW DefaultPixelShader_L(RenderingMode_Road, SAMPLER(BaseSamplerWrapped_L), true);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Low Quality)
// ---------------------------------------------------------------------------

technique Scorch_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_TerrainScorch_L();
		PixelShader  = compile PS_VERSION_LOW DefaultPixelShader_L(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped_L), true);

		ClipPlaneEnable = 0;

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Floor (Low Quality)
// ---------------------------------------------------------------------------

// Floor technique currently unused. To create it, copy scorch technique above and rename all Scorch to Floor.
// [LLatta 2006-09-26]



#endif // #if ENABLE_LOD



// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Depth : TEXCOORD0;
};

// ---------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(float3 Position : POSITION)
{
	VSOutput_CreateShadowMap Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	Out.Depth = Out.Position.z / Out.Position.w;
	
	return Out;
}

// ---------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	return In.Depth;
}



// ---------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ---------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW CreateShadowMapVS();
		PixelShader = compile PS_VERSION_HIGH CreateShadowMapPS();
	
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;
		
	}
}


#if defined(EA_PLATFORM_WINDOWS)

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
float4 VS_FlatColor(float3 Position : POSITION) : POSITION
{
	return mul(float4(Position, 1), WorldViewProjection);	
}

// ---------------------------------------------------------------------------
float4 PS_FlatColor() : COLOR
{
	return float4(0, 0, 0, 1); // Use black color for terrain
}



// ============================================================================
// Technique : Flat Color
// ============================================================================

technique _DrawFlatColor
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColor();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;		
		AlphaTestEnable = false;

		FogEnable = false; // We do custom fog in the pixel shader
	}
}



// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
struct VSWorldNormOutput
{
	float4 Position : POSITION;
	float2 BaseTexCoord : TEXCOORD0;
	float3x3 TangentToViewSpace : TEXCOORD1;
};

// ---------------------------------------------------------------------------
VSWorldNormOutput VS_WorldNormals(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float3 Tangent : TANGENT,
	float3 Binormal : BINORMAL,	
	float4 Color : COLOR0,
	float2 baseTex : TEXCOORD0,
	uniform int renderingMode)
{
	VSWorldNormOutput Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);	
	Out.BaseTexCoord = baseTex;
	
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	
	float3 tangent;
	float3 binormal;
	if(renderingMode == RenderingMode_Scorch)
	{
		tangent = Tangent;
		binormal = Binormal;
	}
	else
	{
		tangent = cross(worldNormal, float3(-1, 0, 0));
		binormal = cross(worldNormal, float3(0, 1, 0));
	}
		
	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorld = (float3x3(-binormal, -tangent, Normal));
	tangentToWorld = mul(tangentToWorld, (float3x3)World);
	Out.TangentToViewSpace = mul(tangentToWorld, (float3x3)View);
		
	return Out;
}
// ---------------------------------------------------------------------------

float4 PS_WorldNormals(VSWorldNormOutput In, uniform int renderingMode, uniform sampler2D normalSampler) : COLOR
{
	//The normal map is stored [0...1] so we have to map it back into the [-1...1] range
	float3 Normal = (2 * (tex2D(normalSampler, In.BaseTexCoord))) - 1.0f;
	float3 colorNormal = mul(Normal, In.TangentToViewSpace);
	colorNormal = (colorNormal / 2) + 0.5f; //shift back to [0...1]

	return float4(colorNormal.xyz, 1);
}

// ============================================================================
// Technique : Render Normals
// ============================================================================

technique _RenderWorldNormals
{
	pass p0 
	{	
		ZEnable = true;
		ZWriteEnable = true;
		CullMode = None;	
		VertexShader = compile VS_VERSION_LOW VS_WorldNormals(RenderingMode_TerrainTile);
		PixelShader = compile PS_VERSION_HIGH PS_WorldNormals(RenderingMode_TerrainTile, SAMPLER(NormalSamplerClamped));
	}
}

#endif // #if defined(EA_PLATFORM_WINDOWS)

