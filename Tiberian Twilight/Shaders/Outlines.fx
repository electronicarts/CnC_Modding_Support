//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for object outlines (selection and hovering)
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "CommonPostFX.fxh"

// we use the first three bits in the stencil buffer for this effect 
// THESE MUST BE KEPT IN SYNC WITH CODE!
#define STENCIL_BITS_SELECTED			0x1
#define STENCIL_BITS_HOVER_SELECT		0x2
#define STENCIL_BITS_HOVER_ATTACK		0x3
#define STENCIL_BITS_ALL_SELECT_MODES	0x3

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------

// ngavalas
// This controls the distance to sample from the center pixel being blurred.
// It needs to be on a border of 4 pixels so we can get more sampling for free.
// 0.5 and 1.5 work well. Please do not change this without consulting me.
static const float  TEXEL_DISTANCE_FROM_CENTER = 1.5f;

static const float4 OutlineSelectedColor = float4(0.0f, 1.0f, 0.0f, 1.0f);
static const float4 OutlineHoverAttackColor = float4(1.0f, 0.0f, 0.0f, 1.0f);
static const float4 OutlineHoverSelectColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
static const float  OutlineIntensity = 2.0f;
static const float  OUTLINE_ALPHA_CUTOFF = 0.35f;
static const float  OUTLINE_ALPHA_MULTIPLIER = 6.0f;

// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( PostEffectOutlineTexture,
				 string SasBindAddress = "WW3D.Outline.Texture";
)
MinFilter = Linear;
MagFilter = Linear;
MipFilter = Point;
AddressU = Clamp;
AddressV = Clamp;
SAMPLER_2D_END

float2 FrameBufferSize
<
string UIWidget = "None";
string SasBindAddress = "WW3D.FrameBufferSize";
> = float2(1.0f, 1.0f);

/*
// $todo (wkan) 2009/10/14 - remove the code side of setting this up once they are happy with the fixed color

float4 OutlineSelectedColor
<
string UIWidget = "None";
string SasBindAddress = "WW3D.Outline.SelectedColor";
> = float4(1.0f, 1.0f, 1.0f, 1.0f);

float4 OutlineHoverAttackColor
<
string UIWidget = "None";
string SasBindAddress = "WW3D.Outline.AttackColor";
> = float4(1.0f, 1.0f, 1.0f, 1.0f);
*/

// ----------------------------------------------------------------------------
// SHADERS
// ----------------------------------------------------------------------------
float4 VS(float3 Position : POSITION) : POSITION
{
	return float4(Position, 1);
}

// ----------------------------------------------------------------------------

float4 PS_Selected(void) : COLOR
{
	return OutlineSelectedColor;
}

// ----------------------------------------------------------------------------

float4 PS_HoverSelect(void) : COLOR
{
	return OutlineHoverSelectColor;
}

// ----------------------------------------------------------------------------

float4 PS_HoverAttack(void) : COLOR
{
	return OutlineHoverAttackColor;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: FillSelected
// ----------------------------------------------------------------------------
technique FillSelected
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS_Selected();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		StencilEnable = true;
		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
		StencilMask = STENCIL_BITS_SELECTED;
		StencilRef = STENCIL_BITS_SELECTED;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: FillHoverSelect
// ----------------------------------------------------------------------------
technique FillHoverSelect
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS_HoverSelect();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		StencilEnable = true;
		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
		StencilMask = STENCIL_BITS_HOVER_SELECT;
		StencilRef = STENCIL_BITS_HOVER_SELECT;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: FillHoverAttack
// ----------------------------------------------------------------------------
technique FillHoverAttack
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS_HoverAttack();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		StencilEnable = true;
		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
		StencilMask = STENCIL_BITS_HOVER_ATTACK;
		StencilRef = STENCIL_BITS_HOVER_ATTACK;
	}  
}

struct VS_OUTPUT_BLUR_BOX
{
	float4	Position   				: POSITION;
	float4	NegX_PosX_NegY_PosY		: TEXCOORD1;
};

// ----------------------------------------------------------------------------

VS_OUTPUT_BLUR_BOX VS_Blur_Box(float3 Position : POSITION, float3 TexCoord : TEXCOORD0)
{
	VS_OUTPUT_BLUR_BOX OUT = (VS_OUTPUT_BLUR_BOX)0;
	OUT.Position = float4(Position, 1);
	
	// Based on the outline size we know how far we should sample by.
	float2 TexelIncrement;
	TexelIncrement.x = 1.0/FrameBufferSize.x;
	TexelIncrement.y = 1.0/FrameBufferSize.y;

	// Store all the possible amounts to move from the source pixel so we don't
	// have to do this in the pixel shader.
	OUT.NegX_PosX_NegY_PosY.x = TexCoord.x + TexelIncrement.x * -TEXEL_DISTANCE_FROM_CENTER;
	OUT.NegX_PosX_NegY_PosY.y = TexCoord.x + TexelIncrement.x *  TEXEL_DISTANCE_FROM_CENTER;
	OUT.NegX_PosX_NegY_PosY.z = TexCoord.y + TexelIncrement.y * -TEXEL_DISTANCE_FROM_CENTER;
	OUT.NegX_PosX_NegY_PosY.w = TexCoord.y + TexelIncrement.y *  TEXEL_DISTANCE_FROM_CENTER;

	return OUT;
}

float4 PS_Blur_Box(VS_OUTPUT_BLUR_BOX IN) : COLOR
{
	float4 color = tex2D(SAMPLER(PostEffectOutlineTexture), IN.NegX_PosX_NegY_PosY.xz);
	color += tex2D(SAMPLER(PostEffectOutlineTexture), IN.NegX_PosX_NegY_PosY.xw);
	color += tex2D(SAMPLER(PostEffectOutlineTexture), IN.NegX_PosX_NegY_PosY.yz);
	color += tex2D(SAMPLER(PostEffectOutlineTexture), IN.NegX_PosX_NegY_PosY.yw);

	return saturate(color*float4(OutlineIntensity*0.25,OutlineIntensity*0.25,OutlineIntensity*0.25,0.25));
}

// ----------------------------------------------------------------------------
// TECHNIQUE: BlurBox   
// ----------------------------------------------------------------------------
technique BlurBox
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Blur_Box();
		PixelShader = compile PS_2_0 PS_Blur_Box();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		StencilEnable = false;

		AlphaBlendEnable = false;

		AlphaTestEnable = false;
	}  
}


// ----------------------------------------------------------------------------

struct VS_DrawWithStencilOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------

VS_DrawWithStencilOutput VS_DrawWithStencil(float3 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	VS_DrawWithStencilOutput Out;
	Out.Position = float4(Position, 1);
	Out.TexCoord = TexCoord;
	return Out;
}

// ----------------------------------------------------------------------------

float4 PS_DrawWithStencil(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(PostEffectOutlineTexture), TexCoord );

	// Clip out the alpha greater than the cutoff value, in order create the gap between the outline and the object
	clip(OUTLINE_ALPHA_CUTOFF - color.a);

	// Bump up the alpha value so the outline appear more solid, an alpha of 0-0.4 isn't going to shows too well
	color.a = saturate(OUTLINE_ALPHA_MULTIPLIER*color.a);

	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: DrawWithStencil
// ----------------------------------------------------------------------------
technique DrawWithStencil
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_DrawWithStencil();
		PixelShader = compile PS_2_0 PS_DrawWithStencil();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		StencilEnable = true;
		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
		StencilMask = STENCIL_BITS_ALL_SELECT_MODES;
		StencilRef = 0;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}


// ----------------------------------------------------------------------------

float4 PS_Blit(float2 TexCoord : TEXCOORD0) : COLOR
{
	float4 color = tex2D( SAMPLER(PostEffectOutlineTexture), TexCoord );
	color.xyz = UncompressRenderTargetColor(color.xyz);
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Blit
// ----------------------------------------------------------------------------
technique Blit
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_DrawWithStencil();
		PixelShader = compile PS_2_0 PS_Blit();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		StencilEnable = false;
		AlphaTestEnable = false;

		AlphaBlendEnable = false;
	}  
}