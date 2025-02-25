//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SOFT_PARTICLE 1

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

//--------------------------------- GENERAL STUFF --------------------------------------

// Transformations
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 View : View;

// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
struct ParticleVSOutput
{
	float4 Position             : POSITION;
	float2 ParticleTexCoord     : TEXCOORD0;
	float3 TangentToViewSpace0  : TEXCOORD1;
	float3 TangentToViewSpace1  : TEXCOORD2;
	float3 TangentToViewSpace2  : TEXCOORD3;
	DECLARE_SOFT_PARTICLE_VS_OUTPUT
	float4 Color                : TEXCOORD6; // Not in color register to have increased range from -1 to 1
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	5
#define ONE_OVER_PARTICLE_VOLUME_SCALE	0.2

// ----------------------------------------------------------------------------
ParticleVSOutput ParticleVertexShader(
	float4 StartPositionLifeInFrames : POSITION, 
	float4 StartVelocityCreationFrame : TEXCOORD0,
	float2 SeedAndIndex : TEXCOORD1)
{
	ParticleVSOutput Out;

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

	//zVector = -zVector;
	float3 Normal = cross(xVector, zVector);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	float3 worldTangent = -zVector;
	float3 worldBinormal = -xVector; // This is inverted to what the normal mapping particles do as screen space xy is upside down otherwise
	float3x3 zRotation3D = float3x3(float3(zRotationMatrix[0], 0), float3(zRotationMatrix[1], 0), float3(0, 0, 1));


	// Build 3x3 tranform from tangent to world space
	float3x3 tangentToWorldSpace = mul(transpose(zRotation3D), float3x3(-worldBinormal, -worldTangent, worldNormal));
	tangentToWorldSpace = mul(tangentToWorldSpace, (float3x3)View);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];
	
	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier) + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);

	// Finish projecting the position.
	float4 ndcPos   = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Position    = ndcPos;

#if SUPPORT_SOFT_PARTICLE
	SOFT_PARTICLE_GENERATE_VS_OUTPUT(Out, cornerPosition, ndcPos, size, PARTICLE_VOLUME_SCALE);
#endif // #if SUPPORT_SOFT_PARTICLE
	
	// compute color
	float4 color = Particle_ComputeColor(relativeAge, Seed, true);
	color.xyz = color.xyz * 2.0 - 1.0; // Unpack to treat the color as normal	
	Out.Color = color;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput In, uniform int blendMode) COLORTARGET
{
	float4 normalMapSample = tex2D( SAMPLER(NormalTexture), In.ParticleTexCoord);

	// Get bump map normal
	float3 bumpNormal = normalMapSample.xyz * 2.0 - 1.0;	
	bumpNormal = normalize(bumpNormal);	
	float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	float3 normal = mul(bumpNormal, TangentToViewSpace);
	float4 Color = float4(In.Color.xyz * normal * 0.5 + 0.5, In.Color.w * normalMapSample.w);

#if SUPPORT_SOFT_PARTICLE
	float linearBlend = SOFT_PARTICLE_GET_LINEAR_BLEND(In);
	ApplySoftParticleBlend(blendMode, linearBlend, Color);
#endif // #if SUPPORT_SOFT_PARTICLE

	return Color;
}



// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
float4 ParticlePixelShader_Xenon(ParticleVSOutput In) : COLOR
{
	return SoftParticlePixelShader(In, ShouldDrawParticleSoft?SOFTBLEND_ALPHA:SOFTBLEND_DISABLED);
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

		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
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

		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
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