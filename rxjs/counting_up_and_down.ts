//ts-node counting_up_and_down.ts

import { interval, repeat, timer, map, finalize, of, takeUntil, filter, concat } from 'rxjs';

// Count up from 1 - 8 in 200ms intervals for 3 full second (have a pause at the end)
// Then count down from 8 to 0 in 50ms intervals for 3 seconds (also have a pause at the end)
// Repeat 3 times and provide a different message to the user each time

const MAX = 8
const COUNT_TIME = 3000
const END_MESSAGES = [
    "Great, Now do it again!..",
    "One more time, that's the ticket..",
    "Done! Bye Bye now 😁"
]
const countUp$ = interval(200).pipe(
    map(i => i+1),
    filter(i => i <= MAX),
    takeUntil(timer(COUNT_TIME)),
    finalize(() => console.log("Times Up!"))
)

const countDown$ = interval(50).pipe(
    map(i => MAX - 1 - i),
    filter(i => i >= 0),
    takeUntil(timer(COUNT_TIME)),
)

concat(countUp$, countDown$).pipe(
    repeat({ count: END_MESSAGES.length, delay: count => {
        console.log(END_MESSAGES[count - 1])
        return of(0)
    }}),
    finalize(() => console.log(END_MESSAGES[END_MESSAGES.length - 1]))
).subscribe(console.log)