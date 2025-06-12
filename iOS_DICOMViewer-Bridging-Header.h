//
//  iOS_DICOMViewer-Bridging-Header.h
//  iOS_DICOMViewer
//
//  Created on 6/9/25.
//

#ifndef iOS_DICOMViewer_Bridging_Header_h
#define iOS_DICOMViewer_Bridging_Header_h

// Import DCMTK Bridge for Swift access
#import "DCMTKBridge.h"

// Core Foundation and other system frameworks
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// DCMTK Headers (enabled for production DICOM parsing)
// Note: These should only be uncommented after running ./build_dcmtk.sh
// and configuring Xcode project with proper library/header search paths
//
// #import "dcmtk/config/osconfig.h"
// #import "dcmtk/dcmdata/dctk.h"  
// #import "dcmtk/dcmimgle/dcmimage.h"
// #import "dcmtk/dcmimage/diregist.h"

#endif /* iOS_DICOMViewer_Bridging_Header_h */
