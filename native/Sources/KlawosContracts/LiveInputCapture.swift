import Foundation
import CoreGraphics
import IOKit
import AppKit

/// Main-run-loop capture. Only reserved F-key candidates enter the router.
@MainActor public final class LiveInputCapture {
    private let router=InputRouter();private let contexts=ContextRouter()
    private var configuration:HelperConfiguration?
    private var tap:CFMachPort?;private var source:CFRunLoopSource?
    private var deviceToken:String=""
    private var timer:Timer?
    private var appObserver:(any NSObjectProtocol)?
    public private(set) var presses=0
    public private(set) var releases=0
    public private(set) var reason="Stopped"
    public var active:Bool{router.isActive}
    public var onPress:((PressToken)->Void)?
    public init(){}
    public func start(allocations:[InputID:String],configuration:HelperConfiguration,deviceToken:String)throws {
        guard InputTapController.permissions.values.allSatisfy({$0}) else{throw InputTapError.permissionRequired}
        stop();guard Self.connected(deviceToken) else{throw InputTapError.disconnected}
        for bindings in configuration.bindings.values{_ = try ContextRouter.resolve(bundleID:nil,bindings:bindings);if case .object(let overrides)=bindings["overrides"]{for id in overrides.keys{_ = try ContextRouter.resolve(bundleID:id,bindings:bindings)}}}
        try router.activate(allocations:allocations,configuration:configuration,deviceGeneration:deviceToken,verifiedRevision:configuration.triggerMapRevision)
        self.configuration=configuration;self.deviceToken=deviceToken;presses=0;releases=0
        let mask=(CGEventMask(1)<<CGEventType.keyDown.rawValue)|(CGEventMask(1)<<CGEventType.keyUp.rawValue)
        guard let newTap=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:mask,callback:{_,type,event,context in
            guard let context else{return Unmanaged.passUnretained(event)}
            let consumed=MainActor.assumeIsolated {
                let owner=Unmanaged<LiveInputCapture>.fromOpaque(context).takeUnretainedValue()
                return owner.process(type,event)
            }
            return consumed ? nil:Unmanaged.passUnretained(event)
        },userInfo:Unmanaged.passUnretained(self).toOpaque()),let runLoopSource=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,newTap,0) else {stop(reason:"Could not start input capture");throw InputTapError.installationFailed}
        tap=newTap;source=runLoopSource;CFRunLoopAddSource(CFRunLoopGetMain(),runLoopSource,.commonModes);CGEvent.tapEnable(tap:newTap,enable:true);reason="Running"
        appObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didLaunchApplicationNotification,object:nil,queue:.main){[weak self] notification in
            if let app=notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,app.bundleIdentifier=="today.vial"{MainActor.assumeIsolated{self?.stop(reason:"Paused while Vial is open. Close Vial and start again to revalidate.")}}
        }
        timer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){[weak self]_ in MainActor.assumeIsolated{guard let self else{return};if !Self.connected(self.deviceToken){self.stop(reason:"Keyboard disconnected")}else if !InputTapController.permissions.values.allSatisfy({$0}){self.stop(reason:"Input permission was revoked")}else if NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="today.vial"}){self.stop(reason:"Paused while Vial is open. Close Vial and start again to revalidate.")}}}
    }
    private func process(_ type:CGEventType,_ event:CGEvent)->Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput{stop(reason:"Input capture was disabled by macOS");return false}
        guard let configuration,active else{return false}
        guard let sample=MacInputEvent.decode(event,type:type) else{return false}
        guard Self.connected(deviceToken) else{stop(reason:"Keyboard disconnected");return false}
        switch router.route(sample,configuration:configuration){
        case .helperPress(let input):
            presses+=1
            if let bindings=configuration.bindings[input],let token=try? contexts.beginPress(input:input,bundleID:NSWorkspace.shared.frontmostApplication?.bundleIdentifier,bindings:bindings){onPress?(token)}
            return true
        case .helperRelease(let input):releases+=1;_ = contexts.endPress(input:input);return true
        case .consumed:return true
        case .ignoredSynthetic,.passThrough:return false
        }
    }
    public func stop(reason:String="Stopped"){
        if let appObserver{NSWorkspace.shared.notificationCenter.removeObserver(appObserver)};appObserver=nil
        router.releaseAll(reason:.stop);contexts.releaseAll();configuration=nil;self.reason=reason;timer?.invalidate();timer=nil
        if let tap{CGEvent.tapEnable(tap:tap,enable:false);CFMachPortInvalidate(tap)}
        if let source{CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes)};tap=nil;source=nil
    }
    private static func connected(_ token:String)->Bool{
        guard let value=UInt64(token),let matching=IORegistryEntryIDMatching(value) else{return false}
        let service=IOServiceGetMatchingService(kIOMainPortDefault,matching);guard service != 0 else{return false};IOObjectRelease(service);return true
    }
}
