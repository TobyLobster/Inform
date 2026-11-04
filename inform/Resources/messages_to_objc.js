class ProjectClass {
    selectView(view) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["selectView", view] );
    }
    confirmAction() {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["confirmAction"] );
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
    install(extension) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["install", extension] );
    }
    uninstall(extension) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["uninstall", extension] );
    }
    modernise(extension) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["modernise", extension] );
    }
    test(extension, command, testcase) {
        window.webkit.messageHandlers.scriptHandler.postMessage( ["test", extension, command, testcase] );
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
