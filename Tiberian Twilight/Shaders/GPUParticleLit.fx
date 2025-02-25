//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

// Disable CPU particle processing until we get the kinks worked out.
// #define USE_PARTICLE_PROCESSOR

#define SUPPORT_GLOBAL_LIGHTS 1

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
	float4 Color                : TEXCOORD2; // Not in color register to have increased range, which could be > 1 for HDR
	float Depth                 : TEXCOORD3; // For _CreateShadowMap technique
};

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

#if defined(USE_PARTICLE_PROCESSOR)
	// The particle processor already calculates the full world position of the particle and puts it in the VB.
	// TODO: put all other output parameters into the VB as well
	cornerPosition = StartPosition;
#endif
	
	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Depth = Out.Position.z / Out.Position.w;

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
/* this stuff depends on the radius of our "sphere" being 1, 
but since our corner vertex is at 1,1 if we multiply the original vertices (.5,.5) by 2 the radius is actually 
1.4142. I scaled down the vertex multiplier to make the radius = 1
	instead of 
	float3 normal = float3(vertexCorner * float2(-2, 2) * flattenNormal, 0);
*/
	float3 normal = float3(vertexCorner * float2(-1.4142, 1.4142) * flattenNormal, 0);
	normal.z =  sqrt(1.0 - normal.x * normal.x - normal.y * normal.y);
	float3 vertexWorldNormal = normalize(mul(normal, particleToWorldSpace));

	// Compute directional lights
	float3 diffuseLight = 0;
	if (NumDirectionalLights > 0)
	{
		diffuseLight += DirectionalLight_0_Color.xyz * max(0, dot(vertexWorldNormal, normalize(DirectionalLight_0_Direction.xyz)));
	}
	
	if (NumDirectionalLights > 1)
	{
		diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(vertexWorldNormal, normalize(DirectionalLight_1_Direction.xyz)));
	}
	
	if (NumDirectionalLights > 2)
	{
		diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(vertexWorldNormal, normalize(DirectionalLight_2_Direction.xyz)));
	}
	
	Out.Color = float4(diffuseLight, 1);

	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier) + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);
	Out.Color *= Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	TextureColor.xyz = GammaToLinear(TextureColor.xyz);

	float4 color = In.Color * TextureColor;

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

		SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);

	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: LowQuality
// ----------------------------------------------------------------------------
struct ParticleVSLowOutput
{
	float4 Position             : POSITION;
	float4 Color                : COLOR0;
	float2 ParticleTexCoord     : TEXCOORD0;
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