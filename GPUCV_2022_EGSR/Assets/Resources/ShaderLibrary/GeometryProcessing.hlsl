#ifndef DAC91A1F_9846_439C_BCD0_0A2A90211014
#define DAC91A1F_9846_439C_BCD0_0A2A90211014

#define MAX_F32 3.402823466e+38f
#define DFL_F32 1.175494351e-38f



// Types of intersection
// --------------------------------------------------
// Two linear components are collinear(on the same line)
#define G2D_X2_LINEAR_COMPS_COLLINEAR_BIT 16u
// Two linear components are collinear
// - has 1 intersection point
#define G1D_X2_LINEAR_COMPS_TOUCH_BIT 1u
// Two linear components are collinear
// - has 1 overlapping segment
#define G1D_X2_LINEAR_COMPS_OVERLAP_BIT 2u


// Two linear components intersects at a point
#define G2D_X2_LINEAR_COMPS_CROSS_BIT 4u
// Two linear components are parallel
#define G2D_X2_LINEAR_COMPS_PARALLEL_BIT 8u




#endif /* DAC91A1F_9846_439C_BCD0_0A2A90211014 */
