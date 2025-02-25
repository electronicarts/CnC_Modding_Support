//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for shadow map debugging
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonParticle.fxh"

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

SAMPLER_2D_BEGIN( BaseTexture,
	string UIName = "Base Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Mirror;
	AddressV = Mirror;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( SwirlTexture,
	string UIName = "Swirl Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Mirror;
	AddressV = Mirror;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;

float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput_FlatColor
{
	float4 Position : POSITION;
};

// ----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColor(float3 Position : POSITION)
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection); // float4(Position, 1);
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_FlatColor(VSOutput_FlatColor In) : COLOR
{
	return float4(1, 0, 0, 1);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
struct VSOutput_Texture1
{
	float4 Position : POSITION;
	float4 Color	: COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_Texture1 VS_Texture1(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 Color : COLOR0)
{
	VSOutput_Texture1 Out;
	float3 warpPos = Position * .25;
	float timeMul = Time * 20; 
	warpPos.x =  GetRandomFloatValue(float2(-1,1),timeMul,5);
	warpPos.y =  GetRandomFloatValue(float2(-1,1),timeMul,6);
	warpPos.z = GetRandomFloatValue(float2(-1,1),timeMul,7);
  warpPos = warpPos + Position;
	Out.Position = mul(float4(warpPos, 1), WorldViewProjection);
	Out.BaseTexCoord = TexCoord0;
	Out.Color = .25;
	Out.Color.r += Color.r * GetRandomFloatValue(float2(0,1),Time*10,5);
	Out.Color.g += Color.g * GetRandomFloatValue(float2(0,1),Time*10,6);
	Out.Color.b += Color.b* GetRandomFloatValue(float2(0,1),Time*10,7);
	
	Out.Color.w = OpacityOverride;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_Texture1(VSOutput_Texture1 In) : COLOR
{

	Time *= 10.75f;
  float2 warpOff1 = float2(Time,Time * 0.1234f) * 0.010f + float2(0.0f,Time * 0.5f);
  float2 warpOff2 = float2(0.0f,-(Time+ 1000.0f)) * 0.010f + float2(0.0f,Time * 0.05f);
  
	float4 WarpColor1 = tex2D( SAMPLER(SwirlTexture),  (In.BaseTexCoord* 1  + warpOff1 ));
	float4 WarpColor2 = tex2D( SAMPLER(SwirlTexture), (In.BaseTexCoord * 1 + warpOff2));
	
	float WarpCol= (WarpColor2.x-WarpColor1.x)  * .75;
	
	float2 Texoff = In.BaseTexCoord -  float2(0.5 , 0.5);
	float warp = WarpCol ;
		
	float2x2 xyRotationMatrix = { 0.0f, 0.0f, 0.0f, 0.0f };
	xyRotationMatrix[0][0] = cos(warp); 
	xyRotationMatrix[0][1] = -sin(warp); 
	xyRotationMatrix[1][1] = xyRotationMatrix[0][0]; 
	xyRotationMatrix[1][0] = -xyRotationMatrix[0][1];
	 
	float2 TexoffRot = mul(Texoff,xyRotationMatrix);
	
	float2 warpTex = TexoffRot + float2(0.5 ,0.5) ;
	
	float4 TextureColor = tex2D( SAMPLER(BaseTexture),warpTex );
	
	float4 color = TextureColor * In.Color * 5;
	color.a = clamp(0,1,TextureColor.r)*5;
	color = float4(In.Color.rgb ,color.a);
	return color ;
}

// ----------------------------------------------------------------------------
technique Simplest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}

technique DynamicParameter
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}

technique Textured
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Texture1();
		PixelShader = compile PS_2_0 PS_Texture1();

		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaBlendEnable = true;


		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;


	}  
}