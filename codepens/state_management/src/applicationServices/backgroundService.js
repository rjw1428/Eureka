let instance = null
export default class BackgroundService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        const colorMap = {
            red: '#9b0a0a',
            green: '#078612',
            blue: '#4ca5ef',
            white: '#ffffff'
        }

        stateManager.watchState('style.background').subscribe(color => {
            document.body.style.background = colorMap[color]
        })
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     * @returns {BackgroundService}
     */
    static get(stateManager, eventService) {
        return instance || new BackgroundService(stateManager, eventService)
    }
}