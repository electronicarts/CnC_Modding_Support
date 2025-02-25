//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// FX Shader for vehicles and structures. 
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_NORMALMAP 1

#include "Common.fxh"

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1
#include "Skinning.fxh"

float Time : Time;


// ----------------------------------------------------------------------------
// Editable parameters
// ----------------------------------------------------------------------------
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

SAMPLER_2D_BEGIN( FilteredNoise,
	string SasBindAddress = "WW3D.FilteredNoise";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


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


// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float3 TangentEyeDir : TEXCOORD5;
};

VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0)
{
	USE_TEXCOORD(TexCoord0);

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	int numJointsPerVertex = 1;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Build 3x3 tranform from world to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	Out.TangentEyeDir = mul(worldEyeDir, worldToTangentSpace);

	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0 = TexCoord0;

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	return Out;
}



// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - High
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, float2 vPos : PIXELLOC) COLORTARGET
{	
	float2 texCoord0 = In.TexCoord0;
	float3 tangentEyeDir = In.TangentEyeDir;

#if defined(SUPPORT_NORMALMAP)
	float3 bumpNormal = (float3)tex2D(SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;	
	bumpNormal = normalize(bumpNormal);
#else
	float3 bumpNormal = float3(0,0,1);
#endif

	
	float2 screenTexCoord = GetScreenTexcoordCoord(vPos);

	float2 noiseCoord1 = float2((screenTexCoord.x + texCoord0.x) * 30, (screenTexCoord.y + texCoord0.y) * 30);
	float2 noiseCoord2 = float2((screenTexCoord.y + sin(Time * 10) - sin(Time * 20)), (screenTexCoord.x + sin(Time * 13) - sin(Time * 23)));

	float2 noiseCoord3 = noiseCoord1 * 0.1f;
	float2 noiseCoord4 = noiseCoord2 * 0.1f;


	//scale noise coords for high freq static on unit
	noiseCoord1 *= 30; 
	noiseCoord2 *= 48; 

	float4 filtnoise1 = tex2D(SAMPLER(FilteredNoise), noiseCoord1); 
	float4 filtnoise2 = tex2D(SAMPLER(FilteredNoise), noiseCoord2);
	

	//test lower period noise for alpha
	float4 filtnoise3 = tex2D(SAMPLER(FilteredNoise), noiseCoord3); 
	float4 filtnoise4 = tex2D(SAMPLER(FilteredNoise), noiseCoord4);

	//Formation Preview Fresnel effect
	float4 FPcolor;
	FPcolor.xyz = float3(0.15,0.7,1.0);
	float FPEyeDotNorm = dot(tangentEyeDir, bumpNormal);
	float FPfresnelDiffuse = pow( 1-FPEyeDotNorm, 2); //2.5);
	FPcolor.xyz *= FPfresnelDiffuse;
	FPcolor.xyz = min(FPcolor.xyz,2);
	FPcolor.w = 0.5f;

	float brightscale = 8.0f;
	float noiseval = saturate(filtnoise1 * filtnoise2);
	float4 color = FPcolor * noiseval * brightscale;

	float alpha = 0.5f;
	//eh...not sure this is better
	alpha = lerp(0.2f, 1.0f, saturate(noiseval)); 

	//apply lower period flickering
	alpha = alpha * filtnoise3 * filtnoise4;
	



	return float4(color.xyz, alpha);
}



// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_H();
		PixelShader = compile PS_3_0 PS_H();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}


