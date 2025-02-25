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
													
//--------------------------------- GENERAL STUFF --------------------------------------

// Transformations
float4x4 Projection             : Projection;
float4x4 WorldViewProjection    : WorldViewProjection;
float4x3 View                   : View;

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

// ----------------------------------------------------------------------------
// SHADER: HIGH ~ ULTRAHIGH
// ----------------------------------------------------------------------------
struct ParticleVSOutput_H
{
	float4 Position             : POSITION;
	float2 ParticleTexCoord     : TEXCOORD0;
	float3 NextFrameTexCoord    : TEXCOORD1; // for interpolating between two frames
	float4 Color                : TEXCOORD2; // Not in color register to have increased range, which could be > 1 for HDR
	DECLARE_SOFT_PARTICLE_VS_OUTPUT
	float Depth                 : TEXCOORD6; // For _CreateShadowMap technique
#if SUPPORT_FOG
	float3 Fog                  : TEXCOORD7; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
#endif // #if SUPPORT_FOG
};

// Making this value smaller will increase the size of the transparent edge where
// the particle intersects the background.
#define PARTICLE_VOLUME_SCALE	1.5
#define ONE_OVER_PARTICLE_VOLUME_SCALE	0.66666667

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
}
#endif // #if !defined(EA_PLATFORM_PS3)	// PS3 TODO - Does not like this being initialized.
;

int GeometryUpdate_RotationType
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.GeometryUpdate.RotationType";
> = 0;

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

	//////////////////////////////////////////
	// UPDATE CORNER POSITION 
	//////////////////////////////////////////
	
	// Calculate the particle position based on the physics parameters.
	float3 finalVelocity;
	float3 particlePosition = GeometryParticle_UpdatePosition(StartPosition, StartVelocity, age, Seed, finalVelocity);

	// SCALE
	// The size can change depending on 3 factors (size, rate, and damping).
	float3 size3 = GeometryParticle_ComputeSize(age, Seed);
	float size = length(size3);
	float3 cornerPosition = GEOMETRY_VERTEX_CORNERS[Index] * size3;
	
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
	
	// Finish projecting the position.
	float4 ndcPos   = mul(float4(cornerPosition, 1), WorldViewProjection);
	Out.Position = ndcPos;
	Out.Depth = Out.Position.z / Out.Position.w;

#if SUPPORT_SOFT_PARTICLE
	SOFT_PARTICLE_GENERATE_VS_OUTPUT(Out, cornerPosition, ndcPos, length(size), PARTICLE_VOLUME_SCALE);
#endif // #if SUPPORT_SOFT_PARTICLE

	//////////////////////////////////////////
	// IDENTICAL TO GpuParticle.fx
	//////////////////////////////////////////

	// Fog depends on world position, but world matrix should be identity.
#if SUPPORT_FOG
	Out.Fog = CalculateFog(Fog, cornerPosition, GetEyePosition()).xxx;
#endif // #if SUPPORT_FOG

	Particle_ComputeVideoTexture(age, Seed, GEOMETRY_VERTEX_CORNERS[Index].xy, GEOMETRY_VERTEX_TEXCOORDS[Index], Out.ParticleTexCoord, Out.NextFrameTexCoord);

	// compute color
	Out.Color = Particle_ComputeColor(relativeAge, Seed, true);

	return Out;
}

// ----------------------------------------------------------------------------
float4 SoftParticlePixelShader(ParticleVSOutput_H In, uniform int fogMode, uniform int blendMode) COLORTARGET
{
	// do interpolation between two frames (for particles with video textures)
	float4 TextureColor = tex2D( SAMPLER(ParticleTextureSampler), In.ParticleTexCoord);
	float4 NextFrameColor = tex2D( SAMPLER(ParticleTextureSampler), In.NextFrameTexCoord.xy);
	float4 Color = lerp(TextureColor, NextFrameColor, In.NextFrameTexCoord.z) * In.Color;

#if SUPPORT_SOFT_PARTICLE
	float linearBlend = SOFT_PARTICLE_GET_LINEAR_BLEND(In);
	ApplySoftParticleBlend(blendMode, linearBlend, Color);
#endif // #if SUPPORT_SOFT_PARTICLE

#if SUPPORT_FOG
	// Apply fog
	ApplyFog(fogMode, In.Fog, Color);
#endif // #if SUPPORT_FOG

	return Color;
}

// ----------------------------------------------------------------------------
// SHADER: XENON
// ----------------------------------------------------------------------------
ParticleVSOutput_H ParticleVertexShader_Xenon(float4 StartPositionLifeInFrames : POSITION, 
		float4 StartVelocityCreationFrame : TEXCOORD0, float2 SeedAndIndex : TEXCOORD1)
{
	return ParticleVertexShader_H(StartPositionLifeInFrames, StartVelocityCreationFrame, SeedAndIndex, GeometryUpdate_RotationType - 1);
}

float4 ParticlePixelShader_Xenon(ParticleVSOutput_H In ) : COLOR
{
	return SoftParticlePixelShader( In, GetParticleFogMode(), GetParticleBlendMode() );
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