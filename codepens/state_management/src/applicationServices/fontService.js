import { map } from 'rxjs'

let instance = null
export default class FontService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        const fontColorMap = {
            red: 'white',
            green: 'black',
            blue: '#f2b951',
            white: '#222222'
        }

        stateManager.watchState('style.background').subscribe(bg => {
            document.body.style.color = fontColorMap[bg]
        })
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     * @returns {FontService}
     */
    static get(stateManager, eventService) {
        return instance || new FontService(stateManager, eventService)
    }
}