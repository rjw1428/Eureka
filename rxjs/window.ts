import { interval, windowTime, map, toArray, switchMap, takeWhile } from 'rxjs';

const source = interval(1000); // Simulate stock price updates every second

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

example.subscribe(val => console.log(val));

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