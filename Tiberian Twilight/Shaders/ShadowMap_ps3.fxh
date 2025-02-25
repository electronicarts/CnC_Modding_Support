//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Shadowmap header for ps3 specific implementation
//////////////////////////////////////////////////////////////////////////////

#ifndef _SHADOWMAP_PS3_FXH_
#define _SHADOWMAP_PS3_FXH_

// ----------------------------------------------------------------------------
// Shadow mapping variables
// ----------------------------------------------------------------------------

static const float4 Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0].Zero_Zero_OneOverMapSize_OneOverMapSize";
> = float4(0.0, 0.0, 1.0/1024.0, 1.0/1024.0);

// ----------------------------------------------------------------------------
// Shadow mapping look-up function. Similar to DXSAS prototype
// ----------------------------------------------------------------------------

float shadow(sampler2D shadowSampler, float4 shadowTexCoord)
{
#if defined(USE_HARDWARE_SHADOW)
	float3 t = shadowTexCoord.xyz;
	float4 shadowval;
	shadowval.x = tex2D(shadowSampler, shadowTexCoord.xyz).x;
	shadowval.y = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zx, 0.0)).x;
	shadowval.z = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.yz, 0.0)).x;
	shadowval.w = tex2D(shadowSampler, shadowTexCoord.xyz + float3(Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.wz, 0.0)).x;

	return dot(0.25,shadowval);
#else // #if defined(USE_HARDWARE_SHADOW)
	float2 t = shadowTexCoord.xy;
		
	float depth = shadowTexCoord.z;

	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.wz).x);
		
	bool4 bits = (samples - depth >= 0);

	return dot(1.0, bits) / 4.0;
#endif // #if defined(USE_HARDWARE_SHADOW)
}

#endif // #define _SHADOWMAP_PS3_FXH_
