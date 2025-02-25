//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#define USE_INTERACTIVE_LIGHTS 1
#include "CommonParticle.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
float3 AmbientLightColor : Ambient = float3(0.1, 0.1, 0.1);
static const int NumDirectionalLights = 3;
SasDirectionalLight DirectionalLight[NumDirectionalLights]
<
	string SasBindAddress = "Sas.DirectionalLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_DIRECTIONAL_LIGHT_1,
	DEFAULT_DIRECTIONAL_LIGHT_2,
	DEFAULT_DIRECTIONAL_LIGHT_3
};
DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

static const int NumPointLights = 1;
SasPointLight PointLight[NumPointLights]
<
	string SasBindAddress = "Sas.PointLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_POINT_LIGHT_DISABLED
};

float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);

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

//--------------------------------- GENERAL STUFF --------------------------------------
WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// Transformations
float4x4 WorldViewProjection : WorldViewProjection;
float4x3 View : View;
float4x3 ViewI : ViewInverse;
float4x3 World : World;

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
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
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

	//zVector = -zVector;
	float3 Normal = cross(xVector, zVector);
	float3 worldNormal = normalize(mul(Normal, (float3x3)World));
	float3 worldTangent = -zVector;
	float3 worldBinormal = xVector;
	
	float3x3 zRotation3D = float3x3(float3(zRotationMatrix[0], 0), float3(zRotationMatrix[1], 0), float3(0, 0, 1));

	// Build 3x3 tranform from object to world space
	float3x3 particleToWorldSpace = mul(transpose(zRotation3D), float3x3(-worldBinormal, -worldTangent, worldNormal));

	// Build normal for particle vertex
	static const float flattenNormal = 5.0; // 0 = totally flat, 1 = sphere normal
	float3 normal = float3(vertexCorner * float2(-2, 2) * flattenNormal, 0);
	normal.z = sqrt(1.0 - normal.x * normal.x + normal.y * normal.y);
	float3 vertexWorldNormal = normalize(mul(normal, particleToWorldSpace));

	// Compute directional lights
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		float3 lightColor = DirectionalLight[i].Color;
		if (i == 0)
		{
			lightColor *= NoCloudMultiplier;
		}
		
		diffuseLight += lightColor * max(0, dot(vertexWorldNormal, DirectionalLight[i].Direction));
	}
	Out.Color = float4(diffuseLight, 1);


//	if (fogMode != FogMode_Disabled)
//	{
//		// Fog depends on world position, but world matrix should be identity.
//		Out.Fog = CalculateFog(Fog, cornerPosition, ViewI[3]).xxx;
//	}
//	else
//	{
//		Out.Fog = 0;
//	}

	// Texture coordinate
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * Draw.VideoTexture_NumPerRow_LastFrame.y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * Draw.SpeedMultiplier + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTexture(currentTexFrame, texCoord);
	Out.Color *= Particle_ComputeColor(relativeAge, Seed, true);
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In, uniform int fogMode) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
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
	return color;
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
	compile ps_2_0 ParticlePixelShader(FogMode_Disabled), \
	compile ps_2_0 ParticlePixelShader(FogMode_Opaque), \
	compile ps_2_0 ParticlePixelShader(FogMode_Additive)

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
		USE_EXPRESSION_EVALUATOR("ParticleWithFog")
	>
	{
		VertexShader = compile vs_2_0 ParticleVertexShader(FogMode_Opaque);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
			compile PS_VERSION ParticlePixelShader_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif

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
	Out.ParticleTexCoord = Particle_ComputeVideoTexture(age * Draw.SpeedMultiplier, texCoord);

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
		VertexShader = compile vs_1_1 ParticleVertexShaderLow();
		PixelShader = compile ps_1_1 ParticlePixelShaderLow();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;

		SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

#endif // #if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: ShadowMap
// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(ParticleVSOutput In, uniform int shaderType) : COLOR
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
	compile ps_2_0 CreateShadowMapPS(0), \
	compile ps_2_0 CreateShadowMapPS(ShaderType_Additive), \
	compile ps_2_0 CreateShadowMapPS(ShaderType_AdditiveAlphaTest), \
	compile ps_2_0 CreateShadowMapPS(ShaderType_Alpha), \
	compile ps_2_0 CreateShadowMapPS(ShaderType_AlphaTest), \
	compile ps_2_0 CreateShadowMapPS(ShaderType_Multiply)

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
		VertexShader = compile vs_2_0 ParticleVertexShader(FogMode_Disabled);
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
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}