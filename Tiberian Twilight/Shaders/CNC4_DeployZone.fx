//////////////////////////////////////////////////////////////////////////////
// 2006 Electronic Arts Inc
//
// Shader for the spawn zone effect
//////////////////////////////////////////////////////////////////////////////


//#define SUPPORT_SHADER_ENERGIA 1 

//#include "Objects.fxh"

// TODO: Rohith - This shader should use the refactored one by MDavies. 
// This is just a temp shader to show the spawnzone effect. Returns a single color for now.

//#define SUPPORT_SPAWN_ZONE 1

//#include "CNC4_EnergyShield.fx"


#include "Common.fxh"
#include "MacroTexture.fxh"


float4 DeployZoneGDIColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeployZoneGDIColor";
> = float4(0.0f,0.1f,1.0f,1.0f);

float4 DeployZoneNODColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeployZoneNODColor";
> = float4(1.0f,0.0f,0.0f,1.0f);

float DeployZoneColorScale
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.DeployZoneColorScale";
> = 1.0f;


SAMPLER_2D_BEGIN( DeployZone,
	string SasBindAddress = "WW3D.Deployment_Zone";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( FilteredNoise,
	string SasBindAddress = "WW3D.FilteredNoise";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x4 Projection     : Projection;
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;

// ---------------------------------------------------------------------------
// Input Struct Definition
// ---------------------------------------------------------------------------
struct VSInput
{
    float3 Position        : POSITION;
    float4 Color           : COLOR0; 
		float2 TexCoord0			 : TEXCOORD0;
};

// ---------------------------------------------------------------------------
// Output Struct Definition
// ---------------------------------------------------------------------------
struct VSOutput
{
	float4 Position   : POSITION;	
	float4 Color      : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float3 ObjPos : TEXCOORD1;
	//float2 MacroTexCoord : TEXCOORD2;
};

// ---------------------------------------------------------------------------
// SpawnZoneEffect Vertex Shader
// ---------------------------------------------------------------------------
VSOutput VS(VSInput Input)
{
	VSOutput Out;
	
	Out.Position = mul( float4( Input.Position, 1 ), GetViewProjection() );
	Out.Color = Input.Color;	
	Out.Position.z = 0.0f;
	
	Out.ObjPos = Input.Position;
	Out.TexCoord0 = Input.TexCoord0;
	
	return Out;
}

// ---------------------------------------------------------------------------
// SpawnZoneEffect Pixel Shader
// ---------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float2 texCoord = In.ObjPos.xy * 0.0091f; //0.01f;
	float3 GridTex = tex2D(SAMPLER(DeployZone), texCoord);

	float GridHex = GridTex.x;
	float GridAlpha = saturate(GridTex.x + 0.1f); 	
	float3 DZColor = In.Color.xyz;	

	//noise version2 
	//test w/ filtered noise
	//layer 1
	float L1tcx = (texCoord.x * 0.9 * 0.25f + (Time * 0.025f));
	float L1tcy = (texCoord.y * 0.7 * 0.25f + (Time * 0.0125f));
	float4 filtnoise = tex2D(SAMPLER(FilteredNoise), float2(L1tcx,L1tcy));
	filtnoise.w = filtnoise.x;
	//layer 2
	float L2tcx = (texCoord.x * 1.2 * 0.25f - (Time * 0.025f));
	float L2tcy = (texCoord.y * 0.8 * 0.25f + (Time * 0.0125f));
	float4 filtnoise2 = tex2D(SAMPLER(FilteredNoise), float2(L2tcx,L2tcy));
	filtnoise2.w = filtnoise2.x;
	//layer 3
	float L3tcx = (texCoord.x * 0.97f * 0.25f - (Time * 0.005f));
	float L3tcy = (texCoord.y * 1.06f * 0.25f - (Time * 0.01f));
	float4 filtnoise3 = tex2D(SAMPLER(FilteredNoise), float2(L3tcx,L3tcy));
	filtnoise3.w = filtnoise3.x;
	//cumulative
	float4 rtncolor = (pow(filtnoise,2) + pow(filtnoise2,2) + pow(filtnoise3,2)) * 2.0f;
	
	float4 deployzone = float4(rtncolor.xyz, GridAlpha);
	
	//grid
	deployzone.xyz = deployzone.xyz * GridAlpha.xxx * DZColor.xyz * 2.0f * GridHex + (DZColor.xyz * 0.1f * (1.0f - GridAlpha));

	return deployzone;

}

// ---------------------------------------------------------------------------
// SpawnZoneBorderEffect Pixel Shader
// ---------------------------------------------------------------------------
float4 PS_Borders(VSOutput In) : COLOR
{	
	float4 borderColor = float4(In.Color.xyz,1.0f);
	static const float borderColorScale = 3.0f;

	//Note - The border lines of the drop zone have a color gradient in the alpha channel
	// This lets us apply an arbitrary alpha ramp and avoids the tesselation visible
	// from a straight texture lookup in the terrain shader
	float retalpha = saturate(smoothstep(0, 0.2f, 1.0 - In.Color.a) + (1.0f - smoothstep(0.7f, 0.9f, 1.0 - In.Color.a)) - 1.0f);
	
	return float4(borderColor.rgb * borderColorScale, retalpha);
}

// ---------------------------------------------------------------------------
technique SpawnZoneEffect
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		CullMode = None;
		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
	
#if defined(EA_PLATFORM_PS3)	
		AlphaBlendEnable = false;
#else
		AlphaBlendEnable = true;
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}

// ---------------------------------------------------------------------------
technique SpawnZoneBorderEffect
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS_Borders();

		CullMode = None;
		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
	
#if defined(EA_PLATFORM_PS3)	
		AlphaBlendEnable = false;
#else
		AlphaBlendEnable = true;
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}

#if ENABLE_LOD

// ---------------------------------------------------------------------------
technique SpawnZoneEffect_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		CullMode = None;
		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
	
#if defined(EA_PLATFORM_PS3)	
		AlphaBlendEnable = false;
#else
		AlphaBlendEnable = true;
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}

// ---------------------------------------------------------------------------
// Output Struct Definition
// ---------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position   : POSITION;	
	float4 Color      : COLOR0;
};

// ---------------------------------------------------------------------------
// SpawnZoneEffect Vertex Shader
// ---------------------------------------------------------------------------
VSOutput_L VS_L(VSInput Input)
{
	VSOutput_L Out;
	
	Out.Position = mul( float4( Input.Position, 1 ), GetViewProjection() );
	Out.Color.rgb = Input.Color.rgb;

	// Calculate opacity based on the ambient light settings, this ensure the deploy zone color is still visible in various lighting
	float Opacity = 1.0f - 0.33f * (AmbientLightColor.r + AmbientLightColor.g + AmbientLightColor.b) ;

	static const float SPAWNZONE_OPACITY_SCALE_FACTOR = 0.75f;
	Out.Color.a = Opacity * SPAWNZONE_OPACITY_SCALE_FACTOR;
	
	return Out;
}

float4 PS_L(VSOutput_L In) : COLOR
{
	return In.Color;
}

// ---------------------------------------------------------------------------
technique SpawnZoneEffect_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_L();
		PixelShader  = compile PS_2_0 PS_L();

		CullMode = None;
		ZEnable = false;
		ZWriteEnable = false;
		AlphaTestEnable = false;
	
#if defined(EA_PLATFORM_PS3)	
		AlphaBlendEnable = false;
#else
		AlphaBlendEnable = true;
#endif
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}

#endif // #if ENABLE_LOD



