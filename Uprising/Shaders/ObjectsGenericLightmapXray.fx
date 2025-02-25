//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Lightmapped Objects | Japan Floating Island
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SPECMAP 1 // Define for objects shader with specularity/envmap/self illumination map
#define SUPPORT_LIGHTMAP 1 // Define for objects that use a lightmap (supports HDR)
#define SUPPORT_XRAY 1 // Used to automagically fade out objects between Yuriko and the camera; specific to her commando levels
#define SUPPORT_NOSHADOWS 1 // Used in Yuriko's level to remove shadow casting from specific objects
#define SUPPORT_SSAO 1	// enable SSAO

#include "Objects.fxh"
