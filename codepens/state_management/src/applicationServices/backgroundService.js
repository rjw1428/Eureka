let instance = null
export default class BackgroundService {
    constructor(state) {
        console.log('BackgroundService initialized')
    }

    static get(state) {
        return instance || new BackgroundService(state)
    }
}