import {
    interval,
    take,
    scan,
    BehaviorSubject,
    switchMap,
    EMPTY,
    finalize,
    takeUntil,
    Subject,
    filter,
    exhaustMap,
    startWith,
} from "rxjs";

const config = {
    delay: 500,
    maxCount: 10,
};
const stop2$ = new Subject();
const stop3$ = new BehaviorSubject(true);
const stop4$ = new BehaviorSubject({ stop: true, complete: true });

// Question 1: Emit number from 1 to 10 to the screen, adding 1 value to the screen every second (in reverse order)
const count1$ = interval(config.delay).pipe(
    scan((acc: number[], val) => [val + 1].concat(acc), []),
    take(config.maxCount)
);

// count1$.subscribe(console.log)

// Question 2: Create a button to stop the output
const count2$ = interval(config.delay).pipe(
    scan((acc: number[], val) => [val + 1].concat(acc), []),
    take(config.maxCount),
    takeUntil(stop2$)
);
// count2$.subscribe(console.log)
// setTimeout(() => stop2$.next(''), 3*1000) // Stop at 5

// Question 3: Lets turn this button into a play/pause button
//  - So it should pause the count, and then when you click the button again, continue
//  - Make the button label change with the state of the stream
//  - Once all 10 values are emitted, return the button to the 'start' state
//  - Optional: Make it initially be in the stopped state (change the behaviorSubject initial state)
const count3$ = stop3$.pipe(
    switchMap((stop) => (stop ? EMPTY : interval(config.delay))),
    scan((acc) => acc + 1, 0),
    take(config.maxCount),
    scan((acc: number[], val) => [val].concat(acc), []),
    finalize(() => stop3$.next(true))
);
count3$.subscribe(console.log);
// Start after 1 second
setTimeout(() => {
    console.log("PLAY");
    stop3$.next(false);
}, 2 * 1000);
// Pause at 5
setTimeout(() => {
    console.log("PAUSE");
    stop3$.next(true);
}, 5 * 1000);
// Continue after 3 seconds
setTimeout(() => {
    console.log("CONTINUE");
    stop3$.next(false);
}, 8 * 1000);


const count4$ = stop4$.pipe(
    filter((val) => !val.complete),
    exhaustMap(() =>
        stop4$.pipe(
            switchMap(({ stop }) => (stop ? EMPTY : interval(config.delay))),
            scan((acc) => acc + 1, 0),
            take(config.maxCount),
            scan((acc: number[], val) => [val].concat(acc), []),
            finalize(() => stop4$.next({ stop: true, complete: true })),
            startWith([])
        )
    )
);


console.log("INIT");

// Optional Continuations:
// Throw an error at a certain value
// Add Another button to do something else (retry)
// Make the current button retry, clearing it out and starting again
// Use the pokemon open API (https://pokeapi.co/) to make each 'tick' return the name of that pokemon
// Take the config values and move them to a new file
// Testing - How would you test this?
