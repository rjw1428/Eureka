import { useEffect, useMemo, useState } from 'react';
import { Subscription, timer, map, Subject, switchMap, takeUntil, exhaustMap, take, finalize, scan, startWith, merge, shareReplay } from 'rxjs'
import './App.css'

// Constants
const SAMPLE_INTERVAL = 10;
const COLUMNS = {
  frequency: 'freq',
  contraction: 'contract'
}

// Types
type Item = {
  id: number;
  column: string;
  value: number;
}
type ListItem = Item & { value: string };

// Helper functions
const pad = (n: number, p: number = 2) => n.toString().padStart(p, '0');
const average = (arr: number[]) => Math.floor(arr.reduce((sum, cur) => cur + sum, 0) / arr.length);
const formatTime = (t: number, withMilliseconds = true) => {
  const h = Math.floor(t / (60 * 60 * 1000));
  const m = Math.floor(t / (60 * 1000) - (h * 60));
  const s = Math.floor(t / 1000 - (m * 60) - (h * 60 * 60));
  const ms = t % 1000;
  const base = h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
  return withMilliseconds ? `${base}.${pad(ms, 3)}` : base;
}

// RxJS State
const start$ = new Subject<number>();
const stop$ = new Subject<void>();
const reset$ = new Subject<void>();
const remove$ = new Subject<Item>()

const overallTimer$ = start$.pipe(
  exhaustMap((start) => timer(0, SAMPLE_INTERVAL).pipe(
    map(() => Date.now() - start),
    takeUntil(reset$),
    finalize(() => console.log('Overall Timer completed')),
  )),
);

const intervalTime$ = start$.pipe(
  exhaustMap((start) => timer(0, SAMPLE_INTERVAL).pipe(
    map(() => Date.now() - start),
    takeUntil(merge(stop$, reset$)),
    finalize(() => console.log('Interval Timer completed')),
  )),
)

const frequencyTimer$ = stop$.pipe(
  exhaustMap(() => {
    const lastEnd = Date.now();
    return timer(0, SAMPLE_INTERVAL).pipe(
      map(() => Date.now() - lastEnd),
      takeUntil(merge(start$, reset$)),
      finalize(() => console.log('Frequency Timer completed')),
    )
  }),
) 

// This is setup to remove the item from both lists.
// To remove from only one list, you can use the `filter` 
// operator to filter out the category you want to keep.
const removeList$ = reset$.pipe(
  startWith(0),
  switchMap(() => remove$.pipe(
    scan((acc, curr) => acc.concat(curr.id), [] as number[]),
    startWith([] as number[]),
  )),
  shareReplay(1),
)

const frequency$ = reset$.pipe(
  startWith(0),
  switchMap(() => stop$.pipe(
    exhaustMap(() => {
      const lastEnd = Date.now();
      return start$.pipe(
        take(1),
        map((latestStart) => latestStart - lastEnd),  
      )
    }),
    scan((acc, curr, i) => acc.concat({id: i, value: curr, column: COLUMNS.frequency}), [] as Item[]),
    switchMap((list) => removeList$.pipe(
      map(removes => list.filter(item => !removes.includes(item.id)))
    )),
    finalize(() => console.log('Frequency list completed')),
    startWith([]),
  )),
)

const intervals$ = reset$.pipe(
    startWith(0),
    switchMap(() => start$.pipe(
      exhaustMap((start) => stop$.pipe(
        map(() => Date.now() - start),
        take(1),
        finalize(() => console.log('Interval completed')),
      )),
      scan((acc, curr, i) => acc.concat({id: i, value: curr, column: COLUMNS.contraction}), [] as Item[]),
      switchMap((list) => removeList$.pipe(
        map(removes => list.filter(item => !removes.includes(item.id)))
      )),
      finalize(() => console.log('Interval list completed')),
      startWith([]),
    ))
)

let subs: Subscription[]= [];

function App() {
  const [showMilliseconds, setShowMilliseconds] = useState(false);
  const [isRunning, setIsRunning] = useState(false);
  const [getOverallTimer, setOverallTimer] = useState(0);
  const [getIntervalTimer, setIntervalTimer] = useState(0);
  const [getFrequencyTimer, setFrequencyTimer] = useState(0);
  const [getIntervals, setIntervals] = useState<Item[]>([]);
  const [getFrequency, setFrequency] = useState<Item[]>([]);

  useEffect(() => {
    subs.push(overallTimer$.subscribe((t) => setOverallTimer(t)))
    subs.push(intervals$.subscribe((intervals) => setIntervals(intervals)))
    subs.push(intervalTime$.subscribe((t) => setIntervalTimer(t)))
    subs.push(frequency$.subscribe((frequency) => setFrequency(frequency)))
    subs.push(frequencyTimer$.subscribe((t) => setFrequencyTimer(t)))

    return () => {
      subs.forEach((s) => s.unsubscribe());
      onReset();
    }
  }, [])

  const startTimer = () => {    
    setIsRunning(!isRunning)
    start$.next(Date.now())
  }

  const stopTimer = () => {
    setIsRunning(!isRunning)
    stop$.next()
  }

  const onReset = () => {
    setOverallTimer(0)
    setIntervalTimer(0)
    setFrequencyTimer(0)
    setFrequency([])
    setIntervals([])
    setIsRunning(false)
    reset$.next()
  }

  const {overallTime, intervalTime, frequencyTime, intervals, frequency} = useMemo(() => ({
    overallTime: formatTime(getOverallTimer, showMilliseconds),
    intervalTime: formatTime(getIntervalTimer, showMilliseconds),
    frequencyTime: formatTime(getFrequencyTimer, showMilliseconds),
    intervals: getIntervals.map((i) => ({...i, value: formatTime(i.value, true)} as ListItem)).reverse(),
    frequency: getFrequency.map((i) => ({...i, value: formatTime(i.value, true)} as ListItem)).reverse(),
  }), [getOverallTimer, showMilliseconds]);

  const averageContraction = getIntervals.length > 0
    ? <h2>{formatTime(average(getIntervals.map(i => i.value)), true)}</h2>
    : <></>

  const averageFrequency = getFrequency.length > 0
    ? <h2>{formatTime(average(getFrequency.map(i => i.value)), true)}</h2>
    : <></>

  const createRowItem = (item: ListItem, index: number, arr: ListItem[]) => {
    return <li style={{display: 'flex', alignItems: 'center', justifySelf: 'center', gap: '8px'}} key={item.id}>
      <div><strong>{arr.length - index})</strong> {item.value}</div>
      <button style={{backgroundColor: 'unset'}} onClick={() => remove$.next(item)}><small>X</small></button>
    </li>
  }

  const button = isRunning
  ? <button style={{marginTop: '20px', padding: '1.2em 2.4em', background: 'lightcoral'}} onClick={stopTimer}>Stop Contraction</button>
  : <button style={{marginTop: '20px', padding: '1.2em 2.4em', background: 'lightgreen'}} onClick={startTimer}>Start Contraction</button>

  
  return (
    <div style={{display: 'flex', flexDirection: 'column', justifyContent: 'space-around', height: '80vh', overflow: 'hidden'}}>
      <p>Total Monitoring Time</p>
      <h1>{overallTime}</h1>

      <div style={{ marginTop: '20px' }}>
        <label>Show milliseconds</label>
        <input type="checkbox" checked={showMilliseconds} onChange={() => setShowMilliseconds(!showMilliseconds)} />
      </div>

      <div className="row" style={{ display: 'flex', flexDirection: 'row', height: '50vh'}}>
        <div style={{ display: 'flex', flexDirection: 'column'}}>
          <p>Contraction Time</p>
          <h2>{intervalTime}</h2>

          <h2 className='header'>Average Contraction</h2>
          {averageContraction}

          <p>Contractions</p>
          <ul style={{ listStyleType: 'none', padding: 0, overflow: 'auto' }}>
            {intervals.map(createRowItem)}
          </ul>
        </div>

        <div  style={{ display: 'flex', flexDirection: 'column'}}>
          <p>Frequency Time</p>
          <h2>{frequencyTime}</h2>

          <h2 className="header">Average Frequency</h2>
          {averageFrequency}

          <p>Frequency</p> 
          <ul style={{ listStyleType: 'none', padding: 0, overflow: 'auto'  }}>
            {frequency.map(createRowItem)}
          </ul>
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
        {button}
        <button onClick={onReset}>Reset</button>
      </div>
    </div>
  )
}

export default App
