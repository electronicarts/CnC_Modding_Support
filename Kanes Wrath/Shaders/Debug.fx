//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for shadow map debugging
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"


SAMPLER_2D_BEGIN( BaseTexture,
	string UIName = "Base Texture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
>;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 World : World;
float4x3 ViewI : ViewInverse;
float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput_Texture1
{
	float4 Position : POSITION;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
struct VSOutput_FlatColor
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
};

// ----------------------------------------------------------------------------
VSOutput_Texture1 VS_ShadowMap(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_Texture1 Out;
	Out.Position = float4(Position, 1);	
	Out.BaseTexCoord = TexCoord0;
	return Out;
}

// ----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColor(float3 Position : POSITION, float4 color : COLOR0 )
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = color;
	
	return Out;
}

// ----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColorOveride(float3 Position : POSITION )
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = FlatColorOverride;
	
	return Out;
}

// ----------------------------------------------------------------------------
VSOutput_FlatColor VS_Box(float3 Position : POSITION, float3 Normal : NORMAL,
	float4 color : COLOR0 )
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = color;
	Out.DiffuseColor.xyz 
		= saturate(dot(Normal, float3(0.5, 0.25, 0.5))) * float3(0.8, 0.7, 0.2)
		+ saturate(dot(Normal, -float3(0.5, 0.25, 0.5))) * float3(0.0, 0.3, 0.9);
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_Texture1(VSOutput_Texture1 In) : COLOR
{
	float4 color = (float)tex2D( SAMPLER(BaseTexture), In.BaseTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
float4 PS_FlatColor(VSOutput_FlatColor In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	return color;
}

// ----------------------------------------------------------------------------
technique DisplayShadowMap
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_ShadowMap();
		PixelShader = compile PS_VERSION_LOW PS_Texture1();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique DebugIcons_Regular
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColor();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique DebugDisplay
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColorOveride();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

//		FogEnable = false;
	}  
}


// ----------------------------------------------------------------------------
technique DrawObject_Opaque
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColor();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();
		
		FillMode = Solid;

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}

// ----------------------------------------------------------------------------
technique DrawObject_Opaque_ZTest
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColor();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();
		
		FillMode = Solid;

		ClipPlaneEnable = 0;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}

// ----------------------------------------------------------------------------
technique DrawObject_Alpha
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_FlatColor();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();
		
		FillMode = Solid;

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}

// ----------------------------------------------------------------------------
technique CollisionBox
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS_Box();
		PixelShader = compile PS_VERSION_LOW PS_FlatColor();
		
		FillMode = Solid;

		ClipPlaneEnable = 0;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}