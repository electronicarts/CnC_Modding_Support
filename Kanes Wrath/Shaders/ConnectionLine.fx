//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

//----------------------------------------------------------------------------
// Transforms
//----------------------------------------------------------------------------

float4x4 View        : View;
float4x3 ViewInverse : ViewInverse;
float4x4 Projection  : Projection;

float Time : Time;

//----------------------------------------------------------------------------
// Connection Parameters
//----------------------------------------------------------------------------

float4 HouseColor
<
	string UIWidget = "None";
	string SasBindAddress = "ConnectionLine.HouseColor";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = float4( 1, 1, 1, 1 );

float LineLength
<
	string UIWidget = "None";
	string SasBindAddress = "ConnectionLine.LineLength";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = 2.5;

static float LineWidth
<
	string UIName = "Line Width";
    string UIWidget = "Slider";
    float UIMin = 0;
    float UIMax = 100;
> = 2.5;

static float UVWorldSize
<
	string UIName = "UV World Size";
    string UIWidget = "Slider";
    float UIMin = 0;
    float UIMax = 100;
> = 15.0;

static const float TextureScrollSpeed
<
	string UIName = "Texture Scroll Speed";
    string UIWidget = "Slider";
    float UIMin = 0;
    float UIMax = 100;
> = 4;

//----------------------------------------------------------------------------
// LineTexture
//----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( LineTexture,
    string UIWidget = "None";
	)
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU  = Wrap;
    AddressV  = Wrap;
SAMPLER_2D_END

//----------------------------------------------------------------------------
// Shroud
//----------------------------------------------------------------------------

ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudTexture,
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

//-----------------------------------------------------------------------------
// Vertex Shader structure
//-----------------------------------------------------------------------------

struct VSInput
{
    float3 Position           : POSITION;
    float3 Normal             : NORMAL;
    float3 Binormal           : BINORMAL;
    float3 Tangent            : TANGENT;
    float2 NormalizedTexCoord : TEXCOORD0;
};

struct VSOutput
{
    float4 Position         : POSITION;
    float2 DiffuseTexCoord  : TEXCOORD0;
    float2 DiffuseTexCoord1 : TEXCOORD1;
    float2 ShroudTexCoord   : TEXCOORD2;
};

//-----------------------------------------------------------------------------
// Billboard Edge
//-----------------------------------------------------------------------------

#if 1
    float3 BillboardEdge( float3 world_pos_center, float normalized_offset, float3 world_tangent )
    {
		LineWidth = 10;
        float3 view_out = float3( View[0][2], View[1][2], View[2][2] );
    
        float3 world_offset = cross( world_tangent, view_out );
        world_offset *= ( normalized_offset - 0.5 ) * LineWidth;
        
        return world_pos_center + world_offset;
    }
#else
    float3 BillboardEdge( float3 world_pos_center, float normalized_offset, float3 world_tangent )
    {
        float3 view_up  = float3( View[0][1], View[1][1], View[2][1] );
        float3 view_out = float3( View[0][2], View[1][2], View[2][2] );
    
        float3 world_offset_up    = cross( world_tangent, view_out );
        float3 world_offset_right = cross( world_tangent, view_up  );

        // Blend between "up" and "right" from tangent in view space
        // based on the angle between the camera and the edge's tangent
        float parrallelism = abs( dot( world_tangent, view_out ) );

        float3 world_offset = normalize( lerp( world_offset_up, world_offset_right, parrallelism ) );
        world_offset *= ( normalized_offset - 0.5 ) * LineWidth;

        return world_pos_center + world_offset;
    }
#endif

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
	UVWorldSize =150;
    VSOutput Output;

    // Get the final vertex position
    float3 world_pos = BillboardEdge( Input.Position, Input.NormalizedTexCoord.x, Input.Tangent );

	float4x4 ViewProjection = mul( View, Projection );
    Output.Position = mul( float4( world_pos, 1 ), ViewProjection );

    // Calculate UVs
    Output.DiffuseTexCoord    = Input.NormalizedTexCoord;
    Output.DiffuseTexCoord.y *= LineLength / UVWorldSize;
    Output.DiffuseTexCoord.y -= Time * TextureScrollSpeed;
    
     // Calculate UVs
    Output.DiffuseTexCoord1    = Input.NormalizedTexCoord;
    Output.DiffuseTexCoord1.y *= LineLength / UVWorldSize;
    Output.DiffuseTexCoord1.y -= (Time * 0.2) * TextureScrollSpeed;

    // Calculate Shroud UVs
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, world_pos );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input ) : Color
{
    float4 color = tex2D( SAMPLER(LineTexture), Input.DiffuseTexCoord );
    color += tex2D( SAMPLER(LineTexture), Input.DiffuseTexCoord1);
    color *= HouseColor;

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	color.xyz *= shroud;

    return color;
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

technique Default
{
    pass pass0
    {
        VertexShader = compile VS_VERSION_LOW VS();
        PixelShader  = compile PS_VERSION_LOW PS();

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;

        CullMode         = None;
        SrcBlend         = ONE;
        DestBlend        = ONE;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}