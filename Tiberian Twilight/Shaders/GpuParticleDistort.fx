//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// GPU vertex particle FX Shader with 2 pass distortion
//////////////////////////////////////////////////////////////////////////////

// Disable CPU particle processing until we get the kinks worked out.
// #define USE_PARTICLE_PROCESSOR

#define SUPPORT_SOFT_PARTICLE 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "CommonParticle.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);

#if defined(USE_PARTICLE_PROCESSOR)
	// Use appropriate CPU processing class for the particle data
	string ParticleProcessor = "Default";
#endif
> = 0;

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

SAMPLER_2D_BEGIN( DetailTextureSampler,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.DetailTexture";
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
float4x3 View : View;

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

// ----------------------------------------------------------------------------
// SHADER: HIGH ~ ULTRAHIGH
// ----------------------------------------------------------------------------
struct ParticleVSOutput_H
{
	float4 Position             : POSITION;
	float2 ParticleTexCoord     : TEXCOORD0;
	float3 NextFrameTexCoord    : TEXCOORD1; // for interpolating between two frames
	float4 Color                : TEXCOORD2; // Not in color register to have increased range, which could be > 1 for HDR
	DECLARE_SOFT_PARTICLE_VS_OUTPUT
	float4 DisplaceTexCoord     : TEXCOORD6;
#if SUPPORT_FOG
	float3 Fog                  : TEXCOORD7; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
#endif // #if SUPPORT_FOG
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	5
#define ONE_OVER_PARTICLE_VOLUME_SCALE	0.2

// ----------------------------------------------------------------------------
ParticleVSOutput_H ParticleVertexShader_H(
		float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, 
		float2 SeedAndIndex : TEXCOORD1,
		uniform int fogMode)
{
	ParticleVSOutput_H Out;

	// decode vertex data
	float3 StartPosition    = StartPositionLifeInFrames.xyz; 
	float LifeInFrames      = StartPositionLifeInFrames.w;
	float3 StartVelocity    = StartVelocityCreationFrame.xyz;
	float CreationFrame     = StartVelocityCreationFrame.w;
	float Seed              = SeedAndIndex.x;
	float Index             = SeedAndIndex.y;

	float age;
	float relativeAge;

	Particle_ComputeAge(age, relativeAge, Index,
		CreationFrame, LifeInFrames);
		
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

#if defined(USE_PARTICLE_PROCESSOR)
	// The particle processor already calculates the full world position of the particle and puts it in the VB.
	// TODO: put all other output parameters into the VB as well
	cornerPosition = StartPosition;
#endif
	
	// Project the particle into world
	float4 ndcPos   = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Position    = ndcPos;

#if SUPPORT_SOFT_PARTICLE
	SOFT_PARTICLE_GENERATE_VS_OUTPUT(Out, cornerPosition, ndcPos, size, PARTICLE_VOLUME_SCALE);
#endif // #if SUPPORT_SOFT_PARTICLE
	
#if SUPPORT_FOG
	// Fog depends on world position, but world matrix should be identity.
	Out.Fog = (fogMode == FogMode_Disabled) ? 0 : CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
#endif // #if SUPPORT_FOG

	Particle_ComputeVideoTexture(age, Seed, vertexCorner, GetVertexTexCoord(vertexCorner), Out.ParticleTexCoord, Out.NextFrameTexCoord);
 
	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);
	
	// Build Displace Texture Rotation Matrix And Convert Degrees to Radians -----
	float DisplaceScalar = ParticleMiscValues.x;
	float DisplaceSpeed = ParticleMiscValues.y * Time;
	float DisplaceDivergenceAngle = ParticleMiscValues.z;
//	float DisplaceScalar = .1;
//	float DisplaceSpeed = .07 * Time;
//	float DisplaceDivergenceAngle = 45;
	
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	sincos (DisplaceDivergenceAngle * .017453, sinAngle, cosAngle);
					 
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];
	
	// Rotate and Animate Displace Divergence Texture Coords --------------------
	float2 texCoord = GetVertexTexCoord(vertexCorner);	
	float2 DisplaceTexCoords = texCoord * DisplaceScalar + Seed;	
	float2 DisplaceTexCoordsDiverge = mul(DisplaceTexCoords, uvCoordRotate);
	DisplaceTexCoordsDiverge.x += DisplaceSpeed;
	float2 DisplaceTexCoordsDivergeInv = mul(DisplaceTexCoords, transpose(uvCoordRotate));	
	DisplaceTexCoordsDivergeInv.x += DisplaceSpeed;	
	
	Out.DisplaceTexCoord = float4(DisplaceTexCoordsDiverge, DisplaceTexCoordsDivergeInv);
	return Out;
}

ParticleVSOutput_H ParticleVertexShader_H_FogMode_Opaque(float4 StartPositionLifeInFrames : POSITION, 
														float4 StartVelocityCreationFrame : TEXCOORD0, 
														float2 SeedAndIndex : TEXCOORD1)
{
	return ParticleVertexShader_H(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, FogMode_Opaque);
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput_H In, uniform int fogMode, uniform int blendMode) COLORTARGET
{
	float3 ndcPosition = In.NDCPosition.xyz / In.NDCPosition.w;

	//Grab the detail texture and displace primary texture coords according to normal
	float4 DetailColor = tex2D( SAMPLER(DetailTextureSampler), In.DisplaceTexCoord.xy) * 2 -1;
	DetailColor += tex2D( SAMPLER(DetailTextureSampler), In.DisplaceTexCoord.zw) * 2 - 1;
	
	DetailColor *= ParticleMiscValues.w;
	
	// do interpolation between two frames (for particles with video textures)
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord + DetailColor.xy);
	float4 NextFrameColor = tex2D( SAMPLER(ParticleTextureSampler), In.NextFrameTexCoord.xy + DetailColor.xy);
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;
	Color.xyz = GammaToLinear(Color.xyz);

#if SUPPORT_SOFT_PARTICLE
	float linearBlend = SOFT_PARTICLE_GET_LINEAR_BLEND(In);
	ApplySoftParticleBlend(blendMode, linearBlend, Color);
#endif // #if SUPPORT_SOFT_PARTICLE
	
#if SUPPORT_FOG
	// Apply fog
	ApplyFog(fogMode, In.Fog, Color);
#endif // #if SUPPORT_FOG

	return Color;
}

// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
float4 ParticlePixelShader_Xenon(ParticleVSOutput_H In ) : COLOR
{
	return SoftParticlePixelShader( In, GetParticleFogMode(), GetParticleBlendMode() );
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
		VertexShader = compile VS_3_0 ParticleVertexShader_H_FogMode_Opaque();
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array_H, (!ShouldDrawParticleSoft ? SOFTBLEND_DISABLED : ((Draw_ShaderType == ShaderType_Alpha) ? SOFTBLEND_ALPHA : SOFTBLEND_ADDITIVE)) * PS_Multiplier_ShaderType
#if SUPPORT_FOG
			+ (Fog.IsEnabled ? ((Draw_ShaderType == ShaderType_Additive || Draw_ShaderType == ShaderType_AdditiveAlphaTest || Draw_ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled),
#else // #if SUPPORT_FOG
			+ FogMode_Disabled,
#endif // #if SUPPORT_FOG
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
	}
}

// ----------------------------------------------------------------------------
// SHADER: MEDIUM
// ----------------------------------------------------------------------------
struct ParticleVSOutput_M
{
	float4 Position             : POSITION;
	float4 Color                : COLOR0;
	float2 ParticleTexCoord     : TEXCOORD0;
	float3 NextFrameTexCoord    : TEXCOORD1; // for interpolating between two frames
	float Depth                 : TEXCOORD2; // For _CreateShadowMap technique
#if SUPPORT_FOG
	float3 Fog                  : TEXCOORD3; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
#endif // #if SUPPORT_FOG
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

	float age;
	float relativeAge;

	Particle_ComputeAge(age, relativeAge, Index,
		CreationFrame, LifeInFrames);
		
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
	Out.Depth = Out.Position.z / Out.Position.w;

#if SUPPORT_FOG
	// Fog depends on world position, but world matrix should be identity.
	Out.Fog = (fogMode == FogMode_Disabled) ? 0 : CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
#endif // #if SUPPORT_FOG

	Particle_ComputeVideoTexture(age, Seed, vertexCorner, GetVertexTexCoord(vertexCorner), Out.ParticleTexCoord, Out.NextFrameTexCoord);
 
	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

ParticleVSOutput_M ParticleVertexShader_M_FogMode_Opaque(float4 StartPositionLifeInFrames : POSITION, 
														float4 StartVelocityCreationFrame : TEXCOORD0, 
														float2 SeedAndIndex : TEXCOORD1)
{
	return ParticleVertexShader_M(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, FogMode_Opaque);
}

ParticleVSOutput_M ParticleVertexShader_M_FogMode_Disabled(float4 StartPositionLifeInFrames : POSITION, 
														float4 StartVelocityCreationFrame : TEXCOORD0, 
														float2 SeedAndIndex : TEXCOORD1)
{
	return ParticleVertexShader_M(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, FogMode_Disabled);
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput_M In, uniform int fogMode) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(ParticleTextureSampler), In.NextFrameTexCoord.xy);

	// do interpolation between two frames (for particles with video textures)
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;

#if SUPPORT_FOG
	// Apply fog
	ApplyFog(fogMode, In.Fog, Color);
#endif // #if SUPPORT_FOG

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
		VertexShader = compile VS_2_0 ParticleVertexShader_M_FogMode_Opaque();
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array_M,
#if SUPPORT_FOG
			Fog.IsEnabled ? ((Draw_ShaderType == ShaderType_Additive || Draw_ShaderType == ShaderType_AdditiveAlphaTest || Draw_ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
#else // #if SUPPORT_FOG
			FogMode_Disabled,
#endif // #if SUPPORT_FOG
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
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

	float age;
	float relativeAge;

	Particle_ComputeAge(age, relativeAge, Index,
		CreationFrame, LifeInFrames);

	float3 particlePosition;
	float size;
	float2x2 zRotationMatrix;
	
	Particle_ComputePhysics_Simplified(particlePosition, size, zRotationMatrix,
		age, StartPosition, StartVelocity, Seed);

	// Calculate vertex position
	float2 vertexCorner = VertexCorners[Index];
	float2 relativeCornerPos = mul(vertexCorner, zRotationMatrix);

	float3 xVector = float3( View[0][0], View[1][0], View[2][0] );
	float3 zVector = float3( View[0][1], View[1][1], View[2][1] );
	float3 cornerPosition = particlePosition + size * (relativeCornerPos.x * xVector + relativeCornerPos.y * zVector);

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
		
		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
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
		clip(dot(color.xyz, float3(1, 1, 1)) - 3 * opacityThreshold);
	}
	else if (shaderType == ShaderType_Multiply)
	{
		// The darker the color the denser the particle. Clip bright areas.
		clip(3 * opacityThreshold - dot(color.xyz, float3(1, 1, 1)));
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
	return CreateShadowMapPS( In, min(Draw_ShaderType, ShaderType_Multiply) );
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
		VertexShader = compile VS_2_0 ParticleVertexShader_M_FogMode_Disabled();
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			min(Draw_ShaderType, ShaderType_Multiply),
			compile PS_VERSION CreateShadowMapPS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = None;	
		AlphaBlendEnable = false;		
		AlphaTestEnable = false; // Handled in pixel shader

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}