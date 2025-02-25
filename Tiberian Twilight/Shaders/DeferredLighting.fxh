
// ©2005 Electronic Arts Inc
//
// FX Shader include for sampling the deferred lighitng buffers
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "Gamma.fxh"
#include "ShadowMap.fxh"

SAMPLER_2D_BEGIN( DeferredDiffuseLightTexture,
	string SasBindAddress = "WW3D.DeferredLighting.DiffuseLightTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( DeferredSpecularLightTexture,
	string SasBindAddress = "WW3D.DeferredLighting.SpecularLightTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float3 SampleDiffuseLight( float2 screenTexCoord )
{
	return tex2D( SAMPLER(DeferredDiffuseLightTexture), screenTexCoord ).rgb;
}

float3 SampleSpecularLight( float2 screenTexCoord )
{
	return tex2D( SAMPLER(DeferredSpecularLightTexture), screenTexCoord ).rgb;
}

#if !defined(_3DSMAX_)

SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4x4 ProjectionI : ProjectionInverse;
float4x4 ViewI : ViewInverse;

// ----------------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------------
float3 ComputeWorldPosition(float2 texcoord)
{
	float depth = TexDepth2D(SAMPLER(DepthTexture), texcoord).x;
	
	// We need to convert the view space depth values from the depth texture to world space positions.
	// First build a ray "through" the pixel in question
	float4 screenFarPlanePosition = float4(texcoord*2-1, 1, 1);
	screenFarPlanePosition.y *= -1;
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	float3 viewEyeDir = viewFarPlanePosition / viewFarPlanePosition.z;

	float3 worldEyeDir = mul(viewEyeDir, ViewI);
	float3 eyePosition = ViewI[3].xyz;
 	float3 worldPosition = eyePosition + depth * worldEyeDir;
	
	return worldPosition;
}

#endif // #if !defined(_3DSMAX_)
