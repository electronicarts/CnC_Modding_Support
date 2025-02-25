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
// static const int MaxSkinningBones = 80;			// Number of bones supported on >= VS2.0 hardware
// static const int MaxSkinningBones_L = 32;		// Number of bones supported on VS1.1 hardware
//
//////////////////////////////////////////////////////////////////////////////

#ifndef _SKINNING_FXH_
#define _SKINNING_FXH_

static const int MaxSkinningBones = 80;
static const int MaxSkinningBones_L = 32;

//
// Defines
//

// Define the bone representation to use:
#define BONES_AS_QUATERNION_TRANSLATION	// Lowest per-bone data, but cannot represent scaling
//#define BONES_AS_FLOAT4X3				// Medium per-bone data, but still incompatible with DXSAS
//#define BONES_AS_MATRIX				// Highest per-bone data, but compatible with DXSAS

#if defined(BONES_AS_QUATERNION_TRANSLATION)
	// Define this to allow non-skinned objects to use full world matrices.
	// Useful if quaternion-translation mode is used for skinning,
	// as otherwise no object can have scaling
	#define USE_NON_SKINNING_WORLD_MATRIX
#endif



//
// Helper functions/structures
//

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
#if defined(BONES_AS_QUATERNION_TRANSLATION)

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

#else

	#if defined(BONES_AS_MATRIX)
	
		#define BoneTransform float4x3
		
		float4x3 GetBoneMatrix(BoneTransform b)
		{
			return b;
		}
	
	#else // defined(BONES_AS_FLOAT4X3)
	
		struct BoneTransform
		{
			float4 Rows[3];
		};
		
		float4x3 GetBoneMatrix(BoneTransform b)
		{
			return transpose(float3x4(b));
		}
	
	#endif
	
	float3 BoneTransformPosition(BoneTransform b, float3 position)
	{
		return mul(float4(position, 1), GetBoneMatrix(b));
	}
	
	float3 BoneTransformDirection(BoneTransform b, float3 direction)
	{
		return mul(direction, GetBoneMatrix(b));
	}

#endif



//
// Global uploaded constants
//

int NumJointsPerVertex
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Skeleton.NumJointsPerVertex";
> = 0;


#if defined(USE_NON_SKINNING_WORLD_MATRIX)

float4x3 World : World;

#endif


#if !defined(EA_PLATFORM_XENON)
BoneTransform WorldBones[MaxSkinningBones*2]
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
>;

BoneTransform WorldBones_L[MaxSkinningBones_L*2]
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
>;

#else

shared BoneTransform WorldBones[MaxSkinningBones*2] : register(c0)
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
>;

shared BoneTransform WorldBones_L[MaxSkinningBones_L*2] : register(c0)
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
	float4 BlendIndices : BLENDINDICES;
	float2 BlendWeights : BLENDWEIGHT;
};


void CalculatePositionAndNormal(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal)
{
	if (NumJointsPerVertex > 1)
	{
		float2 blendIndices = D3DCOLORtoUBYTE4(InSkin.BlendIndices).xy;

		WorldPosition = 0;
		WorldNormal = 0;
		for (int i = 0; i < NumJointsPerVertex; i++)
		{
			int index = (int)blendIndices[i];
		
			index *= 2;
		
			WorldPosition += BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position[i]) * InSkin.BlendWeights[i];
			WorldNormal += BoneTransformDirection(WorldBones[index], InSkin.Normal[i]) * InSkin.BlendWeights[i];
		}
		WorldNormal = normalize(WorldNormal);
	}
	else if (NumJointsPerVertex > 0)
	{
		float boneIndex = D3DCOLORtoUBYTE4(InSkin.BlendIndices).x;
	
		int index = (int)boneIndex;

		index *= 2;

		WorldPosition = BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position[0]);
		WorldNormal = normalize(BoneTransformDirection(WorldBones[index], InSkin.Normal[0]));
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		WorldPosition = mul(float4(InSkin.Position[0], 1), World);
		WorldNormal = normalize(mul(InSkin.Normal[0], (float3x3)World));
#else
		WorldPosition = BoneTransformPosition(WorldBones[0], InSkin.Position[0]);
		WorldNormal = normalize(BoneTransformDirection(WorldBones[0], InSkin.Normal[0]));
#endif
	}
}

// Low profile version of function above, copy-and-pasted then replaced WorldBones by WorldBones_L. Sorry has to be ugly.
void CalculatePositionAndNormal_L(VSInputSkinningMultipleBones InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal)
{
	if (NumJointsPerVertex > 1)
	{
		float2 blendIndices = D3DCOLORtoUBYTE4(InSkin.BlendIndices).xy;
	
		WorldPosition = 0;
		WorldNormal = 0;
		for (int i = 0; i < NumJointsPerVertex; i++)
		{
			int index = (int)blendIndices[i];
		
			index *= 2;

			WorldPosition += BoneTransformPosition(WorldBones_L[index], WorldBones_L[index+1], InSkin.Position[i]) * InSkin.BlendWeights[i];
			WorldNormal += BoneTransformDirection(WorldBones_L[index], InSkin.Normal[i]) * InSkin.BlendWeights[i];
		}
		WorldNormal = normalize(WorldNormal);
	}
	else if (NumJointsPerVertex > 0)
	{
		float boneIndex = D3DCOLORtoUBYTE4(InSkin.BlendIndices).x;
	
		int index = (int)boneIndex;

		index *= 2;

		WorldPosition = BoneTransformPosition(WorldBones_L[index], WorldBones_L[index+1], InSkin.Position[0]);
		WorldNormal = normalize(BoneTransformDirection(WorldBones_L[index], InSkin.Normal[0]));
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		WorldPosition = mul(float4(InSkin.Position[0], 1), World);
		WorldNormal = normalize(mul(InSkin.Normal[0], (float3x3)World));
#else
		WorldPosition = BoneTransformPosition(WorldBones_L[0], InSkin.Position[0]);
		WorldNormal = normalize(BoneTransformDirection(WorldBones_L[0], InSkin.Normal[0]));
#endif
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
	float4 BlendIndices : BLENDINDICES;
};


void CalculatePositionAndTangentFrame(VSInputSkinningOneBoneTangentFrame InSkin, int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal, out float3 WorldTangent, out float3 WorldBinormal)
{
	if (NumJointsPerVertex > 0)
	{
		int index = D3DCOLORtoUBYTE4(InSkin.BlendIndices).x * 2;

		WorldPosition = BoneTransformPosition(WorldBones[index], WorldBones[index+1], InSkin.Position);
		WorldNormal = BoneTransformDirection(WorldBones[index], InSkin.Normal);
		WorldTangent = BoneTransformDirection(WorldBones[index], InSkin.Tangent);
		WorldBinormal = BoneTransformDirection(WorldBones[index], InSkin.Binormal);
		// Note: re-normalization skipped as quaternion-based BoneTransform can't do scaling anyway
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		WorldPosition = mul(float4(InSkin.Position, 1), World);
		WorldNormal = normalize(mul(InSkin.Normal, (float3x3)World));
		WorldTangent = normalize(mul(InSkin.Tangent, (float3x3)World));
		WorldBinormal = normalize(mul(InSkin.Binormal, (float3x3)World));
#else
		WorldPosition = BoneTransformPosition(WorldBones[0], WorldBones[0+1], InSkin.Position);
		WorldNormal = BoneTransformDirection(WorldBones[0], InSkin.Normal);
		WorldTangent = BoneTransformDirection(WorldBones[0], InSkin.Tangent);
		WorldBinormal = BoneTransformDirection(WorldBones[0], InSkin.Binormal);
		// Note: re-normalization skipped as quaternion-based BoneTransform can't do scaling anyway
#endif
	}
}




void CalculatePositionAndTangentFrame_L(VSInputSkinningOneBoneTangentFrame InSkin, uniform int NumJointsPerVertex,
	out float3 WorldPosition, out float3 WorldNormal, out float3 WorldTangent, out float3 WorldBinormal)
{
	if (NumJointsPerVertex > 0)
	{
		int index = D3DCOLORtoUBYTE4(InSkin.BlendIndices).x * 2;

		WorldPosition = BoneTransformPosition(WorldBones_L[index], WorldBones_L[index+1], InSkin.Position);
		WorldNormal = BoneTransformDirection(WorldBones_L[index], InSkin.Normal);
		WorldTangent = BoneTransformDirection(WorldBones_L[index], InSkin.Tangent);
		WorldBinormal = BoneTransformDirection(WorldBones_L[index], InSkin.Binormal);

		// Note: re-normalization skipped as quaternion-based BoneTransform can't do scaling anyway
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		WorldPosition = mul(float4(InSkin.Position, 1), World);
		WorldNormal = normalize(mul(InSkin.Normal, (float3x3)World));
		WorldTangent = normalize(mul(InSkin.Tangent, (float3x3)World));
		WorldBinormal = normalize(mul(InSkin.Binormal, (float3x3)World));
#else
		WorldPosition = BoneTransformPosition(WorldBones_L[0], WorldBones_L[0+1], InSkin.Position);
		WorldNormal = BoneTransformDirection(WorldBones_L[0], InSkin.Normal);
		WorldTangent = BoneTransformDirection(WorldBones_L[0], InSkin.Tangent);
		WorldBinormal = BoneTransformDirection(WorldBones_L[0], InSkin.Binormal);
		// Note: re-normalization skipped as quaternion-based BoneTransform can't do scaling anyway
#endif
	}
}


float3 GetFirstBonePosition(float4 BlendIndices, int NumJointsPerVertex)
{
	if (NumJointsPerVertex > 0)
	{
		int index = D3DCOLORtoUBYTE4(BlendIndices).x * 2;

		return WorldBones[index+1].xyz;
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		return World[3];
#else
		return WorldBones[0+1].xyz;
#endif
	}
}

float3 GetFirstBonePosition_L(float4 BlendIndices, int NumJointsPerVertex)
{
	if (NumJointsPerVertex > 0)
	{
		int index = D3DCOLORtoUBYTE4(BlendIndices).x * 2;

		return WorldBones_L[index+1].xyz;
	}
	else
	{
#if defined(USE_NON_SKINNING_WORLD_MATRIX)
		return World[3];
#else
		return WorldBones_L[0+1].xyz;
#endif
	}
}


#endif // Include guard
