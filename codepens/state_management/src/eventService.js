import { shareReplay, Subject } from 'rxjs'

export default class EventService {
    constructor() {
        this.events = new Subject()
    }

    getStream() {
        return this.events.asObservable()//.pipe(shareReplay(1))
    }

    publish(value) {
        this.events.next(value)
        return this
    }
}