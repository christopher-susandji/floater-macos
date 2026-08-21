//
//  Constants.swift
//  Floater
//
//  Created by Christopher Susandji on 20/08/26.
//

import Foundation

typealias Sizing = Constants.Sizing

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
    
    static let characterLimit = 16
    
    // - MARK: STRING
    static let untitled = "UNTITLED"
    static let timerTitle = "TIMER TITLE"
    static let paused = "PAUSED"
    static let pausedIcon = "􀊆"
    static let changeTimerButton = "Change Timer"
    static let createTimerButton = "Create Timer"
}
