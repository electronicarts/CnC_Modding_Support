//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Rotating the EnvironmentTexture Cubemap
//////////////////////////////////////////////////////////////////////////////


#define SUPPORT_GLOBAL_LIGHTS 1
#include "Common.fxh"

// ----------------------------------------------------------------------------
// Source Environment map
// ----------------------------------------------------------------------------
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string SasBindAddress = "Environment.SourceTexture";
	string ResourceType = "Cube";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
SAMPLER_CUBE_END

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float3 PixelDirection : TEXCOORD0; // direction in the cubemap associated with this pixel
};

// ----------------------------------------------------------------------------
// Vertex Shader, rotate the face to the correct frame
// ----------------------------------------------------------------------------
VSOutput VS_RotateEnv(float3 Position : POSITION, uniform float3 faceDir, uniform float3 upDir)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	float3 direction = float3(Position.xy,1);

	// rotate the default quad (along positive z) to align with the face direction
	float3 faceCross = normalize(cross(faceDir, upDir));
	float3 faceCross2 = cross(faceDir, faceCross);
	float3x3 worldToFace = float3x3(faceCross, faceCross2, faceDir);
	Out.PixelDirection = mul(direction, worldToFace);

	return Out;
}

VSOutput VS_RotateEnv_CubeFace0(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(1,0,0),float3(0,-1,0));
}

VSOutput VS_RotateEnv_CubeFace1(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(-1,0,0),float3(0,-1,0));
}

VSOutput VS_RotateEnv_CubeFace2(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(0,1,0),float3(0,0,1));
}

VSOutput VS_RotateEnv_CubeFace3(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(0,-1,0),float3(0,0,-1));
}

VSOutput VS_RotateEnv_CubeFace4(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(0,0,1),float3(0,-1,0));
}

VSOutput VS_RotateEnv_CubeFace5(float3 Position : POSITION)
{
	return VS_RotateEnv(Position,float3(0,0,-1),float3(0,-1,0));
}

// ----------------------------------------------------------------------------
// Pixel/Fragment Shader, rotate vector by light, load and return
// ----------------------------------------------------------------------------
float4 PS_RotateEnv(VSOutput In) : COLOR
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	// rotate the cube map to align with the light direction
	float3 lightDir = DirectionalLight_0_Direction.xyz;
	float3 lightCross = normalize(cross(lightDir, float3(1, 0, 0)));
	float3 lightCross2 = cross(lightDir, lightCross);
	float3x3 worldToLight = float3x3(lightCross, lightCross2, lightDir);
	float3 vect = mul(worldToLight, In.PixelDirection);

	return texCUBE( SAMPLER(EnvironmentTexture), vect );
}

// ----------------------------------------------------------------------------
// these are hardcoded frames defined by the vector towards the face and a perpendicular "up" vector
// ----------------------------------------------------------------------------
technique CubeFace0
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace0();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}
// ----------------------------------------------------------------------------
technique CubeFace1
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace1();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}
// ----------------------------------------------------------------------------
technique CubeFace2
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace2();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}
// ----------------------------------------------------------------------------
technique CubeFace3
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace3();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}
// ----------------------------------------------------------------------------
technique CubeFace4
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace4();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}
// ----------------------------------------------------------------------------
technique CubeFace5
{
    pass p0
    {
        VertexShader = compile VS_2_0 VS_RotateEnv_CubeFace5();
        PixelShader  = compile PS_2_0 PS_RotateEnv();
        
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }
}