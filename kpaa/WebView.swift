//
//  WebView.swift
//  kpaa
//
//  Created by rrobbie on 2023/03/16.
//

import SwiftUI
import WebKit
import Foundation

public enum WebViewAction: Equatable {
    case idle,
         load(URLRequest),
         loadHTML(String),
         reload,
         goBack,
         goForward,
         evaluateJS(String, (Result<Any?, Error>) -> Void)
    
    public static func == (lhs: WebViewAction, rhs: WebViewAction) -> Bool {
        if case .idle = lhs,
           case .idle = rhs {
            return true
        }
        if case let .load(requestLHS) = lhs,
           case let .load(requestRHS) = rhs {
            return requestLHS == requestRHS
        }
        if case let .loadHTML(htmlLHS) = lhs,
           case let .loadHTML(htmlRHS) = rhs {
            return htmlLHS == htmlRHS
        }
        if case .reload = lhs,
           case .reload = rhs {
            return true
        }
        if case .goBack = lhs,
           case .goBack = rhs {
            return true
        }
        if case .goForward = lhs,
           case .goForward = rhs {
            return true
        }
        if case let .evaluateJS(commandLHS, _) = lhs,
           case let .evaluateJS(commandRHS, _) = rhs {
            return commandLHS == commandRHS
        }
        return false
    }
}

public struct WebViewState: Equatable {
    public internal(set) var isLoading: Bool
    public internal(set) var pageURL: String?
    public internal(set) var pageTitle: String?
    public internal(set) var pageHTML: String?
    public internal(set) var error: Error?
    public internal(set) var canGoBack: Bool
    public internal(set) var canGoForward: Bool
    
    public static let empty = WebViewState(isLoading: false,
                                           pageURL: nil,
                                           pageTitle: nil,
                                           pageHTML: nil,
                                           error: nil,
                                           canGoBack: false,
                                           canGoForward: false)
    
    public static func == (lhs: WebViewState, rhs: WebViewState) -> Bool {
        lhs.isLoading == rhs.isLoading
            && lhs.pageURL == rhs.pageURL
            && lhs.pageTitle == rhs.pageTitle
            && lhs.pageHTML == rhs.pageHTML
            && lhs.error?.localizedDescription == rhs.error?.localizedDescription
            && lhs.canGoBack == rhs.canGoBack
            && lhs.canGoForward == rhs.canGoForward
    }
}

public class WebViewCoordinator: NSObject {
    private let webView: WebView
    ///window.open()으로 열리는 새창
    var createWebView: WKWebView?
    var button:UIButton?

    var actionInProgress = false
    
    init(webView: WebView) {
        self.webView = webView
    }
    
    func setLoading(_ isLoading: Bool,
                    canGoBack: Bool? = nil,
                    canGoForward: Bool? = nil,
                    error: Error? = nil) {
        var newState =  webView.state
        newState.isLoading = isLoading
        if let canGoBack = canGoBack {
            newState.canGoBack = canGoBack
        }
        if let canGoForward = canGoForward {
            newState.canGoForward = canGoForward
        }
        if let error = error {
            newState.error = error
        }
        webView.state = newState
        webView.action = .idle
        actionInProgress = false
    }
}

extension WebViewCoordinator: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      setLoading(false,
                 canGoBack: webView.canGoBack,
                 canGoForward: webView.canGoForward)
        
        webView.evaluateJavaScript("document.title") { (response, error) in
            if let title = response as? String {
                var newState = self.webView.state
                newState.pageTitle = title
                self.webView.state = newState
            }
        }
      
        webView.evaluateJavaScript("document.URL.toString()") { (response, error) in
            if let url = response as? String {
                var newState = self.webView.state
                newState.pageURL = url
                self.webView.state = newState
            }
        }
        
        if self.webView.htmlInState {
            webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { (response, error) in
                if let html = response as? String {
                    var newState = self.webView.state
                    newState.pageHTML = html
                    self.webView.state = newState
                }
            }
        }
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        setLoading(false)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        setLoading(false, error: error)
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        setLoading(true)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      setLoading(true,
                 canGoBack: webView.canGoBack,
                 canGoForward: webView.canGoForward)
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = navigationAction.request.url?.host {
            if self.webView.restrictedPages?.first(where: { host.contains($0) }) != nil {
                decisionHandler(.cancel)
                setLoading(false)
                return
            }
        }
        
        if let url = navigationAction.request.url,
           let scheme = url.scheme,
           let schemeHandler = self.webView.schemeHandlers[scheme] {
            
            let extension4 = "\(url)".suffix(4)
            let extension5 = "\(url)".suffix(5)
                        
            if extension4 == ".pdf" || extension4 == ".csv" || extension5 == ".pptx" || extension5 == ".xlsx"{
                print("fileDownload: redirect to download events.")
                //파일 다운로드
                decisionHandler(.cancel)
                return
            }            
            
            schemeHandler(url)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
}

extension WebViewCoordinator: WKUIDelegate {
        
  public func webView(_ webView: WKWebView,
                      createWebViewWith configuration: WKWebViewConfiguration,
                      for navigationAction: WKNavigationAction,
                      windowFeatures: WKWindowFeatures) -> WKWebView? {

      let frame = UIScreen.main.bounds
      createWebView = WKWebView(frame: frame, configuration: configuration)
      
      let preferences = WKPreferences()
      preferences.javaScriptEnabled = true
      preferences.javaScriptCanOpenWindowsAutomatically = true
      
      let configuration = WKWebViewConfiguration()
      configuration.allowsInlineMediaPlayback = true
      configuration.mediaTypesRequiringUserActionForPlayback = .all
      configuration.preferences = preferences
      
      createWebView?.allowsBackForwardNavigationGestures = true
      createWebView?.scrollView.isScrollEnabled = true
      createWebView?.isOpaque = true
      
      createWebView?.translatesAutoresizingMaskIntoConstraints = false
      createWebView?.scrollView.bounces = true
      createWebView?.scrollView.showsHorizontalScrollIndicator = false
      createWebView?.scrollView.scrollsToTop = true
      
      createWebView?.backgroundColor = .white
      
      //오토레이아웃 처리
      createWebView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      createWebView?.navigationDelegate = self
      createWebView?.uiDelegate = self
      createWebView?.tag = 100

      webView.addSubview(createWebView!)
      
      self.button = UIButton(type: .system)
      self.button?.frame = CGRect(x:(webView.frame.width) - 45, y:0, width: 45, height: 45)
      self.button?.backgroundColor = .white
      self.button?.setTitleColor(.black, for: .normal)
      self.button?.setTitle("close", for: .normal)
      self.button?.titleLabel?.font = UIFont.systemFont(ofSize: 15.0)
      self.button?.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
      webView.addSubview(self.button!)

      return createWebView
  }
    
    @objc func buttonAction(sender:UIButton!){
        if self.button != nil{
            self.button?.removeFromSuperview()
            self.button = nil
        }
        if(createWebView != nil) {
            createWebView?.removeFromSuperview()
            createWebView = nil
        }
    }
    
    public func webViewDidClose(_ webView: WKWebView) {
        if webView == createWebView {
            createWebView?.removeFromSuperview()
            createWebView = nil
        }
    }
}

public struct WebViewConfig {
    public static let `default` = WebViewConfig()
    
    public let javaScriptEnabled: Bool
    public let javaScriptCanOpenWindowsAutomatically: Bool
    public let allowsBackForwardNavigationGestures: Bool
    public let allowsInlineMediaPlayback: Bool
    public let mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes
    public let isScrollEnabled: Bool
    public let isOpaque: Bool
    public let backgroundColor: Color
    
    public init(javaScriptEnabled: Bool = true,
                javaScriptCanOpenWindowsAutomatically: Bool = true,
                allowsBackForwardNavigationGestures: Bool = true,
                allowsInlineMediaPlayback: Bool = true,
                mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = [],
                isScrollEnabled: Bool = true,
                isOpaque: Bool = true,
                backgroundColor: Color = .clear) {
        self.javaScriptEnabled = javaScriptEnabled
        self.javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindowsAutomatically
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.mediaTypesRequiringUserActionForPlayback = mediaTypesRequiringUserActionForPlayback
        self.isScrollEnabled = isScrollEnabled
        self.isOpaque = isOpaque
        self.backgroundColor = backgroundColor
    }
}

#if os(iOS)
public struct WebView: UIViewRepresentable {
    let config: WebViewConfig
    @Binding var action: WebViewAction
    @Binding var state: WebViewState
    let restrictedPages: [String]?
    let htmlInState: Bool
    let schemeHandlers: [String: (URL) -> Void]
    
    public init(config: WebViewConfig = .default,
                action: Binding<WebViewAction>,
                state: Binding<WebViewState>,
                restrictedPages: [String]? = nil,
                htmlInState: Bool = false,
                schemeHandlers: [String: (URL) -> Void] = [:]) {
        self.config = config
        _action = action
        _state = state
        self.restrictedPages = restrictedPages
        self.htmlInState = htmlInState
        self.schemeHandlers = schemeHandlers
    }
    
    public func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(webView: self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = config.javaScriptEnabled
        preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = config.allowsInlineMediaPlayback
        configuration.mediaTypesRequiringUserActionForPlayback = config.mediaTypesRequiringUserActionForPlayback
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = config.isScrollEnabled
        webView.isOpaque = config.isOpaque
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.bounces = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.scrollsToTop = true
        
        if #available(iOS 14.0, *) {
            webView.backgroundColor = UIColor(config.backgroundColor)
        } else {
            webView.backgroundColor = .clear
        }
        
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if action == .idle || context.coordinator.actionInProgress {
            return
        }
        context.coordinator.actionInProgress = true
        switch action {
        case .idle:
            break
        case .load(let request):
            uiView.load(request)
        case .loadHTML(let pageHTML):
            uiView.loadHTMLString(pageHTML, baseURL: nil)
        case .reload:
            uiView.reload()
        case .goBack:
            uiView.goBack()
        case .goForward:
            uiView.goForward()
        case .evaluateJS(let command, let callback):
            uiView.evaluateJavaScript(command) { result, error in
                if let error = error {
                    callback(.failure(error))
                } else {
                    callback(.success(result))
                }
            }
        }
    }
}
#endif
