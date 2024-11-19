import { interval, windowTime, map, toArray, switchMap, takeWhile, tap, of, take, windowToggle, timer } from 'rxjs';

// Simulate some event occurring every second
const source = of('').pipe( 
    tap(() => console.log('START')),
    switchMap(() => interval(1000)) 
);

const example = source.pipe(
    windowTime(5000), // Create 5-second windows
    switchMap((window$) => window$.pipe(
        toArray(),
        map((array) => { // Collect values in each window
            const average = array.reduce((acc, val) => acc + val, 0) / array.length;
            const max = Math.max(...array);
            const min = Math.min(...array);
            return { average, max, min };
        })
    )),
    takeWhile((val) => val.max < 25)
);

// example.subscribe(val => console.log(val));

/*
Will emit the following, one every 5 seconds
{ average: 1.5, max: 3, min: 0 }
{ average: 6, max: 8, min: 4 }
{ average: 11, max: 13, min: 9 }
{ average: 16, max: 18, min: 14 }
{ average: 21, max: 23, min: 19 }

then will wait 5 seconds to "get" the next state
    { average: 26, max: 28, min: 24 }
and since that fails the `takeWhile`, it completes
 */

const OPEN = 5000
const CLOSE = 3000
const example2 = source.pipe(
    windowToggle(interval(OPEN), () => interval(CLOSE)),
    switchMap(window$ => window$.pipe(toArray())), // Flatten the window observable
    take(3)
);

example2.subscribe(console.log);
/*
using `windowToggle`, we ignore the source value until the window opens.
once then, we continue accumulating until the window closes.
If the window open time is too short, that the close never occurs, then no value get emitted

resulting in:
wait 5 seconds for the window to open
[ 4, 5, 6 ] // after 3 seconds close & accumulate
[ 9, 10, 11 ] // next 5 second trigger starts, 3 seconds later we close
[ 14, 15, 16 ]
 */