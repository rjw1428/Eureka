import{ Subject, switchAll, merge, filter, scan, ReplaySubject, BehaviorSubject }from "rxjs" ;

function test() {
    console.log("here");
}

function getAuthenticationMessage(isAuthenticated) {
    return isAuthenticated
        ? "User is authenticated"
        : "User is not authenticated";
}

function oldMethodName() {
    return "doesn't do anything";
}

function newMethodName() {
    return "replaced method";
}

function test2() {
    newMethodName();
}

test2();
