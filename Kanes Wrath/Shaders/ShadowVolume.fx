//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader helper for shadow map
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------
float4 ShadowColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
> = float4(0, 0, 0, 0);

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 View : View;
float4x4 Projection : Projection;

// ----------------------------------------------------------------------------
// SHADER: RenderVolume
// ----------------------------------------------------------------------------

float4 VSRenderVolume(float3 Position : POSITION) : POSITION
{
	return mul(float4(Position, 1), mul(View, Projection));
}

// ----------------------------------------------------------------------------
float4 PSRenderVolume(void) : COLOR
{
	return float4(0, 0, 0, 0);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _RenderVolume_ZPass_DoubleSided
// ----------------------------------------------------------------------------
technique _RenderVolume_ZPass_DoubleSided
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = None;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		TwoSidedStencilMode = true;

		StencilFunc = Always;
		StencilPass = Decr;
		StencilFail = Keep;
		StencilZFail = Keep;

		CCW_StencilFunc = Always;
		CCW_StencilPass = Incr;
		CCW_StencilFail = Keep;
		CCW_StencilZFail = Keep;
	}
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _RenderVolume_ZFail_DoubleSided
// ----------------------------------------------------------------------------
technique _RenderVolume_ZFail_DoubleSided
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = None;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		TwoSidedStencilMode = true;

		StencilFunc = Always;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Incr;

		CCW_StencilFunc = Always;
		CCW_StencilPass = Keep;
		CCW_StencilFail = Keep;
		CCW_StencilZFail = Decr;
	}
}



// ----------------------------------------------------------------------------
// TECHNIQUE: _RenderVolume_ZPass_SingleSided
// ----------------------------------------------------------------------------
technique _RenderVolume_ZPass_SingleSided
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = CW;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		StencilFunc = Always;
		StencilPass = Incr;
		StencilFail = Keep;
		StencilZFail = Keep;
	}
	pass P1
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = CCW;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		StencilFunc = Always;
		StencilPass = Decr;
		StencilFail = Keep;
		StencilZFail = Keep;
	}

	/*pass DebugWireframe
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = RED|GREEN|BLUE|ALPHA;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = None;
		
		FillMode = Wireframe;
	}*/
	
}



// ----------------------------------------------------------------------------
// TECHNIQUE: _RenderVolume_ZFail_SingleSided
// ----------------------------------------------------------------------------
technique _RenderVolume_ZFail_SingleSided
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = CW;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		StencilFunc = Always;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Incr;
	}
	pass P1
	{
		VertexShader = compile VS_VERSION_LOW VSRenderVolume();
		PixelShader = compile PS_VERSION_LOW PSRenderVolume();

		ColorWriteEnable = 0;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
		ClipPlaneEnable = 0;
		
		ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		CullMode = CCW;
		
		StencilEnable = true;
		StencilMask = 0xFFFFFFFF;
		StencilWriteMask = 0; // To be overridden by code

		StencilFunc = Always;
		StencilPass = Keep;
		StencilFail = Keep;
		StencilZFail = Decr;
	}
}



// ----------------------------------------------------------------------------
// SHADER: StencilToScreen
// ----------------------------------------------------------------------------
float4 VSStencilToScreen(float3 Position : POSITION) : POSITION
{
	return float4(Position, 1);
}

// ----------------------------------------------------------------------------
float4 PSStencilToScreen(void) : COLOR
{
	return ShadowColor;
}


// ----------------------------------------------------------------------------
// TECHNIQUE: _StencilToScreen
// ----------------------------------------------------------------------------
technique _StencilToScreen
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VSStencilToScreen();
		PixelShader = compile PS_VERSION_LOW PSStencilToScreen();

		ColorWriteEnable = RGBA;
		
		ClipPlaneEnable = 0;
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		StencilEnable = true;
		StencilFunc = LessEqual;
		StencilPass = Keep;
		StencilMask = 0; // To be overridden by code
		StencilRef = 1;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = false;
	}  
}
