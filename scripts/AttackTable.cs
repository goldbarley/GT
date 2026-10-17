using System.Collections.Generic;
using System;

using MoveType = int;

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

/* Duration is measured in seconds */
public enum DefenseDuration
{
	DEFENSE_UNKNOWN = -1,
	MAGE_DEFENSE_INVINCIBILITY = 2,
	MAGE_DEFENSE_BARRIER = 3,
	MAGE_DEFENSE_TELEPORT = 0
}

public class Attack
{
	/*
	 * 0 - Attack
	 * 1 - Defense
	 *
	 * 'type' is not boolean (but an int).
	 * This is if we ever want to add more move sets.
	 */
	MoveType type;
	AttackRange range;
	DefenseDuration duration;
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
		public Attack[_queueCapacity] queue;
		public int head = 0;
		public int tail = 0;
		public int size = 0;
	}

	private _AttackQueueData _mainQueue;
	private _AttackQueueData _waitingQueue;

	public bool IsFull()
	{
		return (this._mainQueue.head + 1) % (_queueCapacity - 1)
			== this._mainQueue.tail;
	}

	public bool IsFullWaiting()
	{
		return (this._waitingQueue.tail + 1) % this.SizeWaiting()
			== this.__waitingQueuetail.tail;
	}

	public bool IsEmpty()
	{
		return this._mainQueue.head == this._mainQueue.tail;
	}

	public bool IsEmptyWaiting()
	{
		return this._waitingQueue.head == this._waitingQueue.tail;
	}

	public int Remaining()
	{
		return this._queueCapacity - this._mainQueue.size;
	}

	public int RemainingWaiting()
	{
		return this._queueCapacity - this._waitingQueue.size;
	}

	/* Returns TRUE if queue is full */
	private bool TryMoveHead(int n)
	{
		return (this._mainQueue.head + n) % (_queueCapacity - 1)
		== this._mainQueue.tail;
	}

	private bool MoveHead(int n)
	{
		this._mainQueue.head = (this._mainQueue.head + n) % (_queueCapacity - 1);
		return this._mainQueue.head != this._mainQueue.tail;
	}

	private bool TryMoveHeadWaiting(int n)
	{
		return (this._waitingQueue.head + n) % (_queueCapacity - 1)
			== this._waitingQueue.tail;
	}

	private bool MoveHeadWaiting(int n)
	{
		this._waitingQueue.head = (this._waitingQueue.head + n) % (_queueCapacity - 1);
		return this._waitingQueue.head != this._waitingQueue.tail;
	}

	/* Returns FALSE if queue is empty */
	private bool TryMoveTail(int n)
	{
		return (this._mainQueue.tail + 1) % (_queueCapacity - 1)
			== this._mainQueue.head;
	}

	private bool MoveTail(int n)
	{
		this._mainQueue.tail = (this._mainQueue.head + 1) % (_queueCapacity - 1);
		return this._mainQueue.head != this._mainQueue.tail;
	}

	private bool TryMoveTailWaiting(int n)
	{
		return (this._waitingQueue.tail + 1) % (_queueCapacity - 1)
		== this._waitingQueue.head;
	}

	private bool MoveTailWaiting(int n)
	{
		this._waitingQueue.tail = (this._waitingQueue.head + 1) % (_queueCapacity - 1);
		return this._waitingQueue.head != this._waitingQueue.tail;
	}

	/* Waiting queue does not have non-blocking enqueue */
	private bool SubmitWaiting(in Attack a)
	{
		if (this.IsFullWaiting())
			return false;

		this._waitingQueue.queue[_waitingQueue.head] = a;
		MoveHeadWaiting(1);
		++this._waitingQueue.size;

		return true;
	}

	private void RemoveWaiting()
	{
		MoveTailWaiting(1);
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

		if (this._mainQueue.size + 1 == _queueCapacity)
			this._mainQueue.size = _queueCapacity;
		else
			++this._mainQueue.size;
	}

	public bool SubmitBatchNB(in Attack[] a, int count)
	{
		int rem = count;
		bool nofit;
		if ((nofit = !TryMoveHead(count)))
			rem = Remaining();

		int i = 0;
		for (; i < rem; ++i)
			this.SubmitNB(a[i]);

		bool r;
		if (nofit)
		{
			rem = count - rem;
			for (; i < rem; ++i)
				r = this.SubmitWaiting(a[i]);
		}

		return r;
	}

	public bool Submit(in Attack a)
	{
		if (this.IsFull())
			return SubmitWaiting(a);

		this._mainQueue.queue[_mainQueue.head] = a;
		MoveHead(1);

		return true;
	}

	public bool SubmitBatch(in Attack[] a, int count)
	{
		int rem = count;
		bool nofit;
		if ((nofit = !MoveHead(count)))
			rem = Remaining();

		int i = 0;
		for (; i < rem; ++i)
			this.Submit(a[i]);

		bool r;
		if (nofit)
		{
			rem = count - rem;
			for (; i < rem; ++i)
				r = this.SubmitWaiting(a[i]);
		}

		return r;
	}

	public bool FlushWaiting()
	{
		for (int i = 0; i < this._waitingQueue.size; ++i)
			this.SubmitNB(a[i]);

		this._waitingQueue.size = 0;
	}

	public void Remove()
	{
		MoveTail(1);
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

	public static void GetMageAttackSingle(int x, int y,
					       float angle, out IVector2 dst)
	{
		const int range = 5;
		dst.Set(x, y);
		dst.RotateAcl(angle).Scale(range);
	}

	public static MapElement[,] UpdateMageAttackSingle(int x, int y,
													   float angle, int map)
	{
		if (!MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
			goto exit;

		/* Number of tiles. */
		const int range = 5;

		IVector2 dst = new IVectoer2(x, y);
		dst.RotateAcl(angle).Scale(range);
		MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

		exit:
		return MapTable.GetMap(map);
	}

	public static MapElement[,] UpdateMageAttackMultiple(int x, int y,
														 float angle, int map)
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
