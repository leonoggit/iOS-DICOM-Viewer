import CoreML
import Vision

class TotalSegmentatorWrapper {
    private let model: MLModel
    
    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        // Update the model name to match the .mlpackage file name
        self.model = try TotalSegmentator_Simplified(configuration: config).model
    }
    
    func segment(ctVolume: MLMultiArray) throws -> MLMultiArray {
        let input = TotalSegmentator_SimplifiedInput(ct_scan: ctVolume)
        let output = try model.prediction(input: input)
        return output.output
    }
}
