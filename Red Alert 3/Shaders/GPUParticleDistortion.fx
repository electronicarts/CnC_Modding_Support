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
	
	string RenderBin = "Distorter";
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

// Used to see where the particle volume intersects an object.
SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

//--------------------------------- GENERAL STUFF --------------------------------------
bool ShouldDrawParticleSoft
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.ShouldDrawParticleSoft";
> = false;

// Transformations
float4x4 WorldView : WorldView;
float4x4 Projection: Projection;
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 View : View;
float4x3 World : World;
float4x4 ProjectionI : ProjectionInverse;

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
	float3x3 TangentToViewSpace : TEXCOORD2;
	float4 NDCPosition : TEXCOORD5;
	float2 ZPositions : TEXCOORD6; // x is the particle z position, y is the ViewEyeDirection z component.	
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	5

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
	float3 particlePosition;
	float size;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics(particlePosition, size, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);
	float3 xVector = float3( View[0][0], View[1][0], View[2][0] );
	float3 zVector = float3( View[0][1], View[1][1], View[2][1] );
	float3 cornerPosition = particlePosition + size * (relativeCornerPos.x * xVector + relativeCornerPos.y * zVector);
	
	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);

	//zVector = -zVector;
	float3 Normal = cross(xVector, zVector);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	float3 worldTangent = -zVector;
	float3 worldBinormal = -xVector; // This is inverted to what the normal mapping particles do as screen space xy is upside down otherwise
	float3x3 zRotation3D = float3x3(float3(zRotationMatrix[0], 0), float3(zRotationMatrix[1], 0), float3(0, 0, 1));


	// Build 3x3 tranform from tangent to world space
	float3x3 tangentToWorldSpace = mul(transpose(zRotation3D), float3x3(-worldBinormal, -worldTangent, worldNormal));
	Out.TangentToViewSpace = mul(tangentToWorldSpace, (float3x3)View);
	
	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * Draw.VideoTex_NumPerRow_LastFrame_SingleRow_isRand.y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * Draw.SpeedMultiplier + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);

	// Convert the particle position into view space so that we can get the distance
	// between the particle and the background.
	float particleSize = size / PARTICLE_VOLUME_SCALE;
	float4 particlePosView = mul(float4(cornerPosition, 1), WorldView);
	Out.ZPositions.x = particlePosView.z / particleSize;

	
	// Finish projecting the position.
	float4 ndcPos = mul(particlePosView, Projection);
	Out.Position = ndcPos;
	Out.NDCPosition = ndcPos;
	
	// Convert the position into a view vector to the far plane.
	float4 screenFarPlanePosition = float4(ndcPos.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;	
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	Out.ZPositions.y = (viewFarPlanePosition.z / viewFarPlanePosition.z) / particleSize;	
	
	// compute color
	float4 color = Particle_ComputeColor(relativeAge, Seed, true);
	color.xyz = color.xyz * 2.0 - 1.0; // Unpack to treat the color as normal	
	Out.Color = color;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput In, uniform bool shouldDrawParticleSoft) COLORTARGET
{
	float4 normalMapSample = tex2D( SAMPLER(NormalTexture), In.ParticleTexCoord);

	// Get bump map normal
	float3 bumpNormal = normalMapSample.xyz * 2.0 - 1.0;	
	bumpNormal = normalize(bumpNormal);	
	float3 normal = mul(bumpNormal, In.TangentToViewSpace);
	float4 color = float4(In.Color.xyz * normal * 0.5 + 0.5, In.Color.w * normalMapSample.w);

	if (shouldDrawParticleSoft)
	{
		float3 ndcPosition = In.NDCPosition.xyz / In.NDCPosition.w;

		// Convert the position into texture space then grab the depth value from the
		// depth texture. Then, move along that vector by the depth to find the pixel position.
		float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;
		float backgroundDepth = tex2D(SAMPLER(DepthTexture), depthTexCoord).x;
		float backgroundPosView = backgroundDepth * In.ZPositions.y;

		// The closer the particle is to the background, the more transparent it is.
		float linearBlend = saturate(In.ZPositions.x - backgroundPosView);

		// Don't do soft particles for ground aligned particles, as they will often be almost fully transparent due to terrain proximity
	#if !defined(FORCE_PARTICLES_INTO_XY_PLANE)
		color.w *= linearBlend;
	#endif
	}
	
	return color;
}



// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
float4 ParticlePixelShader_Xenon(ParticleVSOutput In) : COLOR
{
	return SoftParticlePixelShader(In, ShouldDrawParticleSoft);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (High and up)
// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_ShouldDrawParticleSoft_H = 1 );

#define PS_ShouldDrawParticleSoft_H \
	compile PS_2_0 SoftParticlePixelShader(false), \
	compile PS_2_0 SoftParticlePixelShader(true)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final_H = PS_Multiplier_ShouldDrawParticleSoft_H * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array_H[PS_Multiplier_Final_H] =
{
	PS_ShouldDrawParticleSoft_H
};
#endif

technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader();
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array_H,
			ShouldDrawParticleSoft,
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);
	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// TECHNIQUE: Default (Medium and up)
// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader();
		PixelShader = compile PS_2_0 SoftParticlePixelShader(false);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);
	}
}

// ----------------------------------------------------------------------------
// TECHNIQUE: LowQuality
// ----------------------------------------------------------------------------
technique Default_L
{
	// Disabled
}

#endif