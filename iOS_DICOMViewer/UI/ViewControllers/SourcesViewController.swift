//
//  SourcesViewController.swift
//  iOS_DICOMViewer
//
//  Sources configuration view
//

import UIKit

class SourcesViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Sources"
        view.backgroundColor = MedicalColorPalette.primaryDark
        
        // Add close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        
        // Add placeholder content
        let label = UILabel()
        label.text = "DICOM Sources\nConfiguration"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}