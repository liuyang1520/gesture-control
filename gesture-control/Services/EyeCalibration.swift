//
//  EyeCalibration.swift
//  gesture-control
//
//  Created by Codex on 2026-04-04.
//

import CoreGraphics
import Foundation

struct EyeFeatureVector: Codable, Equatable {
  let faceCenterX: Double
  let faceCenterY: Double
  let pupilOffsetX: Double
  let pupilOffsetY: Double

  var designRow: [Double] {
    [1.0, faceCenterX, faceCenterY, pupilOffsetX, pupilOffsetY]
  }

  static func average(_ vectors: [EyeFeatureVector]) -> EyeFeatureVector? {
    guard !vectors.isEmpty else { return nil }

    let count = Double(vectors.count)
    let sum = vectors.reduce(into: (faceX: 0.0, faceY: 0.0, pupilX: 0.0, pupilY: 0.0)) {
      partialResult,
      vector in
      partialResult.faceX += vector.faceCenterX
      partialResult.faceY += vector.faceCenterY
      partialResult.pupilX += vector.pupilOffsetX
      partialResult.pupilY += vector.pupilOffsetY
    }

    return EyeFeatureVector(
      faceCenterX: sum.faceX / count,
      faceCenterY: sum.faceY / count,
      pupilOffsetX: sum.pupilX / count,
      pupilOffsetY: sum.pupilY / count
    )
  }
}

struct EyeCalibrationSample: Codable, Equatable {
  let feature: EyeFeatureVector
  let targetX: Double
  let targetY: Double

  init(feature: EyeFeatureVector, target: CGPoint) {
    self.feature = feature
    self.targetX = target.x
    self.targetY = target.y
  }

  var targetPoint: CGPoint {
    CGPoint(x: targetX, y: targetY)
  }
}

struct EyeCalibrationModel: Codable, Equatable {
  let xCoefficients: [Double]
  let yCoefficients: [Double]

  func map(feature: EyeFeatureVector) -> CGPoint {
    let row = feature.designRow
    return CGPoint(
      x: Self.clamp01(Self.dot(row, xCoefficients)),
      y: Self.clamp01(Self.dot(row, yCoefficients))
    )
  }

  static func fit(samples: [EyeCalibrationSample]) -> EyeCalibrationModel? {
    guard samples.count >= 5 else { return nil }

    let rows = samples.map { $0.feature.designRow }
    guard let width = rows.first?.count, width == 5 else { return nil }

    let xTargets = samples.map(\.targetX)
    let yTargets = samples.map(\.targetY)

    guard
      let xCoefficients = solveLeastSquares(rows: rows, values: xTargets),
      let yCoefficients = solveLeastSquares(rows: rows, values: yTargets)
    else { return nil }

    return EyeCalibrationModel(
      xCoefficients: xCoefficients,
      yCoefficients: yCoefficients
    )
  }

  private static func solveLeastSquares(rows: [[Double]], values: [Double]) -> [Double]? {
    guard let columnCount = rows.first?.count, values.count == rows.count else { return nil }

    var normalMatrix = Array(
      repeating: Array(repeating: 0.0, count: columnCount),
      count: columnCount
    )
    var rightHandSide = Array(repeating: 0.0, count: columnCount)

    for (row, value) in zip(rows, values) {
      guard row.count == columnCount else { return nil }
      for i in 0..<columnCount {
        rightHandSide[i] += row[i] * value
        for j in 0..<columnCount {
          normalMatrix[i][j] += row[i] * row[j]
        }
      }
    }

    return gaussianSolve(matrix: normalMatrix, values: rightHandSide)
  }

  private static func gaussianSolve(matrix: [[Double]], values: [Double]) -> [Double]? {
    guard
      matrix.count == values.count,
      let width = matrix.first?.count,
      width == values.count
    else {
      return nil
    }

    var matrix = matrix
    var values = values
    let count = values.count
    let epsilon = 1e-9

    for pivotIndex in 0..<count {
      var maxRow = pivotIndex
      var maxValue = abs(matrix[pivotIndex][pivotIndex])

      for row in (pivotIndex + 1)..<count {
        let candidate = abs(matrix[row][pivotIndex])
        if candidate > maxValue {
          maxValue = candidate
          maxRow = row
        }
      }

      guard maxValue > epsilon else { return nil }

      if maxRow != pivotIndex {
        matrix.swapAt(maxRow, pivotIndex)
        values.swapAt(maxRow, pivotIndex)
      }

      let pivot = matrix[pivotIndex][pivotIndex]
      for column in pivotIndex..<count {
        matrix[pivotIndex][column] /= pivot
      }
      values[pivotIndex] /= pivot

      for row in 0..<count where row != pivotIndex {
        let factor = matrix[row][pivotIndex]
        guard abs(factor) > epsilon else { continue }

        for column in pivotIndex..<count {
          matrix[row][column] -= factor * matrix[pivotIndex][column]
        }
        values[row] -= factor * values[pivotIndex]
      }
    }

    return values
  }

  private static func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
    zip(lhs, rhs).reduce(0.0) { partialResult, pair in
      partialResult + pair.0 * pair.1
    }
  }

  private static func clamp01(_ value: Double) -> Double {
    min(max(value, 0.0), 1.0)
  }
}
