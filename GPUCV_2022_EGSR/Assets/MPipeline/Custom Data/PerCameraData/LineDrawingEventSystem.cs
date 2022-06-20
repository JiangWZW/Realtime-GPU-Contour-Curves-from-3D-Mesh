using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Types of custom events that we can send & receive
/// in [Line-Drawing Rendering Pipeline].
/// </summary>
public enum LDEventType { 
    UpdatePerCameraData = 0,
    UpdatePerMeshBuffer = 1,
    UpdatePerMeshParams = 2,
};

/// <summary>
/// Every LDEvent instance has to be sent & received
/// with some metadata (LDEvent, LDEArgs == Metadata)
/// </summary>
public abstract class LDEArgs
{
    public LDEArgs(LDEventType typeIn){
        eventType = typeIn;
    }
    public LDEventType eventType;
}

public abstract class LDEvent<TArgs> : ScriptableObject
where TArgs : LDEArgs
{
    protected List<LDEventProcessor<TArgs>> procs;

    public virtual void Register(LDEventProcessor<TArgs> proc){
        procs.Add(proc);
    }

    public virtual void Unregister(LDEventProcessor<TArgs> proc){
        procs.Remove(proc);
    }

    public void Init(){
        procs = new List<LDEventProcessor<TArgs>>();
    }

    public void Raise(TArgs args){
        foreach (LDEventProcessor<TArgs> listener in procs){
            listener.Raise(args);
        }
    }
}

public abstract class LDEventProcessor<TArgs> : ScriptableObject
where TArgs : LDEArgs
{
    protected Action<TArgs> RegisteredActions;

    public virtual void Raise(TArgs args){
        RegisteredActions.Invoke(args);
    }
}

public sealed class UpdatePerCameraDataArgs : LDEArgs
{
    public UpdatePerCameraDataArgs(
        Camera cam,
        LDEventType type = LDEventType.UpdatePerCameraData
    ) : base(type)
    {
        if (type != LDEventType.UpdatePerCameraData){
            Debug.LogError(
                "Error: Mismatched event type."
            );
        }

        camera = cam;
    }

    public readonly Camera camera;
}