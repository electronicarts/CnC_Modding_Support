/*************************************************	*****************************
*
* PostFX_MSAA.fx
*
*	
* Copyright (c)2008 ELectronic Arts, Inc.
*
******************************************************************************/

#include "Common.fxh"
#include "CommonPostFX.fxh"


// Screen info.
float2 ScreenInfo
<
	string SasBindAddress = "WW3D.FrameBufferSize";
>;


// Taken from BFME2, can be made dynamic if needed.
#define NClip 30.0f
#define FClip 3800.0f

float4 CameraInfo	// camera info ( -f*n/(f-n), f/(f-n), n, 1/(f-n) )
<
	string SasBindAddress = "WW3D.AA.CameraInfo";
> = float4( -FClip*NClip/(FClip-NClip), FClip/(FClip-NClip), NClip, 1.0f/(FClip-NClip) );
							
															
static const float KernelSize  = 0.35f;			// anti-alias kernel size
static const float EdgeBarrier = 50.0f; 		// world space edge detection barrier


#define DEBUG_PSAA 0

//   Red = 30% of the luminosity.
// Green = 59% of the luminosity.
//  Blue = 11% of the luminosity.
//
// e.g.
//
// RGB color of (100, 150, 200) would compute luminance as:
//
// (100 x 0.3) + (150 x 0.59) + (200 x 0.11) = 140

static const float3 LumVec = float3(0.3f, 0.59f, 0.11f);

static const float  MinThreshold = 0.02f;
static const float  MaxThreshold = 0.03f;


/*-----------------------------------------------------------------------------
Poisson Distribution Tap Filter
-----------------------------------------------------------------------------*/
#define NumTaps 8
static const float2 PoissonTable[NumTaps] = 
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

static const float BlurThreshold = 0.05f;



// Samplers

SAMPLER_2D_BEGIN(FrameBufferSampler,
	string SasBindAddress = "PostEffect.FrameBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MipFilter = None;
	MinFilter = Linear;
	MagFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(DepthBufferSampler,
	string SasBindAddress = "PostEffect.DepthBufferTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MipFilter = None;
	MinFilter = Point;
	MagFilter = Point;
SAMPLER_2D_END



// ----------------------------------------------------------------------------
struct VSOutputAA
{
	float4 Position	: POSITION;
	float2 TexCoord	: TEXCOORD0;
};


struct VSOutputPSAA
{
    float4 Position			: POSITION;
    float2 TexCoord			: TEXCOORD0;  
    float4 TexCoordOffLR    : TEXCOORD1;  
    float4 TexCoordOffUD    : TEXCOORD2;  

#if DEBUG_PSAA
	float4 DebugColor		: TEXCOORD3;
	float2 DebugThreshold	: TEXCOORD4;
#endif
};


/*-----------------------------------------------------------------------------
SampleZDepth
-----------------------------------------------------------------------------*/
float PointSampleZDepth(const float2 texCoord)
{
	return 1.0f - tex2D(SAMPLER(DepthBufferSampler), texCoord).r;
}

/*-----------------------------------------------------------------------------
ConvertZToWorldDist
	To acuratly control Z blur fall off we should really be working in normalized world space (i.e. a wbuffer).
	Convert z value to world distance		
	W = (-(F*N)/(F-N))/(Z- (F/(F-N))

	CameraInfo.x = - f*n/(f-n);
	CameraInfo.y = f/(f-n);
	CameraInfo.z = n;
	CameraInfo.w = 1.0f/(f-n);

	input: 0.0->1.0 
	output: near->far 
-----------------------------------------------------------------------------*/
float ConvertZToWorldDist(float zDepth) 
{
	return  CameraInfo.x / (zDepth - CameraInfo.y);	
}

// ----------------------------------------------------------------------------
// As above, but does 4 distance conversions at once
float4 ConvertZToWorldDist4(float4 zDepths)
{
	return CameraInfo.x / (zDepths - CameraInfo.y);	
}


// ----------------------------------------------------------------------------
float4 BlurSample(const float2 texCoord, const float blurAmount, float2 blurOffset)
{	
	float tapContribution = 1.0f / NumTaps;
	
	// Grab the first sample, at the center of the disc
	float4 color = tex2D(SAMPLER(FrameBufferSampler), texCoord);

	// If the blur amount is greater than a threshold, then apply the full 8 tap filter.
	if( blurAmount >= BlurThreshold )
	{
		// set up color for accumulation
		color *= tapContribution;

		// scale the blur offset by the blur amount
		blurOffset *= blurAmount;

	    // Accumulate the rest
	    for( int i = 1; i < NumTaps; i++ )
	    {
		    float4 tapColor = tex2D(SAMPLER(FrameBufferSampler), texCoord + PoissonTable[i] * blurOffset);
		    color += tapColor * tapContribution;
	    }

	#if 0
		// Displays the edges in 'white'.
		color = float4( 0.1, 0.0, 0.0, 0.0 );
	#endif
	}

	// Compensate for darkening in Xenon fixed16 HDR render targets
	color.xyz = UncompressRenderTargetColor(color.xyz);

	// Done!
	return color;	
}


// ----------------------------------------------------------------------------
float EdgeDetect(const float2 texCoord)
{
	float du = 1.0f / ScreenInfo.x;
	float dv = 1.0f / ScreenInfo.y;
	
	float4 zsamplesA;
	float4 zsamplesB;

	// Sample Z-buffer
	zsamplesA.x = PointSampleZDepth(texCoord + float2(-du,-dv));
	zsamplesA.y = PointSampleZDepth(texCoord + float2(  0,-dv));
	zsamplesA.z = PointSampleZDepth(texCoord + float2(+du,-dv));
	zsamplesA.w = PointSampleZDepth(texCoord + float2(-du,  0));
	zsamplesB.x = PointSampleZDepth(texCoord + float2(+du,  0));
	zsamplesB.y = PointSampleZDepth(texCoord + float2(-du,+dv));
	zsamplesB.z = PointSampleZDepth(texCoord + float2(  0,+dv));
	zsamplesB.w = PointSampleZDepth(texCoord + float2(+du,+dv));

	// Convert to world distances
	float4 wdepthA = ConvertZToWorldDist4(zsamplesA);
	float4 wdepthB = ConvertZToWorldDist4(zsamplesB);

	// Sobel edge detection filters
	//	vertical filter 		horizontal filter
	//	 [ -1  0  1 ]			 [ -1  -2  -1 ]
	//	 [ -2  0  2 ]			 [  0   0   0 ]
	//	 [ -1  0  1 ]			 [  1   2   1 ]
	float sobelV = dot(wdepthA, float4(-1,  0,  1, -2)) + dot(wdepthB, float4(2, -1, 0, 1));
	float sobelH = dot(wdepthA, float4(-1, -2, -1,  0)) + dot(wdepthB, float4(0,  1, 2, 1));
	
	float2 edge = float2(abs(sobelH), abs(sobelV)) - EdgeBarrier;

	edge = step(0, edge);
	
	// blurAmount (0.0 off, 1.0 on)
	return max(edge.x, edge.y);
}

// ----------------------------------------------------------------------------
VSOutputAA AntiAliasVS(float2 Position : POSITION, float2 Texcoord : TEXCOORD0)
{
	VSOutputAA Out;
	Out.Position = float4(Position, 0, 1);
	Out.TexCoord = Texcoord;
	return Out;
}

// ----------------------------------------------------------------------------
float4 AntiAliasPS(const VSOutputAA In) : COLOR
{
	float2 blurOffset = (1.0f / ScreenInfo) * KernelSize;
	
	return BlurSample(In.TexCoord, EdgeDetect(In.TexCoord), blurOffset);
}


// ----------------------------------------------------------------------------
float PerceptualDifferenceLum( float3 a, float3 b )
{
	float3 diff = abs( a - b );

	return dot( diff, LumVec );
}


// ----------------------------------------------------------------------------
VSOutputPSAA AntiAliasLumVS(float2 Position : POSITION, float2 TexCoord : TEXCOORD0)
{
	float4 PSAAOffsets;

#if DEBUG_PSAA
	PSAAOffsets.z = 1.0f;
    PSAAOffsets.w = MinThreshold * 0.01f + MaxThreshold;
#endif

	PSAAOffsets.x = 1.0f / ScreenInfo.x;
	PSAAOffsets.y = 1.0f / ScreenInfo.y;

	VSOutputPSAA Out;
	Out.Position = float4(Position, 0, 1);

	Out.TexCoord = TexCoord;
	
    Out.TexCoordOffLR.xy = Out.TexCoord;
    Out.TexCoordOffLR.x -= PSAAOffsets.x;
    Out.TexCoordOffLR.zw = Out.TexCoord;
    Out.TexCoordOffLR.z += PSAAOffsets.x;
    Out.TexCoordOffUD.xy = Out.TexCoord;
    Out.TexCoordOffUD.y -= PSAAOffsets.y;
    Out.TexCoordOffUD.zw = Out.TexCoord;
    Out.TexCoordOffUD.w += PSAAOffsets.y;
    
#if DEBUG_PSAA
    Out.DebugColor = PSAAOffsets.z ? float4( 1.0f, 0.0f, 0.0f, -1.0f ) : 0.0f;
    Out.DebugThreshold = PSAAOffsets.w;
#endif
  
	return Out;
}


// ----------------------------------------------------------------------------
float4 AntiAliasLumPS(const VSOutputPSAA In) : COLOR
{
	float4 col0 = tex2D( SAMPLER(FrameBufferSampler), In.TexCoordOffLR.xy );
	float4 col2 = tex2D( SAMPLER(FrameBufferSampler), In.TexCoordOffLR.zw );
	float4 col1 = tex2D( SAMPLER(FrameBufferSampler), In.TexCoordOffUD.xy );
	float4 col3 = tex2D( SAMPLER(FrameBufferSampler), In.TexCoordOffUD.zw );
    
    float4 col = tex2D( SAMPLER(FrameBufferSampler), In.TexCoord );
	float4 colRet = col;

#if DEBUG_PSAA
	float MinThreshold = 0.02f;//In.DebugThreshold.x;
	float MaxThreshold = 0.03f;//In.DebugThreshold.y;
#endif

    float hDiff = PerceptualDifferenceLum( col0.rgb, col2.rgb );
	float vDiff = PerceptualDifferenceLum( col1.rgb, col3.rgb );
	
	float maxDiff = max( hDiff, vDiff );

	if( maxDiff > MinThreshold )
    {
		colRet += col0 + col1 + col2 + col3;
        colRet *= 0.2;

		float filterBlend = saturate( ( maxDiff - MinThreshold ) / ( MaxThreshold - MinThreshold ) );

		colRet = lerp( col, colRet, filterBlend );

#if DEBUG_PSAA
		if( In.DebugColor.a > 0.0f )
		{
			colRet = lerp( colRet, In.DebugColor, In.DebugColor.a * filterBlend );
		}
#endif
	}
	
#if DEBUG_PSAA
	if( In.DebugColor.a < 0.0f )
	{
		float c0 = dot( col.rgb, LumVec );
		float c1 = dot( colRet.rgb, LumVec );
		
		if( c0 < c1 )
			colRet = float4( 0.0f, c1 - c0, 0.0f, 1.0f );
		else
			colRet = float4( c0 - c1, 0.0f, 0.0f, 1.0f );
	}
#endif

	// Compensate for darkening in Xenon fixed16 HDR render targets
	colRet.xyz = UncompressRenderTargetColor( colRet.xyz );

	return colRet;
}



// ----------------------------------------------------------------------------
technique AntiAlias
{
	pass p0
	{
		VertexShader = compile VS_3_0 AntiAliasLumVS();
		PixelShader  = compile PS_3_0 AntiAliasLumPS();

		AlphaTestEnable	= false;
		AlphaBlendEnable = false;
		CullMode = none;
		ZEnable	= false;
		ZWriteEnable = false;
		ZFunc = Always;
		ColorWriteEnable = RED|GREEN|BLUE|ALPHA;
	}
}





