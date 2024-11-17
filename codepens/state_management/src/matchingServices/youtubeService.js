import { filter, map } from "rxjs"
import StateManager from "../state"

let instance = null
export default class YoutubeService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        console.log('YoutubeService initialized')

        stateManager.watchState('text').pipe(
            map((v) => this.isMatch(v)),
            filter(match => !!match),
        ).subscribe(() => eventService.publish({match: this.getType()}))
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    static get(stateManager, eventService) {
        return instance || new YoutubeService(stateManager, eventService)
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