class ProjectClass {
    selectView(view) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["selectView", view] );
    }
    createNewProject(story, title) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["createNewProject", story, title] );
    }
    pasteCode(code) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["pasteCode", code] );
    }
    openFile(file) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["openFile", file] );
    }
    openURL(url) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["openFile", url] );
    }
    askInterfaceForLocalVersion(author, title, available) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["askInterfaceForLocalVersion", author, title, available] );
    }
    askInterfaceForLocalVersionText(author, title) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["askInterfaceForLocalVersionText", author, title] );
    }
    downloadMultipleExtensions(author, list) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["downloadMultipleExtensions", list] );
    }
}

window.Project = new ProjectClass();
