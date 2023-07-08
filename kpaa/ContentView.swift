//
//  ContentView.swift
//  kpaa
//
//  Created by rrobbie on 2023/03/16.
//

import SwiftUI

 struct ContentView: View {
    @State private var action = WebViewAction.idle
    @State private var state = WebViewState.empty
    @State private var address = "https://mobile.kpaa.or.kr:447/main/main.php"
         
    var body: some View {
        VStack(spacing: 0) {
            navigationToolbar
            WebView(action: $action,
                    state: $state,
                    restrictedPages: [address],
                    htmlInState: true
                )
                .onAppear {
                    if let url = URL(string: address) {
                        action = .load(URLRequest(url: url))
                    }
                }
        }
    }
     
     private var titleView: some View {
         Text(String("대한변리사회"))
             .font(.system(size: 18))
     }
     
     private var navigationToolbar: some View {
             HStack(spacing: 10) {
                 // titleView
                 Spacer()
                 
                 Button(action: {
                     if(state.canGoBack) {
                         action = .goBack
                     }
                 }) {
                     Image(systemName: "chevron.left")
                         .imageScale(.large).disabled(state.canGoBack ? false : true)
                 }
                 
                 Button(action: {
                     if(state.canGoForward) {
                         action = .goForward
                     }
                 }) {
                 Image(systemName: "chevron.right")
                     .imageScale(.large).disabled(state.canGoForward ? false : true)
                     
                 }
                 
             }.padding()
         }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
