//
//  ViewerViewController+Preview.swift
//  iOS_DICOMViewer
//
//  SwiftUI Preview for ViewerViewController
//

#if DEBUG
import SwiftUI

struct ViewerViewControllerPreview: UIViewControllerRepresentable {
    let studyType: StudyType
    
    enum StudyType {
        case ct, mr, xray, petct
    }
    
    init(studyType: StudyType = .ct) {
        self.studyType = studyType
    }
    
    func makeUIViewController(context: Context) -> ViewerViewController {
        // Create a simple mock study for preview
        let mockStudy = DICOMStudy(
            studyInstanceUID: "1.2.3.4.5.6.7.8.9.10",
            studyDate: "20241201",
            studyTime: "143000",
            studyDescription: "Mock Study for Preview",
            patientName: "DEMO^PATIENT",
            patientID: "PREVIEW001",
            patientBirthDate: "19850315",
            patientSex: "M",
            accessionNumber: "PREVIEW001"
        )
        
        // Add a mock series
        let mockSeries = DICOMSeries(
            seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10.1",
            seriesNumber: 1,
            seriesDescription: "Preview Series",
            modality: "CT",
            studyInstanceUID: mockStudy.studyInstanceUID
        )
        
        mockStudy.addSeries(mockSeries)
        
        return ViewerViewController(study: mockStudy)
    }
    
    func updateUIViewController(_ uiViewController: ViewerViewController, context: Context) {
        // No updates needed for preview
    }
}

#Preview("DICOM Viewer (CT)") {
    ViewerViewControllerPreview(studyType: .ct)
}

#Preview("DICOM Viewer (MR)") {
    ViewerViewControllerPreview(studyType: .mr)
}

#Preview("DICOM Viewer (X-Ray)") {
    ViewerViewControllerPreview(studyType: .xray)
}

#Preview("DICOM Viewer (PET/CT)") {
    ViewerViewControllerPreview(studyType: .petct)
}

#Preview("DICOM Viewer (Dark)") {
    ViewerViewControllerPreview(studyType: .ct)
        .preferredColorScheme(.dark)
}

#Preview("DICOM Viewer (iPad)") {
    ViewerViewControllerPreview(studyType: .ct)
}
#endif
