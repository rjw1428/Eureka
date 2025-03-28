import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class LinkedinService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        stateManager.watchState('input.text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match),
        ).subscribe(() => eventService.setState({ 'input.matcher': this.getType() }))
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    static get(stateManager, eventService) {
        return instance || new LinkedinService(stateManager, eventService)
    }

    /**
     * 
     * @param {string} value
     * @returns {boolean}
    */
    isMatch(value) {
        return value && value.includes('linkedin.com')
    }

    getType() {
        return 'LinkedIn Account'
    }
    
}