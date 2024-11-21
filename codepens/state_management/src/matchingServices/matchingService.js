import { combineLatest, map, skip, take, filter, pairwise, withLatestFrom, tap, defaultIfEmpty, switchMap } from "rxjs"
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
        stateManager.watchState('input.result').pipe(filter(v => !!v)).subscribe(innerText => {
            console.log(`SETTING RESULT: ${JSON.stringify(innerText)}`)
            document.getElementById('result').innerText = innerText
        })

        // Clear ui state if it's a new input value
        stateManager.watchState('input.text').pipe(
            pairwise(),
            filter(([previous, current]) => {
                return previous != current
            }),
            tap(() => console.log("CLEARING"))
        ).subscribe(() => eventService.publish({ 'input.matcher': null }))


        // Determine UI Value
        stateManager.watchState('input.matcher').pipe(
            skip(1),
            withLatestFrom(stateManager.watchState('input.text')),
            map(([matcher, text]) => {
                console.log(`text=${text}, matcher=${matcher}`)
                if (text === '') {
                    return 'Empty'
                }
                if (matcher) {
                    return `Result: ${matcher}`
                }
                return 'No Match'
            })
        ).subscribe((val) => eventService.publish({ 'input.result': val}))

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