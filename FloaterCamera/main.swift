//
//  main.swift
//  FloaterCamera
//
//  Created by Christopher Susandji on 07/09/26.
//

import Foundation
import CoreMediaIO

let source = FloaterProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: source.provider)

CFRunLoopRun()
