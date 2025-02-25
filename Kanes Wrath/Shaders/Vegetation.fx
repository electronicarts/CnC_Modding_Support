//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for tree rendering
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#include "Common.fxh"

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
};


// ----------------------------------------------------------------------------
// Tree rendering specific data
// ----------------------------------------------------------------------------
static const int MAX_SWAY_TYPES = 10; // Keep in sync with enum in W3DTreeBuffer

float3 SwayOffsets[MAX_SWAY_TYPES + 1] // SwayOffset[0] is always (0, 0, 0). After that the real sway offsets are uploaded.
<
	string SasBindAddress = "Vegetation.SwayOffsets[*]";
	string UIWidget = "None";
>;

bool IsAlphaBlendEnabled
<
//	string SasBindAddress = "Vegetation.IsAlphaBlendEnabled";
	string UIWidget = "None";
> = true;


SAMPLER_2D_BEGIN( BaseSampler,
	string SasBindAddress = "Vegetation.BaseTexture";
	string UIName = "Base Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END


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
// FOG
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
float4x3 ViewI : ViewInverse;
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: VS
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
	float2 CloudTexCoord : TEXCOORD2;
	float4 ShadowMapTexCoord : TEXCOORD3;
	float3 MainLightColor : TEXCOORD4;
	float Fog : COLOR1;
};

VSOutput VS(float3 Position : POSITION, float3 Normal : NORMAL,
		float2 TexCoord0 : TEXCOORD0, float2 SwayType_TreeLocationZ : TEXCOORD1,
		float4 VertexColor: COLOR0, uniform bool hasCloud)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;

	// Offset the vertex positions of trees to simulate swaying in the wind.
	float swayType = SwayType_TreeLocationZ.x;
	float treeLocationZ = SwayType_TreeLocationZ.y;
	Position += (Position.z - treeLocationZ) * SwayOffsets[swayType];

	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	float3 worldPosition = mul(float4(Position, 1), World);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	
	// Compute light
	float3 diffuseLight = 0;
	
	// Compute directional lights
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		// Trees have "double-sided" lighting, ie. absolute value of dot product rather than clamping with 0
		float lighting = abs(dot(worldNormal, DirectionalLight[i].Direction));

		if (i == 0)
		{
			float3 lightColor = DirectionalLight[i].Color;
			if (!hasCloud)
			{
				lightColor *= NoCloudMultiplier;
			}
		
			Out.MainLightColor = lightColor * lighting * VertexColor.xyz / 2;
		}
		else
		{
			diffuseLight += DirectionalLight[i].Color * lighting;
		}
	}

	// Compute point lights
	for (int i = 0; i < NumPointLights; i++)
	{
		float3 direction = PointLight[i].Position - worldPosition;
		float lightDistance = length(direction);
		direction /= lightDistance;

		// Trees have "double-sided" lighting, ie. absolute value of dot product rather than clamping with 0
		float lighting = abs(dot(worldNormal, direction));
		
		float attenuation = CalculatePointLightAttenuation(PointLight[i], lightDistance);
		
		diffuseLight += PointLight[i].Color * attenuation * lighting;
	}
	
	float3 diffuseColor = (AmbientLightColor + diffuseLight) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, VertexColor.w);
	Out.BaseTexCoord = TexCoord0;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PS
// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int numShadows) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;
	
	float3 cloud = tex2D( SAMPLER(CloudTexture), In.CloudTexCoord);
	if (numShadows >= 1)
	{
		cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo);
	}
	
	color.xyz += In.MainLightColor * cloud;
	color *= tex2D( SAMPLER(BaseSampler), In.BaseTexCoord);
	color.xyz += color.xyz;
	color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	color *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In ) : COLOR
{
	return PS( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default
// ----------------------------------------------------------------------------
#define PS_NumShadows \
	compile ps_2_0 PS(0), \
	compile ps_2_0 PS(1),

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_NumShadows
};
#endif

technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Vegetation")
	>
	{
		VertexShader = compile vs_1_1 VS(true);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			min( NumShadows, 1 ),
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaBlendEnable = ( IsAlphaBlendEnabled );
#endif

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Handled by pixel shader
#endif
	}  
}

// ----------------------------------------------------------------------------
// SHADER: PS_L
// ----------------------------------------------------------------------------
float4 PS_L(VSOutput In, uniform bool fogEnabled) : COLOR
{
	float4 color = In.DiffuseColor_Opacity;
	color *= tex2D( SAMPLER(BaseSampler), In.BaseTexCoord);
	color.xyz += color.xyz * 0.999;
	if (fogEnabled)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}
	color *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
// SHADER: PS_L_Xenon
// ----------------------------------------------------------------------------
float4 PS_L_Xenon( VSOutput In ) : COLOR
{
	return PS_L( In, Fog.IsEnabled );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: LowQuality
// ----------------------------------------------------------------------------
#define PS_L_FogEnabled \
	compile ps_1_1 PS_L(false), \
	compile ps_1_1 PS_L(true)

DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_L_Array[PS_L_Multiplier_Final] =
{
	PS_L_FogEnabled
};
#endif

#if ENABLE_LOD

technique Default_L
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Vegetation_L")
	>
	{
		VertexShader = compile vs_1_1 VS(false);
		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
			Fog.IsEnabled,
			compile PS_VERSION PS_L_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		AlphaBlendEnable = ( IsAlphaBlendEnabled );
#endif

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60; // WW3D magic number
	}  
}

#endif // #if ENABLE_LOD

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
VSOutput_CreateShadowMap CreateShadowMapVS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0,
		float2 SwayType_TreeLocationZ : TEXCOORD1, float4 VertexColor: COLOR0)
{
	VSOutput_CreateShadowMap Out;

	// Offset the vertex positions of trees to simulate swaying in the wind.
	float swayType = SwayType_TreeLocationZ.x;
	float treeLocationZ = SwayType_TreeLocationZ.y;
	Position += (Position.z - treeLocationZ) * SwayOffsets[swayType];
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.Opacity = VertexColor.w;
	Out.BaseTexCoord = TexCoord0;
	Out.Depth = Out.Position.z / Out.Position.w;
	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In) : COLOR
{
	float opacity = In.Opacity;
	opacity *= tex2D( SAMPLER(BaseSampler), In.BaseTexCoord).w;

	// Simulate alpha testing for floating point render target
	clip(opacity - ((float)0x60 / 255));
	
	return In.Depth;
}


// ----------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW CreateShadowMapVS();
		PixelShader = compile PS_VERSION_HIGH CreateShadowMapPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		AlphaBlendEnable = false;
		AlphaTestEnable = false; // Unfortunately not supported with floating point render targets
	}  
}