import { concatMap, exhaustMap, from, map, mergeMap, switchMap } from 'rxjs'
import { createArray } from './util'

const LIMIT = 9

function mergeTime (limit: number) {
    console.time('merge')
    from(createArray(limit))
        .pipe(
            mergeMap(i => from(fetch(`https://pokeapi.co/api/v2/pokemon/${i+1}`)).pipe(
                switchMap(resp => resp.json()),
                map(unit => `${i+1}) ${unit.name}`)
            )
        )
    ).subscribe({
        next: console.log,
        error: console.warn,
        complete: () => {
            console.timeEnd('merge')
        }
    })
}


function concatTime (limit: number) {
    console.time('concat')
    from(createArray(limit))
        .pipe(
            concatMap(i => from(fetch(`https://pokeapi.co/api/v2/pokemon/${i+1}`)).pipe(
                switchMap(resp => resp.json()),
                map(unit => `${i+1}) ${unit.name}`)
            )
        )
    ).subscribe({
        next: console.log,
        error: console.warn,
        complete: () => {
            console.timeEnd('concat')
        }
    })
}

function exhaustTime (limit: number) {
    console.time('exhaust')
    from(createArray(limit))
        .pipe(
            exhaustMap(i => from(fetch(`https://pokeapi.co/api/v2/pokemon/${i+1}`)).pipe(
                switchMap(resp => resp.json()),
                map(unit => `${i+1}) ${unit.name}`)
            )
        )
    ).subscribe({
        next: console.log,
        error: console.warn,
        complete: () => {
            console.timeEnd('exhaust')
        }
    })
}

function switchTime (limit: number) {
    console.time('switch')
    from(createArray(limit))
        .pipe(
            switchMap(i => from(fetch(`https://pokeapi.co/api/v2/pokemon/${i+1}`)).pipe(
                switchMap(resp => resp.json()),
                map(unit => `${i+1}) ${unit.name}`)
            )
        )
    ).subscribe({
        next: console.log,
        error: console.warn,
        complete: () => {
            console.timeEnd('switch')
        }
    })
}

// exhaustTime(LIMIT) // Will only return the first one and all others will not be sent
// switchTime(LIMIT) // Will begin to send each one, canceling them until the very last, which will get returned
mergeTime(LIMIT) // Will send requests for all of them, returning them in the order which they complete (parallel)
// concatTime(LIMIT) // Will send each request only after the previous one completes