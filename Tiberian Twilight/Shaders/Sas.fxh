//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Common header file with DXSAS 1.0 definitions
//////////////////////////////////////////////////////////////////////////////

#ifndef _SAS_FXH_
#define _SAS_FXH_

struct SasCamera
{
	float4x4 WorldToView;	   
	float4x4 Projection;    
	float2 NearFarClipping; 
};

struct SasAmbientLight
{
	float3 Color;			// default: {0, 0, 0}
};

struct SasDirectionalLight
{
	float4 Color;			// default: {0, 0, 0}
	float4 Direction;		// default: {0, 0, 1} // Note: default value non-standard
};

struct SasPointLight
{
	float4 Color;			// default: {0, 0, 0} // Color / Range Inner
	float4 Position;		// default: {0, 0, 0} // Position / Range Outer
};

struct SasPointLightsAttenuationInfo
{
	float4 InnerRanges; 			// default: {0, 0, 0, 0} // Range Inner for 4 Point Lights
	float4 OneOverFalloffDistance; 	// default: {0, 0, 0, 0} // 1 / (Range Outer-Range Inner) for 4 Point Lights
};

struct SasSpotLight
{
	float3 Color;			// default: {0, 0, 0}
	float3 Position;		// default: {0, 0, 0}
	float  Direction;		// default: {0, 0, 0}
	float  Range;			// default: 0
	float  Theta;			// default: 0
	float  Phi;				// default: 0
};

#endif // Include guard
