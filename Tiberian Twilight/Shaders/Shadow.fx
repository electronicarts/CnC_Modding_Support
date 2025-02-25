//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader helper for shadow map
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "ShadowMap.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;

SAMPLER_2D_BEGIN( Sampler_PostProcess,
	string UIName = "None";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4x4 ViewI : ViewInverse;
float4x4 ProjectionI : ProjectionInverse;

// ----------------------------------------------------------------------------
// SHADER: WriteColor
// ----------------------------------------------------------------------------
float4 ColorToWrite = float4(0, 0, 0, 0);
float4 VSWriteColor(float3 Position : POSITION) : POSITION
{
	return float4(Position, 1);
}

// ----------------------------------------------------------------------------
float4 PSWriteColor(void) : COLOR
{
	return ColorToWrite;
}


// ----------------------------------------------------------------------------
// SHADER: VSShadowMapPostProcess
// ----------------------------------------------------------------------------
struct VSOutput_ShadowMapPostProcess
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_ShadowMapPostProcess VSShadowMapPostProcess(float3 Position : POSITION,
		float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_ShadowMapPostProcess Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord0 = TexCoord0;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PSShadowMapPostProcess(VSOutput_ShadowMapPostProcess In) : COLOR
{
	//return tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0).x;
	
	float4 Zero_Zero_OneOverMapSize_OneOverMapSize = float4(0, 0, 1, 1) / 1024;
	
	float surroundingCross = 
		max(
			max(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 + Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
				tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 - Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x),
			max(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 + Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
				tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0 - Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x));

	return lerp(tex2D( SAMPLER(Sampler_PostProcess), In.TexCoord0).x, surroundingCross, 0.5);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: WriteColor
// ----------------------------------------------------------------------------
technique _WriteColor
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSWriteColor();
		PixelShader = compile PS_2_0 PSWriteColor();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _ShadowMapPostProcess
// ----------------------------------------------------------------------------
technique _ShadowMapPostProcess
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSShadowMapPostProcess();
		PixelShader = compile PS_2_0 PSShadowMapPostProcess();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}


#if defined(USE_SCREENSPACE_SHADOW)

// ----------------------------------------------------------------------------
struct VSOutput_ScreenSpaceShadow
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 WorldFarPosition : TEXCOORD2;
	float4 WorldNearPosition : TEXCOORD3;
};

// ----------------------------------------------------------------------------
static const float4 Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].Zero_Zero_OneOverMapSize_OneOverMapSize";
> = float4(0.0, 0.0, 1.0/1024.0, 1.0/1024.0);

// ----------------------------------------------------------------------------
float3 ComputeWorldPosition(VSOutput_ScreenSpaceShadow In)
{
	float depth = TexDepth2D(SAMPLER(DepthTexture), In.TexCoord).x;

	float4 worldPosition4 = lerp(In.WorldNearPosition, In.WorldFarPosition, depth);
	worldPosition4 = worldPosition4 / worldPosition4.w;
	float3 worldPosition = worldPosition4.xyz;
	
	return worldPosition;
}

// ----------------------------------------------------------------------------
VSOutput_ScreenSpaceShadow VSScreenSpaceShadow(float3 Position : POSITION,
		float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_ScreenSpaceShadow Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord0;

	// Calculate the transformation matrix from screen to world
	float4x4 projectionToWorld = mul(ProjectionI, ViewI);

	float4 worldNear	= mul(float4(Position.xy, 0, 1), projectionToWorld);
	float4 worldFar		= mul(float4(Position.xy, 1, 1), projectionToWorld);

	Out.WorldNearPosition	= worldNear;//worldNear.xyz / worldNear.w;
	Out.WorldFarPosition	= worldFar;//worldFar.xyz / worldFar.w;
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PSScreenSpaceShadow(VSOutput_ScreenSpaceShadow In) : COLOR
{
	// Calculate world position
	float3 worldPosition = ComputeWorldPosition(In);

	// Transform the position in lightspace
	float4 shadowTexCoord = mul(float4(worldPosition, 1), ShadowMapWorldToShadow);

	shadowTexCoord.xyz /= shadowTexCoord.w;
	shadowTexCoord.z -= shadowZBias;

	sampler2D shadowSampler = SAMPLER(ShadowMap);
	float3 t = shadowTexCoord.xyz;

#if defined(USE_HARDWARE_SHADOW)
	float4 shadowVal;
	shadowVal.x = tex2D(shadowSampler, shadowTexCoord.xyz).x;
	shadowVal.y = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zx, 0.0)).x;
	shadowVal.z = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.yz, 0.0)).x;
	shadowVal.w = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.wz, 0.0)).x;

	return dot(0.25, shadowVal);
#else // #if defined(USE_HARDWARE_SHADOW)

	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.wz).x);
		
	bool4 bits = (samples - shadowTexCoord.z >= 0);

	return dot(0.25, bits);
#endif // #if defined(USE_HARDWARE_SHADOW)
}

// ----------------------------------------------------------------------------
// TECHNIQUE: ScreenSpaceShadow
// ----------------------------------------------------------------------------
technique ScreenSpaceShadow
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSScreenSpaceShadow();
		PixelShader = compile PS_2_0 PSScreenSpaceShadow();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( ScreenSpaceShadowTexture,
				 string SasBindAddress = "WW3D.ScreenSpaceShadowTexture";
)
MinFilter = GAUSSIAN;
MagFilter = GAUSSIAN;
MipFilter = Point;
AddressU = Clamp;
AddressV = Clamp;
SAMPLER_2D_END

struct VS_OUTPUT_BLUR
{
	float4	Position   				: POSITION;
	float2  TexCoord				: TEXCOORD0;	
};

VS_OUTPUT_BLUR VSScreenSpaceShadowBlurBox(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VS_OUTPUT_BLUR OUT;
	OUT.Position = float4(Position, 1);
	OUT.TexCoord = TexCoord;
	return OUT;
}

float4 PSScreenSpaceShadowBlurBox(VS_OUTPUT_BLUR IN) : COLOR
{
	return tex2D(SAMPLER(ScreenSpaceShadowTexture), IN.TexCoord);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: ScreenSpaceShadowBlurBox
// ----------------------------------------------------------------------------
technique ScreenSpaceShadowBlurBox
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSScreenSpaceShadowBlurBox();
		PixelShader = compile PS_2_0 PSScreenSpaceShadowBlurBox();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

#endif // #if defined(USE_SCREENSPACE_SHADOW)
