using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleGizmo : MonoBehaviour
{
    private void OnDrawGizmos()
    {
        Gizmos.DrawIcon(transform.position, "Profiler.Rendering");
    }
}
