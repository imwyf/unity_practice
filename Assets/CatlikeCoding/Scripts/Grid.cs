using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class Grid : MonoBehaviour
{
    private Vector3[] vertices;
    private Mesh mesh; // mesh不作为一个组件单独存在，得new出来或者从文件读取
    public int xSize, ySize;
    private void Awake()
    {
        StartCoroutine(Generate());
    }

    private IEnumerator Generate()
    {
        WaitForSeconds wait = new WaitForSeconds(0.05f);

        GetComponent<MeshFilter>().mesh = mesh = new Mesh();
        mesh.name = "Procedural Grid";

        vertices = new Vector3[(xSize + 1) * (ySize + 1)];
        Vector2[] uv = new Vector2[vertices.Length]; // 一个数组，每个元素是顶点的UV坐标
        for (int i = 0, y = 0; y <= ySize; y++)
        {
            for (int x = 0; x <= xSize; x++, i++)
            {
                vertices[i] = new Vector3(x, y); // 设置顶点坐标
                uv[i] = new Vector2((float)x / xSize, (float)y / ySize); // UV映射

            }
        }
        mesh.vertices = vertices; // mesh.vertices存放顶点位置
        mesh.uv = uv;// mesh.uv存放顶点UV坐标

        int[] triangles = new int[xSize * ySize * 6];
        for (int ti = 0, vi = 0, y = 0; y < ySize; y++, vi++)
            for (int x = 0; x < xSize; x++, ti += 6, vi++)
            {
                triangles[ti] = vi;
                triangles[ti + 3] = triangles[ti + 2] = vi + 1;
                triangles[ti + 4] = triangles[ti + 1] = vi + xSize + 1;
                triangles[ti + 5] = vi + xSize + 2;
                mesh.triangles = triangles; // mesh.triangles给他一个int[]的参数，每3个元素作为索引（这个索引用来访问mesh.vertices）组成一个三角形，三角形的着色遵循左手定则，手指顺时针弯曲，大拇指指向的方向那一面被着色
                mesh.RecalculateNormals(); // 
                yield return wait;
            }

    }
    private void OnDrawGizmos()
    {
        Gizmos.color = Color.black;
        if (vertices == null) return;
        for (int i = 0; i < vertices.Length; i++)
        {
            Gizmos.DrawSphere(vertices[i], 0.1f);
        }
    }
}
