import Foundation

/// DICOM metadata structure inspired by OHIF's metadata organization
struct DICOMMetadata {
    let patientName: String?
    let patientID: String?
    let patientBirthDate: String?
    let patientSex: String?
    let studyInstanceUID: String
    let studyDate: String?
    let studyTime: String?
    let studyDescription: String?
    let seriesInstanceUID: String
    let seriesNumber: Int?
    let seriesDescription: String?
    let modality: String
    let sopInstanceUID: String
    let instanceNumber: Int?
    
    // Image-specific metadata
    let rows: Int
    let columns: Int
    let bitsAllocated: Int
    let bitsStored: Int
    let samplesPerPixel: Int
    let photometricInterpretation: String?
    let pixelRepresentation: Int
    let pixelSpacing: [Double]?
    let sliceThickness: Double?
    let imagePositionPatient: [Double]?
    let imageOrientationPatient: [Double]?
    let frameOfReferenceUID: String?
    
    // Window/Level
    let windowCenter: [Double]?
    let windowWidth: [Double]?
    let rescaleIntercept: Double?
    let rescaleSlope: Double?
    
    // Multi-frame support
    let numberOfFrames: Int?
    
    init(dictionary: [String: Any]) {
        self.patientName = dictionary["PatientName"] as? String
        self.patientID = dictionary["PatientID"] as? String
        self.patientBirthDate = dictionary["PatientBirthDate"] as? String
        self.patientSex = dictionary["PatientSex"] as? String
        
        self.studyInstanceUID = dictionary["StudyInstanceUID"] as? String ?? ""
        self.studyDate = dictionary["StudyDate"] as? String
        self.studyTime = dictionary["StudyTime"] as? String
        self.studyDescription = dictionary["StudyDescription"] as? String
        
        self.seriesInstanceUID = dictionary["SeriesInstanceUID"] as? String ?? ""
        self.seriesNumber = dictionary["SeriesNumber"] as? Int
        self.seriesDescription = dictionary["SeriesDescription"] as? String
        self.modality = dictionary["Modality"] as? String ?? "UNKNOWN"
        
        self.sopInstanceUID = dictionary["SOPInstanceUID"] as? String ?? ""
        self.instanceNumber = dictionary["InstanceNumber"] as? Int
        
        self.rows = dictionary["Rows"] as? Int ?? 0
        self.columns = dictionary["Columns"] as? Int ?? 0
        self.bitsAllocated = dictionary["BitsAllocated"] as? Int ?? 8
        self.bitsStored = dictionary["BitsStored"] as? Int ?? 8
        self.samplesPerPixel = dictionary["SamplesPerPixel"] as? Int ?? 1
        self.photometricInterpretation = dictionary["PhotometricInterpretation"] as? String
        self.pixelRepresentation = dictionary["PixelRepresentation"] as? Int ?? 0
        
        self.pixelSpacing = dictionary["PixelSpacing"] as? [Double]
        self.sliceThickness = dictionary["SliceThickness"] as? Double
        self.imagePositionPatient = dictionary["ImagePositionPatient"] as? [Double]
        self.imageOrientationPatient = dictionary["ImageOrientationPatient"] as? [Double]
        self.frameOfReferenceUID = dictionary["FrameOfReferenceUID"] as? String
        
        self.windowCenter = dictionary["WindowCenter"] as? [Double]
        self.windowWidth = dictionary["WindowWidth"] as? [Double]
        self.rescaleIntercept = dictionary["RescaleIntercept"] as? Double
        self.rescaleSlope = dictionary["RescaleSlope"] as? Double
        
        self.numberOfFrames = dictionary["NumberOfFrames"] as? Int
    }
    
    var isMultiFrame: Bool {
        return (numberOfFrames ?? 1) > 1
    }
    
    var defaultWindowCenter: Double {
        return windowCenter?.first ?? (bitsStored > 8 ? 32768.0 : 128.0)
    }
    
    var defaultWindowWidth: Double {
        return windowWidth?.first ?? (bitsStored > 8 ? 65536.0 : 256.0)
    }
}
