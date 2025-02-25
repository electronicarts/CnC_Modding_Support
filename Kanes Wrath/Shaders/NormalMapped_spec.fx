//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// DEPRECATED SHADER
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
//#define PER_PIXEL_POINT_LIGHT
#include "Common.fxh"

//
//
// DEPRECATED SHADER
//
//
#if !defined ( _3DSMAX_ )
#include "Simple.fx"
#else

//
// Skinning
//

static const int MaxSkinningBonesPerVertex = 1;

#include "Skinning.fxh"



//
// Light sources
//

float3 AmbientLightColor : Ambient = float3(0.1, 0.1, 0.1);


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
int NumPointLightsUsed
<
	string SasBindAddress = "Sas.NumPointLights";
	string UIWidget = "None";
> = 0;

SasPointLight PointLight[NumPointLights]
<
	string SasBindAddress = "Sas.PointLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_POINT_LIGHT_DISABLED
};

float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
>;

//
// Shadow mapping
//

int NumShadows
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.NumShadows";
> = 0;

texture ShadowMap
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].ShadowMap";
>;

sampler2D ShadowMapSampler = shadow_sampler(ShadowMap);

ShadowSetup ShadowInfo
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0]";
>;


CloudSetup Cloud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Cloud";
#endif
> = DEFAULT_CLOUD;

texture CloudTexture
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Cloud.Texture";
#endif
	string ResourceName = "ShaderPreviewCloud.dds";
>;

sampler2D CloudSampler = sampler_state
{
	Texture = <CloudTexture>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};



// Textures
texture DiffuseTexture
<
	string UIName = "Diffuse Texture";
//	string ResourceName = "test_shader_GBBarracks_dif.tga"; 
>;

sampler2D DiffuseSampler = sampler_state
{
	Texture = <DiffuseTexture>;
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
};

texture NormalMap
< 
	string UIName = "Normal Texture";
//	string ResourceName = "test_shader_GBBarracks_nrm.tga"; 
>;

sampler2D NormalSampler = sampler_state 
{
	Texture = <NormalMap>;
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
};

texture SpecMap
< 
	string UIName = "Spec Texture";
//	string ResourceName = "test_shader_GBBarracks_nrm.tga"; 
>;

sampler2D SpecSampler = sampler_state 
{
	Texture = <SpecMap>;
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
};



// Editable parameters
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

float SpecMult
<
	string UIName = "Specular Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.1f;
> = 10.0;


bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;



//
// Shroud
//

ShroudSetup Shroud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud";
#endif
> = DEFAULT_SHROUD;

texture ShroudTexture
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud.Texture";
#endif
>;

sampler2D ShroudSampler = sampler_state
{
	Texture = <ShroudTexture>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

int ObjectShroudStatus
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud.ObjectShroudStatus";
#endif
> = OBJECTSHROUD_INVALID;



//
// Fog
//

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




// Transformations (world transformations are in skinning header)
half4x4 WorldIT : WorldInverseTranspose < string UIWidget="None"; >;
float4x4 View : View;
float4x3 ViewI : ViewInverse;
float4x4 Projection : Projection;

float Time : Time;





//
// Technique: Default_L
// Low LOD technique. Doesn't do any normal mapping.
//

struct VSOutput_L
{
	float4 Position : POSITION;
	float4 Color_Opacity : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float Fog : FOG;
};

VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_L Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame_L(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
	
	//if (doSkinning)
	//	VertexColor *= float4(1, 0, 0, 1);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// Compute directional lights
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
	
	Out.Color_Opacity.xyz = AmbientLightColor * AmbientColor + diffuseLight * DiffuseColor;
	
	Out.Color_Opacity.xyz /= 2; // Allow overbright light through, pixel shader will mulitply by two again
	
	// Compute opacity
	Out.Color_Opacity.w = OpacityOverride;
	
	// Pass through texture coordinates
	Out.BaseTexCoord.xy = TexCoord.xy;

	// Calculate shroud texture coordinate
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	return Out;
}

float4 PS_L(VSOutput_L In, uniform bool applyShroud) : COLOR
{
	// Get diffuse color
	float4 baseTexture = tex2D(DiffuseSampler, In.BaseTexCoord);

	float3 color;
	color = baseTexture.xyz * In.Color_Opacity.xyz;
	
	color.xyz += color.xyz;
	
	if (applyShroud)
	{
		color.xyz *= tex2D(ShroudSampler, In.ShroudTexCoord);
	}

	//color = float4(bumpNormal, 0) * 0.5 + 0.5;
	//color.xyz = color * In.LightVector + 0.2;
	
	return float4(color, baseTexture.w * In.Color_Opacity.w);
}



#define VS_L_NumJointsPerVertex \
	compile vs_1_1 VS_L(0), \
	compile vs_1_1 VS_L(1)

static const int VS_L_Multiplier_Final = 2;

vertexshader VS_L_Array[VS_L_Multiplier_Final] =
{
	VS_L_NumJointsPerVertex
};


#define PS_L_ApplyShroud \
	compile ps_1_1 PS_L(false), \
	compile ps_1_1 PS_L(true)

static const int PS_L_Multiplier_Final = 2;

pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_ApplyShroud
};



// Technique definition
technique Default_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass p0
	{
		VertexShader = ( VS_L_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = ( PS_L_Array[
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR)
		] );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = (Fog.IsEnabled);
		FogColor = (Fog.Color);
#endif
	}
}


//
// Technique: Default_M
//

struct VSOutput_M
{
	float4 Position : POSITION;
	float3 Color : TEXCOORD4; // Allows strong overbrightness
	float2 TexCoord0 : TEXCOORD0;
	float3 LightVector : TEXCOORD2;
	float3 HalfEyeLightVector : TEXCOORD3;
	float2 ShroudTexCoord : TEXCOORD5;
	float Fog : FOG;
};

VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput_M Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
	
	//if (doSkinning)
	//	VertexColor *= float4(1, 0, 0, 1);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);
	
	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	// Compute lighting direction in tangent space
	float3 worldLightDir1 = DirectionalLight[NumDirectionalLights > 1 ? 1 : 0].Direction;
	Out.LightVector = mul(worldLightDir1, worldToTangentSpace);

	// Compute half angle direction between light and view direction in tangent space
	Out.HalfEyeLightVector = normalize(mul(DirectionalLight[0].Direction + worldEyeDir, worldToTangentSpace));

	float3 diffuseLight = 0;
	if (NumDirectionalLights > 1)
	{
		// Compute light 0 and 2 diffuse per vertex, light 0 specular and light 1 diffuse will be done in pixel shader
		diffuseLight += DirectionalLight[0].Color * max(0, dot(worldNormal, DirectionalLight[0].Direction));
		for (int i = 2; i < NumDirectionalLights; i++)
		{
			diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
		}
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
	
	Out.Color = AmbientLightColor * AmbientColor + diffuseLight * DiffuseColor;
	
	// Pass through texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0 = TexCoord.xy;

	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	return Out;
}

float4 PS_M(VSOutput_M In, uniform bool applyShroud) : COLOR
{
	// Get diffuse color
	float4 baseTexture = tex2D(DiffuseSampler, In.TexCoord0);
	float3 diffuse = baseTexture.xyz;
	
	//mult spec by specmap
	float4 specmap = tex2D(SpecSampler, In.TexCoord0);
	float3 spectex = specmap.xyz;

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D(NormalSampler, In.TexCoord0) * 2.0 - 1.0;
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	//bumpNormal = float3(0, 0, 1);

	// Compure lighting
	float4 lighting = lit(dot(bumpNormal, In.LightVector),
		dot(bumpNormal, In.HalfEyeLightVector), SpecularExponent);
	
	float4 color;	
	color.xyz = In.Color * diffuse
		+ DirectionalLight[NumDirectionalLights > 1 ? 1 : 0].Color * diffuse * DiffuseColor * lighting.y
		+ DirectionalLight[0].Color * SpecularColor   * lighting.z;
		
	//color.xyz *= spectex;	

	if (applyShroud)
	{
		color.xyz *= tex2D(ShroudSampler, In.ShroudTexCoord);
	}
	
	color.a = baseTexture.w * OpacityOverride;
	
	//color = float4(bumpNormal, 0) * 0.5 + 0.5;
	//color.xyz = In.LightVector * 0.5 + 0.5;
	
	return color;
}



#define VS_M_NumJointsPerVertex \
	compile vs_2_0 VS_M(0), \
	compile vs_2_0 VS_M(1)

static const int VS_M_Multiplier_Final = 2;

vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_NumJointsPerVertex
};


#define PS_M_ApplyShroud \
	compile ps_2_0 PS_M(false), \
	compile ps_2_0 PS_M(true)

static const int PS_M_Multiplier_Final = 2;

pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_ApplyShroud
};


// Technique definition
technique Default_M
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	{
		VertexShader = ( VS_M_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = ( PS_M_Array[
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR)
		] );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = (Fog.IsEnabled);
		FogColor = (Fog.Color);
#endif
	}
}


//
// Technique: Default
//

struct VSOutput {
	float4 Position : POSITION;
	float4 TexCoord0_CloudTexCoord : TEXCOORD0;
	float4 LightVector[NumDirectionalLights] : TEXCOORD1;
	float3 HalfEyeLightVector[NumDirectionalLights] : TEXCOORD4;
#ifdef PER_PIXEL_POINT_LIGHT
	//float3 WorldPosition : TEXCOORD7;
	float3 WorldNormal : COLOR1;
#endif
	float4 ShadowMapTexCoord : TEXCOORD7;
	float4 Color : COLOR0;
	float Fog : FOG;
};

VSOutput VS(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
	
	//if (doSkinning)
	//	VertexColor *= float4(1, 0, 0, 1);

	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - worldPosition);

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));

	for (int i = 0; i < NumDirectionalLights; i++)
	{
		// Compute lighting direction in tangent space
		Out.LightVector[i] = float4(mul(DirectionalLight[i].Direction, worldToTangentSpace), 0);

		// Compute half direction between view and light direction in tangent space
		Out.HalfEyeLightVector[i] = normalize(mul(DirectionalLight[i].Direction + worldEyeDir, worldToTangentSpace));
	}

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

#ifdef PER_PIXEL_POINT_LIGHT
	Out.WorldNormal = worldNormal * 0.5 + 0.5;
	//Out.WorldPosition = worldPosition;
#else
	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		Out.Color.xyz += PointLight[i].Color * attenuation * max(0, dot(worldNormal, direction));
	}
#endif

	Out.Color /= 2; // Prevent clamping in interpolator

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_CloudTexCoord.xy = TexCoord.xy;

	// Calculate shroud texture coordinates
	//Out.TexCoord0_ShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, worldPosition);
	
	// Hack cloud tex coord into final components of light vectors
	float2 cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	Out.TexCoord0_CloudTexCoord.zw = cloudTexCoord.yx;
	//Out.LightVector[0].w = cloudTexCoord.x;
	//Out.LightVector[1].w = cloudTexCoord.y;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	
	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	

	return Out;
}

float4 PS(VSOutput In, uniform int numShadows, uniform bool doPointLights,
		uniform bool applyShroud, uniform bool fogEnabled) : COLOR
{
	float2 texCoord0 = In.TexCoord0_CloudTexCoord.xy;
	//float2 shroudTexCoord = In.TexCoord0_ShroudTexCoord.zw;
	//float2 cloudTexCoord = float2(In.LightVector[0].w, In.LightVector[1].w);
	float2 cloudTexCoord = In.TexCoord0_CloudTexCoord.wz;
	
	// Get diffuse color
	float4 baseTexture = tex2D(DiffuseSampler, texCoord0);
	float3 diffuse = baseTexture.xyz * DiffuseColor;

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D(NormalSampler, texCoord0) * 2.0 - 1.0;
	// Scale normal to increase/decrease bump effect
	bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);
	//bumpNormal = float3(0, 0, 1);
	

	
	
	//mult spec by specmap
	float4 specTexture = tex2D(SpecSampler, texCoord0);
	float3 spectex = specTexture.xyz;
	SpecularColor = float3(SpecMult * SpecularColor.x ,SpecMult * SpecularColor.y,SpecMult * SpecularColor.z) * spectex;
	
	

	float4 color = In.Color * baseTexture * 2;

	for (int i = 0; i < NumDirectionalLights; i++)
	{
		// Compute lighting
		float4 lighting = lit(dot(bumpNormal, /*normalize*/(In.LightVector[i].xyz)),
		dot(bumpNormal, In.HalfEyeLightVector[i]), SpecularExponent);
						
		if (i == 0)
		{
			if (numShadows >= 1)
			{
				lighting.yz *= shadow(ShadowMapSampler, In.ShadowMapTexCoord, ShadowInfo);
			}
	
			float3 cloud = float3(1, 1, 1);			
#if defined(_WW3D_) && !defined(_W3DVIEW_)
			cloud = tex2D(CloudSampler, cloudTexCoord);
#endif

			color.xyz += DirectionalLight[0].Color * cloud
				* (diffuse * lighting.y + SpecularColor * lighting.z);
		}
		else
		{
			color.xyz += DirectionalLight[i].Color * (diffuse * lighting.y);
		}
	}

	/*
	// Moved to outside of fixed function fog due to instruction count limit
	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}*/

	/*
	// Moved to pass 1 due to instruction count limit...
	if (applyShroud)
	{
		color.xyz *= tex2D(ShroudSampler, shroudTexCoord);
	}*/
	
	//color = float4(bumpNormal, 0) * 0.5 + 0.5;
	//color.xyz = In.WorldNormal * 0.5 + 0.5;

	return color;
	//return float4(0.2f,0.2f,0.2f,1);
}



struct VSOutput_1 {
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
};

VSOutput_1 VS_1(VSInputSkinningOneBoneTangentFrame InSkin, float2 TexCoord : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	VSOutput_1 Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
	
	// transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));
	
	// Pass through texture coordinates
	Out.TexCoord0 = TexCoord;

	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

float4 PS_1(VSOutput_1 In, uniform bool applyShroud) : COLOR
{
	float4 color = 1;

	color.w = OpacityOverride * tex2D(DiffuseSampler, In.TexCoord0).w;

	if (applyShroud)
	{
		color.xyz *= tex2D(ShroudSampler, In.ShroudTexCoord);
	}

	return color;
}



#define VS_NumJointsPerVertex \
	compile vs_2_0 VS(0), \
	compile vs_2_0 VS(1)

static const int VS_Multiplier_Final = 2;

vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};


#define PS_NumShadows(doPointLights, applyShroud, fogEnabled) \
	compile ps_2_0 PS(0, doPointLights, applyShroud, fogEnabled), \
	compile ps_2_0 PS(1, doPointLights, applyShroud, fogEnabled)

static const int PS_Multiplier_DoPointLights = 2;

#define PS_DoPointLights(applyShroud, fogEnabled) \
	PS_NumShadows(false, applyShroud, fogEnabled), \
	PS_NumShadows(true, applyShroud, fogEnabled)

static const int PS_Multiplier_ApplyShroud = PS_Multiplier_DoPointLights * 2;

#define PS_ApplyShroud(fogEnabled) \
	PS_DoPointLights(false, fogEnabled), \
	PS_DoPointLights(true, fogEnabled)

static const int PS_Multiplier_FogEnabled = PS_Multiplier_ApplyShroud * 2;

#define PS_FogEnabled \
	PS_ApplyShroud(false), \
	PS_ApplyShroud(true)

static const int PS_Multiplier_Final = PS_Multiplier_FogEnabled * 2;

pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_FogEnabled
};


#define VS1_NumJointsPerVertex \
	compile vs_2_0 VS_1(0), \
	compile vs_2_0 VS_1(1)

static const int VS1_Multiplier_Final = 2;

vertexshader VS1_Array[VS1_Multiplier_Final] =
{
	VS1_NumJointsPerVertex
};


#define PS1_ApplyShroud \
	compile ps_2_0 PS_1(false), \
	compile ps_2_0 PS_1(true)

static const int PS1_Multiplier_Final = 2;

pixelshader PS1_Array[PS1_Multiplier_Final] =
{
	PS1_ApplyShroud
};



// Technique definition
technique Default
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	{
		VertexShader = ( VS_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = ( PS_Array[
			min(NumShadows, 1)
			+ (NumPointLightsUsed > 0) * PS_Multiplier_DoPointLights
			+ (ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR) * PS_Multiplier_ApplyShroud
			+ Fog.IsEnabled * PS_Multiplier_FogEnabled
		] );
		//PixelShader = compile ps_2_0 PS(1, true, true, true);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = (Fog.IsEnabled);
		FogColor = (Fog.Color);
#endif
	}
	
	pass p1
	{
		VertexShader = ( VS1_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = ( PS1_Array[
			(ObjectShroudStatus == OBJECTSHROUD_PARTIAL_CLEAR)
		] );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}



//
// Technique _CreateShadowMap
//

struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Depth : TEXCOORD0;
};

VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Transform position to projection space
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));
	
	Out.Depth = Out.Position.z / Out.Position.w;
	
	return Out;
}

float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	return In.Depth;
}


#define VSCreateShadowMap_NumJointsPerVertex \
	compile vs_1_1 CreateShadowMapVS(0), \
	compile vs_1_1 CreateShadowMapVS(1)

static const int VSCreateShadowMap_Multiplier_Final = 2;

vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};

technique _CreateShadowMap
{
	pass p0
	{
		VertexShader = ( VSCreateShadowMap_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = compile ps_2_0 CreateShadowMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

//struct used for viewing world space normals
struct VSWorldNormOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord : TEXCOORD0;
	float3x3 TangentToViewSpace : TEXCOORD1;		
};

VSWorldNormOutput VS_WorldNormShader(
		VSInputSkinningOneBoneTangentFrame InSkin,
		uniform int numJointsPerVertex,
		float2 TexCoord : TEXCOORD0	)
{
	VSWorldNormOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);
		
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));
	Out.Color.xyz = (worldNormal / 2) + 0.5f; //transform the normal		
	Out.Color.w = OpacityOverride;
	
	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = (float3x3(-worldBinormal, -worldTangent, worldNormal));
	Out.TangentToViewSpace = mul(tangentToWorldSpace, (float3x3)View);
	Out.TexCoord = TexCoord;
		
	return Out;
}

float4 PS_WorldNormColor(VSWorldNormOutput In) : COLOR
{
	float opacity = In.Color.w;

	float2 texcoord0 = In.TexCoord.xy;
	opacity *= tex2D(DiffuseSampler, In.TexCoord.xy).w;
	
	//The normal map is stored [0...1] so we have to map it back into the [-1...1] range
	float3 Normal = (2 * (tex2D(NormalSampler, texcoord0))) - 1.0f;
	float3 colorNormal = mul(Normal, In.TangentToViewSpace);
	colorNormal = (colorNormal / 2) + 0.5f; //shift back to [0...1]
	
	return float4(colorNormal, opacity);
}

static const int VS_Multiplier_NumJointsPerVertex = 1;
#define VS_WorldNormNumJointsPerVertex \
	compile vs_2_0 VS_WorldNormShader(0), \
	compile vs_2_0 VS_WorldNormShader(1)

vertexshader VS_WorldNormArray[2] =
{
	VS_WorldNormNumJointsPerVertex
};
technique _RenderWorldNormals
{
	pass p0 
	{		
		VertexShader = ( VS_WorldNormArray[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = compile ps_2_0 PS_WorldNormColor();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = (Fog.IsEnabled);
		FogColor = (Fog.Color);
#endif		
	}
}

float4 PS_FlatColor(VSOutput In) : COLOR
{
	float opacity = OpacityOverride;

	opacity *= tex2D(DiffuseSampler, In.TexCoord0_CloudTexCoord.xy).w;
	return float4(FlatColorOverride.xyz, opacity); 
}

// Technique definition
technique _DrawFlatColor
<
	int MaxSkinningBones = MaxSkinningBones;
>
{
	pass p0
	{
		VertexShader = ( VS_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = compile ps_1_1 PS_FlatColor();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = ( OpacityOverride < 0.99);
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = (Fog.IsEnabled);
		FogColor = (Fog.Color);
#endif
	}
	
	pass p1
	{
		VertexShader = ( VS1_Array[
			min(NumJointsPerVertex, 1)
		] );
		PixelShader = compile ps_1_1 PS_FlatColor();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = ( AlphaTestEnable );
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}


#endif //EA_PLATFORM_XENON