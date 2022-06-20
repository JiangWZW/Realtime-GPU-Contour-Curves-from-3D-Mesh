#ifndef PARTICLECULLCOMMON_INCLUDED
#define PARTICLECULLCOMMON_INCLUDED

#define MAX_LIFESPAN 8.0f
#define CULL_MIN_SPRING_LENGTH 32u

void IncrementVisibility(inout float visibility)
{
	visibility = min(visibility + 1.0f, MAX_LIFESPAN);
}
void DecrementVisibility(inout float visibility)
{
	visibility -= 1.0f;
}
float _VisibilityCullThreshold;



#endif /* PARTICLECULLCOMMON_INCLUDED */
