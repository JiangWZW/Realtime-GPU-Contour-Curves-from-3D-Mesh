using System;
using System.Collections.Generic;
using JetBrains.Annotations;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    public interface IShaderPropsBase
    {
        int Length { get; }
        bool Disposed { get; }
        void Dispose();
        void BindPropsAllCommand(CommandBuffer cmd, ComputeShader cs);
        void BindPropsAllCommand(MaterialPropertyBlock matProps);

        void BindPropsCommand(
            int[] handles, CommandBuffer cmd, ComputeShader CS);

        void BindPropsCommand(
            int[] handles, MaterialPropertyBlock matProps);
    }

    public abstract class ShaderPropsBase<T> : IShaderPropsBase where T : struct
    {
        protected NativeArray<T> Props;
        protected NativeArray<int> PropIds;
        private Dictionary<string, int> _propsBook;

        private bool _disposed;
        private int _length;

        public int Length
        {
            get { return _length; }
        }

        public bool Disposed
        {
            get => _disposed;
            set => _disposed = value;
        }

        // Life Cycle
        // -------------------------------------------------------------------------
        protected ShaderPropsBase(
            Func<PropDescriptor, string> descToNameFunc)
        {
            _descToNameFunc = descToNameFunc;
        }

        protected void Init(PropDescriptor[] descs, T[] initValues)
        {
            _disposed = true;
            // Check in case my head was fucked up
            if (descs.Length != initValues.Length)
            {
                Debug.LogError(
                    "Error: descriptor and property arrays should have" +
                    " the same number of elements."
                );
                return;
            }

            // Init propsBook
            _propsBook = new Dictionary<string, int>();

            // Alloc & Init props
            _length = descs.Length;
            // --- props
            Props = new NativeArray<T>(
                Length,
                Allocator.Persistent
            );
            Props.CopyFrom(initValues);

            // --- prop IDs
            PropIds = new NativeArray<int>(
                Length,
                Allocator.Persistent
            );
            for (int i = 0; i < Length; ++i)
            {
                string name = _descToNameFunc(descs[i]);
                PropIds[i] = Shader.PropertyToID(name);
                _propsBook.Add(name, i); // <PropertyName:string, PropertyID:int> 
            }

            _disposed = false;
        }

        public bool UpdatePropsAll(T[] values)
        {
            if (values.Length != Length)
            {
                return false;
            }

            Props.CopyFrom(values);
            return true;
        }

        /// <summary>
        /// Update properties via handles retrieved from
        /// <see cref="TryGetPropHandles"/>.
        /// </summary>
        /// <param name="handles">Handles reference to prop items.</param>
        /// <param name="values">New values to assign.</param>
        /// <returns></returns>
        public bool UpdateProps(int[] handles, T[] values)
        {
            if (handles.Length > Length)
            {
                return false;
            }

            // TODO: This needs to be checked.
            for (int i = 0; i < handles.Length; ++i)
            {
                Props[handles[i]] = values[i];
            }

            return true;
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Props.Dispose();
                PropIds.Dispose();
                _disposed = true;
            }
        }


        // Data Access
        // ---------------------------------------------------------

        public ShaderProperty<T> this[int index]
        {
            get { return GetVectorPropUnsafe(index); }
        }

        private ShaderProperty<T> GetVectorPropUnsafe(int index)
        {
            return new ShaderProperty<T>(
                PropIds[index], Props[index]);
        }

        // Property Name => Property Handle
        private int NameToHandle(string vectorName)
        {
            if (!(_propsBook.TryGetValue(vectorName, out int index)))
            {
                return -1;
            }

            return index;
        }
        // Descriptor => Property Name
        private readonly Func<PropDescriptor, string> _descToNameFunc;
        // Descriptor => Handle == (Desc => Name) * (Name => Handle)
        protected int DescToHandle(PropDescriptor desc)
        {
            return NameToHandle(_descToNameFunc(desc));
        }
        
        /// <summary>
        /// Try to get handles(indices) pointing to
        /// a special group of properties.    
        /// Note: For performance concerns,
        /// Don't use this in realtime, instead,
        /// use this to fetch a list of indices in init state,
        /// and use that list to update resources in each frame.
        /// </summary>
        /// <param name="descs">List of descriptors to filter props</param>
        /// <param name="handles">Outputs a list of prop handles</param>
        /// <returns>False if some descriptor(s) can't be found.</returns>
        public virtual bool TryGetPropHandles(
            PropDescriptor[] descs,
            out int[] handles
        )
        {
            handles = new int[descs.Length];
            for (int i = 0; i < descs.Length; i++)
            {
                handles[i] = DescToHandle(descs[i]);
                if (handles[i] == -1)
                {
                    return false;
                }
            }

            return true;
        }


        // Bind Props to Shader Resource
        // ----------------------------------------------------------------------------------
        protected Action<CommandBuffer, ComputeShader, int> BindPropCommand;
        protected Action<MaterialPropertyBlock, int> BindPropMatProps;

        public void BindPropsAllCommand(CommandBuffer cmd, ComputeShader cs)
        {
            for (int i = 0; i < Length; ++i)
            {
                BindPropCommand(cmd, cs, i);
            }
        }

        public void BindPropsAllCommand(MaterialPropertyBlock matProps)
        {
            for (int i = 0; i < Length; ++i)
            {
                BindPropMatProps(matProps, i);
            }
        }

        public void BindPropsCommand(
            [NotNull] int[] handles, CommandBuffer cmd, ComputeShader CS)
        {
            for (int i = 0; i < handles.Length; ++i)
            {
                BindPropCommand(cmd, CS, handles[i]);
            }
        }

        public void BindPropsCommand(
            [NotNull] int[] handles, MaterialPropertyBlock matProps)
        {
            for (int i = 0; i < handles.Length; ++i)
            {
                BindPropMatProps(matProps, handles[i]);
            }
        }
    }
}