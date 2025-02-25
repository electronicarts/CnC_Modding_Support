//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// FX Shader for vehicles and structures. Infantry should use Infantry.fx
//////////////////////////////////////////////////////////////////////////////


#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define FIRSTPASS 0
#define FROZENPASS 1
#define TESLAPASS 2

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "ShadowMap.fxh"
#include "MacroTexture.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);


	int MaxLocalLights = 8;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

DECLARE_MAPPING_TEXCOORD(0)
DECLARE_MAPPING_VERTEXCOLOR(1, 2)

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


SAMPLER_2D_BEGIN( MembraneTexture,
		string UIWidget = "None";
		string SasBindAddress = "WW3D.Membrane_NOD_Red";
		)
		MipFilter = Linear;
		MinFilter = Linear;
		MagFilter = Linear;
		AddressU = WRAP;
		AddressV = WRAP;
SAMPLER_2D_END


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


// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------
//#if defined(SUPPORT_RECOLORING)
//SAMPLER_2D_BEGIN( RecolorTexture,
//	string UIName = "House Color Tex";
//	)
//	MinFilter = MinFilterBest;
//	MagFilter = MagFilterBest;
//	MipFilter = MipFilterBest;
//	AddressU = Wrap;
//	AddressV = Wrap;
//SAMPLER_2D_END	
//#endif 

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

const bool AlphaTestEnable = false;



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
	float4 Color : COLOR0;
	float3 WorldNormal : TEXCOORD7;
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

	Out.WorldNormal = worldNormal; //for membrane test...use packed version from matrix for real version

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

#if !defined(SUPPORT_ALTMAPPING)

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
#endif // SUPPORT_ALTMAPPING

	Out.WorldPosition = worldPosition;

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
			float2 vPos : PIXELLOC, uniform int isMultiPass) COLORTARGET
{	
	//USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	

	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
	//float2 shroudTexCoord = In.ShroudTexCoord_CloudTexCoord.xy;
	//float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;
	float3 worldEyeDir = normalize(GetEyePosition() - In.WorldPosition);


	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	baseTexture.xyz = GammaToLinear(baseTexture.xyz);



////	// MAKE THIS WORK ....
////	// Primary House color
////#if defined(SUPPORT_RECOLORING)
////	if(recolorEnabled)
////	{
////		float4 recolorColor = tex2D( SAMPLER(SpecMap), texCoord0);		
////		
////		float3 RecolorPColor;
////#if defined(_3DSMAX_)
////		RecolorPColor = RecolorColor.xyz;
////#else		
////		RecolorPColor = RecolorColor;
////#endif
////		//Commenting out Primary House Color for now as they need this feature for the Video Shoot. rravin
////		baseTexture.xyz = lerp(baseTexture.xyz, baseTexture.xyz * RecolorPColor.xyz * 2 , recolorColor.z); 
////	}
////#endif
//////baseTexture.xyz = RecolorColor[0];
//////return baseTexture;
//////END HOUSECOLOR



	//USING NORMAL MAP
	//NORMAL MAP 
	// Get bump map normal
	float3 bumpNormal;
	bumpNormal = (float3)tex2D(SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;	
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	// Bring bump normal into world space
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	bumpNormal = mul(bumpNormal, TangentToViewSpace);
	bumpNormal = normalize(bumpNormal);


	//Using WorldNormal
	//float EyeDotNorm = dot(normalize(worldEyeDir), normalize(In.WorldNormal));
	//Using NormalMap 
	float EyeDotNorm = dot(worldEyeDir, bumpNormal);

	float4 MembraneTex = tex2D( SAMPLER(MembraneTexture), float2(EyeDotNorm, 0.0f));


	//KEEP OFF UNTIL CAN TEST W/ TEAMS -- CURRENTLY NOT ABLE TO RUN
	//Test HOUSECOLOR 
	float intensity = dot(MembraneTex, float3(1.0f, 1.0f, 1.0f));
	float3 HouseC = float3(0.0f, 0.0f, 0.8f);
	//House Color needs to be either orange, white, or lerped between based on color
	if (intensity < 0.3f)
	{
		HouseC *= intensity;
	}
	else
	{
		float lerpamt = (intensity - 0.3f) / 0.53f;  //scale 0.3f - 0.83f to 0.0f - 1.0f
		HouseC = lerp(HouseC, float3(1.0f,1.0f,1.0f), lerpamt);
	}
	MembraneTex.xyz = HouseC.xyz;
	//end Test HOUSECOLOR
	
	

	//hack -- need to get less color across mid-ranges
	if (EyeDotNorm < 0.75f && EyeDotNorm > lerp(0.35f, 0.4f, (sin(Time * 4) * 2 - 1)))    //0.3f)  //was lerp to 0.4
	{
		MembraneTex.xyz = 0.0f;
	}

	//SHUT OFF HIGHLIGHTS/WHITES PER DESIGNER REQUEST
	if (EyeDotNorm > 0.75f)
	{
		MembraneTex.xyz = 0.0f;
	}

	//adjust gb out of baseTexture
	//NOTE -- DESIGNERS DIDN'T LIKE RED AREAS FROM BASETEXTURE, SO NOW DARKENING ALL COLOR CHANNELS
	baseTexture.rgb *= 0.5f;

	float4 memcolor = lerp(MembraneTex, baseTexture, 0.3f); 

	//Transparency setting -- move this to user param
	memcolor.w = 0.5f;
	
	return CorrectForFrameBufferGamma(memcolor);
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

// Helper functions for console
VSOutput_H VS_NoMultiPass(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3)
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2)
#endif
)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), false);
}

float4 PS_NoMultiPass( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
{
	return PS_H( In, HasShadow, HasRecolorColors, vPos, false);
}

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{

		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_NoMultiPass() );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled,
			compile PS_VERSION PS_NoMultiPass() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = true;

		//test w/ transparency
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
			
	}

}



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
#if defined(SUPPORT_JAPANBUILDUP)
	// Get Buildup Mask
	float Mask = smoothstep(.4,.51,In.TexCoord0.y + (In.Opacity * 1.2) - .65);	
	clip(Mask - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
#else
	float opacity = tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;
	
#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= damagedTexture * (1 - In.Opacity);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= lerp(damagedTexture, 1.0, In.Opacity);
#elif !defined(SUPPORT_JAPANBUILDUP)
	opacity *= In.Opacity;
#endif

	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}
#endif //SUPPORT_JAPANBUILDUP

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
