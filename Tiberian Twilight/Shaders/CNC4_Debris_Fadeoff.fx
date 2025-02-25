//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for debris that fades off & does not use deferred lighting
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SPECMAP 1
#define SUPPORT_NORMALMAP 1
#define MATERIAL_PARAMS_DEFAULT 1

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

#define EXPRESSION_EVALUATOR_NAME "Objects"

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

//////// ----------------------------------------------------------------------------
//////// Environment map
//////// ----------------------------------------------------------------------------
//////SAMPLER_CUBE_BEGIN( EnvironmentTexture,
//////	string UIWidget = "None";
//////	string SasBindAddress = "Objects.LightSpaceEnvironmentMap";
//////	string ResourceType = "Cube";
//////	)
//////	MinFilter = Linear;
//////	MagFilter = Linear;
//////	MipFilter = Linear;
//////	AddressU = Clamp;
//////	AddressV = Clamp;
//////	AddressW = Clamp;
//////SAMPLER_CUBE_END

#if defined(_3DSMAX_)
	bool AlphaTestEnable = false;
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
	float4 specMap = float4( 1.0f, 1.0f, 1.0f, 0.0f );
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
#if defined(SUPPORT_SPECMAP)
	float3 TangentEyeDir : TEXCOORD5;
#endif
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

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);


#if (defined(SUPPORT_SPECMAP))
	// Build 3x3 tranform from world to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	Out.TangentEyeDir = mul(worldEyeDir, worldToTangentSpace);
#endif
	

 	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
 	Out.Color.xyz /= 2; // Prevent clamping in interpolator
 	Out.Color *= VertexColor;


	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;


	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

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

#if defined(_W3DVIEW_)
	// $todo (wkan) 2009/05/21 - Fix this when we are fixing directional light for w3xviewer
	return baseTexture;
#endif // #if defined(_W3DVIEW_)
	

	float4 specMap = GetSpecMap(texCoord0);
	
	float EmissiveMask = GetEmissiveMask(specMap, texCoord0);

	baseTexture.xyz = GammaToLinear(baseTexture.xyz);
	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;

	float4 color = baseTexture;
	color.xyz *= In.Color.xyz; 

	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);
	float3 diffuseLight = SampleDiffuseLight(screenTexCoord); 
	float3 specularLight = SampleSpecularLight(screenTexCoord); 

	color.xyz += (diffuseLight * diffuse) + (specularLight * SpecularColor * specMap.x);

	color.w *= In.Color.w;
	color.xyz *= TintColor * FactionTintColor;
	//Force transparency
	color.w = min(color.w, 0.98f);

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

#if !defined(EA_PLATFORM_PS3)
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon(false) );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled
			+ 0 * PS_H_Multiplier_StealthEnabled,  
			compile PS_VERSION PS_Xenon(false) );
#else // !defined(EA_PLATFORM_PS3)
		VertexShader = compile VS_VERSION VS_PS3_NoMultiPass();
		PixelShader = compile PS_VERSION PS_PS3_NoMultiPass();
#endif // !defined(EA_PLATFORM_PS3)

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
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
	float2 MacroTexCoord : TEXCOORD5;
	float3 WorldTangentEyeDir : TEXCOORD6;
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
	Out.MacroTexCoord = CalculateMacroTexCoord(worldPosition);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------

float4 PS_M(VSOutput_M In, uniform bool hasShadow, uniform bool recolorEnabled, uniform int isMultiPass, float2 vPos : PIXELLOC) COLORTARGET
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
	float4 HouseColorMap = tex2D( SAMPLER(RecolorTexture), texCoord0);
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

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord_CloudTexCoord.xy ).x;
#endif

	return color;
}

// We only want to do this for the really expensive part. The rest of the shader can be normal.
#undef float4
#undef float3
#undef float2
#undef float


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

#define PS_M_HasShadow(recolorEnabled, isMultiPass) \
	compile PS_3_0 PS_M(false, recolorEnabled, isMultiPass), \
	compile PS_3_0 PS_M(true, recolorEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_RecolorEnabled = PS_M_Multiplier_HasShadow * 2 );
	
#define PS_M_RecolorEnabled(isMultiPass) \
	PS_M_HasShadow(false, isMultiPass), \
	PS_M_HasShadow(true, isMultiPass)

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
			+ HasRecolorColors * PS_M_Multiplier_RecolorEnabled,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

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

// This will save us .5ms on the GPU on a 6800 card. Worth it and there is no visual difference.
#define float4 half4
#define float3 half3
#define float2 half2
#define float  half

float4 PS_L(VSOutput_L In, uniform bool recolorEnabled) COLORTARGET
{
	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;

	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	
#if defined(SUPPORT_RECOLORING)
	if (recolorEnabled)
	{
#if defined(SUPPORT_SPECMAP)
		float4 recolorColor = tex2D( SAMPLER(SpecMap), texCoord0);
#else
		float4 recolorColor = tex2D( SAMPLER(RecolorTexture), texCoord0 );
#endif //defined(SUPPORT_SPECMAP)
		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, recolorColor.z);
	}
#endif //defined(SUPPORT_RECOLORING)

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

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_RecolorEnabled = 1 );
	
#define PS_L_RecolorEnabled \
	compile PS_2_0 PS_L(false), \
	compile PS_2_0 PS_L(true)

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
			HasRecolorColors * PS_L_Multiplier_RecolorEnabled,
			NO_ARRAY_ALTERNATIVE);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	} //defined(SUPPORT_DAMAGETEXTURE)
}


#endif // ENABLE_LOD


