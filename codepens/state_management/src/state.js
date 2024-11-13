import { scan, shareReplay, startWith, take } from "rxjs";
import EventService from "./eventService";


const DEFAULT_STATE = {
    text: ''
}

export default class StateManager {
    /**
     * 
     * @param {EventService} eventService 
     */
    constructor(eventService) {
        eventService.getStream().subscribe(console.log)

        this.state = eventService.getStream().pipe(
            scan((acc, cur) => ({...acc, text: cur}), DEFAULT_STATE),
            startWith(DEFAULT_STATE),
            shareReplay(1)
        )
    }

    outputState() {
        this.state.pipe(take(1)).subscribe(state => console.log(state))
    }
}