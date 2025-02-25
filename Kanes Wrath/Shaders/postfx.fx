/******************************************************************************
*
* PostFX.fx
*
*	
*	
*	
*
* Copyright (c)2005 ELectronic Arts, Inc.
*
******************************************************************************/


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	CONFIG

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

#define DO_SAMPLE_MASKING	0

#define RGBA				15


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	PARAMETERS

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

// Common
float4 screen_info // screen res info (1/W, 1/H, W/(1280^2), H/(720^2))
<
	string UIName = "screen_info";
> = float4( 1.0f/1280.0f, 1.0f/720.0f, 1.0f/1280.0f, 1.0f/720.0f );					

#define NClip 30.0f
#define FClip 3800.0f

float4 camera_info	// camera info ( -f*n/(f-n), f/(f-n), n, 1/(f-n) )
<
	string UIName = "camera_info";
> = float4( -FClip*NClip/(FClip-NClip), FClip/(FClip-NClip), NClip, 1.0f/(FClip-NClip) );
															
// Anti-aliasing
float  e_kernel = 1.25f;		// anti-alias kernel size
float  e_barrier = 50.0f; 		// world space edge detection barrier

// Contains sampling offsets used by the techniques
static const int MAX_SAMPLES = 16;    // Maximum texture grabs
float2 avSampleOffsets[MAX_SAMPLES];
float4 avSampleWeights[MAX_SAMPLES];
float bright_pass_threshold = 1.0/8.0;
float bright_weight = 1.0;
float bloom_weight = 0.3;

// Depth of field
const float focal_distance = 0.0f;				// distance to object in focus
const float inv_focal_range = 1.0f/2000.0f;		// radius of 1/focal range.
const float maxCoC = 4.0f;


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	TEXTURES AND SAMPLERS

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

sampler blit_sampler  : register(s0);
sampler depth_sampler : register(s1);

texture framebuffer     : FrameTex;
sampler frame_buffer_sampler = sampler_state
{
	texture = <framebuffer>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MIPFILTER = NONE;//LINEAR;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

texture depthmap		: DepthTex;
sampler depthmap_pointsampler = sampler_state
{
	texture = <depthmap>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MIPFILTER = NONE;//LINEAR;
	MINFILTER = POINT;
	MAGFILTER = POINT;
};

texture focusramp		: FocusRamp;
sampler focus_ramp_sampler = sampler_state
{
	texture = <focusramp>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

texture glowmap;
sampler glow_sampler = sampler_state
{
	texture = <glowmap>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	VERTEX + PIXEL STRUCTURES

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

struct VS_INPUT
{
	float4 position	: POSITION;
	float4 color	: COLOR;
	float4 tex0		: TEXCOORD0;
};

struct PS_OUTPUT
{
	float4 color	: COLOR;
	float  depth	: DEPTH;
};

struct VtoP
{
	float4 position	: POSITION;
	float4 tex0		: TEXCOORD0;
};


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	COMMON

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
ComputeBlurFactor
	Simple, and it works. Linear fall off towards bluriness in both directions. 
	Sharpness (slope) of falloff is controlled by inv_focal_range (2.0f / focal_range)	
	
	input: worlddepth // distance in world coordinate [near->far]
	output: blurriness 0.0->1.0f
-----------------------------------------------------------------------------*/
float ComputeBlurFactor(float worlddepth)
{
//	float blur = saturate(abs(worlddepth - focal_distance) * inv_focal_range);	

	float absVal = abs(worlddepth - focal_distance);
	float invVal = absVal * inv_focal_range;
	float blur   = saturate(invVal);

	return (1-tex1D( focus_ramp_sampler, blur ).x);			
}

/*-----------------------------------------------------------------------------
SampleZDepth

	Sample Z buffer. Current format is A8R8G8B8 (Z24 S8). Only ARG contains Z 
	information. We will switch to a 16bit format on beta hardware. For now 
	recalucalate Z using A and R. using the upper 16bits of the 24bit Zbuffer 
	should not impact quality significantly.		
-----------------------------------------------------------------------------*/
float PointSampleZDepth(const float2 tex_coord)
{
//	float4 depth_blur_sample = tex2D(depthmap_pointsampler, tex_coord);	
//	return (depth_blur_sample.a * 16711680.0f + depth_blur_sample.r * 65280.0f) / 16777216.0f;		
#if !HIZ_CULLING
	return tex2D(depthmap_pointsampler, tex_coord).r;
#else
	float zdepth = tex2D(depthmap_pointsampler, tex_coord).r;

	return 1.0f - zdepth;
#endif
}

/*-----------------------------------------------------------------------------
ConvertZToWorldDist
	To acuratly control Z blur fall off we should really be working in normalized world space (i.e. a wbuffer).
	Convert z value to world distance		
	W = (-(F*N)/(F-N))/(Z- (F/(F-N))

	camera_info.x = - f*n/(f-n);
	camera_info.y = f/(f-n);
	camera_info.z = n;
	camera_info.w = 1.0f/(f-n);

	input: 0.0->1.0 
	output: near->far 
-----------------------------------------------------------------------------*/
float ConvertZToWorldDist(float zdepth) 
{
	return  camera_info.x / (zdepth - camera_info.y);	
}

// As above, but does 4 distance conversions at once
float4 ConvertZToWorldDist4(float4 zdepths)
{
	return  camera_info.x / (zdepths - camera_info.y);	
}

/*-----------------------------------------------------------------------------
ConvertZToWDepth
	To acuratly control Z blur fall off we should really be working in normalized world space (i.e. a wbuffer).
	Convert z value to world distance		
	W = (-(F*N)/(F-N))/(Z- (F/(F-N))
	W = (W-N)/(F-N)
	
	camera_info.x = - f*n/(f-n);
	camera_info.y = f/(f-n);
	camera_info.z = n;
	camera_info.w = 1.0f/(f-n);
	
	input: 0.0->1.0 
	output: near->far 
-----------------------------------------------------------------------------*/
float ConvertZToWDepth(float zdepth) 
{
	float d = camera_info.x  / (zdepth - camera_info.y);
	return  (d - camera_info.z) * camera_info.w ;	
}

// As above, but does 4 distance conversions at once
float4 ConvertZToWDepth4(float4 zdepths) 
{
	float4 d = camera_info.x  / (zdepths - camera_info.y);
	return  (d - camera_info.z) * camera_info.w ;	
}


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	DEPTH OF FIELD

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
Poisson Distribution Tap Filter
-----------------------------------------------------------------------------*/
#if 0
#define NUM_TAPS 12
static const float2 g_Poisson[NUM_TAPS] = 
{
	float2(  0.000000f,  0.000000f ),
	float2( -0.326212f, -0.405810f ),
	float2( -0.695914f,  0.457137f ),
	float2( -0.203345f,  0.620716f ),
	float2(  0.962340f, -0.194983f ),
	float2(  0.473434f, -0.480026f ),
	float2(  0.519456f,  0.767022f ),
	float2(  0.185461f, -0.893124f ),
	float2(  0.507431f,  0.064425f ),
	float2(  0.896420f,  0.412458f ),
	float2( -0.321940f, -0.932615f ),
	float2( -0.791559f, -0.597710f ),
};
#else
static const int NUM_TAPS = 8;
static const float2 g_Poisson[NUM_TAPS] = 
{
    float2( 0.000000f, 0.000000f ),
    float2( 0.527837f,-0.085868f ),
    float2(-0.040088f, 0.536087f ),
    float2(-0.670445f,-0.179949f ),
    float2(-0.419418f,-0.616039f ),
    float2( 0.440453f,-0.639399f ),
    float2(-0.757088f, 0.349334f ),
    float2( 0.574619f, 0.685879f ),
};
#endif

static const float g_BlurThreshold = 0.05f;



float4 BlurSample(const float2 tex_coord, const float blurAmount, float2 blur_offset)
{	
	float  tap_contribution = 1.0f / NUM_TAPS;
	// Grab the first sample, at the center of the disc
	float4 color = tex2D(frame_buffer_sampler, tex_coord);

	// If the blur amount is greater than a threshold, then apply the full 12 tap filter.
	if( blurAmount >= g_BlurThreshold )
	{
		// set up color for accumulation
		color *= tap_contribution;
		// scale the blur offset by the blur amount
		blur_offset *= blurAmount;
	    // Accumulate the rest
	    for (int i=1; i<NUM_TAPS; i++)
	    {
		    float4 tap_color = tex2D(frame_buffer_sampler, tex_coord + g_Poisson[i] * blur_offset);
		    color += tap_color * tap_contribution;
	    }
		
//		color /= 4;	//float4( 1.0, 1.0, 1.0, 1.0 );
	}

	// Done!
	return color;	
}


float4 DOF_main(const float2 texCoord)
{
	//sample Z buffer
	float zdepth = PointSampleZDepth(texCoord);
	//convert to World Distance
	float worlddepth = ConvertZToWorldDist(zdepth);
	//compute blur factor (0->1.0)
	float blur = ComputeBlurFactor(worlddepth);	
	//generate blur sample
	float4 colour = BlurSample(texCoord, blur, maxCoC*screen_info.zw);
	// Return the colour and the amount we blurred
	return float4(colour.xyz, blur);
}


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	ANTI-ALIASING

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

//
#define du screen_info.x
#define dv screen_info.y

//
float2 edge_detect(const float2 texCoord)
{
	// Sample Z-buffer
	float4 zsamples_a;
	float4 zsamples_b;
	zsamples_a.x = PointSampleZDepth(texCoord + float2(-du,-dv));
	zsamples_a.y = PointSampleZDepth(texCoord + float2(  0,-dv));
	zsamples_a.z = PointSampleZDepth(texCoord + float2(+du,-dv));
	zsamples_a.w = PointSampleZDepth(texCoord + float2(-du,  0));
	zsamples_b.x = PointSampleZDepth(texCoord + float2(+du,  0));
	zsamples_b.y = PointSampleZDepth(texCoord + float2(-du,+dv));
	zsamples_b.z = PointSampleZDepth(texCoord + float2(  0,+dv));
	zsamples_b.w = PointSampleZDepth(texCoord + float2(+du,+dv));

	// Convert to world distances
	float4 wdepth_a = ConvertZToWorldDist4(zsamples_a);
	float4 wdepth_b = ConvertZToWorldDist4(zsamples_b);

	// Sobel edge detection filters
	//	vertical filter 		horizontal filter
	//	 [ -1  0  1 ]			 [ -1  -2  -1 ]
	//	 [ -2  0  2 ]			 [  0   0   0 ]
	//	 [ -1  0  1 ]			 [  1   2   1 ]
	float sobel_v = dot(wdepth_a, float4(-1,  0,  1, -2)) + dot(wdepth_b, float4(2, -1, 0, 1));
	float sobel_h = dot(wdepth_a, float4(-1, -2, -1,  0)) + dot(wdepth_b, float4(0,  1, 2, 1));
	
	float2 edge = float2(abs(sobel_h), abs(sobel_v)) - e_barrier;

	return step(0, edge);  // step(a,x) = (x>=a) ? 1 : 0
}

float AA_for_combined_main(const float2 texCoord)
{
	// Do the edge-detection thing
	float2 eh_ev = edge_detect(texCoord);

	// blurAmount (0.0 off, 1.0 on)
	return max(eh_ev.x, eh_ev.y); 
}

float4 AA_main(const float2 texCoord)
{
	float4 colour = BlurSample(texCoord, AA_for_combined_main(texCoord), screen_info.zw * e_kernel);
	
	return colour;	
}



/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	VERTEX SHADERS

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

VtoP VS_Screen(const VS_INPUT IN)
{
	VtoP OUT;
	OUT.position = IN.position;
	OUT.tex0 = IN.tex0;
	return OUT;
}


/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	PIXEL SHADERS

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

float4 PS_BlitPixel(const VtoP IN) : COLOR
{
	float4 pixel = tex2D(blit_sampler, IN.tex0);
	
	return pixel;
}

PS_OUTPUT PS_BlitColorDepth(const VtoP IN)
{
	PS_OUTPUT Out;

	Out.color = tex2D(blit_sampler, IN.tex0).rgba;
	Out.depth = tex2D(depth_sampler, IN.tex0).r;
	
	return Out;
}

float4 PS_BlitStencil(const VtoP IN) : COLOR
{
	float StencilValue = tex2D(blit_sampler, IN.tex0).b;
	
	return float4(StencilValue.xxx, 1);
}

float4 PS_DOF(const VtoP IN) : COLOR
{
	return DOF_main(IN.tex0);
}

float4 PS_AntiAlias(const VtoP IN) : COLOR
{
	return AA_main(IN.tex0);
}

float4 PS_Edge(const VtoP IN) : COLOR
{
	return float4(edge_detect(IN.tex0), 0, 1);
}

float4 Bloom_main( const float2 vScreenPosition )
{
	float4 frame = tex2D( frame_buffer_sampler, vScreenPosition );
	float4 glow = tex2D( glow_sampler, vScreenPosition );
	float4 color  = frame + glow * bloom_weight;
	return color;
}

float4 PS_Bloom(const VtoP IN) : COLOR
{
	// Look up source frame buffer color //glow_sampler
	return Bloom_main(IN.tex0);
}

float4 GaussDirectional_main(const float2 vScreenPosition)
{    
    float4 vSample = 0.0f;
    float4 vColor = 0.0f;
        
    float2 vSamplePosition;
    
    // Perform a one-directional gaussian blur
    for(int iSample = 0; iSample < 15; iSample++)
    {
        vSamplePosition = vScreenPosition + avSampleOffsets[iSample];
        vColor = tex2D(frame_buffer_sampler, vSamplePosition);
        vSample += avSampleWeights[iSample]*vColor;
    }
    
    return vSample;
}

float4 DownScale4x4Mask_main(const float2 vScreenPosition)
{	
    float4 sample = 0.0f;

	for( int i=0; i < 16; i++ )
	{
		float4 mask_sample = tex2D( frame_buffer_sampler, vScreenPosition + avSampleOffsets[i] );
		
		//subtract threshold
		float threadhold_luminance = mask_sample.a-bright_pass_threshold;
		//only add values above threshold					
		float sample_weight = step(0, threadhold_luminance); // step(a,x) = (x>=a) ? 1 : 0
				
		//add rgbs. already exposed.
		sample.rgb += mask_sample.rgb * sample_weight * mask_sample.a * bright_weight;
	}
    
	return sample / 16;
}

float4 DownScale4x4_main(const float2 vScreenPosition)
{	
    float4 sample = 0.0f;

	for( int i=0; i < 16; i++ )
	{
		sample += tex2D( frame_buffer_sampler, vScreenPosition + avSampleOffsets[i] );
	}
    
	return sample / 16;
}

float4 GaussBlur5x5_main( const float2 vScreenPosition )
{	
    float4 sample = 0.0f;

	for( int i=0; i < 12; i++ )
	{
		sample += avSampleWeights[i] * tex2D( frame_buffer_sampler, vScreenPosition + avSampleOffsets[i] );
	}

	return sample;
}

float4 PS_DownScale4x4Mask(const VtoP IN) : COLOR
{
	float4 frame =  DownScale4x4Mask_main(IN.tex0 );	
	frame.a = 1.0f;
	
	return frame;	
}

float4 PS_DownScale4x4(const VtoP IN) : COLOR
{
	float4 frame =  DownScale4x4_main(IN.tex0 );	
	frame.a = 1.0f;
	
	return frame;	
}

float4 PS_GaussBlur5x5(const VtoP IN) : COLOR 
{
	float4 frame =  GaussBlur5x5_main(IN.tex0 );
	
	frame.a = 1.0f;
	return frame;	
}

float4 PS_GaussDirectional(const VtoP IN)  : COLOR 
{
	float4 frame =  GaussDirectional_main(IN.tex0 );
	
	frame.a = 1.0f;
	return frame;	
}

float4 PS_Embossed(const VtoP IN) : COLOR
{
	float4 color = 0.0f;
	
	color.a = 1.0f;
	color.rgb = 0.5f;
	
	color -= tex2D(frame_buffer_sampler, IN.tex0 - 0.001) * 2.0f;
	color += tex2D(frame_buffer_sampler, IN.tex0 + 0.001) * 2.0f;
	
	color.rgb = (color.r + color.g + color.b) / 4.0f;

	return color;
}

float4 PS_GreyScaleBlurStatic(const VtoP IN) : COLOR
{
	float4 color = tex2D(frame_buffer_sampler, IN.tex0);

	color += tex2D(frame_buffer_sampler, IN.tex0 + 0.001);
	color += tex2D(frame_buffer_sampler, IN.tex0 + 0.002);
	color += tex2D(frame_buffer_sampler, IN.tex0 + 0.003);
	
	color /= 4;
	
	float Intensity = dot(color, float4(0.299, 0.587, 0.184, 0));

	return float4(Intensity.xxx, color.a);
}

/*-----------------------------------------------------------------------------
-------------------------------------------------------------------------------

	TECHNIQUES

-------------------------------------------------------------------------------
-----------------------------------------------------------------------------*/

technique Default
{
	pass p0
	{
		AlphaTestEnable		= false;
		AlphaBlendEnable	= false;
		CullMode			= none;
		ZEnable				= false;
		ZWriteEnable		= false;
		ZFunc				= Always;
		ColorWriteEnable	= RGBA;
		VertexShader		= compile vs_3_0 VS_Screen();
		PixelShader 		= compile ps_3_0 PS_AntiAlias();
//		PixelShader 		= compile ps_3_0 PS_Edge();
	}
}

technique Bloom
{
    pass p0 
    {		
	    AlphaBlendEnable	= false;
        SrcBlend			= SrcAlpha;
	    DestBlend			= InvSrcAlpha;
		CullMode			= none;
		ZEnable				= false;
		ZWriteEnable		= false;
		VertexShader		= compile vs_3_0 VS_Screen();
		PixelShader			= compile ps_3_0 PS_Bloom();
    }
}

technique DownScale4x4Mask
{
	pass p0
	{
		AlphaTestEnable		= false;
		AlphaBlendEnable	= false;
		CullMode			= none;
		ZEnable				= false;
		ZWriteENable		= false;
		VertexShader		= compile vs_3_0 VS_Screen();
		PixelShader			= compile ps_3_0 PS_DownScale4x4Mask();
	}
}

technique DownScale4x4
{
	pass p0
	{
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
	
		CullMode		= NONE;
		ZENABLE			= FALSE;
		ZWRITEENABLE	= FALSE;
		
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_DownScale4x4();
	}
}

technique GaussBlur5x5
{
    pass p0 
    {		
	    AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
	    DestBlend = InvSrcAlpha;
		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_GaussBlur5x5();
    }
}

technique GaussDirectional
{
    pass p0 
    {		
	    AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
	    DestBlend = InvSrcAlpha;
		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_GaussDirectional();
    }
}

technique DOF
{
	pass p0
	{
		AlphaTestEnable	= false;
		AlphaBlendEnable = false;
		CullMode = none;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader = compile ps_3_0 PS_DOF();
	}
}

technique Blit
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_BlitPixel();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

technique BlitColorDepth
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_BlitColorDepth();

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = Always;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

technique BlitStencil 
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader  = compile ps_3_0 PS_BlitStencil();
	}
}

technique Embossed
{
	pass p0
	{
		AlphaTestEnable	= false;
		AlphaBlendEnable = false;
		CullMode = none;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader = compile ps_3_0 PS_Embossed();
	}
}	

technique GreyScaleBlur
{
	pass p0
	{
		AlphaTestEnable	= false;
		AlphaBlendEnable = false;
		CullMode = none;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader = compile ps_3_0 PS_GreyScaleBlurStatic();
	}
}	