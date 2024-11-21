import { catchError, distinctUntilChanged, map, scan, shareReplay, startWith, take, tap } from "rxjs";
import EventService from "./eventService";


const DEFAULT_STATE = {
    input: {
        text: null,
        matcher: null,
        result: null
    },
    style: {
        background: 'white'
    }
}
export default class StateManager {
    /**
     * 
     * @param {EventService} eventService 
     */
    constructor(eventService) {
        this.state = eventService.getStream().pipe(
            tap((e) => console.log(`EVENT: ${JSON.stringify(e)}`)),
            scan((acc, cur) => {
                const [path, value] = Object.entries(cur)[0]
                const keys = path.split('.');
                // Recursively construct a new object tree
                const updateNestedObject = (obj, keys) => {
                    const [key, ...rest] = keys;
                    return rest.length === 0
                        ? { ...obj, [key]: value }
                        : { ...obj, [key]: updateNestedObject(obj[key] || {}, rest)};
                };
                return updateNestedObject(acc, keys);
            }, DEFAULT_STATE),
            startWith(DEFAULT_STATE),
            shareReplay(1)
        )
    }

    watchState(key) {
        return this.state.pipe(
                map(s => key.split('.').reduce((result, key) => result[key], s)),
                catchError((err, caught) => {
                    console.log(err)
                    return caught.pipe({})
                }),
                distinctUntilChanged(),
                tap((v) => `   Reading ${key}: ${v}`)
            )
    }

    outputState() {
        this.state.pipe(take(1)).subscribe(state => console.log(state))
    }
}