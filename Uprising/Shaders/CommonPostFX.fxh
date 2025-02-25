//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Common header for PostFX shaders
//////////////////////////////////////////////////////////////////////////////

#ifndef _COMMON_POST_FX_FXH_
#define _COMMON_POST_FX_FXH_

#define XENON_HDR_RESOLVE_FACTOR 8

bool IsHdrEnabled
<
	string SasBindAddress = "WW3D.IsHdrEnabled";
> = false;

 // Compensate for the intensity decrease from the conversion fp12 to fixed16 on Xenon HDR RTs
float3 UncompressRenderTargetColor(float3 color)
{
#if defined(EA_PLATFORM_XENON)
	if (IsHdrEnabled)
		color *= XENON_HDR_RESOLVE_FACTOR;
#endif

	return color;
}

#endif // Include guard
