//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple unlit rendering
//////////////////////////////////////////////////////////////////////////////
#include "Common.fxh"


SAMPLER_2D_BEGIN( BaseSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.BaseTexture";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( GlowSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.BaseTexture";
	)
	AddressU = Wrap;
	AddressV = Wrap;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( MaskSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.MaskTexture";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( MetaGlowSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.BaseTexture";
	)
	AddressU = Wrap;
	AddressV = Wrap;
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( MetaMaskSampler,
	string UIWidget = "None";
	string SasBindAddress = "Decal.MaskTexture";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
// FOG
// ----------------------------------------------------------------------------
bool FogEnable
<
	string UIName = "Fog Enable";
> = true;

WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;


// ----------------------------------------------------------------------------
// Light sources (only used by Tiberium decals)
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

float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 World : World;
float4x3 ViewI : ViewInverse;
float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = color;
	Out.BaseTexCoord = TexCoord0;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
	color *= tex2D( SAMPLER(BaseSampler), In.BaseTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
float4 MaskPS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
	color *= tex2D( SAMPLER(MaskSampler), In.BaseTexCoord);

	return color;
}


// ----------------------------------------------------------------------------
// Tiberium shader
// ----------------------------------------------------------------------------
struct VSOutput_Tiberium
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float  Fog : COLOR1;
	float2 MaskTexCoord : TEXCOORD0;
	float2 GlowTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
// Tiberium shader
// ----------------------------------------------------------------------------
struct VSOutput_TiberiumMetagame
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float  Fog : COLOR1;
	float2 MaskTexCoord : TEXCOORD0;
	float2 GlowTexCoord : TEXCOORD1;
	float2 GlowTexCoord01 : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_Tiberium TiberiumVS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 VertexColor : COLOR0)
{
	VSOutput_Tiberium Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);

	float3 worldPosition = mul(float4(Position, 1), World);
	float3 worldNormal = float3(0, 0, 1); // Close enough

	// Material parameters. Values equivalent to DefaultW3D.fx setup in 3DSMax
	float3 ColorAmbient = float3(1.0, 1.0, 1.0);

//	float3 ColorDiffuse = float3(0.0, 0.3, 0.04);
	float3 ColorDiffuse = float3(1.0, 1.0, 1.0);
	float3 ColorSpecular = float3(0.45, 1.0, 0.70) * 0.75;
	float Shininess = 25.0;
	float3 ColorEmissive = float3(0.0, 0.0, 0.0);
	
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
	
	float3 color = ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse + specularLight * ColorSpecular;

	Out.DiffuseColor = float4(color, 1) * VertexColor;	
	Out.MaskTexCoord = TexCoord0;
	float3 CP = ViewI[3];
	Out.Fog = CalculateFog(Fog, worldPosition, CP);

	// The glow texture needs to be sampled with polar coordinates, u = angle, v = radius
	float2 relativeTexCoord = TexCoord0 - float2(0.5, 0.5);
	Out.GlowTexCoord.x = atan2(relativeTexCoord.x, relativeTexCoord.y) / 3.14159 * 0.5;
	Out.GlowTexCoord.y = length(relativeTexCoord) - Time * 0.03;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 TiberiumPS(VSOutput_Tiberium In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;		// Get my color
	// Multiply by the main color
	color.xyzw *= tex2D( SAMPLER(MetaMaskSampler), In.MaskTexCoord);
	color.w *= 2;		// Double the alpha
	color.xyz += tex2D( SAMPLER(MetaGlowSampler), In.GlowTexCoord);
	color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	return color;
}

// ----------------------------------------------------------------------------
VSOutput_TiberiumMetagame TiberiumVS_Metagame(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 VertexColor : COLOR0)
{
	VSOutput_TiberiumMetagame Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);

	float3 worldPosition = mul(float4(Position, 1), World);
	float3 worldNormal = float3(0, 0, 1); // Close enough

	// Material parameters. Values equivalent to DefaultW3D.fx setup in 3DSMax
	float3 ColorAmbient = float3(1.0, 1.0, 1.0);

//	float3 ColorDiffuse = float3(0.0, 0.3, 0.04);
	float3 ColorDiffuse = float3(1.0, 1.0, 1.0);
	float3 ColorSpecular = float3(0.45, 1.0, 0.70) * 0.75;
	float Shininess = 25.0;
	float3 ColorEmissive = float3(0.0, 0.0, 0.0);
	
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
	
	float3 color = ColorEmissive + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse + specularLight * ColorSpecular;

	Out.DiffuseColor = float4(color, 1) * VertexColor;	
	Out.MaskTexCoord = TexCoord0;
	float3 CP = ViewI[3];
	Out.Fog = CalculateFog(Fog, worldPosition, CP);

	// The glow texture needs to be sampled with polar coordinates, u = angle, v = radius
	float2 relativeTexCoord = (TexCoord0.xy * 0.1);
	//worldPosition.xyz *= 0.001;
	relativeTexCoord.xy = (worldPosition.xy * float2(0.003, 0.003)); // change the value worldposition is multiplied by to modify the scale of the texture.  smaller numbers scale up the texture
	Out.GlowTexCoord = relativeTexCoord + (Time * 0.004);              // change the value time is scaled by to adjust how fast the texture moves.  smaller numbers mean slower movement     
	Out.GlowTexCoord01 = relativeTexCoord - (Time * 0.004);	
	return Out;
}



float4 MaxColorDelta = float4(1.0, 1.0, 1.0, 0.0);
float4 HalfColorDelta = float4(-0.33, -0.33, -0.33, -0.0);
// ----------------------------------------------------------------------------
float4 TiberiumPS_Metagame(VSOutput_TiberiumMetagame In) : COLOR
{
	// Get vertex color
	float4 color;		// Get my color
	float4 glowA;
	float4 glowB;
	float4 colorDelta;
        float4 colorSample;
        float4 colorMix;
	// Multiply by the main color
	color.xyzw = tex2D( SAMPLER(MaskSampler), In.MaskTexCoord) * In.DiffuseColor;
	glowA      = tex2D( SAMPLER(GlowSampler), In.GlowTexCoord);
	glowB      = tex2D( SAMPLER(GlowSampler), In.GlowTexCoord01);
	colorSample =  glowA * glowB;           // multiply these 2 samples so we have a squared effect instead of linear addition
        colorMix =  dot(float4(1.0f, 0.0f, 0.0f, 1.0f),colorSample); // mix color and alpha channel together.  Alpha has one frequency noise pattern, rgb another.  Since its black and white we can just use the red channel
	colorDelta =  (colorMix * MaxColorDelta) + HalfColorDelta; // scale the color change to MaxColorDelta, and then bias the result so that we can have a negative influence 
	color.xyzw +=  colorDelta;
	return saturate(color);
}

// ----------------------------------------------------------------------------
technique Alpha
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique Add
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique Multiply
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		AlphaBlendEnable = true;
		SrcBlend = Zero;
		DestBlend = SrcColor;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique SimpleMerge
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		//AlphaRef = 0x60;
		StencilFunc = NotEqual;
		StencilPass = Replace;
		StencilEnable = true;
		StencilRef = 0xff;
		StencilMask = 0xffffffff;
		StencilWriteMask = 0xffffffff;
		StencilZFail = Keep;
		StencilFail = Keep;
	}  
}

// ----------------------------------------------------------------------------
technique Merge
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW MaskPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		ColorWriteEnable = 0;
		AlphaBlendEnable = true;
		SrcBlend = Zero;
		DestBlend = One;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60;
		StencilFunc = Always;
		StencilPass = Replace;
		StencilEnable = true;
		StencilRef = 0xff;
		StencilMask = 0xffffffff;
		StencilWriteMask = 0xffffffff;
		StencilZFail = Keep;
		StencilFail = Keep;
	}  

	pass P1
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;	//One;
		DestBlend = InvSrcAlpha;
		ColorWriteEnable = RGBA;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = 0x60;
		StencilFunc = NotEqual;
		StencilPass = Keep;
		StencilEnable = true;
		StencilRef = 0xff;
		StencilMask = 0xffffffff;
		StencilWriteMask = 0xffffffff;
		StencilZFail = Keep;
		StencilFail = Keep;
	}  
}


// ----------------------------------------------------------------------------
technique TiberiumRoot
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW TiberiumVS();
		PixelShader = compile PS_VERSION_LOW TiberiumPS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
	}  
}


// ----------------------------------------------------------------------------
technique TiberiumRootMetagame
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW TiberiumVS_Metagame();
		PixelShader = compile PS_VERSION_LOW TiberiumPS_Metagame();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
	}  
}
