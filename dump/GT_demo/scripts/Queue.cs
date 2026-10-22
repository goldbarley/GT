/* NOT IN USE
 * API design for all classes in this file SHOULD BE IDENTICAL!
 *
 * Designs can be changed by renaming FIFOQueue to Buffer and
 * accepting data structure bits or types.
 *
 * If not, Mailbox can be implemented separately if required.
 */

using System.Runtime.CompilerServices;

public class FIFOQueue<T>
{
    private int _capacity;
    private readonly T _defaultT;

    private class _FIFOQueueData
    {
        public T[] queue;
        public int head;
        public int tail;
        public int size;

        public _FIFOQueueData(int capacity)
        {
            this.queue = new T[capacity];
            this.head = 0;
            this.tail = 0;
            this.size = 0;
        }
    }

    private _FIFOQueueData _queue;

    public FIFOQueue(int capacity, T defaultT)
    {
        this._capacity = capacity;
        this._defaultT = defaultT;

        _queue = new _FIFOQueueData(capacity);
    }

    public FIFOQueue(T defaultT)
    {
        this._capacity = 64;
        this._defaultT = defaultT;

        _queue = new _FIFOQueueData(this._capacity);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool CanMoveHead(int n)
    {
        return (this._queue.head + n) % this._capacity == this._queue.tail;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool TryMoveHead(int n)
    {
        bool b = true;
        if ((b = CanMoveHead(n)))
            this._queue.head = (this._queue.head + n) % this._capacity;

        return b;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool CanMoveTail(int n)
    {
        return (this._queue.tail + n) % this._capacity == this._queue.head;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool TryMoveTail(int n)
    {
        bool b = true;
        if ((b = CanMoveTail(n)))
            this._queue.tail = (this._queue.tail + n) % this._capacity;

        return b;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool CanAddToSize(int n)
    {
        return this._queue.size + n <= this._capacity;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private bool TryAddToSize(int n)
    {
        bool b = true;
        if ((b = CanAddToSize(n)))
            this._queue.size += n;

        return b;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool IsFull()
    {
        return this._queue.size == this._capacity;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool IsEmpty()
    {
        return this._queue.size == 0;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public int Size()
    {
        return this._queue.size;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Realloc(int n)
    {
        System.Array.Resize(ref this._queue.queue, n);
        this._capacity = n;
    }

    public int GetAllocSize(int n)
    {
        return this._capacity;
    }

    /*
     * Submit uses busy waiting. This can be swapped out for
     * a condition variable and putting the thread to sleep.
     *
     * Until then use TrySubmit.
     */
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Submit(T data)
    {
        while (!this.IsFull())
            ;

        this._queue.queue[this._queue.head] = data;
        TryAddToSize(1);
        TryMoveHead(1);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool TrySubmit(T data)
    {
        if (this.IsFull())
            return false;

        this._queue.queue[this._queue.head] = data;
        TryAddToSize(1);
        TryMoveHead(1);

        return true;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool Remove(out T data)
    {
        if (this.IsEmpty())
        {
            data = this._defaultT;
            return false;
        }

        data = this._queue.queue[this._queue.tail];
        TryAddToSize(-1);
        TryMoveTail(1);

        return true;
    }

    public void ShrinkToFit()
    {
        this.Realloc(this.Size());
    }

    public void Extract(out T[] data)
    {
        int head = this._queue.head;
        int tail = this._queue.tail;
        int size = this._queue.size;

        data = new T[size];

        for (int i = tail, j = 0; i != head && j < size; ++j)
        {
            i = (i + 1) % this._capacity;
            data[j] = this._queue.queue[i];
        }
    }
}

/* Implement later if needed. */
public class Mailbox<T>
{
    /* Capacity is always one for a mailbox. Do not change! */
    private const int _Capacity = 1;
}
