//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Definitions of functions and global variables for skinning
//
// Before including this header, define the number of bone matrices the shader
// is to support. This is limited by the number of free vertex shader constant
// registers.
//
// Declare this:
//
// static const int MaxSkinningBonesPerVertex = 2;	// Number of bones per vertex supported (1 or 2)
// static const int MaxSkinningBones = 64;			// Number of bones supported
//
//////////////////////////////////////////////////////////////////////////////

#ifndef _SKINNING_FXH_
#define _SKINNING_FXH_

#include "RegisterMap.fxh"


//
// Helper functions/structures
//

float3 MaybeNormalize(float3 direction)
{
	// Normalization causes issues with HDR render targets that preserve floating point specials (eg on a Geforce7800).
	// At the moment we are not doing scaling, so the normals should be ok usually.
	// If we do scaling again, we will have to implement a "safe normalize" for some hardware,
	// sth equivalent to:  return normalize(direction);
	return direction;
}

float3 Quaternion_RotateVector(float4 rotation, float3 position)
{
/*	float x = rotation.w * position.x + rotation.y * position.z - rotation.z * position.y;
	float y = rotation.w * position.y + rotation.z * position.x - rotation.x * position.z;
	float z = rotation.w * position.z + rotation.x * position.y - rotation.y * position.x;
	float w = -(rotation.x * position.x + rotation.y * position.y) - rotation.z * position.z;

	float3 outPosition;
	outPosition.x = rotation.w * x - w * rotation.x + rotation.y * z - y * rotation.z;
	outPosition.y = rotation.w * y - w * rotation.y + rotation.z * x - z * rotation.x;
	outPosition.z = rotation.w * z - w * rotation.z + rotation.x * y - x * rotation.y;

	return outPosition;
*/
	
	float4 a;
	a = rotation.wwwx * position.xyzx + rotation.yzxy * position.zxyy;
	a.w = -a.w;
	a -= rotation.zxyz * position.yzxz;

	return rotation.www * a.xyz - rotation.xyz * a.www + rotation.yzx * a.zxy - rotation.zxy * a.yzx;
}


//
// Definition of the BoneTransform struct with accessor functions
//
#define BoneTransform float4

//	struct BoneTransform;
//	{
//		float4 Rotation;
//		float4 Translation_Zero;
//	};

float3 BoneTransformPosition(BoneTransform r, BoneTransform t, float3 position)
{	
	return Quaternion_RotateVector(r, position) + t.xyz;
//		return Quaternion_RotateVector(b.Rotation, position) + b.Translation_Zero.xyz;
}

float3 BoneTransformDirection(BoneTransform r, float3 direction)
{
	return Quaternion_RotateVector(r, direction);
//		return Quaternion_RotateVector(b.Rotation, direction);
}


//
// Global uploaded constants
// Note: this will be declared in GlobalParameters.fxh when using indirect constants
//
int NumJointsPerVertex
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Skeleton.NumJointsPerVertex";
> = 0;

#if defined(EA_PLATFORM_PS3)
float4x3 World : World;
#else
float4x3 World : World : REGISTER_EVAL_VS(REGISTER_NON_SKINNING_WORLD_MATRIX_FIRST);
#endif

// Declare the bone transformation, 
// Note: we don't need to declare this to be in global parameters since the shader should upload these when it's needed
//       and these are not supposed to shared across shaders.
#if !defined(USE_INDIRECT_CONSTANT)
BoneTransform WorldBones[MaxSkinningBones*2]
<
    string UIWidget = "None";
    string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
>;
#endif

//
// Functions/structs for calculating the skinning with multiple bones, but without tangent frame
//

struct VSInputSkinningMultipleBones
{
	float3 Position[MaxSkinningBonesPerVertex] : POSITION;
	float3 Normal[MaxSkinningBonesPerVertex] : NORMAL;
	float2 BlendIndices : BLENDINDICES;
	float2 BlendWeights : BLENDWEIGHT;
};


void CalculatePositionAndNormal(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal)
{
	if (NumJointsPerVertex == 2)
	{
		int index = (int)InSkin.BlendIndices.x * 2;
		WorldPosition = BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position[0]) * InSkin.BlendWeights.x;
		WorldNormal = BoneTransformDirection(WorldBones[index], InSkin.Normal[0]) * InSkin.BlendWeights.x;

		// Calculate for the second bone. Like above except stored in the y part of the variables.
		index = (int)InSkin.BlendIndices.y * 2;
		WorldPosition += BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position[1]) * InSkin.BlendWeights.y;
		WorldNormal += BoneTransformDirection(WorldBones[index], InSkin.Normal[1]) * InSkin.BlendWeights.y;
		
		// Normalize after the calculations.
		WorldNormal = MaybeNormalize(WorldNormal);
	}
	else if (NumJointsPerVertex == 1)
	{
		float boneIndex = InSkin.BlendIndices.x;
	
		int index = (int)boneIndex;

		index *= 2;

		WorldPosition = BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position[0]);
		WorldNormal = MaybeNormalize(BoneTransformDirection(WorldBones[index], InSkin.Normal[0]));
	}
	else
	{
		WorldPosition = mul(float4(InSkin.Position[0], 1), World);
		WorldNormal = MaybeNormalize(mul(InSkin.Normal[0], (float3x3)World));
	}
}

float GetOpacity(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex)
{
	if (NumJointsPerVertex == 2)
	{
		int index = (int)InSkin.BlendIndices.x * 2;
		float visibility = WorldBones[index+1].w * InSkin.BlendWeights.x;
		
		index = (int)InSkin.BlendIndices.y * 2;
		visibility += WorldBones[index+1].w * InSkin.BlendWeights.y;

		return visibility;
	}
	else if (NumJointsPerVertex == 1)
	{
		float boneIndex = InSkin.BlendIndices.x;
	
		int index = (int)boneIndex;

		index *= 2;

		return WorldBones[index+1].w;
	}
	else
	{
		return 1.0;
	}
}



//
// Functions/structs for calculating the skinning with just one, but with a tangent frame
//

struct VSInputSkinningOneBoneTangentFrame
{
	float3 Position : POSITION;
	float3 Normal : NORMAL;
	float3 Tangent : TANGENT;
	float3 Binormal : BINORMAL;
	float BlendIndices : BLENDINDICES;
};


void CalculatePositionAndTangentFrame(VSInputSkinningOneBoneTangentFrame InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal, out float3 WorldTangent, out float3 WorldBinormal)
{
	if (NumJointsPerVertex > 0)
	{
		int index = InSkin.BlendIndices.x * 2;

		WorldPosition = BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position);
		WorldNormal = BoneTransformDirection(WorldBones[index], InSkin.Normal);
		WorldTangent = BoneTransformDirection(WorldBones[index], InSkin.Tangent);
		WorldBinormal = BoneTransformDirection(WorldBones[index], InSkin.Binormal);
		// Note: re-normalization skipped as quaternion-based BoneTransform can't do scaling anyway
	}
	else
	{
		WorldPosition = mul(float4(InSkin.Position, 1), World);
		WorldNormal = MaybeNormalize(mul(InSkin.Normal, (float3x3)World));
		WorldTangent = MaybeNormalize(mul(InSkin.Tangent, (float3x3)World));
		WorldBinormal = MaybeNormalize(mul(InSkin.Binormal, (float3x3)World));
	}
}



float GetOpacity(VSInputSkinningOneBoneTangentFrame InSkin, int NumJointsPerVertex)
{
	if (NumJointsPerVertex > 0)
	{
		float boneIndex = InSkin.BlendIndices.x;
	
		int index = (int)boneIndex;

		index *= 2;

		return WorldBones[index+1].w;
	}
	else
	{
		return 1.0;
	}
}

float3 GetFirstBonePosition(float BlendIndex, int NumJointsPerVertex)
{
	if (NumJointsPerVertex > 0)
	{
		int index = BlendIndex * 2;

		return WorldBones[index+1].xyz;
	}
	else
	{
		return World[3];
	}
}


#endif // Include guard
