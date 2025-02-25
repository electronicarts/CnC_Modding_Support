//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader, accumulated lighting
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "CommonParticle.fxh"

// ----------------------------------------------------------------------------
// draw params
// ----------------------------------------------------------------------------
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

//--------------------------------- GENERAL STUFF --------------------------------------
// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// Transformations
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 View : View;

// Time (ie. material is animated)
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
struct ParticleVSOutput
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
//	float3 Fog : TEXCOORD2; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
	float Depth : TEXCOORD3; // For _CreateShadowMap technique
};

// ----------------------------------------------------------------------------
ParticleVSOutput ParticleVertexShader(
	float4 StartPositionLifeInFrames : POSITION, 
	float4 StartVelocityCreationFrame : TEXCOORD0,
	float2 SeedAndIndex : TEXCOORD1,
	uniform int fogMode)
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
	Out.Depth = Out.Position.z / Out.Position.w;
/*
	//zVector = -zVector;
	float3 Normal = cross(xVector, zVector);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	float3 worldTangent = -zVector;
	float3 worldBinormal = xVector;
	
	float3x3 zRotation3D = float3x3(float3(zRotationMatrix[0], 0), float3(zRotationMatrix[1], 0), float3(0, 0, 1));

	// Build 3x3 tranform from object to world space
	float3x3 particleToWorldSpace = mul(transpose(zRotation3D), float3x3(-worldBinormal, -worldTangent, worldNormal));

	// Build normal for particle vertex
	static const float flattenNormal = 1.0; // 0 = totally flat, 1 = sphere normal
	float3 normal = float3(vertexCorner * float2(2, 2) * flattenNormal, 0);
	normal.z =  1.0 - sqrt(0.5*(normal.x * normal.x + normal.y * normal.y));
	float3 vertexWorldNormal = normalize(mul(normal, particleToWorldSpace));
*/
#if defined(EA_PLATFORM_PS3)
	Out.Color = 1.0.xxxx;
#else // #if defined(EA_PLATFORM_PS3)
	// Compute directional lights
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 lightColor = DirectionalLight[i].Color;
		diffuseLight += lightColor;
	}
	diffuseLight *= 1.0f / float(NumDirectionalLights);
	Out.Color = float4(diffuseLight, 1);
#endif // #if defined(EA_PLATFORM_PS3)


//	if (fogMode != FogMode_Disabled)
//	{
//		// Fog depends on world position, but world matrix should be identity.
//		Out.Fog = CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
//	}
//	else
//	{
//		Out.Fog = 0;
//	}

	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * Draw.VideoTex_NumPerRow_LastFrame_SingleRow_isRand.y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * Draw.SpeedMultiplier + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	//float2 texRange = {-1.0f,1.0f};
	texCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);
	float texWarp = 0.15f;
//	float2 texRange = float2(-texWarp,texWarp * 2.0f);
	float rand1 = GetRandomFloatValue(float2(0.5f,1.0f),vertexCorner, Seed);
	float rand2 = sign(GetRandomFloatValue(float2(-1.0f,2.0f),vertexCorner, Seed + 10.0f)) * texWarp;
	float rand3 = GetRandomFloatValue(float2(0.5f,1.0f),vertexCorner, Seed + 20.0f);
	float rand4 = sign(GetRandomFloatValue(float2(-1.0f,2.0f),vertexCorner, Seed + 30.0f))* texWarp;
	rand3 *= rand4;
	rand1 *= rand2;
	float wiggle = relativeAge;
	texCoord.x = texCoord.x + lerp(0.0f,rand1,wiggle);
	texCoord.y = texCoord.y + lerp(0.0f,rand3,wiggle);
	Out.ParticleTexCoord = texCoord;
	Out.Color *= Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In, uniform int fogMode) COLORTARGET
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	TextureColor.xyz = GammaToLinear(TextureColor.xyz);

	float4 color = In.Color * TextureColor;
	
//	float3 fogStrength = saturate(In.Fog);
//	if (fogMode == FogMode_Opaque)
//	{		
//		// apply fog
//		Color.xyz = lerp(Fog.Color, Color.xyz, fogStrength);
//	}
//	else if (fogMode == FogMode_Additive)
//	{
//	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
//		Color.xyz *= fogStrength;
//	}
		// The ColorScale input is actually used as an offset...
		// Fade out offset over time, so that additive particles can still reach black at the end of their lifetime.
//		float randomColorOffset = GetRandomFloatValue(Draw.ColorScaleRange, particleSeed, 4);
//		color = saturate(color + float4(randomColorOffset.xxx, 0.0f) * (1 - relativeAge));
		color *= float4(Draw.ColorScaleRange.xxx,1.0f);
	return color ;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader_Xenon( ParticleVSOutput In ) : COLOR
{
	return ParticlePixelShader( In, Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: DEFAULT
// ----------------------------------------------------------------------------
#define PS_ShaderType \
	compile PS_2_0 ParticlePixelShader(FogMode_Disabled), \
	compile PS_2_0 ParticlePixelShader(FogMode_Opaque), \
	compile PS_2_0 ParticlePixelShader(FogMode_Additive)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_ShaderType
};
#endif

// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader(FogMode_Opaque);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
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

#if ENABLE_LOD

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

	float3 xVector = float3( View[0][0], View[1][0], View[2][0] );
	float3 zVector = float3( View[0][1], View[1][1], View[2][1] );
	float3 cornerPosition = particlePosition + size * (relativeCornerPos.x * xVector + relativeCornerPos.y * zVector);

	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);

	// texture coordinate
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(age * Draw.SpeedMultiplier, texCoord);

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
technique _Default_L
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
// SHADER: ShadowMap
// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(ParticleVSOutput In, uniform int shaderType) COLORTARGET
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
float4 CreateShadowMapPS_Xenon( ParticleVSOutput In ) : COLOR
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
		VertexShader = compile VS_2_0 ParticleVertexShader(FogMode_Disabled);
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