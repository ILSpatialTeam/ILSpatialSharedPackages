//
//  SpatialRuntime.swift
//  CockpitDomain
//
//  Created by Tafani Rabbani on 03/08/26.
//

import Foundation
import simd

@MainActor
public enum SpatialRuntime {
    public static var handPoseProvider: (any HandPoseProviding)?
}
