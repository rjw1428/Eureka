import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class GithubService {
    /**
     * 
     * @param {StateManager} stateManager 
     */
    constructor(stateManager) {
        console.log('GithubService initialized')

        stateManager.watchState('text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match)
        ).subscribe(() => stateManager.publish({match: this.getType()}))
    }

    static get(state) {
        return instance || new GithubService(state)
    }

    /**
     * 
     * @param {string} value
     * @returns {boolean}
    */
    isMatch(value) {
        return value && value.includes('github.com')
    }

    getType() {
        return 'Github Link'
    }
}