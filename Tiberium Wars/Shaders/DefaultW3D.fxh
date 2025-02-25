//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple Phong lighting
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
//#define SUPPORT_CLOUDS 0	// disable clouds
//#define SUPPORT_FOG 0		// disable fog

#if !defined(CAST_SHADOWS)
#define CAST_SHADOWS 1		// define to 0 before to disable shadow casting
#endif

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
// Skinning
// ----------------------------------------------------------------------------
static const int MaxSkinningBonesPerVertex = 2;

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
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
DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

static const int NumPointLights = 1;
SasPointLight PointLight[NumPointLights]
<
	string SasBindAddress = "Sas.PointLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_POINT_LIGHT_DISABLED
	//{ float3(1, 0, 0), float3(0, 0, 0), 5 }
};
DECLARE_POINT_LIGHT_INTERACTIVE(PointLight, 0);

// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
int NumShadows
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.NumShadows";
> = 0;

ShadowSetup ShadowInfo
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0]";
>;

SAMPLER_2D_SHADOW( ShadowTexture )

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
float3 ColorAmbient
<
	string UIName = "Ambient Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float3 ColorDiffuse
<
	string UIName = "Diffuse Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float3 ColorSpecular
<
	string UIName = "Specular Material Color";
    string UIWidget = "Color";
> = float3(0.0, 0.0, 0.0);

float Shininess
<
	string UIName = "Specular Shininess";
    string UIWidget = "Slider";
    float UIMax = 100;
> = 1.0;

float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(0.0, 0.0, 0.0);

float Opacity
<
	string UIName = "Opacity";
    string UIWidget = "Slider";
> = 1.0;

float EdgeFadeOut
<
	string UIName = "Edge fade out";
    string UIWidget = "Slider";
> = 0.0f;

int NumTextures
<
	string UIName = "Number of textures to use";
	int UIMin = 0;
	int UIMax = 2;
> = 1;

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

bool UseRecolorColors
<
	string UIName = "Allow House Color";
> = false;

#if defined(_3DSMAX_)
bool NumRecolorColors
<
	string UIName = "Preview House Color Enable";
	bool ExportValue = false;
> = false;

float3 RecolorColor
<
	string UIName = "Preview House Color";
	string UIWidget = "Color";
	bool ExportValue = false;
> = float3(.7, .05, .05);

#else

int NumRecolorColors
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.NumRecolorColors";
	bool ExportValue = false;
> = 0;

float3 RecolorColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.RecolorColor[0]";
	bool ExportValue = false;
> = float3(0, 0, 0);
#endif

bool HouseColorPulse
<
	string UIName = "House Color Pulse Enable";
> = false;

bool DepthWriteEnable
<
	string UIName = "Depth Write Enable";
> = true;

bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;

bool CullingEnable
<
	string UIName = "Culling Enable";
> = true;


static const int BlendMode_Opaque = 0;
static const int BlendMode_Alpha = 1;
static const int BlendMode_Additive = 2;

int BlendMode
<
	string UIName = "Blend mode (0: opaque, 1: alpha, 2: additive)";
	int UIMin = 0;
	int UIMax = 2;
> = BlendMode_Opaque;

static const int SecTexBlend_Modulate = 0;
static const int SecTexBlend_Modulate2X = 1;
static const int SecTexBlend_AlphaBlend = 2;
static const int SecTexBlend_SpecularAlpha = 3;

int SecondaryTextureBlendMode
<
	string UIName = "Sec tex func (0: mul, 1: mul2x, 2: alph, 3: specularAlph)";
	int UIMin = 0;
	int UIMax = 3;
> = SecTexBlend_Modulate;

static const int TexCoordMapper_Direct = 0;
static const int TexCoordMapper_ScaleMove = 1;
static const int TexCoordMapper_Video = 2;
// TODO: static const int TexCoordMapper_Rotate = 3;


static const int MaxTexCoordMapper_0 = 2;

int TexCoordMapper_0
<
	string UIName = "TexMapper0 (0: direct, 1: scl/move, 2: video)";
	int UIMin = 0;
	int UIMax = MaxTexCoordMapper_0;
> = TexCoordMapper_Direct;

float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float4 TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0
<
	string UIName = "UV0 Video Tex";
    string UIWidget = "Spinner";
    float4 UIMin = float4(-100, 1, 1, 0);
    float4 UIMax = float4(100, 32, 1024, 1024);
> = float4(0.0, 1.0, 1.0, 0.0);

static const int MaxTexCoordMapper_1 = 1;

int TexCoordMapper_1
<
	string UIName = "TexMapper1 (0: direct, 1: scl/move)";
	int UIMin = 0;
	int UIMax = MaxTexCoordMapper_1;
> = TexCoordMapper_Direct;

float4 TexCoordTransform_1
<
	string UIName = "UV1 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float3 Sampler_ClampU_ClampV_NoMip_0
<
	string UIName = "UV0 Clmp/Mip";
    string UIWidget = "Spinner";
    float3 UIMin = float3(0, 0, 0);
    float3 UIMax = float3(1, 1, 1);
> = float3(0, 0, 0);

float3 Sampler_ClampU_ClampV_NoMip_1
<
	string UIName = "UV1 Clmp/Mip";
    string UIWidget = "Spinner";
    float3 UIMin = float3(0, 0, 0);
    float3 UIMax = float3(1, 1, 1);
> = float3(0, 0, 0);

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud";
#endif
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

int ObjectShroudStatus
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud.ObjectShroudStatus";
#endif
> = OBJECTSHROUD_INVALID;


// ----------------------------------------------------------------------------
// Clouds
// ----------------------------------------------------------------------------
CloudSetup Cloud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Cloud";
#endif
> = DEFAULT_CLOUD;

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

float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);


// ----------------------------------------------------------------------------
// FOG
// ----------------------------------------------------------------------------
WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
>;

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 View : View;
float4x4 Projection : Projection;
float4x3 ViewI : ViewInverse;
float Time : Time;


// ----------------------------------------------------------------------------
// Video texture animation. The following assumptions are made:
// - The original texture coordinates are already scaled to a subrectangle of the video texture (e.g [0, 0.25] for 4 frames per row)
// - FPS can be positive or negative, negative means anim is running backward
// ----------------------------------------------------------------------------
float2 CalculateVideoTextureOffset(float4 FPS_NumPerRow_LastFrame_FrameOffset)
{
	float fps = FPS_NumPerRow_LastFrame_FrameOffset.x;
	float numPerRow = FPS_NumPerRow_LastFrame_FrameOffset.y;
	float lastFrame = FPS_NumPerRow_LastFrame_FrameOffset.z;
	float frameOffset = FPS_NumPerRow_LastFrame_FrameOffset.w;
	
	float frameNumber = fmod(Time * fps + frameOffset, lastFrame);
	if (fps < 0)
		frameNumber = lastFrame + frameNumber; // Note frameNumber is negative when getting here.
	float2 uvOffset = float2(fmod(frameNumber, numPerRow), frameNumber / numPerRow);
	uvOffset -= frac(uvOffset); // Make this into an integer. More efficient here than performing the whole calculation with integers.
	uvOffset /= numPerRow;
	
	return uvOffset;
}


// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondaryTexCoord : TEXCOORD1;
	float2 CloudTexCoord : TEXCOORD2;
	float2 ShroudTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD4;
	float3 MainLightDiffuseColor : TEXCOORD5;
	float3 MainLightSpecularColor : TEXCOORD6;
};

// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform int texCoordMapper_0,
		uniform int texCoordMapper_1,
		uniform bool applyHouseColor)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	USE_POINT_LIGHT_INTERACTIVE(PointLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);

	
#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	// Apply house color
	if (applyHouseColor)
	{
		VertexColor.xyz *= lerp(RecolorColor, float3(1.0,1.0,1.0),.25);
		
		if (HouseColorPulse)
		{
			VertexColor.xyz *= (sin(Time * 2) + 1.2);
		}
	}

	// Fade out edges.
	float viewingAngle = abs(dot(worldEyeDir, worldNormal));
	float fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle);
	if (BlendMode == BlendMode_Additive)
	{
		VertexColor.xyz *= fadeOut;
	}
	else
	{
		VertexColor.a *= fadeOut;
	}

	// Compute light
	
	// Compute directional lights
	if (NumDirectionalLights > 0)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[0].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[0].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		float3 lightColor = DirectionalLight[0].Color;
#if !SUPPORT_CLOUDS
		lightColor *= NoCloudMultiplier;
#endif

		float3 diffuseLight = lightColor * lighting.y;
		float3 specularLight = lightColor * lighting.z;
		
		Out.MainLightDiffuseColor = diffuseLight * ColorDiffuse * VertexColor.xyz / 2;
		Out.MainLightSpecularColor = specularLight * ColorSpecular / 2;
	}

	float3 diffuseLight = 0;
	float3 specularLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[i].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[i].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		diffuseLight += DirectionalLight[i].Color * lighting.y;
		specularLight += DirectionalLight[i].Color * lighting.z;
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;

		float3 halfEyeLightVector = normalize(direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, direction),
			dot(worldNormal, halfEyeLightVector), Shininess);
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * lighting.y;
		specularLight += PointLight[i].Color * attenuation * ColorSpecular * lighting.z;
	}
	
	float3 diffuseColor = (ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, Opacity * OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = specularLight * ColorSpecular / 2;

	// Set base texture coordinate	
	Out.BaseTexCoord = TexCoord0;
	if (texCoordMapper_0 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.BaseTexCoord = Out.BaseTexCoord * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	}
	else if (texCoordMapper_0 == TexCoordMapper_Video)
	{
		Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	}

	Out.SecondaryTexCoord = TexCoord1;
	if (texCoordMapper_1 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.SecondaryTexCoord = Out.SecondaryTexCoord * TexCoordTransform_1.xy + Time * TexCoordTransform_1.zw;
	}
	
	// Calculate cloud layer coordinates
#if SUPPORT_CLOUDS
	Out.CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
#else
	Out.CloudTexCoord = float2( 1.0, 1.0 );
#endif
	
	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate shadow map texture coordinates	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);

	// Calculate fog
#if SUPPORT_FOG
	Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);
#else
	Out.SpecularColor_Fog.w = 1.0;
#endif
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int numTextures, uniform int secondaryTextureBlendMode,
		uniform bool applyShroud, uniform int fogMode, uniform int numShadows ) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;
	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

	float3 cloud = float3(1, 1, 1);

#if defined(_WW3D_) && !defined(_W3DVIEW_) && SUPPORT_CLOUDS
	cloud = tex2D( SAMPLER(CloudTexture), In.CloudTexCoord);
#endif

	if (numShadows > 0)
	{
		cloud *= shadow( SAMPLER(ShadowTexture), In.ShadowMapTexCoord, ShadowInfo);
	}

	color.xyz += In.MainLightDiffuseColor * cloud;
	specularColor += In.MainLightSpecularColor * cloud;

	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;

	if (numTextures >= 1)
	{
		color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);
	}

	if (numTextures >= 2)
	{
		float4 secondaryColor = tex2D( SAMPLER(Texture_1), In.SecondaryTexCoord);

		if (secondaryTextureBlendMode == SecTexBlend_Modulate)
		{
			color.xyz *= secondaryColor;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_Modulate2X)
		{
			color.xyz *= secondaryColor.xyz;
			color.xyz += color.xyz;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_AlphaBlend)
		{
			color.xyz = lerp(color.xyz, secondaryColor.xyz, color.a);
		}
		else if (secondaryTextureBlendMode == SecTexBlend_SpecularAlpha)
		{
			color.xyz += specularColor * color.a;
		}
	}

	// Overbrighten	
	color.xyz += color.xyz;

	// Apply fog
#if SUPPORT_FOG
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}
#endif

	// Apply shroud
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

	return color;
}

// ----------------------------------------------------------------------------
// SHADER: VS_Xenon
// ----------------------------------------------------------------------------
VSOutput VS_Xenon(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0 )
{
	return VS(	InSkin, TexCoord0, TexCoord1, VertexColor, 
				min(NumJointsPerVertex, 2), min(TexCoordMapper_0, MaxTexCoordMapper_0),
				min(TexCoordMapper_1, MaxTexCoordMapper_1),
				NumRecolorColors > 0 && UseRecolorColors);
}

// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In ) : COLOR
{
	return PS( In, min( NumTextures, 2 ),
			   SecondaryTextureBlendMode,
			   (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR),
			   (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled),
			   min(NumShadows, 1));
}

// ----------------------------------------------------------------------------
// TECHNIQUE : DEFAULT
// ----------------------------------------------------------------------------
#define VS_NumJointsPerVertex(texCoordMapper0, texCoordMapper1, applyHouseColor) \
	compile vs_2_0 VS(0, texCoordMapper0, texCoordMapper1, applyHouseColor), \
	compile vs_2_0 VS(1, texCoordMapper0, texCoordMapper1, applyHouseColor), \
	compile vs_2_0 VS(2, texCoordMapper0, texCoordMapper1, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_TexCoordMapper0 = 3 );

#define VS_TexCoordMapper0(texCoordMapper1, applyHouseColor) \
	VS_NumJointsPerVertex(TexCoordMapper_Direct, texCoordMapper1, applyHouseColor), \
	VS_NumJointsPerVertex(TexCoordMapper_ScaleMove, texCoordMapper1, applyHouseColor), \
	VS_NumJointsPerVertex(TexCoordMapper_Video, texCoordMapper1, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_TexCoordMapper1 = VS_Multiplier_TexCoordMapper0 * 3 );

#define VS_TexCoordMapper1(applyHouseColor) \
	VS_TexCoordMapper0(TexCoordMapper_Direct, applyHouseColor), \
	VS_TexCoordMapper0(TexCoordMapper_ScaleMove, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_ApplyHouseColor = VS_Multiplier_TexCoordMapper1 * 2 );

#define VS_ApplyHouseColor \
	VS_TexCoordMapper1(false), \
	VS_TexCoordMapper1(true)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = VS_Multiplier_ApplyHouseColor * 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_ApplyHouseColor
};
#endif
	
#define PS_NumTextures(secondaryTextureBlendMode, applyShroud, fogMode, numShadows ) \
	compile ps_2_0 PS(0, secondaryTextureBlendMode, applyShroud, fogMode, numShadows ), \
	compile ps_2_0 PS(1, secondaryTextureBlendMode, applyShroud, fogMode, numShadows ), \
	compile ps_2_0 PS(2, secondaryTextureBlendMode, applyShroud, fogMode, numShadows )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_SecondaryTextureBlendMode = 3 );

#define PS_SecondaryTextureBlendMode(applyShroud, fogMode, numShadows ) \
	PS_NumTextures(SecTexBlend_Modulate, applyShroud, fogMode, numShadows ), \
	PS_NumTextures(SecTexBlend_Modulate2X, applyShroud, fogMode, numShadows ), \
	PS_NumTextures(SecTexBlend_AlphaBlend, applyShroud, fogMode, numShadows ), \
	PS_NumTextures(SecTexBlend_SpecularAlpha, applyShroud, fogMode, numShadows )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_ApplyShroud = PS_Multiplier_SecondaryTextureBlendMode * 4 );

#define PS_ApplyShroud(fogMode, numShadows ) \
	PS_SecondaryTextureBlendMode(false, fogMode, numShadows ), \
	PS_SecondaryTextureBlendMode(true, fogMode, numShadows )
	
DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_FogMode = PS_Multiplier_ApplyShroud * 2 );

#define PS_FogMode(numShadows ) \
	PS_ApplyShroud(FogMode_Disabled, numShadows ), \
	PS_ApplyShroud(FogMode_Opaque, numShadows ), \
	PS_ApplyShroud(FogMode_Additive, numShadows )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = PS_Multiplier_FogMode * 3 );

#define PS_NumShadows \
	PS_FogMode(0), \
	PS_FogMode(1)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_NumShadows
};
#endif

technique Default
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array, min(NumJointsPerVertex, 2)
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_Multiplier_TexCoordMapper1
			+ (NumRecolorColors > 0 && UseRecolorColors) * VS_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_Multiplier_SecondaryTextureBlendMode
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_Multiplier_ApplyShroud
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode
			+ min(NumShadows, 1) * PS_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );

		AddressU[0] = ( Sampler_ClampU_ClampV_NoMip_0.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[0] = ( Sampler_ClampU_ClampV_NoMip_0.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[0] = ( Sampler_ClampU_ClampV_NoMip_0.z > 0.5 ? 0 /*None*/ : MipFilterBest);

		AddressU[1] = ( Sampler_ClampU_ClampV_NoMip_1.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[1] = ( Sampler_ClampU_ClampV_NoMip_1.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[1] = ( Sampler_ClampU_ClampV_NoMip_1.z > 0.5 ? 0 /*None*/ : MipFilterBest);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}  
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: Default_LowQuality
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondaryTexCoord : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_L VS_L(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform bool blendModeAdditive,
		uniform int texCoordMapper_0,
		uniform int texCoordMapper_1,
		uniform bool applyHouseColor,
		uniform bool fogEnabled)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	USE_POINT_LIGHT_INTERACTIVE(PointLight, 0);
	
	VSOutput_L Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal_L(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);


	// Apply house color
	if (applyHouseColor)
	{
		VertexColor.xyz *= lerp(RecolorColor, float3(1.0,1.0,1.0),.25);
		
		if (HouseColorPulse)
		{
			//VertexColor.xyz *= (sin(Time * 2) + 1.2);
		}
	}

	// Fade out edges.
	float viewingAngle = abs(dot(worldEyeDir, worldNormal));
	float fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle);
	if (blendModeAdditive)
	{
		VertexColor.xyz *= fadeOut;
	}
	else
	{
		VertexColor.a *= fadeOut;
	}

	// Compute light
	float3 diffuseLight = 0;
	float3 specularLight = 0;
	
	// Compute directional lights
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[i].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[i].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		float3 lightColor = DirectionalLight[i].Color;
		if (i == 0)
		{
			lightColor *= NoCloudMultiplier;
		}

		diffuseLight += lightColor * lighting.y;
		specularLight += lightColor * lighting.z;
	}

	// Compute point lights
	/*for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;

		float3 halfEyeLightVector = normalize(direction + worldEyeDir);
		float4 lighting = max(0, dot(worldNormal, direction));
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * lighting.y;
	}*/
	
	float3 diffuseColor = (ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, Opacity * OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = specularLight * ColorSpecular / 2;
	
	// Set base texture coordinate	
	Out.BaseTexCoord = TexCoord0;
	if (texCoordMapper_0 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.BaseTexCoord = Out.BaseTexCoord * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	}
	else if (texCoordMapper_0 == TexCoordMapper_Video)
	{
		Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	}

	Out.SecondaryTexCoord = TexCoord1;
	if (texCoordMapper_1 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.SecondaryTexCoord = Out.SecondaryTexCoord * TexCoordTransform_1.xy + Time * TexCoordTransform_1.zw;
	}

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate fog
#if SUPPORT_FOG
	if (fogEnabled)
	{
		Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);
	}
	else
	{
		Out.SpecularColor_Fog.w = 1.0;
	}
#else
	Out.SpecularColor_Fog.w = 1.0;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_L In, uniform int numTextures, uniform int secondaryTextureBlendMode,
		uniform bool applyShroud, uniform int fogMode) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;
	float3 specularColor = In.SpecularColor_Fog.xyz;

	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;
	
	if (numTextures >= 1)
	{
		color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);
	}

	if (numTextures >= 2)
	{
		float4 secondaryColor = tex2D( SAMPLER(Texture_1), In.SecondaryTexCoord);

		if (secondaryTextureBlendMode == SecTexBlend_Modulate)
		{
			color.xyz *= secondaryColor;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_Modulate2X)
		{
			color.xyz *= secondaryColor.xyz;
			color.xyz += color.xyz;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_AlphaBlend)
		{
			color.xyz = lerp(color.xyz, secondaryColor.xyz, saturate(color.a));
		}
		else if (secondaryTextureBlendMode == SecTexBlend_SpecularAlpha)
		{
			color.xyz += specularColor * color.a;
		}
	}
	
	// Overbrighten	
	color.xyz += color.xyz * 0.999;

	// Apply fog
#if SUPPORT_FOG
	float fogStrength = In.SpecularColor_Fog.w;
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}
#endif

	// Apply shroud
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

	return color;
}

// ----------------------------------------------------------------------------
// SHADER: VS_L_Xenon
// ----------------------------------------------------------------------------
VSOutput_L VS_L_Xenon(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0 )
{
	return VS_L( InSkin, TexCoord0, TexCoord1, VertexColor, 
				min(NumJointsPerVertex, 2),
				BlendMode == BlendMode_Additive,
				min(TexCoordMapper_0, MaxTexCoordMapper_0),
				min(TexCoordMapper_1, MaxTexCoordMapper_1),
				NumRecolorColors > 0 && UseRecolorColors,
				true);
				
}

// ----------------------------------------------------------------------------
// SHADER: PS_L_Xenon
// ----------------------------------------------------------------------------
float4 PS_L_Xenon( VSOutput_L In ) : COLOR
{
	return PS_L( In, min( NumTextures, 2 ), SecondaryTextureBlendMode,
					(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR),
					(Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default_M
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_NumJointsPerVertex = 1 );

#define VS_L_NumJointsPerVertex(blendModeAdditive, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget) \
	compile compileTarget VS_L(0, blendModeAdditive, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled), \
	compile compileTarget VS_L(1, blendModeAdditive, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled), \
	compile compileTarget VS_L(2, blendModeAdditive, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_BlendModeAdditive = 3 * VS_L_Multiplier_NumJointsPerVertex );

#define VS_L_BlendModeAdditive(texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget) \
	VS_L_NumJointsPerVertex(false, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget), \
	VS_L_NumJointsPerVertex(true, texCoordMapper0, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_TexCoordMapper0 = 2 * VS_L_Multiplier_BlendModeAdditive );

#define VS_L_TexCoordMapper0(texCoordMapper1, applyHouseColor, fogEnabled, compileTarget) \
	VS_L_BlendModeAdditive(TexCoordMapper_Direct, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget), \
	VS_L_BlendModeAdditive(TexCoordMapper_ScaleMove, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget), \
	VS_L_BlendModeAdditive(TexCoordMapper_Video, texCoordMapper1, applyHouseColor, fogEnabled, compileTarget)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_TexCoordMapper1 = 3 * VS_L_Multiplier_TexCoordMapper0 );

#define VS_L_TexCoordMapper1(applyHouseColor, fogEnabled, compileTarget) \
	VS_L_TexCoordMapper0(TexCoordMapper_Direct, applyHouseColor, fogEnabled, compileTarget), \
	VS_L_TexCoordMapper0(TexCoordMapper_ScaleMove, applyHouseColor, fogEnabled, compileTarget)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_ApplyHouseColor = 2 * VS_L_Multiplier_TexCoordMapper1 );

#define VS_L_ApplyHouseColor(fogEnabled, compileTarget) \
	VS_L_TexCoordMapper1(false, fogEnabled, compileTarget), \
	VS_L_TexCoordMapper1(true, fogEnabled, compileTarget)

DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 * VS_L_Multiplier_ApplyHouseColor );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_ApplyHouseColor(false, vs_1_1)
};
#endif

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = VS_L_Multiplier_Final );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_L_ApplyHouseColor(true, vs_2_0) // Medium technique uses low shader, but with fog and VS2.0
};
#endif
	
#define PS_L_NumTextures(secondaryTextureBlendMode, applyShroud, fogMode) \
	compile ps_1_1 PS_L(0, secondaryTextureBlendMode, applyShroud, fogMode), \
	compile ps_1_1 PS_L(1, secondaryTextureBlendMode, applyShroud, fogMode), \
	compile ps_1_1 PS_L(2, secondaryTextureBlendMode, applyShroud, fogMode)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_SecondaryTextureBlendMode = 3 );

#define PS_L_SecondaryTextureBlendMode(applyShroud, fogMode) \
	PS_L_NumTextures(SecTexBlend_Modulate, applyShroud, fogMode), \
	PS_L_NumTextures(SecTexBlend_Modulate2X, applyShroud, fogMode), \
	PS_L_NumTextures(SecTexBlend_AlphaBlend, applyShroud, fogMode), \
	PS_L_NumTextures(SecTexBlend_SpecularAlpha, applyShroud, fogMode)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_ApplyShroud = PS_L_Multiplier_SecondaryTextureBlendMode * 4 );

#define PS_L_ApplyShroud(fogMode) \
	PS_L_SecondaryTextureBlendMode(false, fogMode), \
	PS_L_SecondaryTextureBlendMode(true, fogMode)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_FogMode = PS_L_Multiplier_ApplyShroud * 2 );

#define PS_L_FogMode \
	PS_L_ApplyShroud(FogMode_Disabled), \
	PS_L_ApplyShroud(FogMode_Opaque), \
	PS_L_ApplyShroud(FogMode_Additive)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_FogMode * 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_FogMode
};
#endif

technique _Default_M
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_M")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
			min(NumJointsPerVertex, 2)
			+ (BlendMode == BlendMode_Additive) * VS_L_Multiplier_BlendModeAdditive
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_L_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_L_Multiplier_TexCoordMapper1
			+ (NumRecolorColors > 0 && UseRecolorColors) * VS_L_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_L_Xenon() );

		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_L_Multiplier_SecondaryTextureBlendMode
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_L_Multiplier_ApplyShroud
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_L_Multiplier_FogMode,
			compile PS_VERSION PS_L_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );

		AddressU[0] = ( Sampler_ClampU_ClampV_NoMip_0.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[0] = ( Sampler_ClampU_ClampV_NoMip_0.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[0] = ( Sampler_ClampU_ClampV_NoMip_0.z > 0.5 ? 0 /*None*/ : MipFilterBest);

		AddressU[1] = ( Sampler_ClampU_ClampV_NoMip_1.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[1] = ( Sampler_ClampU_ClampV_NoMip_1.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[1] = ( Sampler_ClampU_ClampV_NoMip_1.z > 0.5 ? 0 /*None*/ : MipFilterBest);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default_L
// ----------------------------------------------------------------------------
technique _Default_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_L")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
			min(NumJointsPerVertex, 2)
			+ (BlendMode == BlendMode_Additive) * VS_L_Multiplier_BlendModeAdditive
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_L_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_L_Multiplier_TexCoordMapper1
			+ (NumRecolorColors > 0 && UseRecolorColors) * VS_L_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_L_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_L_Multiplier_SecondaryTextureBlendMode
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_L_Multiplier_ApplyShroud,
		 	compile PS_VERSION PS_L_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );

		AddressU[0] = ( Sampler_ClampU_ClampV_NoMip_0.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[0] = ( Sampler_ClampU_ClampV_NoMip_0.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[0] = ( Sampler_ClampU_ClampV_NoMip_0.z > 0.5 ? 0 /*None*/ : MipFilterBest);

		AddressU[1] = ( Sampler_ClampU_ClampV_NoMip_1.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[1] = ( Sampler_ClampU_ClampV_NoMip_1.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[1] = ( Sampler_ClampU_ClampV_NoMip_1.z > 0.5 ? 0 /*None*/ : MipFilterBest);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}  
}

#endif // ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: ShadowMap
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Opacity : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float Depth : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex, uniform bool blendModeAdditive)
{
	VSOutput_CreateShadowMap Out;
	
	float3 worldPosition = 0;
	float3 ignoredWorldNormal;
	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, ignoredWorldNormal);
	
	float4 position = mul(mul(float4(worldPosition, 1), View), Projection);
	
	Out.Opacity = Opacity * OpacityOverride * VertexColor.w;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	
	Out.Depth = position.z / position.w;

	// Don't render additive objects
	if (blendModeAdditive)
	{
		position = float4(1, 1, 1, 1);
	}

	Out.Position = position;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform int numTextures, uniform bool alphaTestEnable) : COLOR
{
	float opacity = In.Opacity;

	if (numTextures >= 1)
	{
		opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	}
	
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
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon( VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float4 VertexColor: COLOR0 )
{
	return CreateShadowMapVS( InSkin, TexCoord0, VertexColor, min(NumJointsPerVertex, 2), BlendMode == BlendMode_Additive );
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapPS_Xenon
// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon( VSOutput_CreateShadowMap In ) : COLOR
{
	return CreateShadowMapPS( In, min(NumTextures, 1), AlphaTestEnable || BlendMode == BlendMode_Alpha );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _CreateShadowMap
// ----------------------------------------------------------------------------
#if CAST_SHADOWS

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_NumJointsPerVertex = 1 );

#define VSCreateShadowMap_NumJointsPerVertex(blendModeAdditive) \
	compile vs_1_1 CreateShadowMapVS(0, blendModeAdditive), \
	compile vs_1_1 CreateShadowMapVS(1, blendModeAdditive), \
	compile vs_1_1 CreateShadowMapVS(2, blendModeAdditive)

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_BlendModeAdditive = 3 * VSCreateShadowMap_Multiplier_NumJointsPerVertex );

#define VSCreateShadowMap_BlendModeAdditive \
	VSCreateShadowMap_NumJointsPerVertex(false), \
	VSCreateShadowMap_NumJointsPerVertex(true)

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 * VSCreateShadowMap_Multiplier_BlendModeAdditive );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_BlendModeAdditive
};
#endif

#define PSCreateShadowMap_NumTextures(alphaTestEnable) \
	compile ps_2_0 CreateShadowMapPS(0, alphaTestEnable), \
	compile ps_2_0 CreateShadowMapPS(1, alphaTestEnable)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_AlphaTestEnable = 2 );

#define PSCreateShadowMap_AlphaTestEnable \
	PSCreateShadowMap_NumTextures(false), \
	PSCreateShadowMap_NumTextures(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = PSCreateShadowMap_Multiplier_AlphaTestEnable * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif

technique _CreateShadowMap
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_CreateShadowMap")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 2)
			+ (BlendMode == BlendMode_Additive) * VSCreateShadowMap_Multiplier_BlendModeAdditive,
			compile VS_VERSION CreateShadowMapVS_Xenon()
		);
		
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			min(NumTextures, 1)
			+ (AlphaTestEnable || BlendMode == BlendMode_Alpha) * PSCreateShadowMap_Multiplier_AlphaTestEnable,
			compile PS_VERSION CreateShadowMapPS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AddressU[1] = ( Sampler_ClampU_ClampV_NoMip_1.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[1] = ( Sampler_ClampU_ClampV_NoMip_1.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[1] = ( Sampler_ClampU_ClampV_NoMip_1.z > 0.5 ? 0 /*None*/ : MipFilterBest);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}
}

#endif // if CAST_SHADOWS

// ----------------------------------------------------------------------------
// SHADER: FlatColor
// ----------------------------------------------------------------------------
float4 PS_FlatColor( VSOutput In, uniform int numTextures ) : COLOR
{
	float opacity = OpacityOverride;

	opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	return float4(FlatColorOverride.xyz, opacity); 
}

// ----------------------------------------------------------------------------
// SHADER: FlatColor_Xenon
// ----------------------------------------------------------------------------
float4 PS_FlatColor_Xenon( VSOutput In ) : COLOR
{
	return PS_FlatColor( In, min(NumTextures, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: FlatColor
// ----------------------------------------------------------------------------
#define PSFlatColorMap_NumTextures \
	compile ps_2_0 PS_FlatColor( 0 ), \
	compile ps_2_0 PS_FlatColor( 1 )

DEFINE_ARRAY_MULTIPLIER( PSCreateFlatColor_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateFlatColor_Array[PSCreateFlatColor_Multiplier_Final] =
{
	PSFlatColorMap_NumTextures
};
#endif

// ----------------------------------------------------------------------------
technique _DrawFlatColor
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_DrawFlatColor")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array, min(NumJointsPerVertex, 2)
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_Multiplier_TexCoordMapper1,
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateFlatColor_Array, min(NumTextures, 1),
			compile PS_VERSION PS_FlatColor_Xenon()
		);		

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaBlendEnable = false;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );

		AddressU[0] = ( Sampler_ClampU_ClampV_NoMip_0.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[0] = ( Sampler_ClampU_ClampV_NoMip_0.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[0] = ( Sampler_ClampU_ClampV_NoMip_0.z > 0.5 ? 0 /*None*/ : MipFilterBest);

		AddressU[1] = ( Sampler_ClampU_ClampV_NoMip_1.x > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		AddressV[1] = ( Sampler_ClampU_ClampV_NoMip_1.y > 0.5 ? 3 /*Clamp*/ : 1 /*Wrap*/);
		MipFilter[1] = ( Sampler_ClampU_ClampV_NoMip_1.z > 0.5 ? 0 /*None*/ : MipFilterBest);
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}  
}

// ----------------------------------------------------------------------------
// SHADER: WorldNormals
// ----------------------------------------------------------------------------
struct VSWorldNormOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSWorldNormOutput VS_WorldNormShader(
		float4 VertexColor : COLOR0, float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		VSInputSkinningMultipleBones InSkin,
		uniform int numJointsPerVertex	)
{
	VSWorldNormOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
				
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));
	Out.Color.xyz = mul(worldNormal, (float3x3)View); //transform the normal		
	Out.Color.w = Opacity * OpacityOverride * VertexColor.w;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	Out.SecondTexCoord = TexCoord1;
	
	return Out;
}

// ----------------------------------------------------------------------------
VSWorldNormOutput VS_WorldNormShader_Xenon( float4 VertexColor : COLOR0, float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		VSInputSkinningMultipleBones InSkin )
{
	return VS_WorldNormShader( VertexColor, TexCoord0, TexCoord1, InSkin, min(NumJointsPerVertex, 2) );
}

// ----------------------------------------------------------------------------
float4 PS_WorldNormColor( VSWorldNormOutput In, uniform int numTextures ) : COLOR
{
	float opacity = In.Color.w;

	if (numTextures >= 1)
	{
		opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	}
	
	float3 colorNormal = (In.Color.xyz / 2) + 0.5f; //translated to [0..1]
	return float4(colorNormal, opacity);
}

// ----------------------------------------------------------------------------
float4 PS_WorldNormColor_Xenon( VSWorldNormOutput In ) : COLOR
{
	return PS_WorldNormColor( In, min(NumTextures, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: WorldNormals
// ----------------------------------------------------------------------------
#define VS_WorldNormNumJointsPerVertex \
	compile vs_2_0 VS_WorldNormShader(0), \
	compile vs_2_0 VS_WorldNormShader(1), \
	compile vs_2_0 VS_WorldNormShader(2)

DEFINE_ARRAY_MULTIPLIER( VSCreateWorldNorm_Multiplier_Final = 3 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_WorldNormArray[VSCreateWorldNorm_Multiplier_Final] =
{
	VS_WorldNormNumJointsPerVertex
};
#endif

#define PSWorldNormMap_NumTextures \
	compile ps_2_0 PS_WorldNormColor( 0 ), \
	compile ps_2_0 PS_WorldNormColor( 1 )

DEFINE_ARRAY_MULTIPLIER( PSCreateWorldNorm_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateWorldNorm_Array[ PSCreateWorldNorm_Multiplier_Final ] =
{
	PSWorldNormMap_NumTextures
};
#endif
	
// ----------------------------------------------------------------------------
technique _RenderWorldNormals
{
	pass p0 
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_RenderWorldNormals")
	>
	{		
		VertexShader = ARRAY_EXPRESSION_VS( VS_WorldNormArray,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_WorldNormShader_Xenon()
		);
			
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateWorldNorm_Array,
			min(NumTextures, 1),
			compile PS_VERSION PS_WorldNormColor_Xenon()
		);
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaBlendEnable = false;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaTestEnable = ( AlphaTestEnable || BlendMode == BlendMode_Alpha );
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}
}
