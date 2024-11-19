import { of, map, Observable, shareReplay } from 'rxjs'

/**
 ** Cold Observable 
    - These are lazy observables, new data is produced each time we subscribe to it
    - New subscribers would start from the very beginning of the stream
*/
const cold = of(null).pipe(map(() => Math.random()))
// different value
// cold.subscribe(console.log)
// cold.subscribe(console.log)

const cold2 = new Observable(subscriber => {
    subscriber.next(Math.random())
    subscriber.complete()
})
// different value
// cold2.subscribe(console.log)
// cold2.subscribe(console.log)

/** 
 **Hot Observable
    - These are emitting whether something is subscribed or not
    - New subscribers would get only the new values
 */
const hot = cold.pipe(
    shareReplay(1)
)
// same value
// hot.subscribe(console.log)
// hot.subscribe(console.log)

const data = Math.random()
const hot2 = new Observable(subscriber => {
    subscriber.next(data)
    subscriber.complete()
})
// same value
hot2.subscribe(console.log)
hot2.subscribe(console.log)