import { take, filter } from "rxjs";
import EventService from "./eventService";
import StateManager from "./state";
import MatchingService from "./matchingServices/matchingService";

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
    start(button, input, debug, bgButtons, target) {
        const textMatchingService = MatchingService.get(this.stateManager, this.eventService)

        button.addEventListener('click', () => {
            // Broadcast new value
            this.eventService.publish({ text: input.value })
        });

        if (debug) {
            debug.addEventListener('click', () => this.stateManager.outputState())
        }

        bgButtons.forEach((bgButton) => {
            bgButton.addEventListener('click', () => this.eventService.publish({ background: bgButton.name }))
        })

        textMatchingService.uiValue.subscribe(innerText => target.innerText = innerText)
    }
}


const input = document.getElementById('input');
const button = document.getElementById('action');
const resultTarget = document.getElementById('result')
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
app.start(button, input, debug, bgButtons, resultTarget)
