using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.PerCameraData
{
    public class DispatchIndirectSwapChain
    {
        private CommandBuffer _cmd;
        
        private int _front = 1;
        private readonly List<ComputeBuffer> DispatchBuffers;

        public DispatchIndirectSwapChain(
            ComputeBuffer buffer0, ComputeBuffer buffer1)
        {
            DispatchBuffers = new List<ComputeBuffer> {buffer0, buffer1};
            _cmd = null;
        }

        public void ResetCommand(CommandBuffer cmd)
        {
            _front = 1;
            // Reset front
            cmd.SetBufferData(
                DispatchBuffers[_front],
                new uint[] {1, 1, 1, 0}
            );
            // Reset back
            cmd.SetBufferData(
                DispatchBuffers[(_front + 1) % 2],
                new uint[] {1, 1, 1, 0}
            );
        }

        public ComputeBuffer Front()
        {
            return DispatchBuffers[_front];
        }

        public void Swap()
        {
            // Reset old front dispatch buffer
            _cmd.SetBufferData(
                DispatchBuffers[_front],
                new uint[] {1, 1, 1, 0}
            );
            // Swap back buffer to front
            _front = (_front + 1) % 2;
        }

        public void DirtySwap()
        {
            // Swap back buffer to front
            _front = (_front + 1) % 2;
        }

        public void ConnectTo(CommandBuffer cmd)
        {
            _cmd = cmd;
        }

        public void DisconnectFromCmd()
        {
            _cmd = null;
        }
    }

    public class LineDrawingDispatchIndirectArgs
    {
        private readonly Dictionary<int, ComputeBuffer> _dispatchArgs;
        
        private int _activeBufferHandle;
        public ComputeBuffer CurrentArgs => _dispatchArgs[_activeBufferHandle];

        public LineDrawingDispatchIndirectArgs(params (int, ComputeBuffer)[] dispatchArgs)
        {
            _dispatchArgs = new Dictionary<int, ComputeBuffer>();
            foreach ((int, ComputeBuffer) arg in dispatchArgs)
            {
                _dispatchArgs.Add(arg.Item1, arg.Item2);
            }

            _activeBufferHandle = -1; // must be explicitly 
        }

        public void AddIndirectArgsBuffer(int lineDrawingBufferHandle, ComputeBuffer buffer)
        {
            _dispatchArgs.Add(lineDrawingBufferHandle, buffer);
        }

        public void SetCurrent(int lineDrawingBufferHandle)
        {
            if (!_dispatchArgs.ContainsKey(lineDrawingBufferHandle))
            {
                Debug.LogError(
                    "Error: indirect args buffer "
                    + lineDrawingBufferHandle
                    + " invalid / not-registered."
                );
                return;
            }
            _activeBufferHandle = lineDrawingBufferHandle;
        }

        public void ResetArgsCommand(int lineDrawingBufferHandle, CommandBuffer cmd)
        {
            cmd.SetBufferData(
                _dispatchArgs[lineDrawingBufferHandle],
                new uint[] { 1, 1, 1, 0 }
            );
        }

        public void ResetAllArgsCommand(CommandBuffer cmd)
        {
            foreach (KeyValuePair<int, ComputeBuffer> args in _dispatchArgs)
            {
                for (int i = 0; i < _dispatchArgs.Count; i++)
                {
                    cmd.SetBufferData(
                        args.Value,
                        new uint[] { 1, 1, 1, 0 }
                    );
                }
            }
        }

        public ComputeBuffer Args(int lineDrawingBufferHandle)
        {
            return _dispatchArgs[lineDrawingBufferHandle];
        }

      
        public void ConnectTo(CommandBuffer cmd)
        {
        }

        public void DisconnectFromCmd()
        {
        }
    }
}