using UnityEngine;

[RequireComponent(typeof(Camera))]
public class PostProcessBase : MonoBehaviour
{
    protected Material CreateMaterial(Shader shader, Material material) {
        if (shader == null) {
            return null;
        }
		
        switch (shader.isSupported)
        {
            case true when material && material.shader == shader:
                return material;
            case false:
                return null;
            default:
                material = new Material(shader);
                material.hideFlags = HideFlags.DontSave;
                return material ? material : null;
        }
    } 

}