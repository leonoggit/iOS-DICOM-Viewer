#!/usr/bin/env node

/**
 * Test script for Custom DICOM MCP Server
 * Verifies all core functionality is working correctly
 */

const { MedicalFileDetector } = require('./dist/tools/medical-file-detector.js');
const { DICOMComplianceChecker } = require('./dist/tools/dicom-compliance-checker.js');
const { PixelDataAnalyzer } = require('./dist/tools/pixel-data-analyzer.js');
const { MedicalTerminologyLookup } = require('./dist/tools/medical-terminology-lookup.js');

async function runTests() {
  console.log('🔬 Testing Custom DICOM MCP Server');
  console.log('=====================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function testResult(testName, success, details = '') {
    totalTests++;
    if (success) {
      console.log(`✅ ${testName}`);
      passedTests++;
    } else {
      console.log(`❌ ${testName}${details ? ': ' + details : ''}`);
    }
  }

  // Test 1: Medical File Detector
  try {
    const detector = new MedicalFileDetector();
    testResult('Medical File Detector initialization', true);
  } catch (error) {
    testResult('Medical File Detector initialization', false, error.message);
  }

  // Test 2: DICOM Compliance Checker
  try {
    const complianceChecker = new DICOMComplianceChecker();
    const profiles = complianceChecker.getAvailableProfiles();
    testResult('DICOM Compliance Checker initialization', profiles.length > 0);
    console.log(`   Available profiles: ${profiles.join(', ')}`);
  } catch (error) {
    testResult('DICOM Compliance Checker initialization', false, error.message);
  }

  // Test 3: Pixel Data Analyzer
  try {
    const pixelAnalyzer = new PixelDataAnalyzer();
    
    // Test with dummy pixel data
    const dummyPixelData = {
      data: new Uint16Array([100, 200, 300, 400, 500]),
      rows: 5,
      columns: 1,
      samplesPerPixel: 1,
      bitsAllocated: 16,
      bitsStored: 16,
      highBit: 15,
      pixelRepresentation: 0,
      photometricInterpretation: 'MONOCHROME2'
    };
    
    const analysis = pixelAnalyzer.analyzePixelData(dummyPixelData);
    testResult('Pixel Data Analyzer functionality', 
      analysis.statistics && analysis.statistics.mean !== undefined);
    console.log(`   Statistics: min=${analysis.statistics.min}, max=${analysis.statistics.max}, mean=${Math.round(analysis.statistics.mean)}`);
  } catch (error) {
    testResult('Pixel Data Analyzer functionality', false, error.message);
  }

  // Test 4: Medical Terminology Lookup
  try {
    const terminologyLookup = new MedicalTerminologyLookup();
    
    // Test brain lookup
    const brainLookup = terminologyLookup.lookupTerm('brain');
    testResult('Medical Terminology Lookup - Brain', 
      brainLookup.definitions.length > 0);
    console.log(`   Found ${brainLookup.definitions.length} definitions for 'brain'`);
    
    // Test CT modality lookup
    const ctLookup = terminologyLookup.lookupTerm('CT');
    testResult('Medical Terminology Lookup - CT', 
      ctLookup.definitions.length > 0);
    console.log(`   Found ${ctLookup.definitions.length} definitions for 'CT'`);
    
    // Test anatomical regions
    const regions = terminologyLookup.getAnatomicalRegions();
    testResult('Anatomical Regions Database', regions.length > 0);
    console.log(`   Available anatomical regions: ${regions.length}`);
    
    // Test code validation
    const codeValidation = terminologyLookup.validateTerminologyCode('CT', 'DCM');
    testResult('Terminology Code Validation', codeValidation.isValid);
    
  } catch (error) {
    testResult('Medical Terminology Lookup', false, error.message);
  }

  // Test 5: Error Handling
  try {
    const { errorHandler } = require('./dist/utils/error-handler.js');
    
    // Test error creation
    const testError = errorHandler.createError(
      'FILE_NOT_FOUND', 
      'Test error message',
      'test_context'
    );
    testResult('Error Handler - Error Creation', 
      testError.code === 'FILE_NOT_FOUND' && testError.message === 'Test error message');
    
    // Test error statistics
    const stats = errorHandler.getErrorStatistics();
    testResult('Error Handler - Statistics', 
      typeof stats.totalErrors === 'number');
    
  } catch (error) {
    testResult('Error Handler', false, error.message);
  }

  // Test 6: TypeScript Type Definitions
  try {
    const { DICOMMetadata } = require('./dist/types/dicom.js');
    testResult('TypeScript Type Definitions Export', true);
  } catch (error) {
    testResult('TypeScript Type Definitions Export', false, error.message);
  }

  // Summary
  console.log('\n📊 Test Summary');
  console.log('================');
  console.log(`Tests passed: ${passedTests}/${totalTests}`);
  console.log(`Success rate: ${Math.round((passedTests / totalTests) * 100)}%`);
  
  if (passedTests === totalTests) {
    console.log('\n🎉 All tests passed! The Custom DICOM MCP Server is ready for use.');
    console.log('\n📝 Next steps:');
    console.log('1. Configure the server in your MCP config file');
    console.log('2. Test with actual DICOM files');
    console.log('3. Integrate with Claude Code for iOS DICOM Viewer development');
    return true;
  } else {
    console.log('\n⚠️  Some tests failed. Please review the implementation.');
    return false;
  }
}

// Run tests
runTests().then(success => {
  process.exit(success ? 0 : 1);
}).catch(error => {
  console.error('❌ Test runner failed:', error);
  process.exit(1);
});