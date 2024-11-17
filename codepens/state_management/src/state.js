import { catchError, distinctUntilChanged, map, scan, shareReplay, startWith, take } from "rxjs";
import EventService from "./eventService";


const DEFAULT_STATE = {
}

export default class StateManager {
    /**
     * 
     * @param {EventService} eventService 
     */
    constructor(eventService) {
        this.eventService = eventService
        // this.eventService.getStream().subscribe(console.log)

        this.state =  this.eventService.getStream().pipe(
            scan((acc, cur) => ({...acc, ...cur}), DEFAULT_STATE),
            startWith(DEFAULT_STATE),
            shareReplay(1)
        )
    }

    watchState(key) {
        return this.state.pipe(
            map(s => s[key]),
            distinctUntilChanged()
        )
    }

    outputState() {
        this.state.pipe(take(1)).subscribe(state => console.log(state))
    }
}