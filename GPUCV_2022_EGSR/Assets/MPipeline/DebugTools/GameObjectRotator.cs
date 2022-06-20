using Unity.Mathematics;
using UnityEngine;

namespace Assets.MPipeline.DebugTools
{
    public class GameObjectRotator : MonoBehaviour
    {
        [Range(-1.0f, 1.0f)]
        public float xForceDirection = 0.0f;
        [Range(-1.0f, 2.0f)]
        public float yForceDirection = 0.0f;
        [Range(-1.0f, 1.0f)]
        public float zForceDirection = 0.0f;

        public float speedMultiplier = 1;

        public bool worldPivote = false;

        private Space spacePivot = Space.Self;

        private float Period = 2400;
        private float _currFrame = 0;

        void Start()
        {
            _currFrame = 0;
            if (worldPivote) spacePivot = Space.World;
        }

        void Update()
        {
            // Rotation
            Period = 14400;
            float turnaround = math.sin(2.0f * math.PI * (_currFrame / Period));
            // gameObject.transform.Rotate(xForceDirection * speedMultiplier
            //     , yForceDirection * turnaround * speedMultiplier
            //     , zForceDirection * speedMultiplier
            //     , spacePivot
            // );

            // Translate along z
            // gameObject.transform.Translate(
            //     0, 0,
            //     yForceDirection * math.sin(2.0f * math.PI * (_currFrame / Period)),
            //     spacePivot
            // );

            _currFrame += 1;
        }

    }
}
