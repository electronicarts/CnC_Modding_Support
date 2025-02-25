//////////////////////////////////////////////////////////////////////////////
// ©2007 Electronic Arts Inc
//
// Shader for ocean displacement waves
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

SAMPLER_2D_BEGIN( DisplacementTexture,
	string SasBindAddress = "Water.DisplacementTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float OneOverDisplacementTextureSize
<
	string SasBindAddress = "Water.OneOverDisplacementTextureSize";
> = 0;

SAMPLER_2D_BEGIN( StaticDisplacementTexture,
	string SasBindAddress = "Water.StaticDisplacementTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 ViewI : ViewInverse;
float4x4 ProjectionI : ProjectionInverse;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 View 		: View;
float4x4 Projection : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

float Time : Time;


// ----------------------------------------------------------------------------
struct VSOutput_RenderWaveParticles
{
	float4 Position : POSITION;
	float4 Amplitude : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_RenderWaveParticles VS_RenderWaveParticles(float4 StartPosition_Velocity : POSITION, float2 StartAmplitude_CreationTime : TEXCOORD0)
{
	float2 startPosition = StartPosition_Velocity.xy;
	float2 velocity = StartPosition_Velocity.zw;
	float startAmplitude = StartAmplitude_CreationTime.x;
	float creationTime = StartAmplitude_CreationTime.y;
	
	float age = Time - creationTime;
	
	float2 position = startPosition + age * velocity;
	float amplitude = startAmplitude;
	
	// Wave particles that should be explicitly faded in and out, are uploaded with a negative amplitude.
	if (startAmplitude < 0.0f)
	{
		amplitude = abs(amplitude);
		
		float fadeInTime = 2.0; // Number of seconds to linearly fade in
		float fadeOutFactor = 4.0; // "Steepness" of the curve for fade out falloff

		float oneOverFadeInTime = 0.5;
		float oneOverFadeOutFactor = 0.25;
	
		// Note: If this formula or the fadeOutFactor changes, external code should be changed as well, so that the actual particle deletion occurs at the correct time.
		amplitude *= exp(-age * oneOverFadeOutFactor);
		// amplitude /= (age + 1); // Alternative to try out
		
		amplitude *= saturate(age * oneOverFadeInTime);
	}
	
	// Transform position from world space into the render target's space
	float2 positionXY = mul(float4(position, 0, 1), GetViewProjection()).xy;

	VSOutput_RenderWaveParticles Out;
	Out.Position = float4(positionXY, 0, 1);
	amplitude = min(amplitude,1);

#if defined(EA_PLATFORM_XENON) // scale range on xenon
	float4 amplitudeMultiplier = float4(0.5, 0.5, 1.0, 0.0);
#elif defined(EA_PLATFORM_PS3) // scale range on ps3
	float4 amplitudeMultiplier = float4(0.5, 0.5, 0.25, 0.0);
#else 
	// Complier should opt this multiplication out
	float amplitudeMultiplier = 1.0;
#endif
	Out.Amplitude = amplitudeMultiplier * float4(amplitude, amplitude, amplitude, 0.0);

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_RenderWaveParticles(VSOutput_RenderWaveParticles In) : COLOR
{
	return In.Amplitude;
}

// ----------------------------------------------------------------------------
technique RenderWaveParticles
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_RenderWaveParticles();
		PixelShader = compile PS_2_0 PS_RenderWaveParticles();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}  
}

// ----------------------------------------------------------------------------
struct VSOutput_Blur
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_Blur VS_Blur(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput_Blur Out;	
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;	
	return Out;
}

// ----------------------------------------------------------------------------
// Two dimensional version of the wave particle "blurring". More expensive, but can be used to prototype different wave shapes better
float4 PS_Blur2D(VSOutput_Blur In, uniform float2 direction) : COLOR
{
//return tex2D(SAMPLER(DisplacementTexture), In.TexCoord + .2).xxxx;
//return float4(0.5, 0, 0, 0);
	static const int kernelSize = 10;
	static const float oneOverTextureSize = OneOverDisplacementTextureSize;
	float3 result = 0;
	for (int j = -kernelSize; j <= kernelSize; j++)
		for (int i = -kernelSize; i <= kernelSize; i++)
		{
			float2 texCoord = In.TexCoord + float2(i, j) /* * direction */ * oneOverTextureSize;
			
			float radius = 10;
			const float pi = 3.14159265;
			
			float phase = pi * min(length(float2(i, j)) / radius, 1);
			
			float transversalFactor = 0.5 * (cos(phase) + 1);
			float2 longitudinalFactor = -sin(phase) * transversalFactor * normalize(float2(i, j)) * radius;
			//float2 longitudinalFactor = -sin(phase) * transversalFactor * float2(i, j);
			
			float3 factor = float3(longitudinalFactor, transversalFactor);
			
			result += tex2D(SAMPLER(DisplacementTexture), texCoord).zzz * factor;
		}
	result /= (kernelSize * 2 + 1) * (kernelSize * 2 + 1);
	//result *= 20;
	result /= 50;
	result.xy /= -2;
	result.y *= -1;
	return float4(result, 0);
}

#if defined(EA_PLATFORM_WINDOWS)
static const int kernelSize = 10;
#elif defined(EA_PLATFORM_XENON) || defined(EA_PLATFORM_PS3)
static const int kernelSize = 5;
#endif
static const float radius = float(kernelSize);
static const float one_over_radius = 1.0/float(kernelSize);
static const float pi = 3.14159265;

float computeTransversalFactor( float index )
{
	return 0.5 * (cos(pi * index * one_over_radius) + 1);
}
float computeLongitudinalFactor( float index )
{
	return -sin(pi * index * one_over_radius) * radius;
}

float4 PS_Blur(VSOutput_Blur In, uniform float2 direction) COLORTARGET
{
	STATICARRAY const float oneOverTextureSize = OneOverDisplacementTextureSize;

#if defined(EA_PLATFORM_PS3)
	// $note (WSK) 2008/11/17 - this is a precomputed table for the constants using computeTransversalFactor(), need to update this whenever the math changes or if the kernel size changed
	STATICARRAY const float transversalFactor[kernelSize * 2 + 1] = {
		 0.000000000000,
		 0.095491502813,
		 0.345491502813,
		 0.654508497187,
		 0.904508497187,
		 1.000000000000,
		 0.904508497187,
		 0.654508497187,
		 0.345491502813,
		 0.095491502813,
		 0.000000000000,
	};

	// $note (WSK) 2008/11/17 - this is a precomputed table for the constants using computeLongitudinalFactor(), need to update this whenever the math changes or if the kernel size changed
	STATICARRAY const float longitudinalFactor[kernelSize * 2 + 1] = {
		 0.000000000000, 
		 2.938926261462, 
		 4.755282581476, 
		 4.755282581476, 
		 2.938926261462, 
		 0.000000000000, 
		-2.938926261462,
		-4.755282581476,
		-4.755282581476,
		-2.938926261462,
		 0.000000000000,
	};
#else // #if defined(EA_PLATFORM_PS3)

	STATICARRAY const float transversalFactor[kernelSize * 2 + 1] = {
#if defined(EA_PLATFORM_WINDOWS)
		computeTransversalFactor(-10),
		computeTransversalFactor(-9),
		computeTransversalFactor(-8),
		computeTransversalFactor(-7),
		computeTransversalFactor(-6),
#endif
		computeTransversalFactor(-5),
		computeTransversalFactor(-4),
		computeTransversalFactor(-3),
		computeTransversalFactor(-2),
		computeTransversalFactor(-1),
		computeTransversalFactor(0),
		computeTransversalFactor(1),
		computeTransversalFactor(2),
		computeTransversalFactor(3),
		computeTransversalFactor(4),
		computeTransversalFactor(5),
#if defined(EA_PLATFORM_WINDOWS)
		computeTransversalFactor(6),
		computeTransversalFactor(7),
		computeTransversalFactor(8),
		computeTransversalFactor(9),
		computeTransversalFactor(10),
#endif
	};
	STATICARRAY const float longitudinalFactor[kernelSize * 2 + 1] = {
#if defined(EA_PLATFORM_WINDOWS)
		computeLongitudinalFactor(-10),
		computeLongitudinalFactor(-9),
		computeLongitudinalFactor(-8),
		computeLongitudinalFactor(-7),
		computeLongitudinalFactor(-6),
#endif
		computeLongitudinalFactor(-5),
		computeLongitudinalFactor(-4),
		computeLongitudinalFactor(-3),
		computeLongitudinalFactor(-2),
		computeLongitudinalFactor(-1),
		computeLongitudinalFactor(0),
		computeLongitudinalFactor(1),
		computeLongitudinalFactor(2),
		computeLongitudinalFactor(3),
		computeLongitudinalFactor(4),
		computeLongitudinalFactor(5),
#if defined(EA_PLATFORM_WINDOWS)
		computeLongitudinalFactor(6),
		computeLongitudinalFactor(7),
		computeLongitudinalFactor(8),
		computeLongitudinalFactor(9),
		computeLongitudinalFactor(10),
#endif
	};
#endif // #if defined(EA_PLATFORM_PS3)

	float3 result = 0;
	for (int i = -kernelSize; i <= kernelSize; i++)
	{
		float2 texCoord = In.TexCoord + i * direction * oneOverTextureSize;
		
		// For the "separable blur" in two passes, we want to modulate always both x and y distortion
		// by the transversal wave factor (that causes the bell shape of the wave),
		// but also during the horizontal pass we want to apply the longitudinal factor to the x component,
		// and in the vertical pass to the y component.
		float3 factor = float3(lerp(1, longitudinalFactor[i+kernelSize], direction), 1) * transversalFactor[i+kernelSize];
		
		float3 val = tex2D(SAMPLER(DisplacementTexture), texCoord).xyz; 
#if defined(EA_PLATFORM_XENON) // scale range on xenon (scale up to full range float)
		val.xy = val.xy * 2 - 1;
#endif
		result += val * factor; 
	}

#if defined(EA_PLATFORM_PS3)

	// Compute the divider term, by combining the following math into a mul and add (include scaling of the xy)
	float3 divider = kernelSize * float3(4.0, 4.0, 2.0) + float3(2.0, 2.0, 1.0);
	result /= divider;

#else // #if defined(EA_PLATFORM_PS3)
	result /= kernelSize * 2 + 1;

	result.xy /= 2;// decrease longitudinal wave strength by arbitrary amount

#if defined(EA_PLATFORM_XENON) // scale range on xenon (reduce back to int)
	result.xy = result.xy * 0.5 + 0.5; 
#endif

#endif // #if defined(EA_PLATFORM_PS3)

	return float4(result,0);
}

float4 PS_BlurU(VSOutput_Blur In) : COLOR
{
	return PS_Blur(In, float2(1.0, 0.0));
}

float4 PS_BlurV(VSOutput_Blur In) : COLOR
{
	return PS_Blur(In, float2(0.0, 1.0));
}

technique BlurU
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_Blur();
		PixelShader = compile PS_3_0 PS_BlurU();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;		
		AlphaBlendEnable = false;	
		AlphaTestEnable = false;
	}
}

technique BlurV
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_Blur();
		PixelShader = compile PS_3_0 PS_BlurV();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;		
		AlphaBlendEnable = false;	
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
struct VSOutput_StaticDisplacement
{
	float4 Position : POSITION;
	float2 StaticTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_StaticDisplacement VS_StaticDisplacement(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput_StaticDisplacement Out;	
	Out.Position = float4(Position, 1);
	TexCoord.y = 1 - TexCoord.y;
	Out.StaticTexCoord = mul(float4(TexCoord * 2 - 1, 0, 1), mul(ProjectionI, ViewI)).xy;
	return Out;
}

// ----------------------------------------------------------------------------

float4 PS_StaticDisplacement(VSOutput_StaticDisplacement In) : COLOR
{
//return float4(In.StaticTexCoord / 2000, 0, 0);
//	float3 dynamicDisplacement = tex2D(SAMPLER(DisplacementTexture), In.TexCoord).xyz;


// -------------------------------------------------------------------------------
// -- Static Displacment and Mapping ---------------------------------------------
// -------------------------------------------------------------------------------

	// Build Static Tex coords ---------------------------------------------------
	float StaticDispDivergenceAngle = 75;
	float StaticDispScalar = 2; // create a more managable number in MAX sliders
	float StaticDispSpeed = Time * 45; // animate Octave 3 as a multiplier of Time
	float2 StaticDispTexCoords = In.StaticTexCoord * StaticDispScalar;

	// Precompute the UV coord rotation for StaticDispDivergenceAngle = 75;
	// It should be uvCoordRotate = { cosAngle, -sinAngle,
	//								  sinAngle, cosAngle };
	float2x2 uvCoordRotate = {	0.258819045102f, -0.965925826289f, 
								0.965925826289f,  0.258819045102f };

	// Rotate and Animate StaticDisp Divergence Texture Coords --------------------
	float2 StaticDispTexCoordsDiverge = mul(StaticDispTexCoords, uvCoordRotate);
	StaticDispTexCoordsDiverge.x += StaticDispSpeed;
	float2 StaticDispTexCoordsDivergeInv = mul(StaticDispTexCoords, transpose(uvCoordRotate));	
	StaticDispTexCoordsDivergeInv.x += StaticDispSpeed;

#if defined(EA_PLATFORM_PS3)

	// Optimization to do the same calculations as pc, except using multiplier of 1/4000 as the texcoord, as our source texture is half size
	const float SCALE_FACTOR = 0.0004; // 1/2500
	float staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDiverge * SCALE_FACTOR).w 
								+ tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDivergeInv * SCALE_FACTOR).w;

	// combine the math for *2-2 and *0.06 together
	float4 factor = float4(0.12, 0.12, 0.12, 0.0);
	return staticDisplacement * factor - factor;

#else // #if defined(EA_PLATFORM_PS3)

	float staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDiverge / 2000).w * 2 - 1;
	staticDisplacement += tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDivergeInv / 2000).w * 2 - 1;

	float displacement = staticDisplacement *.06;

#if defined(EA_PLATFORM_XENON) // scale range on xenon
	return float4(displacement * 0.5, displacement * 0.5, displacement, 0); 
#else
	return float4(displacement, displacement, displacement, 0); 
#endif

#endif // #if defined(EA_PLATFORM_PS3)
}

technique StaticDisplacement
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_StaticDisplacement();
		PixelShader = compile PS_3_0 PS_StaticDisplacement();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;		
		AlphaTestEnable = false;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
	}
}

// ----------------------------------------------------------------------------
struct VSOutput_DebugDisplayDisplacement
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_DebugDisplayDisplacement VS_DebugDisplayDisplacement(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput_DebugDisplayDisplacement Out;
	Out.Position = float4(Position * float3(0.5, 2./3., 0), 1);
	Out.TexCoord = TexCoord;// / 3 + 0.5;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_DebugDisplayDisplacement(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(DisplacementTexture), TexCoord);
	return float4(color.xyz * 0.5 + 0.5, 1);
}

// ----------------------------------------------------------------------------
technique DebugDisplayDisplacement
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_DebugDisplayDisplacement();
		PixelShader = compile PS_3_0 PS_DebugDisplayDisplacement();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
		SrcBlend = One;
		DestBlend = One;
		
		//ColorWriteEnable = 0;
	}  
}

struct VSOutput_DownSample
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_DownSample VS_DownSample(float2 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput_DownSample Out;
	Out.Position = float4(Position, 0, 1);
	Out.TexCoord = TexCoord;
	// Invert Y so it match the vertex data
	Out.TexCoord.y = 1.0 - TexCoord.y;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_DownSample(VSOutput_DownSample In) : COLOR
{
	float4 color = tex2D(SAMPLER(DisplacementTexture), In.TexCoord); 
	return color;
}

// ----------------------------------------------------------------------------
technique Downsample
{
	pass p0
	{
		VertexShader = compile VS_2_0 VS_DownSample();
		PixelShader = compile PS_2_0 PS_DownSample();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}
