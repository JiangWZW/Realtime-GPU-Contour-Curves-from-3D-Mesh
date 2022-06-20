using System;
using System.Collections;
using System.Collections.Generic;
using MPipeline.Custom_Data.BasicDataTypes.Global_Properties;
using UnityEngine;

/// ///////////////// -------------------------------
// HLSL NAMING CONVENTION
// Resources
// | Convention: 
// | -- Data Type
// |----------+--------------+---------------+---------------------|
// | Prefix   | Data Type    | #Elem         | Meaning             |
// |----------+--------------+---------------+---------------------|
// | CBuffer  | Buffer       | /             | ComputeBuffer       |
// | CMatrix  | float4x4     | 4x4           | matrix              |
// | CVector  | float4       | 4             | color,vector        |
// | CPos/Dir | float3       | 3             | position,direction  |
// | CVal     | float/uint   | 1             | scalar              |
// | VP       | List<float4> | #Vertex       | vertex list         |
// | VN       | List<float4> | #Vertex       | vertex normal list  |
// | TV       | List<uint>   | 3 x #Triangle | Triangle index list |


// | -- Postfix
// |-----------+---------+-------------------------------|
// | Prefix    | Postfix | Meaning                       |
// |-----------+---------+-------------------------------|
// | CMatrix   | M       | Model -> World                |
// | ~         | V       | World -> View                 |
// | ~         | P       | View -> Homogenous Clip Space |
// | ~         | I_X(Y)  | Inverse Transform             |
// |-----------+---------+-------------------------------|
// | CPos/CDir | OS      | Object Space Pos/Dir          |
// | ~         | WS      | World Space Pos/Dir           |
// | ~         | VS      | View Space Pos/Dir            |
// | ~         | CS      | Homogenous Clip Space Pos/Dir |
// | ~         | TS      | Tangent Space                 |
// | ~         | TXS     | Texture Space                 |
// |           |         |                               |
/// <summary>
/// Giving names for GPU resources in hlsl code.
/// </summary>
public sealed class ObjectNaming
{
    // //////////////////////////////////////////////////////////
    #region Resource-Related Naming
    // ------------------- <C# Type, HLSL prefix> -----------
    private static readonly Dictionary<string, string> Prefix =
    new Dictionary<string, string>{
        { "ComputeBuffer", "CBuffer"},
        { "Matrix4x4",     "CMatrix"},
        { "Vector4",       "CVector"},
        { "float",         "CVal"},
        { "uint",          "CVal"},
        { "Int32",         "CVal"}
    };
    #endregion


    // //////////////////////////////////////////////////////////
    #region Space-Related Naming
    public static class Space
    {
        public static int Object = 0;
        public static int World = 1;
        public static int View = 2;
        public static int HomogenousClip = 3;
        public static int Tangent = 4;
        public static int Texture = 5;
        public static int Screen = 6;
        public static int History = 7;
        public static int Transposed = 8;
    }
    // ------------------- < <from, to>, HLSL shortcut> ---------------
    private static readonly Dictionary<Vector2Int, string> TransformPostfix =
    new Dictionary<Vector2Int, string>
    {
        { new Vector2Int(Space.Object, Space.World),         "M" },
        { new Vector2Int(Space.World, Space.View),           "V" },
        { new Vector2Int(Space.View, Space.HomogenousClip),  "P" },
        { new Vector2Int(Space.History, Space.Object),  "H" },
        { new Vector2Int(Space.Transposed, Space.Object), "T"}
    };


    // -------------- <Space Name, HLSL shortcut> ---------------
    private static readonly Dictionary<int, string> PostfixSpace =
    new Dictionary<int, string>
    {
        { Space.Object,         "OS" },
        { Space.World,          "WS" },
        { Space.View,           "VS" },
        { Space.HomogenousClip, "CS" },
        { Space.Tangent,        "TS" },
        { Space.Texture,        "TXS"},
        { Space.Screen,         "SS" }
    };
    #endregion



    // //////////////////////////////////////////////////////////
    /// <summary>
    /// Gets prefix for generic types, including:
    /// 1. ComputeBuffer
    /// 2. Matrix4x4
    /// 3. Vector4
    /// 4. float
    /// </summary>
    /// <param name="resource">
    /// The object that you want to calculate its name
    /// </param>
    /// <typeparam name="T">
    /// Type of your object
    /// </typeparam>
    /// <returns>
    /// 1. empty string "" if type not supported
    /// 2. valid prefix for resource otherwise
    /// </returns>
    public static string getPrefix<T>(T resource)
    {
        string typeName = resource.GetType().Name;
        if (!Prefix.ContainsKey(typeName))
        {
            Debug.LogError(
                "Error: Auto prefix for type of " + typeName
                + " hasn't been supported yet."
            );
            return "";
        }
        Prefix.TryGetValue(typeName, out string prefixstr);

        return prefixstr + "_";
    }
    /// <summary>
    /// Gets prefix for generic types, including:
    /// 1. ComputeBuffer
    /// 2. Matrix4x4
    /// 3. Vector4
    /// 4. float
    /// </summary>
    /// <typeparam name="T">
    /// Type of your object
    /// </typeparam>
    /// <returns>
    /// 1. empty string "" if type not supported
    /// 2. valid prefix for resource otherwise
    /// </returns>
    public static string getPrefix<T>()
    {
        string typeName = typeof(T).Name;
        if (!Prefix.ContainsKey(typeName))
        {
            Debug.LogError(
                "Error: Auto prefix for type of " + typeName
                + " hasn't been supported yet."
            );
            return "";
        }
        Prefix.TryGetValue(typeName, out string prefixstr);

        return prefixstr + "_";
    }


    public static class Matrix
    {
        public static class Usages
        {
            public const int SpaceTransform = 0;
            public const int Custom = 1;
        }
        public static class Transform
        {
            public static string GetName(int from, int to, string tag = "")
            {
                string prefix = getPrefix<Matrix4x4>();
                string postfix = GetPostfix(  // Postfix
                    from, to
                );
                if (tag == "")
                {
                    // "Prefix_" => "Prefix"
                    // "Prefix__Postfix" => "Prefix_Postfix"
                    int pos_ = prefix.LastIndexOf('_');
                    prefix = prefix.Remove(pos_);
                }
                return prefix + tag + postfix;
            }

            public static string GetName(string tag = "", params int[] spaceChain)
            {
                string prefix = getPrefix<Matrix4x4>();
                string postfix = GetPostfix(  // Postfix
                    spaceChain
                );
                if (tag == "")
                {
                    // "Prefix_" => "Prefix"
                    // "Prefix__Postfix" => "Prefix_Postfix"
                    int pos_ = prefix.LastIndexOf('_');
                    prefix = prefix.Remove(pos_);
                }
                return prefix + tag + postfix;
            }

            private static string GetPostfix(int from, int to)
            {
                _GetPostfix(from, to, out string postfix);
                return "_" + postfix;
            }

            private static string GetPostfix(params int[] spaceChain)
            {
                _GetPostfix(spaceChain, out string postfix);
                return "_" + postfix;
            }

            private static bool _GetPostfix(
                int[] spaceChain,
                out string postfixComposite
            )
            {
                // Inversion flags
                bool isInvPrev = false;
                bool isInv = false; // inversion flag of single transform

                int from = 0, to = 0;
                postfixComposite = "";
                string postfixSingle;
                for (int i = 0; i < spaceChain.Length - 1; ++i)
                {
                    from = spaceChain[i];
                    to = spaceChain[i + 1];

                    isInvPrev = isInv;
                    isInv = !(_GetPostfix(from, to, out postfixSingle));
                    // Check coherence of compositing direction 
                    if (i > 0 && isInvPrev != isInv)
                    {
                        Debug.LogError(
                            "Error: Incorrect transform chain: \n" +
                            "We only support transform composited in one single direction."
                        );
                        break;
                    }

                    if (isInv)
                    {
                        // Remove "I_" prefix, we'll add it later
                        int invIndex = postfixSingle.IndexOf("I_");
                        postfixSingle = postfixSingle.Remove(invIndex, 2);
                    }
                    postfixComposite += postfixSingle;
                }

                if (isInv)
                {
                    // Reverse postfix composition order: eg. PV => VP
                    postfixComposite = Reverse(postfixComposite);
                    // Add 'I_' tag: eg. VP => I_VP
                    postfixComposite = _InvertTransformOf(postfixComposite);
                }

                return isInv;
            }

            private static bool _GetPostfix(
                int from, int to,
                out string postfix
            )
            {
                Vector2Int key = new Vector2Int(from, to);
                if (TransformPostfix.ContainsKey(key))
                {
                    // -- 1 --
                    // Check if is a supported transform
                    TransformPostfix.TryGetValue(key, out postfix);
                    return true;
                }
                else
                {
                    // -- 2 --
                    // Check if its inverse transform is supported,
                    // for instance, I_M, I_V, I_P, etc.
                    Vector2Int keyInv = new Vector2Int(to, from);
                    if (TransformPostfix.ContainsKey(keyInv))
                    {
                        TransformPostfix.TryGetValue(keyInv, out postfix);
                        postfix = _InvertTransformOf(postfix);
                        return false;

                    }
                    else
                    { // -- 3 --
                      // Neither forward / inverse transforms is supported.
                      // Report as an error & return empty string.
                        Debug.LogError(
                           "Error: Auto postfix for transform of \n" +
                           from + " to " + to +
                           " hasn't been supported yet.\n"
                        );
                        postfix = "";
                    }
                }
                return true;
            }

            private static string Reverse(string str)
            {
                if (str == null) return null;

                // this was posted by petebob as well 
                char[] array = str.ToCharArray();
                Array.Reverse(array);
                return new String(array);
            }

            private static string _InvertTransformOf(string postfix)
            {
                return "I_" + postfix;
            }
        }
    }

    public static class Vector
    {
        public static class Usages
        {
            public static int Position = 0;
            public static int Direction = 1;
            public static int Normal = 2;
            public static int Tangent = 3;
            public static int Custom = 4;
        }

        private static Dictionary<int, string> TagForUsage =
            new Dictionary<int, string>{
                { Usages.Position, "Pos" },
                { Usages.Direction, "Dir" },
                { Usages.Normal, "N" },
                { Usages.Tangent, "T" },
                { Usages.Custom, "" }
        };

        public static string GetVectorName(PropDescriptor desc)
        {
            // Example: GetVectorName(1, 0, "Light")
            // return "CVector_LightDir_WS"
            // ---------------------------------
            // Default Setup
            string prefix = getPrefix<Vector4>();
            string name = desc.Tag;
            string postfix = "";

            // ---------------------------------
            // Specialized tokens
            if (desc.Space != -1)
            {
                // Generate postfix by which Space
                // this vector is in
                postfix = GetVectorPostfix(desc.Space);
            }
            if (desc.Usage != Usages.Custom)
            {
                // Commonly-used vectors, e.g, 
                // Normal, Position, etc.
                name = name + GetVectorUsageTag(desc.Usage);
            }

            // String Composition
            return prefix + name + postfix;
        }

        private static string GetVectorUsageTag(int usage)
        {
            return _GetVectorUsageTag(usage);
        }

        private static string _GetVectorUsageTag(int usage)
        {
            if (!TagForUsage.TryGetValue(usage, out string tag))
            {
                Debug.LogError(
                    "Error: Cannot find vector usage '" +
                    usage + " in ObjectorNaming.Vector.CommonVectorBook."
                );
                return "";
            }
            return tag;
        }

        private static string GetVectorPostfix(int space)
        {
            return "_" + _GetVectorPostfix(space);
        }

        private static string _GetVectorPostfix(int space)
        {
            if (!PostfixSpace.ContainsKey(space))
            {
                Debug.LogError(
                    "Error: Auto postfix for space \n" +
                    space +
                    "hasn't been supported yet.\n"
                );
                return "";
            }
            PostfixSpace.TryGetValue(space, out string postfix);

            return postfix;
        }
    }

    public static class Scalar
    {
        public static class Usage
        {
            public static int Count = 0;
            public static int Counter = 1;
            public static int Index = 2;
            public static int Custom = 3;
        }

        private static readonly Dictionary<int, string> TagForUsage =
            new Dictionary<int, string>
            {
                { Usage.Count,      "Count" },
                { Usage.Counter,    "Counter" },
                { Usage.Index,      "ID" },
                { Usage.Custom,     "" }
            };

        /// <summary>
        /// Returns a HLSL name for a scalar variable.
        /// </summary>
        /// <param name="usage">See ObjectNaming.Scalar.Usages</param>
        /// <param name="tag">User defined name that describes this property.</param>
        /// <typeparam name="T"></typeparam>
        /// <returns>The name to match in hlsl code.</returns>
        public static string GetScalarName<T>(PropDescriptor propDesc)
        {
            string prefix = getPrefix<T>();
            string name = propDesc.Tag;
            string postfix = "";

            int usage = propDesc.Usage;
            if (usage != Usage.Custom)
            { // Append pre-defined tags
                postfix += "_";
                postfix += GetScalarUsageTag(usage);
            }

            return prefix + name + postfix;
        }

        private static string GetScalarUsageTag(int usage)
        {
            return _GetScalarUsageTag(usage);
        }

        private static string _GetScalarUsageTag(int usage)
        {
            if (!TagForUsage.TryGetValue(usage, out string tag))
            {
                Debug.LogError(
                    "Error: cannot find usage of " + usage +
                    " in current ScalarBook."
                );
                return "";
            }
            return tag;
        }
    }


    public static string getBufferHlslName(string bufferTag)
    {
        string hlslName = /* Prefix(CBuffer_) + bufferTag */
            ObjectNaming.getPrefix<ComputeBuffer>() +
            bufferTag;
        return hlslName;
    }

    public static string GetBufferDebugName(
        string bufferTag, GameObject gameObject)
    {
        string debugName = /* hlslName + "_" + gameObject Name */
            getBufferHlslName(bufferTag) + "_" + gameObject.name;
        return debugName;
    }
}
