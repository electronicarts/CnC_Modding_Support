//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// A simple random number generator
//////////////////////////////////////////////////////////////////////////////

#ifndef _RANDOM_FXH_
#define _RANDOM_FXH_

//
// Random number generator
//

#if !defined(EA_PLATFORM_PS3)

STATICARRAY const float4 RandomValues[MAX_RANDOM_VALUES] = // random values in range 0..1
{
	// To generate this table, use excel with rows of this formula: =CONCATENATE("float4(",RAND(),", ",RAND(),", ", RAND(),", ", RAND(), "),")
	float4(0.957897000503582, 0.378870525347763, 0.363571890095615, 0.328760908964182),
	float4(0.176237249178937, 0.914575110140635, 0.436093504459558, 0.347628420779846),
	float4(0.74321894178331, 0.442561117711613, 0.997454573448046, 0.362213792964882),
	float4(0.489662653412263, 0.666423292057291, 0.830569846431306, 0.974257713027646),
	float4(0.894767456143942, 0.823621517393205, 0.930970549797899, 0.0521984733736147),
	float4(0.141100733280401, 0.652700235943417, 0.00845252291957532, 0.643057387894008),
	float4(0.22979899343149, 0.897999019438672, 0.753821963794792, 0.131650373484698),
	float4(0.581538391481718, 0.283691652574809, 0.0915647105845903, 0.407480940983646),
	float4(0.270604393931209, 0.72281806272639, 0.16943672558123, 0.146905246115598),
	float4(0.599555574957733, 0.096453300376983, 0.876398320463974, 0.117222883790552),
	float4(0.510171077745377, 0.942157193101133, 0.195788791440078, 0.916756497322788),
	float4(0.0354679287382584, 0.534009408848821, 0.167321778635773, 0.557676417292525),
	float4(0.861564026888471, 0.225160105115149, 0.0823319997715926, 0.87900387469963),
	float4(0.173086589845635, 0.89351880243715, 0.0139240580314164, 0.178738120005564),
	float4(0.826938346482238, 0.771814362160947, 0.439535939575699, 0.49396301649165),
	float4(0.542361347073796, 0.721861671956157, 0.769731420798597, 0.587856677976187),
};	

#endif // #if !defined(EA_PLATFORM_PS3)

// Get a random value in a specific range. Range has minimum in x and spread (= max - min) in y
float GetRandomFloatValue(float2 range, float index, float seed)
{
	float fraction = frac(seed * 11.0f/MAX_RANDOM_VALUES + index * 3.0f / MAX_RANDOM_VALUES); 
	return (range.x + RandomValues[fraction * MAX_RANDOM_VALUES].x * range.y);
}

float2 GetRandomFloatValues(float2 minimum, float2 range, float index, float seed)
{
	float fraction = frac(seed * 11.0f/MAX_RANDOM_VALUES + index * 3.0f / MAX_RANDOM_VALUES);
	return minimum + RandomValues[fraction * MAX_RANDOM_VALUES].xy * range;
}

float3 GetRandomFloatValues(float3 minimum, float3 range, float index, float seed)
{
	float fraction = frac(seed * 11.0f/MAX_RANDOM_VALUES + index * 3.0f / MAX_RANDOM_VALUES);
	return minimum + RandomValues[fraction * MAX_RANDOM_VALUES].xyz * range;
}

float4 GetRandomFloatValues(float4 minimum, float4 range, float index, float seed)
{
	float fraction = frac(seed * 11.0f/MAX_RANDOM_VALUES + index * 3.0f / MAX_RANDOM_VALUES);
	return minimum + RandomValues[fraction * MAX_RANDOM_VALUES] * range;
}

#endif // _RANDOM_FXH_