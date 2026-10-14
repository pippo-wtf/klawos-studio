import Foundation
import WebKit
@MainActor final class Assets: NSObject, WKURLSchemeHandler {
    let root: URL
    init(root:URL){self.root=root.resolvingSymlinksInPath()}
    func webView(_ webView:WKWebView,start urlSchemeTask:any WKURLSchemeTask){
        guard let url=urlSchemeTask.request.url,url.scheme=="klawos",url.host=="app" else {urlSchemeTask.didFailWithError(URLError(.badURL));return}
        let file=root.appendingPathComponent(url.path).resolvingSymlinksInPath()
        guard file.path.hasPrefix(root.path+"/"),let data=try? Data(contentsOf:file) else {urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist));return}
        let types=["html":"text/html","js":"text/javascript","mjs":"text/javascript","css":"text/css","json":"application/json","png":"image/png","glb":"model/gltf-binary"]
        urlSchemeTask.didReceive(URLResponse(url:url,mimeType:types[file.pathExtension] ?? "application/octet-stream",expectedContentLength:data.count,textEncodingName:"utf-8"))
        urlSchemeTask.didReceive(data);urlSchemeTask.didFinish()
    }
    func webView(_ webView:WKWebView,stop urlSchemeTask:any WKURLSchemeTask){}
}
