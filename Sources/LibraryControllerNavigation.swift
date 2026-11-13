import AppKit
import GameController

@MainActor extension AppModel {
    var controllerSystems:[GameSystem]{GameSystem.allCases.filter{(galleryFilter=="All systems" || $0.family==galleryFilter || $0.maker.capitalized==galleryFilter) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))}}
    func startLibraryControllerNavigation(){
        navigationTimer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak self] _ in Task{@MainActor in self?.pollLibraryController()}}
    }
    func pollLibraryController(){
        guard NSApp.isActive,let pad=GCController.controllers().first?.extendedGamepad else{navigationHasFocus=false;navigationPrevious=[];return}
        if NSApp.keyWindow?.firstResponder is NSTextView{return}
        var pressed=Set<String>()
        for (name,down) in [("up",pad.dpad.up.isPressed || pad.leftThumbstick.yAxis.value>0.65),("down",pad.dpad.down.isPressed || pad.leftThumbstick.yAxis.value < -0.65),("left",pad.dpad.left.isPressed || pad.leftThumbstick.xAxis.value < -0.65),("right",pad.dpad.right.isPressed || pad.leftThumbstick.xAxis.value>0.65),("a",pad.buttonA.isPressed),("b",pad.buttonB.isPressed),("x",pad.buttonX.isPressed),("lb",pad.leftShoulder.isPressed),("rb",pad.rightShoulder.isPressed)]{if down{pressed.insert(name)}}
        // A held button from the game must be released before it can launch
        // another session when the library regains focus.
        if !navigationHasFocus{navigationHasFocus=true;navigationPrevious=pressed;return}
        applyControllerButtons(pressed)
    }
    func applyControllerButtons(_ pressed:Set<String>){
        let fresh=pressed.subtracting(navigationPrevious);navigationPrevious=pressed
        guard !pressed.isEmpty else{navigationRepeat = .distantPast;return}
        controllerNavigationActive=true
        if error != nil{if fresh.contains("a") || fresh.contains("b"){error=nil};return}
        if recoveryOpen{if fresh.contains("b"){recoveryOpen=false};return}
        if engine.running{if fresh.contains("a"){engine.resumeGame()};if fresh.contains("x"){engine.openSessionMenu()};return}
        if let item=inspectedItem {
            if fresh.contains("b"){inspectedItem=nil;return}
            if fresh.contains("left"){controllerDetailSlot=(controllerDetailSlot+5)%6}
            if fresh.contains("right"){controllerDetailSlot=(controllerDetailSlot+1)%6}
            if fresh.contains("a"),progress(item).info(controllerDetailSlot) != nil{inspectedItem=nil;loadSlot(item,slot:controllerDetailSlot)}
            if fresh.contains("x"){inspectedItem=nil;launch(item,resume:hasResume(item))}
            return
        }
        let sections=["Consoles","Library","Saves","Controllers","Sessions","System"]
        if fresh.contains("lb") || fresh.contains("rb"){let index=sections.firstIndex(of:section) ?? 0;section=sections[(index+(fresh.contains("rb") ? 1:sections.count-1))%sections.count];return}
        if fresh.contains("b"){section="Consoles";return}
        let directions=pressed.intersection(["up","down","left","right"])
        let moveAllowed = !directions.isEmpty && (Date().timeIntervalSince(navigationRepeat)>0.2 || !fresh.intersection(directions).isEmpty)
        let delta=directions.contains("up") ? -libraryColumns:directions.contains("down") ? libraryColumns:directions.contains("left") ? -1:directions.contains("right") ? 1:0
        if section=="Consoles" {
            let items=controllerSystems;guard !items.isEmpty else{return}
            if moveAllowed{controllerConsoleIndex=max(0,min(items.count-1,controllerConsoleIndex+delta));navigationRepeat=Date()}
            if fresh.contains("a"){openSystem(items[min(controllerConsoleIndex,items.count-1)])}
        }else if section=="Library" {
            let items=visibleItems;guard !items.isEmpty else{return}
            var index=items.firstIndex{$0.id==controllerSelection} ?? 0
            if moveAllowed{index=max(0,min(items.count-1,index+delta));navigationRepeat=Date()}
            controllerSelection=items[index].id
            if fresh.contains("a"){launch(items[index],resume:hasResume(items[index]))}
            if fresh.contains("x"){inspectedItem=items[index]}
        }
    }
}
