import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class LinkedinService {
    /**
     * 
     * @param {StateManager} stateManager 
     */
    constructor(stateManager) {
        console.log('LinkedinService initialized')

        stateManager.watchState('text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match),
        ).subscribe(() => stateManager.publish({match: this.getType()}))
    }

    static get(state) {
        return instance || new LinkedinService(state)
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