//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// GPU geometry particle with two perpendicular quads and the pivot point in the bottom
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SOFT_PARTICLE 1

// Windows shader compiler runs out of vertex shader constants on this shader.
// Save some constants by not declare the indirect constant range for skinning.
// This is safe to do, because the next skinned mesh that is rendered will have to set them up again anyway.
// Do not do this on Xenon though, as this causes debug errors about contentions of literal and user constants.
#if defined(EA_PLATFORM_WINDOWS)
#define NO_SKINNING_MATRICES
#endif

#include "Common.fxh"
#include "CommonParticle.fxh"

//
// Vertex data
//
// P - Is the pivot point for reference.
//
//  0            5  
//  | \        / |	 
//  |   \    /   |	                   +z
//  |     \/     |	                    |
//  |    /  \    |	                    |
//  |  4      \  |	                    |
//  |  |       1 |	         -x <-------+ 
//  3  |       | |	                     \
//    \|       | 6	                      \
//     |\      /	                       \
//     |  \P / |	                       +y
//     |   /\  |	
//     | /    \|
//     7       2
//

float3 fixup(float3 p)
{
	return -p.xyz + float3(0.5, 0, 0);
}

STATICARRAY const float3 GEOMETRY_VERTEX_CORNERS[MAX_VERTICES_PER_PARTICLE] =
{
// $note (WSK) 2008/10/16 - we need to expand this explicitly
#if defined(EA_PLATFORM_PS3)	
	// First horizontal quad.
	float3( 1.0,  0.5,  0.0),
	float3( 1.0, -0.5,  0.0),
	float3( 0.0, -0.5,  0.0),
	float3( 0.0,  0.5,  0.0),

	// Second vertical quad.
	float3( 1.0,  0.0,  0.5),
	float3( 1.0,  0.0, -0.5),
	float3( 0.0,  0.0, -0.5),
	float3( 0.0,  0.0,  0.5),
#else // #if defined(EA_PLATFORM_PS3)	
	// First horizontal quad.
	fixup(float3(-0.5, -0.5, 0)),
	fixup(float3(-0.5, 0.5, 0)),
	fixup(float3(0.5, 0.5, 0)),
	fixup(float3(0.5, -0.5, 0)),
	
	// Second vertical quad.
	fixup(float3(-0.5, 0, -0.5)),
	fixup(float3(-0.5, 0, 0.5)),
	fixup(float3(0.5, 0, 0.5)),
	fixup(float3(0.5, 0, -0.5)),
#endif // #if defined(EA_PLATFORM_PS3)	
	
	// NOT USED
	float3(0.0f, 0.0f, 0.0f)
};

STATICARRAY const float2 GEOMETRY_VERTEX_TEXCOORDS[MAX_VERTICES_PER_PARTICLE] =
{
	// First horizontal quad.
	float2(0.0f, 0.0f),
	float2(0.0f, 1.0f),
	float2(1.0f, 1.0f),
	float2(1.0f, 0.0f),
	
	// Second vertical quad.
	float2(0.0f, 0.0f),
	float2(0.0f, 1.0f),
	float2(1.0f, 1.0f),
	float2(1.0f, 0.0f),
	
	// NOT USED
	float2(0.0f, 0.0f)
};


#include "CommonGeometryParticle.fxh"


// ----------------------------------------------------------------------------
// TECHNIQUE: HIGH ~ ULTRAHIGH (And XENON)
// ----------------------------------------------------------------------------


technique Default
{
	pass P0
	<
	USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array_H, (GeometryUpdate_RotationType - 1), 
			compile VS_VERSION ParticleVertexShader_Xenon() 
		);
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


#if ENABLE_LOD

// ----------------------------------------------------------------------------
// TECHNIQUE: LOW
// ----------------------------------------------------------------------------

technique Default_L
{
	pass P0
	<
	USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array_L, (GeometryUpdate_RotationType - 1), NULL );
		PixelShader = compile PS_2_0 ParticlePixelShader_L();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
	}
}




#endif // #if ENABLE_LOD



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

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMap
// ----------------------------------------------------------------------------
ParticleVSOutput_M CreateShadowMapVS(float4 StartPositionLifeInFrames : POSITION, 
														float4 StartVelocityCreationFrame : TEXCOORD0, 
														float2 SeedAndIndex : TEXCOORD1)
{
	return ParticleVertexShader_M(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, FogMode_Disabled);
}

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
		VertexShader = compile VS_2_0 CreateShadowMapVS();
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
