//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Gamma color space support
//////////////////////////////////////////////////////////////////////////////

#ifndef _GAMMA_FXH_
#define _GAMMA_FXH_

#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
#define ENABLE_GAMMA_CONVERSION
#endif

//
// Gamma color space support
//

float3 GammaToLinear(float3 c)
{
#if defined(ENABLE_GAMMA_CONVERSION)
	return pow(c, 2.2);
#else
	return c;
#endif
}

float3 LinearToGamma(float3 c)
{
#if defined(ENABLE_GAMMA_CONVERSION)
	return pow(c, 1.0 / 2.2);
#else
	return c;
#endif
}

// This should be the final function applied during the return of a pixel shader that should support gamma.
float4 CorrectForFrameBufferGamma(float4 c)
{
	// Note that we normally use a linear frame buffer when using gamma correction,
	// so this function will not actually do anything.
	// However 3DSMax does not handle linear output, so we have to re-gamma for it.
#if defined(_3DSMAX_)
	return float4(LinearToGamma(c.xyz), c.w);
#else
	return c;
#endif
}


#endif // Include guard
