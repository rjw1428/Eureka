import { fromEvent, interval, of, scan, switchMap, take, tap, throttle, timer } from "rxjs";


const THROTTLE_TIMEOUT = 3000
const throttle$ = of('').pipe(
    tap(() => console.log('throttle closed')),
    switchMap(() => timer(THROTTLE_TIMEOUT)),
    tap(() => console.log('throttle open'))
);

// fromEvent(document, 'click')
interval(200)
    .pipe(
        scan((acc, cur) => acc + 1, 0),
        // tap((val) => console.log('.   ' + val)),
        throttle(() => throttle$),
        take(5)
    )
    .subscribe((event) => console.log(`-- EVENT --(${event})`));