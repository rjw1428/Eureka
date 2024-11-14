import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class YoutubeService {
    /**
     * 
     * @param {StateManager} stateManager 
     */
    constructor(stateManager) {
        console.log('YoutubeService initialized')

        stateManager.watchState('text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match),
        ).subscribe(() => stateManager.publish({match: this.getType()}))
    }

    static get(state) {
        return instance || new YoutubeService(state)
    }

    /**
     * 
     * @param {string} value
     * @returns {boolean}
    */
    isMatch(value) {
        return value && value.includes('youtube.com')
    }

    getType() {
        return 'Youtube Video'
    }
}