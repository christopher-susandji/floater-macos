//
//  Constants.swift
//  Floater
//
//  Created by Christopher Susandji on 20/08/26.
//

import Foundation
import SwiftUI

typealias Sizing = Constants.Sizing
typealias FloaterColor = Constants.Color

enum Constants {
    enum Sizing {
        /// 2pt
        static let xxs: CGFloat = 2
        /// 4pt
        static let xs: CGFloat = 4
        /// 8pt
        static let sm: CGFloat = 8
        /// 12pt — default stack spacing
        static let md: CGFloat = 12
        /// 16pt — section/panel padding
        static let lg: CGFloat = 16
        /// 24pt
        static let xl: CGFloat = 24
        /// 32pt — large section spacing
        static let xxl: CGFloat = 32
    }
    
    enum Color {
        static let gold = SwiftUI.Color(#colorLiteral(red: 0.835, green: 0.635, blue: 0.29, alpha: 1)) // #d5a24a
        static let vintageBrown = SwiftUI.Color(#colorLiteral(red: 0.612, green: 0.416, blue: 0.184, alpha: 1)) // #9c6a2f
        static let vintageRedBrown = SwiftUI.Color(#colorLiteral(red: 0.557, green: 0.275, blue: 0.192, alpha: 1)) // #8e4631
        static let vintageDarkBrown = SwiftUI.Color(#colorLiteral(red: 0.243, green: 0.169, blue: 0.129, alpha: 1)) // #3e2b21
    }
    
    static let characterLimit = 16
    
    // - MARK: STRING
    static let untitled = "UNTITLED"
    static let timerTitle = "TIMER TITLE"
    static let paused = "PAUSED"
    static let pausedIcon = "􀊆"
    static let changeTimerButton = "Change Timer"
    static let createTimerButton = "Create Timer"
}
