using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    public class MatrixProps : IShaderPropsBase
    {
        /// <summary>
        /// Hard-Coded Matrix Types
        /// </summary>
        public static class Type
        {
            // Fundamental Transforms
            public const int M = 0;
            public const int V = 1;
            public const int P = 2;
            public const int I_M = 3;
            public const int I_V = 4;

            public const int I_P = 5;

            // Composite Transforms
            public const int VP = 6;
            public const int MVP = 7;
            public const int I_VP = 8;
            public const int I_MVP = 9;
            public const int IT_MV = 10;

            // History Transforms
            public const int PRE_MVP = 11;
            public const int PRE_I_MVP = 12;
        }

        private static class MatrixDefs
        {
            public static readonly Dictionary<int, List<int>> Defs =
                new Dictionary<int, List<int>>
                {
                    {
                        // Model transform: Object => World
                        Type.M,
                        new List<int>
                        {
                            ObjectNaming.Space.Object,
                            ObjectNaming.Space.World
                        }
                    },
                    {
                        // Model transform: Object => World
                        Type.I_M,
                        new List<int>
                        {
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.Object
                        }
                    },
                    {
                        // View transform: World => Camera
                        Type.V,
                        new List<int>
                        {
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.View
                        }
                    },
                    {
                        // View transform: World => Camera
                        Type.I_V,
                        new List<int>
                        {
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.World
                        }
                    },
                    {
                        // Projection transform: Camera => Screen
                        Type.P,
                        new List<int>
                        {
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.HomogenousClip
                        }
                    },
                    {
                        // transform: =>
                        Type.I_P,
                        new List<int>
                        {
                            ObjectNaming.Space.HomogenousClip,
                            ObjectNaming.Space.View
                        }
                    },
                    {
                        // transform: =>
                        Type.VP,
                        new List<int>
                        {
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.HomogenousClip
                        }
                    },
                    {
                        // transform: =>
                        Type.I_VP,
                        new List<int>
                        {
                            ObjectNaming.Space.HomogenousClip,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.World
                        }
                    },
                    {
                        // transform: =>
                        Type.MVP,
                        new List<int>
                        {
                            ObjectNaming.Space.Object,
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.HomogenousClip
                        }
                    },
                    {
                        // transform: =>
                        Type.I_MVP,
                        new List<int>
                        {
                            ObjectNaming.Space.HomogenousClip,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.Object
                        }
                    },
                    {
                        // transform: =>
                        Type.IT_MV,
                        new List<int>
                        {
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.Object,
                            ObjectNaming.Space.Transposed
                        }
                    },
                    {
                        // transform: =>
                        Type.PRE_MVP,
                        new List<int>
                        {
                            ObjectNaming.Space.History,
                            ObjectNaming.Space.Object,
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.HomogenousClip
                        }
                    },
                    {
                        // transform: =>
                        Type.PRE_I_MVP,
                        new List<int>
                        {
                            ObjectNaming.Space.HomogenousClip,
                            ObjectNaming.Space.View,
                            ObjectNaming.Space.World,
                            ObjectNaming.Space.Object,
                            ObjectNaming.Space.History
                        }
                    },
                };
        }

        // Every 'Global Matrix' has a pre-defined ID value
        private static readonly List<int> GlobalIDs;

        private static int getGlobalId(int type)
        {
            return GlobalIDs[type];
        }

        static MatrixProps()
        {
            GlobalIDs = new List<int>(new int[MatrixDefs.Defs.Count]);
            // Pre-Calculate global matrix ids
            // Note: 'global' means wherever this matrix is,
            // it always has the same name, e.g, CMatrix_MVP;
            foreach (var definition in MatrixDefs.Defs)
            {
                int type = definition.Key; // Matrix Type
                // Chain of spaces to define this transform matrix
                List<int> transformDef = definition.Value;
                string name = ObjectNaming.Matrix.Transform.GetName("", transformDef.ToArray());
                GlobalIDs[type] = getTransformMatrixId(transformDef.ToArray());
            }
        }


        // Serialized matrix props stored in an array.
        private bool _disposed;
        private NativeArray<Matrix4x4> _props;
        private NativeArray<int> _propIds;
        private Dictionary<string, int> _propBook;

        public bool Disposed
        {
            get => _disposed;
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                _props.Dispose();
                _propIds.Dispose();
                _disposed = true;
            }
        }

        public MatrixProps(params (int type, Matrix4x4 data)[] globalMatrices)
        {
            // Check input params
            int length = globalMatrices.Length;

            // Alloc prop ID container & dictionary
            _propIds = new NativeArray<int>(
                length, Allocator.Persistent
            );
            _propBook = new Dictionary<string, int>();
            for (int i = 0; i < length; i++)
            {
                // Tuple layout: <type:int, data:Matrix4x4>
                int matrixType = globalMatrices[i].type;
                Matrix4x4 data = globalMatrices[i].data;
                if (!MatrixDefs.Defs.ContainsKey(matrixType))
                {
                    Debug.LogError(
                        "globalMatricesError: Invalid global matrix ID: " +
                        matrixType + "."
                    );
                    return;
                }

                // Fetch pre-calculated global id
                _propIds[i] = getGlobalId(matrixType);
                // Register KV pair
                _propBook.Add(getTransformMatrixName(matrixType), i);
            }

            // Alloc prop container
            List<Matrix4x4> src = new List<Matrix4x4>(length);
            foreach (var tuple in globalMatrices)
            {
                Matrix4x4 data = tuple.data;
                src.Add(data);
            } // Data extracted from input tuple params

            _props = new NativeArray<Matrix4x4>(
                length, Allocator.Persistent
            );
            _props.CopyFrom(src.ToArray());

            // Update flags
            _disposed = false;
        }

        public int Length
        {
            get { return _props.Length; }
        }

        public void SetGlobalMatricesUnsafe(params Matrix4x4[] newMatrices)
        {
            _props.CopyFrom(newMatrices);
        }
        
        /// <summary>
        /// Try to get handles(indices) pointing to
        /// a special group of properties.    
        /// Note: For performance concerns,
        /// Don't use this in realtime, instead,
        /// use this to fetch a list of indices in init state,
        /// and use that list to update resources in each frame.
        /// </summary>
        /// <param name="types">List of global matrix types</param>
        /// <param name="handles">Outputs a list of prop handles</param>
        public void TryGetPropHandlesGlobal(int[] types, out int[] handles)
        {
            handles = new int[types.Length];
            for (int i = 0; i < types.Length; i++)
            {
                int globalMatrixType = types[i];
                string matrixName = getTransformMatrixName(globalMatrixType);
                if (matrixName == null)
                {
                    Debug.LogError("Error: can't find global matrix with type: " +
                                   globalMatrixType + ".");
                }
                if (_propBook.TryGetValue(
                    matrixName,   // key
                    out int id    // value
                )) // If this type of matrix has been pre-defined as global
                {
                    handles[i] = id;
                }
                else
                {    // Otherwise, report as an error
                    Debug.LogError("Error: can't find global matrix with name: " +
                                   matrixName + ".");
                    return;
                }
            }
        }

        public void BindPropsAllCommand(
            CommandBuffer command,
            ComputeShader cs
        )
        {
            for (int i = 0; i < _props.Length; i++)
            {
                command.SetComputeMatrixParam(
                    cs, _propIds[i], _props[i]
                );
            }
        }

        public void BindPropsAllCommand(
            MaterialPropertyBlock propsBlock
        )
        {
            for (int i = 0; i < _props.Length; i++)
            {
                propsBlock.SetMatrix(_propIds[i], _props[i]);
            }
        }

        public void BindPropsCommand(
            int[] handles, 
            CommandBuffer cmd, 
            ComputeShader cs
        )
        {
            foreach (int index in handles)
            {
                cmd.SetComputeMatrixParam(cs, _propIds[index], _props[index]);
            }
        }

        public void BindPropsCommand(
            int[] handles,
            MaterialPropertyBlock propsBlock)
        {
            foreach (int index in handles)
            {
                propsBlock.SetMatrix(_propIds[index], _props[index]);
            }
        }

        public (int id, Matrix4x4 data) this[int index] => (_propIds[index], _props[index]);

        private static string getTransformMatrixName(int matrixType)
        {
            MatrixDefs.Defs.TryGetValue(matrixType, out List<int> spaceChain);
            if (spaceChain != null)
            {
                return ObjectNaming.Matrix.Transform.GetName("", spaceChain.ToArray());
            }

            return null;
        }

        private static int getTransformMatrixId(
            params int[] transformChain
        )
        {
            return Shader.PropertyToID(
                ObjectNaming.Matrix.Transform.GetName(
                    "", // Empty tag
                    transformChain
                )
            );
        }
    }
}