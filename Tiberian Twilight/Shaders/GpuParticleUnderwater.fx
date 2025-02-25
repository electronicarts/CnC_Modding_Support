//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// GPU particle shader for rendering underwater particles.
// It applies depth based coloring, and tags the particle system to be rendered before water rendering.
//////////////////////////////////////////////////////////////////////////////

#define DRAW_UNDERWATER // Define this to apply depth based coloring, and tag the particle system to be rendered before water rendering

#include "GpuParticle.fx"
