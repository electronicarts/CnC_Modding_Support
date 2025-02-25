//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple material with one texture
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_RECOLORING 1 // Defined only in Infantry.fx!
#define USE_INTERACTIVE_LIGHTS 1
//#define DISABLE_EXPRESSION_EVALUATORS
#include "Common.fxh"
#include "Random.fxh"

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
// Transformations
// ----------------------------------------------------------------------------
float4x4 View       : View;
float4x3 ViewI      : ViewInverse;

#if defined(_WW3D_)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 Projection : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

float Time : Time;

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
SAMPLER_2D_SHADOW( ShadowMap )


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
	//string UIName = "Opacity";
    //string UIWidget = "Slider";
> = 1.0;

SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Base Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------


#if defined(SUPPORT_RECOLORING)

SAMPLER_2D_BEGIN( RecolorTexture,
	string UIName = "House Color Tex.";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

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
> = float3(.8, .3, .2);

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

#else // defined(SUPPORT_RECOLORING)
static const int NumRecolorColors = 0;
static const float3 RecolorColor = float3(0, 0, 0);
#endif // defined(SUPPORT_RECOLORING)


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

// ----------------------------------------------------------------------------
// Tree Sway
// ----------------------------------------------------------------------------

#if defined(TREE_SWAY)

    float SwayStartHeight
    <
    	string UIName = "Sway Start Height";
        string UIWidget = "Slider";
    > = 15.0;

    float SwayStartRadius
    <
    	string UIName = "Sway Start Radius";
        string UIWidget = "Slider";
        float UIMin = 0.01;
        float UIMax = 1000;
    > = 5.0;

    float SwayStrength
    <
    	string UIName = "Sway Strength";
        string UIWidget = "Slider";
        float UIMin = 0;
        float UIMax = 100;
    > = 1.0;

    void ApplyTreeSway( VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex, inout float3 WorldPosition, bool UseLowLODBones )
    {
        // Only vertices above SwayStartHeight, which is relative to the origin of the object, will be affected
        // Above SwayStartHeight, the amount of sway will ramp up to full strength based on the SwayStartRadius
        float3 worldPivotPosition;

        if( UseLowLODBones )
        {
		    worldPivotPosition = GetFirstBonePosition_L(InSkin.BlendIndices, NumJointsPerVertex);
        }
        else
        {
		    worldPivotPosition = GetFirstBonePosition(InSkin.BlendIndices, NumJointsPerVertex);
        }

        float pivotOffset = WorldPosition.z - worldPivotPosition.z;
    
        float swayHeight = pivotOffset - SwayStartHeight;
        float swayAmount = clamp( swayHeight / SwayStartRadius, 0, 1 ) * SwayStrength;
        
        // Make the sway unique based on the position of the object in the world
        float2 phaseOffset = GetRandomFloatValues( float2(0, 0), float2(20, 20), 3, ( worldPivotPosition.x + worldPivotPosition.y ) * 2 );

        float2 phase = Time.xx + phaseOffset;
    
        float2 sway = sin( phase );

        WorldPosition.xy += swayAmount * sway;
    }
#endif // defined(TREE_SWAY)

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

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

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

// ----------------------------------------------------------------------------
// SHADER : DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 CloudTexCoord : TEXCOORD2;
	float2 ShroudTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD4;
	float3 MainLightDiffuseColor : TEXCOORD5;
	float3 MainLightSpecularColor : TEXCOORD6;
};

// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	USE_POINT_LIGHT_INTERACTIVE(PointLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
#if defined(TREE_SWAY)
    ApplyTreeSway( InSkin, numJointsPerVertex, worldPosition, false );
#endif
	
	//if (doSkinning)
	//	VertexColor = float4(BlendWeights.xy, 0, 1);
	//	VertexColor *= float4(1, 0, 0, 1);
	
#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	
	// Compute light
	
	// Compute directional lights
	if (NumDirectionalLights > 0)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[0].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[0].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		float3 diffuseLight = DirectionalLight[0].Color * lighting.y;
		float3 specularLight = DirectionalLight[0].Color * lighting.z;
		
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
	
	// Calculate cloud layer coordinates
	Out.CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	
	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate shadow map texture coordinates	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);

	// Calculate fog
	Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);
	
//Out.DiffuseColor_Opacity = VertexColor;
	return Out;
}

// Xenon vertex shader: Remove uniform from NumJointsPerVertex parameter and have it do real branching.
VSOutput VS_Xenon(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0)
{
	return VS(InSkin, TexCoord0, VertexColor, NumJointsPerVertex);
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform bool applyShroud, uniform int fogMode, uniform int numShadows,
		uniform bool recolorEnable) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;
//return color;
	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

	float3 cloud = float3(1, 1, 1);
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	cloud = tex2D( SAMPLER(CloudTexture), In.CloudTexCoord);
#endif

	if (numShadows > 0)
	{
		cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo);
	}

	color.xyz += In.MainLightDiffuseColor * cloud;
	specularColor += In.MainLightSpecularColor * cloud;

//	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;

	color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

#if defined(SUPPORT_RECOLORING)
	if (recolorEnable)
	{
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), In.BaseTexCoord);
		recolorColor.xyz *= RecolorColor;
		color.xyz = lerp(color.xyz, recolorColor.xyz / 2, recolorColor.a);
	}
#endif
	// Overbrighten	
	color.xyz += color.xyz;

	// Apply fog
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}

	// Apply shroud
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

///
//if (applyShroud)
//	color = lerp(color, float4(0, 1, 1, 1), saturate(sin(Time * 10) ));
//else
//	color = lerp(color, float4(1, 0, 1, 1), saturate(sin(Time * 10) ));
///

	return color;
}

float4 PS_Xenon(VSOutput In) : COLOR
{
	return PS( In, true, (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled), 1, NumRecolorColors > 0);
}


DEFINE_ARRAY_MULTIPLIER(VS_Multiplier_NumJointsPerVertex = 1);

#define VS_NumJointsPerVertex \
	compile vs_2_0 VS(0), \
	compile vs_2_0 VS(1), \
	compile vs_2_0 VS(2)

DEFINE_ARRAY_MULTIPLIER(VS_Multiplier_Final = VS_Multiplier_NumJointsPerVertex * 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] = { VS_NumJointsPerVertex };
#endif

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_ApplyShroud = 1);

#define PS_ApplyShroud(fogMode, numShadows, houseColorEnable) \
	compile ps_2_0 PS(false, fogMode, numShadows, houseColorEnable), \
	compile ps_2_0 PS(true, fogMode, numShadows, houseColorEnable)
	
DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_FogMode = PS_Multiplier_ApplyShroud * 2);

#define PS_FogMode(numShadows, houseColorEnable) \
	PS_ApplyShroud(FogMode_Disabled, numShadows, houseColorEnable), \
	PS_ApplyShroud(FogMode_Opaque, numShadows, houseColorEnable), \
	PS_ApplyShroud(FogMode_Additive, numShadows, houseColorEnable)

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_NumShadows = PS_Multiplier_FogMode * 3);

#define PS_NumShadows(houseColorEnable) \
	PS_FogMode(0, houseColorEnable), \
	PS_FogMode(1, houseColorEnable)

#if defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_RecolorEnable = PS_Multiplier_NumShadows * 2);

#define PS_RecolorEnable \
	PS_NumShadows(false), \
	PS_NumShadows(true)

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_Final = PS_Multiplier_RecolorEnable * 2);

#else // defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_Final = PS_Multiplier_NumShadows * 2);
DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_RecolorEnable = 0);

#define PS_RecolorEnable \
	PS_NumShadows(false)

#endif // defined(SUPPORT_RECOLORING)

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] = { PS_RecolorEnable };
#endif


// ----------------------------------------------------------------------------
// TECHNIQUE : DEFAULT
// ----------------------------------------------------------------------------

technique Default
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("BasicW3D")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS(VS_Array,
			min(NumJointsPerVertex, 2) * VS_Multiplier_NumJointsPerVertex,
			// Non-array alternative:
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS(PS_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_Multiplier_ApplyShroud
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode
			+ min(NumShadows, 1) * PS_Multiplier_NumShadows
			+ (NumRecolorColors > 0) * PS_Multiplier_RecolorEnable,
			// Non-array alternative:
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride >= 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );
		
		AlphaTestEnable = ( AlphaTestEnable );
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

// ----------------------------------------------------------------------------
// SHADER: Default_MediumQuality
// ----------------------------------------------------------------------------
#if ENABLE_LOD
struct VSOutput_M
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondaryTexCoord : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform bool DoApplyTreeSway)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	USE_POINT_LIGHT_INTERACTIVE(PointLight, 0);
	
	VSOutput_M Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal_L(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
#if defined(TREE_SWAY)
    if( DoApplyTreeSway )
    {
	    ApplyTreeSway( InSkin, numJointsPerVertex, worldPosition, true );
    }
#endif

	//if (doSkinning)
	//	VertexColor = float4(BlendWeights.xy, 0, 1);
	//	VertexColor *= float4(1, 0, 0, 1);

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	
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

		// Disabled specular lighting from point light, as shader is running out of instruction slots.
		//float4 lighting = lit(dot(worldNormal, direction),
		//	dot(worldNormal, halfEyeLightVector), Shininess);
		float4 lighting = max(0, dot(worldNormal, direction));
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * lighting.y;
		//specularLight += PointLight[i].Color * attenuation * ColorSpecular * lighting.z;
	}*/
	
	float3 diffuseColor = (ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, Opacity * OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = specularLight * ColorSpecular / 2;
	
	// Set base texture coordinate	
	Out.BaseTexCoord = TexCoord0;

	// If recoloring is used, the second texture coordinate needs to be the same as base texture coordinate
	Out.SecondaryTexCoord = Out.BaseTexCoord;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate fog
	Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, ViewI[3]);
	
//Out.DiffuseColor_Opacity = VertexColor;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_M(VSOutput_M In, uniform bool applyShroud, uniform int fogMode, uniform bool recolorEnable) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;

	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

//	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;
	
	color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

#if defined(SUPPORT_RECOLORING)
	if (recolorEnable)
	{
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), In.SecondaryTexCoord);
		recolorColor.xyz *= RecolorColor;
		color.xyz = lerp(color.xyz, recolorColor.xyz / 2, recolorColor.a);
	}
#endif	
	// Overbrighten	
	color.xyz += color.xyz * 0.999;

	// Apply fog
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}

	// Apply shroud
	if (applyShroud)
	{
		color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	}

	return color;
}


// Medium
DEFINE_ARRAY_MULTIPLIER(VS_M_Multiplier_NumJointsPerVertex = 1);

#define VS_M_NumJointsPerVertex \
	compile VS_VERSION_HIGH VS_M(0, true), \
	compile VS_VERSION_HIGH VS_M(1, true), \
	compile VS_VERSION_HIGH VS_M(2, true)

DEFINE_ARRAY_MULTIPLIER(VS_M_Multiplier_Final = VS_M_Multiplier_NumJointsPerVertex * 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};
#endif

// Low
DEFINE_ARRAY_MULTIPLIER(VS_L_Multiplier_NumJointsPerVertex = 1);

#define VS_L_NumJointsPerVertex \
	compile VS_VERSION_LOW VS_M(0, false), \
	compile VS_VERSION_LOW VS_M(1, false), \
	compile VS_VERSION_LOW VS_M(2, false)

DEFINE_ARRAY_MULTIPLIER(VS_L_Multiplier_Final = VS_L_Multiplier_NumJointsPerVertex * 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};
#endif

// Medium and below
DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_ApplyShroud = 1);

#define PS_M_ApplyShroud(fogMode, recolorEnable) \
	compile PS_VERSION_LOW PS_M(false, fogMode, recolorEnable), \
	compile PS_VERSION_LOW PS_M(true, fogMode, recolorEnable)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_FogMode = PS_M_Multiplier_ApplyShroud * 2);

#define PS_M_FogMode(recolorEnable) \
	PS_M_ApplyShroud(FogMode_Disabled, recolorEnable), \
	PS_M_ApplyShroud(FogMode_Opaque, recolorEnable), \
	PS_M_ApplyShroud(FogMode_Additive, recolorEnable)

#if defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_RecolorEnable = PS_M_Multiplier_FogMode * 3);

#define PS_M_RecolorEnable \
	PS_M_FogMode(false), \
	PS_M_FogMode(true)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_Final = PS_M_Multiplier_RecolorEnable * 2);

#else // defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_Final = PS_M_Multiplier_FogMode * 3);
DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_RecolorEnable = 0);

#define PS_M_RecolorEnable \
	PS_M_FogMode(false)

#endif // defined(SUPPORT_RECOLORING)

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_RecolorEnable
};
#endif



// ----------------------------------------------------------------------------
// TECHNIQUE : Default_MediumQuality
// ----------------------------------------------------------------------------
technique _Default_M
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("BasicW3D_M")
	>
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_M_Array,
			min(NumJointsPerVertex, 2) * VS_M_Multiplier_NumJointsPerVertex,
			NO_ARRAY_ALTERNATIVE
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_M_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_M_Multiplier_ApplyShroud
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_M_Multiplier_FogMode
			+ (NumRecolorColors > 0) * PS_M_Multiplier_RecolorEnable,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride >= 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );
		
		AlphaTestEnable = ( AlphaTestEnable );
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE : Default_LowQuality
// ----------------------------------------------------------------------------
technique _Default_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("BasicW3D_M")
	>
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_L_Array,
			min(NumJointsPerVertex, 2) * VS_M_Multiplier_NumJointsPerVertex,
			NO_ARRAY_ALTERNATIVE
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_M_Array,
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_M_Multiplier_ApplyShroud
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_M_Multiplier_FogMode
			+ (NumRecolorColors > 0) * PS_M_Multiplier_RecolorEnable,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride >= 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );
		
		AlphaTestEnable = ( AlphaTestEnable );
#endif

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}


#endif // ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMap
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
		uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;
	
	float3 worldPosition = 0;
	float3 ignoredWorldNormal;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, ignoredWorldNormal);
	
#if defined(TREE_SWAY)
    ApplyTreeSway( InSkin, numJointsPerVertex, worldPosition, false );
#endif

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	
	Out.Opacity = Opacity * OpacityOverride * VertexColor.w;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0;
	
	Out.Depth = Out.Position.z / Out.Position.w;

	// Don't render additive objects
	if (BlendMode == BlendMode_Additive)
	{
		Out.Position = float4(1, 1, 1, 0);
	}
	
	return Out;
}

// Xenon vertex shader: Remove uniform from NumJointsPerVertex parameter and have it do real branching.
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon(VSInputSkinningMultipleBones InSkin,
		 float2 TexCoord0 : TEXCOORD0, 
		 float4 VertexColor: COLOR0)
{
	return CreateShadowMapVS(InSkin, TexCoord0, VertexColor, NumJointsPerVertex);
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform bool alphaTestEnable) : COLOR
{
	float opacity = In.Opacity;

	opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	
	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}

	return In.Depth;	
}



#define VSCreateShadowMap_NumJointsPerVertex \
	compile vs_1_1 CreateShadowMapVS(0), \
	compile vs_1_1 CreateShadowMapVS(1), \
	compile vs_1_1 CreateShadowMapVS(2)

DEFINE_ARRAY_MULTIPLIER(VSCreateShadowMap_Multiplier_Final = 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif


#define PSCreateShadowMap_AlphaTestEnable \
	compile ps_2_0 CreateShadowMapPS(false), \
	compile ps_2_0 CreateShadowMapPS(true)

DEFINE_ARRAY_MULTIPLIER(PSCreateShadowMap_Multiplier_Final = 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif



// ----------------------------------------------------------------------------
// TECHNIQUE : CreateShadowMap
// ----------------------------------------------------------------------------

technique _CreateShadowMap
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("BasicW3D_CreateShadowMap")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS(VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 2),
			// Non-array alternative:
			compile VS_VERSION CreateShadowMapVS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS(PSCreateShadowMap_Array,
			(AlphaTestEnable || BlendMode == BlendMode_Alpha),
			// Non-array alternative:
			compile PS_VERSION CreateShadowMapPS(true)
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
#endif
		
		AlphaBlendEnable = false;
		
		AlphaTestEnable = false; // Handled in pixel shader ( AlphaTestEnable /*|| BlendMode == BlendMode_Alpha */);
		// AlphaFunc = GreaterEqual;
		// AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}



#if defined(EA_PLATFORM_WINDOWS)

// ----------------------------------------------------------------------------
// SHADER: WorldSpaceNormals
// ----------------------------------------------------------------------------
struct VSWorldNormOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSWorldNormOutput VS_WorldNormShader(
		float2 BaseTexCoord : TEXCOORD0, float4 VertexColor : COLOR0,
		VSInputSkinningMultipleBones InSkin,
		uniform int numJointsPerVertex	)
{
	VSWorldNormOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

#if defined(TREE_SWAY)
    ApplyTreeSway( InSkin, numJointsPerVertex, worldPosition, false );
#endif
		
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.Color.xyz = mul(worldNormal, (float3x3)View); //transform the normal		
	Out.Color.w = Opacity * OpacityOverride * VertexColor.w;
	Out.BaseTexCoord = BaseTexCoord;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_WorldNormColor(VSWorldNormOutput In) : COLOR
{
	float opacity = In.Color.w;

	opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	//return float4(In.Color.xyz, opacity); 
	
	float3 colorNormal = (In.Color.xyz / 2) + 0.5f;
	return float4(colorNormal, opacity);	
}



// ----------------------------------------------------------------------------
// TECHNIQUE : WorldSpaceNormals
// ----------------------------------------------------------------------------
#define VS_WorldNormNumJointsPerVertex \
	compile vs_2_0 VS_WorldNormShader(0), \
	compile vs_2_0 VS_WorldNormShader(1), \
	compile vs_2_0 VS_WorldNormShader(2)

vertexshader VS_WorldNormArray[VS_Multiplier_Final] =
{
	VS_WorldNormNumJointsPerVertex
};

technique _RenderWorldNormals
{
	pass p0 
	{		
		VertexShader = ( VS_WorldNormArray[
			min(NumJointsPerVertex, 2) * VS_Multiplier_NumJointsPerVertex
		] );
		PixelShader = compile ps_1_1 PS_WorldNormColor();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AlphaBlendEnable = false;
		
		//AlphaBlendEnable = ( OpacityOverride < 0.99);
		//SrcBlend = SrcAlpha;
		//DestBlend = InvSrcAlpha;
				
		AlphaTestEnable = ( AlphaTestEnable /*|| BlendMode == BlendMode_Alpha */);
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}



// ----------------------------------------------------------------------------
// SHADER: FlatColor
// ----------------------------------------------------------------------------
float4 PS_FlatColor(VSOutput In) : COLOR
{
	float opacity = OpacityOverride;

	opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	return float4(FlatColorOverride.xyz, opacity); 
}



// ----------------------------------------------------------------------------
// TECHNIQUE : DrawFlatColor
// ----------------------------------------------------------------------------
technique _DrawFlatColor
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass P0
	{
		VertexShader = ( VS_Array[
			min(NumJointsPerVertex, 2) * VS_Multiplier_NumJointsPerVertex
		] );	
		PixelShader = compile ps_1_1 PS_FlatColor();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride >= 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

#endif // defined(EA_PLATFORM_WINDOWS)
