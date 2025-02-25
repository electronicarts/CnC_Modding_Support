//////////////////////////////////////////////////////////////////////////////
// 2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

//#define FORCE_PARTICLES_INTO_XY_PLANE // Define this for xy (ground) aligned instead of screen facing particles

#define SUPPORT_FOG 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "CommonParticle.fxh"

//
// draw params
//
SAMPLER_2D_BEGIN( ParticleTextureSampler,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// $Note(WSK) - We shouldn't need to use a different sampler, and it actually doesn't work on ps3
//                We should be able to do the same for pc and xenon but since they are close to final,
//				  we want to be safe and make this change for ps3 only
#if defined(EA_PLATFORM_PS3)
static const sampler2D NextFrameTextureSamplerSampler = ParticleTextureSamplerSampler;
#else // #if defined(EA_PLATFORM_PS3) 
SAMPLER_2D_BEGIN( NextFrameTextureSampler,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END
#endif // #if defined(EA_PLATFORM_PS3)

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

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// Transformations
float4x4 WorldView : WorldView;
float4x4 Projection: Projection;
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 View : View;
float4x4 ProjectionI : ProjectionInverse;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x3 ViewI          : ViewInverse;

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)


// Time (ie. material is animated)
float Time : Time;


float3 TransformParticleCornerInto3D(float2 relativeCornerPos)
{
#if defined(FORCE_PARTICLES_INTO_XY_PLANE)
	// Just treat 2D position as being 3D
	return float3(relativeCornerPos, 0);
#else
	// Bring 2D "particle space" into view space
	float3x2 transform = (float3x2)View;
	return mul(transform, relativeCornerPos);
#endif
}

// ----------------------------------------------------------------------------
// SHADER: HIGH ~ ULTRAHIGH
// ----------------------------------------------------------------------------
struct ParticleVSOutput_H
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
	float3 Fog : TEXCOORD1; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
	float Depth : TEXCOORD2; // For _CreateShadowMap technique
	float3 NextFrameTexCoord : TEXCOORD3; // for interpolating between two frames
	float4 NDCPosition : TEXCOORD4;
	float2 ZPositions : TEXCOORD5; // x is the particle z position, y is the ViewEyeDirection z component.
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	5

// For indexing the shader array based on what type of blend is needed for the particle draw type.
#define SOFTBLEND_ADDITIVE		0
#define SOFTBLEND_ALPHA			1
#define SOFTBLEND_DISABLED		2

// ----------------------------------------------------------------------------
ParticleVSOutput_H ParticleVertexShader_H(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1,
		uniform int fogMode)
{
	ParticleVSOutput_H Out;

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
		Index = 0;
	float relativeAge = age / LifeInFrames; 	
		
	float3 particlePosition;
	float size;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics(particlePosition, size, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float3 cornerPosition = particlePosition + size * TransformParticleCornerInto3D(relativeCornerPos);
	
	// Convert the particle position into view space so that we can get the distance
	// between the particle and the background.
	float particleSize = size / PARTICLE_VOLUME_SCALE;
	float4 particlePosView = mul(float4(cornerPosition, 1), WorldView);
	Out.ZPositions.x = particlePosView.z / particleSize;
	
	// Finish projecting the position.
	float4 ndcPos = mul(particlePosView, Projection);
	Out.Position = ndcPos;
	Out.NDCPosition = ndcPos;
	Out.Depth = Out.Position.z / Out.Position.w;

	// Convert the position into a view vector to the far plane.
	float4 screenFarPlanePosition = float4(ndcPos.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	Out.ZPositions.y = (viewFarPlanePosition.z / viewFarPlanePosition.z) / particleSize;
	
	if (fogMode != FogMode_Disabled)
	{
		// Fog depends on world position, but world matrix should be identity.
		Out.Fog = CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
	}
	else
	{
		Out.Fog = 0;
	}

	Particle_ComputeVideoTexture(age, Seed, vertexCorner, GetVertexTexCoord(vertexCorner), Out.ParticleTexCoord, Out.NextFrameTexCoord);

	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput_H In, uniform int fogMode, uniform int blendMode) COLORTARGET
{
	float3 ndcPosition = In.NDCPosition.xyz / In.NDCPosition.w;

	// Convert the position into texture space then grab the depth value from the
	// depth texture. Then, move along that vector by the depth to find the pixel position.
	float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;
	float backgroundDepth = tex2D(SAMPLER(DepthTexture), depthTexCoord).x;
	float backgroundPosView = backgroundDepth * In.ZPositions.y;

	// The closer the particle is to the background, the more transparent it is.
	float linearBlend = saturate(In.ZPositions.x - backgroundPosView);

	// do interpolation between two frames (for particles with video textures)
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(NextFrameTextureSampler), In.NextFrameTexCoord.xy);
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;
	Color.xyz = GammaToLinear(Color.xyz);

	// Don't do soft particles for ground aligned particles, as they will often be almost fully transparent due to terrain proximity
#if !defined(FORCE_PARTICLES_INTO_XY_PLANE)
	// Modify the color (or alpha) of a the particle depending on how it's being drawn
	// so the particle has a soft edge to it.
	if (blendMode == SOFTBLEND_ALPHA)
	{
		Color.w *= linearBlend;
	}
	else if (blendMode == SOFTBLEND_ADDITIVE)
	{
		Color.xyz *= linearBlend;
	}
#endif

	// Apply fog
	float3 fogStrength = saturate(In.Fog) ;
	if (fogMode == FogMode_Opaque)
	{
		// apply fog
		Color.xyz = lerp(Fog.Color, Color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		Color.xyz *= fogStrength;
	}

	return Color;
}

// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
float4 ParticlePixelShader_Xenon(ParticleVSOutput_H In ) : COLOR
{
	return SoftParticlePixelShader( In, 
		Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
		!ShouldDrawParticleSoft ? SOFTBLEND_DISABLED : ((Draw.ShaderType == ShaderType_Alpha) ? SOFTBLEND_ALPHA : SOFTBLEND_ADDITIVE));
}

// ----------------------------------------------------------------------------
// TECHNIQUE: HIGH ~ ULTRAHIGH (And XENON)
// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_FogMode = 1 );

#define PS_FogMode_H(drawType) \
	compile PS_3_0 SoftParticlePixelShader(FogMode_Disabled, drawType), \
	compile PS_3_0 SoftParticlePixelShader(FogMode_Opaque, drawType), \
	compile PS_3_0 SoftParticlePixelShader(FogMode_Additive, drawType)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_ShaderType = PS_Multiplier_FogMode * 3 );

#define PS_ShaderType_H \
	PS_FogMode_H(SOFTBLEND_ADDITIVE), \
	PS_FogMode_H(SOFTBLEND_ALPHA), \
	PS_FogMode_H(SOFTBLEND_DISABLED)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final_H = PS_Multiplier_ShaderType * 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array_H[PS_Multiplier_Final_H] =
{
	PS_ShaderType_H
};
#endif

technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_3_0 ParticleVertexShader_H(FogMode_Opaque);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array_H,
			(!ShouldDrawParticleSoft ? SOFTBLEND_DISABLED : ((Draw.ShaderType == ShaderType_Alpha) ? SOFTBLEND_ALPHA : SOFTBLEND_ADDITIVE)) * PS_Multiplier_ShaderType
			+ (Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled),
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);
	}
}

// ----------------------------------------------------------------------------
// SHADER: MEDIUM
// ----------------------------------------------------------------------------
struct ParticleVSOutput_M
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
	float3 Fog : TEXCOORD1; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
	float Depth : TEXCOORD2; // For _CreateShadowMap technique
	float3 NextFrameTexCoord : TEXCOORD3; // for interpolating between two frames
};

// ----------------------------------------------------------------------------
ParticleVSOutput_M ParticleVertexShader_M(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1,
		uniform int fogMode)
{
	ParticleVSOutput_M Out;

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
		Index = 0;
	float relativeAge = age / LifeInFrames; 	
		
	float3 particlePosition;
	float size;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics(particlePosition, size, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float3 cornerPosition = particlePosition + size * TransformParticleCornerInto3D(relativeCornerPos);
	
	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Depth = Out.Position.z / Out.Position.w;

	if (fogMode != FogMode_Disabled)
	{
		// Fog depends on world position, but world matrix should be identity.
		Out.Fog = CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
	}
	else
	{
		Out.Fog = 0;
	}

	Particle_ComputeVideoTexture(age, Seed, vertexCorner, GetVertexTexCoord(vertexCorner), Out.ParticleTexCoord, Out.NextFrameTexCoord);
 
	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput_M In, uniform int fogMode) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(NextFrameTextureSampler), In.NextFrameTexCoord.xy);

	// do interpolation between two frames (for particles with video textures)
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;

	// Apply fog
	float3 fogStrength = saturate(In.Fog) ;
	if (fogMode == FogMode_Opaque)
	{		
		// apply fog
		Color.xyz = lerp(Fog.Color, Color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		Color.xyz *= fogStrength;
	}

	return Color;
}

// Having this ensures that xenon doesn't load techniques that it doesn't use.
// This has to be below the medium functions because that is used for the shadowmap.
#if ENABLE_LOD

// ----------------------------------------------------------------------------
// TECHNIQUE: MEDIUM
// ----------------------------------------------------------------------------
#define PS_ShaderType_M \
	compile PS_2_0 ParticlePixelShader(FogMode_Disabled), \
	compile PS_2_0 ParticlePixelShader(FogMode_Opaque), \
	compile PS_2_0 ParticlePixelShader(FogMode_Additive)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final_M = 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array_M[PS_Multiplier_Final_M] =
{
	PS_ShaderType_M
};
#endif

technique Default_M
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader_M(FogMode_Opaque);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array_M,
			Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);
			}
}

// ----------------------------------------------------------------------------
// SHADER: LowQuality
// ----------------------------------------------------------------------------
struct ParticleVSLowOutput
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
};

// ----------------------------------------------------------------------------
ParticleVSLowOutput ParticleVertexShaderLow(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1)
{
	ParticleVSLowOutput Out;

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
		Index = 0;
	float relativeAge = age / LifeInFrames; 	


	float3 particlePosition;
	float size;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics_Simplified(particlePosition, size, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float3 cornerPosition = particlePosition + size * TransformParticleCornerInto3D(relativeCornerPos);

	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);

	// texture coordinate
	Particle_ComputeVideoTextureNoNextFrame(age, Seed, GetVertexTexCoord(vertexCorner), Out.ParticleTexCoord);

	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, false);
			
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShaderLow(ParticleVSLowOutput In) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 Color = TextureColor * In.Color;
	return Color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: LowQuality
// ----------------------------------------------------------------------------
technique Default_L
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShaderLow();
		PixelShader = compile PS_2_0 ParticlePixelShaderLow();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);
	}
}

#endif // #if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMap
// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(ParticleVSOutput_M In, uniform int shaderType) COLORTARGET
{
	float4 textureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 color = textureColor * In.Color;

	// Threshold where "alpha testing" or color equivalents set pixel to be opaque.
	// Needs to be much lower than common alpha test threshold as a single particle is usually quite transparent.
	const float opacityThreshold = 0.1;
	
	if (shaderType == ShaderType_Additive)
	{
		// The brighter the color the denser the particle. Clip dark areas.
		clip(dot(color, float3(1, 1, 1)) - 3 * opacityThreshold);
	}
	else if (shaderType == ShaderType_Multiply)
	{
		// The darker the color the denser the particle. Clip bright areas.
		clip(3 * opacityThreshold - dot(color, float3(1, 1, 1)));
	}
	else if (shaderType == ShaderType_AdditiveAlphaTest || shaderType == ShaderType_Alpha
			|| shaderType == ShaderType_AlphaTest)
	{
		// Simulate alpha testing
		clip(color.a - opacityThreshold);
	}

	return In.Depth;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon( ParticleVSOutput_M In ) : COLOR
{
	return CreateShadowMapPS( In, min(Draw.ShaderType, ShaderType_Multiply) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ----------------------------------------------------------------------------
#define PSCreateShadowMap_ShaderType \
	compile PS_2_0 CreateShadowMapPS(0), \
	compile PS_2_0 CreateShadowMapPS(ShaderType_Additive), \
	compile PS_2_0 CreateShadowMapPS(ShaderType_AdditiveAlphaTest), \
	compile PS_2_0 CreateShadowMapPS(ShaderType_Alpha), \
	compile PS_2_0 CreateShadowMapPS(ShaderType_AlphaTest), \
	compile PS_2_0 CreateShadowMapPS(ShaderType_Multiply)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = 6 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_ShaderType
};
#endif

// ----------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("GPUParticle_CreateShadowMap")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader_M(FogMode_Disabled);
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			min(Draw.ShaderType, ShaderType_Multiply),
			compile PS_VERSION CreateShadowMapPS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = None;	
		AlphaBlendEnable = false;		
		AlphaTestEnable = false; // Handled in pixel shader
	}
}