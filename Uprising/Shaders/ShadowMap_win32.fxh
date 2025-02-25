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

//
// Shadow mapping look-up function. Similar to DXSAS prototype.
//
float shadow(sampler2D shadowSampler, float4 shadowTexCoord)
{
	float2 t = shadowTexCoord.xy;
		
	float depth = shadowTexCoord.z;
	
	float4 samples = float4(
		tex2D(shadowSampler, t).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.zx).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.yz).x,
		tex2D(shadowSampler, t + Shadowmap_Zero_Zero_OneOverMapSize_OneOverMapSize.wz).x);
		
	bool4 bits = (samples - depth >= 0);

	return dot(1.0, bits) / 4.0;
}

#endif // #define _SHADOWMAP_WIN32_FXH_
