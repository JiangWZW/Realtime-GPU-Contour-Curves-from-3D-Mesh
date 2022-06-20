using System.Collections.Generic;
using System.Text;
using MPipeline.Custom_Data.BasicDataTypes.Global_Properties;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

public class LineDrawingProps : MonoBehaviour, ILineDrawingData
{
    public MatrixProps matrixProps;
    public VectorProps vectorProps;

    private List<IShaderPropsBase> _propsSerialized;

    void OnDestroy()
    {
        ContourExtractionPass.UpdatePerCameraData -= OnUpdatePerCameraData;
        // Native array
        DisposeAll();
    }

    private void OnDisable()
    {
        DisposeAll();
    }

    private void DisposeAll()
    {
        foreach (IShaderPropsBase props in _propsSerialized)
        {
            props?.Dispose();
        }
    }

    public void Init(Camera cam)
    {
        InitCameraMatrices(cam);
        InitCameraVectors(cam);

        _propsSerialized = new List<IShaderPropsBase>
        {
            matrixProps,
            vectorProps,
        };

        ContourExtractionPass.UpdatePerCameraData += OnUpdatePerCameraData;
    }

    public void OnUpdatePerCameraData(Camera camera, CommandBuffer cmd)
    {
        Camera currCamera = gameObject.GetComponent<Camera>();
        if (camera != currCamera)
        {
            return;
        }

        UpdateCameraMatrices(camera);
        UpdateCameraVectors(camera);
    }

    public void BindCameraVectorsCommand(
        int[] handles,
        CommandBuffer cmd,
        ComputeShader cs
    )
    {
        vectorProps.BindPropsCommand(handles, cmd, cs);
    }

    public void BindCameraVectorsAllCommand(
        CommandBuffer cmd,
        ComputeShader cs
    )
    {
        vectorProps.BindPropsAllCommand(cmd, cs);
    }

    public void BindCameraVectorsCommand(
        int[] handles,
        MaterialPropertyBlock props
    )
    {
        vectorProps.BindPropsCommand(handles, props);
    }

    public void BindCameraVectorsAllCommand(
        MaterialPropertyBlock props
    )
    {
        vectorProps.BindPropsAllCommand(props);
    }

    public void BindCameraMatricesCommand(
        int[] handles,
        CommandBuffer command,
        ComputeShader cs
    )
    {
        matrixProps.BindPropsCommand(handles, command, cs);
    }

    public void BindCameraMatricesCommand(
        int[] handles,
        MaterialPropertyBlock matProps)
    {
        matrixProps.BindPropsCommand(handles, matProps);
    }
    
    public void BindCameraMatricesAllCommand(
        CommandBuffer command,
        ComputeShader cs
    )
    {
        matrixProps.BindPropsAllCommand(command, cs);
    }

    public void BindCameraMatricesAllCommand(
        MaterialPropertyBlock matProps)
    {
        matrixProps.BindPropsAllCommand(matProps);
    }


    public enum PropTypes
    {
        CameraPositionWS,
        ScreenTexelSize
    }

    /// <summary>
    /// Receives property types provided by LineDrawingProps,
    /// returns internal handles of these props 
    /// </summary>
    /// <param name="matrixTypes"></param>
    /// <returns>internal handles of properties</returns>
    public int[] MatrixHandles(int[] matrixTypes)
    {
        matrixProps.TryGetPropHandlesGlobal(matrixTypes, out int[] handles);
        return handles;
    }

    public int[] VectorHandles(int[] propTypes)
    {
        if (!vectorProps.TryGetPropHandles(Descriptors(propTypes), out int[] handles))
        {
            Debug.LogError("Cannot fetch vector handles in LineDrawingProps.");
            return null;
        }

        return handles;
    }

    private static PropDescriptor[] Descriptors(int[] handles)
    {
        PropDescriptor[] output = new PropDescriptor[handles.Length];
        for (int i = 0; i < handles.Length; i++)
        {
            output[i] = DescriptorOfPropType[(PropTypes) handles[i]];
        }

        return output;
    }

    private static readonly Dictionary<PropTypes, PropDescriptor> DescriptorOfPropType =
        new Dictionary<PropTypes, PropDescriptor>
        {
            {
                PropTypes.CameraPositionWS, new PropDescriptor(
                    "Camera",
                    ObjectNaming.Vector.Usages.Position,
                    ObjectNaming.Space.World
                )
            },
            {
                PropTypes.ScreenTexelSize, new PropDescriptor(
                    "ScreenTexelSize",
                    ObjectNaming.Vector.Usages.Custom,
                    ObjectNaming.Space.Screen
                )
            }
        };

    private void InitCameraMatrices(Camera camera)
    {
        // Basic Transforms
        Matrix4x4 V = GetViewTransformMatrix(camera);
        Matrix4x4 P = GetProjectionTransformMatrix(camera);
        matrixProps = new MatrixProps(
            (MatrixProps.Type.V, V),
            (MatrixProps.Type.P, P),
            (MatrixProps.Type.VP, P * V), // !!! Note: Be careful about the order !!!
            (MatrixProps.Type.I_VP, (P * V).inverse),
            (MatrixProps.Type.I_P, P.inverse)
        );
    }

    public static Matrix4x4 GetViewTransformMatrix(Camera camera)
    {
        return camera.worldToCameraMatrix;
    }


    public static Matrix4x4 GetProjectionTransformMatrix(Camera camera)
    {
        return GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
    }

    private void InitCameraVectors(Camera camera)
    {
        // Allocate & Init a VectorProps instance
        vectorProps = new VectorProps(
            FetchCameraVectorDescs(),
            FetchCameraVectors(camera)
        );
    }

    private void UpdateCameraVectors(Camera camera)
    {
        if (!vectorProps.UpdatePropsAll(
            FetchCameraVectors(camera)))
        {
            Debug.LogError("Error: Cannot update camera vectors.");
        }
    }

    private PropDescriptor[] FetchCameraVectorDescs()
    {
        return new[]
        {
            DescriptorOfPropType[PropTypes.CameraPositionWS],
            DescriptorOfPropType[PropTypes.ScreenTexelSize]
        };
    }

    private Vector4[] FetchCameraVectors(Camera cam)
    {
        float w = Screen.width;
        float h = Screen.height;

        Vector4[] values =
        {
            GetCameraPosWS(cam),
            new Vector4(w, h, 1 / w, 1 / h)
        };

        return values;
    }

    private void UpdateCameraMatrices(Camera camera)
    {
        Matrix4x4 V = camera.worldToCameraMatrix;
        Matrix4x4 P = GetProjectionTransformMatrix(camera);
        // V, P, VP, I_VP
        matrixProps.SetGlobalMatricesUnsafe(
            V, P, P * V, (P * V).inverse, P.inverse
        );
    }


    // Utilities
    public static Vector4 GetCameraPosWS(Camera camera)
    {
        Vector3 pos = camera.transform.position;
        Vector4 posWS = new Vector4(
            pos.x,
            pos.y,
            pos.z,
            1.0f
        );
        return posWS;
    }
}