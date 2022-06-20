using System.Runtime.CompilerServices;
using Sirenix.OdinInspector;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Assets.MPipeline.Custom_Data.TextureCurve
{
    [CreateAssetMenu(fileName = "CurveTexture.asset", menuName = "LDPipeline Data/Texture/Curve", order = 0)]
    public class MyTextureCurve : ScriptableObject
    {
        [SerializeField] private AnimationCurve _curve = 
            AnimationCurve.Linear(0, 0, 1, 1);

        [SerializeField] private Texture2D _texture;
        public int shaderPropertyID = -1;
        public static implicit operator RenderTargetIdentifier(MyTextureCurve src)
        {
            return src._texture;
        }
        public static implicit operator Texture2D(MyTextureCurve src)
        {
            return src._texture;
        }

        [SerializeField] int _resolution = 512;
        public int Resolution => _resolution;

        [SerializeField] TextureWrapMode _wrapMode = TextureWrapMode.Clamp;
        [SerializeField] FilterMode _filterMode = FilterMode.Bilinear;


        private bool _isTextureDirty;


        public static void SetupTextureCurve(
            string defaultPath, 
            string shaderPropName, 
            ref MyTextureCurve myTextureCurve
        ) {
            myTextureCurve =
                myTextureCurve != null
                    ? myTextureCurve
                    : UnityEngine.Resources.Load<MyTextureCurve>(defaultPath);
            myTextureCurve.SetShaderPropertyID(shaderPropName);
            myTextureCurve.ReBakeCurveTexture();
        }


        public void OnEnable()
        {
            if (_texture == null)
            {
                _texture = new Texture2D(_resolution, 1, TextureFormat.RFloat, false, true);
            }
            _isTextureDirty = true;
        }

        public void SetShaderPropertyID(string propName)
        {
            shaderPropertyID = Shader.PropertyToID(propName);
        }

        /// <summary>
        /// Marks the curve as dirty to trigger a redraw of the texture the next time
        /// is called.
        /// </summary>
        [Button(ButtonSizes.Medium)]
        public new void SetDirty()
        {
            _isTextureDirty = true;
        }

        [Button(ButtonSizes.Medium)]
        public void Bake()
        {
            if (_texture == null)
                _texture = new Texture2D(_resolution, 1, TextureFormat.RFloat, false, true);

            if (_isTextureDirty)
            {
                if (_texture.width != _resolution) // Change res dynamically
                    _texture.Reinitialize(_resolution, 1);

                _texture.wrapMode = _wrapMode;
                _texture.filterMode = _filterMode;

                Color[] colors = new Color[_resolution];
                for (int i = 0; i < _resolution; ++i)
                {
                    var t = (float)i / _resolution;

                    colors[i].r = _curve.Evaluate(t);
                }

                _texture.SetPixels(colors);
                _texture.Apply(false);

                _isTextureDirty = false;
            }
        }
        
        public void ReBakeCurveTexture()
        {
            Bake();
            SetDirty();
        }
    }
}
