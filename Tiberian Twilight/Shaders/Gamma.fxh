//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Gamma color space support
//////////////////////////////////////////////////////////////////////////////

#ifndef _GAMMA_FXH_
#define _GAMMA_FXH_

#define ENABLE_GAMMA_CONVERSION

#if defined(EA_PLATFORM_PS3)
	#define USE_APPROXIMATE_GAMMA
#endif // #if defined(EA_PLATFORM_PS3)

//
// Gamma color space support
//

float3 GammaToLinear(float3 c)
{
#if defined(ENABLE_GAMMA_CONVERSION)

	#if defined(USE_APPROXIMATE_GAMMA)
		return c * c;
	#else // #if defined(USE_APPROXIMATE_GAMMA)
		return pow(c, 2.2);
	#endif // #if defined(USE_APPROXIMATE_GAMMA)

#else
	return c;
#endif
}

float3 LinearToGamma(float3 c)
{
#if defined(ENABLE_GAMMA_CONVERSION)

	#if defined(USE_APPROXIMATE_GAMMA)
		return c * rsqrt(c);
	#else // #if defined(USE_APPROXIMATE_GAMMA)
		return pow(c, 1.0 / 2.2);
	#endif // #if defined(USE_APPROXIMATE_GAMMA)

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

// This is to correct any gamma approximation
float3 CorrectForGammaApproximation(float3 c)
{
	#if defined(USE_APPROXIMATE_GAMMA)
        // $note(WSK) - This is trying to compensate difference between pow(2) and pow(2.2)
		//              We try to solve a parabolic equation y=ax^2 + bx + c by these 3 points
		//              (0.2, 0) (0.6, 0.035) (1,0) and we clamp the y to 0 from x=0 to x=0.2.
		return saturate(c - saturate(c*c*(-0.21875) + 0.2625*c - 0.04375));
	#else // #if defined(USE_APPROXIMATE_GAMMA)
		return c;
	#endif // #if defined(USE_APPROXIMATE_GAMMA)
}

#endif // Include guard
