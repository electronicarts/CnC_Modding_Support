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
#if 0 //defined(EA_PLATFORM_PS3)
	// Note: (WSK) 2008/11/21 - this has proven to be faster on ps3,  saved about 8 instructions on the vertex shader according to GPAD
	//						  - TODO: need to verify there is savings for pc and xenon too.
	float4 Q = rotation;
	float3 V = position;
	float3 T;
	float3 R;
	T = Q.www * V.xyz;
	R = Q.yzx * V.zxy - Q.zxy * V.yzx + T;
	R = Q.yzx * R.zxy - Q.zxy * R.yzx;
	return 2 * R + V;
#else // #if defined(EA_PLATFORM_PS3)	
	float4 a;
	a = rotation.wwwx * position.xyzx + rotation.yzxy * position.zxyy;
	a.w = -a.w;
	a -= rotation.zxyz * position.yzxz;

	return rotation.www * a.xyz - rotation.xyz * a.www + rotation.yzx * a.zxy - rotation.zxy * a.yzx;
#endif // #if defined(EA_PLATFORM_PS3)	
}


//
// Definition of the BoneTransform struct with accessor functions
//

#if defined(USE_MATRIX_FOR_SKINNING)

	struct BoneTransform
	{
		float4 Matrix[4];
	};

    // Declare the bone transformation, 
    // Note: we don't need to declare this to be in global parameters since the shader should upload these when it's needed
    //       and these are not supposed to shared across shaders.
    #if !defined(USE_INDIRECT_CONSTANT) && !defined(EA_PLATFORM_PS3)
        float4 WorldBones[MaxSkinningBones*NUM_CONSTANTS_PER_BONE] : register(c0)
        <
            string UIWidget = "None";
            string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
        >;
    #endif

	float3 BoneTransformPosition(BoneTransform b, float3 position)
	{
		float4 position4 = float4(position, 1.0);
		return float3( dot(position4, b.Matrix[0]), dot(position4, b.Matrix[1]), dot(position4, b.Matrix[2]) );
	}

	float3 BoneTransformDirection(BoneTransform b, float3 direction)
	{
		return float3( dot(direction, b.Matrix[0].xyz), dot(direction, b.Matrix[1].xyz), dot(direction, b.Matrix[2].xyz) );
	}

	float GetBoneOpacity(int boneIndex)
	{
		int index = boneIndex * NUM_CONSTANTS_PER_BONE;
		return saturate(WorldBones[index+3].x);
	}

	void GetBoneTransform(int boneIndex, out BoneTransform boneTransform)
	{
		int index = boneIndex * NUM_CONSTANTS_PER_BONE;

		boneTransform.Matrix[0] = WorldBones[index  ];
		boneTransform.Matrix[1] = WorldBones[index+1];
		boneTransform.Matrix[2] = WorldBones[index+2];
	}

#else // #if defined(USE_MATRIX_FOR_SKINNING)

    // Declare the bone transformation, 
    // Note: we don't need to declare this to be in global parameters since the shader should upload these when it's needed
    //       and these are not supposed to shared across shaders.
    #if !defined(USE_INDIRECT_CONSTANT) && !defined(EA_PLATFORM_PS3)
        float4 WorldBones[MaxSkinningBones*NUM_CONSTANTS_PER_BONE]
        <
            string UIWidget = "None";
            string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
        >;
    #endif

	struct BoneTransform
	{
		float4 Rotation;
		float4 Translation_Zero;
	};

	float3 BoneTransformPosition(BoneTransform b, float3 position)
	{	
		return Quaternion_RotateVector(b.Rotation, position) + b.Translation_Zero.xyz;
	}

	float3 BoneTransformDirection(BoneTransform b, float3 direction)
	{
		return Quaternion_RotateVector(b.Rotation, direction);
	}

	float GetBoneOpacity(int boneIndex)
	{
		int index = boneIndex * NUM_CONSTANTS_PER_BONE;
		return saturate(WorldBones[index+1].w);
	}

	void GetBoneTransform(int boneIndex, out BoneTransform boneTransform)
	{
		int index = boneIndex * NUM_CONSTANTS_PER_BONE;

		boneTransform.Rotation			= WorldBones[index];
		boneTransform.Translation_Zero	= WorldBones[index+1];
	}

#endif // #if defined(USE_MATRIX_FOR_SKINNING)

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
STATICBOOL(bool UseOneJointPerVertex
<
	string UIWidget = "None";
> = false;)

STATICBOOL(bool UseTwoJointPerVertex
<
	string UIWidget = "None";
> = false;)
#endif

//
// Functions/structs for calculating the skinning with multiple bones, but without tangent frame
//

struct VSInputSkinningMultipleBones
{
	float3 Position_0	: POSITION;
	float3 Normal_0		: NORMAL;
#if defined(EA_PLATFORM_PS3)
	float3 Position_1	: TEXCOORD6;
	float3 Normal_1		: TEXCOORD7;
#else // #if defined(EA_PLATFORM_PS3)
	float3 Position_1	: POSITION1;
	float3 Normal_1		: NORMAL1;
#endif // #if defined(EA_PLATFORM_PS3)
	float2 BlendIndices : BLENDINDICES;
	float2 BlendWeights : BLENDWEIGHT;
};


void CalculatePositionAndNormal(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal)
{
#if defined(EA_PLATFORM_PS3)
	if (UseTwoJointPerVertex)
#else
	if (NumJointsPerVertex == 2)
#endif
	{
		BoneTransform boneTransform;
		GetBoneTransform((int)InSkin.BlendIndices.x, boneTransform);

		WorldPosition	= BoneTransformPosition(boneTransform, InSkin.Position_0) * InSkin.BlendWeights.x;
		WorldNormal	 	= BoneTransformDirection(boneTransform, InSkin.Normal_0) * InSkin.BlendWeights.x;

		// Calculate for the second bone. Like above except stored in the y part of the variables.
		GetBoneTransform((int)InSkin.BlendIndices.y, boneTransform);
		WorldPosition	+= BoneTransformPosition(boneTransform, InSkin.Position_1) * InSkin.BlendWeights.y;
		WorldNormal	 	+= BoneTransformDirection(boneTransform, InSkin.Normal_1) * InSkin.BlendWeights.y;
	}
#if defined(EA_PLATFORM_PS3)
	else if (UseOneJointPerVertex)
#else
	else if (NumJointsPerVertex == 1)
#endif
	{
		BoneTransform boneTransform;
		GetBoneTransform((int)InSkin.BlendIndices.x, boneTransform);

		WorldPosition	= BoneTransformPosition(boneTransform, InSkin.Position_0);
		WorldNormal	 	= BoneTransformDirection(boneTransform, InSkin.Normal_0);
	}
	else
	{
		WorldPosition	= mul(float4(InSkin.Position_0, 1), World);
		WorldNormal		= mul(InSkin.Normal_0, (float3x3)World);
	}

	// Normalize after the calculations.
	WorldNormal = MaybeNormalize(WorldNormal);
}

float GetOpacity(VSInputSkinningMultipleBones InSkin, uniform int NumJointsPerVertex)
{
#if defined(EA_PLATFORM_PS3)
	if (UseTwoJointPerVertex)
#else
	if (NumJointsPerVertex == 2)
#endif
	{
		float visibility = GetBoneOpacity((int)InSkin.BlendIndices.x) * InSkin.BlendWeights.x;
		visibility += GetBoneOpacity((int)InSkin.BlendIndices.y) * InSkin.BlendWeights.y;
		return visibility;
	}
#if defined(EA_PLATFORM_PS3)
	else if (UseOneJointPerVertex)
#else
	else if (NumJointsPerVertex == 1)
#endif
	{
		return GetBoneOpacity((int)InSkin.BlendIndices.x);
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
#if defined(EA_PLATFORM_PS3)
	if (UseTwoJointPerVertex || UseOneJointPerVertex)
#else
	if (NumJointsPerVertex > 0)
#endif
	{
		BoneTransform boneTransform;
		GetBoneTransform((int)InSkin.BlendIndices.x, boneTransform);

		WorldPosition	= BoneTransformPosition(boneTransform, InSkin.Position);
		WorldNormal	 	= BoneTransformDirection(boneTransform, InSkin.Normal);
		WorldTangent	= BoneTransformDirection(boneTransform, InSkin.Tangent);
		WorldBinormal	= BoneTransformDirection(boneTransform, InSkin.Binormal);
	}
	else
	{
		WorldPosition	= mul(float4(InSkin.Position, 1), World);
		WorldNormal		= MaybeNormalize(mul(InSkin.Normal, (float3x3)World));
		WorldTangent	= MaybeNormalize(mul(InSkin.Tangent, (float3x3)World));
		WorldBinormal	= MaybeNormalize(mul(InSkin.Binormal, (float3x3)World));
	}
}



float GetOpacity(VSInputSkinningOneBoneTangentFrame InSkin, uniform int NumJointsPerVertex)
{
#if defined(EA_PLATFORM_PS3)
	if (UseTwoJointPerVertex || UseOneJointPerVertex)
#else
	if (NumJointsPerVertex > 0)
#endif
	{
		return GetBoneOpacity((int)InSkin.BlendIndices.x);
	}
	else
	{
		return 1.0;
	}
}

float3 GetFirstBonePosition(float BlendIndex, int NumJointsPerVertex)
{
#if defined(EA_PLATFORM_PS3)
	if (UseTwoJointPerVertex || UseOneJointPerVertex)
#else
	if (NumJointsPerVertex > 0)
#endif
	{
		int index = (int)BlendIndex * NUM_CONSTANTS_PER_BONE;

        #if defined(USE_MATRIX_FOR_SKINNING)
    		return float3( WorldBones[index].w, WorldBones[index+1].w, WorldBones[index+2].w );
        #else // #if defined(USE_MATRIX_FOR_SKINNING)
		    return WorldBones[index+1].xyz;
        #endif // #if defined(USE_MATRIX_FOR_SKINNING)
	}
	else
	{
		return World[3];
	}
}


#endif // Include guard
