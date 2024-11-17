import { combineLatest, map, skip } from "rxjs"
import StateManager from "../state"
import EmailService from "./emailService";
import GithubService from "./githubService";
import LinkedinService from "./linkedinService";
import YoutubeService from "./youtubeService";

const matcherServices = [
    YoutubeService,
    GithubService,
    LinkedinService,
    EmailService
]

let instance = null

export default class MatchingService {
    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    constructor(stateManager, eventService) {
        console.log('Matching initialized')

        // USE PAIRWISE TO HANDLE THIS (CURRENT VS PREVIOUS INPUT)
        // Clear ui state if it's a new input value
        this.stateManager.watchState('text').pipe(
            take(1),
            filter(previousInput => previousInput !== input.value)
        ).subscribe(() => this.eventService.publish({ match: null }))

        // Determine UI Value
        this.uiValue = combineLatest([
            stateManager.watchState('match'),
            stateManager.watchState('text')
        ]).pipe(
            skip(1),
            map(([result, inputText]) => {
                console.log(result, inputText)
                if (inputText === '') {
                    return 'Empty'
                }
                if (result) {
                    return `Result: ${result}`
                }
                return 'No Match'
            })
        )

        this.registerMatchers(matcherServices, stateManager, eventService)
    }

    /**
     * 
     * @param {StateManager} stateManager
     * @param {EventService} eventService 
     */
    static get(stateManager, eventService) {
        return instance || new MatchingService(stateManager, eventService)
    }

    registerMatchers(matcherServices = [], stateManager, eventService) {
        matcherServices.map(service => service.get(stateManager, eventService))
    }
}