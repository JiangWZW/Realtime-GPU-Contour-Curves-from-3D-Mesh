using System.Collections;
using System.Collections.Generic;
using System;
using MPipeline.SRP_Assets.Features;
using UnityEngine;
using Object = System.Object;

/// <summary>
/// Custom data stored in each camera,
/// will be used by custom SRP later. 
/// Each ILineDrawingData must implement following methods:
/// 1. void Init(), for data initialization
/// 2. void OnUpdatePerCameraData(Camera camera), for
/// defining its behaviour 
/// </summary>
public interface ILineDrawingData
{
    void Init(Camera cam);
}

public interface ILineDrawingDataUser
{
    bool AsyncDataLoaded();
    void SetupDataAsync(List<ILineDrawingData> perCameraDataList);
}


/// <summary>
/// Provides services to fetch all types of 
/// componets with ILineDrawingData interface...
/// inside each camera. 
/// </summary>
public abstract class PerCameraDataFactory
{
    /// <summary>
    /// Try to create a custom singleton-component, if there is no instance
    /// in camera at present. (Using custom init function)
    /// </summary>
    /// <param name="camera">Which camera this component belongs to.</param>
    /// <param name="initAction">Function to initialize this type of resource.</param>
    /// <returns>If the component has already existed in camera.</returns>
    public static bool TryCreateSingleton<T>(
        Camera camera, Action<T> initAction, out T data)
        where T : MonoBehaviour
    {
        if (false == camera.gameObject.TryGetComponent<T>(out data))
        {
            data = Create<T>(camera, initAction);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Try to create a custom singleton-component if there is no instance
    /// in camera at present. (Using defalut init interface)
    /// </summary>
    /// <param name="camera">Which camera this component belongs to.</param>
    /// <param name="data"></param>
    /// <returns>If the component has already existed in camera.</returns>
    public static bool TryCreateSingleton<T>(
        Camera camera, out T data)
        where T : MonoBehaviour
    {
        if (false == camera.gameObject.TryGetComponent<T>(out data))
        {
            data = Create<T>(camera);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Get a custom component of type T,   
    /// binded with a certain camera.   
    /// If that component doesn't exist, create a new one.
    /// </summary>
    /// <param name="camera">Which camera this component belongs to.</param>
    /// <param name="initAction">Function to initialize this type of resource.</param>
    /// <typeparam name="T">Actual type of the monobehaviour.</typeparam>
    /// <returns>Resource that needed.</returns>
    public static T GetOrCreateSingleton<T>(Camera camera, Action<T> initAction)
        where T : MonoBehaviour
    {
        if (false == camera.gameObject.TryGetComponent<T>(out T data))
        {
            data = Create<T>(camera, initAction);
        }

        return data;
    }

    /// <summary>
    /// Get a custom component of type T,   
    /// binded with a certain camera.   
    /// If that component doesn't exist, create a new one.
    /// </summary>
    /// <param name="camera">Which camera this component belongs to.</param>
    /// <typeparam name="T">Actual type of the monobehaviour.</typeparam>
    /// <returns>Resource that needed.</returns>
    public static T GetOrCreateSingleton<T>(Camera camera)
        where T : MonoBehaviour
    {
        if (false == camera.gameObject.TryGetComponent<T>(out T data))
        {
            data = Create<T>(camera);
        }

        return data;
    }


    /// <summary>
    /// Try to get a resource component in camera.
    /// </summary>
    /// <param name="camera"></param>
    /// <param name="data"></param>
    /// <typeparam name="T"></typeparam>
    /// <returns>True if exists, False otherwise.</returns>
    public static bool TryGet<T>(Camera camera, out T data)
        where T : MonoBehaviour
    {
        bool res = camera.gameObject.TryGetComponent<T>(out data);
        return res;
    }

    private static T Create<T>(Camera camera, Action<T> initAction)
        where T : MonoBehaviour
    {
        T data = camera.gameObject.AddComponent<T>();
        if (data != null)
        {
            initAction(data);
        }

        return data;
    }

    private static T Create<T>(Camera camera)
        where T : MonoBehaviour
    {
        T data = camera.gameObject.AddComponent<T>();
        if (data != null)
        {
            InitAction<T>(data, camera);
        }

        return data;
    }

    /// <summary>
    /// Use C# reflection technology
    /// to get init method of generic class T.
    /// </summary>
    private static void InitAction<T>(T data, Camera camera)
        where T : MonoBehaviour
    {
        System.Reflection.MethodInfo mt = data.GetType().GetMethod("Init");
        mt.Invoke(data, new Object[] {camera});
    }
}