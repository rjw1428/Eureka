import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class EmailService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        stateManager.watchState('input.text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match)
        ).subscribe(() => eventService.publish({ 'input.matcher': this.getType() }))
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    static get(stateManager, eventService) {
        return instance || new EmailService(stateManager, eventService)
    }

    /**
     * 
     * @param {string} value
     * @returns {boolean}
     */
    isMatch(value) {
        return value && !!value.match(/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/)
    }

    getType() {
        return 'Email Address'
    }
}