import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class EmailService {
    /**
     * 
     * @param {StateManager} stateManager 
     */
    constructor(stateManager) {
        console.log('EmailService initialized')

        stateManager.watchState('text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match)
        ).subscribe(() => stateManager.publish({match: this.getType()}))
    }

    static get(state) {
        return instance || new EmailService(state)
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