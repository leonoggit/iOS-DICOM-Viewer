//
//  MockDataProvider.swift
//  iOS_DICOMViewer
//
//  Mock data provider for SwiftUI previews and testing
//

#if DEBUG
import Foundation

/// Provides mock DICOM data for previews and testing
class MockDataProvider {
    
    static let shared = MockDataProvider()
    
    private init() {}
    
    // MARK: - Mock Studies
    
    func createMockStudies() -> [DICOMStudy] {
        return [
            createCTChestStudy(),
            createMRBrainStudy(),
            createXRayStudy(),
            createPETCTStudy(),
            createMammographyStudy()
        ]
    }
    
    func createCTChestStudy() -> DICOMStudy {
        let study = DICOMStudy(
            studyInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.78",
            studyDate: "20241201",
            studyTime: "143000",
            studyDescription: "CT Chest with Contrast",
            patientName: "DEMO^PATIENT^CT",
            patientID: "CT001",
            patientBirthDate: "19850315",
            patientSex: "M",
            accessionNumber: "ACC001"
        )
        
        let series = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.78.1",
            seriesNumber: 1,
            seriesDescription: "Axial CT Chest",
            modality: "CT",
            studyInstanceUID: study.studyInstanceUID
        )
        
        // Add multiple instances for a realistic CT series
        for i in 1...120 {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: series.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.78.1.\(i)",
                instanceNumber: i,
                modality: "CT",
                rows: 512,
                columns: 512
            )
            let instance = DICOMInstance(metadata: metadata)
            series.addInstance(instance)
        }
        
        study.addSeries(series)
        return study
    }
    
    func createMRBrainStudy() -> DICOMStudy {
        let study = DICOMStudy(
            studyInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.79",
            studyDate: "20241130",
            studyTime: "091500",
            studyDescription: "MR Brain without Contrast",
            patientName: "DEMO^PATIENT^MR",
            patientID: "MR001",
            patientBirthDate: "19920708",
            patientSex: "F",
            accessionNumber: "ACC002"
        )
        
        // T1 Sagittal Series
        let t1Series = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.79.1",
            seriesNumber: 1,
            seriesDescription: "T1 Sagittal",
            modality: "MR",
            studyInstanceUID: study.studyInstanceUID
        )
        
        for i in 1...25 {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: t1Series.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.79.1.\(i)",
                instanceNumber: i,
                modality: "MR",
                rows: 256,
                columns: 256
            )
            let instance = DICOMInstance(metadata: metadata)
            t1Series.addInstance(instance)
        }
        
        // T2 Axial Series
        let t2Series = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.79.2",
            seriesNumber: 2,
            seriesDescription: "T2 Axial",
            modality: "MR",
            studyInstanceUID: study.studyInstanceUID
        )
        
        for i in 1...30 {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: t2Series.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.79.2.\(i)",
                instanceNumber: i,
                modality: "MR",
                rows: 256,
                columns: 256
            )
            let instance = DICOMInstance(metadata: metadata)
            t2Series.addInstance(instance)
        }
        
        study.addSeries(t1Series)
        study.addSeries(t2Series)
        return study
    }
    
    func createXRayStudy() -> DICOMStudy {
        let study = DICOMStudy(
            studyInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.80",
            studyDate: "20241129",
            studyTime: "161200",
            studyDescription: "Chest X-Ray PA and Lateral",
            patientName: "DEMO^PATIENT^XR",
            patientID: "XR001",
            patientBirthDate: "19751122",
            patientSex: "M",
            accessionNumber: "ACC003"
        )
        
        let series = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.80.1",
            seriesNumber: 1,
            seriesDescription: "PA and Lateral Views",
            modality: "CR",
            studyInstanceUID: study.studyInstanceUID
        )
        
        // PA View
        let paMetadata = createMockMetadata(
            studyUID: study.studyInstanceUID,
            seriesUID: series.seriesInstanceUID,
            sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.80.1.1",
            instanceNumber: 1,
            modality: "CR",
            rows: 2048,
            columns: 2048
        )
        let paInstance = DICOMInstance(metadata: paMetadata)
        series.addInstance(paInstance)
        
        // Lateral View
        let lateralMetadata = createMockMetadata(
            studyUID: study.studyInstanceUID,
            seriesUID: series.seriesInstanceUID,
            sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.80.1.2",
            instanceNumber: 2,
            modality: "CR",
            rows: 2048,
            columns: 2048
        )
        let lateralInstance = DICOMInstance(metadata: lateralMetadata)
        series.addInstance(lateralInstance)
        
        study.addSeries(series)
        return study
    }
    
    func createPETCTStudy() -> DICOMStudy {
        let study = DICOMStudy(
            studyInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.81",
            studyDate: "20241128",
            studyTime: "103000",
            studyDescription: "PET/CT Whole Body",
            patientName: "DEMO^PATIENT^PETCT",
            patientID: "PETCT001",
            patientBirthDate: "19680425",
            patientSex: "F",
            accessionNumber: "ACC004"
        )
        
        // CT Series
        let ctSeries = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.81.1",
            seriesNumber: 1,
            seriesDescription: "CT Whole Body",
            modality: "CT",
            studyInstanceUID: study.studyInstanceUID
        )
        
        for i in 1...200 {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: ctSeries.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.81.1.\(i)",
                instanceNumber: i,
                modality: "CT",
                rows: 512,
                columns: 512
            )
            let instance = DICOMInstance(metadata: metadata)
            ctSeries.addInstance(instance)
        }
        
        // PET Series
        let petSeries = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.81.2",
            seriesNumber: 2,
            seriesDescription: "PET Whole Body",
            modality: "PT",
            studyInstanceUID: study.studyInstanceUID
        )
        
        for i in 1...200 {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: petSeries.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.81.2.\(i)",
                instanceNumber: i,
                modality: "PT",
                rows: 128,
                columns: 128
            )
            let instance = DICOMInstance(metadata: metadata)
            petSeries.addInstance(instance)
        }
        
        study.addSeries(ctSeries)
        study.addSeries(petSeries)
        return study
    }
    
    func createMammographyStudy() -> DICOMStudy {
        let study = DICOMStudy(
            studyInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.82",
            studyDate: "20241127",
            studyTime: "140000",
            studyDescription: "Digital Mammography Bilateral",
            patientName: "DEMO^PATIENT^MAMMO",
            patientID: "MAMMO001",
            patientBirthDate: "19800910",
            patientSex: "F",
            accessionNumber: "ACC005"
        )
        
        let series = DICOMSeries(
            seriesInstanceUID: "1.2.840.113619.2.5.1762583153.215519.978957063.82.1",
            seriesNumber: 1,
            seriesDescription: "Bilateral Mammography",
            modality: "MG",
            studyInstanceUID: study.studyInstanceUID
        )
        
        let views = ["RCC", "RMLO", "LCC", "LMLO"]
        for (index, view) in views.enumerated() {
            let metadata = createMockMetadata(
                studyUID: study.studyInstanceUID,
                seriesUID: series.seriesInstanceUID,
                sopUID: "1.2.840.113619.2.5.1762583153.215519.978957063.82.1.\(index + 1)",
                instanceNumber: index + 1,
                modality: "MG",
                rows: 3328,
                columns: 2560
            )
            let instance = DICOMInstance(metadata: metadata)
            series.addInstance(instance)
        }
        
        study.addSeries(series)
        return study
    }
    
    // MARK: - Mock Metadata Helper
    
    private func createMockMetadata(
        studyUID: String,
        seriesUID: String,
        sopUID: String,
        instanceNumber: Int,
        modality: String,
        rows: Int,
        columns: Int
    ) -> DICOMMetadata {
        var dictionary: [String: Any] = [
            "StudyInstanceUID": studyUID,
            "SeriesInstanceUID": seriesUID,
            "SOPInstanceUID": sopUID,
            "InstanceNumber": instanceNumber,
            "Modality": modality,
            "Rows": rows,
            "Columns": columns,
            "BitsAllocated": 16,
            "BitsStored": modality == "CT" ? 12 : 16,
            "SamplesPerPixel": 1,
            "PhotometricInterpretation": "MONOCHROME2",
            "PixelRepresentation": 0
        ]
        
        // Add modality-specific metadata
        switch modality {
        case "CT":
            dictionary["WindowCenter"] = [40.0]
            dictionary["WindowWidth"] = [400.0]
            dictionary["RescaleIntercept"] = -1024.0
            dictionary["RescaleSlope"] = 1.0
            dictionary["SliceThickness"] = 1.25
            dictionary["PixelSpacing"] = [0.6836, 0.6836]
            
        case "MR":
            dictionary["WindowCenter"] = [128.0]
            dictionary["WindowWidth"] = [256.0]
            dictionary["SliceThickness"] = 5.0
            dictionary["PixelSpacing"] = [0.9375, 0.9375]
            
        case "CR", "MG":
            dictionary["WindowCenter"] = [2048.0]
            dictionary["WindowWidth"] = [4096.0]
            dictionary["PixelSpacing"] = [0.1, 0.1]
            
        case "PT":
            dictionary["WindowCenter"] = [1.0]
            dictionary["WindowWidth"] = [2.0]
            dictionary["SliceThickness"] = 3.27
            dictionary["PixelSpacing"] = [4.0625, 4.0625]
            
        default:
            break
        }
        
        return DICOMMetadata(dictionary: dictionary)
    }
    
    // MARK: - Single Instance Helpers
    
    func createMockCTInstance() -> DICOMInstance {
        let metadata = createMockMetadata(
            studyUID: "1.2.3.4.5.6.7.8.9.1",
            seriesUID: "1.2.3.4.5.6.7.8.9.1.1",
            sopUID: "1.2.3.4.5.6.7.8.9.1.1.1",
            instanceNumber: 1,
            modality: "CT",
            rows: 512,
            columns: 512
        )
        return DICOMInstance(metadata: metadata)
    }
    
    func createMockMRInstance() -> DICOMInstance {
        let metadata = createMockMetadata(
            studyUID: "1.2.3.4.5.6.7.8.9.2",
            seriesUID: "1.2.3.4.5.6.7.8.9.2.1",
            sopUID: "1.2.3.4.5.6.7.8.9.2.1.1",
            instanceNumber: 1,
            modality: "MR",
            rows: 256,
            columns: 256
        )
        return DICOMInstance(metadata: metadata)
    }
}
#endif 