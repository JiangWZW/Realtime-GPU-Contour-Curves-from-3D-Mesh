//  Copyright (c) 2017 amlovey
//  
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEditor.Callbacks;
using System.Linq;
using UnityEditorInternal;
using System;
using System.Text.RegularExpressions;
using System.Net;
using System.Text;

namespace ShaderlabVSCode
{
    public class DataPair
    {
        public string Uri1;
        public string Uri2;
    }

    public class ShaderlabVSCodeEditor : EditorWindow
    {
        [MenuItem("Tools/ShaderlabVSCode/Download Visual Studio Code", false, 11)]
        public static void DownloadVSCode()
        {
            Application.OpenURL("https://code.visualstudio.com/Download");
        }

        [MenuItem("Tools/ShaderlabVSCode/Online Documentation", false, 33)]
        public static void OpenOnlineDocumentation()
        {
            Application.OpenURL("http://www.amlovey.com/shaderlabvscode/index/");
        }

        [MenuItem("Tools/ShaderlabVSCode/Open An Issue", false, 33)]
        public static void OpenIssue()
        {
            Application.OpenURL("https://github.com/amloveyweb/amloveyweb.github.io/issues");
        }

        [MenuItem("Tools/ShaderlabVSCode/Star And Review", false, 33)]
        public static void StarAndReview()
        {
            UnityEditorInternal.AssetStore.Open("content/94653");
        }

        private static string GetVSXIPath()
        {
            string assetsFolderPath = Application.dataPath;
            string vsxiPath = Path.Combine(assetsFolderPath, "ShaderlabVSCode/VSCodePlugin/shaderlabvscode.vsix");

#if UNITY_EDITOR_WIN
            return vsxiPath.Replace("/", @"\");
#else
            return vsxiPath;
#endif
        }

        #region Use VSCode to open files
        [OnOpenAssetAttribute(1)]
        public static bool step1(int instanceID, int line)
        {
            return false;
        }

        static string[] SHADER_FILE_EXTENSIONS = new string[] {
            ".shader",
            ".compute",
            ".cginc",
            ".glslinc"
        };

        [OnOpenAssetAttribute(2)]
        public static bool step2(int instanceID, int line)
        {
            string path = AssetDatabase.GetAssetPath(EditorUtility.InstanceIDToObject(instanceID));
            path = Path.Combine(Path.Combine(Application.dataPath, ".."), path);

            if (SHADER_FILE_EXTENSIONS.Any(extension => path.Trim().ToLower().EndsWith(extension)))
            {
                if (VSCodeBridge.IsVSCodeExists())
                {
                    VSCodeBridge.CallVSCodeWithArgs(string.Format("\"{0}\"", path));
                }
                else
                {
                    InternalEditorUtility.OpenFileAtLineExternal(path, 0);
                }
                return true;
            }

            return false;
        }

        [MenuItem("Tools/ShaderlabVSCode/Update Data of VSCode Extension", false, 22)]
        public static void UpdateData()
        {
            bool updated = false;
            
            try
            {
                var extensionsFolder = GetExtensionPath();
                if (string.IsNullOrEmpty(extensionsFolder))
                {
                    EditorUtility.DisplayDialog("Not Found", "Seems like there are no ShaderlabVSCode extension installed.", "OK");
                    return;
                }

                string title = "Updating Data of ShaderlabVSCode Extension";
                EditorUtility.DisplayProgressBar(title, title, 0);
                int count = 0;
                
                foreach (var pair in DATA_PAIRS)
                {
                    EditorUtility.DisplayProgressBar(title, title, (count + 1) * 1.0f / DATA_PAIRS.Count);
                    var webContent = GetContentFromWeb(pair.Uri1);
                    var localPath = Path.Combine(extensionsFolder, pair.Uri2);
                    var localContent = File.ReadAllText(localPath);

                    int v1 = GetVersionId(webContent);
                    int v2 = GetVersionId(localContent);

                    if (v1 > v2)
                    {
                        File.WriteAllText(localPath, webContent);
                        updated = true;
                    }
                    count ++;
                }
            }
            catch (System.Exception)
            {
               
            }

            EditorUtility.ClearProgressBar();

            if (updated)
            {
                EditorUtility.DisplayDialog("Done", "Completed! The new data will take effect after reload VSCode window.", "OK");
            }
            else
            {
                EditorUtility.DisplayDialog("Done", "Data is already up to date!", "OK");
            }
        }

        private static string GetContentFromWeb(string url)
        {
            WebClient client = new WebClient();
            var bytes = client.DownloadData(url);
            return Encoding.UTF8.GetString(bytes);
        }

        private static int GetVersionId(string code)
        {
            string pattern = "\"[Vv]ersion\"\\s*?:\\s*?(?<VER>\\d+?)\\s*?,";
            var match = Regex.Match(code, pattern);
            if (match != null)
            {
                var version = match.Groups["VER"].Value;
                if (!string.IsNullOrEmpty(version))
                {
                    return int.Parse(version);
                }
            }

            return -1;
        }

        private static List<DataPair> DATA_PAIRS = new List<DataPair>()
        {
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/functions.json", Uri2 = "out/src/data/functions.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/intellisense.json", Uri2 = "out/src/data/intellisense.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/keywords.json", Uri2 = "out/src/data/keywords.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/values.json", Uri2 = "out/src/data/values.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/shaderlab.json", Uri2 = "snippets/shaderlab.json" },
        };

        private static string GetExtensionPath()
        {
            string path;
#if UNITY_EDITOR_WIN
            path = Environment.ExpandEnvironmentVariables(@"%USERPROFILE%\.vscode\extensions");
#else
            path = Environment.GetFolderPath(Environment.SpecialFolder.Personal) + "/.vscode/extensions";
#endif

            if (Directory.Exists(path))
            {
                var subDirs = Directory.GetDirectories(path);
                foreach (var item in subDirs)
                {
                    if (item.ToLower().Contains("amlovey.shaderlabvscode") 
                        && !item.ToLower().Contains("shaderlabvscodefree"))
                    {
                        return item;
                    }
                }
            }

            return null;
        }
    }
    #endregion
}
