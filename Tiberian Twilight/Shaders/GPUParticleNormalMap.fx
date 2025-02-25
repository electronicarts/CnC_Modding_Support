//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_CLOUDS 1
#define SUPPORT_GLOBAL_LIGHTS 1

#include "Common.fxh"
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

SAMPLER_2D_BEGIN( NormalTextureSampler,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.DetailTexture";
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
	float3 NextFrameTexCoord    : TEXCOORD1; // for interpolating between two frames
	float4 Color                : TEXCOORD2; // Not in color register to have increased range, which could be > 1 for HDR
	float Depth                 : TEXCOORD3; // For _CreateShadowMap technique
	float4 LightVector[NumDirectionalLights] : TEXCOORD5;
};

// ----------------------------------------------------------------------------
ParticleVSOutput ParticleVertexShader(
	float4 StartPositionLifeInFrames : POSITION, 
	float4 StartVelocityCreationFrame : TEXCOORD0,
	float2 SeedAndIndex : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
	
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
	Out.Depth = Out.Position.z / Out.Position.w;

	//zVector = -zVector;
	float3 Normal = cross(xVector, zVector);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	float3 worldTangent = -zVector;
	float3 worldBinormal = xVector;
	
	float3x3 zRotation3D = float3x3(float3(zRotationMatrix[0], 0), float3(zRotationMatrix[1], 0), float3(0, 0, 1));

	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = mul(transpose(float3x3(-worldBinormal, -worldTangent, worldNormal)), zRotation3D);
	if (NumDirectionalLights > 0)
	{
		Out.LightVector[0] = float4(mul(DirectionalLight_0_Direction.xyz, worldToTangentSpace), 0);
	}
	
	if (NumDirectionalLights > 1)
	{
		Out.LightVector[1] = float4(mul(DirectionalLight_1_Direction.xyz, worldToTangentSpace), 0);
	}
	
	if (NumDirectionalLights > 2)
	{
		Out.LightVector[2] = float4(mul(DirectionalLight_2_Direction.xyz, worldToTangentSpace), 0);
	}

	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).y;
	randomIndex -= frac(randomIndex);

	float currentTexFrame = age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier) + randomIndex;

	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);

	Out.NextFrameTexCoord.xy = Particle_ComputeVideoTextureDefault(currentTexFrame + 1.0, texCoord);
	Out.NextFrameTexCoord.z = frac(currentTexFrame);
	
	// compute color
	float4 Color = Particle_ComputeColor(relativeAge, Seed, true);
	
	Out.Color = Color;	
		
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In) : COLOR
{
	float4 Color = In.Color;
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(ParticleTextureSampler), In.NextFrameTexCoord.xy);

	// Get bump map normal
	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalTextureSampler), In.ParticleTexCoord) * 2.0 - 1.0;
	bumpNormal = normalize(bumpNormal * 10);
	float4 color = In.Color * TextureColor;// * 2;

	float3 diffuselighting = 0;
	diffuselighting += DirectionalLight_0_Color.xyz * NoCloudMultiplier * max(0, dot(bumpNormal, In.LightVector[0].xyz));
	diffuselighting += DirectionalLight_1_Color.xyz * NoCloudMultiplier * max(0, dot(bumpNormal, In.LightVector[1].xyz));
	diffuselighting += DirectionalLight_2_Color.xyz * NoCloudMultiplier * max(0, dot(bumpNormal, In.LightVector[2].xyz));
	color.xyz *= diffuselighting;
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: DEFAULT
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Particle")
	>
	{
		VertexShader = compile VS_2_0 ParticleVertexShader();
		PixelShader = compile PS_2_0 ParticlePixelShader();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);	}
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
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier), texCoord);

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
	
		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
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
float4 CreateShadowMapPS_Xenon( ParticleVSOutput In ) : COLOR
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
		VertexShader = compile VS_2_0 ParticleVertexShader();
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