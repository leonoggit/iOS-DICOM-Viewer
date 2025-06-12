/**
 * Pixel Data Analyzer
 * Provides comprehensive analysis of DICOM pixel data
 */

import { 
  DICOMPixelData, 
  PixelDataStatistics,
  WindowLevelPreset
} from '../types/dicom.js';
import { 
  calculatePixelStatistics,
  calculateOptimalWindowLevel,
  getWindowLevelPresets
} from '../utils/dicom-utils.js';

export interface PixelDataAnalysis {
  statistics: PixelDataStatistics;
  recommendations: PixelDataRecommendations;
  qualityMetrics: ImageQualityMetrics;
  windowLevelSuggestions: WindowLevelPreset[];
  artifacts: ImageArtifact[];
  performance: PerformanceMetrics;
}

export interface PixelDataRecommendations {
  optimalWindowLevel: { center: number; width: number };
  displayPresets: WindowLevelPreset[];
  processingRecommendations: string[];
  renderingHints: string[];
}

export interface ImageQualityMetrics {
  contrast: number; // 0-1 scale
  sharpness: number; // 0-1 scale
  noise: number; // 0-1 scale (lower is better)
  uniformity: number; // 0-1 scale
  dynamicRange: number;
  signalToNoise: number;
  contrastToNoise: number;
}

export interface ImageArtifact {
  type: ArtifactType;
  severity: 'low' | 'medium' | 'high';
  confidence: number; // 0-1 scale
  description: string;
  location?: { x: number; y: number; width: number; height: number };
}

export enum ArtifactType {
  MOTION_BLUR = 'motion_blur',
  RING_ARTIFACT = 'ring_artifact',
  BEAM_HARDENING = 'beam_hardening',
  TRUNCATION = 'truncation',
  NOISE = 'noise',
  ALIASING = 'aliasing',
  GHOSTING = 'ghosting',
  SUSCEPTIBILITY = 'susceptibility',
  CHEMICAL_SHIFT = 'chemical_shift'
}

export interface PerformanceMetrics {
  analysisTime: number; // milliseconds
  memoryUsage: number; // bytes
  recommendedRenderingMode: string;
  estimatedLoadTime: number; // milliseconds
}

export class PixelDataAnalyzer {
  /**
   * Perform comprehensive pixel data analysis
   */
  analyzePixelData(
    pixelData: DICOMPixelData,
    modality?: string,
    metadata?: any
  ): PixelDataAnalysis {
    const startTime = Date.now();
    
    // Calculate basic statistics
    const statistics = calculatePixelStatistics(pixelData.data);
    
    // Generate recommendations
    const recommendations = this.generateRecommendations(pixelData, statistics, modality);
    
    // Assess image quality
    const qualityMetrics = this.assessImageQuality(pixelData, statistics);
    
    // Detect artifacts
    const artifacts = this.detectArtifacts(pixelData, statistics, modality);
    
    // Get window/level suggestions
    const windowLevelSuggestions = modality ? getWindowLevelPresets(modality) : [];
    
    const endTime = Date.now();
    const analysisTime = endTime - startTime;
    
    // Performance metrics
    const performance = this.calculatePerformanceMetrics(pixelData, analysisTime);
    
    return {
      statistics,
      recommendations,
      qualityMetrics,
      windowLevelSuggestions,
      artifacts,
      performance
    };
  }

  /**
   * Analyze histogram for optimal display settings
   */
  analyzeHistogram(pixelData: DICOMPixelData): {
    peaks: number[];
    valleys: number[];
    distribution: 'uniform' | 'bimodal' | 'multimodal' | 'skewed';
    recommendations: string[];
  } {
    const histogram = this.calculateDetailedHistogram(pixelData.data, 256);
    
    // Find peaks and valleys
    const peaks = this.findHistogramPeaks(histogram);
    const valleys = this.findHistogramValleys(histogram);
    
    // Determine distribution type
    const distribution = this.classifyDistribution(histogram, peaks);
    
    // Generate recommendations based on histogram analysis
    const recommendations = this.generateHistogramRecommendations(distribution, peaks.length);
    
    return {
      peaks,
      valleys,
      distribution,
      recommendations
    };
  }

  /**
   * Calculate optimal display parameters
   */
  calculateDisplayParameters(
    pixelData: DICOMPixelData,
    statistics: PixelDataStatistics,
    targetDisplayRange: [number, number] = [0, 255]
  ): {
    windowCenter: number;
    windowWidth: number;
    lookupTable: number[];
    gamma: number;
  } {
    // Calculate optimal window/level
    const { center, width } = calculateOptimalWindowLevel(statistics);
    
    // Generate lookup table for display
    const lookupTable = this.generateLookupTable(
      statistics.min,
      statistics.max,
      center,
      width,
      targetDisplayRange
    );
    
    // Calculate optimal gamma correction
    const gamma = this.calculateOptimalGamma(statistics);
    
    return {
      windowCenter: center,
      windowWidth: width,
      lookupTable,
      gamma
    };
  }

  /**
   * Detect and analyze regions of interest
   */
  detectROI(pixelData: DICOMPixelData): Array<{
    type: 'tissue' | 'bone' | 'air' | 'contrast' | 'background';
    bounds: { x: number; y: number; width: number; height: number };
    meanValue: number;
    confidence: number;
  }> {
    const { data, rows, columns } = pixelData;
    const rois: Array<{
      type: 'tissue' | 'bone' | 'air' | 'contrast' | 'background';
      bounds: { x: number; y: number; width: number; height: number };
      meanValue: number;
      confidence: number;
    }> = [];

    // Simple thresholding-based ROI detection
    const statistics = calculatePixelStatistics(data);
    
    // Define thresholds based on typical Hounsfield units for CT or intensity ranges for MR
    const thresholds = {
      air: { min: statistics.min, max: statistics.mean - statistics.standardDeviation },
      tissue: { min: statistics.mean - statistics.standardDeviation / 2, max: statistics.mean + statistics.standardDeviation / 2 },
      bone: { min: statistics.mean + statistics.standardDeviation, max: statistics.max },
      background: { min: statistics.min, max: statistics.min + (statistics.max - statistics.min) * 0.1 }
    };

    // Analyze regions (simplified implementation)
    for (const [type, threshold] of Object.entries(thresholds)) {
      const regionPixels = this.findPixelsInRange(data, rows, columns, threshold.min, threshold.max);
      
      if (regionPixels.length > (rows * columns * 0.01)) { // At least 1% of image
        const bounds = this.calculateBoundingBox(regionPixels, columns);
        const meanValue = regionPixels.reduce((sum, pixel) => sum + pixel.value, 0) / regionPixels.length;
        
        rois.push({
          type: type as any,
          bounds,
          meanValue,
          confidence: Math.min(regionPixels.length / (rows * columns), 1.0)
        });
      }
    }

    return rois;
  }

  /**
   * Generate processing recommendations
   */
  private generateRecommendations(
    pixelData: DICOMPixelData,
    statistics: PixelDataStatistics,
    modality?: string
  ): PixelDataRecommendations {
    const optimalWindowLevel = calculateOptimalWindowLevel(statistics);
    const displayPresets = modality ? getWindowLevelPresets(modality) : [];
    
    const processingRecommendations: string[] = [];
    const renderingHints: string[] = [];

    // Generate processing recommendations
    if (statistics.standardDeviation / statistics.mean > 0.3) {
      processingRecommendations.push('High noise detected - consider noise reduction filtering');
    }
    
    if (statistics.dynamicRange > 4096) {
      processingRecommendations.push('High dynamic range - use 16-bit rendering pipeline');
    } else {
      processingRecommendations.push('Standard dynamic range - 8-bit rendering acceptable');
    }
    
    if (pixelData.rows * pixelData.columns > 1024 * 1024) {
      processingRecommendations.push('Large image - implement progressive loading');
    }

    // Generate rendering hints
    if (modality === 'CT') {
      renderingHints.push('Use Hounsfield unit calibration');
      renderingHints.push('Apply appropriate CT window/level presets');
    } else if (modality === 'MR') {
      renderingHints.push('Consider T1/T2 weighting for display');
      renderingHints.push('Use appropriate MR intensity scaling');
    }
    
    if (pixelData.bitsAllocated > 8) {
      renderingHints.push('Use high-precision rendering for better quality');
    }

    return {
      optimalWindowLevel,
      displayPresets,
      processingRecommendations,
      renderingHints
    };
  }

  /**
   * Assess image quality metrics
   */
  private assessImageQuality(
    pixelData: DICOMPixelData,
    statistics: PixelDataStatistics
  ): ImageQualityMetrics {
    const { data, rows, columns } = pixelData;
    
    // Calculate contrast (using standard deviation as proxy)
    const contrast = Math.min(statistics.standardDeviation / statistics.mean, 1.0);
    
    // Calculate sharpness (using gradient magnitude)
    const sharpness = this.calculateSharpness(data, rows, columns);
    
    // Calculate noise (using high-frequency content)
    const noise = this.calculateNoise(data, rows, columns);
    
    // Calculate uniformity (using coefficient of variation)
    const uniformity = 1.0 - Math.min(statistics.standardDeviation / statistics.mean, 1.0);
    
    // Dynamic range
    const dynamicRange = statistics.dynamicRange;
    
    // Signal-to-noise ratio
    const signalToNoise = statistics.mean / statistics.standardDeviation;
    
    // Contrast-to-noise ratio (simplified)
    const contrastToNoise = contrast / noise;

    return {
      contrast,
      sharpness,
      noise,
      uniformity,
      dynamicRange,
      signalToNoise,
      contrastToNoise
    };
  }

  /**
   * Detect common imaging artifacts
   */
  private detectArtifacts(
    pixelData: DICOMPixelData,
    statistics: PixelDataStatistics,
    modality?: string
  ): ImageArtifact[] {
    const artifacts: ImageArtifact[] = [];
    const { data, rows, columns } = pixelData;

    // Detect excessive noise
    if (statistics.standardDeviation / statistics.mean > 0.4) {
      artifacts.push({
        type: ArtifactType.NOISE,
        severity: 'high',
        confidence: 0.8,
        description: 'High noise levels detected in the image'
      });
    }

    // Detect potential motion artifacts (simplified)
    const edgeVariance = this.calculateEdgeVariance(data, rows, columns);
    if (edgeVariance > statistics.standardDeviation * 2) {
      artifacts.push({
        type: ArtifactType.MOTION_BLUR,
        severity: 'medium',
        confidence: 0.6,
        description: 'Possible motion artifacts detected'
      });
    }

    // Detect truncation artifacts
    const edgePixels = this.getEdgePixels(data, rows, columns);
    const edgeMean = edgePixels.reduce((sum, val) => sum + val, 0) / edgePixels.length;
    if (Math.abs(edgeMean - statistics.mean) > statistics.standardDeviation) {
      artifacts.push({
        type: ArtifactType.TRUNCATION,
        severity: 'low',
        confidence: 0.5,
        description: 'Potential truncation artifacts at image edges'
      });
    }

    return artifacts;
  }

  /**
   * Calculate performance metrics
   */
  private calculatePerformanceMetrics(
    pixelData: DICOMPixelData,
    analysisTime: number
  ): PerformanceMetrics {
    const pixelCount = pixelData.rows * pixelData.columns;
    const bytesPerPixel = Math.ceil(pixelData.bitsAllocated / 8);
    const memoryUsage = pixelCount * bytesPerPixel * pixelData.samplesPerPixel;
    
    // Estimate rendering performance requirements
    let recommendedRenderingMode = 'standard';
    if (pixelCount > 2048 * 2048) {
      recommendedRenderingMode = 'tiled';
    } else if (pixelData.bitsAllocated > 12) {
      recommendedRenderingMode = 'high-precision';
    }
    
    // Estimate load time (simplified model)
    const estimatedLoadTime = (memoryUsage / (1024 * 1024)) * 10; // ~10ms per MB

    return {
      analysisTime,
      memoryUsage,
      recommendedRenderingMode,
      estimatedLoadTime
    };
  }

  /**
   * Calculate detailed histogram
   */
  private calculateDetailedHistogram(data: Uint8Array | Uint16Array | Int16Array, bins: number): number[] {
    const histogram = new Array(bins).fill(0);
    const values = Array.from(data);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min;
    
    if (range === 0) return histogram;
    
    for (const value of values) {
      const binIndex = Math.min(bins - 1, Math.floor(((value - min) / range) * bins));
      histogram[binIndex]++;
    }
    
    return histogram;
  }

  /**
   * Find histogram peaks
   */
  private findHistogramPeaks(histogram: number[]): number[] {
    const peaks: number[] = [];
    const threshold = Math.max(...histogram) * 0.1; // 10% of max
    
    for (let i = 1; i < histogram.length - 1; i++) {
      if (histogram[i] > histogram[i-1] && 
          histogram[i] > histogram[i+1] && 
          histogram[i] > threshold) {
        peaks.push(i);
      }
    }
    
    return peaks;
  }

  /**
   * Find histogram valleys
   */
  private findHistogramValleys(histogram: number[]): number[] {
    const valleys: number[] = [];
    
    for (let i = 1; i < histogram.length - 1; i++) {
      if (histogram[i] < histogram[i-1] && histogram[i] < histogram[i+1]) {
        valleys.push(i);
      }
    }
    
    return valleys;
  }

  /**
   * Classify histogram distribution
   */
  private classifyDistribution(histogram: number[], peaks: number[]): 'uniform' | 'bimodal' | 'multimodal' | 'skewed' {
    if (peaks.length === 0 || peaks.length === 1) {
      // Check for skewness
      const mean = this.calculateHistogramMean(histogram);
      const median = this.calculateHistogramMedian(histogram);
      return Math.abs(mean - median) > histogram.length * 0.1 ? 'skewed' : 'uniform';
    } else if (peaks.length === 2) {
      return 'bimodal';
    } else {
      return 'multimodal';
    }
  }

  /**
   * Generate histogram-based recommendations
   */
  private generateHistogramRecommendations(
    distribution: 'uniform' | 'bimodal' | 'multimodal' | 'skewed',
    peakCount: number
  ): string[] {
    const recommendations: string[] = [];
    
    switch (distribution) {
      case 'bimodal':
        recommendations.push('Bimodal distribution detected - consider dual window/level settings');
        break;
      case 'multimodal':
        recommendations.push('Multimodal distribution - may benefit from region-specific windowing');
        break;
      case 'skewed':
        recommendations.push('Skewed distribution - consider gamma correction for optimal display');
        break;
      case 'uniform':
        recommendations.push('Uniform distribution - standard windowing should work well');
        break;
    }
    
    return recommendations;
  }

  /**
   * Generate lookup table for display
   */
  private generateLookupTable(
    minValue: number,
    maxValue: number,
    windowCenter: number,
    windowWidth: number,
    targetRange: [number, number]
  ): number[] {
    const lut: number[] = [];
    const windowMin = windowCenter - windowWidth / 2;
    const windowMax = windowCenter + windowWidth / 2;
    const [targetMin, targetMax] = targetRange;
    const targetRange_ = targetMax - targetMin;
    
    for (let i = minValue; i <= maxValue; i++) {
      let value: number;
      
      if (i <= windowMin) {
        value = targetMin;
      } else if (i >= windowMax) {
        value = targetMax;
      } else {
        value = targetMin + ((i - windowMin) / windowWidth) * targetRange_;
      }
      
      lut.push(Math.round(value));
    }
    
    return lut;
  }

  /**
   * Calculate optimal gamma correction
   */
  private calculateOptimalGamma(statistics: PixelDataStatistics): number {
    // Simple gamma calculation based on histogram distribution
    const skewness = (statistics.mean - statistics.median) / statistics.standardDeviation;
    
    if (skewness > 0.5) {
      return 0.8; // Darker gamma for right-skewed data
    } else if (skewness < -0.5) {
      return 1.2; // Brighter gamma for left-skewed data
    } else {
      return 1.0; // No gamma correction needed
    }
  }

  // Helper methods for quality assessment
  private calculateSharpness(data: Uint8Array | Uint16Array | Int16Array, rows: number, columns: number): number {
    // Calculate gradient magnitude as a proxy for sharpness
    let gradientSum = 0;
    let count = 0;
    
    for (let y = 1; y < rows - 1; y++) {
      for (let x = 1; x < columns - 1; x++) {
        const idx = y * columns + x;
        const gx = data[idx + 1] - data[idx - 1];
        const gy = data[idx + columns] - data[idx - columns];
        gradientSum += Math.sqrt(gx * gx + gy * gy);
        count++;
      }
    }
    
    return Math.min(gradientSum / count / 1000, 1.0); // Normalize to 0-1
  }

  private calculateNoise(data: Uint8Array | Uint16Array | Int16Array, rows: number, columns: number): number {
    // Use Laplacian operator to estimate noise
    let noiseSum = 0;
    let count = 0;
    
    for (let y = 1; y < rows - 1; y++) {
      for (let x = 1; x < columns - 1; x++) {
        const idx = y * columns + x;
        const laplacian = Math.abs(
          4 * data[idx] - data[idx - 1] - data[idx + 1] - data[idx - columns] - data[idx + columns]
        );
        noiseSum += laplacian;
        count++;
      }
    }
    
    return Math.min(noiseSum / count / 1000, 1.0); // Normalize to 0-1
  }

  private calculateEdgeVariance(data: Uint8Array | Uint16Array | Int16Array, rows: number, columns: number): number {
    const edgePixels = this.getEdgePixels(data, rows, columns);
    const mean = edgePixels.reduce((sum, val) => sum + val, 0) / edgePixels.length;
    const variance = edgePixels.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / edgePixels.length;
    return Math.sqrt(variance);
  }

  private getEdgePixels(data: Uint8Array | Uint16Array | Int16Array, rows: number, columns: number): number[] {
    const edgePixels: number[] = [];
    
    // Top and bottom edges
    for (let x = 0; x < columns; x++) {
      edgePixels.push(data[x]); // Top edge
      edgePixels.push(data[(rows - 1) * columns + x]); // Bottom edge
    }
    
    // Left and right edges
    for (let y = 1; y < rows - 1; y++) {
      edgePixels.push(data[y * columns]); // Left edge
      edgePixels.push(data[y * columns + columns - 1]); // Right edge
    }
    
    return edgePixels;
  }

  private findPixelsInRange(
    data: Uint8Array | Uint16Array | Int16Array,
    rows: number,
    columns: number,
    min: number,
    max: number
  ): Array<{ x: number; y: number; value: number }> {
    const pixels: Array<{ x: number; y: number; value: number }> = [];
    
    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < columns; x++) {
        const idx = y * columns + x;
        const value = data[idx];
        
        if (value >= min && value <= max) {
          pixels.push({ x, y, value });
        }
      }
    }
    
    return pixels;
  }

  private calculateBoundingBox(
    pixels: Array<{ x: number; y: number; value: number }>,
    columns: number
  ): { x: number; y: number; width: number; height: number } {
    if (pixels.length === 0) {
      return { x: 0, y: 0, width: 0, height: 0 };
    }
    
    const xs = pixels.map(p => p.x);
    const ys = pixels.map(p => p.y);
    
    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);
    
    return {
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1
    };
  }

  private calculateHistogramMean(histogram: number[]): number {
    let sum = 0;
    let count = 0;
    
    for (let i = 0; i < histogram.length; i++) {
      sum += i * histogram[i];
      count += histogram[i];
    }
    
    return count > 0 ? sum / count : 0;
  }

  private calculateHistogramMedian(histogram: number[]): number {
    const total = histogram.reduce((sum, val) => sum + val, 0);
    const half = total / 2;
    
    let cumSum = 0;
    for (let i = 0; i < histogram.length; i++) {
      cumSum += histogram[i];
      if (cumSum >= half) {
        return i;
      }
    }
    
    return 0;
  }
}