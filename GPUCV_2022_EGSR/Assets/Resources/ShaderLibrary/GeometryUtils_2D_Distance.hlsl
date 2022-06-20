#ifndef E0AB1067_074E_40BD_A490_EDA9A7F780B4
#define E0AB1067_074E_40BD_A490_EDA9A7F780B4

bool same_direction(const float2 u, const float2 v)
{
	return (abs(u.x) > abs(u.y)) // pick a robust(larger) value
		? (sign(u.x) == sign(v.x))
		: (sign(u.y) == sign(v.y));
}

float wdot(float2 p, float2 q, float2 r)
{
	return dot(p - q, r - q);
}


// angle<pq, rq> < 90
bool is_acute_angle(float2 p, float2 q, float2 r)
{
    return wdot(p, q, r) > .0f;
}
bool is_acute_angle(float2 u, float2 v)
{
    return dot(u, v) > .0f;
}


float _distance_measure_sub(float startwcross, float endwcross)
{
    return abs(startwcross) - abs(endwcross);
}

#endif /* E0AB1067_074E_40BD_A490_EDA9A7F780B4 */
