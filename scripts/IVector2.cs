using System;
using System.Runtime.CompilerServices;

public enum Axis2 : uint
{
    UNKOWN = 0x00000000,
    PX = 0x00000001,
    PY = 0x00000002,
    NX = 0x00000004,
    NY = 0x00000008,
    PXPY = 0x00000003,
    NXPY = 0x00000006,
    PXNY = 0x00000009,
    NXNY = 0x0000000C,
};

public struct IVector2
{
    public int x;
    public int y;

    public IVector2(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    public IVector2(IVector2 v)
    {
        this.x = v.x;
        this.y = v.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Set(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Scale(int s)
    {
        this.x *= s;
        this.y *= s;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void ScaleOnAxis(uint a, IVector2 s)
    {
        if ((a & Axis2.PX) != 0)
            this.x *= s.x;

        if ((a & Axis2.NX) != 0)
            this.x *= -s.x;

        if ((a & Axis2.PY) != 0)
            this.y *= s.y;

        if ((a & Axis2.NY) != 0)
            this.y *= -s.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void NegateX(int x)
    {
        this.x = -this.x;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void NegateY(int y)
    {
        this.y = -this.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Negate()
    {
        this.x = -this.x;
        this.y = -this.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Add(IVector2 v)
    {
        this.x += v.x;
        this.y += v.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Subtract(IVector2 v)
    {
        this.x -= v.x;
        this.y -= v.y;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void RotateAcl(float angle)
    {
        float s = MathF.Sin(angle);
        float c = MathF.Cos(angle);

        int ogx = this.x;
        int ogy = this.y;

        this.x = (int)MathF.Round(ogx * c - ogy * s);
        this.y = (int)MathF.Round(ogx * s + ogy * c);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void RotateCl(float angle)
    {
        RotateAcl(-angle);
    }
}
