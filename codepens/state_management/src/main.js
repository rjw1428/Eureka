import EventService from "./eventService";
import StateManager from "./state";

class App {
    /**
     * 
     *
     * @param {EventService} eventService
     * @param {StateManager} stateManager
     */
    constructor(eventService, stateManager) {
        this.eventService = eventService
        this.stateManager = stateManager
    }

    /**
     * 
     * @param {HTMLElement } input 
     * @param {HTMLElement } button 
     */
    start(button, input, debug) {
        button.addEventListener('click', () => this.eventService.publish(input.value));

        if (debug) {
            debug.addEventListener('click', () => this.stateManager.outputState())
        }
    }
}


const input = document.getElementById('input');
const button = document.getElementById('action');
const debug = document.getElementById('debug')

const eventService = new EventService()
const stateManager = new StateManager(eventService)
const app = new App(eventService, stateManager)

app.start(button, input, debug)
