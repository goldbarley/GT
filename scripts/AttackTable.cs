public enum MoveType
{
    NOTHING = 0,
    ATTACK = 1,
    DEFENSE = 2,
}

/*
 * Covers number of tiles.
 * *_AREA attacks are always square.
 */
public enum AttackRange
{
    ATTACK_UNKNOWN = -1,
    MAGE_ATTACK_SINGLE = 5,
    MAGE_ATTACK_DIAGONAL_QUAD = 4,
    MAGE_ATTACK_AOE = 7,
    MAGE_ATTACK_AOE_AREA = 9, /* 3x3 */
    MAGE_ATTACK_PILLAR_AREA = 1, /* 1x1 */
}

//Updated comment.
/* Duration is measured in steps */
public enum DefenseRoundCooldown
{
    DEFENSE_UNKNOWN = -1,
    MAGE_DEFENSE_INVINCIBILITY = 4,
    MAGE_DEFENSE_BARRIER = 2,
    MAGE_DEFENSE_TELEPORT = 3,
}

public class Attack
{
    public MoveType type;
    public AttackRange range;
    public DefenseRoundCooldown cooldown;
}

/*
 * May be a lot of errors here.
 * Tread carefully. Queue is untested.
 * Math may be wrong, so do a dry run.
 *
 * :(	<- Change this to a happy face when queue is functional.
 */
public class AttackQueue
{
    /*
     * Do not change or it will fuck the math up.
     * If change is required, keep it a power of 2.
     */
    private const int _queueCapacity = 32;

    private class _AttackQueueData
    {
        //Fixed Array Initlialization. This aint C dawg.
        public Attack[] queue = new Attack[_queueCapacity];
        public int head = 0;
        public int tail = 0;
        public int size = 0;

        public _AttackQueueData()
        {
            this.head = 0;
            this.tail = 0;
            this.size = 0;

            for (int i = 0; i < _queueCapacity; ++i)
            {
                //Forgot to initlialize the Attack objects in the queue array. This will cause a null reference exception when trying to access them.
                queue[i] = new Attack();
                queue[i].type = MoveType.NOTHING;
                queue[i].range = AttackRange.ATTACK_UNKNOWN;
                //Accidently tried to update the same field twice.
                queue[i].cooldown = DefenseRoundCooldown.DEFENSE_UNKNOWN;
            }
        }
    }

    private _AttackQueueData _mainQueue;
    private _AttackQueueData _waitingQueue;

    public AttackQueue()
    {
        _mainQueue = new _AttackQueueData();
        _waitingQueue = new _AttackQueueData();
    }

    public bool IsFull()
    {
        return this._mainQueue.size == _queueCapacity;
    }

    public bool IsFullWaiting()
    {
        return this._waitingQueue.size == _queueCapacity;
    }

    public bool IsEmpty()
    {
        return this._mainQueue.size == 0;
    }

    public bool IsEmptyWaiting()
    {
        return this._waitingQueue.size == 0;
    }

    public int Remaining()
    {
        //Static variables cannot be directly accessed in non static instances. Since I assume 2 queues can exist at once, I am gonna update references instead of making all methods static.
        return AttackQueue._queueCapacity - this._mainQueue.size;
    }

    public int RemainingWaiting()
    {
        return AttackQueue._queueCapacity - this._waitingQueue.size;
    }

    /* Returns TRUE if queue is full */
    private bool TryMoveHead(int n)
    {
        //Idk how its supposed to work. I just fixed the brackets in a way that fixed the error.
        return ((this._mainQueue.head + n) & (_queueCapacity - 1)) == this._mainQueue.tail;
    }

    private bool MoveHead(int n)
    {
        this._mainQueue.head = (this._mainQueue.head + n) & (_queueCapacity - 1);
        return this._mainQueue.head != this._mainQueue.tail;
    }

    private bool TryMoveHeadWaiting(int n)
    {
        return ((this._waitingQueue.head + n) & (_queueCapacity - 1)) == this._waitingQueue.tail;
    }

    private bool MoveHeadWaiting(int n)
    {
        this._waitingQueue.head = (this._waitingQueue.head + n) & (_queueCapacity - 1);
        return this._waitingQueue.head != this._waitingQueue.tail;
    }

    /* Returns FALSE if queue is empty */
    private bool TryMoveTail(int n)
    {
        return ((this._mainQueue.tail + 1) & (_queueCapacity - 1)) == this._mainQueue.head;
    }

    private bool MoveTail(int n)
    {
        this._mainQueue.tail = (this._mainQueue.head + 1) & (_queueCapacity - 1);
        return this._mainQueue.head != this._mainQueue.tail;
    }

    private bool TryMoveTailWaiting(int n)
    {
        return ((this._waitingQueue.tail + 1) & (_queueCapacity - 1)) == this._waitingQueue.head;
    }

    private bool MoveTailWaiting(int n)
    {
        this._waitingQueue.tail = (this._waitingQueue.head + 1) & (_queueCapacity - 1);
        return this._waitingQueue.head != this._waitingQueue.tail;
    }

    private bool TryAddToSize(int n)
    {
        if (this._mainQueue.size + n == _queueCapacity)
            return false;

        return true;
    }

    private bool AddToSize(int n)
    {
        bool r = true;
        //Replaced capacity with the variabe that made the most sesne.
        if ((r = !TryAddToSize(n)))
        {
            this._mainQueue.size = _queueCapacity;
            return r;
        }
        this._mainQueue.size += n;
        return r;
    }

    private bool TryAddToSizeWaiting(int n)
    {
        //Not a error here, but I think >= would be better than ==. I think the queue is supposed to be full when the size is equal to the capacity, not when it is greater than or equal to the capacity.
        if (this._waitingQueue.size + n >= _queueCapacity)
            return false;

        return true;
    }

    private bool AddToSizeWaiting(int n)
    {
        bool r = true;
        if ((r = !TryAddToSizeWaiting(n)))
        {
            this._waitingQueue.size = _queueCapacity;
            return r;
        }
        this._waitingQueue.size += n;
        return r;
    }

    /* Waiting queue does not have non-blocking enqueue */
    private bool SubmitWaiting(in Attack a)
    {
        if (this.IsFullWaiting())
            return false;

        this._waitingQueue.queue[_waitingQueue.head] = a;
        MoveHeadWaiting(1);
        //I think its supposed to be waiting here instead of standard like earlier.
        AddToSizeWaiting(1);

        return true;
    }

    private void RemoveWaiting()
    {
        MoveTailWaiting(1);
        AddToSizeWaiting(-1);
    }

    /*
     * All *NB functions are non-blocking.
     * All non-*NB functions are blocking.
     *
     * TODO: Optimize *Batch* functions if possible.
     */
    public void SubmitNB(in Attack a)
    {
        if (this.IsFull())
            IncrementTail();
        this._mainQueue.queue[_mainQueue.head] = a;
        MoveHead(1);

        AddToSize(1);
    }

    public bool SubmitBatchNB(in Attack[] a, int count)
    {
        int rem = count;
        bool nofit = false;
        if ((nofit = !TryMoveHead(count)))
            rem = Remaining();

        int i = 0;
        for (; i < rem; ++i)
            this.SubmitNB(a[i]);

        //r had  no default value, so I initialized it to true. It will be set to false if any of the SubmitWaiting calls return false.
        bool r = true;
        if (nofit)
        {
            rem = count - rem;
            for (; i < rem; ++i)
            {
                r = this.SubmitWaiting(a[i]);
                if (r == false)
                    break;
            }
        }

        return r;
    }

    public bool Submit(in Attack a)
    {
        if (this.IsFull())
            return SubmitWaiting(a);

        this._mainQueue.queue[_mainQueue.head] = a;
        MoveHead(1);

        AddToSize(1);

        return true;
    }

    public bool SubmitBatch(in Attack[] a, int count)
    {
        int rem = count;
        bool nofit = false;
        if ((nofit = !TryMoveHead(count)))
            rem = Remaining();

        int i = 0;
        for (; i < rem; ++i)
            this.Submit(a[i]);

        bool r = true;
        if (nofit)
        {
            rem = count - rem;
            for (; i < rem; ++i)
            {
                r = this.SubmitWaiting(a[i]);
                if (!r)
                    break;
            }
        }

        return r;
    }

    public bool FlushWaiting()
    {
        if (this._waitingQueue.size == 0)
            return true;

        for (int i = 0; i < this._waitingQueue.size; i++)
        {
            this.SubmitNB(this._waitingQueue.queue[this._waitingQueue.head]);
            MoveHeadWaiting(1);
        }

        this._waitingQueue.size = 0;
        return true;
    }

    public void Remove()
    {
        MoveTail(1);
        AddToSize(-1);
    }

    public int Size()
    {
        return this._mainQueue.size;
    }

    public int SizeWaiting()
    {
        return this._waitingQueue.size;
    }
}

/*
 * Functions should pull from the attack queue.
 * That has not been implemented yet.
 *
 * DO NOT modify this class.
 * This is completely broken but I have things planned.
 * Ask me (Nilabhro) before modifying.
 */
public static class AttackTable
{
    public delegate int[,] Attack(int x, int y, int map);

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static void GetMageAttackSingle(int x, int y, float angle, out IVector2 dst)
    {
        const int range = 5;
        dst.Set(x, y);
        dst.RotateAcl(angle).Scale(range);
    }

    public static MapElement[,] UpdateMageAttackSingle(int x, int y, float angle, int map)
    {
        if (!MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        /* Number of tiles. */
        const int range = 5;

        IVector2 dst = new IVector2(x, y);
        dst.RotateAcl(angle).Scale(range);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        exit:
        return MapTable.GetMap(map);
    }

    public static MapElement[,] UpdateMageAttackMultiple(int x, int y, float angle, int map)
    {
        const int natk = 3;

        if (MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        const int range = 4;

        IVector2 dst = new IVector2(x, y);

        dst.RotateAcl(angle).Scale(range);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        /* 30 degrees */
        dst.RotateAcl(0.5235987755982988);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        /* 60 degrees */
        dst.RotateCl(1.0471975511965976);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        exit:
        return MapTable.GetMap(map);
    }
}
