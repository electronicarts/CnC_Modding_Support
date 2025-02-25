//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple material with one texture
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_RECOLORING 1 // Defined only in Infantry.fx!
//#define SUPPORT_HOLOGRAPHIC //Enable Holographic shader support branch
//#define SUPPORT_HDR // Define for HDR Multiplier Support
//#define DISABLE_EXPRESSION_EVALUATORS
//#define SUPPORT_SSAO 0	// disable SSAO
//#define SUPPORT_FROZEN 1 // Defined to change appearance of infantry to ice
//#define SUPPORT_RADIATION 1 // Used only for defining radiation infantry deaths
//#define SUPPORT_CHRONORIFT 1 // Defined to change appearance of infantry to Chrono Rifted
#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define MaxNumPointLights 3

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "Random.fxh"
#include "ShadowMap.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);

	int MaxLocalLights = MaxNumPointLights;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
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
#define MaxSkinningBonesPerVertex 2

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

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

float Time : Time;

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

#if defined(SUPPORT_HDR)
	float HDRMultiplier
	<
		string UIName = "HDR Multiplier";
		string UIWidget = "Slider";
		float UIMax = 100;
	> = 1.0;
#endif

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

    void ApplyTreeSway(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex, inout float3 WorldPosition)
    {
        // Only vertices above SwayStartHeight, which is relative to the origin of the object, will be affected
        // Above SwayStartHeight, the amount of sway will ramp up to full strength based on the SwayStartRadius
        float3 worldPivotPosition = GetFirstBonePosition(InSkin.BlendIndices, NumJointsPerVertex);

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

// ----------------------------------------------------------------------------
// Frozen shader ice normal map
// ----------------------------------------------------------------------------
#if defined(SUPPORT_FROZEN)
SAMPLER_2D_BEGIN( FrozenNormalMap,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FXDistortionFractal";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

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

#endif

// ----------------------------------------------------------------------------
// Chrono Rift texture map
// ----------------------------------------------------------------------------
#if defined(SUPPORT_CHRONORIFT)
	SAMPLER_2D_BEGIN( ChronoRiftTexture,
		string UIWidget = "None";
		string SasBindAddress = "WW3D.FXChronoRift";
		)
		MipFilter = Linear;
		MinFilter = Linear;
		MagFilter = Linear;
		AddressU = WRAP;
		AddressV = WRAP;
	SAMPLER_2D_END
#endif

// ----------------------------------------------------------------------------
// Clouds
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
// FOG
// ----------------------------------------------------------------------------
// Variations for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

#if !defined(USE_INDIRECT_CONSTANT)
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
// SHADER : DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : TEXCOORD1;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float4 CloudTexCoord_ShroudTexCoord : TEXCOORD2;
#if defined (SUPPORT_HOLOGRAPHIC)
	float EdgeFade : TEXCOORD3;
#else
	float4 ShadowMapTexCoord : TEXCOORD3;
	float3 MainLightDiffuseColor : TEXCOORD4;	
	float3 MainLightSpecularColor : TEXCOORD5;
#endif
#if defined (SUPPORT_FROZEN)
	float3 WorldNormal : TEXCOORD6;
	float3 WorldEyeDir : TEXCOORD7;
#endif
#if defined(SUPPORT_RADIATION) || defined(SUPPORT_CHRONORIFT)
	float3 EdgeFallOff : TEXCOORD6;
#endif
};

// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform bool usePointLights,
		uniform bool isFrozenPass)		
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

	VertexColor.xyz *= TintColor;

    // $Note (WSK) - diffuse light is not working yet, we simply want the opacity term for now
	float3 diffuseLight = 0;
	float3 diffuseColor = (ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;

	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, OpacityOverride * VertexColor.w);

	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	Out.BaseTexCoord = TexCoord0;

	Out.CloudTexCoord_ShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, worldPosition).yx;
	
	return Out;
}

#else // EA_PLATFORM_WINDOWS || EA_PLATFORM_XENON

VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform bool usePointLights,
		uniform bool isFrozenPass)		
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(TREE_SWAY)
    ApplyTreeSway(InSkin, numJointsPerVertex, worldPosition);
#endif
	
#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	VertexColor.xyz *= TintColor;
	
	if (isFrozenPass)
	{
		// Extrude geo to create a shell for the ice
		worldPosition += worldNormal * 1.5;
	}	

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);

#if defined (SUPPORT_HOLOGRAPHIC)
	float edgeFade = 1-pow(saturate(dot(worldNormal,worldEyeDir)),0.5f);
	Out.EdgeFade = edgeFade;
	Out.DiffuseColor_Opacity = float4(.1,1,.1, OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = float3(1,1,1);
#else

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
	if (usePointLights)
	{
		for (int i = 0; i < NumPointLights; i++)
		{
			diffuseLight += CalculatePointLightDiffuse(PointLight[i], worldPosition, worldNormal);
		}
	}
	
	float3 diffuseColor = (ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;

	#if defined(SUPPORT_HDR)
		diffuseColor.xyz *= HDRMultiplier;
	#endif //SUPPORT_HDR
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = specularLight * ColorSpecular / 2;
	
	// Calculate shadow map texture coordinates	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
#endif	//SUPPORT_HOLOGRAPHIC

	// Set base texture coordinate
	if (isFrozenPass)
	{
		// Use world coords when mapping
		Out.BaseTexCoord = worldPosition.xy * .025;
	}
	else
	{
		#if defined(SUPPORT_HOLOGRAPHIC)
			// Use world coords when mapping rotated 45 degrees
	
			// Build Texture Rotation Matrix And Convert Degrees to Radians --
			float cosAngle = 0;
			float sinAngle = 0;
			float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
			sincos (45 * .017453, sinAngle, cosAngle);	
	
			// Build Rotation 	
			uvCoordRotate[0][0] = cosAngle;
			uvCoordRotate[0][1] = -sinAngle;
			uvCoordRotate[1][1] = uvCoordRotate[0][0];
			uvCoordRotate[1][0] = -uvCoordRotate[0][1];	
			
			Out.BaseTexCoord = mul(worldPosition.xy, uvCoordRotate) * .1;
		#else
			// pass texture coordinates
			Out.BaseTexCoord = TexCoord0;
		#endif
	}		
		
	// Calculate cloud layer coordinates
	Out.CloudTexCoord_ShroudTexCoord.xy = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	
	// Calculate shroud texture coordinates
	Out.CloudTexCoord_ShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, worldPosition).yx;

	// Calculate fog
	Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, GetEyePosition());

#if defined(SUPPORT_FROZEN)
	Out.WorldEyeDir = worldEyeDir;
	// Build 3x3 tranform from object to tangent space
	Out.WorldNormal = worldNormal;
#endif

#if defined(SUPPORT_FORMATIONPREVIEW)
	float fallOff = 1 - dot(worldEyeDir, worldNormal);
	
	Out.DiffuseColor_Opacity.xyz = min(float3(0.0,0.055,0.045) + pow(fallOff, 2.5) * float3(0.0,1.0,0.0), 2); 
#endif

#if defined(SUPPORT_RADIATION)
	float fallOff = 1 - dot(worldEyeDir, worldNormal);
	Out.EdgeFallOff = pow(fallOff, 1.1) * 4;
	Out.BaseTexCoord = TexCoord0 + (worldPosition.xy * .05) + (Time *.15);
#endif

#if defined(SUPPORT_CHRONORIFT)
	float fallOff = 1 - dot(worldEyeDir, worldNormal);
	Out.EdgeFallOff = pow(fallOff, 2);
	Out.BaseTexCoord = TexCoord0 + (worldPosition.xy * .05) + (Time *.3);
#endif

	return Out;
}
#endif

// Xenon vertex shader: Remove uniform from NumJointsPerVertex parameter and have it do real branching.
VSOutput VS_Xenon(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform bool isFrozenPass)
{
	return VS(InSkin, TexCoord0, VertexColor, NumJointsPerVertex, true, isFrozenPass);
}

// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
float4 PS(VSOutput In, uniform int fogMode, uniform bool hasShadow,
	uniform bool recolorEnable, uniform bool isFrozenPass, float2 vPos : PIXELLOC) COLORTARGET
{
	float4 color = In.DiffuseColor_Opacity;

	float2 shroudTexCoord = In.CloudTexCoord_ShroudTexCoord.wz;

	float4 baseTexture = tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

	#if defined(SUPPORT_RECOLORING)
		if (recolorEnable && !isFrozenPass)
		{
			baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, baseTexture.w);
			baseTexture.w = 1;
		}
	#endif //defined(SUPPORT_RECOLORING)

	baseTexture *= tex2D( SAMPLER(ShroudTexture), shroudTexCoord).x;

	color.xyz = baseTexture.xyz;

 	return(color);
}

#else // EA_PLATFORM_WINDOWS || EA_PLATFORM_XENON

float4 PS(VSOutput In, uniform int fogMode, uniform bool hasShadow,
	uniform bool recolorEnable, uniform bool isFrozenPass, float2 vPos : PIXELLOC) COLORTARGET
{
	float2 shroudTexCoord = In.CloudTexCoord_ShroudTexCoord.wz;
	float2 cloudTexCoord = In.CloudTexCoord_ShroudTexCoord.xy;
	float4 color = In.DiffuseColor_Opacity;

#if defined(SUPPORT_HOLOGRAPHIC)
	float4 textureSampler = tex2D( SAMPLER(Texture_0), In.BaseTexCoord);
	textureSampler.xyz = GammaToLinear(textureSampler.xyz);

	color.xyz = textureSampler.xyz + color.xyz * (In.EdgeFade + 0.25);
	color.w *= saturate(textureSampler.x * 2 + .5);
#else

#if defined(SUPPORT_FROZEN)
	if (isFrozenPass)
	{
		// Get bump map normal
		float3 bumpNormal;
		bumpNormal = (float3)tex2D(SAMPLER(FrozenNormalMap), In.BaseTexCoord) * 2.0 - 1.0;

		// Compute view direction in world space
		float3 reflVect = -reflect(In.WorldEyeDir,bumpNormal);

		// Although not technically correct, since we use the Cubemap to fake specular, multiply against the shadow map and add to color
		float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz;
		
		color.xyz = min((In.DiffuseColor_Opacity + envcolor * DirectionalLight[0].Color) * float3(.25, .4, .5),.3);
		
	}
#endif

		float3 specularColor = In.SpecularColor_Fog.xyz;
		float fogStrength = In.SpecularColor_Fog.w;

		float3 cloud = float3(1, 1, 1);
	#if defined(_WW3D_) && !defined(_W3DVIEW_)
		cloud = GammaToLinear(tex2D( SAMPLER(CloudTexture), cloudTexCoord));
	#endif

		if (hasShadow)
		{
			cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord);
		}

		float4 baseTexture = tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

	#if defined(SUPPORT_RECOLORING)
		if (recolorEnable && !isFrozenPass)
		{
			baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, baseTexture.w);
			baseTexture.w = 1;
		}
	#endif //defined(SUPPORT_RECOLORING)

		baseTexture.xyz = GammaToLinear(baseTexture.xyz);
		
	#if defined(SUPPORT_RADIATION)

		color.xyz += In.EdgeFallOff;
	
	#endif
	
		if (!isFrozenPass)
		{
			color.xyz += In.MainLightDiffuseColor * cloud;
			specularColor += In.MainLightSpecularColor * cloud;
			color.xyz += specularColor.xyz;
			color *= baseTexture;
		}

	// Overbrighten	
	color.xyz += color.xyz;

	#if defined(SUPPORT_FORMATIONPREVIEW)
		color = In.DiffuseColor_Opacity;
	#endif // SUPPORT_FORMATIONPREVIEW

	#if SUPPORT_SSAO
		color.xyz *= ComputeSSAO(vPos);
	#endif

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

#endif //SUPPORT_HOLOGRAPHIC

#if defined(SUPPORT_CHRONORIFT)
	float3 Texture0 = GammaToLinear(tex2D( SAMPLER(ChronoRiftTexture), In.BaseTexCoord.xy *2));
	float3 Texture1 = GammaToLinear(tex2D( SAMPLER(ChronoRiftTexture), In.BaseTexCoord.yx *2));
	color.xyz = Texture0 * Texture1 * 50;
	
	// Compute view direction in world space
	color.xyz += In.EdgeFallOff * float3(0.3,0.6,3.0);
	color.xyz = min(color.xyz,2);
	color.w = In.DiffuseColor_Opacity.w;
#endif // SUPPORT_CHRONORIFT

	#if defined(_WW3D_) && !defined(_W3DVIEW_)
		// Apply shroud
		color.xyz *= tex2D( SAMPLER(ShroudTexture), shroudTexCoord);
	#endif

	return CorrectForFrameBufferGamma(color);
}
#endif

float4 PS_Xenon(VSOutput In, uniform bool isFrozenPass, float2 vPos : PIXELLOC) : COLOR
{
	return PS( In, (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled), 1, HasRecolorColors, isFrozenPass, vPos);
}


DEFINE_ARRAY_MULTIPLIER(VS_Multiplier_NumJointsPerVertex = 1);

#define VS_NumJointsPerVertex(isFrozenPass) \
	compile VS_3_0 VS(0, true, isFrozenPass), \
	compile VS_3_0 VS(1, true, isFrozenPass), \
	compile VS_3_0 VS(2, true, isFrozenPass)

DEFINE_ARRAY_MULTIPLIER(VS_Multiplier_Final = VS_Multiplier_NumJointsPerVertex * 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] = 
{
	VS_NumJointsPerVertex(false)
};

#if defined(SUPPORT_FROZEN)
vertexshader VS_Frozen_Array[VS_Multiplier_Final] = 
{
	VS_NumJointsPerVertex(true)
};
#endif
#endif


DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_FogMode = 1);

#define PS_FogMode(hasShadow, houseColorEnable, isFrozenPass) \
	compile PS_3_0 PS(FogMode_Disabled, hasShadow, houseColorEnable, isFrozenPass), \
	compile PS_3_0 PS(FogMode_Opaque, hasShadow, houseColorEnable, isFrozenPass), \
	compile PS_3_0 PS(FogMode_Additive, hasShadow, houseColorEnable, isFrozenPass)

DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_NumShadows = PS_Multiplier_FogMode * 3);

#define PS_NumShadows(houseColorEnable, isFrozenPass) \
	PS_FogMode(0, houseColorEnable, isFrozenPass), \
	PS_FogMode(1, houseColorEnable, isFrozenPass)

#if defined(SUPPORT_RECOLORING)

	DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_RecolorEnable = PS_Multiplier_NumShadows * 2);

	#define PS_RecolorEnable(isFrozenPass) \
		PS_NumShadows(false, isFrozenPass), \
		PS_NumShadows(true, isFrozenPass)

	DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_Final = PS_Multiplier_RecolorEnable * 2);

#else // defined(SUPPORT_RECOLORING)

	DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_Final = PS_Multiplier_NumShadows * 2);
	DEFINE_ARRAY_MULTIPLIER(PS_Multiplier_RecolorEnable = 0);

	#define PS_RecolorEnable(isFrozenPass) \
		PS_NumShadows(false, isFrozenPass)

#endif // defined(SUPPORT_RECOLORING)

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_RecolorEnable(false)
};

#if defined(SUPPORT_FROZEN)
pixelshader PS_Frozen_Array[PS_Multiplier_Final] =
{
	PS_RecolorEnable(true)
};
#endif
#endif


// ----------------------------------------------------------------------------
// TECHNIQUE : DEFAULT
// ----------------------------------------------------------------------------

technique Default
{
	pass P0
#if !defined(SUPPORT_FROZEN) && !defined(SUPPORT_CHRONORIFT)
	<
		USE_EXPRESSION_EVALUATOR("BasicW3D")
	>
#endif
	{
		VertexShader = ARRAY_EXPRESSION_VS(VS_Array,
			min(NumJointsPerVertex, 2) * VS_Multiplier_NumJointsPerVertex,
			// Non-array alternative:
			compile VS_VERSION VS_Xenon(false)
		);
		PixelShader = ARRAY_EXPRESSION_PS(PS_Array,
			(Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode
			+ HasShadow * PS_Multiplier_NumShadows
			+ HasRecolorColors * PS_Multiplier_RecolorEnable,
			// Non-array alternative:
			compile PS_VERSION PS_Xenon(false)
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if defined(SUPPORT_FROZEN)
		ZWriteEnable = true;
		CullMode = CW;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#elif defined(SUPPORT_CHRONORIFT)
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;

#elif !EXPRESSION_EVALUATOR_ENABLED
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
	
#if defined(SUPPORT_FROZEN)
	pass p1
	{
		VertexShader = ARRAY_EXPRESSION_VS(VS_Frozen_Array,
			min(NumJointsPerVertex, 2) * VS_Multiplier_NumJointsPerVertex,
			// Non-array alternative:
			compile VS_VERSION VS_Xenon(true)
		);
		PixelShader = ARRAY_EXPRESSION_PS(PS_Frozen_Array,
			(Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode
			+ HasShadow * PS_Multiplier_NumShadows
			+ HasRecolorColors * PS_Multiplier_RecolorEnable,
			// Non-array alternative:
			compile PS_VERSION PS_Xenon(true)
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
		
		StencilEnable = false;
	}
#endif // SUPPORT_FROZEN
}


#if ENABLE_LOD

// ----------------------------------------------------------------------------
// TECHNIQUE : Default Medium LOD
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
float4 PS_M(VSOutput In, uniform int fogMode, uniform bool hasShadow,
		uniform bool recolorEnable) : COLOR
{
	float2 shroudTexCoord = In.CloudTexCoord_ShroudTexCoord.wz;
	float2 cloudTexCoord = In.CloudTexCoord_ShroudTexCoord.xy;
	float4 color = In.DiffuseColor_Opacity;

#if !defined (SUPPORT_HOLOGRAPHIC)
	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

	float3 cloud = float3(1, 1, 1);
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
#endif

#if !defined(SUPPORT_FROZEN)
	if (hasShadow)
	{
		cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord);
	}

	color.xyz += In.MainLightDiffuseColor * cloud;
	specularColor += In.MainLightSpecularColor * cloud;

#endif

//	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;

	float4 baseTexture = tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

#if defined(SUPPORT_RECOLORING)
	if (recolorEnable)
	{
		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, baseTexture.w);
		baseTexture.w = 1;
	}
#endif //defined(SUPPORT_RECOLORING)

#if defined(SUPPORT_FROZEN)
	color.xyz *= baseTexture.xyz; // Remove diffuse alpha from opacity calculation, uses only vertex alpha
#else
	color *= baseTexture;
#endif

	// Overbrighten	
	color.xyz += color.xyz;
	
#if defined(SUPPORT_FORMATIONPREVIEW)
	color = In.DiffuseColor_Opacity;
#endif	
	
#if defined(SUPPORT_CHRONORIFT)
	float3 Texture0 = tex2D( SAMPLER(ChronoRiftTexture), In.BaseTexCoord.xy * 2);
	float3 Texture1 = tex2D( SAMPLER(ChronoRiftTexture), In.BaseTexCoord.yx * 2);
	color.xyz = Texture0 * Texture1 * 3;
	
	// Compute view direction in world space
	color.xyz += In.EdgeFallOff * float3(0.3,0.6,3.0);
	color.xyz = min(color.xyz,2);
	color.w = In.DiffuseColor_Opacity.w;
#endif // SUPPORT_CHRONORIFT

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

#endif // SUPPORT_HOLOGRAPHIC

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	// Apply shroud
	color.xyz *= tex2D( SAMPLER(ShroudTexture), shroudTexCoord);
#endif

	return color;
}

DEFINE_ARRAY_MULTIPLIER(VS_M_Multiplier_NumJointsPerVertex = 1);

#define VS_M_NumJointsPerVertex \
	compile VS_2_0 VS(0, false, false), \
	compile VS_2_0 VS(1, false, false), \
	compile VS_2_0 VS(2, false, false)

DEFINE_ARRAY_MULTIPLIER(VS_M_Multiplier_Final = VS_M_Multiplier_NumJointsPerVertex * 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] = { VS_M_NumJointsPerVertex };
#endif


DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_FogMode = 1);

#define PS_M_FogMode(hasShadow, houseColorEnable) \
	compile PS_2_0 PS_M(FogMode_Disabled, hasShadow, houseColorEnable), \
	compile PS_2_0 PS_M(FogMode_Opaque, hasShadow, houseColorEnable), \
	compile PS_2_0 PS_M(FogMode_Additive, hasShadow, houseColorEnable)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_NumShadows = PS_M_Multiplier_FogMode * 3);

#define PS_M_NumShadows(houseColorEnable) \
	PS_M_FogMode(0, houseColorEnable), \
	PS_M_FogMode(1, houseColorEnable)

#if defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_RecolorEnable = PS_M_Multiplier_NumShadows * 2);

#define PS_M_RecolorEnable \
	PS_M_NumShadows(false), \
	PS_M_NumShadows(true)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_Final = PS_M_Multiplier_RecolorEnable * 2);

#else // defined(SUPPORT_RECOLORING)

DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_Final = PS_M_Multiplier_NumShadows * 2);
DEFINE_ARRAY_MULTIPLIER(PS_M_Multiplier_RecolorEnable = 0);

#define PS_M_RecolorEnable \
	PS_M_NumShadows(false)

#endif // defined(SUPPORT_RECOLORING)

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] = { PS_M_RecolorEnable };
#endif


technique _Default_M
{
	pass P0
	#if !defined(SUPPORT_CHRONORIFT)
		<
			USE_EXPRESSION_EVALUATOR("BasicW3D")
		>
	#endif
	
	{
		VertexShader = ARRAY_EXPRESSION_VS(VS_M_Array,
			min(NumJointsPerVertex, 2) * VS_M_Multiplier_NumJointsPerVertex,
			// Non-array alternative:
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS(PS_M_Array,
			(Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_M_Multiplier_FogMode
			+ HasShadow * PS_M_Multiplier_NumShadows
			+ HasRecolorColors * PS_M_Multiplier_RecolorEnable,
			// Non-array alternative:
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if defined(SUPPORT_CHRONORIFT)
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;
#elif !EXPRESSION_EVALUATOR_ENABLED
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
// TECHNIQUE : Default Low LOD
// ----------------------------------------------------------------------------
technique _Default_L
{
	pass P0
#if !defined(SUPPORT_CHRONORIFT)
		<
		USE_EXPRESSION_EVALUATOR("BasicW3D")
		>
#endif
	{
		VertexShader = ARRAY_EXPRESSION_VS(VS_M_Array,
			min(NumJointsPerVertex, 2) * VS_M_Multiplier_NumJointsPerVertex,
			// Non-array alternative:
			compile VS_VERSION VS_Xenon()
			);
		PixelShader = ARRAY_EXPRESSION_PS(PS_M_Array,
			FogMode_Disabled * PS_M_Multiplier_FogMode // Low LOD has no fog
			+ HasShadow * PS_M_Multiplier_NumShadows
			+ HasRecolorColors * PS_M_Multiplier_RecolorEnable,
			// Non-array alternative:
			compile PS_VERSION PS_Xenon()
			);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;

#if defined(SUPPORT_CHRONORIFT)
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;
#elif !EXPRESSION_EVALUATOR_ENABLED
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

#endif // if ENABLE_LOD

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

	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);
	
#if defined(TREE_SWAY)
    ApplyTreeSway(InSkin, numJointsPerVertex, worldPosition);
#endif

	//Out.Position = mul(mul(float4(worldPosition, 1), View), Projection);
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	
	Out.Opacity = OpacityOverride * VertexColor.w;
	
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
	
#if !defined(SUPPORT_RECOLORING) && !defined(SUPPORT_FROZEN)// House colored shaders use texture alpha for house color strength instead of opacity
	opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
#endif
	
	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}

	return In.Depth;	
}



#define VSCreateShadowMap_NumJointsPerVertex \
	compile VS_2_0 CreateShadowMapVS(0), \
	compile VS_2_0 CreateShadowMapVS(1), \
	compile VS_2_0 CreateShadowMapVS(2)

DEFINE_ARRAY_MULTIPLIER(VSCreateShadowMap_Multiplier_Final = 3);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif


#define PSCreateShadowMap_AlphaTestEnable \
	compile PS_2_0 CreateShadowMapPS(false), \
	compile PS_2_0 CreateShadowMapPS(true)

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
#if !defined(SUPPORT_HOLOGRAPHIC)

#if defined(SUPPORT_FORMATIONPREVIEW) || defined(SUPPORT_CHRONORIFT)
technique _CreateDepthMap // Don't cast a shadow, but still render to the depth map
#else
technique _CreateShadowMap
#endif

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
#endif //Dont return shadows for Holographic
