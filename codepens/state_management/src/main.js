import { combineLatest, map, skip, take, filter } from "rxjs";
import EventService from "./eventService";
import EmailService from "./matchingServices/emailService";
import GithubService from "./matchingServices/githubService";
import LinkedinService from "./matchingServices/linkedinService";
import YoutubeService from "./matchingServices/youtubeService";
import StateManager from "./state";

class App {
    /**
     * 
     *
     * @param {StateManager} stateManager
     */
    constructor(stateManager) {
        this.stateManager = stateManager

        
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
        button.addEventListener('click', () => {
            // Clear ui state if it's a new input value
            this.stateManager.watchState('text').pipe(
                take(1),
                filter(previousInput => previousInput !== input.value)
            ).subscribe(() => this.stateManager.publish({ match: null }))
            
            // Broadcast new value
            this.stateManager.publish({ text: input.value })
        });

        if (debug) {
            debug.addEventListener('click', () => this.stateManager.outputState())
        }

        bgButtons.forEach((bgButton) => {
            bgButton.addEventListener('click', () => this.stateManager.publish({ background: bgButton.name }))
        })

        // Determine UI Value
        combineLatest([
            this.stateManager.watchState('match'),
            this.stateManager.watchState('text')
        ]).pipe(
            skip(1),
            map(([result, inputText]) => {
                if (inputText === '') {
                    return 'Empty'
                }
                if (result) {
                    return `Result: ${result}`
                }
                return 'No Match'
            })
        ).subscribe(innerText => target.innerText = innerText)

        
    }

    registerMatchers(matcherServices = []) {
        matcherServices.map(service => service.get(this.stateManager))
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
const app = new App(stateManager)

app.start(button, input, debug, bgButtons, resultTarget)

const matcherServices = [
    YoutubeService,
    GithubService,
    LinkedinService,
    EmailService
]
app.registerMatchers(matcherServices)
