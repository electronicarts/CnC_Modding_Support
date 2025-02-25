//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Shield FX (unlit, 2 texture solution, assumed additive)
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_FOG 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "Random.fxh"

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
static const int MaxSkinningBonesPerVertex = 2;

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 Projection     : Projection;
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 ProjectionI 	: ProjectionInverse;
float Time 				: Time;

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
	float4x4 GetViewProjection()
	{
		return mul(View, Projection);
	}

	float3 GetEyePosition()
	{
	    return ViewI[3];
	}
#endif // #if defined(_WW3D_)

// Used to see where the shader volume intersects an object.
SAMPLER_2D_BEGIN( DepthTexture,
	string SasBindAddress = "WW3D.DepthTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

bool OpacityOverrideEnable
<
	string UIName = "Use Opacity Override for Keyframes";
> = true;

float3 ColorDiffuseKey1
<
	string UIName = "Diffuse Material Color Keyframe 1";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float3 ColorDiffuseKey2
<
	string UIName = "Diffuse Material Color Keyframe 2";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float EmissiveHDRMultipler
<
	string UIName = "HDR Multiplier";
    string UIWidget = "Slider";
    float UIMax = 200;
> = 1.0;

bool MultiTextureEnable
<
	string UIName = "Multi-Texture Enable";
> = false;

bool MultiplyBlendEnable
<
	string UIName = "Multiply Enable";
> = false;

float4 DiffuseCoordOffset
<
	string UIName = "Diffuse Coord Offset/Scale"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.001f;
> = float4(0.00, 0.00, 1.0, 1.0);

float IntersectionMultiplier
<
	string UIName = "Intersection Multiplier: In Game Only";
	string UIWidget = "Slider";
	float UIMax = 100.0f;
	float UIMin = 0.0f;
> = 1.0f;

float EdgeFadeOut
<
	string UIName = "Edge Fade: Linear";
	string UIWidget = "Slider";
	float UIMax = 10.0f;
	float UIMin = -10.0f;
> = 0.0f;

bool TextureFadeOutEnable
<
	string UIName = "Edge Fade: Custom LUT";
> = false;	

SAMPLER_2D_BEGIN( TextureFadeOut,
	string UIName = "Edge Fade LUT";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END
	
// ----------------------------------------------------------------------------
// Displace Mapping
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( Texture_1,
	string UIName = "Displace Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float DisplaceScalar
<
	string UIName = "Displace Scale"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float DisplaceAmp
<
	string UIName = "Displace Amplitude"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float DisplaceDivergenceAngle
<
	string UIName = "Displace Divergence Angle"; 
    string UIWidget = "Slider";
	float UIMax = 180.0f;
	float UIMin = 0;
	float UIStep = 0.5f;
> = 0.0;

float DisplaceSpeed
<
	string UIName = "Displace Speed"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

bool CullingEnable
<
	string UIName = "Culling Enable";
> = true;

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

// ----------------------------------------------------------------------------
// SHADER : DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position			: POSITION;
	float4 DiffuseColor		: TEXCOORD0;
	float4 DiffuseTexCoord	: TEXCOORD1;
	float4 DisplaceTexCoord	: TEXCOORD2;
	float2 EdgeFadeValue_Fog: TEXCOORD3;
#if !defined(_3DSMAX_)	
	float2 ZPositions 		: TEXCOORD5; // x is z position, y is the ViewEyeDirection z component.	
	float4 NDCPosition 		: TEXCOORD6;
#endif // !defined(_3DSMAX_)
};

// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex)
{
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
	#if defined(_3DSMAX_)
		// Default vertex color is 0 in Max, that's bad.
		VertexColor = 1.0;
		
		// A little bit better motion previewing in MAX
		Time *= .25;
	#endif

	//Calculate the displace texture coordinates
	DisplaceSpeed *= Time * .01; // animate Displace as a multiplier of Time with a happy MAX modifier

	float2 DisplaceTexCoords = TexCoord0 * DisplaceScalar;

	// Build Displace Texture Rotation Matrix And Convert Degrees to Radians -----
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	sincos (DisplaceDivergenceAngle * .017453, sinAngle, cosAngle);

	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate Displace Divergence Texture Coords --------------------
	float2 DisplaceTexCoordsDiverge = mul(DisplaceTexCoords, uvCoordRotate);
	DisplaceTexCoordsDiverge.x += DisplaceSpeed;
	float2 DisplaceTexCoordsDivergeInv = mul(DisplaceTexCoords, transpose(uvCoordRotate));	
	DisplaceTexCoordsDivergeInv.x += DisplaceSpeed;	

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	float viewingAngle = abs(dot(worldEyeDir,normalize(worldNormal)));

	float fadeOut = 0;
	Out.EdgeFadeValue_Fog.x = 0;
	if	(TextureFadeOutEnable == true)
	{
		Out.EdgeFadeValue_Fog.x = saturate(1 - viewingAngle); // Used in texcoords for per pixel calcultion
	}
	else
	{
		if (EdgeFadeOut >= 0)
		{
			fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle); // Soften Edges
		}
		else
		{
			fadeOut = smoothstep(abs(EdgeFadeOut), 0, viewingAngle); // Soften Center
		}
		Out.EdgeFadeValue_Fog.x = fadeOut;
	}

	
	// Compute Diffuse Color and Final Vertex Color
	float3 diffuseColorKeyCurrent =	0;
		
	if (OpacityOverrideEnable == true) // Lerp between the 2 key colors using OpacityOverride to drive it
	{	
		//	float3 diffuseColorKeyCurrent = lerp(ColorDiffuseKey1, ColorDiffuseKey2, OpacityOverride); // <----- Gavin use me for the final

		// Use this temporarily till enginering has the hooks
		diffuseColorKeyCurrent = ColorDiffuseKey1; // <----- Gavin delete me in the final
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1);
	}
	else // Use it for its intended purpose
	{
		diffuseColorKeyCurrent = ColorDiffuseKey1;
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1) * OpacityOverride;
	}
	
	// Compute all registers
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	TexCoord0.xy *= DiffuseCoordOffset.zw;
	
	// Restrict the numerical range to 0-1 to hide precision issues in the texture sampling when Time goes really large
	float2 offset = frac(DiffuseCoordOffset.xy * Time);
	
	Out.DiffuseTexCoord.xyzw = TexCoord0.xyxy + offset.xyxy;
	if (MultiTextureEnable == true )
	{	
		Out.DiffuseTexCoord.zw = TexCoord0.xy * DiffuseCoordOffset.zw - offset;
	}
	Out.DisplaceTexCoord = float4(DisplaceTexCoordsDiverge, DisplaceTexCoordsDivergeInv);
	Out.EdgeFadeValue_Fog.y = CalculateFog(Fog, worldPosition, GetEyePosition());
	
#if !defined(_3DSMAX_)
	// --------------------------------------------------------------------------------------------------------
	// ------------------------------ Generate Z-depth information --------------------------------------------
	// --------------------------------------------------------------------------------------------------------
	
#define OUTLINE_SCALE 5	//Increase to make the outline bigger
	
	// Convert the vertex position into view space so that we can get the distance between the vertex and the background
	float4 vertexPosView = mul(float4(worldPosition, 1), View);
	
	// Finish projecting the position.
	float4 ndcPos = mul(vertexPosView, Projection);
	Out.NDCPosition = ndcPos;
	
	// Convert the position into a view vector to the far plane.
	float4 screenFarPlanePosition = float4(ndcPos.xy, 1, 1);
	float4 viewFarPlanePosition4 = mul(screenFarPlanePosition, ProjectionI);
	float3 viewFarPlanePosition = viewFarPlanePosition4.xyz / viewFarPlanePosition4.w;	
	
	// We don't really want a vector to the far plane. We want the vector with a z length of 1,
	// so that we know how much in x-y we need to step per z-depth that we get from the depth texture.
	Out.ZPositions.x = vertexPosView.z / OUTLINE_SCALE;
	Out.ZPositions.y = (viewFarPlanePosition.z / viewFarPlanePosition.z) / OUTLINE_SCALE;		
#endif // !defined(_3DSMAX_)	
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{

	//-------------------------------------------------------------------------
	// Shared between Additive and Multiplicitive -----------------------------
	//-------------------------------------------------------------------------
	float4 color = In.DiffuseColor; // Get vertex color value
	float fogStrength = In.EdgeFadeValue_Fog.y; // Get fog value
	float3 textureDisplace = tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.xy); // Get first texture pass of Displaced Coords
	textureDisplace += tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.zw); // Multiply against second pass
	textureDisplace = textureDisplace - 1; // Normalize as these are normal maps

	// Create displaced texture coords
	float4 displacedTextureCoords = In.DiffuseTexCoord + (textureDisplace.xyxy * DisplaceAmp); // Create final texture coords

	// Look up diffuse texture using displaced texture coords
	float4 textureDiffuse = tex2D( SAMPLER(Texture_0), displacedTextureCoords.xy);
	// If using multiple textures do...
	if (MultiTextureEnable)
	{
		textureDiffuse *= tex2D( SAMPLER(Texture_0), displacedTextureCoords.zw);
	}
	textureDiffuse.xyz = GammaToLinear(textureDiffuse.xyz); // Correct for gamma rendering
	
	// Create texture falloff value
	float textureFalloff = 0; // Float defined
	if	(TextureFadeOutEnable == true) // If using texture LUT for falloff do...
	{
		textureFalloff = tex2D( SAMPLER(TextureFadeOut), float2(In.EdgeFadeValue_Fog.x,1) );
	}
	else // Use pure vertex calculated falloff value
	{
		textureFalloff = In.EdgeFadeValue_Fog.x;
	}
	
#if !defined(_3DSMAX_)
	// Use Z depth information
	float3 ndcPosition = In.NDCPosition.xyz / In.NDCPosition.w;

	// Convert the position into texture space then grab the depth value from the
	// depth texture. Then, move along that vector by the depth to find the pixel position.
	float2 depthTexCoord = ndcPosition.xy * float2(0.5, -0.5) + 0.5;
	float backgroundDepth = tex2D(SAMPLER(DepthTexture), depthTexCoord).x;
	float backgroundPosView = backgroundDepth * In.ZPositions.y;

	// The closer the particle is to the background, the more transparent it is.
	float outlineBlend = saturate(In.ZPositions.x - backgroundPosView);
	
	float outlineDiffuse = tex2D( SAMPLER(TextureFadeOut), float2(1-outlineBlend.x,1) ) * color.xyz * IntersectionMultiplier;
#else
	float outlineDiffuse =1;
#endif // !defined(_3DSMAX_)
	
	
	//-------------------------------------------------------------------------
	// Additive ---------------------------------------------------------------
	//-------------------------------------------------------------------------
	if (MultiplyBlendEnable == false) // If additive do...
	{
		// Multiply diffuse colors by HDR multiplier if shader is additive
		color = float4(In.DiffuseColor.xyz * EmissiveHDRMultipler, In.DiffuseColor.w);
		
		// Overbrighten	
		color.xyz += color.xyz;

		// Output final color
		textureDiffuse = (color + outlineDiffuse) * textureDiffuse * textureFalloff * fogStrength;
	}
	
	//-------------------------------------------------------------------------
	// Multiplicitive ---------------------------------------------------------
	//-------------------------------------------------------------------------
	else // if Multiplicitive do...
	{
		// Output final color
		// Yes we need to take the inverted VertexColor to multiply against everything else
		// so that when we invert the whole equation we get the original color correctly
		// multiplied aginst the other values. This allows us to specifiy a single color
		// that works for both additive and multiplicitve. mjones
		
		textureDiffuse = 1 - (1 - (color - outlineDiffuse)) * textureDiffuse * textureFalloff * fogStrength * EmissiveHDRMultipler;
		textureDiffuse = max(textureDiffuse,0); // Clamp value to > 0 so as to avoid rendering artifacts when working with negative blend numbers
	}
	
	//-------------------------------------------------------------------------
	// Global shader wrap-up --------------------------------------------------
	//-------------------------------------------------------------------------
	color.xyz = textureDiffuse;
	
	return color;
}


// ----------------------------------------------------------------------------
// SHADER : MEDIUM
// ----------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position			: POSITION;
	float4 DiffuseColor		: TEXCOORD0;
	float4 DiffuseTexCoord	: TEXCOORD1;
	float4 DisplaceTexCoord	: TEXCOORD2;
	float2 EdgeFadeValue_Fog: TEXCOORD3;
};

// ----------------------------------------------------------------------------
VSOutput_M VS_M(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex)
{
	
	VSOutput_M Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
	#if defined(_3DSMAX_)
		// Default vertex color is 0 in Max, that's bad.
		VertexColor = 1.0;
		
		// A little bit better motion previewing in MAX
		Time *= .25;
	#endif

	//Calculate the displace texture coordinates
	DisplaceSpeed *= Time * .01; // animate Displace as a multiplier of Time with a happy MAX modifier

	float2 DisplaceTexCoords = TexCoord0 * DisplaceScalar;

	// Build Displace Texture Rotation Matrix And Convert Degrees to Radians -----
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	sincos (DisplaceDivergenceAngle * .017453, sinAngle, cosAngle);

	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate Displace Divergence Texture Coords --------------------
	float2 DisplaceTexCoordsDiverge = mul(DisplaceTexCoords, uvCoordRotate);
	DisplaceTexCoordsDiverge.x += DisplaceSpeed;
	float2 DisplaceTexCoordsDivergeInv = mul(DisplaceTexCoords, transpose(uvCoordRotate));	
	DisplaceTexCoordsDivergeInv.x += DisplaceSpeed;	

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	float viewingAngle = abs(dot(worldEyeDir,normalize(worldNormal)));

	float fadeOut = 0;
	Out.EdgeFadeValue_Fog.x = 0;
	if	(TextureFadeOutEnable == true)
	{
		Out.EdgeFadeValue_Fog.x = saturate(1 - viewingAngle); // Used in texcoords for per pixel calcultion
	}
	else
	{
		if (EdgeFadeOut >= 0)
		{
			fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle); // Soften Edges
		}
		else
		{
			fadeOut = smoothstep(abs(EdgeFadeOut), 0, viewingAngle); // Soften Center
		}
		Out.EdgeFadeValue_Fog.x = fadeOut;
	}
	
	// Compute Diffuse Color and Final Vertex Color
	float3 diffuseColorKeyCurrent =	0;
		
	if (OpacityOverrideEnable == true) // Lerp between the 2 key colors using OpacityOverride to drive it
	{	
		//	float3 diffuseColorKeyCurrent = lerp(ColorDiffuseKey1, ColorDiffuseKey2, OpacityOverride); // <----- Gavin use me for the final

		// Use this temporarily till enginering has the hooks
		diffuseColorKeyCurrent = ColorDiffuseKey1; // <----- Gavin delete me in the final
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1);
	}
	else // Use it for its intended purpose
	{
		diffuseColorKeyCurrent = ColorDiffuseKey1;
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1) * OpacityOverride;
	}
	
	// Compute all registers
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	TexCoord0.xy *= DiffuseCoordOffset.zw;
	
	// Restrict the numerical range to 0-1 to hide precision issues in the texture sampling when Time goes really large
	float2 offset = frac(DiffuseCoordOffset.xy * Time);
	
	Out.DiffuseTexCoord.xyzw = TexCoord0.xyxy + offset.xyxy;
	if (MultiTextureEnable == true )
	{	
		Out.DiffuseTexCoord.zw = TexCoord0.xy * DiffuseCoordOffset.zw - offset;
	}
	Out.DisplaceTexCoord = float4(DisplaceTexCoordsDiverge, DisplaceTexCoordsDivergeInv);
	Out.EdgeFadeValue_Fog.y = CalculateFog(Fog, worldPosition, GetEyePosition());

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_M(VSOutput_M In) : COLOR
{

	//-------------------------------------------------------------------------
	// Shared between Additive and Multiplicitive -----------------------------
	//-------------------------------------------------------------------------
	float4 color = In.DiffuseColor; // Get vertex color value
	float fogStrength = In.EdgeFadeValue_Fog.y; // Get fog value
	float3 textureDisplace = tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.xy); // Get first texture pass of Displaced Coords
	textureDisplace += tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.zw); // Multiply against second pass
	textureDisplace = textureDisplace - 1; // Normalize as these are normal maps

	// Create displaced texture coords
	float4 displacedTextureCoords = In.DiffuseTexCoord + (textureDisplace.xyxy * DisplaceAmp); // Create final texture coords

	// Look up diffuse texture using displaced texture coords
	float4 textureDiffuse = tex2D( SAMPLER(Texture_0), displacedTextureCoords.xy);
	// If using multiple textures do...
	if (MultiTextureEnable)
	{
		textureDiffuse *= tex2D( SAMPLER(Texture_0), displacedTextureCoords.zw);
	}
	
	// Create texture falloff value
	float textureFalloff = 0; // Float defined
	if	(TextureFadeOutEnable == true) // If using texture LUT for falloff do...
	{
		textureFalloff = tex2D( SAMPLER(TextureFadeOut), float2(In.EdgeFadeValue_Fog.x,1) );
	}
	else // Use pure vertex calculated falloff value
	{
		textureFalloff = In.EdgeFadeValue_Fog.x;
	}
	
	//-------------------------------------------------------------------------
	// Additive ---------------------------------------------------------------
	//-------------------------------------------------------------------------
	if (MultiplyBlendEnable == false) // If additive do...
	{
		// Multiply diffuse colors by HDR multiplier if shader is additive
		color = float4(In.DiffuseColor.xyz * EmissiveHDRMultipler, In.DiffuseColor.w);
		
		// Overbrighten	
		color.xyz += color.xyz;

		// Output final color
		textureDiffuse = color * textureDiffuse * textureFalloff * fogStrength;
	}
	
	//-------------------------------------------------------------------------
	// Multiplicitive ---------------------------------------------------------
	//-------------------------------------------------------------------------
	else // if Multiplicitive do...
	{
		// Output final color
		// Yes we need to take the inverted VertexColor to multiply against everything else
		// so that when we invert the whole equation we get the original color correctly
		// multiplied aginst the other values. This allows us to specifiy a single color
		// that works for both additive and multiplicitve. mjones
		
		textureDiffuse = 1 - (1 - color) * textureDiffuse * textureFalloff * fogStrength * EmissiveHDRMultipler;
		textureDiffuse = max(textureDiffuse,0); // Clamp value to > 0 so as to avoid rendering artifacts when working with negative blend numbers
	}
	
	//-------------------------------------------------------------------------
	// Global shader wrap-up --------------------------------------------------
	//-------------------------------------------------------------------------
	color.xyz = textureDiffuse;
	
	return color;
}

// ----------------------------------------------------------------------------
// SHADER : LOW
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position			: POSITION;
	float4 DiffuseColor		: TEXCOORD0;
	float4 DiffuseTexCoord	: TEXCOORD1;
	float2 EdgeFadeValue_Fog: TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_L VS_L(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex)
{
	
	VSOutput_L Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
	#if defined(_3DSMAX_)
		VertexColor = 1.0; // Default vertex color is 0 in Max, that's bad.
		Time *= .25; // A little bit better motion previewing in MAX
	#endif

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	float viewingAngle = abs(dot(worldEyeDir,normalize(worldNormal)));

	float fadeOut = 0;
	Out.EdgeFadeValue_Fog.x = 0;
	if	(TextureFadeOutEnable == true)
	{
		Out.EdgeFadeValue_Fog.x = saturate(1 - viewingAngle); // Used in texcoords for per pixel calcultion
	}
	else
	{
		if (EdgeFadeOut >= 0)
		{
			fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle); // Soften Edges
		}
		else
		{
			fadeOut = smoothstep(abs(EdgeFadeOut), 0, viewingAngle); // Soften Center
		}
		Out.EdgeFadeValue_Fog.x = fadeOut;
	}
	
	// Compute Diffuse Color and Final Vertex Color
	float3 diffuseColorKeyCurrent =	0;
		
	if (OpacityOverrideEnable == true) // Lerp between the 2 key colors using OpacityOverride to drive it
	{	
		//	float3 diffuseColorKeyCurrent = lerp(ColorDiffuseKey1, ColorDiffuseKey2, OpacityOverride); // <----- Gavin use me for the final

		// Use this temporarily till enginering has the hooks
		diffuseColorKeyCurrent = ColorDiffuseKey1; // <----- Gavin delete me in the final
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1);
	}
	else // Use it for its intended purpose
	{
		diffuseColorKeyCurrent = ColorDiffuseKey1;
		Out.DiffuseColor = VertexColor * float4(diffuseColorKeyCurrent,1) * OpacityOverride;
	}
	
	// Compute all registers
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	TexCoord0.xy *= DiffuseCoordOffset.zw;
	
	// Restrict the numerical range to 0-1 to hide precision issues in the texture sampling when Time goes really large
	float2 offset = frac(DiffuseCoordOffset.xy * Time);
	
	Out.DiffuseTexCoord.xyzw = TexCoord0.xyxy + offset.xyxy;
	if (MultiTextureEnable == true )
	{	
		Out.DiffuseTexCoord.zw = TexCoord0.xy * DiffuseCoordOffset.zw - offset;
	}
	Out.EdgeFadeValue_Fog.y = CalculateFog(Fog, worldPosition, GetEyePosition());

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_L(VSOutput_L In) : COLOR
{

	//-------------------------------------------------------------------------
	// Shared between Additive and Multiplicitive -----------------------------
	//-------------------------------------------------------------------------
	float4 color = In.DiffuseColor; // Get vertex color value
	float fogStrength = In.EdgeFadeValue_Fog.y; // Get fog value

	// Look up diffuse texture using displaced texture coords
	float4 textureDiffuse = tex2D( SAMPLER(Texture_0), In.DiffuseTexCoord.xy);
	if (MultiTextureEnable) // If using multiple textures do...
	{
		textureDiffuse *= tex2D( SAMPLER(Texture_0), In.DiffuseTexCoord.zw);
	}
	
	// Create texture falloff value
	float textureFalloff = 0; // Float defined
	if	(TextureFadeOutEnable == true) // If using texture LUT for falloff do...
	{
		textureFalloff = tex2D( SAMPLER(TextureFadeOut), float2(In.EdgeFadeValue_Fog.x,1) );
	}
	else // Use pure vertex calculated falloff value
	{
		textureFalloff = In.EdgeFadeValue_Fog.x;
	}
	
	//-------------------------------------------------------------------------
	// Additive ---------------------------------------------------------------
	//-------------------------------------------------------------------------
	if (MultiplyBlendEnable == false) // If additive do...
	{
		// Multiply diffuse colors by HDR multiplier if shader is additive
		color = float4(In.DiffuseColor.xyz * EmissiveHDRMultipler, In.DiffuseColor.w);
		
		// Overbrighten	
		color.xyz += color.xyz;

		// Output final color
		textureDiffuse = color * textureDiffuse * textureFalloff * fogStrength;
	}
	
	//-------------------------------------------------------------------------
	// Multiplicitive ---------------------------------------------------------
	//-------------------------------------------------------------------------
	else // if Multiplicitive do...
	{
		// Output final color
		// Yes we need to take the inverted VertexColor to multiply against everything else
		// so that when we invert the whole equation we get the original color correctly
		// multiplied aginst the other values. This allows us to specifiy a single color
		// that works for both additive and multiplicitve. mjones
		
		textureDiffuse = 1 - (1 - color) * textureDiffuse * textureFalloff * fogStrength * EmissiveHDRMultipler;
		textureDiffuse = max(textureDiffuse,0); // Clamp value to > 0 so as to avoid rendering artifacts when working with negative blend numbers
	}
	
	//-------------------------------------------------------------------------
	// Global shader wrap-up --------------------------------------------------
	//-------------------------------------------------------------------------
	color.xyz = textureDiffuse;
	
	return color;
}

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS(0);
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;

#if defined(EA_PLATFORM_WINDOWS)
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		// If MultiplyBlendEnable then blend mode = MULTIPLY else ADDITIVE
		SrcBlend = ( MultiplyBlendEnable == true ? D3DBLEND_DESTCOLOR : D3DBLEND_ONE );
		DestBlend = ( MultiplyBlendEnable == true ? D3DBLEND_ZERO : D3DBLEND_ONE );		
#else
		// TODO: Needs to support additive or multiplicative switch, hardcoding additive for now
		SrcBlend = One;
		DestBlend = One;
		CullMode = None;
#endif

	}  
}

// ----------------------------------------------------------------------------
// Technique: Medium
// ----------------------------------------------------------------------------
technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_M(0);
		PixelShader = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;

#if defined(EA_PLATFORM_WINDOWS)
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		// If MultiplyBlendEnable then blend mode = MULTIPLY else ADDITIVE
		SrcBlend = ( MultiplyBlendEnable == true ? D3DBLEND_DESTCOLOR : D3DBLEND_ONE );
		DestBlend = ( MultiplyBlendEnable == true ? D3DBLEND_ZERO : D3DBLEND_ONE );		
#else
		// TODO: Needs to support additive or multiplicative switch, hardcoding additive for now
		SrcBlend = One;
		DestBlend = One;
		CullMode = None;
#endif

	}  
}

// ----------------------------------------------------------------------------
// Technique: LOW
// ----------------------------------------------------------------------------
technique Default_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_L(0);
		PixelShader = compile PS_2_0 PS_L();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;

#if defined(EA_PLATFORM_WINDOWS)
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		
		// If MultiplyBlendEnable then blend mode = MULTIPLY else ADDITIVE
		SrcBlend = ( MultiplyBlendEnable == true ? D3DBLEND_DESTCOLOR : D3DBLEND_ONE );
		DestBlend = ( MultiplyBlendEnable == true ? D3DBLEND_ZERO : D3DBLEND_ONE );		
#else
		// TODO: Needs to support additive or multiplicative switch, hardcoding additive for now
		SrcBlend = One;
		DestBlend = One;
		CullMode = None;
#endif

	}  
}

