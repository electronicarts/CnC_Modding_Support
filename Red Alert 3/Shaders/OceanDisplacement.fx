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

float DisplacementTextureSize
<
	string SasBindAddress = "Water.DisplacementTextureSize";
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
	float Amplitude : TEXCOORD0;
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
	
		// Note: If this formula or the fadeOutFactor changes, external code should be changed as well, so that the actual particle deletion occurs at the correct time.
		amplitude *= exp(-age / fadeOutFactor);
		// amplitude /= (age + 1); // Alternative to try out
		
		amplitude *= saturate(age / fadeInTime);
	}
	
	// Transform position from world space into the render target's space
	float2 positionXY = mul(float4(position, 0, 1), GetViewProjection()).xy;

	VSOutput_RenderWaveParticles Out;
	Out.Position = float4(positionXY, 0, 1);
	Out.Amplitude = min(amplitude,1);
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_RenderWaveParticles(VSOutput_RenderWaveParticles In) : COLOR
{
#if defined(EA_PLATFORM_XENON) // scale range on xenon
	float4 color = float4(In.Amplitude * 0.5, In.Amplitude * 0.5, In.Amplitude, 0);
#else
	float4 color = float4(In.Amplitude, In.Amplitude, In.Amplitude, 0);
#endif
#if defined(EA_PLATFORM_XENON) // divide by 4 since we divide the texture area by 4 on xenon
	color /= 4;
#endif
	return color;
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
	static const float textureSize = DisplacementTextureSize;
	float3 result = 0;
	for (int j = -kernelSize; j <= kernelSize; j++)
		for (int i = -kernelSize; i <= kernelSize; i++)
		{
			float2 texCoord = In.TexCoord + float2(i, j) /* * direction */ / textureSize;
			
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
static const float pi = 3.14159265;

float computeTransversalFactor( float index )
{
	return 0.5 * (cos(pi * index / radius) + 1);
}
float computeLongitudinalFactor( float index )
{
	return -sin(pi * index / radius) * radius;
}

float4 PS_Blur(VSOutput_Blur In, uniform float2 direction) : COLOR
{
	STATICARRAY const float textureSize = DisplacementTextureSize;
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

	float3 result = 0;
	for (int i = -kernelSize; i <= kernelSize; i++)
	{
		float2 texCoord = In.TexCoord + i * direction / textureSize;
		
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
	result /= kernelSize * 2 + 1;

	result.xy /= 2;// decrease longitudinal wave strength by arbitrary amount

#if defined(EA_PLATFORM_XENON) // scale range on xenon (reduce back to int)
	result.xy = result.xy * 0.5 + 0.5; 
#endif

	return float4(result,0);
}

technique BlurU
{
	pass p0
	{
		VertexShader = compile VS_3_0 VS_Blur();
		PixelShader = compile PS_3_0 PS_Blur(float2(1.0, 0.0));

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
		PixelShader = compile PS_3_0 PS_Blur(float2(0.0, 1.0));

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
	float2 TexCoord : TEXCOORD0;
	float2 StaticTexCoord : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_StaticDisplacement VS_StaticDisplacement(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput_StaticDisplacement Out;	
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	
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

	// Build StaticDisp Texture Rotation Matrix And Convert Degrees to Radians --
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	sincos (StaticDispDivergenceAngle * .017453, sinAngle, cosAngle);
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate StaticDisp Divergence Texture Coords --------------------
	float2 StaticDispTexCoordsDiverge = mul(StaticDispTexCoords, uvCoordRotate);
	StaticDispTexCoordsDiverge.x += StaticDispSpeed;
	float2 StaticDispTexCoordsDivergeInv = mul(StaticDispTexCoords, transpose(uvCoordRotate));	
	StaticDispTexCoordsDivergeInv.x += StaticDispSpeed;

	float staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDiverge / 2000).w * 2 - 1;
	staticDisplacement += tex2D(SAMPLER(StaticDisplacementTexture), StaticDispTexCoordsDivergeInv / 2000).w * 2 - 1;

	float displacement = staticDisplacement *.06;

#if defined(EA_PLATFORM_XENON) // scale range on xenon
	return float4(displacement * 0.5, displacement * 0.5, displacement, 0); 
#else
	return float4(displacement, displacement, displacement, 0); 
#endif
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
