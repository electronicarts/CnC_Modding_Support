//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Shroud FX
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"
#include "Gamma.fxh"

// ----------------------------------------------------------------------------
// Texture declarations

SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( FilteredNoise,
	string SasBindAddress = "WW3D.FilteredNoise";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( ShroudCloudA,
	string SasBindAddress = "WW3D.ShroudCloudA";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( ShroudCloudB,
	string SasBindAddress = "WW3D.ShroudCloudB";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
// Shroud(ingame info)
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;

SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.BlurTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

float4 ShroudColorA
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.ShroudColorA";
> = float4(0.682f, 0.416f, 0.325f, 1);

float4 ShroudColorB
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.ShroudColorB";
> = float4(0.819f, 0.353f, 0.353f, 1);

// ----------------------------------------------------------------------------
// Transforms
// ----------------------------------------------------------------------------
float4x4 ViewI : ViewInverse;
float4x4 ProjectionI : ProjectionInverse;
float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position						: POSITION;
	float2 TexCoord						: TEXCOORD0;
	float4 MapBorderCoefficientX2		: TEXCOORD1;
	float4 MapBorderCoefficientX		: TEXCOORD2;

#if defined(EA_PLATFORM_PS3)
	// On PS3, to save memory, we use the depth buffer as is, so we need to do more math
	float4 WorldFarPosition				: TEXCOORD3;
	float4 WorldNearPosition			: TEXCOORD4;
#else // #if defined(EA_PLATFORM_PS3)
	// For PC and PS3, the depth texture already has the depth in world position, so we could get by using simple math
	float3 WorldEyeDir					: TEXCOORD3;
#endif // #if defined(EA_PLATFORM_PS3)

};

// ----------------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------------
float3 ComputeWorldPosition(VSOutput In)
{
	float depth = TexDepth2D(SAMPLER(DepthTexture), In.TexCoord).x;

#if defined(EA_PLATFORM_PS3)
	float4 worldPosition4 = lerp(In.WorldNearPosition, In.WorldFarPosition, depth);
	worldPosition4 = worldPosition4 / worldPosition4.w;
	float3 worldPosition = worldPosition4.xyz;
#else 
	float3 eyePosition = ViewI[3].xyz;
	float3 worldPosition = eyePosition + depth * In.WorldEyeDir;
#endif // #if defined(EA_PLATFORM_PS3)
	
	return worldPosition;
}

// ----------------------------------------------------------------------------
// Default Vertex Shader
// ----------------------------------------------------------------------------
VSOutput DefaultVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;

	Out.MapBorderCoefficientX2	= CalcMapBorderCoefficientX2();
	Out.MapBorderCoefficientX	= CalcMapBorderCoefficientX();

#if defined(EA_PLATFORM_PS3)
	// Calculate the transformation matrix from screen to world
	float4x4 projectionToWorld = mul(ProjectionI, ViewI);

	float4 worldNear	= mul(float4(Position.xy, 0, 1), projectionToWorld);
	float4 worldFar		= mul(float4(Position.xy, 1, 1), projectionToWorld);

	Out.WorldNearPosition	= worldNear;//worldNear.xyz / worldNear.w;
	Out.WorldFarPosition	= worldFar;//worldFar.xyz / worldFar.w;
#else // #if defined(EA_PLATFORM_PS3)

	// We need to convert the view space depth values from the depth texture to world space positions.
	// First build a ray "through" the pixel in question
	float4 screenFarPlanePosition = float4(Position.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	float3 viewEyeDir = viewFarPlanePosition / viewFarPlanePosition.z;

	float3 worldEyeDir = mul(viewEyeDir, ViewI);
	
	Out.WorldEyeDir = worldEyeDir;

#endif // #if defined(EA_PLATFORM_PS3)

	return Out;
}

// ----------------------------------------------------------------------------
// ShroudPS
// ----------------------------------------------------------------------------
float4 ShroudPS(VSOutput In) : COLOR
{		
	//// The one i'm actually using is below
	float3 worldPosition = ComputeWorldPosition(In);

	///////////////////////
	// Calculating Shroud
	///////////////////////

	//// Get the shroud texture coordinates based on this world coordinate position
	float2 shroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);		
	float shroudValue = tex2D(SAMPLER(ShroudTexture), shroudTexCoord).x;

	//Shroud Cloud A
	float2 shroudCloudTexCoord = shroudTexCoord * 10.0f; //TODO -- THIS SCALE NEEDS TO BE A MULTIPLIER AGAINST MAPS SIZE (OR WORLD CELL SIZE)
	shroudCloudTexCoord.x -= (Time * 0.05f);
	float CloudColorA = tex2D(SAMPLER(ShroudCloudA), shroudCloudTexCoord);
	//mult color into cloud texture
	float CloudABright = 0.075f * 0.5f;
	
	//Shroud Cloud B
	shroudCloudTexCoord = shroudTexCoord * 10.0f;
	shroudCloudTexCoord.x -= (Time * 0.01f);
	float CloudColorB = tex2D(SAMPLER(ShroudCloudB), shroudCloudTexCoord);
	float CloudBBright = 0.075f * 0.5f;

	float4 shroudColor;	
	shroudColor.rgb = float3(ShroudColorA.xyz) * CloudColorA * CloudABright + float3(ShroudColorB.xyz) * CloudColorB * CloudBBright;	
	shroudColor.a = smoothstep(0.95f, 0.0f, shroudValue);	

	///////////////////////////
	// Calculating Map Border
	///////////////////////////

	// Applying map border fade in
	float4 mapBorderColor = float4(0,0,0,1);
	float mapBorderFactor = CalcMapBorderFactor(In.MapBorderCoefficientX2, In.MapBorderCoefficientX, worldPosition);

	// Lerp between the shroud and the map border color
	float4 color = lerp(mapBorderColor, shroudColor, mapBorderFactor);	

	return color;	
}


float4 ApplyShroudDistortionPS(VSOutput In) : COLOR
{		

	//// The one i'm actually using is below
	float3 worldPosition = ComputeWorldPosition(In);

	//// Get the shroud texture coordinates based on this world coordinate position
	float2 shroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);		
	float shroudValue = tex2D(SAMPLER(ShroudTexture), shroudTexCoord).x;


	//// return neutral from non-transition areas
	float4 neutral = float4(0.5,0.5,0,0);
	//////return neutral for non-transition areas
	if (shroudValue < 0.22f)
	{
		return neutral;
	}
	if (shroudValue > 0.95f)
	{
		return neutral;
	}


	//test w/ filtered noise
	//layer 1
	float L1tcx = (shroudTexCoord.x * 24 + (Time * 0.025f));
	float L1tcy = (shroudTexCoord.y * 24 + (Time * 0.0125f));
	float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(L1tcx,L1tcy));
	filtnoise.w = filtnoise.x;
	//layer 2
	float L2tcx = (shroudTexCoord.x * 24 - (Time * 0.025f));
	float L2tcy = (shroudTexCoord.y * 24 + (Time * 0.0125f));
	float4 filtnoise2 = tex2D(SAMPLER(FilteredNoise), float2(L2tcx,L2tcy));
	filtnoise2.w = filtnoise2.x;
	//layer 3
	float L3tcx = (shroudTexCoord.x * 30 - (Time * 0.005f));
	float L3tcy = (shroudTexCoord.y * 15 - (Time * 0.01f));
	float4 filtnoise3 = tex2D(SAMPLER(FilteredNoise), float2(L3tcx,L3tcy));
	filtnoise3.w = filtnoise3.x;
	//cumulative
	float4 rtncolor = (filtnoise + filtnoise2 + filtnoise3) * 0.33f;

	//scale noise -- around 0.5f
	//rtncolor = (rtncolor * 0.25f) + 0.375f; //maybe too subtle
	rtncolor = (rtncolor * 0.5f) + 0.25f;

	float4 color = lerp(rtncolor, neutral, smoothstep(0.0f, 0.9f, shroudValue));

	return float4(color.x, color.y, 1, 1);
}


// Technique: ShroudFinalTechnique
technique ShroudFinalTechnique
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		PixelShader = compile PS_3_0 ShroudPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false; //true for test only, need false;
		AlphaBlendEnable = true; //false for test only//for working need true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}


// Technique: ShroudDistortion 
technique ShroudDistortion
{
	pass p0
	{
		VertexShader = compile VS_3_0 DefaultVS();
		PixelShader = compile PS_3_0 ApplyShroudDistortionPS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}