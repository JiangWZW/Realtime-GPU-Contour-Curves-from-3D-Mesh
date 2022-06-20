using System;
using System.ComponentModel;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    public class IntegerProps: ShaderPropsBase<int>
    {
        public IntegerProps(
            PropDescriptor[] descs,
            int[] integers
        ) : base(ObjectNaming.Scalar.GetScalarName<int>)
        {
            Init(descs, integers);
            
            BindPropCommand += (cmd, cs, handle) =>
            {
                cmd.SetComputeIntParam(cs, PropIds[handle], Props[handle]);
            };
            BindPropMatProps += (matProps, handle) =>
            {
                matProps.SetInt(PropIds[handle], Props[handle]);
            };
        }
    }
}