//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for shadow map debugging
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_GLOBAL_LIGHTS 1
#include "Common.fxh"
#include "CommonPostFX.fxh"

SAMPLER_2D_BEGIN( ShadowMap,
	string SasBindAddress = "Sas.Shadow[0].ShadowMap";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( Texture0,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.MiscTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = float4( 1.0f, 0.0f, 0.0f, 1.0f );

float3 OverdrawWeights
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OverdrawWeights";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = float3( 5, 10, 20 );	// x is the count that the overdraw reaches the second color, y the third color, and z the fourth color

//----------------------------------------------------------------------------
// Transformations
//----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;

//----------------------------------------------------------------------------
struct VSOutput_Default
{
	float4 Position : POSITION;
};

//----------------------------------------------------------------------------
struct VSOutput_Texture1
{
	float4 Position : POSITION;
	float2 BaseTexCoord : TEXCOORD0;
};

//----------------------------------------------------------------------------
struct VSOutput_FlatColor
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
};

//----------------------------------------------------------------------------
VSOutput_Texture1 VS_ShadowMap(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_Texture1 Out;
	Out.Position = float4(Position, 1);	
	Out.BaseTexCoord = TexCoord0;
	return Out;
}

//----------------------------------------------------------------------------
VSOutput_Default VS_Default(float3 Position : POSITION)
{
	VSOutput_Default Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	return Out;
}

//----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColor(float3 Position : POSITION, float4 color : COLOR0 )
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = color;
	
	return Out;
}

//----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColorOveride(float3 Position : POSITION )
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = FlatColorOverride;
	
	return Out;
}

#if defined(EA_PLATFORM_WINDOWS)
//----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColorOverideLines(float3 Position : POSITION)
{
	VSOutput_FlatColor Out;
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = FlatColorOverride;
	return Out;
}

//----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColorOverideTriangles(float3 Position : POSITION, float3 Normal : NORMAL )
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
	VSOutput_FlatColor Out;
	float3 worldNormal = mul(float4(Normal, 1), WorldViewProjection);
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.DiffuseColor = FlatColorOverride;
	Out.DiffuseColor.xyz *= dot(Normal, DirectionalLight_0_Direction.xyz);
	return Out;
}
#endif

//----------------------------------------------------------------------------
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

//----------------------------------------------------------------------------
float4 PS_ShadowMap(VSOutput_Texture1 In) : COLOR
{
	float4 color = (float)tex2D( SAMPLER(ShadowMap), In.BaseTexCoord);
	return color;
}

//----------------------------------------------------------------------------
float4 PS_MiscTextureRGBA(VSOutput_Texture1 In) : COLOR
{
	float4 color = tex2D( SAMPLER(Texture0), In.BaseTexCoord);
	return color;
}

//----------------------------------------------------------------------------
float4 PS_MiscTextureRGB(VSOutput_Texture1 In) : COLOR
{
	float4 color = float4( tex2D( SAMPLER(Texture0), In.BaseTexCoord).rgb, 1.0f );
	return color;
}

//----------------------------------------------------------------------------
float4 PS_MiscTextureRGBHDR(VSOutput_Texture1 In) : COLOR
{
	float4 color = float4( UncompressRenderTargetColor(tex2D( SAMPLER(Texture0), In.BaseTexCoord).rgb), 1.0f );
	return color;
}

//----------------------------------------------------------------------------
float4 PS_MiscTextureA(VSOutput_Texture1 In) : COLOR
{
	float4 color = float4( tex2D( SAMPLER(Texture0), In.BaseTexCoord).aaa, 1.0f );
	return color;
}

//----------------------------------------------------------------------------
float4 PS_MiscTextureDepth(VSOutput_Texture1 In) : COLOR
{
	float4 color = float4( 1.0f - tex2D( SAMPLER(Texture0), In.BaseTexCoord).xxx, 1.0f );
	color.xyz *= 10;
	return color;
}

//----------------------------------------------------------------------------
float4 PS_FlatColor(VSOutput_FlatColor In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	return color;
}

//----------------------------------------------------------------------------
float4 PS_OverdrawWrite(VSOutput_Default In) : COLOR
{
	// write up to 255 steps
	return 1.0f.xxxx/255.0f;
}

//----------------------------------------------------------------------------
float4 PS_OverdrawVisualize(VSOutput_Texture1 In) : COLOR
{
	float4 green	= float4( 0.0f, 1.0f, 0.0f, 0.75f ); 
	float4 yellow	= float4( 1.0f, 1.0f, 0.0f, 0.75f ); // 10
	float4 orange	= float4( 1.0f, 0.5f, 0.0f, 0.75f ); // 30
	float4 red		= float4( 1.0f, 0.0f, 0.0f, 0.75f ); // 50
	
	// we are going to solve a catmull-rom spline for the interpolation
	// the value stored in the texture is the 
	float t = tex2D(SAMPLER(Texture0), In.BaseTexCoord).x;
	
	// these weights correspond to the 3 segments of the curve
	float3 scaledWeights = OverdrawWeights / 255.0f;
	float  weights[6] = { 0.0f, 0.0f, scaledWeights.x, scaledWeights.y, scaledWeights.z, 1.0f }; 
	float4 points[6] = { green, green, yellow, orange, red, red };
	
	// figure out which segment of the curve to interpolate
	float start = t > scaledWeights.x ? ( t > scaledWeights.y ? ( 3 ) : 2 ) : 1;
	
	// normalize t by the range of the segment
	t = min(t, scaledWeights.z); 
	t = (( t - weights[start] ) / (weights[start+1] - weights[start]));
	
	// grab the 4 points
	float4 p1 = points[start-1];
	float4 p2 = points[start];
	float4 p3 = points[start+1];
	float4 p4 = points[start+2];
	
	float t2 = t * t;
	float t3 = t2 * t;
	
	float4 color =	0.5f * ((-p1 + 3.0f*p2 - 3.0f*p3 + p4)*t3 +
					(2.0f*p1 -5.0f*p2 + 4.0f*p3 - p4)*t2 +
					(-p1+p3)*t + 2.0f*p2);
					
	return color;
}

//----------------------------------------------------------------------------
technique DisplayShadowMap
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_ShadowMap();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

//----------------------------------------------------------------------------
technique DisplayMiscTextureRGBA
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_MiscTextureRGBA();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

//----------------------------------------------------------------------------
technique DisplayMiscTextureRGB
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_MiscTextureRGB();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

//----------------------------------------------------------------------------
technique DisplayMiscTextureRGBHDR
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_MiscTextureRGBHDR();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

//----------------------------------------------------------------------------
technique DisplayMiscTextureA
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_MiscTextureA();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

//----------------------------------------------------------------------------
technique DisplayMiscTextureDepth
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_MiscTextureDepth();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

//----------------------------------------------------------------------------
technique DebugIcons_Regular
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();

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

//----------------------------------------------------------------------------
technique DebugDisplay
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColorOveride();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = false;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

//----------------------------------------------------------------------------
technique DebugDisplayZTest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColorOveride();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

//----------------------------------------------------------------------------
technique DebugOverdrawWrite
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default();
		PixelShader = compile PS_2_0 PS_OverdrawWrite();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CCW;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}  
}

//----------------------------------------------------------------------------
technique DebugOverdrawVisualize
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_ShadowMap();
		PixelShader = compile PS_2_0 PS_OverdrawVisualize();

		ZEnable = false;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}

#if defined(EA_PLATFORM_WINDOWS)
//----------------------------------------------------------------------------
technique DebugDisplayLines
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColorOveride();
		PixelShader = compile PS_2_0 PS_FlatColor();
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = true;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

//----------------------------------------------------------------------------
technique DebugDisplayTrianglesBackFaceCCW
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColorOverideTriangles();
		PixelShader = compile PS_2_0 PS_FlatColor();
		ZEnable = false;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = D3DCULL_CCW;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		SrcBlend = D3DBLEND_SRCALPHA;
		DestBlend = D3DBLEND_INVSRCALPHA;
		ColorWriteEnable = RGBA;
	}  
}

//----------------------------------------------------------------------------
technique DebugDisplayTrianglesBackFaceCW
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColorOverideTriangles();
		PixelShader = compile PS_2_0 PS_FlatColor();
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = true;
		CullMode = D3DCULL_CW;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		SrcBlend = D3DBLEND_SRCALPHA;
		DestBlend = D3DBLEND_INVSRCALPHA;
		ColorWriteEnable = RGBA;
	}  
}


//----------------------------------------------------------------------------
technique DebugDisplayColoredLines
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = true;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}
#endif

//----------------------------------------------------------------------------
technique DrawObject_Opaque
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();
		
#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}

//----------------------------------------------------------------------------
technique DrawObject_Opaque_ZTest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();
		
#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;
	}  
}

//----------------------------------------------------------------------------
technique DrawObject_Alpha
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();
		
#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif

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

//----------------------------------------------------------------------------
technique CollisionBox
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Box();
		PixelShader = compile PS_2_0 PS_FlatColor();
		
#if !defined(EA_PLATFORM_PS3)
		FillMode = Solid;
#endif

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