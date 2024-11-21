import EventService from "./eventService";
import StateManager from "./state";
import MatchingService from "./matchingServices/matchingService";
import { filter } from 'rxjs'
import BackgroundService from "./applicationServices/backgroundService";
import FontService from "./applicationServices/fontService";

class App {
    /**
     * 
     *
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        this.stateManager = stateManager
        this.eventService = eventService
        
    }

    /**
     * 
     * @param {HTMLElement } input 
     * @param {HTMLElement } button 
     * @param {HTMLElement} debug 
     * @param {HTMLElement[]} bgButtons 
     * @param {HTMLElement} target 
     */
    start(button, input, debug, bgButtons) {
        button.addEventListener('click', () => {
            this.eventService.publish({ 'input.text': input.value })
        });

        bgButtons.forEach((bgButton) => {
            bgButton.addEventListener('click', () => {
                this.eventService.publish({ 'style.background': bgButton.name })
            })
        })

        if (debug) {
            debug.addEventListener('click', () => this.stateManager.outputState())
        }
    }
}


const input = document.getElementById('input');
const button = document.getElementById('action');
const debug = document.getElementById('debug')

const bgButtons = [
    document.getElementById('bg-red'),
    document.getElementById('bg-green'),
    document.getElementById('bg-blue'),
    document.getElementById('bg-default')
]

const eventService = new EventService()
const stateManager = new StateManager(eventService)
const app = new App(stateManager, eventService)
MatchingService.get(stateManager, eventService)
BackgroundService.get(stateManager, eventService)
FontService.get(stateManager, eventService)
app.start(button, input, debug, bgButtons)

