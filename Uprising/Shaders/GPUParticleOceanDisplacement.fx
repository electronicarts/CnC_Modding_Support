//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonParticle.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	string RenderBin = "OceanDisplacement";
> = 0;

SAMPLER_2D_BEGIN( NormalTexture,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float4 ParticleMiscValues
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.MiscValues";
> = float4(1.0,1.0,1.0,1.0);

//--------------------------------- GENERAL STUFF --------------------------------------

// Transformations
float4x4 WorldViewProjection : WorldViewProjection;

// Time (ie. material is animated)
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
struct ParticleVSOutput
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : TEXCOORD1; // Not in color register to have increased range from -1 to 1
};

// ----------------------------------------------------------------------------
ParticleVSOutput ParticleVertexShader(
	float4 StartPositionLifeInFrames : POSITION, 
	float4 StartVelocityCreationFrame : TEXCOORD0,
	float2 SeedAndIndex : TEXCOORD1)
{
	ParticleVSOutput Out;

	// decode vertex data
	float3 StartPosition = StartPositionLifeInFrames.xyz; 
	float LifeInFrames = StartPositionLifeInFrames.w;
	float3 StartVelocity = StartVelocityCreationFrame.xyz;
	float CreationFrame = StartVelocityCreationFrame.w;
	float Seed = SeedAndIndex.x;
	float Index = SeedAndIndex.y;

	// particle system works with frames, so first convert time to frame
	// rather than converting everything else to time
	float age = (Time * CLIENT_FRAMES_PER_SECOND - CreationFrame);
	
	// first eliminate dead particles
	if (age > LifeInFrames)
	{
		Index = 0;
	}
	float relativeAge = age / LifeInFrames; 

	// Calculate the z rotation, before position and other values
	float dummy1;
	float3 dummy3;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics(dummy3, dummy1, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);
		
	// Rotatate StartVelocity by z rotation
	StartVelocity.xy = mul(StartVelocity.xy, zRotationMatrix);

	// Now calculate position based on rotated velocity
	float3 particlePosition;
	float size;
	float2x2 dummy2x2;
	float aspectRatio = ParticleMiscValues.x;
	
	Particle_ComputePhysics(particlePosition, size, dummy2x2,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];

	float2 velocityDir = normalize(StartVelocity.xy); // TODO: Take current velocity, not start velocity into account
	
	float2 xVector = float2(-velocityDir.y, velocityDir.x); // orthogonal to velocityDir
	float2 yVector = velocityDir;
	float2 cornerPosition = particlePosition + size * (vertexCorner.x * xVector * aspectRatio + vertexCorner.y * yVector);
	
	Out.Position = mul(float4(cornerPosition, 0, 1), WorldViewProjection);

	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * Draw.VideoTex_NumPerRow_LastFrame_SingleRow_isRand.y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * Draw.SpeedMultiplier + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);
	
	// compute color
	float4 color = Particle_ComputeColor(relativeAge, Seed, true);
	Out.Color = color;
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In) : COLOR
{
	float2 texCoord0 = In.ParticleTexCoord;	
	float4 displacementSample = tex2D( SAMPLER( NormalTexture ), texCoord0);

	float amplitude = In.Color.w;

#if defined(EA_PLATFORM_XENON) // scale range on xenon
	return float4(amplitude * 0.5, amplitude * 0.5, amplitude, 0) * displacementSample * 0.6; // want less static waves for now
#else
	return float4(amplitude, amplitude, amplitude, 0) * displacementSample;
#endif
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (Medium and up)
// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_3_0 ParticleVertexShader();
		PixelShader = compile PS_3_0 ParticlePixelShader();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		AlphaTestEnable = false;
	}
}

// ----------------------------------------------------------------------------
// TECHNIQUE: LowQuality
// ----------------------------------------------------------------------------
technique Default_L
{
	// Disabled
}
