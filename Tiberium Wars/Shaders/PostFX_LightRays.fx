//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// Image post processing effect simulating light rays
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

// Post effect parameters
int RaytracingSteps = 100;
float3 BrightnessScale = float3(3, 3, 3);
//texture CloudTexture; Definition see below
int CloudMipMapLevel = 0;


// ----------------------------------------------------------------------------
// Frame buffer 
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	string ResourceName = "ShaderPreviewShroud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Cloud
// ----------------------------------------------------------------------------
CloudSetup Cloud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud";
> = DEFAULT_CLOUD;

SAMPLER_2D_BEGIN( CloudTexture,
	string UIWidget = "None";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// DEPTH
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( SceneDepthSampler,
	string SasBindAddress = "PostEffect.LightRays.DepthTexture";
	)
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
int NumShadows
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.NumShadows";
> = 0;

ShadowSetup ShadowInfo
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Shadow[0]";
>;
SAMPLER_2D_SHADOW( ShadowMap )

// ----------------------------------------------------------------------------
// Transforms
// ----------------------------------------------------------------------------
float4x4 View : View;
float4x4 Projection : Projection;
float4x4 ViewI : ViewInverse;
float4x4 ProjectionI : ProjectionInverse;
float Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput DefaultVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord + 0.5 / 256;
	return Out;
}

// ----------------------------------------------------------------------------
float4 DefaultPS(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(FrameBufferSampler), TexCoord);
	return color;
}

// ----------------------------------------------------------------------------
VSOutput LightRayVS(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VSOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	return Out;
}

// ----------------------------------------------------------------------------
float4 LightRayPS(float2 TexCoord : TEXCOORD0) : COLOR
{
//return float4(MainDirectionalLight.Direction, 0);
//return float4(0, 0, 0, 1);
//return tex2D( SAMPLER(MacroSampler), TexCoord) * 100;
//return tex2D( SAMPLER(SceneDepthSampler), TexCoord).xxxx;// / 4;

	// We need to trace a ray from the camera through the pixel we are rendering
	// With the inverse projection (and view) matrix we can get a point
	// in [-1..1]x[-1..1]x[0..1] projection space to world space
	float4x4 projectionToWorld = mul(ProjectionI, ViewI);
	//float4x4 worldToProjection = mul(View, Projection);

	float maximumDepth = tex2D( SAMPLER(SceneDepthSampler), TexCoord).x;
	//maximumDepth = 1;
	
	float4 rayStart = float4(TexCoord.x * 2 - 1, -TexCoord.y * 2 + 1, 0, 1);
	float4 rayEnd = float4(TexCoord.x * 2 - 1, -TexCoord.y * 2 + 1, maximumDepth, 1);
	float4 worldRayStart4 = mul(rayStart, projectionToWorld);
	float3 worldRayStart = worldRayStart4.xyz / worldRayStart4.w;
	float4 worldRayEnd4 = mul(rayEnd, projectionToWorld);
	float3 worldRayEnd = worldRayEnd4.xyz / worldRayEnd4.w;

//return float4(distance(worldRayStart, worldRayEnd) / 1000, 0, 0, 0.1);

	float2 shroudTexCoord = CalculateShroudTexCoord(Shroud, worldRayEnd);
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	float3 accumulatedCloudLight = float3(0, 0, 0);

	//int numSteps = 100;
	int numSteps = RaytracingSteps;
	
	//worldRayEnd = lerp(worldRayStart, worldRayEnd, 0.3);
	//float3 initialWorldRayDelta = worldRayEnd - worldRayStart;
	//worldRayEnd = worldRayStart.xyz - (worldRayStart.z / initialWorldRayDelta.z) * initialWorldRayDelta;
	float3 worldPosition = worldRayStart;
	float3 worldPositionFirstStep = lerp(worldRayStart, worldRayEnd, 1.0 / numSteps);
	float3 worldRayDelta = worldPositionFirstStep - worldPosition;
	float2 cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	float2 cloudFirstStep = CalculateCloudTexCoord(Cloud, worldPositionFirstStep, Time);
	float2 cloudDelta = cloudFirstStep - cloudTexCoord; 
	float4 shadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, worldPosition);
	float4 shadowFirstStep = CalculateShadowMapTexCoord(ShadowInfo, worldPositionFirstStep);
	float4 shadowDelta = shadowFirstStep - shadowMapTexCoord;

	float clipped = 1;
	
	for (int i = 0; i < numSteps; i++)
	{
		//worldPosition = lerp(worldRayStart, worldRayEnd, (float)i / numSteps);
		worldPosition += worldRayDelta;

		//cloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
		cloudTexCoord += cloudDelta;
		
		//float3 cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
		float3 cloud = tex2Dlod( SAMPLER(CloudTexture), float4(cloudTexCoord, 0, CloudMipMapLevel));
		//cloud = saturate(cloud - 0.5) * 2;

		shadowMapTexCoord += shadowDelta;
		cloud *= shadowSimple( SAMPLER(ShadowMap), shadowMapTexCoord, ShadowInfo);
		
		/*float2 macroTexCoord = (worldPosition.xy + MapBorderWidth + MapCellSize / 2) / float2(MapSize.x, -MapSize.y);
		float height = tex2D( SAMPLER(MacroSampler), macroTexCoord).x;
		//return float4(cloud.x, (height * 5000 < worldPosition.z), 0, 0.3);
		clipped *= (height * 5100 < worldPosition.z);
		cloud *= clipped;*/
	
		accumulatedCloudLight += cloud;
	}

	accumulatedCloudLight /= numSteps;
	accumulatedCloudLight *= BrightnessScale / 400;
	accumulatedCloudLight *= distance(worldRayStart, worldRayEnd);
	//accumulatedCloudLight *= 200 / distance(worldRayStart, worldRayEnd);	
	accumulatedCloudLight *= shroud;

	return float4(accumulatedCloudLight, 0.1);
}

// ----------------------------------------------------------------------------
// Technique: Ultra High
// ----------------------------------------------------------------------------
technique Default_U
{
	pass LightRays
	{
		VertexShader = compile VS_VERSION_ULTRAHIGH LightRayVS();
		PixelShader = compile PS_VERSION_ULTRAHIGH LightRayPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;//true;
		SrcBlend = One;
		DestBlend = Zero;
		
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}

	pass FinalOverlay
	{
		VertexShader = compile VS_VERSION_LOW DefaultVS();
		PixelShader = compile PS_VERSION_LOW DefaultPS();

		ClipPlaneEnable = 0;
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
		
#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif
	}
}

// ----------------------------------------------------------------------------
// Technique: High and below
// ----------------------------------------------------------------------------
technique Default
{
	// Disabled
}
