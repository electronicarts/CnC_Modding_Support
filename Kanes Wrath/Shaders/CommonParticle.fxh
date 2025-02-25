//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// Utility code for GPU vertex particle shaders
//////////////////////////////////////////////////////////////////////////////

#include "Random.fxh"

// Client frame rate used in time conversion
static const float CLIENT_FRAMES_PER_SECOND = 30.0;

//
// Draw module data
//

// We allow only four keyframes on color and no alpha yet				
static const int MAX_KEYFRAMES = 4;

struct ParticleDraw
{
	float2 VideoTexture_NumPerRow_LastFrame;
	float4 ColorAnimationFunctions[(MAX_KEYFRAMES - 1) * 2];
	float4 TimeKeys;
	int ShaderType;
	float SpeedMultiplier;
	float2 ColorScaleRange;
};

// Common values for ParticleDraw.ShaderType. Based on fxpscommon.inc.
static const int ShaderType_Additive = 1;
static const int ShaderType_AdditiveAlphaTest = 2;
static const int ShaderType_Alpha = 3;
static const int ShaderType_AlphaTest = 4;
static const int ShaderType_Multiply = 5;

#if !EXPRESSION_EVALUATOR_ENABLED
#define SETUP_ALPHA_BLEND_AND_TEST(ShaderType) \
		SrcBlend = (ShaderType == ShaderType_Additive || ShaderType == ShaderType_AdditiveAlphaTest || ShaderType == ShaderType_AlphaTest \
			? D3DBLEND_ONE \
			: (ShaderType == ShaderType_Alpha \
				? D3DBLEND_SRCALPHA \
				: /* ShaderType == ShaderType_Multiply */ D3DBLEND_ZERO)); \
		DestBlend = (ShaderType == ShaderType_Additive || ShaderType == ShaderType_AdditiveAlphaTest \
			? D3DBLEND_ONE \
			: (ShaderType == ShaderType_Alpha \
				? D3DBLEND_INVSRCALPHA \
				: (ShaderType == ShaderType_Multiply \
					? D3DBLEND_INVSRCCOLOR \
					: /* ShaderType == ShaderType_AlphaTest */ D3DBLEND_ZERO))); \
		AlphaTestEnable = (ShaderType == ShaderType_AdditiveAlphaTest || ShaderType == ShaderType_AlphaTest); \
		AlphaBlendEnable = true; \
		AlphaFunc = GreaterEqual; \
		AlphaRef = 0x60
#else
#define SETUP_ALPHA_BLEND_AND_TEST(ShaderType) \
		AlphaBlendEnable = true; \
		AlphaFunc = GreaterEqual; \
		AlphaRef = 0x60
#endif

ParticleDraw Draw
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw";
> = 
{
	float2(4.0f, 15.0f),
	
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
	float4(0.0f, 0.0f, 0.0f, 1.0f), 
		
	float4(0.0f, 0.0f, 0.0f, 0.0f),
	ShaderType_Additive,
	1.0f,
	float2(-0.1f, 0.2f)
};

float4 Particle_ComputeColor(float relativeAge, float particleSeed, bool allowRandomize)
{
	// compute color
	float4 color;
	if (relativeAge < Draw.TimeKeys.y)
	{
		color = Draw.ColorAnimationFunctions[0] * relativeAge + Draw.ColorAnimationFunctions[1];
	}
	else if (relativeAge < Draw.TimeKeys.z)
	{
		color = Draw.ColorAnimationFunctions[2] * relativeAge + Draw.ColorAnimationFunctions[3];
	}
	else
	{
		color = Draw.ColorAnimationFunctions[4] * relativeAge + Draw.ColorAnimationFunctions[5];
	}

	if (allowRandomize)
	{
		// The ColorScale input is actually used as an offset...
		// Fade out offset over time, so that additive particles can still reach black at the end of their lifetime.
		float randomColorOffset = GetRandomFloatValue(Draw.ColorScaleRange, particleSeed, 4);
		color = saturate(color + float4(randomColorOffset.xxx, 0.0f) * (1 - relativeAge));
	}
	
	return color;
}

float2 Particle_ComputeVideoTexture(float frameNumber, float2 cornerTexCoord)
{
	float numPerRow = Draw.VideoTexture_NumPerRow_LastFrame.x;
	float lastFrame = Draw.VideoTexture_NumPerRow_LastFrame.y;

	frameNumber = fmod(frameNumber, lastFrame);
	float2 uvOffset = float2(fmod(frameNumber, numPerRow), frameNumber / numPerRow);
	uvOffset -= frac(uvOffset); // Make this into an integer. More efficient here than performing the whole calculation with integers.

	return (uvOffset + cornerTexCoord) / numPerRow;
}

//
// Physics data
//
struct ParticlePhysics
{
	float3 Gravity;
	float3 DriftVelocity;
	float2 VelocityDampingRange; // Range with minimum in x and spread (= max - min) in y
};

ParticlePhysics Physics
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Physics";
> =
{
	float3(0.0f, 0.0f, 0.0f),
	float3(0.0f, 0.0f, 0.0f),
	float2(1.0f, 0.0f)
};

//
// Update params -- other things that update every frame :)
//
struct ParticleUpdate
{
	float3 Size_Rate_Damping__Min;
	float3 Size_Rate_Damping__Spread;

	float3 XYRotation_Rate_Damping__Min;
	float3 XYRotation_Rate_Damping__Spread;

	float3 ZRotation_Rate_Damping__Min;
	float3 ZRotation_Rate_Damping__Spread;
};

ParticleUpdate Update
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Update";
> =
{
	float3(0, 0, 1),
	float3(10, 0, 0),
	
	float3(0, 0, 1),
	float3(0, 0, 0),
	
	float3(0, 0, 1),
	float3(0, 0, 0)
};

float CalculateDampingIntegral(float damping, float age)
{
	// The following computation is derived from this:
	// In the iterative integration we do: v = v' * damp, with v: new velocity, v' old velocity
	// To get the fixed function solution based only starting values, we need to integrate from 0 to t over the integral((damp ^ u) du).
	// The solution to the integral is (damp ^ u) / ln(damp).
	// Entering the two borders (0 and t) into it leads to: (damp ^ t - 1) / ln(damp)
	
	// The integral is undefined at 1.0, but it's approaching a good value (= age). Be pragmatic.
	//if (abs(damping - 1.0) < 0.0001)
	if (damping == 1.0)
		damping = 1.0001;

	return (pow(damping, age) - 1) / log(damping);
}
							
void Particle_ComputePhysics(out float3 particlePosition, out float size, out float2x2 zRotationMatrix,
	float age, float3 startPosition, float3 startVelocity, float particleSeed)
{
	// size animation
	float3 sizeRandoms = GetRandomFloatValues(Update.Size_Rate_Damping__Min,
		Update.Size_Rate_Damping__Spread, particleSeed, 3);
	
	size = sizeRandoms.x;
	float sizeRate = sizeRandoms.y;
	float sizeRateDamping = sizeRandoms.z;
	size += sizeRate * CalculateDampingIntegral(sizeRateDamping, age);


	// update particle position
	float velocityDamping = GetRandomFloatValue(Physics.VelocityDampingRange,
		particleSeed, 13);
	
	float integratedDampedVelocity = CalculateDampingIntegral(velocityDamping, age);
	
	particlePosition = startPosition
		+ startVelocity * integratedDampedVelocity
		+ (Physics.DriftVelocity + 0.5 * age * Physics.Gravity) * age;


	// apply little bit of xy-rotation 
	float2 xyVec = particlePosition.xy - startPosition.xy;

	float3 xyRotRandoms = GetRandomFloatValues(Update.XYRotation_Rate_Damping__Min,
		Update.XYRotation_Rate_Damping__Spread, particleSeed, 9);
	float xyRotation = xyRotRandoms.x;
	float xyRotationRate = xyRotRandoms.y;
	float xyRotationDamping = xyRotRandoms.z;

	xyRotation += xyRotationRate * CalculateDampingIntegral(xyRotationDamping, age);

	float2x2 xyRotationMatrix = { 1.0f, 0.0f, 1.0f, 0.0f };
	xyRotationMatrix[0][0] = cos(xyRotation); 
	xyRotationMatrix[0][1] = -sin(xyRotation); 
	xyRotationMatrix[1][1] = xyRotationMatrix[0][0]; 
	xyRotationMatrix[1][0] = -xyRotationMatrix[0][1]; 
	particlePosition.xy = startPosition.xy + mul(xyVec, xyRotationMatrix);
		
	// apply z rotation
	float3 zRotRandoms = GetRandomFloatValues(Update.ZRotation_Rate_Damping__Min,
		Update.ZRotation_Rate_Damping__Spread, particleSeed, 2);
	float zRotation = zRotRandoms.x;
	float zRotationRate = zRotRandoms.y;
	float zRotationDamping = zRotRandoms.z;

	zRotation += zRotationRate * CalculateDampingIntegral(zRotationDamping, age);

	zRotationMatrix[0][0] = cos(zRotation); 
	zRotationMatrix[0][1] = -sin(zRotation); 
	zRotationMatrix[1][1] = zRotationMatrix[0][0]; 
	zRotationMatrix[1][0] = -zRotationMatrix[0][1]; 
}

void Particle_ComputePhysics_Simplified(out float3 particlePosition, out float size, out float2x2 zRotationMatrix,
	float age, float3 startPosition, float3 startVelocity, float particleSeed)
{
	float4 sizePositionRandoms = GetRandomFloatValues(float4(Update.Size_Rate_Damping__Min, Physics.VelocityDampingRange.x),
		float4(Update.Size_Rate_Damping__Spread, Physics.VelocityDampingRange.y), particleSeed, 3);
		
	// size animation
	size = sizePositionRandoms.x;
	float sizeRate = sizePositionRandoms.y;
	size += sizeRate * age;

	// update particle position
	float velocityDamping = sizePositionRandoms.w;
	
	float integratedDampedVelocity = CalculateDampingIntegral(velocityDamping, age);
	
	particlePosition = startPosition
		+ startVelocity * integratedDampedVelocity
		+ (Physics.DriftVelocity + 0.5 * age * Physics.Gravity) * age;

	// Find random values for xy and z rotation
	float4 rotationRandoms = GetRandomFloatValues(
		float4(Update.XYRotation_Rate_Damping__Min.xy, Update.ZRotation_Rate_Damping__Min.xy),
		float4(Update.XYRotation_Rate_Damping__Spread.xy, Update.ZRotation_Rate_Damping__Spread.xy),
		particleSeed, 9);
		
	// apply little bit of xy-rotation 
	float2 xyVec = particlePosition.xy - startPosition.xy;
	float xyRotation = rotationRandoms.x;
	float xyRotationRate = rotationRandoms.y;
	xyRotation += xyRotationRate * age;

	float2x2 xyRotationMatrix = { 1.0f, 0.0f, 1.0f, 0.0f };
	xyRotationMatrix[0][0] = cos(xyRotation); 
	xyRotationMatrix[0][1] = -sin(xyRotation); 
	xyRotationMatrix[1][1] = xyRotationMatrix[0][0]; 
	xyRotationMatrix[1][0] = -xyRotationMatrix[0][1]; 
	particlePosition.xy = startPosition.xy + mul(xyVec, xyRotationMatrix);
		
	// apply z rotation
	float zRotation = rotationRandoms.z;
	float zRotationRate = rotationRandoms.w;
	zRotation += zRotationRate * age;

	zRotationMatrix[0][0] = cos(zRotation); 
	zRotationMatrix[0][1] = -sin(zRotation); 
	zRotationMatrix[1][1] = zRotationMatrix[0][0]; 
	zRotationMatrix[1][0] = -zRotationMatrix[0][1]; 
}


//
// Vertex data
//

//
// The particles can either be built out of 4, 5 or 9 verts:
//
//	0-------1
//	|\     /|
//	| 5---6 |
//	| |\ /| |
//	| | 4 | |
//	| |/ \| |
//	| 8---7 |
//	|/     \|
//	3-------2
//
// With this vertex layout, the following geometry can be built:
// Vertex 0-3 span a simple quad (2 triangles)
// Vertex 0-4 are a quad with center point, forming 4 triangles
// Vertex 0-8 builds two "concentric" quads (as in the diagram), with 12 triangles
//
static const int MAX_VERTICES_PER_PARTICLE = 9;

static const float2 VertexCorners[MAX_VERTICES_PER_PARTICLE] =
{
	float2(-0.5f, -0.5f),
	float2(0.5f, -0.5f),
	float2(0.5f, 0.5f),
	float2(-0.5f, 0.5f),
	
	float2(0, 0),
	
	float2(-0.25, -0.25),
	float2(0.25, -0.25),
	float2(0.25, 0.25),
	float2(-0.25, 0.25)
};

float2 GetVertexTexCoord(float2 vertexCorner)
{
	return vertexCorner * float2(1, -1) + float2(0.5, 0.5);
}
