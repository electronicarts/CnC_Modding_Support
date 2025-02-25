//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Shadowmap header for pc specific implementation
//////////////////////////////////////////////////////////////////////////////

#ifndef _SHADOWMAP_WIN32_FXH_
#define _SHADOWMAP_WIN32_FXH_

// ----------------------------------------------------------------------------
// Shadow mapping variables
// ----------------------------------------------------------------------------
float4 Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].Zero_Zero_OneOverMapSize_OneOverMapSize";
>;

SAMPLER_2D_BEGIN( Noise,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Noise_Shadow";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#include "Random.fxh"

float shadowSoftSampling(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, 
						uniform float2 numSteps, uniform float stepSize, uniform float jitterSize)
{
	float2 t		= shadowTexCoord.xy;
	float depth		= shadowTexCoord.z;

	float2 start	= -0.5f*(numSteps-1.0f);
	float2 end		=  0.5f*(numSteps-1.0f);

	float4 samplesAccum = 0;

	// Using the random generate for generate the jitter offset
  	float4 jitter = GetRandomFloatValues(-0.5*jitterSize.xxxx, jitterSize.xxxx, vPos.x, vPos.y);

	[unroll]for(float x=start.x; x<=end.x; x+=1.0f)
	{
		[unroll]for(float y=start.y; y<=end.y; y+=1.0f)
		{
			float4 offset = float4(x,y,x,y) + float4(-0.25f,-0.25f,0.25f,0.25f);

			float4 samples;
			samples.x = tex2D(shadowSampler, t + (offset.xy*stepSize+jitter.zw)*Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zw);
			samples.y = tex2D(shadowSampler, t + (offset.xw*stepSize+jitter.zy)*Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zw);
			samples.z = tex2D(shadowSampler, t + (offset.zw*stepSize+jitter.xy)*Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zw);
			samples.w = tex2D(shadowSampler, t + (offset.zy*stepSize+jitter.xw)*Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zw);

			bool4 b = (samples >= depth);
			samplesAccum += b;
		}
	}

	return dot(samplesAccum, 0.25) / (numSteps.x * numSteps.y);
}

//
// Shadow mapping look-up function. Similar to DXSAS prototype.
//
float shadow(sampler2D shadowSampler, float4 shadowTexCoord, float2 vPos, uniform int shadowmapSampling)
{
	float2 t = shadowTexCoord.xy;
	float depth = shadowTexCoord.z;

	float numDivisionX;
	float numDivisionY;
	float kernelSize;
	float jitterSize;

	if(shadowmapSampling == SHADOWMAP_SAMPLE_SOFT
#if defined(ENABLE_SOFTSHADOW_TOGGLE)
	 && SoftShadowParms.z > 0.0f
#endif // #if defined(ENABLE_SOFTSHADOW_TOGGLE)
		)
	{
		numDivisionX	= 3.0;
		numDivisionY	= 3.0;
		kernelSize		= SoftShadowParms.x;
		jitterSize		= SoftShadowParms.y;
	}
	else
	{
		numDivisionX	= 1.0;
		numDivisionY	= 1.0;
		kernelSize		= 2.0;
		jitterSize		= 0.0;
	}

	return shadowSoftSampling(shadowSampler, shadowTexCoord, vPos, float2(numDivisionX, numDivisionY), kernelSize, jitterSize);
}

#endif // #define _SHADOWMAP_WIN32_FXH_
