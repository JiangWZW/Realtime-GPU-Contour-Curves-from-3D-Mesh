#ifndef A44D8E8A_78D0_45B1_939A_D7BD9D23BED3
#define A44D8E8A_78D0_45B1_939A_D7BD9D23BED3


float2 orth_vec2d(float2 vec)
{
	return float2(vec.y, -vec.x);
}

// On a right-handed 2d cartesian coordinate,
//
// wcross(u, v) ==
// > 0 if u->v turns CCW
// == 0 if u//v
// < 0 if u->v turns CW
// 
// -------------------------------------------
// Special properties:
//
// wcross(u, v) = -wcross(u, v)
//
// wcross(u, v) = |u||v|sin<theta>,
// theta is the angle formed from u to v
//
// wcross(u, v) == 0 <==> u//v
//
// wcross(u, v) can also be seen as
// signed area of triangle formed from u to v
float wcross(float2 u, float2 v)
{
    return u.x * v.y - u.y * v.x;
}


#define LEFT_TURN 1
#define RIGHT_TURN -1
int orientationC2(const float2 u, const float2 v)
{
  return sign(wcross(u, v));
}

// Tells R is on PQ's left or right side
// (only right-handed axis)
int orientationC2(
	const float2 p,
    const float2 q,
    const float2 r)
{
  return orientationC2(q - p, r - p);
}


bool left_turn(float2 u, float2 v)
{
    return wcross(u, v) > .0f;
}
bool right_turn(float2 u, float2 v)
{
    return wcross(u, v) < .0f;
}

#endif /* A44D8E8A_78D0_45B1_939A_D7BD9D23BED3 */
