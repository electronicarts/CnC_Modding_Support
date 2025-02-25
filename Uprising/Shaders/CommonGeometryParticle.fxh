//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// Common GPU geometry particle FX Shader
//////////////////////////////////////////////////////////////////////////////

#ifndef _COMMON_GEOMETRY_PARTICLE_FXH_
#define _COMMON_GEOMETRY_PARTICLE_FXH_

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

// Used to see where the particle volume intersects an object.
SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END
													
//--------------------------------- GENERAL STUFF --------------------------------------
bool ShouldDrawParticleSoft
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.ShouldDrawParticleSoft";
> = false;

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// Transformations
float4x4 WorldView              : WorldView;
float4x4 Projection             : Projection;
float4x4 WorldViewProjection    : WorldViewProjection;
float4x3 View                   : View;
float4x4 ProjectionI            : ProjectionInverse;

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
float4x3 ViewI                  : ViewInverse;

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

// Time (ie. material is animated)
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: HIGH ~ ULTRAHIGH
// ----------------------------------------------------------------------------
struct ParticleVSOutput_H
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
	float3 Fog : TEXCOORD1; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
	float Depth : TEXCOORD2; // For _CreateShadowMap technique
	float3 NextFrameTexCoord : TEXCOORD3; // for interpolating between two frames
	float4 NDCPosition : TEXCOORD4;
	float2 ZPositions : TEXCOORD5; // x is the particle z position, y is the ViewEyeDirection z component.
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	1.5

// For indexing the shader array based on what type of blend is needed for the particle draw type.
#define SOFTBLEND_ADDITIVE		0
#define SOFTBLEND_ALPHA			1
#define SOFTBLEND_DISABLED		2

// These are the FXParticleSystem_RotationType values in FXParticleBase.xsd minus 1. We subtract
// 1 so that it's easier to index into a shader array.
#define ROTATION_OFF			0
#define ROTATE_AROUND_VELOCITY	1
#define ROTATE_IN_WORLD_SPACE	2


//
// Geometry update params. These update every frame.
//
struct ParticleGeometryUpdate
{
	float3 StartSizeMinimums;
	float3 StartSizeSpreads;
	float3 SizeRateMinimums;
	float3 SizeRateSpreads;
	float3 SizeDampingMinimums;
	float3 SizeDampingSpreads;
	float3 AngleMinimums;
	float3 AngleSpreads;
	float3 AngularRateMinimums;
	float3 AngularRateSpreads;
	float2 AngleDampingMin_AngleDampingSpread;
	int RotationType;
};

ParticleGeometryUpdate GeometryUpdate
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.GeometryUpdate";
> 
#if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
=
{
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float3(0, 0, 0),
	float2(0, 0),
	int(0)
}
#endif // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
;


// ----------------------------------------------------------------------------
float3 CalculateDampingIntegral(float3 damping, float age)
{
	// The following computation is derived from this:
	// In the iterative integration we do: v = v' * damp, with v: new velocity, v' old velocity
	// To get the fixed function solution based only starting values, we need to integrate from 0 to t over the integral((damp ^ u) du).
	// The solution to the integral is (damp ^ u) / ln(damp).
	// Entering the two borders (0 and t) into it leads to: (damp ^ t - 1) / ln(damp)
	
	// The integral is undefined at 1.0, but it's approaching a good value (= age). Be pragmatic.
	//if (abs(damping - 1.0) < 0.0001)
	if (damping.x == 1.0)
		damping.x = 1.0001;
	if (damping.y == 1.0)
		damping.y = 1.0001;
	if (damping.z == 1.0)
		damping.z = 1.0001;
		
	return (pow(damping, age) - 1) / log(damping);
}

// ----------------------------------------------------------------------------
float3 GeometryParticle_ComputeSize(float age, float particleSeed)
{
	// start size, rate, and damping
	float3 sizeStart = GetRandomFloatValues(GeometryUpdate.StartSizeMinimums, GeometryUpdate.StartSizeSpreads, particleSeed, 3);
	float3 sizeRate = GetRandomFloatValues(GeometryUpdate.SizeRateMinimums, GeometryUpdate.SizeRateSpreads, particleSeed, 3);
	float3 sizeDamping = GetRandomFloatValues(GeometryUpdate.SizeDampingMinimums, GeometryUpdate.SizeDampingSpreads, particleSeed, 3);
		
	return sizeStart + sizeRate * CalculateDampingIntegral(sizeDamping, age);
}

// ----------------------------------------------------------------------------
float3 GeometryParticle_ComputeAngles(float age, float particleSeed)
{
	// start size, rate, and damping
	float3 angleStart = GetRandomFloatValues(GeometryUpdate.AngleMinimums, GeometryUpdate.AngleSpreads, particleSeed, 3);
	float3 angleRate = GetRandomFloatValues(GeometryUpdate.AngularRateMinimums, GeometryUpdate.AngularRateSpreads, particleSeed, 3);
	float angleDamping = GetRandomFloatValue(float2(GeometryUpdate.AngleDampingMin_AngleDampingSpread.x, GeometryUpdate.AngleDampingMin_AngleDampingSpread.y), particleSeed, 3);
		
	return angleStart + angleRate * CalculateDampingIntegral(angleDamping, age);
}

// ----------------------------------------------------------------------------
float3 GeometryParticle_UpdatePosition(float3 startPosition, float3 startVelocity, float age, float particleSeed, out float3 finalVelocity)
{
	// update particle position
	float velocityDamping = GetRandomFloatValue(Physics.VelocityDampingRange, particleSeed, 13);
	float integratedDampedVelocity = CalculateDampingIntegral(velocityDamping, age);
	finalVelocity = startVelocity * integratedDampedVelocity + (Physics.DriftVelocity + 0.5 * age * Physics.Gravity) * age;
	return startPosition + finalVelocity;
}

// ----------------------------------------------------------------------------
// Modified from rwmath
float3x3 Matrix33FromEulerXYZ(float3 euler)
{
    float ci, cj, ch, si, sj, sh;

    sincos(euler.x, si, ci);
    sincos(euler.y, sj, cj);
    sincos(euler.z, sh, ch);

    float cc = ci * ch;
    float cs = ci * sh;
    float sc = si * ch;
    float ss = si * sh;

    return float3x3(
        cj * ch     ,  cj * sh     , -sj      , 
        sj * sc - cs,  sj * ss + cc,  cj * si ,
        sj * cc + ss,  sj * cs - sc,  cj * ci 
        );
}

float3x3 Matrix33FromEulerSinCosXYZ(float3 eulerSin, float3 eulerCos)
{
	float ci, cj, ch, si, sj, sh;

	si = eulerSin.x;
	ci = eulerCos.x;
	sj = eulerSin.y;
	cj = eulerCos.y;
	sh = eulerSin.z;
	ch = eulerCos.z;

	float cc = ci * ch;
	float cs = ci * sh;
	float sc = si * ch;
	float ss = si * sh;

	return float3x3(
		cj * ch     ,  cj * sh     , -sj      , 
		sj * sc - cs,  sj * ss + cc,  cj * si ,
		sj * cc + ss,  sj * cs - sc,  cj * ci 
		);
}

// Build a look-at matrix so that the x-axis points along the given direction
// Modified from Matrix3x4::Obj_Look_At
float3x3 ObjectLookAt(float3 lookAtDirection)
{
	float3 d = lookAtDirection;

	float len1 = length(d);
	float len2 = length(d.xy);

	float sinp, cosp;	//sine and cosine of the pitch ("up-down" tilt about y)
	if (len1 != 0.0f)
	{
		sinp = d.z / len1;
		cosp = len2 / len1;
	}
	else
	{
		sinp = 0.0f;
		cosp = 1.0f;
	}

	float siny, cosy;	//sine and cosine of the yaw ("left-right"tilt about z)
	if (len2 != 0.0f)
	{
		siny = d.y / len2;
		cosy = d.x / len2;
	}
	else
	{
		siny = 0.0f;
		cosy = 1.0f;
	}

	// Use 0 degree roll for now
	float sinRoll = 0.0;
	float cosRoll = 1.0;

	// Yaw rotation to projection of target in x-y plane and then pitch rotation
	return Matrix33FromEulerSinCosXYZ(float3(sinRoll, -sinp, siny), float3(cosRoll, cosp, cosy));
}

// ----------------------------------------------------------------------------
ParticleVSOutput_H ParticleVertexShader_H(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1,
		uniform int rotationType)
{
	ParticleVSOutput_H Out;

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


	//////////////////////////////////////////
	// UPDATE CORNER POSITION 
	//////////////////////////////////////////
	
	// Calculate the particle position based on the physics parameters.
	float3 finalVelocity;
	float3 particlePosition = GeometryParticle_UpdatePosition(StartPosition, StartVelocity, age, Seed, finalVelocity);

	// SCALE
	// The size can change depending on 3 factors (size, rate, and damping).
	float3 size = GeometryParticle_ComputeSize(age, Seed);
	float3 cornerPosition = GEOMETRY_VERTEX_CORNERS[Index] * size;
	
	// ROTATE
	// Depending on the rotation type we either rotate in world space
	// or we rotate around the velocity of the particle.
	if (rotationType != ROTATION_OFF)
	{
		float3 eulerAngles = GeometryParticle_ComputeAngles(age, Seed);
		float3x3 rotateMatrix = Matrix33FromEulerXYZ(eulerAngles);
		
		if (rotationType == ROTATE_AROUND_VELOCITY)
		{
			if (length(finalVelocity) < 0.001)
			{
				finalVelocity = StartVelocity;
			}
			
			float3x3 lookAt = ObjectLookAt(finalVelocity);
			rotateMatrix = mul(rotateMatrix, lookAt);
		}
		
		cornerPosition = mul(cornerPosition, rotateMatrix);
	}
	
	// TRANSLATE
	cornerPosition += particlePosition;
	

	//////////////////////////////////////////
	// PROJECT AND SETUP SOFT PARTICLES
	//////////////////////////////////////////
		
	float particleSize = size / PARTICLE_VOLUME_SCALE;
	float4 particlePosView = mul(float4(cornerPosition, 1), WorldView);
	Out.ZPositions.x = particlePosView.z / particleSize;
	
	// Finish projecting the position.
	float4 ndcPos = mul(particlePosView, Projection);
	Out.Position = ndcPos;
	Out.NDCPosition = ndcPos;
	Out.Depth = Out.Position.z / Out.Position.w;

	// Convert the position into a view vector to the far plane.
	float4 screenFarPlanePosition = float4(ndcPos.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	Out.ZPositions.y = (viewFarPlanePosition.z / viewFarPlanePosition.z) / particleSize;


	//////////////////////////////////////////
	// IDENTICAL TO GpuParticle.fx
	//////////////////////////////////////////

	// Fog depends on world position, but world matrix should be identity.
	Out.Fog = CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;

	Particle_ComputeVideoTexture(age, Seed, GEOMETRY_VERTEX_CORNERS[Index], GEOMETRY_VERTEX_TEXCOORDS[Index], Out.ParticleTexCoord, Out.NextFrameTexCoord);

	// compute color
	float relativeAge = age / LifeInFrames; 	
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);

	return Out;
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput_H In, uniform int fogMode, uniform int blendMode) COLORTARGET
{
	float3 ndcPosition = In.NDCPosition.xyz / In.NDCPosition.w;

	// Convert the position into texture space then grab the depth value from the
	// depth texture. Then, move along that vector by the depth to find the pixel position.
	float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;
	float backgroundDepth = tex2D(SAMPLER(DepthTexture), depthTexCoord).x;
	float backgroundPosView = backgroundDepth * In.ZPositions.y;

	// The closer the particle is to the background, the more transparent it is.
	float linearBlend = saturate(In.ZPositions.x - backgroundPosView);

	// do interpolation between two frames (for particles with video textures)
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(NextFrameTextureSampler), In.NextFrameTexCoord.xy);
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;

	// Modify the color (or alpha) of a the particle depending on how it's being drawn
	// so the particle has a soft edge to it.
	if (blendMode == SOFTBLEND_ALPHA)
	{
		Color.w *= linearBlend;
	}
	else if (blendMode == SOFTBLEND_ADDITIVE)
	{
		Color.xyz *= linearBlend;
	}

	// Apply fog
	float3 fogStrength = saturate(In.Fog) ;
	if (fogMode == FogMode_Opaque)
	{
		// apply fog
		Color.xyz = lerp(Fog.Color, Color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		Color.xyz *= fogStrength;
	}

	return Color;
}

// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
ParticleVSOutput_H ParticleVertexShader_Xenon(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1,
		uniform int rotationType)
{
	return ParticleVertexShader_H(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, GeometryUpdate.RotationType - 1);
}

float4 ParticlePixelShader_Xenon(ParticleVSOutput_H In ) : COLOR
{
	return SoftParticlePixelShader( In, 
		Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
		!ShouldDrawParticleSoft ? SOFTBLEND_DISABLED : ((Draw.ShaderType == ShaderType_Alpha) ? SOFTBLEND_ALPHA : SOFTBLEND_ADDITIVE));
}

// ----------------------------------------------------------------------------
// TECHNIQUE: HIGH ~ ULTRAHIGH (And XENON)
// ----------------------------------------------------------------------------

#define VS_ShaderType_H \
	compile VS_3_0 ParticleVertexShader_H(ROTATION_OFF), \
	compile VS_3_0 ParticleVertexShader_H(ROTATE_AROUND_VELOCITY), \
	compile VS_3_0 ParticleVertexShader_H(ROTATE_IN_WORLD_SPACE)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final_H = 3 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array_H[VS_Multiplier_Final_H] =
{
	VS_ShaderType_H
};
#endif


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


// ----------------------------------------------------------------------------
// TECHNIQUE: LOW
// ----------------------------------------------------------------------------

struct ParticleVSOutput_L
{
	float4 Position : POSITION;
	float2 ParticleTexCoord : TEXCOORD0;
	float4 Color : COLOR0;
	float Depth : TEXCOORD1; // For _CreateShadowMap technique
};


// ----------------------------------------------------------------------------
ParticleVSOutput_L ParticleVertexShader_L(float4 StartPositionLifeInFrames : POSITION, 
										  float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1,
										  uniform int rotationType)
{
	ParticleVSOutput_L Out;

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


	//////////////////////////////////////////
	// UPDATE CORNER POSITION 
	//////////////////////////////////////////

	// Calculate the particle position based on the physics parameters.
	float3 finalVelocity;
	float3 particlePosition = GeometryParticle_UpdatePosition(StartPosition, StartVelocity, age, Seed, finalVelocity);

	// SCALE
	// The size can change depending on 3 factors (size, rate, and damping).
	float3 size = GeometryParticle_ComputeSize(age, Seed);
	float3 cornerPosition = GEOMETRY_VERTEX_CORNERS[Index] * size;

	// ROTATE
	// Depending on the rotation type we either rotate in world space
	// or we rotate around the velocity of the particle.
	if (rotationType != ROTATION_OFF)
	{
		float3 eulerAngles = GeometryParticle_ComputeAngles(age, Seed);
		float3x3 rotateMatrix = Matrix33FromEulerXYZ(eulerAngles);

		if (rotationType == ROTATE_AROUND_VELOCITY)
		{
			if (length(finalVelocity) < 0.001)
			{
				finalVelocity = StartVelocity;
			}

			float3x3 lookAt = ObjectLookAt(finalVelocity);
			rotateMatrix = mul(rotateMatrix, lookAt);
		}

		cornerPosition = mul(cornerPosition, rotateMatrix);
	}

	// TRANSLATE
	cornerPosition += particlePosition;


	//////////////////////////////////////////
	// PROJECT
	//////////////////////////////////////////

	// Finish projecting the position.
	Out.Position = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Depth = Out.Position.z / Out.Position.w;

	// texture coordinate
	Particle_ComputeVideoTextureNoNextFrame(age, Seed, GEOMETRY_VERTEX_TEXCOORDS[Index], Out.ParticleTexCoord);

	//////////////////////////////////////////
	// IDENTICAL TO GpuParticle.fx
	//////////////////////////////////////////

	// compute color
	float relativeAge = age / LifeInFrames; 	
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);

	return Out;
}

// ----------------------------------------------------------------------------
float4 ParticlePixelShader_L(ParticleVSOutput_L In) : COLOR
{
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 Color = TextureColor * In.Color;
	return Color;
}


#define VS_ShaderType_L \
	compile VS_2_0 ParticleVertexShader_L(ROTATION_OFF), \
	compile VS_2_0 ParticleVertexShader_L(ROTATE_AROUND_VELOCITY), \
	compile VS_2_0 ParticleVertexShader_L(ROTATE_IN_WORLD_SPACE)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final_L = 3 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array_L[VS_Multiplier_Final_L] =
{
	VS_ShaderType_L
};
#endif

#endif // _COMMON_GEOMETRY_PARTICLE_FXH_