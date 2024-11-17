let instance = null
export default class BackgroundService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        console.log('BackgroundService initialized')
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    static get(stateManager, eventService) {
        return instance || new BackgroundService(stateManager, eventService)
    }
}