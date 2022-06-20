using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    public class VectorProps : ShaderPropsBase<Vector4>
    {
        public VectorProps(
            PropDescriptor[] descs,
            Vector4[] vectors)
        :base(ObjectNaming.Vector.GetVectorName)
        {
            Init(descs, vectors);
            BindPropCommand += (cmd, cs, handle) =>
            {
                cmd.SetComputeVectorParam(cs, PropIds[handle], Props[handle]);
            };
            BindPropMatProps += (matProps, handle) =>
            {
                matProps.SetVector(PropIds[handle], Props[handle]);
            };
        }
    }
}