//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for particles
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"
#include "Gamma.fxh"
#include "CommonParticle.fxh"


SAMPLER_2D_BEGIN(ParticleTexture,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 Projection : Projection;
float4x3 View : View;
	
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

// ----------------------------------------------------------------------------
// Vertex shader
// ----------------------------------------------------------------------------
	
struct VSInput
{
	float4 Position_Index 	: POSITION;		// position (xyz), index (w)
	float2 Angle_Size 		: TEXCOORD0;	// angle (x), size (y)
	float4 VertexColor 		: COLOR0;		// color
};

struct VSOutput
{
	float4 Position 	: POSITION;
	float4 DiffuseColor : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

VSOutput VS_Billboard(VSInput In)
{
	VSOutput Out;
	
	// compute the z rotation matrix
	float zRotation = In.Angle_Size.x;
	float2x2 zRotationMatrix;
	zRotationMatrix[0][0] = cos(zRotation); 
	zRotationMatrix[0][1] = -sin(zRotation); 
	zRotationMatrix[1][1] = zRotationMatrix[0][0]; 
	zRotationMatrix[1][0] = -zRotationMatrix[0][1];

	// compute the vertex corners
	float Index = In.Position_Index.w;
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float size = In.Angle_Size.y;
	float3 xVector = float3( View[0][0], View[1][0], View[2][0] );
	float3 zVector = float3( View[0][1], View[1][1], View[2][1] );
	float3 cornerPosition = In.Position_Index.xyz + size * (relativeCornerPos.x * xVector + relativeCornerPos.y * zVector);
	
	Out.Position = mul(float4(cornerPosition, 1), GetViewProjection());
	Out.DiffuseColor = In.VertexColor;
	Out.BaseTexCoord = GetVertexTexCoord(vertexCorner);
	
	return Out;
}

VSOutput VS_NoBillboard(VSInput In)
{
	VSOutput Out;
	
	// compute the z rotation matrix
	float zRotation = In.Angle_Size.x;
	float2x2 zRotationMatrix;
	zRotationMatrix[0][0] = cos(zRotation); 
	zRotationMatrix[0][1] = -sin(zRotation); 
	zRotationMatrix[1][1] = zRotationMatrix[0][0]; 
	zRotationMatrix[1][0] = -zRotationMatrix[0][1];

	// compute the vertex corners
	float Index = In.Position_Index.w;
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float size = In.Angle_Size.y;
	float3 cornerPosition = float3( In.Position_Index.xy + ( size * relativeCornerPos ), In.Position_Index.z );
	
	Out.Position = mul(float4(cornerPosition, 1), GetViewProjection());
	Out.DiffuseColor = In.VertexColor;
	Out.BaseTexCoord = GetVertexTexCoord(vertexCorner);
	
	return Out;
}

// ----------------------------------------------------------------------------
// Pixel Shader
// ----------------------------------------------------------------------------

float4 PS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
   
   	// Apply texture
	float4 baseTexture = tex2D(SAMPLER(ParticleTexture), In.BaseTexCoord);
	baseTexture.xyz = GammaToLinear(baseTexture.xyz);

 	color *= baseTexture;

	return color;
}

float4 PS_M(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
   
   	// Apply texture
 	color *= tex2D(SAMPLER(ParticleTexture), In.BaseTexCoord);

	return color;
}

//--------------------------------------------------------------------------
// No billboard techniques
//--------------------------------------------------------------------------

technique AdditiveSpriteShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

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

//--------------------------------------------------------------------------

technique AdditiveAlphaTestSpriteShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique AlphaSpriteShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

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

//--------------------------------------------------------------------------

technique ATestSpriteShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique MultiplicativeSpriteShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Additive2DShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Alpha2DShader
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}


//--------------------------------------------------------------------------
// Billboard techniques
//--------------------------------------------------------------------------

technique AdditiveSpriteShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

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

//--------------------------------------------------------------------------

technique AdditiveAlphaTestSpriteShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique AlphaSpriteShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

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

//--------------------------------------------------------------------------

technique ATestSpriteShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique MultiplicativeSpriteShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Additive2DShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Alpha2DShaderBillboard
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}

//
// Medium LOD versions
//

//--------------------------------------------------------------------------
// No billboard techniques
//--------------------------------------------------------------------------

technique AdditiveSpriteShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

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

//--------------------------------------------------------------------------

technique AdditiveAlphaTestSpriteShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique AlphaSpriteShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

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

//--------------------------------------------------------------------------

technique ATestSpriteShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique MultiplicativeSpriteShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;

		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Additive2DShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Alpha2DShader_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_NoBillboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}  
}


//--------------------------------------------------------------------------
// Billboard techniques
//--------------------------------------------------------------------------

technique AdditiveSpriteShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

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

//--------------------------------------------------------------------------

technique AdditiveAlphaTestSpriteShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique AlphaSpriteShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

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

//--------------------------------------------------------------------------

technique ATestSpriteShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}

//--------------------------------------------------------------------------

technique MultiplicativeSpriteShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;

		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Additive2DShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = false;
	}  
}

//--------------------------------------------------------------------------

technique Alpha2DShaderBillboard_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Billboard();
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}  
}
