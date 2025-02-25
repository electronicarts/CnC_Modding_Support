//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// Utility code for GPU vertex particle shaders
//////////////////////////////////////////////////////////////////////////////

#ifndef _COMMON_PARTICLE_FXH_
#define _COMMON_PARTICLE_FXH_

#include "GlobalParameters.fxh"
#include "Random.fxh"
#include "RegisterMap.fxh"

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

#if !defined(EA_PLATFORM_PS3)
// If you change these values, be sure to change the corresponding PS3 values in ScopeManagerParticle.cpp
STATICARRAY const float2 VertexCorners[MAX_VERTICES_PER_PARTICLE] =
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
#endif

float2 GetVertexTexCoord(float2 vertexCorner)
{
	return vertexCorner * float2(1, -1) + float2(0.5, 0.5);
}


// Client frame rate used in time conversion
static const float CLIENT_FRAMES_PER_SECOND = 30.0;

//
// Draw module data
//

// Common values for ParticleDraw.ShaderType. Based on fxpscommon.inc.
static const int ShaderType_Additive = 1;
static const int ShaderType_AdditiveAlphaTest = 2;
static const int ShaderType_Alpha = 3;
static const int ShaderType_AlphaTest = 4;
static const int ShaderType_Multiply = 5;

int Draw_ShaderType
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.ShaderType";
> = ShaderType_Additive;

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

#if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.

    struct ParticleDraw
    {
	    float4 VideoTex_NumPerRow_LastFrame_SingleRow_isRand;
	    float4 ColorAnimationFunctions[PARTICLE_COLOR_ANIMATION_NUM_FUNCTIONS];
	    float4 TimeKeys;
	    float SpeedMultiplier;
	    float2 ColorScaleRange;  
    };

    ParticleDraw Draw
    <
	    string UIWidget = "None";
	    string SasBindAddress = "Particle.Draw";
    > 
    = {
	    float4(4.0f, 15.0f, -1.0f, 0.0f),
	
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
	    float4(0.0f, 0.0f, 0.0f, 1.0f), 
		
	    float4(0.0f, 0.0f, 0.0f, 0.0f),
	    1.0f,
	    float2(-0.1f, 0.2f)   
    }
    ;

    // Macro to return ParticleDraw members
    #define PARTICLEDRAW_DATA(varname, membername) varname##.##membername

#else // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.

    // Macro to return ParticleDraw members as seperate variables since CGFXShader does not handle structure with different data type
    #define PARTICLEDRAW_DATA(varname, membername) varname##_##membername

#endif // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.

float4 Particle_ComputeColor(float relativeAge, float particleSeed, bool allowRandomize)
{
	// compute color
	float4 color;
	if (relativeAge < PARTICLEDRAW_DATA(Draw,TimeKeys).y)
	{
		color = PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[0] * relativeAge + PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[1];
	}
	else if (relativeAge < PARTICLEDRAW_DATA(Draw,TimeKeys).z)
	{
		color = PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[2] * relativeAge + PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[3];
	}
	else
	{
		color = PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[4] * relativeAge + PARTICLEDRAW_DATA(Draw,ColorAnimationFunctions)[5];
	}

	if (allowRandomize)
	{
		// $note (WSK) 2008/12/10 - We should not scale the alpha by the ColorScaleRange.  We don't want something that is semi-transparent to end up opaque.
		//                          On PS3, it framebuffer color becomes invalid if alpha is not within 0-1. 
		color.xyz *= (float)GetRandomFloatValue(PARTICLEDRAW_DATA(Draw,ColorScaleRange), particleSeed, 4);
	}
	
	return color;
}

float2 Particle_ComputeVideoTextureDefault(float frameNumber, float2 cornerTexCoord)
{
	float numPerRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).x;
	float lastFrame = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).y;  

	frameNumber = fmod(frameNumber, lastFrame);
	float2 uvOffset = float2(fmod(frameNumber, numPerRow), frameNumber / numPerRow);
	uvOffset -= frac(uvOffset); // Make this into an integer. More efficient here than performing the whole calculation with integers.

	return (uvOffset + cornerTexCoord) / numPerRow;
}

float2 Particle_ComputeVideoTextureSingleRow(float colNum, float2 cornerTexCoord,int rowNum)
{
    float numPerRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).x;
    float2 uvOffset = float2(colNum, rowNum);
    uvOffset -= frac(uvOffset); // Make this into an integer. More efficient here than performing the whole calculation with integers.
    
    return (uvOffset + cornerTexCoord) / numPerRow;
}

void Particle_ComputeVideoTexture(float age, float seed, float2 vertexCorner, float2 texCoord, out float2 particleTexCoord,
								  out float3 nextFrameTexCoord)
{
	// Texture coordinate
	float currentTexFrame = age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier); 

	float numFramesPerRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).x;
	float singleRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).z;
	float isRand = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).a;  

	//Random Frame....Get a random number between 0 - 3 (for the row and column) and finally plays a random texture between 0-15
	int randNumRow = GetRandomFloatValue(float2(0, numFramesPerRow),seed, 2);
	int randNumCol = GetRandomFloatValue(float2(0, numFramesPerRow),seed, 7);

	numFramesPerRow--;

	float frameToPlay = min(currentTexFrame, numFramesPerRow);
	float nextFrameToPlay = min(currentTexFrame + 1.0, numFramesPerRow);

	// Plays a single row of the texture specified by 'SingleRow' and stops at the last frame until the particle dies.
	if(singleRow > 0 && !isRand)
	{  			
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(frameToPlay, texCoord, singleRow - 1);	  			
		nextFrameTexCoord.xy = Particle_ComputeVideoTextureSingleRow(nextFrameToPlay, texCoord, singleRow - 1);
		nextFrameTexCoord.z = frac(frameToPlay);
	}
	// Plays a random frame for the lifetime of the particle.
	else if(isRand)
	{
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(randNumCol, texCoord, randNumRow);	
		nextFrameTexCoord.xy = particleTexCoord.xy;
		nextFrameTexCoord.z = 0;
	}
	// Plays a random row and stops at the last frame until the particle dies.
	else if(singleRow == -1)
	{
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(frameToPlay, texCoord, randNumRow);	
		nextFrameTexCoord.xy = Particle_ComputeVideoTextureSingleRow(nextFrameToPlay, texCoord, randNumRow);
		nextFrameTexCoord.z = frac(frameToPlay);  
	}
	// Plays the sequential animation of the texture.
	else
	{
		particleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);	
		nextFrameTexCoord.xy = Particle_ComputeVideoTextureDefault(currentTexFrame + 1.0, texCoord);     
		nextFrameTexCoord.z = frac(currentTexFrame);
	}    


}

void Particle_ComputeVideoTextureNoNextFrame(float age, float seed, float2 texCoord, out float2 particleTexCoord)
{
	// Texture coordinate
	float currentTexFrame = age * PARTICLEDRAW_DATA(Draw,SpeedMultiplier); 

	float numFramesPerRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).x;
	float singleRow = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).z;
	float isRand = PARTICLEDRAW_DATA(Draw,VideoTex_NumPerRow_LastFrame_SingleRow_isRand).a;  

	//Random Frame....Get a random number between 0 - 3 (for the row and column) and finally plays a random texture between 0-15
	int randNumRow = GetRandomFloatValue(float2(0, numFramesPerRow),seed, 2);
	int randNumCol = GetRandomFloatValue(float2(0, numFramesPerRow),seed, 7);

	numFramesPerRow--;

	float frameToPlay = min(currentTexFrame, numFramesPerRow);

	// Plays a single row of the texture specified by 'SingleRow' and stops at the last frame until the particle dies.
	if(singleRow > 0 && !isRand)
	{  			
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(frameToPlay, texCoord, singleRow - 1);	  			
	}
	// Plays a random frame for the lifetime of the particle.
	else if(isRand)
	{
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(randNumCol, texCoord, randNumRow);	
	}
	// Plays a random row and stops at the last frame until the particle dies.
	else if(singleRow == -1)
	{
		particleTexCoord = Particle_ComputeVideoTextureSingleRow(frameToPlay, texCoord, randNumRow);	
	}
	// Plays the sequential animation of the texture.
	else
	{
		particleTexCoord = Particle_ComputeVideoTextureDefault(currentTexFrame, texCoord);	
	}    
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
>
#if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
=
{
	float3(0.0f, 0.0f, 0.0f),
	float3(0.0f, 0.0f, 0.0f),
	float2(1.0f, 0.0f)
}
#endif // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
;

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
>
#if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
=
{
	float3(0, 0, 1),
	float3(10, 0, 0),
	
	float3(0, 0, 1),
	float3(0, 0, 0),
	
	float3(0, 0, 1),
	float3(0, 0, 0)
}
#endif // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
;

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
	float sizeRateDamping = sizePositionRandoms.z;
	size += sizeRate * CalculateDampingIntegral(sizeRateDamping, age);

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
// Fog data
//

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

int GetParticleFogMode()
{
#if SUPPORT_FOG
	return Fog.IsEnabled ? ((Draw_ShaderType == ShaderType_Additive || Draw_ShaderType == ShaderType_AdditiveAlphaTest || Draw_ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled;
#else // #if SUPPORT_FOG
	return FogMode_Disabled;
#endif // #if SUPPORT_FOG
}

#if SUPPORT_FOG
void ApplyFog(uniform int fogMode, float3 fog, inout float4 color)
{
	float3 fogStrength = saturate(fog);
	if (fogMode == FogMode_Opaque)
	{
		// apply fog
		color.xyz = lerp(Fog.Color.xyz, color.xyz, fogStrength).xyz;
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}
}
#endif // #if SUPPORT_FOG

//
// Soft Particle data
//

#if defined(EA_PLATFORM_PS3)
	#define SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER
#endif // #if defined(EA_PLATFORM_PS3)

// For indexing the shader array based on what type of blend is needed for the particle draw type.
#define SOFTBLEND_ADDITIVE		0
#define SOFTBLEND_ALPHA			1
#define SOFTBLEND_DISABLED		2

#if SUPPORT_SOFT_PARTICLE

// Used to see where the particle volume intersects an object.
SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
#if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)
	MinFilter = Point;
	MagFilter = Point;
#else // #if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)
	MinFilter = Linear;
	MagFilter = Linear;
#endif // #if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

bool ShouldDrawParticleSoft
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.ShouldDrawParticleSoft";
> = false;

void ApplySoftParticleBlend(uniform int blendMode, float linearBlend, inout float4 color)
{
        // $note (MD) SoftParticleBlend turned on for GPUParticleXY types to prevent intersection with cliffs
	// Modify the color (or alpha) of a the particle depending on how it's being drawn
	// so the particle has a soft edge to it.
	if (blendMode == SOFTBLEND_ALPHA)
	{
		color.w *= linearBlend;
	}
	else if (blendMode == SOFTBLEND_ADDITIVE)
	{
		color.xyz *= linearBlend;
	}
}

	#if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)

		float4x4 ProjectionI            : ProjectionInverse;
		float4x4 ViewI                  : ViewInverse;
		float4x4 WorldView              : WorldView;

		#define DECLARE_SOFT_PARTICLE_VS_OUTPUT \
			float4 WorldNearPosition    : TEXCOORD8; \
			float4 WorldFarPosition     : TEXCOORD9; \
			float4 NDCPosition          : TEXCOORD4; \
			float2 ViewZPosition_Scale  : TEXCOORD5;

		void SoftParticleGenerateVSOutput(	out float4 NDCPosition, out float2 ViewZPosition_Scale, out float4 WorldNearPosition, out float4 WorldFarPosition,
											float3 ParticleCornerPosition, float4 ParticleWorldPosition, float ParticleSize, float ParticleVolumeScale)
		{
			NDCPosition = ParticleWorldPosition;

			// Convert the particle position into view space so that we can get the distance
			// between the particle and the background.
			float4 particlePosView = mul(float4(ParticleCornerPosition, 1), WorldView);
			ViewZPosition_Scale.x = particlePosView.z;
			ViewZPosition_Scale.y = ParticleVolumeScale / ParticleSize;

			float4x4 projectionToWorld = mul(ProjectionI, ViewI);
			WorldNearPosition = mul(float4(ParticleCornerPosition.xy, 0, 1), projectionToWorld);
			WorldFarPosition  = mul(float4(ParticleCornerPosition.xy, 1, 1), projectionToWorld);
		}

		float SoftParticleGetLinearBlend(float4 NDCPosition, float2 ViewZPosition_Scale, float4 WorldNearPosition, float4 WorldFarPosition)
		{
			float3 ndcPosition = NDCPosition.xyz / NDCPosition.w;

			// Convert the position into texture space then grab the depth value from the
			// depth texture. Then, move along that vector by the depth to find the pixel position.
			float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;

			// Getting the depth from the real depth buffer
			float depth = TexDepth2D(SAMPLER(DepthTexture), depthTexCoord).x;

			// Getting the position in world space
			float4 worldPosition4 = lerp(WorldNearPosition, WorldFarPosition, depth);
			worldPosition4 = worldPosition4 / worldPosition4.w;

			// Transform the position in view space
			float4 viewPosition4 = mul(worldPosition4, WorldView);
			viewPosition4 = viewPosition4 / viewPosition4.w;

			// The closer the particle is to the background, the more transparent it is.
			return saturate(ViewZPosition_Scale.y*(ViewZPosition_Scale.x - viewPosition4.z));
		}

		#define SOFT_PARTICLE_GENERATE_VS_OUTPUT(ParticleVSOutput, ParticleCornerPosition, ParticleWorldPosition, ParticleSize, ParticleVolumeScale) SoftParticleGenerateVSOutput(ParticleVSOutput.NDCPosition, ParticleVSOutput.ViewZPosition_Scale, ParticleVSOutput.WorldNearPosition, ParticleVSOutput.WorldFarPosition, ParticleCornerPosition, ParticleWorldPosition, ParticleSize, ParticleVolumeScale)
		#define SOFT_PARTICLE_GET_LINEAR_BLEND(ParticleVSOutput) SoftParticleGetLinearBlend(ParticleVSOutput.NDCPosition, ParticleVSOutput.ViewZPosition_Scale, ParticleVSOutput.WorldNearPosition, ParticleVSOutput.WorldFarPosition)

	#else // #if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)

		float4x4 WorldView : WorldView;

		#define DECLARE_SOFT_PARTICLE_VS_OUTPUT \
			float4 NDCPosition          : TEXCOORD4; \
			float2 ZPositions           : TEXCOORD5; // x is the particle z position, y is the ViewEyeDirection z component.

		void SoftParticleGenerateVSOutput(	out float4 NDCPosition, out float2 ZPositions,
											float3 ParticleCornerPosition, float4 ParticleWorldPosition, float ParticleSize, float ParticleVolumeScale)
		{
			NDCPosition = ParticleWorldPosition;

			// Convert the particle position into view space so that we can get the distance
			// between the particle and the background.
			float4 particlePosView = mul(float4(ParticleCornerPosition, 1), WorldView);

			// We don't really want a vector to the far plane. We want the vector with a z length of 1,
			// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
			ZPositions.xy = float2(particlePosView.z, 1.0) *  ParticleVolumeScale / ParticleSize;
		}

		float SoftParticleGetLinearBlend(float4 NDCPosition, float2 ZPositions)
		{
			float3 ndcPosition = NDCPosition.xyz / NDCPosition.w;

			// Convert the position into texture space then grab the depth value from the
			// depth texture. Then, move along that vector by the depth to find the pixel position.
			float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;
			float backgroundDepth = tex2D(SAMPLER(DepthTexture), depthTexCoord).x;
			float backgroundPosView = backgroundDepth * ZPositions.y;

			// The closer the particle is to the background, the more transparent it is.
			return saturate(ZPositions.x - backgroundPosView);
		}

		#define SOFT_PARTICLE_GENERATE_VS_OUTPUT(ParticleVSOutput, ParticleCornerPosition, ParticleWorldPosition, ParticleSize, ParticleVolumeScale) SoftParticleGenerateVSOutput(ParticleVSOutput.NDCPosition, ParticleVSOutput.ZPositions, ParticleCornerPosition, ParticleWorldPosition, ParticleSize, ParticleVolumeScale)
		#define SOFT_PARTICLE_GET_LINEAR_BLEND(ParticleVSOutput) SoftParticleGetLinearBlend(ParticleVSOutput.NDCPosition, ParticleVSOutput.ZPositions)

	#endif // #if defined(SOFT_PARTICLE_USE_REAL_DEPTH_BUFFER)

#else // #if SUPPORT_SOFT_PARTICLE

#define DECLARE_SOFT_PARTICLE_VS_OUTPUT
#define DECLARE_SOFT_PARTICLE_PS_INPUT
static const bool ShouldDrawParticleSoft = false;

#endif // #if SUPPORT_SOFT_PARTICLE

int GetParticleBlendMode()
{
	return ShouldDrawParticleSoft ? ((Draw_ShaderType == ShaderType_Alpha) ? SOFTBLEND_ALPHA : SOFTBLEND_ADDITIVE) : SOFTBLEND_DISABLED;
}


//
// Age Data
//

// Time (ie. material is animated)
float Time : Time;

void Particle_ComputeAge(out float age, out float relativeAge, inout float Index,
                         float CreationFrame, float LifeInFrames)
{
	// particle system works with frames, so first convert time to frame
	// rather than converting everything else to time
	age = (Time * CLIENT_FRAMES_PER_SECOND - CreationFrame);
	
	// first eliminate dead particles
	if (age > LifeInFrames)
	{
		Index = 0;
	}
	relativeAge = age / LifeInFrames; 	
}

#endif // _COMMON_PARTICLE_FXH_
