//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// GPU vertex particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonParticle.fxh"

int _GlobalInfo : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int SortLevel = SortLevel_Distorter;
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
	float4 Color : TEXCOORD1; // Not in color register to have increased range from -1 to 1
	float3x3 TangentToViewSpace : TEXCOORD2;
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
	float randomIndex = GetRandomFloatValue(float2(0.0f, 1.0f), Seed, 7) * Draw.VideoTexture_NumPerRow_LastFrame.y;
	randomIndex -= frac(randomIndex);
	float currentTexFrame = age * Draw.SpeedMultiplier + randomIndex;
	float2 texCoord = GetVertexTexCoord(vertexCorner);
	Out.ParticleTexCoord = Particle_ComputeVideoTexture(currentTexFrame, texCoord);
	
	// compute color
	float4 color = Particle_ComputeColor(relativeAge, Seed, true);
	color.xyz = color.xyz * 2.0 - 1.0; // Unpack to treat the color as normal	
	Out.Color = color;	
	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader(ParticleVSOutput In) : COLOR
{
	float2 texCoord0 = In.ParticleTexCoord;	
	float4 normalMapSample = tex2D( SAMPLER( NormalTexture ), texCoord0);

	// Get bump map normal
	float3 bumpNormal = normalMapSample.xyz * 2.0 - 1.0;
	
	// Scale normal to increase/decrease bump effect
	//bumpNormal.xy *= BumpScale;
	bumpNormal = normalize(bumpNormal);	
	float3 normal = mul(bumpNormal, In.TangentToViewSpace);
	float4 color = float4(In.Color.xyz * normal * 0.5 + 0.5, In.Color.w * normalMapSample.w);
	return color;
}

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
		VertexShader = compile VS_VERSION_HIGH ParticleVertexShader();
		PixelShader = compile PS_VERSION_HIGH ParticlePixelShader();

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

// ----------------------------------------------------------------------------
// TECHNIQUE: LowQuality
// ----------------------------------------------------------------------------
technique Default_L
{
	// Disabled
}
