#!/usr/bin/env python3

import sys
import re
import shutil
import uuid

def add_files_to_xcode_project():
    project_file = "/Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Make backup
    shutil.copy(project_file, project_file + ".backup_add_files")
    
    # Files to add
    files_to_add = [
        {
            'name': 'AutomaticSegmentationService.swift',
            'path': 'iOS_DICOMViewer/Core/Services/AutomaticSegmentationService.swift'
        },
        {
            'name': 'UrinaryTractSegmentationService.swift', 
            'path': 'iOS_DICOMViewer/Core/Services/UrinaryTractSegmentationService.swift'
        },
        {
            'name': 'CoreMLSegmentationService.swift',
            'path': 'iOS_DICOMViewer/Core/Services/CoreMLSegmentationService.swift'
        },
        {
            'name': 'ModernStudyCell.swift',
            'path': 'iOS_DICOMViewer/ViewControllers/ModernStudyCell.swift'
        },
        {
            'name': 'StudyHeaderView.swift',
            'path': 'iOS_DICOMViewer/ViewControllers/StudyHeaderView.swift'
        }
    ]
    
    # Generate UUIDs for the new files
    file_refs = {}
    build_refs = {}
    
    for file_info in files_to_add:
        file_refs[file_info['name']] = str(uuid.uuid4()).replace('-', '').upper()[:24]
        build_refs[file_info['name']] = str(uuid.uuid4()).replace('-', '').upper()[:24]
    
    # Add PBXBuildFile entries
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/', content, re.DOTALL)
    if build_file_section:
        build_section_content = build_file_section.group(1)
        
        # Add new build file entries
        new_build_entries = ""
        for file_info in files_to_add:
            new_build_entries += f"\t\t{build_refs[file_info['name']]} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[file_info['name']]} /* {file_info['name']} */; }};\n"
        
        # Insert new entries at the end of the build files section
        updated_build_section = build_section_content.rstrip() + "\n" + new_build_entries
        content = content.replace(build_section_content, updated_build_section)
    
    # Add PBXFileReference entries
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/(.*?)/\* End PBXFileReference section \*/', content, re.DOTALL)
    if file_ref_section:
        file_section_content = file_ref_section.group(1)
        
        # Add new file reference entries
        new_file_entries = ""
        for file_info in files_to_add:
            new_file_entries += f"\t\t{file_refs[file_info['name']]} /* {file_info['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_info['name']}; sourceTree = \"<group>\"; }};\n"
        
        # Insert new entries at the end of the file references section
        updated_file_section = file_section_content.rstrip() + "\n" + new_file_entries
        content = content.replace(file_section_content, updated_file_section)
    
    # Add to Core/Services group for segmentation services
    services_group_pattern = r'(\/\* Core\/Services \*/ = \{[^}]+children = \([^)]*)'
    if re.search(services_group_pattern, content):
        services_group = re.search(services_group_pattern, content).group(1)
        new_services_group = services_group + f"\n\t\t\t\t{file_refs['AutomaticSegmentationService.swift']} /* AutomaticSegmentationService.swift */,"
        new_services_group += f"\n\t\t\t\t{file_refs['UrinaryTractSegmentationService.swift']} /* UrinaryTractSegmentationService.swift */,"
        new_services_group += f"\n\t\t\t\t{file_refs['CoreMLSegmentationService.swift']} /* CoreMLSegmentationService.swift */,"
        content = content.replace(services_group, new_services_group)
    
    # Add to ViewControllers group for UI files
    vc_group_pattern = r'(\/\* ViewControllers \*/ = \{[^}]+children = \([^)]*)'
    if re.search(vc_group_pattern, content):
        vc_group = re.search(vc_group_pattern, content).group(1)
        new_vc_group = vc_group + f"\n\t\t\t\t{file_refs['ModernStudyCell.swift']} /* ModernStudyCell.swift */,"
        new_vc_group += f"\n\t\t\t\t{file_refs['StudyHeaderView.swift']} /* StudyHeaderView.swift */,"
        content = content.replace(vc_group, new_vc_group)
    
    # Add to Sources build phase
    sources_build_phase_pattern = r'(\/\* Sources \*/ = \{[^}]+files = \([^)]*)'
    if re.search(sources_build_phase_pattern, content):
        sources_phase = re.search(sources_build_phase_pattern, content).group(1)
        new_sources_phase = sources_phase
        for file_info in files_to_add:
            new_sources_phase += f"\n\t\t\t\t{build_refs[file_info['name']]} /* {file_info['name']} in Sources */,"
        content = content.replace(sources_phase, new_sources_phase)
    
    # Write the updated content back
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Added missing files to Xcode project:")
    for file_info in files_to_add:
        print(f"  - {file_info['name']}")

if __name__ == "__main__":
    add_files_to_xcode_project()